-- tests/test_reactor.lua
-- Basic unit test for core/reactor using the ntm mock

local reactor = require('core.reactor')
local ntm_mock = require('oc_mocks.ntm_mock')

print('Starting reactor module tests...')
reactor.init({ max_level = 100, safe_stress_threshold = 0.8, max_rate_per_second = 500 })
local adapter = ntm_mock.connect('mock1')
reactor.attach(adapter)

local ok, err = reactor.set_level(50)
assert(ok, 'set_level should succeed: ' .. tostring(err))
local st = reactor.get_state()
assert(st.level == 50, 'state.level should be 50')

-- test rate limiting by quickly requesting large change
reactor.init({ max_level = 100, safe_stress_threshold = 0.8, max_rate_per_second = 1 })
reactor.attach(adapter)
ok, err = reactor.set_level(100)
assert(not ok, 'set_level should be rate_limited')

print('All reactor tests passed')

-- test stabilizer durability shutdown
reactor.init({ max_level = 100, safe_stress_threshold = 0.8, max_rate_per_second = 500, stabilizer_durability_threshold = 20 })
reactor.attach(adapter)
-- simulate low durability
adapter._mock_obj.stabilizer_durability = 10
local res, reason = reactor.tick()
assert(res == 'emergency_stop' and reason == 'stabilizer_durability_low', 'reactor should shutdown for low stabilizer durability')

print('Stabilizer durability shutdown test passed')
