-- oc_mocks/ntm_mock.lua
-- Mock NTM adapter for local testing

local M = {}

function M.connect(addr)
  local obj = {
    addr = addr or 'mock_ntm',
    level = 0,
    maxPower = 100,
    stress = 0,
    maxStress = 100,
    running = false,
    stabilizer_durability = 100,
  }
  function obj.query()
    return {
      level = obj.level,
      power = obj.level * (obj.maxPower / 100),
      maxPower = obj.maxPower,
      stress = obj.stress,
      maxStress = obj.maxStress,
      chargePercent = 100 - obj.level,
      stabilizer_durability = obj.stabilizer_durability,
    }
  end
  function obj.command(cmd, params)
    if cmd == 'setLevel' and params and params.level then
      obj.level = params.level
      return true
    elseif cmd == 'start' then
      obj.running = true
      return true
    elseif cmd == 'stop' then
      obj.running = false
      return true
    end
    return false
  end
  -- adapter wrapper to match adapter interface used by core/reactor
  local adapter = {}
  function adapter.query(self) return obj.query() end
  function adapter.command(self, cmd, params) return obj.command(cmd, params) end
  adapter._mock_obj = obj
  return adapter
end

return M
