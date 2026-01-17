local internet = require("internet")
local serialization = require("serialization")
local term = require("term")
local fs = require("filesystem")

local function usage()
  print("Usage: deploy.lua <base_url>")
  print("Example: deploy.lua http://192.168.1.10:8000")
end

-- Set your default repo here (GitHub shorthand `owner/repo` or a raw base URL).
-- If you prefer not to edit the file, you can still pass an argument.
local DEFAULT_REPO = "pb6106/SM.OS" -- default repo set to your GitHub repo

local base = ... or DEFAULT_REPO
if not base or base == "" then usage() return end

-- Accept several forms for `base`:
-- 1) full URL to a directory on a raw host, e.g. https://example.com/path
-- 2) full URL to a manifest file, e.g. https://raw.githubusercontent.com/owner/repo/branch/path/files.lua
-- 3) GitHub shorthand: owner/repo[/branch[/path]]  (branch defaults to 'main')
if not string.match(base, "^https?://") then
  -- treat as GitHub shorthand
  local parts = {}
  for p in string.gmatch(base, "([^
/]+)") do table.insert(parts, p) end
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
  local handle, err = internet.request(url)
  if not handle then return nil, err end
  local data = ""
  for chunk in handle do
    data = data .. chunk
  end
  return data
end

local manifest_url = nil
if string.match(base, "files.lua$") then
  manifest_url = base
  print("Fetching manifest from "..manifest_url)
else
  print("Fetching file list from "..base.."/files.lua")
  manifest_url = "files.lua"
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
