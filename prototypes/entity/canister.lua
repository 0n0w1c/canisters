local name = "canister"
local item = table.deepcopy(data.raw["item"]["barrel"])
local recipe = table.deepcopy(data.raw["recipe"]["barrel"])

item.name = name
item.icon = "__canisters__/graphics/icon/" .. name .. ".png"
item.stack_size = 100
item.weight = 1000

recipe.name = name
recipe.results = { { type = "item", name = name, amount = 1 } }

if data.raw["item"]["tin-plate"] then
    recipe.ingredients = { { type = "item", name = "tin-plate", amount = 1 } }
end

if data.raw["item"]["titanium-plate"] then
    recipe.ingredients = { { type = "item", name = "titanium-plate", amount = 1 } }
end

if data.raw["item"]["glass-plate"] then
    table.insert(recipe.ingredients, { type = "item", name = "glass-plate", amount = 1 })
end

data.extend({ item, recipe })
