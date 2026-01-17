local component = require("component")
local event = require("event")
local serialization = require("serialization")
local term = require("term")

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

local communicator = nil
local injector = nil
local absorber = nil

local function detect()
  communicator = config.communicator and component.proxy(config.communicator) or find_component_by_type("dfc_communicator")
  injector = config.injector and component.proxy(config.injector) or find_component_by_type("dfc_injector")
  absorber = config.absorber and component.proxy(config.absorber) or find_component_by_type("dfc_absorber")
end

local function analyze()
  if not communicator then return nil end
  local ok, data = pcall(function() return communicator.analyze() end)
  if ok and data then return data end
  -- fallback minimal fields
  local status = {}
  status.level = safe_call(communicator.getLevel)
  status.power = safe_call(communicator.getPower)
  status.maxPower = safe_call(communicator.getMaxPower)
  status.charge = safe_call(communicator.getChargePercent)
  return status
end

local function set_level(level)
  if not communicator then return false, "no communicator" end
  -- try numeric, then table style
  local ok
  ok = pcall(function() communicator.setLevel(level) end)
  if ok then return true end
  ok = pcall(function() communicator.setLevel({level = level}) end)
  if ok then return true end
  return false, "setLevel failed"
end

local function get_absorber_status()
  if not absorber then return nil end
  local t = {}
  t.level = safe_call(absorber.getLevel)
  t.storedCoolant = safe_call(absorber.storedCoolant)
  t.getStress = safe_call(absorber.getStress)
  return t
end

local function get_injector_status()
  if not injector then return nil end
  local t = {}
  t.fuel = safe_call(injector.getFuel)
  t.types = safe_call(injector.getTypes)
  t.info = safe_call(injector.getInfo)
  return t
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
  local s = {}
  s.analyze = analyze()
  s.absorber = get_absorber_status()
  s.injector = get_injector_status()
  return s
end

local function check_safety_and_act(status)
  if not status then return end
  -- try to read stress
  local stress
  if status.absorber and status.absorber.getStress then
    stress = status.absorber.getStress
  elseif status.analyze and status.analyze.stress then
    stress = status.analyze.stress
  end
  if stress and tonumber(stress) and config.maxStress and tonumber(config.maxStress) then
    if stress >= config.maxStress then
      print("[SAFETY] stress " .. tostring(stress) .. " >= maxStress, shutting down")
      set_level(0)
      return true
    end
  end
  return false
end

local function monitor_loop()
  detect()
  if not communicator then print("No dfc_communicator found") return end
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
  print("  monitor       - continuous monitoring + safety shutdown")
  print("  detect        - show which components were found")
end

-- main CLI
local cmd = ...
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
elseif cmd == "describe" then
  -- safe introspection helper: lists methods for detected components and
  -- attempts to call non-mutating getter-like methods to show sample outputs.
  detect()
  local function describe_component(name, proxy)
    if not proxy then
      print(name .. ": none")
      return
    end
    print("--- " .. name .. " (" .. tostring(proxy.address) .. ") ---")
    local methods = component.methods(proxy.address) or {}
    table.sort(methods)
    for _, m in ipairs(methods) do
      -- skip likely-mutating methods (set/activate/start/stop/inject/eject/remove/add)
      if not (string.sub(m,1,3) == "set" or string.find(m, "inject") or string.find(m, "eject") or string.find(m, "remove") or string.find(m, "add") or string.find(m, "start") or string.find(m, "activate") or string.find(m, "stop")) then
        io.write(" - " .. m .. ": ")
        local ok, res = pcall(function()
          -- attempt calling without arguments; many component getters work this way
          return proxy[m]()
        end)
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

  describe_component("Communicator", communicator)
  describe_component("Injector", injector)
  describe_component("Absorber", absorber)

elseif cmd == "detect" then
  print("Communicator: " .. tostring(communicator and communicator.address or "none"))
  print("Injector: " .. tostring(injector and injector.address or "none"))
  print("Absorber: " .. tostring(absorber and absorber.address or "none"))
else
  usage()
end
