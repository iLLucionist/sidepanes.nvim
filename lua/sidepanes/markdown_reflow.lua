--[[
sidepanes.markdown_reflow
Purpose: Reflow Markdown buffers with an internal formatter or an optional external formatter.
Does: Preserves protected regions, optionally masks tables for external tools, computes sensible widths, and registers optional commands/mappings.
Architecture: Internal Sidepanes Markdown utility kept behind a narrow module boundary so it can be extracted into a standalone plugin later.
]]

local M = {
    config = {
        external_reflow_cmd = nil,
        external_reflow_fallback = true,
        external_reflow_protect_tables = true,
        commands = false,
        mappings = {
            reflow = false,
        },
    },
}

local register_commands
local register_mappings

--- Return command names from a boolean or table setup value.
local function command_names(config)
    if not config then
        return nil
    end

    if config == true then
        return {
            reflow = "MarkdownReflow",
        }
    end

    if type(config) == "table" then
        return vim.tbl_deep_extend("force", {
            reflow = "MarkdownReflow",
        }, config)
    end

    return nil
end

--- Trim leading and trailing whitespace from text.
local function trim(text)
    local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")

    return trimmed
end

--- Return the display width of text in the current Neovim UI.
local function display_width(text)
    return vim.fn.strdisplaywidth(text)
end

--- Resolve the target reflow width from options, Sidepanes, textwidth, or default.
local function target_width(opts)
    if opts and opts.width and opts.width > 0 then
        return opts.width
    end

    local ok, sidepanes = pcall(require, "sidepanes")

    if ok and sidepanes.is_open and sidepanes.is_open() and sidepanes.text_width then
        local pane_width = sidepanes.text_width()

        if pane_width and pane_width > 0 then
            return pane_width
        end
    end

    if vim.bo.textwidth > 0 then
        return vim.bo.textwidth
    end

    return 80
end

local function external_protect_tables_enabled(opts)
    if opts and opts.external_reflow_protect_tables ~= nil then
        return opts.external_reflow_protect_tables
    end

    return M.config.external_reflow_protect_tables
end

local function fenced_delimiter(line)
    return line:match("^%s*(```+)") or line:match("^%s*(~~~+)")
end

local function table_line(line)
    return line:match("^%s*|") or line:match("|%s*$")
end

