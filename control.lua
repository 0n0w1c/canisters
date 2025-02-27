-- Ensure the storage table exists
storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}

local function handle_on_rocket_launched(event)
    local silo = event.rocket_silo
    local rocket = event.rocket

    -- Ensure storage exists
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}

    -- Ensure the rocket and silo are valid
    if not (silo and silo.valid) then
        game.print("⚠ Warning: Rocket launch event received but silo is missing or invalid.")
        return
    end

    if not (rocket and rocket.valid and rocket.unit_number) then
        game.print("⚠ Warning: Rocket launch event received but rocket is missing or invalid.")
        return
    end

    local productivity = silo.productivity_bonus or 0
    local base_fuel = space_age and 50 or 100

    -- Ensure divisor is valid
    local divisor = 1 + productivity
    if divisor <= 0 then divisor = 1 end

    -- Compute fuel used and round to nearest integer
    local fuel_used = math.floor((base_fuel / divisor) + 0.5)

    -- Store the rocket launch info in storage
    storage.rocket_cargo_pods[rocket.unit_number] = {
        silo_productivity = productivity,
        fuel_used = fuel_used
    }

    game.print("🚀 Rocket launched! Rocket ID: " .. rocket.unit_number)
    game.print("Tracking for cargo pod assignment.")
end


local function handle_on_cargo_pod_finished_ascending(event)
    local cargo_pod = event.cargo_pod
    if cargo_pod and cargo_pod.valid then
        -- Get the rocket attached to this cargo pod
        local rocket = cargo_pod.ascending_rocket

        if rocket and rocket.valid and storage.rocket_cargo_pods[rocket.unit_number] then
            -- Transfer data from the rocket to the cargo pod
            local pod_unit_number = cargo_pod.unit_number
            storage.rocket_cargo_pods[pod_unit_number] = storage.rocket_cargo_pods[rocket.unit_number]

            -- Remove the old rocket entry
            storage.rocket_cargo_pods[rocket.unit_number] = nil

            game.print("✅ Cargo pod " .. pod_unit_number .. " is now assigned and tracked.")
        else
            game.print("⚠ Warning: No rocket data found for cargo pod " .. cargo_pod.unit_number)
        end
    end
end

local function handle_cargo_pod_delivery(event)
    if not reuseable then return end

    local cargo_pod = event.cargo_pod
    local platform_hub = cargo_pod.surface.find_entity("space-platform-hub", cargo_pod.position)

    -- Ensure storage.rocket_cargo_pods is not nil
    if not storage.rocket_cargo_pods then
        storage.rocket_cargo_pods = {} -- Initialize if missing
    end

    -- Get the cargo pod's unit number
    local pod_unit_number = cargo_pod.unit_number
    local pod_data = storage.rocket_cargo_pods[pod_unit_number]

    if not pod_data then
        game.print("⚠ Warning: No stored data for cargo pod " .. pod_unit_number)
        return
    end

    local base_canisters = space_age and 50 or 100
    local productivity = pod_data.silo_productivity or 0

    -- Calculate the correct number of canisters to return
    local count = math.floor((base_canisters / (1 + productivity)) + 0.5)

    -- Adjust count based on metal type
    if metal == "Tin" then
        local rng = game.create_random_generator()
        count = rng(count - 5, count)
    end

    -- Insert canisters into platform hub
    local inventory = platform_hub and platform_hub.valid and platform_hub.get_inventory(defines.inventory.chest)
    local inserted = inventory and inventory.insert({ name = "canister", count = count }) or 0
    count = count - inserted -- Remaining canisters after insertion

    if count > 0 then
        if spill then
            -- Spill remaining canisters onto the platform
            cargo_pod.surface.spill_item_stack({
                position = platform_hub.position,
                stack = { name = "canister", count = count }
            })

            -- Find all items on the platform surface
            local spilled_items = cargo_pod.surface.find_entities_filtered { name = "item-on-ground" }

            -- Mark all canisters for deconstruction
            for _, entity in pairs(spilled_items) do
                if entity.valid and entity.stack and entity.stack.name == "canister" then
                    entity.order_deconstruction(platform_hub.force)
                end
            end

            -- Trigger no_platform_storage alert for spilled canisters (only for same force)
            for _, player in pairs(game.connected_players) do
                if player.force == platform_hub.force then
                    player.add_alert(platform_hub, defines.alert_type.no_platform_storage)
                end
            end
        else
            -- Trigger a void alert (only for same force)
            for _, player in pairs(game.connected_players) do
                if player.force == platform_hub.force then
                    player.add_custom_alert(
                        platform_hub,
                        { type = "virtual", name = "canisters-void-alert" },
                        count .. " canisters were ejected into space!",
                        true
                    )
                end
            end
        end
    end

    -- Cleanup: Remove the cargo pod entry after processing
    storage.rocket_cargo_pods[pod_unit_number] = nil
end

-- Register event handlers
local function register_events()
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_cargo_pod_delivery)
    script.on_event(defines.events.on_rocket_launched, handle_on_rocket_launched)
    script.on_event(defines.events.on_cargo_pod_finished_ascending, handle_on_cargo_pod_finished_ascending)
end

-- Runs when the mod is first loaded
script.on_init(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {} -- Ensure storage is initialized
    register_events()
end)

-- Runs when the mod is updated or settings change
script.on_configuration_changed(function()
    storage.rocket_cargo_pods = storage.rocket_cargo_pods or {}
    register_events()
end)

-- Runs when the game is loaded from a save
script.on_load(function()
    register_events()
end)
