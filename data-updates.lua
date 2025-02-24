local reuseable = settings.startup["canisters-reuseable-canisters"].value

local recipe = data.raw["recipe"]["canister"]
if recipe then
    -- update rocket-fuel techology effects to unlock the canister recipe
    table.insert(data.raw["technology"]["rocket-fuel"].effects, { type = "unlock-recipe", recipe = "canister" })

    -- conditionally set fuels to return canisters when burnt
    if reuseable then
        data.raw["item"]["rocket-fuel"].burnt_result = "canister"
        data.raw["item"]["nuclear-fuel"].burnt_result = "canister"
        data.raw["item"]["plutonium-fuel"].burnt_result = "canister"
    end
end
