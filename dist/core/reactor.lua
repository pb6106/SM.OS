-- core/reactor.lua
-- Pure reactor-control logic with safety checks (unit-testable)

local M = {}

local adapter = nil
local cfg = {
  max_level = 100,
  safe_stress_threshold = 0.8, -- fraction (80%)
  max_rate_per_second = 20, -- maximum allowed change in level per second
}

local state = {
  level = 0,
  running = false,
  last_change_time = 0,
  last_level = 0,
  last_telemetry = {},
}

function M.init(config)
  if config then
    for k,v in pairs(config) do cfg[k]=v end
  end
  state = {
    level = 0,
    running = false,
    last_change_time = os.time(),
    last_level = 0,
    last_telemetry = {},
  }
end

function M.attach(adapter_obj)
  adapter = adapter_obj
end

local function now()
  return os.time()
end

local function check_rate_limit(desired_level)
  local t = now()
  local dt = math.max(1, t - state.last_change_time)
  local max_delta = cfg.max_rate_per_second * dt
  local delta = math.abs(desired_level - state.last_level)
  return delta <= max_delta
end

local function safe_with_telemetry(tel, desired_level)
  if not tel then return true end
  if tel.stress and tel.maxStress then
    local frac = tel.stress / (tel.maxStress ~= 0 and tel.maxStress or 1)
    if frac >= cfg.safe_stress_threshold then
      return false, 'stress_exceeded'
    end
  elseif tel.stress and tel.maxStress==nil then
    -- if we have stress but no max, use threshold on absolute value conservatively
    if tel.stress >= cfg.safe_stress_threshold then return false, 'stress_high' end
  end
  if tel.level and tel.maxPower and desired_level > (tel.maxPower or cfg.max_level) then
    return false, 'exceeds_power'
  end
  return true
end

function M.set_level(desired_level)
  desired_level = math.max(0, math.min(cfg.max_level, desired_level))
  -- rate limit
  if not check_rate_limit(desired_level) then
    return false, 'rate_limited'
  end
  -- get telemetry if available
  local tel = nil
  if adapter and adapter.query then
    tel = adapter.query(adapter)
    state.last_telemetry = tel
  end
  local ok, reason = safe_with_telemetry(tel, desired_level)
  if not ok then
    return false, reason
  end
  -- send command
  if adapter and adapter.command then
    local success = adapter.command(adapter, 'setLevel', { level = desired_level })
    if not success then return false, 'adapter_failed' end
  end
  state.last_level = state.level
  state.level = desired_level
  state.last_change_time = now()
  return true
end

function M.start()
  -- set running flag and attempt to validate/start via adapter
  if adapter and adapter.command then
    local ok = adapter.command(adapter, 'start', {})
    if not ok then return false, 'adapter_failed' end
  end
  state.running = true
  return true
end

function M.stop()
  if adapter and adapter.command then
    local ok = adapter.command(adapter, 'stop', {})
    if not ok then return false, 'adapter_failed' end
  end
  state.running = false
  return true
end

function M.tick()
  -- poll telemetry periodically
  if adapter and adapter.query then
    local tel = adapter.query(adapter)
    state.last_telemetry = tel or {}
    -- emergency conditions
    if tel then
      if tel.stress and tel.maxStress and (tel.stress / tel.maxStress) >= 0.98 then
        -- emergency shutdown
        M.stop()
        return 'emergency_stop', 'stress_critical'
      end
      -- stabilizer durability monitoring: if durability present and below threshold, shutdown
      if tel.stabilizer_durability then
        local dur = tel.stabilizer_durability
        local thresh = cfg.stabilizer_durability_threshold or 10 -- percent
        if dur <= thresh then
          -- emergency shutdown due to low stabilizer durability
          M.stop()
          return 'emergency_stop', 'stabilizer_durability_low'
        end
      end
    end
  end
  return 'ok'
end

function M.get_state()
  return {
    level = state.level,
    running = state.running,
    telemetry = state.last_telemetry,
  }
end

return M
