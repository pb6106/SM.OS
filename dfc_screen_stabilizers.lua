local base = require("dfc_screen_base")

base.render = function(status)
  local lines = {}
  lines[#lines+1] = "== Stabilizers =="
  if status.analyze and status.analyze.stabilizers then
    for i,st in ipairs(status.analyze.stabilizers) do
      lines[#lines+1] = string.format("Stabilizer %d: %s", i, tostring(st.address or st.addr or "unknown"))
      if st.stress then lines[#lines+1] = "  Stress: "..tostring(st.stress) end
      if st.health then lines[#lines+1] = "  Health: "..tostring(st.health) end
    end
  elseif status.communicators and type(status.communicators) == "table" then
    for i,c in ipairs(status.communicators) do
      lines[#lines+1] = string.format("Comm %d: %s", i, tostring(c.address or c.addr or "unknown"))
    end
  else
    lines[#lines+1] = "No stabilizer info available"
    lines[#lines+1] = serialization.serialize(status)
  end
  base.show_lines(lines, 0, {fg=0x87CEFA, bg=0x000000})
end

local token, port, controller = ...
-- EMBEDDED SCREEN UUID for stabilizers monitor
local screenUUID = "fbec3a19-0949-4f2e-9bfd-248c2f88502b"
base.start(token, port, controller, screenUUID)
