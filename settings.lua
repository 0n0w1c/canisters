local metals = { "steel" }
local hidden = true

if mods["bztin"] then
    table.insert(metals, "tin")
    hidden = false
end

if mods["bztitanium"] then
    table.insert(metals, "titanium")
    hidden = false
end

data:extend({
    {
        type = "bool-setting",
        name = "canisters-reuseable-canisters",
        setting_type = "startup",
        default_value = true,
        order = "a"
    },
    {
        type = "bool-setting",
        name = "canisters-spill-canisters",
        setting_type = "startup",
        default_value = true,
        order = "b"
    },
    {
        type = "string-setting",
        name = "canisters-canister-metal",
        setting_type = "startup",
        default_value = "steel",
        allowed_values = metals,
        hidden = hidden,
        order = "c"
    }
})
