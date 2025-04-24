local metals = { "Steel" }
if mods["bobores"] or mods["bztin"] then table.insert(metals, "Tin") end
if mods["bobores"] or mods["bztitanium"] then table.insert(metals, "Titanium") end

data:extend
({
    {
        type = "string-setting",
        name = "canisters-canister-metal",
        setting_type = "startup",
        default_value = "Steel",
        allowed_values = metals,
        order = "a"
    },
    {
        type = "bool-setting",
        name = "canisters-disposable",
        setting_type = "startup",
        default_value = false,
        order = "b"
    }
})
