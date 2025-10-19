local name = "canister"
local item = table.deepcopy(data.raw["item"]["barrel"])
local recipe = table.deepcopy(data.raw["recipe"]["barrel"])

local minimum_result = tonumber(settings.startup["canisters-minimum-result"].value)

item.name = name
item.icon = "__canisters__/graphics/icon/" .. name .. ".png"
item.stack_size = 100
item.weight = 1000

recipe.name = name
recipe.main_product = name
recipe.auto_recycle = false
recipe.results = { { type = "item", name = name, amount = 1 } }

data.extend({ item, recipe })

local technology = data.raw["technology"]["rocket-fuel"]
if technology then
    table.insert(technology.effects, { type = "unlock-recipe", recipe = "canister" })
else
    data.raw["recipe"]["canister"].enabled = true
end

if DISPOSABLE then return end

local used_name = name .. "-black"
item = table.deepcopy(data.raw["item"]["barrel"])
item.name = used_name
item.icon = "__canisters__/graphics/icon/" .. used_name .. ".png"
item.stack_size = 100
item.weight = 1000

local refurbishing_recipe = {}
refurbishing_recipe.type = "recipe"
refurbishing_recipe.name = name .. "-refurbishing"
refurbishing_recipe.icon = "__canisters__/graphics/icon/" .. used_name .. ".png"
refurbishing_recipe.category = "crafting-with-fluid"
refurbishing_recipe.auto_recycle = false
refurbishing_recipe.allow_as_intermediate = false
refurbishing_recipe.show_amount_in_title = false
refurbishing_recipe.allow_decomposition = true
refurbishing_recipe.allow_productivity = false
refurbishing_recipe.allow_quality = false
refurbishing_recipe.enabled = false
refurbishing_recipe.energy_required = 5

refurbishing_recipe.ingredients =
{
    { type = "item",  name = used_name,     amount = 10 },
    { type = "item",  name = "repair-pack", amount = 1 },
    { type = "fluid", name = "steam",       amount = 100 },
}

refurbishing_recipe.results =
{
    { type = "item", name = name, amount_min = minimum_result, amount_max = 10 }
}

data.extend({ item, refurbishing_recipe })

technology = data.raw["technology"]["rocket-fuel"]
if technology then
    table.insert(technology.effects, { type = "unlock-recipe", recipe = "canister-refurbishing" })
else
    data.raw["recipe"]["canister-refurbishing"].enabled = true
end
