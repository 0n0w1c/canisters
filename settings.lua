local metals = { "Steel" }
if mods["bztin"] then table.insert(metals, "Tin") end
if mods["bztitanium"] then table.insert(metals, "Titanium") end

data:extend({
    {
        type = "string-setting",
        name = "canisters-canister-metal",
        setting_type = "startup",
        default_value = "Steel",
        allowed_values = metals,
        order = "b"
    },
    {
        type = "int-setting",
        name = "canisters-attrition-rate",
        setting_type = "startup",
        default_value = 10,
        minimum_value = 0,
        maximum_value = 100,
        order = "c"
    }
})
