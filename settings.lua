local metals = { "Steel" }
local hidden = true

if mods["bztin"] then
    table.insert(metals, "Tin")
    hidden = false
end

if mods["bztitanium"] then
    table.insert(metals, "Titanium")
    hidden = false
end

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
        hidden = hidden,
        order = "b"
    }
})
