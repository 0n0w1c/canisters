local metals = { "Steel" }
if mods["bztin"] then table.insert(metals, "Tin") end
if mods["bztitanium"] then table.insert(metals, "Titanium") end

data:extend({
    {
        type = "bool-setting",
        name = "canisters-reusable-canisters",
        setting_type = "startup",
        default_value = true,
        order = "a"
    },
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
        allowed_values = { 0, 10, 50, 100 },
        order = "c"
    }
})
