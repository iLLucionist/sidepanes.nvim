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

    if vim.fn.fnamemodify(root:gsub("/$", ""), ":t") == ".git" then
        return vim.fn.fnamemodify(root, ":h:h:p")
    end

    return root
end

--- Resolve the project root for a buffer using Git as the primary marker.
function M.project_root(bufnr)
    bufnr = bufnr or vim.api.nvim_get_current_buf()

    if vim.fs and vim.fs.root then
        local ok, root = pcall(vim.fs.root, bufnr, { ".git" })

        if ok and root then
            return M.normalize_project_root(root)
        end
    end

    local name = vim.api.nvim_buf_get_name(bufnr)
    local start = name ~= "" and vim.fn.fnamemodify(name, ":p:h") or vim.fn.getcwd()

    if vim.fs and vim.fs.find then
        local found = vim.fs.find(".git", { path = start, upward = true })[1]

        if found then
            return M.normalize_project_root(found)
        end
    end

    return M.normalize_project_root(start)
end

--- Resolve the project root for a filesystem path.
function M.project_root_for_path(path)
    if not path or path == "" then
        return M.project_root()
    end

    local start = vim.fn.fnamemodify(path, ":p:h")

    if vim.fs and vim.fs.find then
        local found = vim.fs.find(".git", { path = start, upward = true })[1]

        if found then
            return M.normalize_project_root(found)
        end
    end

    return M.normalize_project_root(start)
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
    return table.concat({
        tool_name,
        vim.fn.fnamemodify(root or vim.fn.getcwd(), ":p"),
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
