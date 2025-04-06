local rfs_gui = require("rfs-gui")

-- Load settings from startup configuration
local space_age = script.active_mods["space-age"]
local base_canisters = (space_age and 50) or 1000

-- Stores per-surface productivity averages and last update tick
local rocket_fuel_productivity_cache = {}

--- Retrieves the productivity bonus from a given research technology.
--- @param force LuaForce # The force (e.g. player faction) that owns the technology.
--- @param technology_name string # The internal name of the technology (e.g., "rocket-part-productivity").
--- @return number # The productivity bonus as a decimal (e.g., 0.3 for 30%).
local function get_research_bonus(force, technology_name)
    local tech = force.technologies[technology_name]
    if tech and tech.valid then
        return (tech.level - 1) * 0.1
    end
    return 0
end

--- Calculates or retrieves the cached productivity bonus from assemblers producing rocket fuel on a surface.
--- @param surface LuaSurface
--- @return number The average productivity bonus on that surface.
function get_surface_rocket_fuel_productivity(surface)
    local surface_name = surface.name
    local current_tick = game.tick

    -- Default cache life in ticks (if no custom duration set)
    local default_duration_ticks = 60 * 60
    local cache_life = default_duration_ticks

    -- Check if user has a cache duration setting for this surface
    local settings = storage.rfs_surface_settings and storage.rfs_surface_settings[surface_name]
    if settings and settings.cache_duration then
        local minutes = tonumber(settings.cache_duration)
        if minutes and minutes > 0 then
            cache_life = math.floor(minutes * 60)
        end
    end

    -- Use cache if it's still fresh
    local cache = rocket_fuel_productivity_cache[surface_name]
    if cache and (current_tick - cache.tick) < cache_life then
        return cache.average
    end

    -- Recalculate productivity
    local names
    if surface_name == "aquilo" then
        names = { "cryogenic", "chemical-plant", "assembling-machine-2", "assembling-machine-3" }
    elseif surface_name == "gleba" then
        names = { "biochamber", "assembling-machine-2", "assembling-machine-3" }
    else
        names = { "assembling-machine-2", "assembling-machine-3" }
    end

    local assembling_machines = surface.find_entities_filtered {
        type = "assembling-machine",
        name = names
    }

    local total_bonus = 0
    local count = 0

    for _, assembler in pairs(assembling_machines) do
        local recipe = assembler.get_recipe()
        if recipe and recipe.valid and recipe.prototype then
            local proto = recipe.prototype
            local produces_rocket_fuel = false

            if proto.main_product and proto.main_product.name == "rocket-fuel" then
                produces_rocket_fuel = true
            elseif proto.results then
                for _, result in pairs(proto.results) do
                    if result.name == "rocket-fuel" then
                        produces_rocket_fuel = true
                        break
                    end
                end
            end

            if produces_rocket_fuel then
                total_bonus = total_bonus + assembler.productivity_bonus
                count = count + 1
            end
        end
    end

    local average = (count > 0) and (total_bonus / count) or 0

    rocket_fuel_productivity_cache[surface_name] = {
        average = average,
        tick = current_tick
    }

    return average
end

--- Gets the module productivity bonus for a surface, using stored settings or calculating it.
--- @param surface LuaSurface
--- @return number -- the productivity bonus (e.g., 0.2 for 20%)
local function get_effective_module_bonus(surface)
    if not surface or not surface.valid then return 0 end

    local surface_name = surface.name
    local settings = (storage.rfs_surface_settings or {})[surface_name]

    if settings then
        if settings.use_custom and settings.custom_value then
            local value = tonumber(settings.custom_value)
            if value and value >= 0 then
                return value / 100
            end
        elseif settings.use_cached then
            return get_surface_rocket_fuel_productivity(surface)
        end
    end

    -- fallback if no settings found or invalid
    return get_surface_rocket_fuel_productivity(surface)
end

