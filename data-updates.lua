local reuseable = settings.startup["canisters-reuseable-canisters"].value

local recycling = {}
if mods["quality"] then recycling = require("__quality__/prototypes/recycling") end

local recipe = data.raw["recipe"]["canister"]
if recipe then
    if data.raw["item"]["tin-plate"] then
        recipe.ingredients = { { type = "item", name = "tin-plate", amount = 1 } }
    end

    if data.raw["item"]["titanium-plate"] then
        recipe.ingredients = { { type = "item", name = "titanium-plate", amount = 1 } }
    end

    if data.raw["item"]["glass-plate"] then
        table.insert(recipe.ingredients, { type = "item", name = "glass-plate", amount = 1 })
    end

    if mods["quality"] then recycling.generate_recycling_recipe(recipe) end

    table.insert(data.raw["technology"]["rocket-fuel"].effects, { type = "unlock-recipe", recipe = "canister" })

    if reuseable then
        data.raw["item"]["rocket-fuel"].burnt_result = "canister"
        data.raw["item"]["nuclear-fuel"].burnt_result = "canister"
        if mods["PlutoniumEnergy"] then data.raw["item"]["plutonium-fuel"].burnt_result = "canister" end
    end
end
