data:extend({
    {
        type = "shortcut",
        name = "rfs-shortcut",
        localised_name = { "", "[item=rocket-fuel] [item=productivity-module-3]" },
        order = "a[rocket]-b[fuel-productivity]",
        action = "lua",
        toggleable = false,
        icon = "__base__/graphics/icons/rocket-fuel.png",
        icon_size = 64,
        small_icon = "__base__/graphics/icons/rocket-fuel.png",
        small_icon_size = 64,
        associated_control_input = "give-rfs-toggle-gui"
    }
})

require("prototypes.entity.canister")
