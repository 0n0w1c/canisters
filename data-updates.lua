local recipe = data.raw["recipe"]["canister"]
local metal = string.lower(tostring(settings.startup["canisters-canister-metal"].value))
local disposable = settings.startup["canisters-disposable"].value == true

local recycling = {}
if mods["quality"] then recycling = require("__quality__/prototypes/recycling") end

if mods["bobores"] then
    if metal == "tin" then
        recipe.ingredients = { { type = "item", name = "bob-tin-plate", amount = 5 } }
    elseif metal == "titanium" then
        recipe.ingredients = { { type = "item", name = "bob-titanium-plate", amount = 1 } }
    end
else
    if metal == "tin" then
        recipe.ingredients = { { type = "item", name = metal .. "-plate", amount = 5 } }
    elseif metal == "titanium" then
        recipe.ingredients = { { type = "item", name = metal .. "-plate", amount = 1 } }
    end
end

if data.raw["item"]["glass-plate"] then
    table.insert(recipe.ingredients, { type = "item", name = "glass-plate", amount = 1 })
elseif data.raw["item"]["glass"] then
    table.insert(recipe.ingredients, { type = "item", name = "glass", amount = 1 })
elseif data.raw["item"]["bob-glass"] then
    table.insert(recipe.ingredients, { type = "item", name = "bob-glass", amount = 1 })
end

if mods["quality"] then recycling.generate_recycling_recipe(recipe) end

if not disposable then
    data.raw["item"]["rocket-fuel"].burnt_result = "canister-black"
    data.raw["item"]["nuclear-fuel"].burnt_result = "canister-black"
    if data.raw["item"]["plutonium-fuel"] then data.raw["item"]["plutonium-fuel"].burnt_result = "canister-black" end

    for _, prototype_group in pairs(data.raw) do
        for _, prototype in pairs(prototype_group) do
            local energy_source = prototype and prototype.energy_source
            if energy_source and energy_source.type == "burner" then
                local uses_chemical = false
                if energy_source.fuel_categories then
                    for _, category in pairs(energy_source.fuel_categories) do
                        if category == "chemical" then
                            uses_chemical = true
                            break
                        end
                    end
                end

                if uses_chemical and energy_source.fuel_inventory_size and energy_source.fuel_inventory_size > 0 then
                    energy_source.burnt_inventory_size = energy_source.fuel_inventory_size
                end
            end
        end
    end
end
