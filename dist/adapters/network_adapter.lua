-- adapters/network_adapter.lua
-- Simple modem-based network adapter with heartbeat and poll() API.

local M = {}

local function use_component()
  local ok, comp = pcall(require, 'component')
  if ok and comp and (comp.modem or comp.proxy) then return comp end
  return nil
end

function M.connect(cfg)
  cfg = cfg or {}
  local comp = use_component()
  local ok_event, event = pcall(require, 'event')
  if comp and comp.modem then
    local modem = comp.modem
    local channel = cfg.channel or 123
    local port = cfg.port or 0
    if modem.open and pcall(modem.isOpen, modem, channel) == false then pcall(modem.open, modem, channel) end
    local adapter = { modem = modem, channel = channel, port = port }
    function adapter.send_heartbeat()
      local addr = adapter.modem.address or adapter.modem
      local msg = { type = 'heartbeat', from = addr, ts = os.time() }
      pcall(adapter.modem.broadcast, adapter.modem, adapter.channel, adapter.port, msg)
    end
    function adapter.send(msg)
      pcall(adapter.modem.broadcast, adapter.modem, adapter.channel, adapter.port, msg)
    end
    function adapter.poll()
      local out = {}
      if ok_event and event and event.pull then
        -- non-blocking poll: pull events with zero timeout
        while true do
          local ev, receiver, sender, port, distance, message = event.pull(0, 'modem_message')
          if not ev then break end
          table.insert(out, { from = sender, port = port, msg = message })
        end
      end
      return out
    end
    return adapter
  end

  -- fallback mock adapter
  local adapter = {}
  adapter.channel = cfg and cfg.channel or 123
  function adapter.send_heartbeat() end
  function adapter.send(msg) end
  function adapter.poll() return {} end
  return adapter
end

return M
