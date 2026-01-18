local component = require("component")
local term = require("term")
local unicode = require("unicode")

local M = {}

-- Render ASCII art to all attached monitors (GPUs bound to screens).
-- lines: array of strings
-- duration: seconds to keep the art on-screen (0 = don't sleep)
-- opts: table with optional fields: fg, bg (colors as numbers)
function M.show_art(lines, duration, opts)
  duration = duration or 5
  opts = opts or {}
  local fg = opts.fg or 0xFFFFFF
  local bg = opts.bg or 0x000000

  local gpu_addrs = {}
  for addr in component.list("gpu") do gpu_addrs[#gpu_addrs+1] = addr end
  local screen_addrs = {}
  for addr in component.list("screen") do screen_addrs[#screen_addrs+1] = addr end
  -- if opts.screen provided, filter to that single screen address
  if opts and opts.screen then
    local s = tostring(opts.screen)
    local found = false
    for _, a in ipairs(screen_addrs) do if tostring(a) == s then found = true; screen_addrs = {a}; break end end
    if not found then
      -- don't fail hard: just leave screen_addrs as-is so fallback will use terminal
    end
  end

  if #gpu_addrs == 0 or #screen_addrs == 0 then
    -- Fallback: print to the current term
    local old = term.current()
    term.clear()
    for _,ln in ipairs(lines) do
      io.write(ln .. "\n")
    end
    if duration > 0 then os.sleep(duration) end
    return true
  end

  for _, gpuAddr in ipairs(gpu_addrs) do
    local gpu = component.proxy(gpuAddr)
    local ok, prevScreen = pcall(gpu.getScreen)
    for _, screenAddr in ipairs(screen_addrs) do
    pcall(gpu.bind, screenAddr)
      -- try to pick a reasonable resolution
      local w,h
      local okMax, mw, mh = pcall(gpu.maxResolution)
      if okMax and mw and mh then
        w,h = mw,mh
        pcall(gpu.setResolution, w, h)
      else
        local okCur, cw, ch = pcall(gpu.getResolution)
        if okCur and cw and ch then w,h = cw,ch end
      end
      w = w or 80; h = h or 25

      pcall(gpu.setBackground, bg)
      pcall(gpu.setForeground, fg)
      pcall(gpu.fill, 1, 1, w, h, " ")

      local startY = math.floor((h - #lines) / 2) + 1
      for i = 1, #lines do
        local s = lines[i] or ""
        local len = unicode.len(s)
        local x = math.floor((w - len) / 2) + 1
        if x < 1 then x = 1 end
        pcall(gpu.set, x, startY + i - 1, s)
      end

      if duration > 0 then os.sleep(duration) end
    end
    if ok and prevScreen then pcall(gpu.bind, prevScreen) end
  end
  return true
end

function M.show_art_from_file(path, duration, opts)
  local f, err = io.open(path, "r")
  if not f then return nil, err end
  local lines = {}
  for line in f:lines() do lines[#lines+1] = line end
  f:close()
  return M.show_art(lines, duration, opts)
end

return M
