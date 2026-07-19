--[[
sidepanes.width
Purpose: Own runtime pane-width behavior for Sidepanes.
Does: Resolves public width changes, applies them to the live pane window, refreshes Markdown rendering after width changes, handles sticky relative widths, snap points, and the width picker.
Architecture: Keeps width side effects out of init.lua while relying on dependency callbacks for window options, markdown view preservation, reflow, rendering, picker UI, and winbar updates.
]]

local api = require("sidepanes.api")
local pane_window = require("sidepanes.window")
local util = require("sidepanes.util")

local M = {}

--- Apply a resolved normal pane width and refresh markdown layout if needed.
local function apply_width(state, deps, width, opts)
    opts = opts or {}
    state.config.width = width

    if opts.relative_width and state.config.sticky_relative_width then
        state.relative_width = opts.relative_width
    elseif not opts.preserve_relative_width then
        state.relative_width = nil
    end

    if not util.valid_win(state.winid) then
        return width
    end

    if state.active_mode == "markdown" then
        deps.save_markdown_view()
    end

    pcall(vim.api.nvim_win_set_width, state.winid, pane_window.width(state))
    deps.set_window_options(state.winid, state.active_mode == "markdown" and "markdown" or "terminal")

    if state.active_mode == "markdown" and util.valid_buf(state.bufnr) then
        deps.reflow_pane_buffer(state.bufnr)
        deps.render_markview(state.bufnr)
        deps.restore_markdown_view()
    end

    deps.update_sticky_heading()

    return width
end

--- Return display text for a resolved width boundary.
local function width_boundary_label(boundary)
    if not boundary then
        return "none"
    end

    return tostring(boundary.label or boundary.value or boundary.width) .. " (" .. tostring(boundary.width) .. " cols)"
end

--- Notify the user where width snapping landed and nearby snap points.
local function notify_width_snap(state, width, point)
    local context = api.width_boundary_context(width, state.config.width_snap_points)
    local current = point and tostring(point) or (context.current and context.current.label) or tostring(width)

    vim.notify(
        "Sidepanes width: "
            .. tostring(current)
            .. " ("
            .. tostring(width)
            .. " cols); previous "
            .. width_boundary_label(context.previous)
            .. "; next "
            .. width_boundary_label(context.next),
        vim.log.levels.INFO
    )
end

--- Build picker entries for configured common width points.
local function width_picker_entries(state)
    local entries = {}
    local current_width = pane_window.width(state)

    for index, boundary in ipairs(api.width_boundaries(state.config.width_picker_points or state.config.width_snap_points, current_width)) do
        table.insert(entries, {
            index = index,
            key = tostring(index),
            value = boundary.value,
            width = boundary.width,
            relative_width = boundary.relative_width,
            current = boundary.width == current_width,
            label = tostring(boundary.label) .. "  (" .. tostring(boundary.width) .. " cols)",
        })
    end

    return entries
end

--- Return the effective normal pane width in columns.
function M.get(state)
    return pane_window.width(state)
end

--- Set the normal pane width from columns, a percentage, or a screen fraction.
function M.set(state, deps, value)
    local width, err, relative_width = api.resolve_width(value, state.config.width)

    if not width then
        vim.notify(err, vim.log.levels.ERROR)
        return nil
    end

    return apply_width(state, deps, width, { relative_width = relative_width })
end

--- Adjust the normal pane width by a column delta.
function M.adjust(state, deps, delta)
    local width, err = api.resolve_width_delta(delta, state.config.width)

    if not width then
        vim.notify(err, vim.log.levels.ERROR)
        return nil
    end

    return apply_width(state, deps, width)
end

--- Move the normal pane width to the next or previous configured snap point.
function M.snap(state, deps, direction)
    local current_width = pane_window.width(state)
    local width, err, relative_width, point = api.resolve_width_snap(current_width, direction, state.config.width_snap_points)

    if not width then
        vim.notify(err, vim.log.levels.ERROR)
        return nil
    end

    if width == current_width and not relative_width then
        notify_width_snap(state, width, point)
        return width
    end

    local applied = apply_width(state, deps, width, { relative_width = relative_width })

    notify_width_snap(state, applied, point)

    return applied
end

--- Show a picker for common pane width snap points.
function M.picker(state, deps)
    deps.numbered_select("Sidepanes width", width_picker_entries(state), function(choice)
        if not choice then
            return
        end

        local applied = apply_width(state, deps, choice.width, { relative_width = choice.relative_width })

        notify_width_snap(state, applied, choice.value)
    end)
end

--- Toggle whether relative pane widths stay tied to total Neovim columns.
function M.toggle_sticky_relative(state, enabled)
    if enabled == nil then
        enabled = not state.config.sticky_relative_width
    else
        enabled = enabled == true
    end

    state.config.sticky_relative_width = enabled

    if enabled then
        state.relative_width = api.relative_width_spec(state.config.width / vim.o.columns, "current")
    else
        state.relative_width = nil
    end

    vim.notify("Sidepanes sticky relative width " .. (enabled and "on" or "off"), vim.log.levels.INFO)

    return enabled
end

--- Recompute sticky relative width after Neovim columns change.
function M.refresh(state, deps)
    if not state.config.sticky_relative_width or not state.relative_width then
        return nil
    end

    return apply_width(state, deps, pane_window.width(state), { preserve_relative_width = true })
end

return M
