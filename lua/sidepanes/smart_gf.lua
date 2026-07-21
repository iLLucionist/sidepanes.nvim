--[[
sidepanes.smart_gf
Purpose: Resolve file targets from Sidepanes panes and open them in the best non-pane window.
Does: Cleans the target under cursor, prefers already-loaded buffers, searches nearby project files, honors line suffixes, and avoids opening results inside the Sidepanes window.
Architecture: Lives inside Sidepanes because it relies on Sidepanes runtime state such as pane buffers, terminal buffers, roots, and last focused non-pane windows.
]]

local M = {}

local function valid_buf(bufnr)
    return bufnr and vim.api.nvim_buf_is_valid(bufnr)
end

local function valid_win(winid)
    return winid and vim.api.nvim_win_is_valid(winid)
end

local function normalize_path(path)
    if not path or path == "" then
        return nil
    end

    return vim.fn.fnamemodify(path, ":p")
end

local function path_exists(path)
    return path and vim.uv.fs_stat(path) ~= nil
end

local function current_context()
    local bufnr = vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(bufnr)

    local ok, sidepanes = pcall(require, "sidepanes")
    local is_pane = false
    local terminal_ctx = nil

    local sidepanes_state = ok and sidepanes._state and sidepanes._state() or nil

    if sidepanes_state and valid_buf(sidepanes_state.bufnr) and bufnr == sidepanes_state.bufnr and sidepanes_state.source then
        path = sidepanes_state.source
        is_pane = true
    elseif sidepanes_state then
        for _, ctx in pairs(sidepanes_state.terminals or {}) do
            if valid_buf(ctx.bufnr) and bufnr == ctx.bufnr then
                terminal_ctx = ctx
                path = ctx.root
                is_pane = true
                break
            end
        end
    end

    path = normalize_path(path)

    local root = terminal_ctx and normalize_path(terminal_ctx.root) or nil

    if path and not root then
        if vim.fs and vim.fs.root then
            root = vim.fs.root(path, { ".git", "pyproject.toml", "package.json", "Cargo.toml", "go.mod" })
        end

        if not root and vim.fs and vim.fs.find then
            local found = vim.fs.find({ ".git", "pyproject.toml", "package.json", "Cargo.toml", "go.mod" }, {
                path = vim.fn.fnamemodify(path, ":h"),
                upward = true,
            })[1]

            if found then
                root = vim.fn.fnamemodify(found, ":p:h")
            end
        end
    end

    root = normalize_path(root or vim.fn.getcwd())

    return {
        bufnr = bufnr,
        path = path,
        dir = path and vim.fn.fnamemodify(path, ":h") or vim.fn.getcwd(),
        root = root,
        is_pane = is_pane,
        terminal_ctx = terminal_ctx,
        sidepanes = sidepanes_state,
    }
end

local function clean_target(target)
    target = target or vim.fn.expand("<cfile>")
    target = target:gsub("^%s+", ""):gsub("%s+$", "")
    target = target:gsub("^[`'\"(<%[]+", "")
    target = target:gsub("[`'\".,;:)%]>]+$", "")

    if target:match("^%a[%w+.-]*://") then
        return nil
    end

    local line = target:match(":(%d+)$")

    if line then
        target = target:gsub(":%d+$", "")
    else
        local current_line = vim.api.nvim_get_current_line()
        local matched_line = current_line:match(vim.pesc(target) .. ":(%d+)")

        if matched_line then
            line = matched_line
        end
    end

    return target ~= "" and target or nil, line and tonumber(line) or nil
end

local function exact_candidates(target, ctx)
    local candidates = {}

    local function add(path)
        path = normalize_path(path)

        if path and path_exists(path) then
            candidates[path] = true
        end
    end

    if target:sub(1, 1) == "/" or target:sub(1, 1) == "~" then
        add(target)
    else
        add(ctx.dir .. "/" .. target)
        add(ctx.root .. "/" .. target)
    end

    return candidates
end

local function project_files(root)
    if vim.fn.executable("rg") == 1 then
        local files = vim.fn.systemlist({ "rg", "--files", "--hidden", "--glob", "!.git", root })

        if vim.v.shell_error == 0 then
            return files
        end
    end

    local result = {}

    for path, kind in vim.fs.dir(root, { depth = 16 }) do
        if kind == "file" and not path:find("/%.git/") then
            table.insert(result, root .. "/" .. path)
        end
    end

    return result
end

local function common_prefix_score(a, b)
    if not a or not b then
        return 0
    end

    local score = 0
    local a_parts = vim.split(vim.fn.fnamemodify(a, ":p"), "/", { trimempty = true })
    local b_parts = vim.split(vim.fn.fnamemodify(b, ":p"), "/", { trimempty = true })

    for index, part in ipairs(a_parts) do
        if b_parts[index] ~= part then
            break
        end

        score = score + 1
    end

    return score
end

