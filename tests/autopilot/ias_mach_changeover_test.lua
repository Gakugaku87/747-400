-- Run from the repository root with LuaJIT: luajit tests/autopilot/ias_mach_changeover_test.lua
-- (2026-11-07, PERF_SIMBRIEF) the IAS/MACH window when its units change, by
-- the switch or by itself (FCOM p.643, 4.10.4: in climb from IAS to Mach at
-- about .840, in descent from Mach to IAS at about 310 kt), in the autopilot
-- module as XTLua runs it (tests/lib/xtlua.lua): the speed selected before,
-- in the new units. Before, the speed flown: after an air start at FL310
-- with M.85 (318 kt) the descent's change came while the A/T still came
-- back from the set-up's slowdown, and the window became 301 kt (M.81)
-- (notes/ATA-22.md §54). The mock does not convert the target between knots
-- and Mach as X-Plane does: the tests set the knots X-Plane would give.
local T = dofile("tests/lib/check.lua")("ias_mach_changeover")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local I = "sim/cockpit2/gauges/indicators/"
local DIAL = "laminar/B747/autopilot/ias_dial_value"
local IS_MACH = "sim/cockpit2/autopilot/airspeed_is_mach"
local KTS, MACH = "sim/cockpit2/autopilot/airspeed_dial_kts", "sim/cockpit2/autopilot/airspeed_dial_kts_mach"
local IAS_IND = "laminar/B747/gauges/indicators/airspeed_kts_pilot"

-- the standard atmosphere's CAS of a Mach at a pressure altitude, and its
-- inverse, as the module has them (B747.70.xt.autopilot.lua)
local function delta(ft) return (1 - 6.87559e-6 * ft) ^ 5.25588 end
local function cas(m, ft)
    local qc = delta(ft) * ((1 + 0.2 * m * m) ^ 3.5 - 1)
    return 661.4786 * math.sqrt(5 * ((qc + 1) ^ (2 / 7) - 1))
end
local function mach(kt, ft)
    local qc = (1 + 0.2 * (kt / 661.4786) ^ 2) ^ 3.5 - 1
    return math.sqrt(5 * ((qc / delta(ft) + 1) ^ (2 / 7) - 1))
end
T.near(cas(0.85, 31000), 317.96, 0.05, "M.85 at FL310: 318 kt (the reference)")
T.near(mach(cas(0.85, 31000), 31000), 0.85, 1e-9, "the inverse")

local rt = xtlua.new()
rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set(I .. "radio_altimeter_height_ft_pilot", 2500)
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:set("laminar/B747/airspeed/Mms", 0.92)
rt:set("laminar/B747/airspeed/Vmc", 200)
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/fms/fmc_ok", 0, 1)
rt:set("laminar/B747/fms/fmc_ok", 1, 1)
local function at(ft, ias, m, vs)
    rt:set(I .. "altitude_ft_pilot", ft)
    rt:set("sim/flightmodel2/position/pressure_altitude", ft)
    rt:set(I .. "airspeed_kts_pilot", ias)
    rt:set(IAS_IND, ias)
    rt:set("sim/flightmodel/misc/machno", m)
    rt:set(I .. "vvi_fpm_pilot", vs)
end
at(31000, 301, 0.81, 0)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 3 do rt:frame(1 / 30) end end
frames(30)
rt:set("laminar/B747/autopilot/ap_monitor/switchingIASMode", 0)

-- 1. the descent's change at FL310 with M.85 (318 kt) selected, the A/T
-- still at 301 kt (M.81) after the air start: the capture's dip below
-- -250 fpm
rt:set(IS_MACH, 1)
rt:set(DIAL, 85)
frames(5)
T.near(rt:get(MACH), 0.85, 1e-6, "FL310, the window M.85: the target M.85")
rt:set(KTS, cas(0.85, 31000))  -- X-Plane's knots of the Mach target
at(31000, 301, 0.81, -300)
frames(15)                     -- the change's quarter second
T.equal(rt:get(IS_MACH), 0, "V/S -300 fpm with 318 kt selected: the window in IAS")
T.equal(rt:get(DIAL), 318, "the window 318 kt, M.85's (before: 301, the IAS flown)")
at(31000, 301, 0.81, 0)
frames(5)
T.near(rt:get(KTS), 318, 1e-6, "the target 318 kt, M.85 at FL310 (before: 301)")

-- 2. the switch back to Mach (IAS/MACH SEL), still at 301 kt: M.85
rt:command("sim/autopilot/knots_mach_toggle")
frames(15)
T.equal(rt:get(IS_MACH), 1, "IAS/MACH SEL: the window in Mach")
T.equal(rt:get(DIAL), 85, "the window .85, 318 kt's (before: 81, the Mach flown)")
frames(5)
T.near(rt:get(MACH), 0.85, 1e-6, "the target M.85")
-- and to IAS by the switch: 318 kt
rt:command("sim/autopilot/knots_mach_toggle")
frames(15)
T.equal(rt:get(IS_MACH), 0, "IAS/MACH SEL again: IAS")
T.equal(rt:get(DIAL), 318, "the window 318 kt (before: 301)")

-- 3. the climb's change: 310 kt selected through M.840 at FL320 (310 kt is
-- M.847 there), the airplane at 306 kt and M.842
at(32000, 306, 0.842, 600)
rt:set(DIAL, 310)
frames(5)
T.equal(rt:get(IS_MACH), 1, "climbing through M.840: the window in Mach")
frames(15)
T.equal(rt:get(DIAL), 85, "the window .85, 310 kt's at FL320 (M.847; before: 84, the Mach flown)")

-- 4. out of the MCP's range, the speed flown as before (the set-up's window
-- not yet wound)
at(31000, 301, 0.81, 0)
rt:set(DIAL, 0)
rt:command("sim/autopilot/knots_mach_toggle")
frames(15)
T.equal(rt:get(IS_MACH), 0, "IAS/MACH SEL with the window 0: IAS")
T.equal(rt:get(DIAL), 301, "the IAS flown, 301 kt")

-- 5. (2026-11-11 review) the new value kept in the MCP's range (FCOM p.643:
-- 100 to 399 kt, .400 to .950): M.80 at 15,000 ft is 410 kt, 320 kt at
-- FL370 .96 (before, the window showed them)
T.check(cas(0.80, 15000) > 405 and mach(320, 37000) > 0.955, "(M.80 at 15,000 ft above 399 kt, 320 kt at FL370 above .95)")
at(15000, 300, 0.60, 0)
rt:command("sim/autopilot/knots_mach_toggle")      -- to Mach
frames(15)
rt:set(DIAL, 80)
frames(5)
rt:command("sim/autopilot/knots_mach_toggle")      -- M.80 to IAS
frames(15)
T.check(rt:get(IS_MACH) == 0 and rt:get(DIAL) == 399, "M.80 at 15,000 ft to IAS: 399 kt (the MCP's top; before 410): " .. rt:get(DIAL))
at(37000, 250, 0.84, 0)
rt:set(DIAL, 320)
frames(5)
rt:command("sim/autopilot/knots_mach_toggle")      -- 320 kt to Mach
frames(15)
T.check(rt:get(IS_MACH) == 1 and rt:get(DIAL) == 95, "320 kt at FL370 to Mach: .95 (the MCP's top; before .96): " .. rt:get(DIAL))
T.done()