local function calculate_canisters(silo)
    if not (silo and silo.valid) then
        game.print("Silo is invalid. Using base canisters: " .. base_canisters)
        return base_canisters
    end

    local force = silo.force
    local surface = silo.surface
    local module_bonus = get_effective_module_bonus(surface)
    local silo_productivity = silo.productivity_bonus or 0
    local part_research_bonus = get_research_bonus(force, "rocket-part-productivity")
    local fuel_research_bonus = get_research_bonus(force, "rocket-fuel-productivity")

    local total_fuel_productivity_bonus = fuel_research_bonus + module_bonus
    if total_fuel_productivity_bonus > 3 then total_fuel_productivity_bonus = 3 end

    local attrition_rate = 1 - total_fuel_productivity_bonus / 4

    local total_productivity = silo_productivity + part_research_bonus + 1
    if total_productivity > 3 then total_productivity = 3 end

    local canisters = math.floor(base_canisters * attrition_rate / total_productivity)

    --[[
    game.print("--- Canister Calculation Debug ---")
    game.print("Base canisters: " .. base_canisters)
    game.print("Module bonus: " .. string.format("%.3f", module_bonus))
    game.print("Silo productivity: " .. string.format("%.3f", silo_productivity))
    game.print("Part research bonus: " .. string.format("%.3f", part_research_bonus))
    game.print("Fuel research bonus: " .. string.format("%.3f", fuel_research_bonus))
    game.print("Total fuel productivity bonus (capped): " .. string.format("%.3f", total_fuel_productivity_bonus))
    game.print("Attrition rate: " .. string.format("%.3f", attrition_rate))
    game.print("Total productivity (capped): " .. string.format("%.3f", total_productivity))
    game.print("Final canisters: " .. canisters)
    ]]

    return canisters
end

--- Finds the base at a given position.
--- @param surface LuaSurface The game surface to search on.
--- @param position MapPosition The exact position to check.
--- @return LuaEntity|nil The platform hub at the position, or nil if none found.
local function find_base_at_position(surface, position)
    local base_name = space_age and "space-platform-hub" or "cargo-landing-pad"

    return surface.find_entity(base_name, position)
end

--- Prunes old storage entries by removing expired rocket cargo pods.
local function prune_storage()
    local expired = {}

    for unit_number, pod_data in pairs(storage.rocket_cargo_pods) do
        if game.tick - pod_data.tick >= 3600 then
            table.insert(expired, unit_number)
        end
    end

    for _, unit_number in ipairs(expired) do
        storage.rocket_cargo_pods[unit_number] = nil
    end
end

--- Store the count of canisters required for the launch
--- @param event EventData
local function handle_on_rocket_launch_ordered(event)
    local silo = event.rocket_silo
    local rocket = event.rocket
    local cargo_pod = rocket and rocket.attached_cargo_pod

    if not (silo and silo.valid) then return end

    if cargo_pod and cargo_pod.valid and cargo_pod.cargo_pod_destination then
        local destination = nil
        if cargo_pod.cargo_pod_destination.space_platform then
            destination = cargo_pod.cargo_pod_destination.space_platform
        elseif cargo_pod.cargo_pod_destination.station then
            destination = cargo_pod.cargo_pod_destination.station
        end

        local unit_number = cargo_pod.unit_number
        local count = calculate_canisters(silo)
        if count > 1 then
            storage.rocket_cargo_pods[unit_number] =
            {
                canisters = count,
                destination = destination,
                tick = game.tick
            }
        end
    end
end

--- Return canisters to the base.
--- @param event EventData
local function handle_on_cargo_pod_delivered_cargo(event)
    local cargo_pod = event.cargo_pod
    if not (cargo_pod and cargo_pod.valid and cargo_pod.unit_number) then return end

    local unit_number = cargo_pod.unit_number

    local pod_data = storage.rocket_cargo_pods[unit_number]
    if not pod_data then return end

    local destination = pod_data.destination
    local surface = (destination and destination.valid) and destination.surface or nil
    if not surface then return end

    local position
    if string.match(surface.name, "platform%-(%d+)") then
        position = { x = 0, y = 0 }
    else
        position = cargo_pod.position
    end

    -- base is either cargo landing pad or space platform hub
    local base = find_base_at_position(surface, position) or nil
    if not (base and base.valid) then return end

    local count = pod_data.canisters

    -- Attempt to insert canisters into the base inventory
    local inserted = 0
    local inventory = base.get_inventory(defines.inventory.chest)
    if inventory then
        inserted = inventory.insert({ name = "canister-black", count = count })
    end

    local remaining = count - inserted

    -- Spill the remaining canisters
    if remaining > 0 then
        surface.spill_item_stack
        ({
            position = position,
            stack = { name = "canister-black", count = remaining }
        })

        -- Auto-deconstruct spilled canisters
        local spilled_items = surface.find_entities_filtered({ name = "item-on-ground" })

        for _, item in pairs(spilled_items) do
            if item.valid and item.stack and item.stack.name == "canister-black" then
                if not item.to_be_deconstructed() then
                    item.order_deconstruction(base and base.force or cargo_pod.force)
                end
            end
        end

        -- Alert players about the spill
        for _, player in pairs(game.connected_players) do
            if player.force == (base and base.force or cargo_pod.force) then
                player.add_alert(base or cargo_pod, defines.alert_type.no_platform_storage)
            end
        end
    end

    -- Remove processed cargo pod from storage
    storage.rocket_cargo_pods[unit_number] = nil

    -- Paranoia
    prune_storage()
