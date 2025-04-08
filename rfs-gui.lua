local EXCLUDED_SURFACES =
{
    ["minime_dummy_dungeon"] = true
}

function build_rocket_fuel_settings_gui(player, selected_surface_name, preset)
    preset = preset or {}

    if not selected_surface_name or not game.surfaces[selected_surface_name] then
        selected_surface_name = player.surface.name
    end

    storage.rfs_surface_settings = storage.rfs_surface_settings or {}
    local saved = selected_surface_name and storage.rfs_surface_settings[selected_surface_name] or {}

    local use_custom = preset.use_custom or saved.use_custom or false
    local use_cached = preset.use_cached or saved.use_cached or (not use_custom)
    local selected_surface = game.surfaces[selected_surface_name]
    local custom_value = tonumber(preset.custom_value or saved.custom_value)
        or math.floor(get_surface_rocket_fuel_productivity(selected_surface, player.force) * 100 + 0.5)

    if use_cached then
        custom_value = math.floor(get_surface_rocket_fuel_productivity(selected_surface, player.force) * 100 + 0.5)
    end

    local cache_duration = preset.cache_duration or saved.cache_duration or "1"

    local gui_root = player.gui.screen

    if gui_root.rocket_fuel_settings_frame then
        gui_root.rocket_fuel_settings_frame.destroy()
    end

    local frame = gui_root.add
        {
            type = "frame",
            name = "rocket_fuel_settings_frame",
            direction = "vertical",
        }
    frame.auto_center = true

    local titlebar = frame.add
        {
            type = "flow",
            direction = "horizontal",
            name = "rfs_titlebar",
            drag_target = frame,
        }

    titlebar.add
    {
        type = "label",
        caption = { "", "[item=rocket-fuel] [item=productivity-module-3]" },
        style = "frame_title",
        ignored_by_interaction = true
    }

    local spacer = titlebar.add
        {
            type = "empty-widget",
            style = "draggable_space_header"
        }
    spacer.style.horizontally_stretchable = true
    spacer.style.height = 24
    spacer.drag_target = frame

    titlebar.add
    {
        type = "sprite-button",
        name = "rfs_close_button",
        sprite = "utility/close",
        style = "close_button",
        mouse_button_filter = { "left" }
    }

    local surface_names = {}
    for _, surface in pairs(game.surfaces) do
        if surface.planet and not EXCLUDED_SURFACES[surface.name] then
            table.insert(surface_names, surface.name)
        end
    end

    local selected_index = 1
    for i, name in ipairs(surface_names) do
        if name == selected_surface_name then
            selected_index = i
            break
        end
    end

    frame.add
    {
        type = "drop-down",
        name = "rfs_surface_selector",
        items = surface_names,
        selected_index = selected_index
    }

    local settings_frame = frame.add
        {
            type = "frame",
            name = "rfs_settings_frame",
            direction = "vertical",
            style = "inside_shallow_frame_with_padding"
        }

    local custom_row = settings_frame.add { type = "flow", direction = "horizontal" }
    custom_row.style.horizontally_stretchable = true
    custom_row.style.vertical_align = "center"

    local custom_left = custom_row.add { type = "flow", direction = "horizontal" }
    custom_left.style.horizontally_stretchable = true
    custom_left.style.horizontally_squashable = true
    custom_left.style.vertical_align = "center"

    custom_left.add
    {
        type = "checkbox",
        name = "rfs_use_custom",
        state = use_custom
    }
    custom_left.add
    {
        type = "label",
        caption = "Assigned: per building bonus %"
    }

    local custom_right = custom_row.add { type = "flow", direction = "horizontal" }
    custom_right.style.horizontally_stretchable = true
    custom_right.style.horizontal_align = "right"
    custom_right.style.vertical_align = "center"

    local custom_value_options = {}
    for i = 0, 190 do
        table.insert(custom_value_options, tostring(i))
    end

    local selected_custom_index = 1
    for index, value in ipairs(custom_value_options) do
        if value == tostring(custom_value) then
            selected_custom_index = index
            break
        end
    end

    local custom_value_dropdown = custom_right.add
        {
            type = "drop-down",
            name = "rfs_custom_value",
            items = custom_value_options,
            selected_index = selected_custom_index,
            tooltip = { "tooltip.rfs_custom_value" }
        }
    custom_value_dropdown.style.width = 80
    custom_value_dropdown.style.horizontal_align = "right"

    local cached_row = settings_frame.add { type = "flow", direction = "horizontal" }
    cached_row.style.horizontally_stretchable = true
    cached_row.style.vertical_align = "center"

    local cached_left = cached_row.add { type = "flow", direction = "horizontal" }
    cached_left.style.horizontally_stretchable = true
    cached_left.style.horizontally_squashable = true
    cached_left.style.vertical_align = "center"

    cached_left.add
    {
        type = "checkbox",
        name = "rfs_use_cached",
        state = use_cached
    }
    cached_left.add
    {
        type = "label",
        caption = "Calculated: cache life in minutes"
    }

    local cached_right = cached_row.add { type = "flow", direction = "horizontal" }
    cached_right.style.horizontally_stretchable = true
    cached_right.style.horizontal_align = "right"
    cached_right.style.vertical_align = "center"

    local duration_options = {}
    for i = 1, 10 do
        table.insert(duration_options, tostring(i))
    end

    local selected_tick_index = 1
    for i, val in ipairs(duration_options) do
        if val == tostring(cache_duration) then
            selected_tick_index = i
            break
        end
    end

    local cache_duration_dropdown = cached_right.add
        {
            type = "drop-down",
            name = "rfs_cache_duration",
            items = duration_options,
            selected_index = selected_tick_index,
            tooltip = { "tooltip.rfs_cache_duration" }
        }
    cache_duration_dropdown.style.width = 80
    cache_duration_dropdown.style.horizontal_align = "right"

    player.opened = frame
end

return build_rocket_fuel_settings_gui
