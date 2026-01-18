-- dfc_display_agent.lua
-- Run on remote computers that have a monitor/GPU. Listens on a modem
-- port for display commands from the controller.

local component = require("component")
local event = require("event")
local serialization = require("serialization")
local dfc_display = require("dfc_display")

local modem = component.modem

local args = {...}
local TOKEN = args[1] or nil
local PORT = tonumber(args[2]) or 12345
local CONTROLLER_ADDR = args[3]

local ok, opened = pcall(function() return modem.open(PORT) end)
if not ok then print("Warning: could not open modem port "..tostring(PORT)) end

print(string.format("dfc_display_agent listening on port %d (token %s)", PORT, TOKEN and "set" or "none"))

-- send registration via broadcast so controller can discover us
pcall(function()
  local reg = { cmd = "register", info = { name = component.proxy(component.list("computer")()).label or "display_agent" } , token = TOKEN }
  local s = serialization.serialize(reg)
  pcall(modem.broadcast, PORT, s)
  if CONTROLLER_ADDR then pcall(modem.send, CONTROLLER_ADDR, PORT, s) end
end)

local current_status = nil
local showing_alert = false

local function handle_status_update(status)
  current_status = status
  if showing_alert then return end
  -- format a few useful lines if possible
  local lines = {}
  if status.analyze and status.analyze.level then lines[#lines+1] = "Level: "..tostring(status.analyze.level) end
  if status.analyze and status.analyze.stress then lines[#lines+1] = "Stress: "..tostring(status.analyze.stress) end
  if #lines == 0 then lines[#lines+1] = serialization.serialize(status) end
  pcall(dfc_display.show_art, lines, 0, {fg=0xFFFFFF, bg=0x000000})
end

while true do
  local ok, err = pcall(function()
    local ev, _, sender, port, _, raw = event.pull("modem_message")
    if raw then
      local ok2, msg = pcall(serialization.unserialize, raw)
      if not ok2 or type(msg) ~= "table" then
        print("Received malformed message from "..tostring(sender))
        return
      end
      if TOKEN and msg.token ~= TOKEN then
        return
      end
      local cmd = msg.cmd
      if cmd == "show_art" then
        local args = msg.args or {}
        local lines = args.lines or {}
        local duration = args.duration or 5
        local opts = args.opts or {}
        showing_alert = true
        pcall(dfc_display.show_art, lines, duration, opts)
        showing_alert = false
        if current_status then pcall(handle_status_update, current_status) end
      elseif cmd == "show_file" then
        local path = msg.args and msg.args.path
        if path then
          showing_alert = true
          pcall(dfc_display.show_art_from_file, path, msg.args.duration or 5, msg.args.opts)
          showing_alert = false
          if current_status then pcall(handle_status_update, current_status) end
        end
      elseif cmd == "clear" then
        pcall(dfc_display.show_art, {""}, 0, {fg=0xFFFFFF, bg=0x000000})
      elseif cmd == "status_update" then
        pcall(handle_status_update, msg.args and msg.args.status)
      elseif cmd == "register_request" then
        local reg = { cmd = "register", info = { name = component.proxy(component.list("computer")()).label or "display_agent" }, token = TOKEN }
        local s = serialization.serialize(reg)
        pcall(modem.send, sender, PORT, s)
      else
        print("Unknown display command from "..tostring(sender))
      end
    end
  end)
  if not ok then
    print("dfc_display_agent loop error: "..tostring(err))
    os.sleep(2)
  end
end
