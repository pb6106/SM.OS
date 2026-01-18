local base = require("dfc_screen_base")
local serialization = require("serialization")

-- render function for emitter-focused screen
base.render = function(status)
  local lines = {}
  lines[#lines+1] = "== Emitters =="
  if status.emitters and type(status.emitters) == "table" and #status.emitters > 0 then
    for i,e in ipairs(status.emitters) do
      local addr = e.address or (e.proxy and e.proxy.address) or (e.addr) or ("unknown")
      lines[#lines+1] = string.format("Emitter %d: %s", i, tostring(addr))
      if e.level then lines[#lines+1] = string.format("  Level: %s", tostring(e.level)) end
      if e.stress then lines[#lines+1] = string.format("  Stress: %s", tostring(e.stress)) end
    end
  else
    lines[#lines+1] = "No emitter info available"
    lines[#lines+1] = serialization.serialize(status)
  end
  base.show_lines(lines, 0, {fg=0xFFD700, bg=0x000000})
end

-- start with token, port, optional controller addr
local token, port, controller = ...
-- EMBEDDED SCREEN UUID for emitter monitor
local screenUUID = "366385c4-353a-4fea-8c2b-c04244fcb443"
base.start(token, port, controller, screenUUID)
