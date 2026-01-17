local component = require("component")
local serialization = require("serialization")
local term = require("term")
local dfc = require("dfc_lib")

local event = require("event")

-- try load config (optional)
local config = {
  targetLevel = 75,
  pollInterval = 2,
  maxStress = 0.9,
  communicator = nil,
  injector = nil,
  absorber = nil,
}
pcall(function() local c = dofile("config.lua"); for k,v in pairs(c) do config[k]=v end end)

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
    local stopped, stress = check_safety_and_act(s)
    if stopped then
      print("[AUTO] Reactor shut down due to stress: "..tostring(stress))
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
else
  usage()
end

