-- adapters/gpu_adapter.lua
-- GPU/Screen adapter stub for binding and rendering to physical screens

local M = {}
function M.bind(gpu_address, screen_address)
  local ok_comp, comp = pcall(require, 'component')
  local adapter = {}
  if ok_comp and comp then
    local gpu = nil
    if gpu_address and comp.proxy then
      local okp, dev = pcall(comp.proxy, gpu_address)
      if okp and dev then gpu = dev end
    end
    gpu = gpu or comp.gpu or {}
    function adapter:clear()
      if gpu.fill then
        local w,h = 80,25
        if gpu.getResolution then
          local gw, gh = pcall(gpu.getResolution, gpu)
          if gw and gh then w,h = gw, gh end
        end
        pcall(gpu.fill, gpu, 1,1, w, h, ' ')
      else
        print(string.format('[gpu_adapter] clear screen %s', tostring(screen_address)))
      end
    end
    function adapter:draw_text(x,y,text)
      if gpu.set then
        pcall(gpu.set, gpu, x, y, tostring(text))
      else
        print(string.format('[gpu %s|screen %s] (%d,%d) %s', tostring(gpu_address), tostring(screen_address), x, y, text))
      end
    end
    adapter._impl = gpu
    return adapter
  end

  -- fallback
  adapter = {}
  function adapter:clear()
    print(string.format('[gpu_adapter] clear screen %s', tostring(screen_address)))
  end
  function adapter:draw_text(x,y,text)
    print(string.format('[gpu %s|screen %s] (%d,%d) %s', tostring(gpu_address), tostring(screen_address), x, y, text))
  end
  return adapter
end

function M.clear(adapter)
  if adapter and adapter.clear then return adapter:clear() end
end

function M.draw_text(adapter, x, y, text)
  if adapter and adapter.draw_text then return adapter:draw_text(x,y,text) end
end

return M
