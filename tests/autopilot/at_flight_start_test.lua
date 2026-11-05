-- Run from the repository root with LuaJIT: luajit tests/autopilot/at_flight_start_test.lua
-- (2026-11-05 review 3) a new flight starts the A/T anew with the AFDS, in
-- the autopilot module as XTLua runs it (tests/lib/xtlua.lua). Before,
-- flight_start made the AFDS's models only: an A/T engaged at the end of a
-- flight stayed engaged in its model and, the ARM switch off in the new
-- flight, disengaged there with >AUTOTHROT DISC (caution 5).
local T = dofile("tests/lib/check.lua")("at_flight_start")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local AT_ACTIVE, CAUTION = "laminar/B747/engines/autothrottle_active", "laminar/B747/CAS/caution_status"
local ARMED = "laminar/B747/autothrottle/armed"

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
-- in the air at 10,000 ft, the FCCs and the A/T's servo powered, the FMCs
-- working (the glue test's setup: afds_glue_test.lua)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 9000)
for i = 1, 3 do rt:set("laminar/B747/hydraulics/pressure_" .. i, 3000) end
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/xfr_fo", 1)
for i = 0, 2 do
    rt:set("laminar/B747/irs/att_valid", i, 1)
    rt:set("laminar/B747/airdata/valid", i, 1)
    rt:set("laminar/B747/irs/hdg_valid", i, 1)
    rt:set("laminar/B747/irs/nav_valid", i, 1)
end
rt:set("laminar/B747/flt_ctrls/stab_trim/autotrim_valid", 0, 1)
rt:set("laminar/B747/flt_ctrls/stab_trim/autotrim_valid", 1, 1)
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 250)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
frames(30)

-- the A/T engaged in SPD
rt:set("laminar/B747/engines/autothrottle_fail", 0)
rt:set(ARMED, 1)
frames()
rt:command(CMD .. "speed_mode")
frames(10)
T.equal(rt:get(AT_ACTIVE), 1, "the A/T engaged in SPD")
T.equal(rt:get(CAUTION, 5), 0, "no AUTOTHROT DISC")

-- a new flight with the A/T's ARM switch off: nothing engaged, no caution
rt:set(ARMED, 0)
rt:callout("flight_start")
frames(30)
T.equal(rt:get(AT_ACTIVE), 0, "the new flight: the A/T not engaged")
T.equal(rt:get(CAUTION, 5), 0, "and no AUTOTHROT DISC (before, the old flight's A/T disengaged here)")

-- the A/T works as before in the new flight
rt:set(ARMED, 1)
frames()
rt:command(CMD .. "speed_mode")
frames(10)
T.equal(rt:get(AT_ACTIVE), 1, "SPD engages it again")
rt:command(CMD .. "autothrottle_disco_L")
frames()
T.equal(rt:get(AT_ACTIVE), 0, "a disconnect push: off")
T.equal(rt:get(CAUTION, 5), 1, "with AUTOTHROT DISC (FCOM p.641)")
T.done()
