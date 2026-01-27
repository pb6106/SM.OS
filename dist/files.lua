-- files.lua
-- Simple filesystem abstraction for OpenComputers (and test shims)

local M = {}

function M.init()
  -- load config or create defaults
  -- try to load role-specific config if present
  local ok, cfg = pcall(require, 'configs.primary_config')
  if ok and type(cfg) == 'table' then
    M.config = cfg
  else
    M.config = { displays = {}, monitors = {} }
  end
end

function M.load_config()
  return M.config
end

function M.load_display_config()
  return M.config.displays
end

return M
