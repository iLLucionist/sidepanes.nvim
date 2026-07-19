--[[
sidepanes.selection
Purpose: Capture and format source text for sends and questions.
Does: Reads visual selections or line ranges, detects markdown fenced-code languages, resolves file/root metadata, and builds prompt templates.
Architecture: Pure context builder used by context.lua, question.lua, and terminal.lua before content is sent to agents or IPython.
]]

local util = require("sidepanes.util")

local M = {}

--- Capture the active or most recent visual selection from a buffer.
local function from_visual(bufnr, opts)
    opts = opts or {}

    local visual_mode = opts.visual_mode or vim.fn.mode(1)
    local in_active_visual = visual_mode:match("[vV\22]") ~= nil
    local start_pos = in_active_visual and vim.fn.getpos("v") or vim.fn.getpos("'<")
    local end_pos = in_active_visual and vim.fn.getcurpos() or vim.fn.getpos("'>")

    local start_lnum = start_pos[2]
    local start_col = start_pos[3]
    local end_lnum = end_pos[2]
    local end_col = end_pos[3]

    if start_lnum == 0 or end_lnum == 0 then
        return nil
    end

    if start_lnum > end_lnum or (start_lnum == end_lnum and start_col > end_col) then
        start_lnum, end_lnum = end_lnum, start_lnum
        start_col, end_col = end_col, start_col
    end

    local lines = nil

    if visual_mode:sub(1, 1) == "V" then
        lines = vim.api.nvim_buf_get_lines(bufnr, start_lnum - 1, end_lnum, false)
    else
        lines = vim.api.nvim_buf_get_text(bufnr, start_lnum - 1, start_col - 1, end_lnum - 1, end_col, {})
    end

    return {
        text = table.concat(lines, "\n"),
        start_lnum = start_lnum,
        end_lnum = end_lnum,
    }
end

--- Capture an inclusive line range from a buffer.
local function from_range(bufnr, line1, line2)
    line1 = line1 or vim.fn.line(".")
    line2 = line2 or line1

    if line1 > line2 then
        line1, line2 = line2, line1
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, line1 - 1, line2, false)

    return {
        text = table.concat(lines, "\n"),
        start_lnum = line1,
        end_lnum = line2,
    }
end

--- Detect the fenced code language active at a markdown line.
local function markdown_fence_language(bufnr, line)
    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, line, false)
    local open_fence = nil
    local language = nil

    for index = 1, #lines do
        local marker, info = lines[index]:match("^%s*(```+)%s*(.-)%s*$")

        if not marker then
            marker, info = lines[index]:match("^%s*(~~~+)%s*(.-)%s*$")
        end

        if marker then
            if open_fence and marker:sub(1, 1) == open_fence:sub(1, 1) and #marker >= #open_fence then
                open_fence = nil
                language = nil
            else
                open_fence = marker
                info = util.trim(info or "")

                if info ~= "" then
                    language = info:match("^([^%s,{]+)")
                else
                    language = nil
                end
            end
        end
    end

    return open_fence and language or nil
end

--- Build the file and text context for an ask/send operation.
function M.context(opts, deps)
    opts = opts or {}
    deps = deps or {}

    local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
    local selection = opts.visual and from_visual(bufnr, opts) or from_range(bufnr, opts.line1, opts.line2)

    if not selection or selection.text == "" then
        vim.notify("No selection to send", vim.log.levels.WARN)
        return nil
    end

    local terminal_ctx = deps.terminal_context_for_buf and deps.terminal_context_for_buf(bufnr) or nil
    local markdown_source = bufnr == deps.pane_bufnr and deps.source or nil
    local root = terminal_ctx and terminal_ctx.root or (markdown_source and util.project_root_for_path(markdown_source) or util.project_root(bufnr))
    local path = markdown_source or vim.api.nvim_buf_get_name(bufnr)

    selection.bufnr = bufnr
    selection.root = root
    selection.file = terminal_ctx and ("Terminal: " .. terminal_ctx.tool_label .. " / " .. terminal_ctx.preset_label) or util.relative_path(path, root)
    selection.filetype = vim.api.nvim_get_option_value("filetype", { buf = bufnr })
    selection.snippet_filetype = selection.filetype

    if selection.filetype == "markdown" then
        selection.snippet_filetype = markdown_fence_language(bufnr, selection.start_lnum) or selection.filetype
    end

    return selection
end

--- Format a complete editable prompt from context and a question body.
function M.format_prompt(context, question)
    local filetype = context.snippet_filetype ~= "" and context.snippet_filetype or nil
    local fence = util.fence_for(context.text)

    return table.concat({
        "Question:",
        question,
        "",
        "File:",
        context.file,
        "",
        "Selection:",
        "lines " .. context.start_lnum .. "-" .. context.end_lnum,
        "",
        fence .. (filetype and filetype or ""),
        context.text,
        fence,
    }, "\n")
end

--- Format the initial editable prompt with an empty question.
function M.prompt_template(context)
    return M.format_prompt(context, "")
end

return M
