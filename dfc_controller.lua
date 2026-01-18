local component = require("component")
local serialization = require("serialization")
local term = require("term")
local dfc = require("dfc_lib")

local event = require("event")

local config = {
  targetLevel = 75,
  pollInterval = 2,
  maxStress = 0.9,
  communicator = nil,
  injector = nil,
  absorber = nil,
}
pcall(function() local c = dofile("config.lua"); for k,v in pairs(c) do config[k]=v end end)
-- discovered remote display agents (address->timestamp)
local discoveredAgents = {}

-- listen for agent registrations
local function agent_message_handler(_, _, sender, port, _, raw)
  if not raw then return end
  local ok, msg = pcall(serialization.unserialize, raw)
  if not ok or type(msg) ~= "table" then return end
  if msg.cmd == "register" then
    discoveredAgents[sender] = os.time()
    print("Registered display agent: "..tostring(sender))
  end
end

pcall(function()
  for p in component.list("modem") do
    local modem = component.proxy(p)
    pcall(modem.open, config.displayPort or 12345)
  end
  event.listen("modem_message", agent_message_handler)
end)

-- remove stale agents older than expiry seconds
local function prune_agents()
  local expiry = tonumber(config.agentExpiry) or 300
  local now = os.time()
  for addr, t in pairs(discoveredAgents) do
    if now - t > expiry then discoveredAgents[addr] = nil end
  end
end

-- CLI helper to list discovered agents
local function list_agents()
  prune_agents()
  print("Discovered display agents:")
  local any = false
  for addr, t in pairs(discoveredAgents) do
    print(" - "..addr.." (last seen "..tostring(os.date("%Y-%m-%d %H:%M:%S", t))..")")
    any = true
  end
  if not any then print(" (none)") end
end


local function safe_call(fn, ...)
  if not fn then return nil end
  local ok, res = pcall(fn, ...)
  if not ok then return nil end
  return res
end

local function find_component_by_type(t)
  for addr, tp in component.list(t) do
    return component.proxy(addr)
  end
  return nil
end

local communicators, injectors, absorbers, emitters

local function detect()
  communicators, injectors, absorbers, emitters = dfc.detect(config)
end

local function analyze()
  return dfc.analyze(communicators)
end

local function set_level(level)
  return dfc.set_level(communicators, level, config.primaryCommunicator)
end

local function get_absorber_status()
  return dfc.get_absorber_status(absorbers)
end

local function get_injector_status()
  return dfc.get_injector_status(injectors)
end

local function get_emitter_status()
  return dfc.get_emitter_status(emitters)
end

local function pretty_print_status(s)
  print("--- DFC Status ---")
  for k,v in pairs(s) do
    if type(v) == "table" then
      print(k .. ": " .. serialization.serialize(v))
    else
      print(k .. ": " .. tostring(v))
    end
  end
end

-- optional local display helper (may not exist on controller)
local ok_display, dfc_display = pcall(require, "dfc_display")

