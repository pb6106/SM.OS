-- oc_mocks/event.lua
-- Minimal shim for OpenComputers 'event' API

local event = {}

function event.pull(timeout)
  if timeout then
    os.execute('sleep ' .. tonumber(timeout))
  else
    os.execute('sleep 0.01')
  end
  return nil
end

return event
