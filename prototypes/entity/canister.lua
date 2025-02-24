local name = "canister"
local item = table.deepcopy(data.raw["item"]["barrel"])
local recipe = table.deepcopy(data.raw["recipe"]["barrel"])

item.name = name
item.icon = "__canisters__/graphics/icon/" .. name .. ".png"
item.stack_size = 100
item.weight = 1000

recipe.name = name
recipe.results = { { type = "item", name = name, amount = 1 } }

data.extend({ item, recipe })
