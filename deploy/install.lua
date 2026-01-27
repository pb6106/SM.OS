-- Short wrapper for install_from_github.lua
-- Usage: lua deploy/install.lua owner/repo [branch] [role|manifest]

local tried = {
  'deploy/install_from_github.lua',
  './deploy/install_from_github.lua',
  'install_from_github.lua',
  './install_from_github.lua',
}

local ok, err
for _, p in ipairs(tried) do
  ok, err = pcall(dofile, p)
  if ok then return end
end

io.stderr:write('Failed to locate install_from_github.lua in expected locations.\n')
os.exit(1)
