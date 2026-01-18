local base = require("dfc_screen_base")

base.render = function(status)
  local lines = {}
  lines[#lines+1] = "== Core Status =="
  if status.analyze then
    if status.analyze.level then lines[#lines+1] = "Level: "..tostring(status.analyze.level) end
    if status.analyze.stress then lines[#lines+1] = "Stress: "..tostring(status.analyze.stress) end
    if status.analyze.fuel then lines[#lines+1] = "Fuel: "..tostring(status.analyze.fuel) end
  end
  if status.injector and status.injector.getAmount then lines[#lines+1] = "Injector: "..tostring(status.injector.getAmount) end
  if #lines == 1 then lines[#lines+1] = "No core summary available" end
  base.show_lines(lines, 0, {fg=0x00FF00, bg=0x000000})
end

local token, port, controller = ...
-- EMBEDDED SCREEN UUID for core monitor
local screenUUID = "be203944-69b8-4616-bf2c-1a9374194e67"
base.start(token, port, controller, screenUUID)
