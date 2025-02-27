local reuseable = settings.startup["canisters-reuseable-canisters"].value
local metal = settings.startup["canisters-canister-metal"].value

local recycling = {}
if mods["quality"] then recycling = require("__quality__/prototypes/recycling") end

local recipe = data.raw["recipe"]["canister"]
if recipe then
    if metal == "tin" then
        --if data.raw["item"]["tin-plate"] then -- bztin
        recipe.ingredients = { { type = "item", name = "tin-plate", amount = 2 } }
    elseif metal == "titanium" then
        --if data.raw["item"]["titanium-plate"] then -- bztitanium
        recipe.ingredients = { { type = "item", name = "titanium-plate", amount = 1 } }
    end

    if data.raw["item"]["glass-plate"] then -- Glass
        table.insert(recipe.ingredients, { type = "item", name = "glass-plate", amount = 1 })
    end

    if mods["quality"] then recycling.generate_recycling_recipe(recipe) end

    local rocket_fuel_recipe = data.raw["recipe"]["rocket-fuel"]
    if rocket_fuel_recipe then
        table.insert(rocket_fuel_recipe.ingredients, { type = "item", name = "canister", amount = 1 })
        if mods["quality"] then recycling.generate_recycling_recipe(rocket_fuel_recipe) end
    end

    table.insert(data.raw["technology"]["rocket-fuel"].effects, { type = "unlock-recipe", recipe = "canister" })

    if reuseable then
        data.raw["item"]["rocket-fuel"].burnt_result = "canister"
        data.raw["item"]["nuclear-fuel"].burnt_result = "canister"
        if data.raw["item"]["plutonium-fuel"] then data.raw["item"]["plutonium-fuel"].burnt_result = "canister" end
    end
end
