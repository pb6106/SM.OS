local component = require("component")

local M = {}

local function safe_call(fn, ...)
  if not fn then return nil end
  local ok, res = pcall(fn, ...)
  if not ok then return nil end
  return res
end

local function find_components_by_type(t)
  local out = {}
  for addr, tp in component.list(t) do
    table.insert(out, component.proxy(addr))
  end
  return out
end

-- detect returns lists (arrays) of proxies for each type
function M.detect(config)
  local communicators = {}
  local injectors = {}
  local absorbers = {}
  local emitters = {}
  if config.communicator then
    table.insert(communicators, component.proxy(config.communicator))
  else
    communicators = find_components_by_type("dfc_communicator")
  end
  if config.injector then
    table.insert(injectors, component.proxy(config.injector))
  else
    injectors = find_components_by_type("dfc_injector")
  end
  if config.absorber then
    table.insert(absorbers, component.proxy(config.absorber))
  else
    absorbers = find_components_by_type("dfc_absorber")
  end
  if config.emitter then
    table.insert(emitters, component.proxy(config.emitter))
  else
    emitters = find_components_by_type("dfc_emitter")
  end
  return communicators, injectors, absorbers, emitters
end

-- analyze can accept a single proxy or a list; returns list of results
function M.analyze(communicators)
  if not communicators then return nil end
  local list = {}
  if type(communicators) ~= "table" then communicators = {communicators} end
  for _, c in ipairs(communicators) do
    if not c then table.insert(list, nil) else
      local ok, data = pcall(function() return c.analyze and c.analyze() end)
      if ok and data then
        table.insert(list, data)
      else
        local status = {}
        status.level = safe_call(c.getLevel)
        status.power = safe_call(c.getPower)
        status.maxPower = safe_call(c.getMaxPower)
        status.charge = safe_call(c.getChargePercent)
        table.insert(list, status)
      end
    end
  end
  return list
end

function M.set_level(communicators, level, preferredAddress)
  if not communicators then return false, "no communicator" end
  if type(communicators) ~= "table" then communicators = {communicators} end
  local anyOk = false
  -- if preferredAddress provided, try that first
  if preferredAddress then
    for _, c in ipairs(communicators) do
      if c and c.address == preferredAddress then
        local ok = pcall(function() c.setLevel(level) end)
        if ok then return true end
        ok = pcall(function() c.setLevel({level = level}) end)
        if ok then return true end
      end
    end
  end
  for _, c in ipairs(communicators) do
    if c then
      local ok = pcall(function() c.setLevel(level) end)
      if ok then anyOk = true end
      ok = pcall(function() c.setLevel({level = level}) end)
      if ok then anyOk = true end
    end
  end
  if anyOk then return true end
  return false, "setLevel failed"
end

function M.get_absorber_status(absorbers)
  if not absorbers then return nil end
  if type(absorbers) ~= "table" then absorbers = {absorbers} end
  local out = {}
  for _, a in ipairs(absorbers) do
    if not a then table.insert(out, nil) else
      local t = {}
      t.level = safe_call(a.getLevel)
      t.storedCoolant = safe_call(a.storedCoolant)
      t.getStress = safe_call(a.getStress)
      table.insert(out, t)
    end
  end
  return out
end

function M.get_injector_status(injectors)
  if not injectors then return nil end
  if type(injectors) ~= "table" then injectors = {injectors} end
  local out = {}
  for _, inj in ipairs(injectors) do
    if not inj then table.insert(out, nil) else
      local t = {}
      t.fuel = safe_call(inj.getFuel)
      t.types = safe_call(inj.getTypes)
      t.info = safe_call(inj.getInfo)
      table.insert(out, t)
    end
  end
  return out
end

function M.get_emitter_status(emitters)
  if not emitters then return nil end
  if type(emitters) ~= "table" then emitters = {emitters} end
  local out = {}
  for _, e in ipairs(emitters) do
    if not e then table.insert(out, nil) else
      local t = {}
      -- probe common getter-like methods safely
      t.power = safe_call(e.getPower)
      t.active = safe_call(e.isActive) or safe_call(e.getActive)
      t.range = safe_call(e.getRange)
      t.info = safe_call(e.getInfo)
      table.insert(out, t)
    end
  end
  return out
end

-- build_status returns lists for analyze/absorber/injector and a summary
function M.build_status(communicators, injectors, absorbers, emitters)
  local s = {}
  s.analyze = M.analyze(communicators)
  s.absorber = M.get_absorber_status(absorbers)
  s.injector = M.get_injector_status(injectors)
  s.emitter = M.get_emitter_status(emitters)
  -- compute summary: max stress across absorbers
  local maxStress = nil
  if s.absorber then
    for _, a in ipairs(s.absorber) do
      if a and a.getStress and tonumber(a.getStress) then
        local v = tonumber(a.getStress)
        if not maxStress or v > maxStress then maxStress = v end
      end
    end
  end
  s.summary = { maxStress = maxStress }
  -- detect stabilizer info if present in analyze data
  local stabilizers = {}
  if s.analyze then
    for idx, ad in ipairs(s.analyze) do
      if type(ad) == "table" then
        -- look for fields mentioning stabilizer(s)
        if ad.stabilizers then
          stabilizers[idx] = ad.stabilizers
        elseif ad.stabilizer then
          stabilizers[idx] = ad.stabilizer
        end
      end
    end
  end
  if next(stabilizers) then s.stabilizers = stabilizers end
  return s
end

-- check safety: use maxStress from summary when available; act on communicators
function M.check_safety_and_act(status, config, communicators)
  if not status then return end
  local stress = nil
  if status.summary and status.summary.maxStress then
    stress = status.summary.maxStress
  else
    -- fallback: try first absorber
    if status.absorber and status.absorber[1] and status.absorber[1].getStress then
      stress = status.absorber[1].getStress
    elseif status.analyze and status.analyze[1] and status.analyze[1].stress then
      stress = status.analyze[1].stress
    end
  end
  if stress and tonumber(stress) and config.maxStress and tonumber(config.maxStress) then
    if stress >= config.maxStress then
      -- attempt to shut down (use preferred communicator if set)
      local preferred = config.primaryCommunicator
      M.set_level(communicators, 0, preferred)
      return true, stress
    end
  end
  return false, stress
end

return M
