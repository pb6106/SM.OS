-- oc_mocks/component.lua
-- Minimal shim for OpenComputers 'component' API for local tests

local component = {}

component.list = function(filter)
  return function() end
end

component.proxy = function(addr)
  return {}
end

return component
