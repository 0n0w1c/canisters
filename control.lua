--- Canisters Mod for Factorio
--- Handles canister retrieval and spill mechanics for cargo pods.
--- @module Canisters

-- Load settings from startup configuration
local reuseable = settings.startup["canisters-reuseable-canisters"].value
local spill = settings.startup["canisters-spill-canisters"].value
local metal = settings.startup["canisters-canister-metal"].value
local space_age = script.active_mods["space-age"]
local base_canisters = (space_age and 50) or 100

--- Retrieves the infinite research bonus from "rocket-part-productivity" technology.
--- @param force LuaForce The force (faction/team) conducting the research.
--- @return number The total bonus from infinite research, where each level adds 10% (0.1).
local function get_infinite_research_bonus(force)
    local tech = force.technologies["rocket-part-productivity"]
    if tech and tech.valid then
        return tech.level * 0.1 -- Each level adds 10% productivity bonus
    end
    return 0
end

--- Calculates the number of canisters required based on productivity bonuses.
--- @param silo LuaEntity The rocket silo launching the cargo pod.
--- @return number The adjusted number of canisters required.
local function calculate_canisters(silo)
    if not (silo and silo.valid) then
        return base_canisters
    end

    local force = silo.force
    local silo_productivity = silo.productivity_bonus or 0
    local infinite_research_bonus = get_infinite_research_bonus(force)

    local total_productivity = silo_productivity + infinite_research_bonus
    if total_productivity > 3 then total_productivity = 3 end

    -- Compute final canisters needed with proper rounding
    return math.floor(base_canisters / (1 + total_productivity) + 0.5)
end

--- Adjusts the number of canisters when using Tin, applying a random 10% reduction.
--- @param count number The original canister count before adjustment.
--- @return number The adjusted canister count.
local function adjust_for_metal(count)
    if metal == "Tin" then
        local rng = game.create_random_generator(game.tick)

        -- Randomly pick between 90% and 100% of count
        return rng(math.floor(count * 0.90), count)
    end
    return count
end

--- Handles a rocket launch event, capturing cargo pod details.
--- @param event EventData.on_rocket_launch_ordered The event data containing rocket launch details.
local function handle_on_rocket_launch_ordered(event)
    local silo = event.rocket_silo
    local rocket = event.rocket
    local cargo_pod = rocket and rocket.attached_cargo_pod

    if not (silo and silo.valid) then return end

    if cargo_pod and cargo_pod.valid then
        local unit_number = cargo_pod.unit_number
        local canisters = adjust_for_metal(calculate_canisters(silo))

        -- Store cargo pod details in global storage
        storage.rocket_cargo_pods[unit_number] = {
            canisters = canisters,
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

--- Return the canisters to the base.
--- @param event EventData.on_cargo_pod_delivered_cargo The event data containing cargo pod delivery details.
local function handle_on_cargo_pod_delivered_cargo(event)
    if not reuseable then return end

    local cargo_pod = event.cargo_pod
    local unit_number = cargo_pod.unit_number
    local pod_data = storage.rocket_cargo_pods[unit_number]

    if not pod_data then return end

    local count = pod_data.canisters
    local base = find_base_at_position(cargo_pod.surface, cargo_pod.position)

    -- Attempt to insert canisters into the base
    local inserted = 0
    if base and base.valid then
        local inventory = base.get_inventory(defines.inventory.chest)
        if inventory then
            inserted = inventory.insert({ name = "canister", count = count })
        end
    end

    local remaining = count - inserted

    -- Handle remaining canisters (spill or void)
    if remaining > 0 then
        if spill then
            -- Spill remaining canisters onto the platform
            cargo_pod.surface.spill_item_stack({
                position = base and base.valid and base.position or cargo_pod.position,
                stack = { name = "canister", count = remaining }
            })

            -- Auto-deconstruct spilled canisters
            local spilled_items = cargo_pod.surface.find_entities_filtered({ name = "item-on-ground" })
            for _, entity in pairs(spilled_items) do
                if entity.valid and entity.stack and entity.stack.name == "canister" then
                    entity.order_deconstruction(base and base.force or cargo_pod.force)
                end
            end

            -- Alert players about the spill
            for _, player in pairs(game.connected_players) do
                if player.force == (base and base.force or cargo_pod.force) then
                    player.add_alert(base or cargo_pod, defines.alert_type.no_platform_storage)
                end
            end
        else
            -- Alert players about canisters lost in space
            for _, player in pairs(game.connected_players) do
                if player.force == (base and base.force or cargo_pod.force) then
                    player.add_custom_alert(
                        base or cargo_pod,
                        { type = "virtual", name = "canisters-void-alert" },
                        remaining .. " canisters were ejected into space!",
                        true
                    )
                end
            end
        end
    end

    -- Cleanup: Remove processed cargo pod from storage
    storage.rocket_cargo_pods[unit_number] = nil
end

--- Cleans up old storage entries when the mod configuration changes.
local function cleanup_old_entries()
    local current_tick = game.tick
    local expired_time = 3600 -- 60 seconds (3600 ticks)

    for unit_number, pod_data in pairs(storage.rocket_cargo_pods) do
        if current_tick - pod_data.tick >= expired_time then
            storage.rocket_cargo_pods[unit_number] = nil
        end
    end
end

--- Registers event handlers for rocket launches and cargo pod deliveries.
local function register_events()
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_on_cargo_pod_delivered_cargo)
    script.on_event(defines.events.on_rocket_launch_ordered, handle_on_rocket_launch_ordered)
end

--- Initializes the mod and ensures storage is set up properly.
script.on_init(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    register_events()
end)

--- Runs cleanup and re-registers events when mod settings are updated.
script.on_configuration_changed(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    cleanup_old_entries() -- Only run cleanup when configuration changes
    register_events()
end)

--- Ensures event handlers are registered when the game is loaded.
script.on_load(register_events)
