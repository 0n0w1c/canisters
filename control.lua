local rfs_gui = require("rfs-gui")

-- Load settings from startup configuration
local space_age = script.active_mods["space-age"]
local base_canisters = (space_age and 50) or 1000

local machine_types
if space_age then
    machine_types =
    {
        "chemical-plant",
        "assembling-machine-2",
        "assembling-machine-3",
        "cryogenic-plant",
        "biochamber"
    }
else
    machine_types =
    {
        "chemical-plant",
        "assembling-machine-2",
        "assembling-machine-3"
    }
end

-- Stores per-surface productivity averages and last update tick
local rocket_fuel_productivity_cache = {}

--- Calculates the productivity bonus from a research technology.
--- This is based on the technology's level (each level adds 10%).
---
--- @param force LuaForce               The force (e.g. player's faction) that owns the technology.
--- @param technology_name string       The name of the technology (e.g., "rocket-part-productivity").
--- @return number                      The productivity bonus as a decimal (e.g., 0.3 for 30%).
local function get_research_bonus(force, technology_name)
    local tech = force.technologies[technology_name]
    if tech and tech.valid and tech.level then
        return (tech.level - 1) * 0.1
    end

    return 0
end

--- Calculates the total rocket part productivity bonus for a force, specific to the Muluna tech progression.
---
--- This function sums:
--- 1. All researched finite technologies matching "rocket-part-productivity", adding +10% per tech.
--- 2. The infinite bonus from "rocket-part-productivity-aquilo", weighted as 2× its normal value.
---
--- @param force LuaForce The force whose technologies should be scanned for rocket part productivity bonuses.
--- @return number The total rocket part productivity bonus (e.g., 0.5 = +50%).
local function get_muluna_rocket_part_bonus(force)
    local total_bonus = 0
    local level_bonus = 0.1

    for name, tech in pairs(force.technologies) do
        if tech.valid and tech.researched and string.find(name, "rocket%-part%-productivity") then
            total_bonus = total_bonus + level_bonus
        end
    end

    local infinite_bonus = get_research_bonus(force, "rocket-part-productivity-aquilo")
    total_bonus = total_bonus + (2 * infinite_bonus)

    return total_bonus
end

--- Calculates or retrieves the cached productivity bonus from assembling machines
--- producing rocket fuel on a given surface for a specific force.
--- Caches results per (surface, force) key to reduce performance cost.
---
--- The function scans eligible assembling machines belonging to the specified force
--- and averages their productivity bonus if their current recipe produces rocket fuel.
--- Returns 0 if the force has not researched the "rocket-fuel" technology.
---
--- @param surface LuaSurface           The surface to scan for eligible assembling machines.
--- @param force LuaForce               The force to filter entities and check research for.
--- @return number                      The average productivity bonus (e.g., 0.25 for 25%).
function get_surface_rocket_fuel_productivity(surface, force)
    if not surface then return 0 end
    if not (force and force.technologies["rocket-fuel"] and force.technologies["rocket-fuel"].researched) then
        return 0
    end

    local surface_name = surface.name
    local force_name = force.name
    local current_tick = game.tick

    local default_duration_ticks = 60 * 60
    local cache_life = default_duration_ticks

    local settings = storage.rfs_surface_settings and storage.rfs_surface_settings[surface_name]
    if settings and settings.cache_duration then
        local minutes = tonumber(settings.cache_duration)
        if minutes and minutes > 0 then
            cache_life = math.floor(minutes * 60)
        end
    end

    local cache_key = surface_name .. "::" .. force_name
    local cache = rocket_fuel_productivity_cache[cache_key]
    if cache and (current_tick - cache.tick) < cache_life then
        return cache.average
    end

    local assembling_machines = surface.find_entities_filtered {
        type = "assembling-machine",
        name = machine_types,
        force = force
    }

    local total_bonus = 0
    local count = 0

    for _, assembler in pairs(assembling_machines) do
        local recipe = assembler.get_recipe()
        if recipe and recipe.valid and recipe.prototype then
            local recipe_prototype = recipe.prototype
            if recipe_prototype.main_product and recipe_prototype.main_product.name == "rocket-fuel" then
                total_bonus = total_bonus + assembler.productivity_bonus
                count = count + 1
            end
        end
    end

    local average = (count > 0) and (total_bonus / count) or 0

    rocket_fuel_productivity_cache[cache_key] = {
        average = average,
        tick = current_tick
    }

    return average
end

--- Retrieves the effective module productivity bonus for a given surface and force.
---
--- If user-defined settings exist for the surface, they are used in the following order:
--- 1. A custom value (if enabled via checkbox) is returned, converted from percent to decimal.
--- 2. If "use_cached" is selected instead, the value is calculated using entity scanning.
--- 3. If no valid settings exist, fallback to calculated value.
---
--- @param surface LuaSurface           The surface to check productivity on.
--- @param force LuaForce               The force owning the machines and settings.
--- @return number                      The productivity bonus as a decimal (e.g., 0.2 for 20%).
local function get_effective_module_bonus(surface, force)
    if not surface or not surface.valid then return 0 end
    if not force then return 0 end

    local surface_name = surface.name
    local settings = (storage.rfs_surface_settings or {})[surface_name]

    if settings then
        if settings.use_custom and settings.custom_value then
            local value = tonumber(settings.custom_value)
            if value and value >= 0 then
                return value / 100
            end
        elseif settings.use_cached then
            return get_surface_rocket_fuel_productivity(surface, force)
        end
    end

    return get_surface_rocket_fuel_productivity(surface, force)
end

--- Calculates the number of canisters required for a rocket launch.
---
--- Uses rocket fuel productivity (modules + fuel research) to determine attrition,
--- and rocket part productivity (silo + research) to calculate effective throughput.
---
--- Clamps fuel bonus to 75% (max 3.0 out of 4), and part bonus to 200% (max 2.0 additional).
--- Final canister count is floored from the formula:
---     base_canisters * (1 - fuel_bonus / 4) / (1 + part_bonus)
---
--- @param silo LuaEntity               The launching rocket silo.
--- @return integer                     The required number of canisters after all bonuses applied.
local function calculate_canisters(silo)
    if not (silo and silo.valid) then
        return base_canisters
    end

    local force = silo.force
    local surface = silo.surface
    local module_bonus = get_effective_module_bonus(surface, force)
    local silo_productivity = silo.productivity_bonus or 0
    local fuel_research_bonus = get_research_bonus(force, "rocket-fuel-productivity")
    local part_research_bonus = get_research_bonus(force, "rocket-part-productivity")
    if script.active_mods["planet-muluna"] then
        part_research_bonus = get_muluna_rocket_part_bonus(force)
    end

    local total_fuel_bonus = fuel_research_bonus + module_bonus
    if total_fuel_bonus > 4 then total_fuel_bonus = 4 end

    local attrition_rate = 1 - total_fuel_bonus / 4

    local total_part_bonus = silo_productivity + part_research_bonus
    if total_part_bonus > 4 then total_part_bonus = 4 end

    local canisters = math.floor(base_canisters * attrition_rate / (1 + total_part_bonus))

    --[[
    game.print("--- Canister Calculation Debug ---")
    game.print("Base canisters: " .. base_canisters)
    game.print("Module bonus: " .. string.format("%.3f", module_bonus))
    game.print("Fuel research bonus: " .. string.format("%.3f", fuel_research_bonus))
    game.print("Total rocket fuel bonus (capped 4): " .. string.format("%.3f", total_fuel_bonus))
    game.print("Silo productivity: " .. string.format("%.3f", silo_productivity))
    game.print("Part research bonus: " .. string.format("%.3f", part_research_bonus))
    game.print("Total rocket part bonus (capped 4): " .. string.format("%.3f", total_part_bonus))
    game.print("Attrition rate: " .. string.format("%.3f", attrition_rate))
    game.print("Final canisters: " .. canisters)
    ]]

    return canisters
end

--- Finds the base (platform hub or landing pad) at a given position.
--- @param surface LuaSurface # The game surface to search on.
--- @param position MapPosition # The exact position to check.
--- @return LuaEntity|nil # The found base entity (either 'space-platform-hub' or 'cargo-landing-pad'), or nil if none found.
local function find_base_at_position(surface, position)
    local base_name = space_age and "space-platform-hub" or "cargo-landing-pad"

    return surface.find_entity(base_name, position)
end

--- Removes rocket cargo pod entries from storage that are older than 3600 ticks.
--- @return nil
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

--- Stores the number of canisters required for a rocket launch, based on the silo and destination.
--- @param event EventData.on_rocket_launch_ordered # Event data from on_rocket_launch_ordered.
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

--- Returns canisters from a delivered cargo pod back to its destination base or spills them if storage is full.
--- @param event EventData.on_cargo_pod_delivered_cargo # Event data from on_cargo_pod_delivered_cargo.
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

    local base = find_base_at_position(surface, position) or nil
    if not (base and base.valid) then return end

    local count = pod_data.canisters

    local inserted = 0
    local inventory = base.get_inventory(defines.inventory.chest)
    if inventory then
        inserted = inventory.insert({ name = "canister-black", count = count })
    end

    local remaining = count - inserted

    if remaining > 0 then
        surface.spill_item_stack
        ({
            position = position,
            stack = { name = "canister-black", count = remaining }
        })

        local spilled_items = surface.find_entities_filtered({ name = "item-on-ground" })

        for _, item in pairs(spilled_items) do
            if item.valid and item.stack and item.stack.name == "canister-black" then
                if not item.to_be_deconstructed() then
                    item.order_deconstruction(base and base.force or cargo_pod.force)
                end
            end
        end

        for _, player in pairs(game.connected_players) do
            if player.force == (base and base.force or cargo_pod.force) then
                player.add_alert(base or cargo_pod, defines.alert_type.no_platform_storage)
            end
        end
    end

    storage.rocket_cargo_pods[unit_number] = nil

    prune_storage()
end

--- Handles GUI click events, such as closing the rocket fuel settings frame.
--- @param event EventData.on_gui_click # Event data for a GUI click event.
local function handle_on_gui_click(event)
    if event.element.name == "rfs_close_button" then
        local player = game.get_player(event.player_index)
        if player and player.gui.screen.rocket_fuel_settings_frame then
            player.gui.screen.rocket_fuel_settings_frame.destroy()
        end
    end
end

--- Handles selection state changes in the rocket fuel settings GUI.
--- Updates surface-specific settings based on user input.
--- @param event EventData.on_gui_selection_state_changed # Event data for a GUI selection state change.
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

    if element.name == "rfs_surface_selector" then
        frame.destroy()
        build_rocket_fuel_settings_gui(player, surface_name, settings)
        return
    end

    if element.name == "rfs_custom_value" then
        local selected_value = element.items[element.selected_index]
        if selected_value then
            settings.custom_value = selected_value
        end
    end

    if element.name == "rfs_cache_duration" then
        local selected_value = element.items[element.selected_index]
        if selected_value then
            settings.cache_duration = selected_value
        end
    end

    storage.rfs_surface_settings[surface_name] = settings
end

--- Handles checkbox state changes in the rocket fuel settings GUI.
--- Updates the surface-specific settings and ensures checkbox exclusivity between custom and cached options.
--- Rebuilds the GUI to reflect the new settings.
--- @param event EventData.on_gui_checked_state_changed # Event data from a GUI checkbox state change.
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

    local surface = game.surfaces[selected_surface]
    local force = player.force
    local custom_value = math.floor(get_surface_rocket_fuel_productivity(surface, force) * 100 + 0.5)

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
    preset = storage.rfs_surface_settings
    build_rocket_fuel_settings_gui(player, selected_surface, preset)
end

--- Toggles the rocket fuel settings GUI when the push button or shortcut is activated.
--- Destroys the GUI if it's already open, or builds it for the player's current surface.
--- @param event EventData.on_gui_click|EventData.on_lua_shortcut The GUI or shortcut activation event.
local function handle_rfs_push_button_gui(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local frame = player.gui.screen.rocket_fuel_settings_frame
    if frame then
        frame.destroy()
    else
        build_rocket_fuel_settings_gui(player, player.surface.name)
    end
end

--- Handles the Lua shortcut event for toggling the rocket fuel settings GUI.
--- @param event EventData.on_lua_shortcut # The shortcut activation event.
local function handle_on_lua_shortcut(event)
    if event.prototype_name == "rfs-shortcut" then
        handle_rfs_push_button_gui(event)
    end
end

--- Handles the event when a GUI element is closed manually.
--- Ensures the rocket fuel settings frame is destroyed if it was closed.
--- @param event EventData.on_gui_closed # The GUI close event.
local function handle_on_gui_closed(event)
    if event.element and event.element.name == "rocket_fuel_settings_frame" then
        local player = game.get_player(event.player_index)
        if player and player.gui.screen.rocket_fuel_settings_frame then
            player.gui.screen.rocket_fuel_settings_frame.destroy()
        end
    end
end

--- Registers all event handlers used by the mod.
local function register_events()
    script.on_event(defines.events.on_rocket_launch_ordered, handle_on_rocket_launch_ordered)
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_on_cargo_pod_delivered_cargo)
    script.on_event(defines.events.on_gui_click, handle_on_gui_click)
    script.on_event(defines.events.on_gui_checked_state_changed, handle_on_gui_checked_state_changed)
    script.on_event(defines.events.on_gui_selection_state_changed, handle_on_gui_selection_state_changed)
    script.on_event(defines.events.on_lua_shortcut, handle_on_lua_shortcut)
    script.on_event(defines.events.on_gui_closed, handle_on_gui_closed)
end

--- Initializes mod storage and registers event handlers when the mod is first added to a save.
script.on_init(function()
    storage.rocket_cargo_pods = {}
    storage.rfs_surface_settings = {}
    register_events()
end)

--- Handles configuration changes such as mod updates or added/removed mods.
--- Ensures all storage tables are initialized and event handlers are re-registered.
--- @param data ConfigurationChangedData
script.on_configuration_changed(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    storage.rfs_surface_settings = storage.rfs_surface_settings or {}
    register_events()
end)

--- Re-registers event handlers after a game load to ensure event handlers are restored.
script.on_load(function()
    register_events()
end)
