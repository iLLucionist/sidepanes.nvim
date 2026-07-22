--[[
sidepanes.ask_prompt
Purpose: Format and patch editable ask prompts.
Does: Builds prompt/citation Markdown, detects duplicate file/range citations, and appends same-file selections in a stable order when possible.
Architecture: Pure helpers shared by the floating question editor and the planned ask pane, keeping prompt editing logic independent from windows and terminals.
]]

local util = require("sidepanes.util")

local M = {}

local function split_lines(text)
    return vim.split(text or "", "\n", { plain = true })
end

local function normalize_identity_path(path)
    if not path or path == "" then
        return nil
    end

    return vim.fs.normalize(path)
end

local function context_path(context)
    if context.path and context.path ~= "" then
        return context.path
    end

    if context.root and context.file and not context.file:match("^Terminal:") then
        return context.root .. "/" .. context.file
    end

    return context.file
end

--- Return the file label shown in the outgoing prompt.
function M.display_file(context, opts)
    opts = opts or {}
    context = context or {}

    local file = context.file or ""
    local root = context.root
    local target_root = opts.target_root

    if root and target_root and util.normalize_project_root(root) ~= util.normalize_project_root(target_root) then
        return file .. " (root: " .. root .. ")"
    end

    return file
end

--- Return a stable exact duplicate identity for one citation.
function M.citation_identity(context)
    context = context or {}

    return table.concat({
        normalize_identity_path(context_path(context)) or "",
        tostring(context.start_lnum or ""),
        tostring(context.end_lnum or ""),
    }, "\0")
end

--- Build a structured citation table from a captured selection context.
function M.citation_from_context(context, opts)
    opts = opts or {}
    context = context or {}

    return {
        file = M.display_file(context, opts),
        identity = M.citation_identity(context),
        root = context.root,
        path = context_path(context),
        start_lnum = context.start_lnum,
        end_lnum = context.end_lnum,
        text = context.text or "",
        filetype = context.snippet_filetype ~= "" and context.snippet_filetype or context.filetype,
    }
end

local function selection_lines(citation)
    local filetype = citation.filetype and citation.filetype ~= "" and citation.filetype or nil
    local fence = util.fence_for(citation.text or "")
    local lines = {
        "Selection:",
        "lines " .. tostring(citation.start_lnum) .. "-" .. tostring(citation.end_lnum),
        "",
        fence .. (filetype or ""),
    }

    vim.list_extend(lines, split_lines(citation.text))
    table.insert(lines, fence)

    return lines
end

local function file_block_lines(citation)
    local lines = {
        "File:",
        citation.file,
        "",
    }

    vim.list_extend(lines, selection_lines(citation))

    return lines
end

--- Format one citation as a file block.
function M.format_file_block(context, opts)
    return table.concat(file_block_lines(M.citation_from_context(context, opts)), "\n")
end

--- Format a complete editable prompt from context and a question body.
function M.format_prompt(context, question, opts)
    local citation = M.citation_from_context(context, opts)
    local lines = {
        "Question:",
        question or "",
        "",
    }

    vim.list_extend(lines, file_block_lines(citation))

    return table.concat(lines, "\n")
end

--- Format the initial editable prompt with an empty question.
function M.prompt_template(context, opts)
    return M.format_prompt(context, "", opts)
end

local function find_file_blocks(lines)
    local blocks = {}
    local current = nil

    for index, line in ipairs(lines) do
        if line == "File:" then
            if current then
                current.stop = index - 1
                table.insert(blocks, current)
            end

            current = {
                start = index,
                stop = #lines,
                file = lines[index + 1] or "",
            }
        end
    end

    if current then
        current.stop = #lines
        table.insert(blocks, current)
    end

    return blocks
end

local function selection_ranges(lines, block)
    local ranges = {}
    local machine_shaped = true
    local index = block.start

    while index <= block.stop do
        if lines[index] == "Selection:" then
            local range = lines[index + 1] or ""
            local start_lnum, end_lnum = range:match("^lines%s+(%d+)%-(%d+)$")

            if not start_lnum then
                machine_shaped = false
            else
                table.insert(ranges, {
                    line = index,
                    start_lnum = tonumber(start_lnum),
                    end_lnum = tonumber(end_lnum),
                })
            end
        end

        index = index + 1
    end

    return ranges, machine_shaped
end

local function insert_lines(lines, index, inserted)
    local result = vim.deepcopy(lines)

    for offset, line in ipairs(inserted) do
        table.insert(result, index + offset - 1, line)
    end

    return result
end

local function append_lines(lines, inserted)
    local result = vim.deepcopy(lines)

    if #result > 0 and result[#result] ~= "" then
        table.insert(result, "")
    end

    vim.list_extend(result, inserted)

    return result
end

local function duplicate_range(ranges, citation)
    for _, range in ipairs(ranges) do
        if range.start_lnum == citation.start_lnum and range.end_lnum == citation.end_lnum then
            return true
        end
    end

    return false
end

local function insertion_index(block, ranges, citation, machine_shaped)
    if not machine_shaped then
        return block.stop + 1
    end

    for _, range in ipairs(ranges) do
        if citation.start_lnum and range.start_lnum and citation.start_lnum < range.start_lnum then
            return range.line
        end
    end

    return block.stop + 1
end

--- Add one citation to existing prompt lines.
function M.add_citation(lines, context, opts)
    opts = opts or {}
    lines = vim.deepcopy(lines or {})

    local citation = M.citation_from_context(context, opts)
    local blocks = find_file_blocks(lines)
    local duplicate_policy = opts.duplicate_policy or "skip"

    for _, block in ipairs(blocks) do
        if block.file == citation.file then
            local ranges, machine_shaped = selection_ranges(lines, block)

            if duplicate_policy == "skip" and duplicate_range(ranges, citation) then
                return lines, {
                    added = false,
                    reason = "duplicate",
                    citation = citation,
                }
            end

            local chunk = selection_lines(citation)
            table.insert(chunk, 1, "")

            return insert_lines(lines, insertion_index(block, ranges, citation, machine_shaped), chunk), {
                added = true,
                reason = machine_shaped and "same_file_ordered" or "same_file_appended",
                citation = citation,
            }
        end
    end

    return append_lines(lines, file_block_lines(citation)), {
        added = true,
        reason = "new_file",
        citation = citation,
    }
end

return M
