local metal = string.lower(tostring(settings.startup["canisters-canister-metal"].value))

local recycling = {}
if mods["quality"] then recycling = require("__quality__/prototypes/recycling") end

local recipe = data.raw["recipe"]["canister"]
if metal == "tin" then
    recipe.ingredients = { { type = "item", name = metal .. "-plate", amount = 5 } }
elseif metal == "titanium" then
    recipe.ingredients = { { type = "item", name = metal .. "-plate", amount = 1 } }
end

if data.raw["item"]["glass-plate"] then
    table.insert(recipe.ingredients, { type = "item", name = "glass-plate", amount = 1 })
elseif data.raw["item"]["glass"] then
    table.insert(recipe.ingredients, { type = "item", name = "glass", amount = 1 })
end

if mods["quality"] then recycling.generate_recycling_recipe(recipe) end
