local function log_error(msg)
  io.stderr:write('[pdfscribe] ' .. msg .. '\n')
end

local function split(str, pat)
  local result = {}
  for elem in string.gmatch(str, '([^' .. pat .. ']+)') do
    table.insert(result, elem)
  end

  return result
end

if vim then
  local api = vim.api
  log_error = function(msg)
    api.nvim_command('echohl ErrorMsg')
    api.nvim_command('echom "[pdfscribe] ' .. msg .. '"')
    api.nvim_command('echohl None')
  end

  split = vim.fn.split
end

local M = {
  split = split,
  log_error = log_error
}

return M
