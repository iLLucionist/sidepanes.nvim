--[[
sidepanes.version
Purpose: Expose lightweight Sidepanes version and load-path facts.
Does: Keeps the release version string and derives the plugin root from this module source without shelling out.
Architecture: Pure helpers with no Neovim API calls; command/API adapters decide how to display the data.
]]

local M = {}

M.VERSION = "0.4.0-dev"

local module_suffix = "/lua/sidepanes/version.lua"

local function source_path(source)
    source = source or debug.getinfo(1, "S").source or ""

    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    return source:gsub("\\", "/")
end

local function plugin_root(source)
    local path = source_path(source)

    if path:sub(-#module_suffix) == module_suffix then
        return path:sub(1, #path - #module_suffix)
    end

    return path
end

function M.info(opts)
    opts = opts or {}

    return {
        version = opts.version or M.VERSION,
        load_path = opts.load_path or plugin_root(opts.source),
    }
end

function M.lines(info)
    info = info or M.info()

    return {
        "Sidepanes version: " .. tostring(info.version or ""),
        "Load path: " .. tostring(info.load_path or ""),
    }
end

return M
