-- main.lua
-- Single-entrypoint for the consolidated SM.OS runtime (OpenComputers)

local app = require('app')

local function main()
  local ok, err = pcall(app.run)
  if not ok then
    io.stderr:write('Fatal: app.run failed: ' .. tostring(err) .. '\n')
  end
end

if ... == nil then
  main()
end
