--[[
sidepanes.dependencies
Purpose: Centralize optional dependency checks for Sidepanes features.
Does: Describes feature dependencies, checks Lua modules and Treesitter parsers, and emits clear runtime missing-dependency messages.
Architecture: Shared by runtime feature modules, setup validation, and health checks without owning plugin state.
]]

local M = {}

M.features = {
    document_picker = {
        label = "document picker",
        modules = {
            { name = "telescope", label = "telescope.nvim" },
        },
    },
    heading_picker = {
        label = "markdown headings",
        modules = {
            { name = "telescope", label = "telescope.nvim" },
        },
        parsers = {
            { name = "markdown", label = "Treesitter markdown parser" },
        },
    },
    markview = {
        label = "markdown rendering",
        modules = {
            { name = "markview", label = "markview" },
        },
    },
}

--- Return whether a Lua module can be required.
function M.has_module(name)
    return pcall(require, name)
end

--- Return whether a Treesitter parser can be created for a language.
function M.has_parser(lang, bufnr)
    local probe_bufnr = bufnr
    local created = false

    if not probe_bufnr or not vim.api.nvim_buf_is_valid(probe_bufnr) then
        probe_bufnr = vim.api.nvim_create_buf(false, true)
        created = true
    end

    local ok, parser = pcall(vim.treesitter.get_parser, probe_bufnr, lang)

    if created then
        pcall(vim.api.nvim_buf_delete, probe_bufnr, { force = true })
    end

    return ok and parser ~= nil
end

--- Return missing dependency descriptions for a feature.
function M.missing(feature_name, opts)
    opts = opts or {}

    local feature = M.features[feature_name]
    local missing = {}

    if not feature then
        return missing
    end

    for _, module in ipairs(feature.modules or {}) do
        if not M.has_module(module.name) then
            table.insert(missing, module.label)
        end
    end

    for _, parser in ipairs(feature.parsers or {}) do
        if not M.has_parser(parser.name, opts.bufnr) then
            table.insert(missing, parser.label)
        end
    end

    return missing
end

--- Return whether all dependencies for a feature are available.
function M.available(feature_name, opts)
    return #M.missing(feature_name, opts) == 0
end

--- Notify the user that a feature cannot run because dependencies are missing.
function M.notify_missing(feature_name, opts)
    local feature = M.features[feature_name] or { label = feature_name }
    local missing = M.missing(feature_name, opts)

    if #missing == 0 then
        return false
    end

    vim.notify(
        "Sidepanes dependency missing for " .. feature.label .. ": " .. table.concat(missing, ", "),
        vim.log.levels.WARN
    )

    return true
end

return M
