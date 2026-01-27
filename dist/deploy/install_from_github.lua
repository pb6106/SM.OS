-- deploy/install_from_github.lua
-- Installer for OpenComputers that downloads files from a GitHub repo raw tree
-- Usage on OC machine:
-- lua install_from_github.lua owner/repo [branch]


local owner_repo = arg and arg[1]
local branch = (arg and arg[2]) or 'main'
local role_or_manifest = (arg and arg[3]) -- optional: role name or manifest filename
if not owner_repo then
  print('Usage: lua install_from_github.lua owner/repo [branch] [role|manifest]')
  os.exit(1)
end

local base = 'https://raw.githubusercontent.com/' .. owner_repo .. '/' .. branch .. '/'

local function fetch_http(url)
  -- Try LuaSocket first (useful for testing outside OC)
  local ok, http = pcall(require, 'socket.http')
  if ok and http and http.request then
    local body, code = http.request(url)
    if code == 200 then return body end
    return nil, 'http_code_' .. tostring(code)
  end

  -- Try OpenComputers internet component
  local okc, comp = pcall(require, 'component')
  if okc and comp and comp.internet then
    local okr, handle = pcall(comp.internet.request, comp.internet, url)
    if not okr or not handle then return nil, 'internet_request_failed' end
    local out = {}
    while true do
      local chunk = handle.read(16384)
      if not chunk then break end
      table.insert(out, chunk)
    end
    pcall(handle.close, handle)
    return table.concat(out)
  end

  return nil, 'no_http_available'
end

local function fetch(path)
  local url = base .. path
  return fetch_http(url)
end

-- Try to fetch a manifest that lists files to download. Manifest should be a Lua file returning a table array of paths.
-- determine manifest filename: if third arg provided, treat as either a full filename or a role name
local manifest_name = 'install_manifest.lua'
if role_or_manifest and #role_or_manifest > 0 then
  if role_or_manifest:match('\.lua$') then
    manifest_name = role_or_manifest
  else
    -- treat as role: install_manifest_<role>.lua
    manifest_name = 'install_manifest_' .. role_or_manifest .. '.lua'
  end
end

local manifest_body, merr = fetch(manifest_name)
local files = nil
if manifest_body then
  local chunk, err = load(manifest_body, 'manifest', 't')
  if chunk then
    local ok, res = pcall(chunk)
    if ok and type(res) == 'table' then files = res end
  end
end

if not files then
  print('Could not fetch or parse install_manifest.lua from repo. Expecting a manifest listing files to install.')
  print('Create `install_manifest.lua` in the repo root that returns a table of file paths (strings).')
  os.exit(1)
end

local function ensure_dir(path)
  local okfs, fs = pcall(require, 'filesystem')
  if okfs and fs and fs.makeDirectory then
    fs.makeDirectory(path)
    return true
  else
    -- best-effort: try to create nested directories by writing dummy files
    return true
  end
end

local function backup_if_exists(path)
  local f = io.open(path, 'r')
  if f then
    f:close()
    local bak = path .. '.bak'
    pcall(os.rename, path, bak)
  end
end

local written = 0
for _, p in ipairs(files) do
  print('Fetching: ' .. p)
  local body, err = fetch(p)
  if not body then
    io.stderr:write('Failed to fetch ' .. p .. ': ' .. tostring(err) .. '\n')
  else
    local dir = p:match('(.*/)', 1)
    if dir then ensure_dir(dir:sub(1, -2)) end
    backup_if_exists(p)
    local fh, ferr = io.open(p, 'w')
    if not fh then
      io.stderr:write('Failed to open ' .. p .. ' for writing: ' .. tostring(ferr) .. '\n')
    else
      fh:write(body)
      fh:close()
      print('Wrote: ' .. p)
      written = written + 1
    end
  end
end

print('Install complete. Files written: ' .. tostring(written))

return true