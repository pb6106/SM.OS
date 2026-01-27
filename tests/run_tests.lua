-- tests/run_tests.lua
-- Simple test runner using mocks

local component = require('oc_mocks.component')
local event = require('oc_mocks.event')

print('Running basic scaffold smoke tests...')
print('component and event mocks loaded')

-- Run specific unit tests
local tests = {
	'tests/test_reactor.lua',
	'tests/test_ntm_adapter.lua',
}

for _, t in ipairs(tests) do
	print('Running ' .. t)
	local ok, err = pcall(dofile, t)
	if not ok then
		print('Test failed: ' .. tostring(err))
		os.exit(1)
	end
end

print('All tests in run_tests.lua completed successfully')