local function mask_table_blocks(lines, opts)
    if not external_protect_tables_enabled(opts) then
        return lines, nil
    end

    local masked = {}
    local blocks = {}
    local in_fence = false
    local i = 1

    while i <= #lines do
        local line = lines[i]

        if fenced_delimiter(line) then
            in_fence = not in_fence
            table.insert(masked, line)
            i = i + 1
        elseif not in_fence and table_line(line) then
            local block = {}

            while i <= #lines and table_line(lines[i]) do
                table.insert(block, lines[i])
                i = i + 1
            end

            local token = "<!-- sidepanes-reflow-table-" .. tostring(#blocks + 1) .. " -->"

            table.insert(blocks, {
                token = token,
                lines = block,
            })
            table.insert(masked, token)
        else
            table.insert(masked, line)
            i = i + 1
        end
    end

    if #blocks == 0 then
        return lines, nil
    end

    return masked, blocks
end

local function restore_table_blocks(lines, blocks)
    if not blocks then
        return lines
    end

    local by_token = {}

    for _, block in ipairs(blocks) do
        by_token[block.token] = block.lines
    end

    local restored = {}

    for _, line in ipairs(lines) do
        local token = line:match("^%s*(<!%-%- sidepanes%-reflow%-table%-%d+ %-%->)%s*$")
        local block = token and by_token[token] or nil

        if block then
            vim.list_extend(restored, block)
        else
            table.insert(restored, line)
        end
    end

    return restored
end

local function setext_underline(line)
    return line:match("^%s*[=-]+%s*$") ~= nil
end

local function reflow_command(opts, width)
    opts = opts or {}

    local cmd = opts.external_reflow_cmd

    if cmd == nil then
        cmd = M.config.external_reflow_cmd
    end

    if type(cmd) == "function" then
        cmd = cmd(width, opts)
    end

    if cmd == nil or cmd == false or cmd == "" then
        return nil
    end

    local values = {
        width = tostring(width),
    }

    local function expand(value)
        if type(value) ~= "string" then
            return value
        end

        return (value:gsub("{([%w_]+)}", function(key)
            return values[key] or ""
        end))
    end

    if type(cmd) == "table" then
        local expanded = {}

        for _, part in ipairs(cmd) do
            table.insert(expanded, expand(part))
        end

        return expanded
    end

    if type(cmd) == "string" then
        return expand(cmd)
    end

    return nil
end

local function external_fallback_enabled(opts)
    if opts and opts.external_reflow_fallback ~= nil then
        return opts.external_reflow_fallback
    end

    return M.config.external_reflow_fallback
end

local function run_external_reflow(lines, width, opts)
    local cmd = reflow_command(opts, width)

    if not cmd then
        return nil
    end

    local masked, table_blocks = mask_table_blocks(lines, opts)
    local input = table.concat(masked, "\n") .. "\n"
    local output = vim.fn.systemlist(cmd, input)
    local code = vim.v.shell_error

    if code ~= 0 then
        local label = type(cmd) == "table" and table.concat(cmd, " ") or cmd

        if not external_fallback_enabled(opts) then
            vim.notify("External markdown reflow failed: " .. label, vim.log.levels.ERROR)
            return false
        end

        vim.notify("External markdown reflow failed; using internal reflow", vim.log.levels.WARN)
        return nil
    end

    return restore_table_blocks(output, table_blocks)
end

local function mark_protected(lines)
    local protected = {}
    local in_fence = false

    if lines[1] and lines[1]:match("^%s*%-%-%-%s*$") then
        protected[1] = true

        for i = 2, #lines do
            protected[i] = true

            if lines[i]:match("^%s*(%-%-%-|%.%.%.)%s*$") then
                break
            end
        end
    end

    for i, line in ipairs(lines) do
        if protected[i] then
            goto continue
        end

        if fenced_delimiter(line) then
            in_fence = not in_fence
            protected[i] = true
        elseif in_fence then
            protected[i] = true
        end

        ::continue::
    end

    return protected
end

local function special_markdown_line(lines, index)
    local line = lines[index]
    local next_line = lines[index + 1]

    if line == "" or line:match("^%s*$") then
        return true
    end

    if next_line and setext_underline(next_line) then
        return true
    end

    if setext_underline(line) then
        return true
    end

    local patterns = {
        "^%s*#",
        "^%s*%-%-%-%s*$",
        "^%s*%*%*%*%s*$",
        "^%s*___%s*$",
        "^%s*|",
        "|%s*$",
        "^%s*%[.-%]:",
        "^%s*%[%^.-%]:",
        "^%s*!%[",
        "^%s*<[/!%a]",
        "^%s*:::",
    }

    for _, pattern in ipairs(patterns) do
        if line:match(pattern) then
            return true
        end
    end

    return false
end

local function line_kind(lines, protected, index)
    if protected[index] then
        return nil
    end

    local line = lines[index]

    if line:match("^%s%s%s%s%S") or line:match("^\t%S") then
        return nil
    end

    if special_markdown_line(lines, index) then
        return nil
    end

    local quote_indent, quote_text = line:match("^(%s*>%s?)(.*)$")

    if quote_indent then
        if quote_text:match("^%s*$") then
            return nil
        end

        return {
            name = "quote",
            first_prefix = quote_indent,
            rest_prefix = quote_indent,
            text = quote_text,
        }
    end

    local task_indent, task_marker, task_state, task_text = line:match("^(%s*)([%-%*%+])%s+%[([ xX%-])%]%s+(.*)$")

    if task_indent then
        local first_prefix = task_indent .. task_marker .. " [" .. task_state .. "] "

        return {
            name = "list",
            first_prefix = first_prefix,
            rest_prefix = string.rep(" ", display_width(first_prefix)),
            text = task_text,
        }
    end

    local bullet_indent, bullet_marker, bullet_text = line:match("^(%s*)([%-%*%+])%s+(.*)$")

    if bullet_indent then
        local first_prefix = bullet_indent .. bullet_marker .. " "

        return {
            name = "list",
            first_prefix = first_prefix,
            rest_prefix = string.rep(" ", display_width(first_prefix)),
            text = bullet_text,
        }
    end

    local ordered_indent, ordered_marker, ordered_text = line:match("^(%s*)(%d+[%.%)])%s+(.*)$")

    if ordered_indent then
        local first_prefix = ordered_indent .. ordered_marker .. " "

        return {
            name = "list",
            first_prefix = first_prefix,
            rest_prefix = string.rep(" ", display_width(first_prefix)),
            text = ordered_text,
        }
    end

    return {
        name = "paragraph",
        first_prefix = line:match("^(%s*)") or "",
        rest_prefix = line:match("^(%s*)") or "",
        text = trim(line),
    }
end

local function same_kind(a, b)
    if not a or not b or a.name ~= b.name then
        return false
    end

    if a.name == "paragraph" or a.name == "quote" then
        return a.first_prefix == b.first_prefix
    end

    return false
end

local function list_continuation_text(lines, protected, index, rest_prefix)
    if protected[index] or rest_prefix == "" then
        return nil
    end

    local line = lines[index]

    if line == "" or line:match("^%s*$") then
        return nil
    end

    if special_markdown_line(lines, index) then
        return nil
    end

    if line:sub(1, #rest_prefix) ~= rest_prefix then
        return nil
    end

    local text = line:sub(#rest_prefix + 1)

    if text:match("^%s*[%-%*%+]%s+%[[ xX%-]%]%s+")
        or text:match("^%s*[%-%*%+]%s+")
        or text:match("^%s*%d+[%.%)]%s+")
    then
        return nil
    end

    return text
end

local function wrap_text(text, width, first_prefix, rest_prefix)
    local lines = {}
    local current = ""
    local prefix = first_prefix

    for word in text:gmatch("%S+") do
        local candidate = current == "" and (prefix .. word) or (current .. " " .. word)

        if current == "" or display_width(candidate) <= width then
            current = candidate
        else
            table.insert(lines, current)
            prefix = rest_prefix
            current = prefix .. word
        end
    end

    if current ~= "" then
        table.insert(lines, current)
    end

    return lines
end

function M.reflow_buffer(bufnr, opts)
    bufnr = bufnr or vim.api.nvim_get_current_buf()
    opts = opts or {}

    if not opts.force and vim.api.nvim_get_option_value("modifiable", { buf = bufnr }) == false then
        vim.notify("Buffer is not modifiable", vim.log.levels.WARN)
        return 0
    end

    local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
    local width = target_width(opts)
    local external_output = run_external_reflow(lines, width, opts)

    if external_output == false then
        return 0
    end

    if external_output then
        local changed = false

        if #external_output ~= #lines then
            changed = true
        else
            for index, line in ipairs(external_output) do
                if line ~= lines[index] then
                    changed = true
                    break
                end
            end
        end

        if changed then
            vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, external_output)
        end

        if opts.notify ~= false then
            vim.notify(string.format("Reflowed Markdown externally at width %d", width))
        end

        return #external_output
    end

    local protected = mark_protected(lines)
    local output = {}
    local changed = 0
    local paragraph_count = 0
    local i = 1

    while i <= #lines do
        local kind = line_kind(lines, protected, i)

        if kind then
            local start = i
            local paragraph = {}
            local first_prefix = kind.first_prefix
            local rest_prefix = kind.rest_prefix

            while i <= #lines do
                local next_kind = line_kind(lines, protected, i)

                if i == start then
                    table.insert(paragraph, trim(next_kind.text))
                    i = i + 1
                elseif kind.name == "list" then
                    local continuation = list_continuation_text(lines, protected, i, rest_prefix)

                    if not continuation then
                        break
                    end

                    table.insert(paragraph, trim(continuation))
                    i = i + 1
                elseif same_kind(kind, next_kind) then
                    table.insert(paragraph, trim(next_kind.text))
                    i = i + 1
                else
                    break
                end
            end

            local wrapped = wrap_text(table.concat(paragraph, " "), width, first_prefix, rest_prefix)
            vim.list_extend(output, wrapped)
            paragraph_count = paragraph_count + 1

            if #wrapped ~= (i - start) then
                changed = changed + 1
            else
                for offset, wrapped_line in ipairs(wrapped) do
                    if wrapped_line ~= lines[start + offset - 1] then
                        changed = changed + 1
                        break
                    end
                end
            end
        else
            table.insert(output, lines[i])
            i = i + 1
        end
    end

    if changed > 0 then
        vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
    end

    if opts.notify ~= false then
        vim.notify(string.format("Reflowed %d Markdown paragraphs at width %d", paragraph_count, width))
    end

    return paragraph_count
end

--- Register configured MarkdownReflow user commands.
register_commands = function()
    local names = command_names(M.config.commands)

    if not names then
        return
    end

    if names.reflow then
        vim.api.nvim_create_user_command(names.reflow, function(opts)
            M.reflow_buffer(0, { width = tonumber(opts.args) })
        end, { nargs = "?", force = true })
    end
end

--- Register configured markdown reflow keymaps.
register_mappings = function()
    local mappings = M.config.mappings or {}

    if mappings == false or not mappings.reflow then
        return
    end

    vim.keymap.set("n", mappings.reflow, function()
        M.reflow_buffer(0)
    end, { desc = "Reflow Markdown" })
end

--- Merge configuration and install optional commands and mappings.
function M.setup(opts)
    M.config = vim.tbl_deep_extend("force", M.config, opts or {})
    register_commands()
    register_mappings()
end

return M
