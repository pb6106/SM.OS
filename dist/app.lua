-- app.lua
local display = require('display')
local core_reactor = require('core.reactor')
local files = require('files')

local M = {}

-- Scheduler and task management (cooperative coroutines)
local tasks = {}
local function spawn(fn)
  local co = coroutine.create(fn)
  table.insert(tasks, co)
  return co
end

local function run_tasks()
  local i = 1
  while i <= #tasks do
    local co = tasks[i]
    local ok, err = coroutine.resume(co)
    if not ok then
      -- task errored; remove and log
      io.stderr:write('Task error: ' .. tostring(err) .. '\n')
      table.remove(tasks, i)
    else
      if coroutine.status(co) == 'dead' then
        table.remove(tasks, i)
      else
        i = i + 1
      end
    end
  end
end

-- Simple command and inbound queues
local command_queue = {}
local inbound_queue = {}
local function enqueue_command(cmd)
  table.insert(command_queue, cmd)
end
local function dequeue_command()
  return table.remove(command_queue, 1)
end
local function enqueue_inbound(msg)
  table.insert(inbound_queue, msg)
end
local function dequeue_inbound()
  return table.remove(inbound_queue, 1)
end

function M.run()
  -- initialize subsystems
  files.init()
  local cfg = files.load_config() or {}

  core_reactor.init(cfg.core)
  display.init(files.load_display_config())

  -- bind GPU adapters from config (may be a list)
  local ok_gpu, gpu_mod = pcall(require, 'adapters.gpu_adapter')
  if ok_gpu and gpu_mod and gpu_mod.bind and cfg.displays then
    for _,d in ipairs(cfg.displays) do
      local g = gpu_mod.bind(d.gpu_address or 'mockGPU', d.screen_address or 'mockScreen')
      display.bind_adapter(g)
    end
  end

  -- show stylized boot sequence if UI supports it
  if display.ui and display.ui.reactor and display.ui.reactor.boot then
    pcall(display.ui.reactor.boot, display, display.adapters, { subtitle = cfg.boot_subtitle, safe_start = cfg.safe_start })
  end

  -- network adapter (modem) for heartbeat/commands
  local network = nil
  local ok_net, net_mod = pcall(require, 'adapters.network_adapter')
  if ok_net and net_mod and net_mod.connect then
    network = net_mod.connect(cfg.network)
  end

  -- attach ntm adapter to reactor if present
  local ok_ntm, ntm_mod = pcall(require, 'adapters.ntm_adapter')
  if ok_ntm and ntm_mod and ntm_mod.connect then
    local ntm = ntm_mod.connect(cfg.ntm_address)
    if ntm and core_reactor.attach then core_reactor.attach(ntm) end
  end

  -- Task: core tick
  spawn(function()
    while true do
      local status, reason = core_reactor.tick()
      local st = core_reactor.get_state()
      display.render_reactor(st)
      if status and status ~= 'ok' then
        io.stderr:write('Reactor status: ' .. tostring(status) .. ' ' .. tostring(reason) .. '\n')
      end
      coroutine.yield()
    end
  end)

  -- Task: network tick (poll inbound messages, send heartbeat)
  if network then
    spawn(function()
      while true do
        -- poll inbound
        local msgs = network.poll and network.poll() or {}
        for _,m in ipairs(msgs) do enqueue_inbound(m) end
        -- send heartbeat
        if network.send_heartbeat then network.send_heartbeat() end
        coroutine.yield()
      end
    end)
  end

  -- Task: inbound processing
  spawn(function()
    while true do
      local msg = dequeue_inbound()
      if msg then
        -- handle control messages
        if msg.type == 'cmd' and msg.action == 'restart' then
          io.stderr:write('Received restart command; exiting for external restart\n')
          os.exit(1)
        end
      end
      coroutine.yield()
    end
  end)

  -- scheduler main loop
  while true do
    run_tasks()
    -- process command queue (send to network if needed)
    local cmd = dequeue_command()
    if cmd and network and network.send then network.send(cmd) end
    os.sleep(cfg.tick_delay or 0.5)
  end
end

return M
