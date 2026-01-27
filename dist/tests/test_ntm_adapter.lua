-- tests/test_ntm_adapter.lua
-- Unit tests for adapters/ntm_adapter using mocks only

local ntm_adapter = require('adapters.ntm_adapter')
local ntm_mock = require('oc_mocks.ntm_mock')

print('Starting NTM adapter tests...')

-- Force adapter to use fallback mock by passing nil address (adapter.connect uses real component only when addr provided)
local adapter = assert(ntm_adapter.connect(nil), 'adapter.connect should return mock adapter')

-- Query initial telemetry
local tel = adapter.query(adapter)
assert(type(tel) == 'table', 'query should return a table')
assert(tel.level == 0, 'initial level should be 0')

-- set level via adapter.command
local ok = adapter.command(adapter, 'setLevel', { level = 30 })
assert(ok, 'setLevel command should succeed')
local tel2 = adapter.query(adapter)
assert(tel2.level == 30, 'level after setLevel should be 30')

-- start/stop
local ok_start = adapter.command(adapter, 'start', {})
assert(ok_start, 'start should succeed')
local ok_stop = adapter.command(adapter, 'stop', {})
assert(ok_stop, 'stop should succeed')

print('NTM adapter tests passed')
