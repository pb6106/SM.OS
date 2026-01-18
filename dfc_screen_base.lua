-- Shared base for per-screen display agents
local component = require("component")
local event = require("event")
local serialization = require("serialization")
local dfc_display = nil
pcall(function() dfc_display = require("dfc_display") end)

local M = {}

-- public hooks (can be overridden by specific screen modules)
M.render = function(status)
  -- default: show serialized summary (single-line fallback)
  local s = serialization.serialize(status)
  local lines = { s }
  if dfc_display then pcall(dfc_display.show_art, lines, 0) end
end

local modem = nil
local TOKEN = nil
local PORT = 12345

local SCREEN_UUID = nil

local function send_register(controller)
  if not modem then return end
  local reg = { cmd = "register", info = { role = "screen_agent" }, token = TOKEN }
  local ok, s = pcall(serialization.serialize, reg)
  if not ok then return end
  pcall(modem.broadcast, PORT, s)
  if controller then pcall(modem.send, controller, PORT, s) end
end

local function handle_modem_message(_, _, sender, port, _, raw)
  if not raw then return end
  local ok, msg = pcall(serialization.unserialize, raw)
  if not ok or type(msg) ~= "table" then return end
  if TOKEN and msg.token and msg.token ~= TOKEN then return end
  if msg.cmd == "show_art" then
    local args = msg.args or {}
    local lines = args.lines or {}
    local duration = args.duration or 5
    pcall(function()
      if dfc_display then dfc_display.show_art(lines, duration, args.opts) end
    end)
  elseif msg.cmd == "show_file" then
    local path = msg.args and msg.args.path
    if path then pcall(function() if dfc_display then dfc_display.show_art_from_file(path, msg.args.duration or 5, msg.args.opts) end end) end
  elseif msg.cmd == "status_update" then
    local status = msg.args and msg.args.status
    if status then pcall(M.render, status) end
  elseif msg.cmd == "register_request" then
    send_register(sender)
  end
end

function M.start(token, port, controllerAddr, screenUUID)
  TOKEN = token
  PORT = tonumber(port) or PORT
  SCREEN_UUID = screenUUID
  local function find_and_open_modem()
    local addr = next(component.list("modem"))
    if not addr then modem = nil; return false end
    modem = component.proxy(addr)
    pcall(modem.open, PORT)
    return true
  end

  send_register(controllerAddr)
  print(string.format("screen agent starting on port %d (token %s)", PORT, TOKEN and "set" or "none"))

  -- Supervisory loop: keep running and handle modem messages.
  while true do
    local ok = true
    if not modem then
      ok = find_and_open_modem()
      if not ok then
        os.sleep(2)
        goto continue
      end
    end
    -- block waiting for modem messages, handle safely
    local ev, _, sender, portnum, _, raw = event.pull("modem_message")
    local status, err = pcall(function()
      handle_modem_message(ev, nil, sender, portnum, nil, raw)
    end)
    if not status then
      print("screen agent handler error: "..tostring(err))
      os.sleep(1)
    end
    ::continue::
  end
end

function M.show_lines(lines, duration, opts)
  opts = opts or {}
  if SCREEN_UUID and not opts.screen then opts.screen = SCREEN_UUID end
  if dfc_display then pcall(dfc_display.show_art, lines, duration or 0, opts) end
end

return M