end

local function handle_on_gui_click(event)
    if event.element.name == "rfs_close_button" then
        local player = game.get_player(event.player_index)
        if player and player.gui.screen.rocket_fuel_settings_frame then
            player.gui.screen.rocket_fuel_settings_frame.destroy()
        end
    end
end

local function handle_on_gui_selection_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local frame = player.gui.screen.rocket_fuel_settings_frame
    if not frame then return end

    local surface_selector = frame.rfs_surface_selector
    if not surface_selector then return end

    local surface_name = surface_selector.items[surface_selector.selected_index]
    if not surface_name then return end

    storage.rfs_surface_settings = storage.rfs_surface_settings or {}
    local settings = storage.rfs_surface_settings[surface_name] or {}

    -- Handle surface change
    if element.name == "rfs_surface_selector" then
        frame.destroy()
        build_rocket_fuel_settings_gui(player, surface_name, settings)
        return
    end

    -- Handle custom value change
    if element.name == "rfs_custom_value" then
        local selected_value = element.items[element.selected_index]
        if selected_value then
            settings.custom_value = selected_value
        end
    end

    -- Handle cache duration change
    if element.name == "rfs_cache_duration" then
        local selected_value = element.items[element.selected_index]
        if selected_value then
            settings.cache_duration = selected_value
        end
    end

    storage.rfs_surface_settings[surface_name] = settings
end

local function handle_on_gui_checked_state_changed(event)
    local element = event.element
    if not (element and element.valid) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local frame = player.gui.screen.rocket_fuel_settings_frame
    local settings_frame = frame and frame.rfs_settings_frame
    if not settings_frame then return end

    local surface_selector = frame.rfs_surface_selector
    if not surface_selector then return end

    local selected_surface = surface_selector.items[surface_selector.selected_index]
    if not selected_surface then return end

    local custom_value = math.floor(get_surface_rocket_fuel_productivity(game.surfaces[selected_surface]) * 100 + 0.5)

    local cache_dropdown = settings_frame.rfs_cache_duration
    local cache_duration = cache_dropdown and cache_dropdown.items[cache_dropdown.selected_index] or "1"

    local is_custom = element.name == "rfs_use_custom"
    local is_cached = element.name == "rfs_use_cached"

    local use_custom = false
    local use_cached = false

    if is_custom and element.state then
        use_custom = true
        if settings_frame.rfs_use_cached then
            settings_frame.rfs_use_cached.state = false
        end
    elseif is_cached and element.state then
        use_cached = true
        if settings_frame.rfs_use_custom then
            settings_frame.rfs_use_custom.state = false
        end
    end

    storage.rfs_surface_settings = storage.rfs_surface_settings or {}
    storage.rfs_surface_settings[selected_surface] = {
        use_custom = use_custom,
        use_cached = use_cached,
        custom_value = custom_value,
        cache_duration = cache_duration
    }

    frame.destroy()
    build_rocket_fuel_settings_gui(player, selected_surface)
end

local function handle_rfs_push_button_gui(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local frame = player.gui.screen.rocket_fuel_settings_frame
    if frame then
        frame.destroy()
    else
        build_rocket_fuel_settings_gui(player)
    end
end

local function handle_on_lua_shortcut(event)
    if event.prototype_name == "rfs-shortcut" then
        handle_rfs_push_button_gui(event)
    end
end

local function handle_on_gui_closed(event)
    if event.element and event.element.name == "rocket_fuel_settings_frame" then
        local player = game.get_player(event.player_index)
        if player and player.gui.screen.rocket_fuel_settings_frame then
            player.gui.screen.rocket_fuel_settings_frame.destroy()
        end
    end
end

local function register_events()
    script.on_event(defines.events.on_rocket_launch_ordered, handle_on_rocket_launch_ordered)
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_on_cargo_pod_delivered_cargo)
    script.on_event(defines.events.on_gui_click, handle_on_gui_click)
    script.on_event(defines.events.on_gui_checked_state_changed, handle_on_gui_checked_state_changed)
    script.on_event(defines.events.on_gui_selection_state_changed, handle_on_gui_selection_state_changed)
    script.on_event(defines.events.on_lua_shortcut, handle_on_lua_shortcut)
    script.on_event(defines.events.on_gui_closed, handle_on_gui_closed)
end

script.on_init(function()
    storage.rocket_cargo_pods = {}
    storage.rfs_surface_settings = {}
    register_events()
end)

script.on_configuration_changed(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    storage.rfs_surface_settings = storage.rfs_surface_settings or {}
    register_events()
end)

script.on_load(function()
    register_events()
end)
