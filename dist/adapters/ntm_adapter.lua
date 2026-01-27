-- adapters/ntm_adapter.lua
-- NTM adapter stub: translates core reactor API to OpenComputers messages

local M = {}

-- Adapter that prefers real OpenComputers `component` binding when available,
-- otherwise falls back to the test mock `oc_mocks.ntm_mock`.

local function use_component()
  local ok, comp = pcall(require, 'component')
  if ok and comp and type(comp.proxy) == 'function' then return comp end
  return nil
end

function M.connect(addr)
  local comp = use_component()
  if comp and addr then
    -- Bind to real component
    local ok, dev = pcall(comp.proxy, addr)
    if not ok or not dev then return nil, 'proxy_failed' end
    local adapter = {}
    adapter._dev = dev
    function adapter.query(self)
      -- try several common methods exposed by NTM/DFC devices and normalize
      local tel = {}
      if dev.getInfo then
        local ok2, info = pcall(dev.getInfo, dev)
        if ok2 and type(info) == 'table' then
          -- best-effort mapping: many devices return lists; try to read known positions
          tel.info = info
        end
      end
      if dev.getLevel then
        local ok3, level = pcall(dev.getLevel, dev)
        if ok3 then tel.level = level end
      end
      if dev.getPower then
        local ok4, power = pcall(dev.getPower, dev)
        if ok4 then tel.power = power end
      end
      if dev.getMaxPower then
        local ok5, mp = pcall(dev.getMaxPower, dev)
        if ok5 then tel.maxPower = mp end
      end
      if dev.getStress then
        local ok6, st = pcall(dev.getStress, dev)
        if ok6 then tel.stress = st end
      end
      if dev.getDurability then
        local ok7, d = pcall(dev.getDurability, dev)
        if ok7 then tel.stabilizer_durability = d end
      end
      return tel
    end
    function adapter.command(self, cmd, params)
      if cmd == 'setLevel' and dev.setLevel then
        return pcall(dev.setLevel, dev, params.level)
      elseif cmd == 'start' and dev.setActive then
        return pcall(dev.setActive, dev, true)
      elseif cmd == 'stop' and dev.setActive then
        return pcall(dev.setActive, dev, false)
      elseif dev[cmd] then
        return pcall(dev[cmd], dev, params)
      end
      return false
    end
    return adapter
  end

  -- fallback to mock adapter
  local okm, mock = pcall(require, 'oc_mocks.ntm_mock')
  if okm and mock and mock.connect then
    return mock.connect(addr)
  end

  return nil, 'no_adapter_available'
end

return M
