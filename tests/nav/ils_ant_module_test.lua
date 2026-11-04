-- Run from the repository root with LuaJIT: luajit tests/nav/ils_ant_module_test.lua
-- The ILS antenna glue (B747.34.xt.ils.lua; 2026-11-04, for the failure
-- window) in the navigation sensors module (B747.34.xt.nav) as XTLua runs
-- it (tests/lib/xtlua.lua): the PSEU's air/ground and nose gear, the FMA's
-- roll modes and laminar/B747/ils/fail/* in; STATUS G/S and LOC ANTENNA
-- (148-153) and the caution ILS ANTENNA (47) out. The model is tested in
-- ils_ant_model_test.lua; this checks the wiring.
local T = dofile("tests/lib/check.lua")("ils_ant_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local CAUTION = "laminar/B747/CAS/caution_status"
local STATUS = "laminar/B747/CAS/status_status"
local FAIL = "laminar/B747/ils/fail/"
local GND = "laminar/B747/gear/air_ground/"
local FMA = "laminar/B747/autopilot/FMA/"

-- cruise: in the air, the gear up, LNAV
rt:set(GND .. "pri_gnd", 0)
rt:set(GND .. "nose_not_down", 1)
rt:set(FMA .. "active_roll_mode", 2)
rt:callout("flight_start")
frames(1)
for i = 148, 153 do T.equal(get(STATUS, i), 0, "cruise: no STATUS " .. i) end
T.equal(get(CAUTION, 47), 0, "cruise: no ILS ANTENNA")

-- the G/S relays L and C stuck on the capture antenna, the localizer relay
-- R on the VOR antenna; then LOC armed and the gear down
rt:set(FAIL .. "gs_antenna", 0, 1)
rt:set(FAIL .. "gs_antenna", 1, 1)
rt:set(FAIL .. "loc_antenna", 2, 1)
frames(0.2)
T.equal(get(CAUTION, 47), 0, "stuck in cruise: no ILS ANTENNA yet")
rt:set(FMA .. "armed_roll_mode", 3)
frames(0.2)
T.equal(get(STATUS, 153), 1, "LOC armed: STATUS LOC ANTENNA R")
T.equal(get(STATUS, 151), 0, "LOC armed: not L")
rt:set(GND .. "nose_not_down", 0)
frames(0.2)
T.equal(get(STATUS, 148), 1, "gear down: STATUS G/S ANTENNA L")
T.equal(get(STATUS, 149), 1, "gear down: STATUS G/S ANTENNA C")
T.equal(get(STATUS, 150), 0, "gear down: not R")
T.equal(get(CAUTION, 47), 1, "two G/S relays: ILS ANTENNA")
for n = 0, 2 do
    rt:set(FAIL .. "gs_antenna", n, 0)
    rt:set(FAIL .. "loc_antenna", n, 0)
end
frames(0.2)
for i = 148, 153 do T.equal(get(STATUS, i), 0, "repaired: no STATUS " .. i) end
T.equal(get(CAUTION, 47), 0, "repaired: no ILS ANTENNA")

T.done()
