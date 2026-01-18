local internet = require("internet")
local serialization = require("serialization")
local term = require("term")
local fs = require("filesystem")

local function usage()
  print("Usage: deploy.lua [role] [base]")
  print("  role: one of controller, emitters, core, stabilizers (optional)")
  print("  base: repo shorthand owner/repo[/branch[/path]] or full URL (optional)")
  print("Examples:")
  print("  deploy.lua controller                         # uses files_controller.lua from default repo")
  print("  deploy.lua emitters http://host:8000          # fetch files_screen_emitters.lua from host")
  print("  deploy.lua pb6106/SM.OS                       # fetch top-level files.lua from GitHub repo")
end

local DEFAULT_REPO = "pb6106/SM.OS" -- default repo set to your GitHub repo

local args = {...}
local verbose = false
local role = nil
local base = nil
for i=1,#args do
  local a = args[i]
  if a == "--verbose" or a == "-v" then verbose = true
  elseif string.sub(a,1,7) == "--role=" then role = string.sub(a,8)
  elseif a == "controller" or a == "emitters" or a == "core" or a == "stabilizers" or a == "stabilizer" then
    role = (a == "stabilizer") and "stabilizers" or a
  elseif not base then
    base = a
  end
end
if not base or base == "" then base = DEFAULT_REPO end

-- Accept several forms for `base`:
-- 1) full URL to a directory on a raw host, e.g. https://example.com/path
-- 2) full URL to a manifest file, e.g. https://raw.githubusercontent.com/owner/repo/branch/path/files.lua
-- 3) GitHub shorthand: owner/repo[/branch[/path]]  (branch defaults to 'main')
if not string.match(base, "^https?://") then
  -- treat as GitHub shorthand
  local parts = {}
  for p in string.gmatch(base, "([^/]+)") do table.insert(parts, p) end
  if #parts >= 2 then
    local owner = parts[1]
    local repo = parts[2]
    local branch = parts[3] or "main"
    local path = ""
    if #parts > 3 then
      for i=4,#parts do
        path = path .. parts[i]
        if i < #parts then path = path .. "/" end
      end
    end
    base = "https://raw.githubusercontent.com/"..owner.."/"..repo.."/"..branch
    if path ~= "" then base = base .. "/" .. path end
  else
    print("Invalid shorthand; provide owner/repo[/branch[/path]] or a full URL")
    return
  end
end

if string.sub(base, -1) == "/" then base = string.sub(base,1,-2) end

local function fetch(path)
  local url
  if string.match(path, "^https?://") then
    url = path
  else
    url = base .. "/" .. path
  end
  if verbose then print("Fetching URL: "..url) end
  local tries = 3
  local lastErr
  for attempt=1,tries do
    local handle, err = internet.request(url)
    if not handle then
      lastErr = err
      if verbose then print(" request failed: "..tostring(err).." (attempt "..attempt..")") end
      os.sleep(0.5)
    else
      local data = ""
      for chunk in handle do
        data = data .. chunk
      end
      return data
    end
  end
  return nil, lastErr
end

-- choose manifest filename based on role
local role_to_manifest = {
  controller = "files_controller.lua",
  emitters = "files_screen_emitters.lua",
  core = "files_screen_core.lua",
  stabilizers = "files_screen_stabilizers.lua",
}

local manifest_url = nil
-- if user passed a role, prefer the role manifest
if role and role_to_manifest[role] then
  manifest_url = role_to_manifest[role]
  print("Fetching file list for role '"..role.."' from "..base.."/"..manifest_url)
else
  -- if base already pointed to a .lua file, use it as manifest, otherwise use top-level files.lua
  if string.match(base, "%.lua$") then
    manifest_url = base
    print("Fetching manifest from "..manifest_url)
  else
    print("Fetching file list from "..base.."/files.lua")
    manifest_url = "files.lua"
  end
end

local listBody, err = fetch(manifest_url)
if not listBody then print("Failed to fetch files.lua: "..tostring(err)) return end

local fn, perr = load(listBody)
if not fn then print("Failed to parse files.lua: "..tostring(perr)) return end
local ok, files = pcall(fn)
if not ok or type(files) ~= "table" then print("files.lua did not return a table") return end

for _, fname in ipairs(files) do
  io.write("Downloading: "..fname.." ... ")
  local body, ferr = fetch(fname)
  if not body then
    print("failed: "..tostring(ferr))
  else
    local f = io.open(fname, "w")
    if not f then print("failed to open for write: "..tostring(fname)) else
      f:write(body)
      f:close()
      print("ok")
    end
  end
end

print("Deploy complete.")