local function candidate_score(path, target, ctx)
    local basename = vim.fn.fnamemodify(path, ":t")
    local absolute = vim.fn.fnamemodify(path, ":p")
    local relative = absolute:sub(#ctx.root + 1)
    local score = 0
    local matched = false

    if relative == target then
        score = score + 10000
        matched = true
    end

    if relative:sub(-#target) == target then
        score = score + 6000
        matched = true
    end

    if absolute:sub(-#target) == target then
        score = score + 5500
        matched = true
    end

    if basename == target then
        score = score + 5000
        matched = true
    elseif basename:lower() == target:lower() then
        score = score + 4500
        matched = true
    elseif basename:find(vim.pesc(target), 1) then
        score = score + 1500
        matched = true
    elseif relative:find(vim.pesc(target), 1) then
        score = score + 800
        matched = true
    end

    if not matched then
        return -math.huge
    end

    score = score + common_prefix_score(ctx.path, path) * 10

    if relative:match("^src/") or relative:match("^lua/") or relative:match("^lib/") then
        score = score + 40
    end

    score = score - math.min(#relative, 500) / 100

    return score
end

local function best_project_match(target, ctx)
    local exact = exact_candidates(target, ctx)

    for path in pairs(exact) do
        return path
    end

    local best = nil
    local best_score = -math.huge

    for _, path in ipairs(project_files(ctx.root)) do
        local score = candidate_score(path, target, ctx)

        if score > best_score then
            best = path
            best_score = score
        end
    end

    if best and best_score > 0 then
        return best
    end

    return nil
end

local function best_buffer_match(target, ctx)
    local best = nil
    local best_score = -math.huge

    for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
        if valid_buf(bufnr) and vim.api.nvim_buf_is_loaded(bufnr) then
            local path = normalize_path(vim.api.nvim_buf_get_name(bufnr))

            if path then
                local score = candidate_score(path, target, ctx)

                if score > best_score then
                    best = {
                        bufnr = bufnr,
                        path = path,
                    }
                    best_score = score
                end
            end
        end
    end

    if best and best_score > 0 then
        return best
    end

    return nil
end

local function is_pane_win(ctx, winid)
    local pane_winid = ctx.sidepanes and ctx.sidepanes.winid or nil
    local bufnr = valid_win(winid) and vim.api.nvim_win_get_buf(winid) or nil

    if winid == pane_winid then
        return true
    end

    if ctx.sidepanes and bufnr == ctx.sidepanes.bufnr then
        return true
    end

    for _, terminal_ctx in pairs((ctx.sidepanes and ctx.sidepanes.terminals) or {}) do
        if bufnr == terminal_ctx.bufnr then
            return true
        end
    end

    return false
end

local function non_pane_window(ctx)
    for _, winid in ipairs(vim.api.nvim_list_wins()) do
        local config = vim.api.nvim_win_get_config(winid)

        if valid_win(winid) and not is_pane_win(ctx, winid) and (not config.relative or config.relative == "") then
            return winid
        end
    end

    return nil
end

local function target_window(ctx, bufnr)
    if bufnr then
        for _, winid in ipairs(vim.fn.win_findbuf(bufnr)) do
            if valid_win(winid) and not is_pane_win(ctx, winid) then
                return winid
            end
        end
    end

    if ctx.is_pane and ctx.sidepanes then
        local winid = ctx.sidepanes.last_focus_win

        if not valid_win(winid) or is_pane_win(ctx, winid) then
            pcall(vim.cmd, "wincmd p")
            winid = vim.api.nvim_get_current_win()
        end

        if valid_win(winid) and not is_pane_win(ctx, winid) then
            return winid
        end

        winid = non_pane_window(ctx)

        if valid_win(winid) then
            return winid
        end
    end

    return vim.api.nvim_get_current_win()
end

local function jump_to_line(line)
    if not line then
        return
    end

    local last_line = vim.api.nvim_buf_line_count(0)

    vim.api.nvim_win_set_cursor(0, { math.min(math.max(line, 1), last_line), 0 })
    vim.cmd("normal! zv")
end

--- Open the file target under cursor in the best non-pane window.
function M.open()
    local target, line = clean_target()

    if not target then
        vim.notify("No file target under cursor", vim.log.levels.WARN)
        return
    end

    local ctx = current_context()
    local buffer_match = best_buffer_match(target, ctx)

    if buffer_match then
        local winid = target_window(ctx, buffer_match.bufnr)

        if valid_win(winid) then
            vim.api.nvim_set_current_win(winid)
        end

        if vim.api.nvim_get_current_buf() ~= buffer_match.bufnr then
            vim.api.nvim_set_current_buf(buffer_match.bufnr)
        end

        jump_to_line(line)

        return
    end

    local path = best_project_match(target, ctx)

    if not path then
        vim.notify("No nearby file found for " .. target, vim.log.levels.WARN)
        return
    end

    local winid = target_window(ctx)

    if valid_win(winid) then
        vim.api.nvim_set_current_win(winid)
    end

    vim.cmd.edit(vim.fn.fnameescape(path))
    jump_to_line(line)
end

return M
