local M = {}

function M.repo_root(level)
    local source = debug.getinfo(level or 2, "S").source

    if source:sub(1, 1) == "@" then
        source = source:sub(2)
    end

    return vim.fn.fnamemodify(source, ":p:h:h")
end

function M.append_repo_root(level)
    local root = M.repo_root((level or 2) + 1)

    vim.opt.runtimepath:append(root)

    return root
end

return M
