--- @module Canisters

-- Load settings from startup configuration
local reusable = settings.startup["canisters-reusable-canisters"].value
local space_age = script.active_mods["space-age"]
local base_canisters = (space_age and 50) or 100
local attrition_rate_setting = settings.startup["canisters-attrition-rate"].value
local attrition_rate = 1 - (attrition_rate_setting / 100)

--- Retrieves the research bonus from "rocket-part-productivity" technology.
--- @param force LuaForce The force (faction/team) conducting the research.
--- @return number number The total bonus from research, each level adds 10%.
local function get_research_bonus(force)
    local tech = force.technologies["rocket-part-productivity"]
    if tech and tech.valid then
        return (tech.level - 1) * 0.1
    end
    return 0
end

--- Calculates the number of canisters required based on productivity bonuses.
--- @param silo LuaEntity The rocket silo launching the cargo pod.
--- @return number number The adjusted number of canisters required.
local function calculate_canisters(silo)
    if not (silo and silo.valid) then
        return base_canisters
    end

    local force = silo.force
    local silo_productivity = silo.productivity_bonus or 0
    local research_bonus = get_research_bonus(force)

    local total_productivity = silo_productivity + research_bonus
    if total_productivity > 3 then total_productivity = 3 end

    return math.floor(base_canisters / (1 + total_productivity) + 0.5)
end

--- Adjusts the number of canisters, applying a random loss.
--- @param count number The original canister count before adjustment.
--- @return number The adjusted canister count.
local function adjust_for_attrition(count)
    local random
    if not storage.rng then
        storage.rng = game.create_random_generator()
    end

    random = storage.rng(math.floor(count * attrition_rate), count)

    return random
end

--- Store count of canisters required for the launch
--- @param event EventData
local function handle_on_rocket_launch_ordered(event)
    local silo = event.rocket_silo
    local rocket = event.rocket
    local cargo_pod = rocket and rocket.attached_cargo_pod

    if not (silo and silo.valid) then return end

    if cargo_pod and cargo_pod.valid then
        local destination = ""
        if cargo_pod.cargo_pod_destination.station then
            destination = tostring(cargo_pod.cargo_pod_destination.station)
        elseif cargo_pod.cargo_pod_destination.space_platform then
            destination = tostring(cargo_pod.cargo_pod_destination.space_platform)
        end

        local unit_number = cargo_pod.unit_number
        local count = adjust_for_attrition(calculate_canisters(silo))

        storage.rocket_cargo_pods[unit_number] = {
            canisters = count,
            destination = destination,
            tick = game.tick
        }
    end
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
--- Alerts players if canisters are lost due to expiration.
--- @param entity LuaEntity The entity to alert on
local function prune_storage(entity)
    local current_tick = game.tick
    local max_ticks = 3600
    local expired = {}

    for unit_number, pod_data in pairs(storage.rocket_cargo_pods) do
        if current_tick - pod_data.tick >= max_ticks then
            local canisters_lost = pod_data.canisters

            -- Alert players about canisters lost to the void
            for _, player in pairs(game.connected_players) do
                if player.force == entity.force then
                    player.add_custom_alert(
                        entity,
                        { type = "virtual", name = "canisters-void-alert" },
                        canisters_lost .. " canisters have been lost to the void of space!",
                        true
                    )
                end
            end

            -- Collect expired cargo pod data
            table.insert(expired, unit_number)
        end
    end

    -- Remove expired entries
    for _, unit_number in ipairs(expired) do
        storage.rocket_cargo_pods[unit_number] = nil
    end
end

--- Return canisters to the base.
--- @param event EventData
local function handle_on_cargo_pod_delivered_cargo(event)
    if not reusable then return end

    local cargo_pod = event.cargo_pod
    local unit_number = cargo_pod.unit_number
    if not (cargo_pod and unit_number) then return end

    local pod_data = storage.rocket_cargo_pods[unit_number]
    if not pod_data then return end

    local destination = pod_data.destination

    -- If a new platform build, find the surface
    local base = nil
    if string.find(destination, "%[LuaSpacePlatform: index=") then
        local platform_index = string.match(destination, "index=%s*(%d+)%]")
        local surface_name = "platform-" .. platform_index
        local surface = game.get_surface(surface_name)

        if surface then
            base = find_base_at_position(surface, { 0, 0 })
        end
    else
        base = find_base_at_position(cargo_pod.surface, cargo_pod.position)
    end

    if not base then return end

    local count = pod_data.canisters

    -- Attempt to insert canisters into the base inventory
    local inserted = 0
    if base and base.valid then
        local inventory = base.get_inventory(defines.inventory.chest)
        if inventory then
            inserted = inventory.insert({ name = "canister", count = count })
        end
    end

    local remaining = count - inserted

    -- Spill the remaining canisters
    if remaining > 0 then
        cargo_pod.surface.spill_item_stack({
            position = base and base.valid and base.position or cargo_pod.position,
            stack = { name = "canister", count = remaining }
        })

        -- Auto-deconstruct spilled canisters
        local spilled_items = cargo_pod.surface.find_entities_filtered({ name = "item-on-ground" })
        for _, item in pairs(spilled_items) do
            if item.valid and item.stack and item.stack.name == "canister" then
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
    prune_storage(cargo_pod)
end

local function register_events()
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_on_cargo_pod_delivered_cargo)
    script.on_event(defines.events.on_rocket_launch_ordered, handle_on_rocket_launch_ordered)
end

script.on_init(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    storage.rng = storage.rng or game.create_random_generator()
    register_events()
end)

script.on_configuration_changed(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    storage.rng = storage.rng or game.create_random_generator()
    register_events()
end)

script.on_load(register_events)
