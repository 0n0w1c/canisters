DISPOSABLE = settings.startup["canisters-disposable"].value

require("prototypes.entity.canister")

if not DISPOSABLE then
    data:extend({
        {
            type = "shortcut",
            name = "rfs-shortcut",
            localised_name = { "shortcut-name.rfs-shortcut" },
            order = "a[rocket]-b[fuel-productivity]",
            action = "lua",
            toggleable = false,
            icons =
            {
                {
                    icon = "__base__/graphics/icons/rocket-fuel.png",
                    icon_size = 64,
                    scale = 0.5,
                    shift = { -8, -8 }
                },
                {
                    icon = "__base__/graphics/icons/productivity-module-3.png",
                    icon_size = 64,
                    scale = 0.5,
                    shift = { 8, 8 }
                }
            },
            small_icons =
            {
                {
                    icon = "__base__/graphics/icons/rocket-fuel.png",
                    icon_size = 64,
                    scale = 0.5,
                    shift = { -4, -4 }
                },
                {
                    icon = "__base__/graphics/icons/productivity-module-3.png",
                    icon_size = 64,
                    scale = 0.5,
                    shift = { 4, 4 }
                }
            },
            associated_control_input = "give-rfs-toggle-gui"
        }
    })
end