local function send_art_broadcast(lines, duration)
  -- show locally if available
  if ok_display and dfc_display then
    local localOpts = { fg = config.displayFG or 0xFFFFFF, bg = config.displayBG or 0x000000 }
    if config.controllerScreen then localOpts.screen = config.controllerScreen end
    pcall(dfc_display.show_art, lines, duration, localOpts)
  end
  -- send to configured remote agents via modem
  if component and next(component.list("modem")) then
    local modem = component.proxy((next(component.list("modem"))))
    local port = tonumber(config.displayPort) or 12345
    local token = config.displayToken
    local msg = { token = token, cmd = "show_art", args = { lines = lines, duration = duration, opts = {} } }
    local okSer, s = pcall(serialization.serialize, msg)
    if not okSer then return false, "serialize_failed" end
    local targets = {}
    if config.displayAgents and type(config.displayAgents) == "table" and #config.displayAgents > 0 then
      targets = config.displayAgents
    else
      for addr,_ in pairs(discoveredAgents) do targets[#targets+1] = addr end
    end
    for _, addr in ipairs(targets) do
      pcall(modem.open, port)
      pcall(modem.send, addr, port, s)
    end
  end
  return true
end

local function send_status_broadcast(status)
  if component and next(component.list("modem")) then
    local modem = component.proxy((next(component.list("modem"))))
    local port = tonumber(config.displayPort) or 12345
    local token = config.displayToken
    -- send a serializable summary rather than raw status (which may contain proxies)
    local summary = status_to_lines(status)
    local msg = { token = token, cmd = "status_update", args = { summary = summary } }
    local okSer, s = pcall(serialization.serialize, msg)
    if not okSer then return false end
    local targets = {}
    if config.displayAgents and type(config.displayAgents) == "table" and #config.displayAgents > 0 then
      targets = config.displayAgents
    else
      for addr,_ in pairs(discoveredAgents) do targets[#targets+1] = addr end
    end
    for _, addr in ipairs(targets) do pcall(modem.open, port); pcall(modem.send, addr, port, s) end
  end
  return true
end

local function status_to_lines(s)
  local lines = {}
  if s.analyze and s.analyze.level then
    lines[#lines+1] = string.format("Level: %s", tostring(s.analyze.level))
  end
  if s.analyze and s.analyze.stress then
    lines[#lines+1] = string.format("Stress: %s", tostring(s.analyze.stress))
  end
  if s.absorber and type(s.absorber) == "table" then
    if s.absorber.getStress then lines[#lines+1] = string.format("Absorber stress: %s", tostring(s.absorber.getStress)) end
  end
  if s.injector and type(s.injector) == "table" then
    if s.injector.getAmount then lines[#lines+1] = string.format("Injector amount: %s", tostring(s.injector.getAmount)) end
  end
  if s.emitters and type(s.emitters) == "table" and #s.emitters > 0 then
    for i,e in ipairs(s.emitters) do
      local prefix = string.format("Emitter[%d]:", i)
      if e.address then lines[#lines+1] = prefix .. " " .. tostring(e.address) end
    end
  end
  -- fallback: serialize short summary
  if #lines == 0 then lines[#lines+1] = serialization.serialize(s) end
  return lines
end

local function build_status()
  return dfc.build_status(communicators, injectors, absorbers, emitters)
end

local function check_safety_and_act(status)
  return dfc.check_safety_and_act(status, config, communicators)
end

local function monitor_loop()
  detect()
  if not communicators or #communicators == 0 then print("No dfc_communicator found") return end
  print("Starting monitor loop (poll interval: "..tostring(config.pollInterval).."s)")
  while true do
    local s = build_status()
    pretty_print_status(s)
    -- broadcast status to displays/agents
    local lines = status_to_lines(s)
    pcall(send_art_broadcast, lines, 0)
    pcall(send_status_broadcast, s)
    local stopped = check_safety_and_act(s)
    if stopped then break end
    os.sleep(tonumber(config.pollInterval) or 2)
  end
end

local function usage()
  print("Usage: dfc_controller.lua [command]")
  print("Commands:")
  print("  start         - set reactor to targetLevel from config")
  print("  stop          - set reactor level to 0")
  print("  status        - print current status")
  print("  describe      - list component methods and sample (non-mutating) outputs")
  print("  auto [preset] - automatic safety + restart loop (opt-in); optional preset from config")
  print("  autopresets   - list available AUTO presets from config.lua")
  print("  monitor       - continuous monitoring + safety shutdown")
  print("  detect        - show which components were found")
end

-- main CLI
local cmd, preset = ...
if not cmd then usage() return end
detect()
if cmd == "start" then
  local ok,err = set_level(config.targetLevel)
  if ok then print("Started: level="..tostring(config.targetLevel)) else print("Start failed: "..tostring(err)) end
elseif cmd == "stop" then
  local ok,err = set_level(0)
  if ok then print("Stopped") else print("Stop failed: "..tostring(err)) end
elseif cmd == "status" then
  local s = build_status()
  pretty_print_status(s)
elseif cmd == "monitor" then
  monitor_loop()
elseif cmd == "auto" then
  detect()
  if not communicators or #communicators == 0 then print("No dfc_communicator found") return end
  if preset and config.presets and config.presets[preset] then
    for k,v in pairs(config.presets[preset]) do config[k]=v end
    print("Using AUTO preset: "..tostring(preset))
  elseif preset then
    print("AUTO preset not found: "..tostring(preset))
  end
  print("Starting AUTO mode (poll: "..tostring(config.pollInterval).."s, maxStress: "..tostring(config.maxStress)..")")
  local resumeFactor = config.resumeFactor or 0.8
  local restartDelay = config.autoRestartDelay or 5
  while true do
    local s = build_status()
    pretty_print_status(s)
    -- broadcast status to displays/agents while in AUTO
    local lines = status_to_lines(s)
    pcall(send_art_broadcast, lines, 0)
    pcall(send_status_broadcast, s)
    local stopped, stress = check_safety_and_act(s)
    if stopped then
      print("[AUTO] Reactor shut down due to stress: "..tostring(stress))
        -- show configured ASCII art on monitors/agents if requested
        if config.displayArtFile then
          local f = io.open(config.displayArtFile, "r")
          if f then
            local lines = {}
            for line in f:lines() do lines[#lines+1] = line end
            f:close()
            local dur = tonumber(config.displayDuration) or 10
            local ok, err = send_art_broadcast(lines, dur)
            if ok then print("[AUTO] display sent to agents/local monitors") else print("[AUTO] display failed: "..tostring(err)) end
          else
            print("[AUTO] display file not found: "..tostring(config.displayArtFile))
          end
        end
      -- wait for stress to drop below resume threshold
      local resumeThreshold = (tonumber(config.resumeStress) or (tonumber(config.maxStress) * resumeFactor))
      print("[AUTO] waiting until stress < "..tostring(resumeThreshold))
      while true do
        os.sleep(tonumber(config.pollInterval) or 2)
        local s2 = build_status()
        local curStress = nil
        if s2.absorber and s2.absorber.getStress then curStress = s2.absorber.getStress
        elseif s2.analyze and s2.analyze.stress then curStress = s2.analyze.stress end
        if curStress and tonumber(curStress) and tonumber(curStress) < resumeThreshold then
          print("[AUTO] stress recovered ("..tostring(curStress)..") — waiting "..tostring(restartDelay).."s then attempting restart")
          os.sleep(restartDelay)
          local ok, err = set_level(config.targetLevel)
          if ok then print("[AUTO] restarted to level "..tostring(config.targetLevel)) else print("[AUTO] restart failed: "..tostring(err)) end
          break
        else
          print("[AUTO] still high: "..tostring(curStress))
        end
      end
    end
    os.sleep(tonumber(config.pollInterval) or 2)
  end
elseif cmd == "describe" then
  -- safe introspection helper: lists methods for detected components and
  -- attempts to call non-mutating getter-like methods to show sample outputs.
  detect()
  local function describe_list(name, list)
    if not list or #list == 0 then
      print(name .. ": none")
      return
    end
    for i, proxy in ipairs(list) do
      if not proxy then
        print(name .. "["..tostring(i).."]: nil")
      else
        print("--- " .. name .. "["..tostring(i) .. "] (" .. tostring(proxy.address) .. ") ---")
        local methods = component.methods(proxy.address) or {}
        table.sort(methods)
        for _, m in ipairs(methods) do
          if not (string.sub(m,1,3) == "set" or string.find(m, "inject") or string.find(m, "eject") or string.find(m, "remove") or string.find(m, "add") or string.find(m, "start") or string.find(m, "activate") or string.find(m, "stop")) then
            io.write(" - " .. m .. ": ")
            local ok, res = pcall(function() return proxy[m]() end)
            if ok then
              if type(res) == "table" then
                print(serialization.serialize(res))
              else
                print(tostring(res))
              end
            else
              print("<unreadable or requires args>")
            end
          else
            print(" - " .. m .. ": <skipped (mutating)>")
          end
        end
      end
    end
  end

  describe_list("Communicator", communicators)
  describe_list("Injector", injectors)
  describe_list("Absorber", absorbers)
  describe_list("Emitter", emitters)

elseif cmd == "autopresets" then
  if not config.presets then
    print("No presets defined in config.lua")
  else
    print("Available AUTO presets:")
    for name, preset in pairs(config.presets) do
      print(" - " .. name)
      if type(preset) == "table" then
        for k, v in pairs(preset) do
          print("     " .. k .. ": " .. tostring(v))
        end
      else
        print("     value: " .. tostring(preset))
      end
    end
  end

elseif cmd == "detect" then
  local function list_addrs(name, list)
    if not list or #list == 0 then
      print(name .. ": none")
      return
    end
    for i, p in ipairs(list) do
      print(name .. "["..tostring(i).."]: " .. tostring(p.address or "unknown"))
    end
  end
  list_addrs("Communicator", communicators)
  list_addrs("Injector", injectors)
  list_addrs("Absorber", absorbers)
  list_addrs("Emitter", emitters)
elseif cmd == "listagents" then
  list_agents()
elseif cmd == "sendart" then
  local addr = select(2, ...) or args and args[2] or nil
  local file = select(3, ...) or args and args[3] or nil
  if not addr or not file then
    print("Usage: sendart <address> <file> [duration] [token] [port]")
  else
    local duration = tonumber(select(4, ...)) or tonumber((args and args[4])) or 5
    local token = select(5, ...) or (args and args[5])
    local port = tonumber(select(6, ...)) or tonumber((args and args[6])) or (config.displayPort or 12345)
    local lines = {}
    local f, ferr = io.open(file, "r")
    if not f then print("Failed to open file: "..tostring(ferr)) return end
    for line in f:lines() do lines[#lines+1] = line end
    f:close()
    local msg = { token = token, cmd = "show_art", args = { lines = lines, duration = duration, opts = {} } }
    local s_ok, s = pcall(serialization.serialize, msg)
    if not s_ok then print("Failed to serialize message") return end
    local modem = component.modem
    pcall(modem.open, port)
    local ok = pcall(modem.send, addr, port, s)
    if ok then print("Sent art to "..addr.." on port "..tostring(port)) else print("Failed to send to "..addr) end
  end
else
  usage()
end

