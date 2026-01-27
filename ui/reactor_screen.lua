-- ui/reactor_screen.lua
-- Render reactor state to a display abstraction. Minimal textual layout for OpenComputers.

local M = {}

-- Render a compact reactor overview onto a display adapter list.
-- `display` is expected to provide `draw_text(adapter, x, y, text)` and `clear(adapter)`.
function M.render(display, adapters, state)
  local s = state or {}
  local st = s.telemetry or {}
  local title = 'DFC Reactor'
  local lines = {}
  table.insert(lines, title)
  table.insert(lines, '')
  table.insert(lines, string.format('Running: %s', tostring(s.running)))
  table.insert(lines, string.format('Level: %s', tostring(s.level)))
  if st.power then table.insert(lines, string.format('Power: %.1f / %.1f', st.power or 0, st.maxPower or 0)) end
  if st.stress then table.insert(lines, string.format('Stress: %.2f / %.2f', st.stress or 0, st.maxStress or 0)) end
  if st.stabilizer_durability then table.insert(lines, string.format('Stab Dur: %s%%', tostring(st.stabilizer_durability))) end
  table.insert(lines, '')
  table.insert(lines, 'Commands: set_level(start/stop)')

  -- For simplicity, render same text on all adapters. A future enhancement can stitch images.
  for _,ad in ipairs(adapters or {}) do
    if display.clear then display.clear(ad) end
    for i,line in ipairs(lines) do
      if display.draw_text then display.draw_text(ad, 1, i, line) end
    end
  end
end

-- Stylized boot sequence: animated title, status lines and progress bar
function M.boot(display, adapters, opts)
  opts = opts or {}
  local title = 'DFC Reactor OS'
  local subtitle = opts.subtitle or 'Dark Fusion Core Controller'
  local steps = {
    'Loading configuration',
    'Initializing displays',
    'Connecting network',
    'Attaching reactor adapter',
    'Running self-checks',
  }

  for _,ad in ipairs(adapters or {}) do
    if display.clear then display.clear(ad) end
  end

  -- animate title
  for i = 1, #title do
    local part = title:sub(1, i)
    for _,ad in ipairs(adapters or {}) do
      if display.draw_text then display.draw_text(ad, 2, 1, part) end
    end
    os.sleep(0.03)
  end
  for _,ad in ipairs(adapters or {}) do
    if display.draw_text then display.draw_text(ad, 2, 2, subtitle) end
  end
  os.sleep(0.25)

  -- status lines with progress
  local line_y = 4
  for idx, s in ipairs(steps) do
    for _,ad in ipairs(adapters or {}) do
      if display.draw_text then display.draw_text(ad, 2, line_y, string.format('%d/%d: %s', idx, #steps, s)) end
    end
    -- simple progress bar
    for p = 0, 20 do
      local bar = string.rep('#', p) .. string.rep('-', 20 - p)
      for _,ad in ipairs(adapters or {}) do
        if display.draw_text then display.draw_text(ad, 2, line_y+1, '[' .. bar .. '] ' .. tostring(math.floor((p/20)*100)) .. '%') end
      end
      os.sleep(0.02)
    end
    line_y = line_y + 3
  end

  -- final status
  for _,ad in ipairs(adapters or {}) do
    if display.draw_text then display.draw_text(ad, 2, line_y, 'Boot complete.') end
  end
  os.sleep(0.5)
end

return M
