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
})
