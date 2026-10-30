-- Run from the repository root with LuaJIT: luajit tests/autopilot/vnav_speed_test.lua
-- The A/P's VNAV speeds from the FMC's (6-1/6-2 step 8b; notes/
-- ATA-34-61-FMC.md §45; B747.70.xt.autopilot.vnavspd.lua): the cruise's
-- Mach or a crew's CAS as the FMC has them (before, a Mach fitted to the
-- weight and altitude from the cost index here, which overrode a crew's
-- speed: FMC-11); the climb's Mach (its own, else the cruise's); VNAV's
-- descent targets no more than VMO/MMO less 11 kt (FCOM p.1258).
local T = dofile("tests/lib/check.lua")("vnav_speed")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local DIAL, IS_MACH = "laminar/B747/autopilot/ias_dial_value", "sim/cockpit2/autopilot/airspeed_is_mach"
local ALT, MACH, IAS = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/flightmodel/misc/machno", "laminar/B747/gauges/indicators/airspeed_kts_pilot"

local rt = xtlua.new()
local ap = rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("laminar/B747/airspeed/Vmo", 365)
rt:set("laminar/B747/airspeed/Vmc", 120)
rt:callout("flight_start")
local function frames(n) for _ = 1, n or 1 do rt:frame(1 / 30) end end
frames(30)

-- the FMC's data (the FMS module's fields)
local function fmc(t)
    local d = {transpd = "250", spdtransalt = "10000", transalt = "18000", clbrestspd = "---", clbrestalt = "-----",
        crzalt = "FL350", crzspd = "854", crzcas = "   ", clbspd = "335", clbspdmach = "854", desspdmach = "854",
        desspd = "284", destranspd = "240", desspdtransalt = "10000", desrestspd = "---", desrestalt = "-----",
        costindex = "100"}
    for k, v in pairs(t or {}) do d[k] = v end
    local parts = {}
    for k, v in pairs(d) do parts[#parts + 1] = string.format('"%s":"%s"', k, v) end
    rt:set("laminar/B747/fms/data", "{" .. table.concat(parts, ",") .. "}")
    frames()
end

-- cruise: the FMC's Mach, whatever the cost index (before: 0.6203 GW + ...)
rt:set(ALT, 35000)
rt:set(MACH, 0.84)
rt:set(IAS, 280)
fmc()
ap.ns.clb_crz_setSpd()
T.check(rt:get(IS_MACH) == 1 and math.abs(rt:get(DIAL) - 85.4) < 1e-9, "cruise: the FMC's ECON .854 (" .. rt:get(DIAL) .. ")")
fmc{costindex = "9999"}
ap.ns.clb_crz_setSpd()
T.near(rt:get(DIAL), 85.4, 1e-9, "CI 9999: still the FMC's (the old fit here gave .900)")
fmc{crzspd = "840", costindex = "100"}
ap.ns.clb_crz_setSpd()
T.near(rt:get(DIAL), 84.0, 1e-9, "a crew's .840 (SEL SPD): .840 (before, the cost index overrode it)")
fmc{crzcas = "300"}
ap.ns.clb_crz_setSpd()
T.check(rt:get(IS_MACH) == 0 and rt:get(DIAL) == 300, "a crew's CAS 300: the IAS 300")

-- climb above the SPD TRANS altitude: the climb's Mach once faster than it
rt:set(ALT, 30000)
rt:set(MACH, 0.86)
fmc{clbspdmach = "850", crzspd = "860"}
ap.ns.clb_nores_setSpd()
T.check(rt:get(IS_MACH) == 1 and math.abs(rt:get(DIAL) - 85.0) < 1e-9, "climb at .860 above the climb's .850: the climb's Mach .850 (" .. rt:get(DIAL) .. ")")
fmc{clbspdmach = "   ", crzspd = "855"}
ap.ns.clb_nores_setSpd()
T.near(rt:get(DIAL), 85.5, 1e-9, "no climb Mach (a crew's CAS alone): the cruise's .855")

-- descent: a crew's .950 at FL350 no more than MMO less 11 kt (about .894)
rt:set(ALT, 35000)
rt:set(MACH, 0.90)
fmc{desspdmach = "950"}
ap.ns.des_src_setSpd()
local d = rt:get(DIAL)
T.check(rt:get(IS_MACH) == 1 and d > 89.0 and d < 89.8, string.format("a crew's .950 at FL350: Mach %.3f, MMO less 11 kt", d / 100))
-- a crew's 380 kt at FL150 from 360: 354 (VMO less 11 kt)
rt:set(ALT, 15000)
rt:set(MACH, 0.70)
rt:set(IAS, 360)
rt:set(IS_MACH, 0)
rt:set(DIAL, 360)
fmc{desspd = "380", desspdmach = "800"}
ap.ns.des_src_setSpd()
T.equal(rt:get(DIAL), 354, "a crew's 380 kt: 354 kt (VMO less 11 kt)")
fmc{desspd = "300", desspdmach = "800"}
rt:set(DIAL, 360)
ap.ns.des_src_setSpd()
T.equal(rt:get(DIAL), 345, "300 kt from 360: down 15 kt a step as before")

T.done()
