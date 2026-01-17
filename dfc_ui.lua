local dfc = require("dfc_lib")
local serialization = require("serialization")
local term = require("term")

-- Simple terminal UI for DFC controller

local function usage()
  print("DFC UI Controls:")
  print(" s - start reactor to targetLevel")
  print(" x - stop reactor (level 0)")
  print(" r - refresh status")
  print(" d - describe detected components (safe probes)")
  print(" q - quit UI")
  print("")
end

local function pretty_print_status(s)
  print("--- DFC Status ---")
  if not s then print("No status") return end
  if s.summary and s.summary.maxStress then
    print("Max Stress: "..tostring(s.summary.maxStress))
  end
  if s.stabilizers then
    print("Stabilizers info: "..serialization.serialize(s.stabilizers))
  end
  print("\nCommunicators:")
  if s.analyze then
    for i, a in ipairs(s.analyze) do
      print("  ["..i.."] "..(a.level or "").." lvl, power="..tostring(a.power) .. ", charge="..tostring(a.charge))
    end
  else
    print("  none")
  end
  print("\nAbsorbers:")
  if s.absorber then
    for i,a in ipairs(s.absorber) do
      print("  ["..i.."] level="..tostring(a.level)..", stored="..tostring(a.storedCoolant)..", stress="..tostring(a.getStress))
    end
  else
    print("  none")
  end
  print("\nInjectors:")
  if s.injector then
    for i,inj in ipairs(s.injector) do
      print("  ["..i.."] fuel="..tostring(inj.fuel))
    end
  else
    print("  none")
  end
  print("\nEmitters:")
  if s.emitter then
    for i,e in ipairs(s.emitter) do
      print("  ["..i.."] active="..tostring(e.active)..", power="..tostring(e.power))
    end
  else
    print("  none")
  end
end

local function describe_components()
  local component = require("component")
  local serialization = require("serialization")
  for tname, ttype in pairs({Communicator="dfc_communicator", Injector="dfc_injector", Absorber="dfc_absorber", Emitter="dfc_emitter"}) do
    for addr in component.list(ttype) do
      local proxy = component.proxy(addr)
      print("--- "..tname.." ("..addr..") ---")
      local methods = component.methods(addr) or {}
      table.sort(methods)
      for _, m in ipairs(methods) do
        if not (string.sub(m,1,3) == "set" or string.find(m, "inject") or string.find(m, "eject") or string.find(m, "remove") or string.find(m, "add") or string.find(m, "start") or string.find(m, "activate") or string.find(m, "stop")) then
          io.write(" - "..m..": ")
          local ok, res = pcall(function() return proxy[m]() end)
          if ok then
            if type(res) == "table" then print(serialization.serialize(res)) else print(tostring(res)) end
          else
            print("<error/needs-args>")
          end
        else
          print(" - "..m..": <skipped (mutating)>")
        end
      end
    end
  end
end

-- main UI loop
local function main()
  print("DFC Terminal UI")
  usage()
  while true do
    io.write("command> ")
    local cmd = io.read()
    if not cmd then break end
    cmd = cmd:lower():match("^%s*(%S+)") or ""
    if cmd == "q" then break end
    if cmd == "r" then
      local communicators, injectors, absorbers, emitters = dfc.detect(pcall(dofile, "config.lua") and dofile("config.lua") or {})
      local status = dfc.build_status(communicators, injectors, absorbers, emitters)
      pretty_print_status(status)
    elseif cmd == "s" then
      local communicators = dfc.detect(pcall(dofile, "config.lua") and dofile("config.lua") or {})
      local cfg = (pcall(dofile, "config.lua") and dofile("config.lua")) or { targetLevel = 75 }
      local ok, err = dfc.set_level(communicators, cfg.targetLevel)
      if ok then print("Started") else print("Start failed: "..tostring(err)) end
    elseif cmd == "x" then
      local communicators = dfc.detect(pcall(dofile, "config.lua") and dofile("config.lua") or {})
      local ok, err = dfc.set_level(communicators, 0)
      if ok then print("Stopped") else print("Stop failed: "..tostring(err)) end
    elseif cmd == "d" then
      describe_components()
    else
      print("Unknown command")
      usage()
    end
  end
  print("Exiting UI")
end

main()
