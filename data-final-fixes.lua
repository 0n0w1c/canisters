local recycling = {}
if mods["quality"] then recycling = require("__quality__/prototypes/recycling") end

-- dynamically update rocket fuel recipes
-- contribution from Zwikkry
local recipes = data.raw["recipe"]
for _, check_recipe in pairs(recipes) do
    if check_recipe.name and check_recipe.results and check_recipe.ingredients then
        for _, result in pairs(check_recipe.results) do
            if result.name and result.name:match("rocket%-fuel") and not check_recipe.name:match("recycling") then
                local has_canister = false
                for _, ingredient in pairs(check_recipe.ingredients) do
                    if ingredient.name and ingredient.name:match("canister") then
                        has_canister = true
                        break
                    end
                end
                if not has_canister then
                    table.insert(check_recipe.ingredients, { type = "item", name = "canister", amount = 1 })

                    if mods["quality"] then recycling.generate_recycling_recipe(check_recipe) end
                end
            end
        end
    end
end
