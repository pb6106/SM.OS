-- install_package_runner.lua
-- Run on the OpenComputers machine after transferring `install_package.lua`.
-- Writes files to disk, backing up existing files to *.bak

local ok, pkg = pcall(require, 'install_package')
if not ok or type(pkg) ~= 'table' then
  io.stderr:write('install_package not found or invalid. Place install_package.lua next to this script.\n')
  os.exit(1)
end

local okfs, filesystem = pcall(require, 'filesystem')

local function ensure_dir(path)
  if not path then return end
  if okfs and filesystem then
    -- create directories iteratively
    local cur = ''
    for part in path:gmatch('[^/]+') do
      cur = cur .. '/' .. part
      pcall(filesystem.makeDirectory, cur)
    end
  else
    -- best-effort: try to open a file in the directory to force creation will fail if not possible
  end
end

local function backup_if_exists(path)
  local attr = io.open(path, 'r')
  if attr then
    attr:close()
    local bak = path .. '.bak'
    local ok, err
    if okfs and filesystem then
      ok, err = pcall(filesystem.rename, path, bak)
    else
      ok, err = pcall(os.rename, path, bak)
    end
    if not ok then io.stderr:write('Warning: failed to backup ' .. path .. ': ' .. tostring(err) .. '\n') end
  end
end

local written = 0
for path, content in pairs(pkg) do
  -- normalize path separators
  local p = path:gsub('\\', '/')
  local dir = p:match('(.*/)', 1)
  if dir then
    -- remove leading './' if present
    if dir:sub(1,2) == './' then dir = dir:sub(3) end
    ensure_dir(dir:sub(1,-2))
  end
  backup_if_exists(p)
  local f, err = io.open(p, 'w')
  if not f then
    io.stderr:write('Failed to write ' .. p .. ': ' .. tostring(err) .. '\n')
  else
    f:write(content)
    f:close()
    written = written + 1
    print('Wrote: ' .. p)
  end
end

print('Install complete. Files written: ' .. tostring(written))
