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
    },
    {
        type = "int-setting",
        name = "canisters-minimum-result",
        setting_type = "startup",
        default_value = 5,
        minimum_value = 0,
        maximum_value = 10,
        allowed_values = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 },
        order = "c"
    }
})
