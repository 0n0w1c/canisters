local reuseable = settings.startup["canisters-reuseable-canisters"].value
local spill = settings.startup["canisters-spill-canisters"].value
local metal = settings.startup["canisters-canister-metal"].value

local function handle_cargo_pod_delivery(event)
    if not reuseable then return end

    local cargo_pod = event.cargo_pod
    local platform_hub = cargo_pod.surface.find_entity("space-platform-hub", cargo_pod.position)

    if platform_hub and platform_hub.valid then
        local inventory = platform_hub.get_inventory(defines.inventory.chest)

        local count = 50
        if metal == "tin" then
            local rng = game.create_random_generator()
            count = rng(count - 5, count)
        end

        local inserted = inventory and inventory.valid and inventory.insert({ name = "canister", count = count }) or 0

        count = count - inserted

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
    end
end

-- Register event handlers
local function register_events()
    script.on_event(defines.events.on_cargo_pod_delivered_cargo, handle_cargo_pod_delivery)
end

-- Runs when the mod is first loaded
script.on_init(function()
    register_events()
end)

-- Runs when the mod is updated or settings change
script.on_configuration_changed(function()
    register_events()
end)

-- Runs when the game is loaded from a save
script.on_load(function()
    register_events()
end)
