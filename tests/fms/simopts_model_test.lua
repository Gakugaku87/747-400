-- Run from the repository root with LuaJIT: luajit tests/fms/simopts_model_test.lua
-- The sim's options (2026-11-01 the user; notes/ATA-34-61-FMC.md §126):
-- the automatic step climb at the CRZ page's AT NOW (the MCP altitude
-- STEP TO, the altitude selector's push a second later: FCOM p.649,
-- p.1257, p.1348-1349) and the pause two minutes before the T/D (RESET
-- MCP ALT's: FCOM p.1433), once until the T/D is three minutes away.
local T = dofile("tests/lib/check.lua")("simopts_model")
local O = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.simopts_model.lua")

-- the automatic step climb
local function inp(t, over)
    local i = {on = true, air = true, vnav = true, crz = true, crz_alt = 31000, mcp = 31000, to = 35000, now = true, t = t}
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end
local s = O.new()
local act, alt = O.step(s, inp(0))
T.equal(act, "mcp", "AT NOW in the cruise with VNAV: the MCP altitude first")
T.equal(alt, 35000, "to STEP TO")
T.equal(O.step(s, inp(0.5, {mcp = 35000})), nil, "half a second later: nothing yet")
T.equal(O.step(s, inp(1, {mcp = 35000})), "push", "a second later: the altitude selector's push")
T.equal(O.step(s, inp(2, {mcp = 35000})), nil, "pushed: nothing more")
-- the push took: CRZ ALT STEP TO, the cruise climb (not the cruise)
T.equal(O.step(s, inp(3, {mcp = 35000, crz = false})), nil, "the cruise climb: nothing")
T.equal(s.to, nil, "and the step forgotten")
-- the push did not take: tried again after 30 s
s = O.new()
O.step(s, inp(0))
O.step(s, inp(1, {mcp = 35000}))
T.equal(O.step(s, inp(20, {mcp = 35000})), nil, "20 s after a push not taken: nothing")
O.step(s, inp(31, {mcp = 35000}))
local a2, alt2 = O.step(s, inp(31.5, {mcp = 35000}))
T.equal(a2, "mcp", "30 s after: the MCP altitude again")
T.equal(alt2, 35000, "STEP TO")
-- not done
local function none(over, what)
    T.equal(O.step(O.new(), inp(0, over)), nil, what)
end
none({on = false}, "the option off: nothing")
none({air = false}, "on the ground: nothing")
none({vnav = false}, "VNAV not engaged: nothing")
none({crz = false}, "not the cruise (the climb, a cruise climb or descent, the descent): nothing")
none({now = false}, "the step point ahead (AT a time): nothing")
none({to = false}, "no STEP TO (within 200 NM of the T/D, STEP SIZE 0): nothing")
none({to = 31000}, "STEP TO not above CRZ ALT: nothing")
none({mcp = 25000}, "the MCP altitude set below CRZ ALT (the descent's): nothing")
none({crz_alt = 0}, "no CRZ ALT: nothing")
T.equal(O.step(O.new(), inp(0, {mcp = 39000})), "mcp", "the MCP altitude above STEP TO: set to STEP TO")
-- a new STEP TO (the crew's entry) while waiting: the MCP altitude again
s = O.new()
O.step(s, inp(0))
local a3, alt3 = O.step(s, inp(0.5, {to = 37000}))
T.equal(a3, "mcp", "a new STEP TO: the MCP altitude again")
T.equal(alt3, 37000, "to it")

-- the pause before the T/D: 460 kt, two minutes 15.3 NM
local function pin(td, over)
    local i = {on = true, air = true, crz = true, td = td, gs = 460}
    for k, v in pairs(over or {}) do i[k] = v end
    return i
end
s = O.new()
T.equal(O.pause(s, pin(40)), false, "40 NM (5.2 min) to the T/D: no pause")
T.equal(O.pause(s, pin(15.4)), false, "15.4 NM (2.01 min): no pause")
T.equal(O.pause(s, pin(15.3)), true, "15.3 NM (2.0 min): the pause")
T.equal(O.pause(s, pin(15)), false, "unpaused: not again")
T.equal(O.pause(s, pin(-2)), false, "past the T/D in the cruise: not again")
T.equal(O.pause(s, pin(20, {crz = false})), false, "the descent: not again")
T.equal(O.pause(s, pin(20)), false, "2.6 min (a new T/D under 3 min): still not")
O.pause(s, pin(30))
T.equal(s.paused, false, "the T/D 3.9 min away (a new CRZ ALT or route): armed again")
T.equal(O.pause(s, pin(10)), true, "and the pause at the new T/D")
O.pause(s, pin(10, {air = false}))
T.equal(s.paused, false, "on the ground: armed again")
T.equal(O.pause(O.new(), pin(10, {on = false})), false, "the option off: no pause")
T.equal(O.pause(O.new(), pin(10, {crz = false})), false, "not the cruise (the climb's T/D, the descent): no pause")
T.equal(O.pause(O.new(), pin(nil)), false, "no T/D: no pause")
T.equal(O.pause(O.new(), pin(1, {gs = 80})), false, "ground speed under 100 kt: no pause")
s = O.new()
O.pause(s, pin(10, {on = false}))
T.equal(O.pause(s, pin(9)), true, "the option turned on within the two minutes: the pause at once")
T.equal(O.pause(O.new(), pin(-30)), true, "past the T/D still in the cruise (the MCP not set lower): the pause")

T.done()
