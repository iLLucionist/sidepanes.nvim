--[[
sidepanes.util
Purpose: Provide small shared helpers used throughout the sidepanes plugin.
Does: Normalizes paths and roots, validates buffers/windows/jobs, builds terminal commands/keys, and formats safe labels/fences.
Architecture: Low-level utility module with no pane ownership; higher-level modules depend on it for common Neovim and filesystem operations.
]]

local M = {}

--- Trim leading and trailing whitespace from text.
function M.trim(text)
    return (text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

--- Return whether a Neovim window id is still valid.
function M.valid_win(winid)
    return winid and vim.api.nvim_win_is_valid(winid)
end

--- Return whether a Neovim buffer id is still valid.
function M.valid_buf(bufnr)
    return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

--- Return whether a job id still represents a running job.
function M.is_running(job_id)
    return job_id and vim.fn.jobwait({ job_id }, 0)[1] == -1
end

--- Return the OS pid for a Neovim job id when available.
function M.job_pid(job_id)
    if not job_id then
        return nil
    end

    local ok, pid = pcall(vim.fn.jobpid, job_id)

    if ok and type(pid) == "number" and pid > 0 then
        return pid
    end

    return nil
end

--- Return whether an OS process id appears to still be alive.
function M.pid_running(pid)
    pid = tonumber(pid)

    if not pid or pid <= 0 then
        return false
    end

    local uv = vim.uv or vim.loop

    if not (uv and uv.kill) then
        return false
    end

    local ok, result = pcall(uv.kill, pid, 0)

    return ok and result == 0
end

--- Expand a path-like value into an absolute path.
function M.resolve_path(path)
    if not path or path == "" then
        return nil
    end

    local expanded = vim.fn.expand(path)

    if expanded == "" then
        expanded = path
    end

    return vim.fn.fnamemodify(expanded, ":p")
end

--- Normalize a project root and collapse accidental .git roots to the worktree.
function M.normalize_project_root(root)
    root = vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p")
    local trimmed = root:gsub("/$", "")

    root = vim.fn.resolve(trimmed)

    if vim.fn.fnamemodify(root:gsub("/$", ""), ":t") == ".git" then
        return vim.fn.fnamemodify(root, ":h:h:p")
    end

    return vim.fn.fnamemodify(root, ":p")
end

local function project_options(config)
    config = config or {}

    return {
        markers = config.project_root_markers == nil and { ".git" } or config.project_root_markers,
        fallback = config.project_root_fallback == nil and "buffer_dir" or config.project_root_fallback,
        resolver = config.project_root_resolver,
    }
end

local function fallback_root(start, fallback)
    if fallback == "cwd" then
        return M.normalize_project_root(vim.fn.getcwd())
    end

    return M.normalize_project_root(start)
end

local function root_from_resolver(source, kind, config)
    local opts = project_options(config)

    if type(opts.resolver) ~= "function" then
        return nil
    end

    local ok, root = pcall(opts.resolver, source, {
        kind = kind,
        markers = opts.markers,
        fallback = opts.fallback,
    })

    if ok and type(root) == "string" and root ~= "" then
        return M.normalize_project_root(root)
    end

    return nil
end

local function simple_marker_names(markers)
    if type(markers) == "string" then
        return { markers }
    elseif type(markers) ~= "table" then
        return {}
    end

    local result = {}

    for _, marker in ipairs(markers) do
        if type(marker) == "string" then
            table.insert(result, marker)
        end
    end

    return result
end

local function root_from_marker_path(path)
    if not path or path == "" then
        return nil
    end

    path = path:gsub("/+$", "")

    return M.normalize_project_root(vim.fn.fnamemodify(path, ":h")):gsub("/$", "")
end

--- Resolve the project root for a buffer using Git as the primary marker.
function M.project_root(bufnr, config)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    local resolved = root_from_resolver(bufnr, "buffer", config)

    if resolved then
        return resolved
    end

    local opts = project_options(config)

    if opts.markers ~= false and vim.fs and vim.fs.root then
        local ok, root = pcall(vim.fs.root, bufnr, opts.markers)

        if ok and root then
            return M.normalize_project_root(root)
        end
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    local start = name ~= "" and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()
    local marker_names = simple_marker_names(opts.markers)

    if #marker_names > 0 and vim.fs and vim.fs.find then
        local found = vim.fs.find(marker_names, { path = start, upward = true })[1]
        local root = root_from_marker_path(found)

        if root then
            return root
        end
    end

    return fallback_root(start, opts.fallback)
end

--- Resolve the project root for a filesystem path.
function M.project_root_for_path(path, config)
    if not path or path == "" then
        return M.project_root(nil, config)
    end

    local resolved = root_from_resolver(path, "path", config)

    if resolved then
        return resolved
    end

    local start = vim.fn.fnamemodify(path, ":p:h")
    local opts = project_options(config)
    local marker_names = simple_marker_names(opts.markers)

    if #marker_names > 0 and vim.fs and vim.fs.find then
        local found = vim.fs.find(marker_names, { path = start, upward = true })[1]
        local root = root_from_marker_path(found)

        if root then
            return root
        end
    end

    if opts.markers ~= false and #marker_names == 0 and vim.fs and vim.fs.root then
        local ok, root = pcall(vim.fs.root, path, opts.markers)

        if ok and root then
            return M.normalize_project_root(root)
        end
    end

    return fallback_root(start, opts.fallback)
end

--- Format a path relative to a root when possible.
function M.relative_path(path, root)
    if not path or path == "" then
        return "[No file name]"
    end

    path = vim.fn.fnamemodify(path, ":p")
    root = root and vim.fn.fnamemodify(root, ":p") or nil

    if root and vim.startswith(path, root) then
        return path:sub(#root + 1)
    end

    return vim.fn.fnamemodify(path, ":.")
end

--- Return a compact display label for a project root.
function M.root_label(root)
    local normalized = vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p"):gsub("/$", "")

    return vim.fn.fnamemodify(normalized, ":t")
end

--- Build the stable key used to identify one pane terminal session.
function M.terminal_key(tool_name, root)
    local normalized = M.normalize_project_root(root or vim.fn.getcwd()):gsub("/$", "")

    return table.concat({
        tool_name,
        normalized,
    }, "::")
end

--- Sanitize arbitrary text so it can safely appear in a buffer name.
function M.sanitize_name(text)
    return (text or ""):gsub("[^%w_.-]", "_")
end

--- Build the command argv for a configured tool and preset.
function M.command_list(tool, preset, root)
    local cmd = tool.cmd or tool.command

    if type(cmd) == "function" then
        cmd = cmd(root, preset, tool)
    end

    local result = type(cmd) == "table" and vim.deepcopy(cmd) or { cmd }

    if tool.include_cd_arg then
        vim.list_extend(result, { "--cd", root })
    end

    vim.list_extend(result, vim.deepcopy(tool.args or {}))
    vim.list_extend(result, vim.deepcopy(preset.args or {}))

    return result
end

--- Return whether an executable command is available on PATH.
function M.executable_exists(cmd)
    return cmd and cmd ~= "" and (cmd:find("/") or vim.fn.executable(cmd) == 1)
end

--- Choose a Markdown code fence marker that does not conflict with text.
function M.fence_for(text)
    local fence = "```"

    while (text or ""):find(fence, 1, true) do
        fence = fence .. "`"
    end

    return fence
end

return M
