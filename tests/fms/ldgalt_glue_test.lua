-- Run from the repository root with LuaJIT: luajit tests/fms/ldgalt_glue_test.lua
-- The FMC's landing altitude for the cabin pressure controllers (6-1/6-2
-- step 11b; notes/ATA-34-61-FMC.md §91; FCOM p.1400, p.993; ATA34_2
-- p.477) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), from
-- the synthetic ZZAA (100 ft; RW34L 98 ft) to ZZBB (50 ft; RW09): none
-- without an active route; the origin's, then the departure runway's, also
-- after the takeoff; past halfway the destination's, then the approach's
-- runway; kept back near the origin; none after the flight completion and
-- the departure's again on a new route.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("ldgalt_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function at(lat, lon)
    rt:set("sim/flightmodel/position/latitude", lat)
    rt:set("sim/flightmodel/position/longitude", lon)
    frames(1.2)
end
local ALT, VALID = "laminar/B747/fms/landing_alt", "laminar/B747/fms/landing_alt_valid"
local function route()
    key("func_key/fpln")
    enter("ZZAA", "L1")
    enter("ZZBB", "R1")
    key("ls_key/R6")             -- ACTIVATE
    key("key/execute")
    frames(1.2)
end

frames(1.2)
T.equal(rt:get(VALID), 0, "no active route: no landing altitude (LANDING ALT)")

-- ZZAA to ZZBB: the origin's, then the departure runway's
route()
T.check(fms.ns.B747_fmc_route.active, "the route active")
T.equal(rt:get(VALID), 1, "an active route: a landing altitude")
T.equal(rt:get(ALT), 100, "on the ground: the origin's elevation (FCOM p.993)")
key("func_key/clb")              -- DEPARTURES (the ground, an active route)
T.check(line(5):find("34L", 1, true) ~= nil, "34L the second runway: " .. line(5))
key("ls_key/R2")
key("key/execute")
frames(1.2)
T.equal(fms.ns.B747_fmc_route.rte.runway and fms.ns.B747_fmc_route.rte.runway.ident, "RW34L", "the runway 34L active")
T.equal(rt:get(ALT), 98, "the departure runway's threshold elevation")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
at(35.2, 140.2)                  -- 15 NM from ZZAA, 62 to ZZBB
T.equal(rt:get(ALT), 98, "after the takeoff near the origin: still the departure's (a return)")

-- past halfway: the destination's, then its approach's runway (RW09 put
-- apart from the field)
at(35.7, 140.7)                  -- 54 NM from ZZAA, 23 to ZZBB
T.equal(rt:get(ALT), 50, "past halfway: the destination's elevation (FCOM p.1400)")
fms.ns.B747_navdb.cifp(fms.ns.B747_fmc_navdb, "ZZBB").runways.RW09.elev = 42
key("func_key/clb")              -- ARRIVALS (the air, an active route)
T.check(line(1):find("ZZBB ARRIVALS", 1, true) ~= nil, "ZZBB ARRIVALS: " .. line(1))
key("ls_key/R1")                 -- the approach R09
key("key/execute")
frames(1.2)
T.equal(fms.ns.B747_fmc_route.rte.appr and fms.ns.B747_fmc_route.rte.appr.rwy, "RW09", "the approach to RW09 active")
T.equal(rt:get(ALT), 42, "an approach in the active route: its runway's threshold elevation")
at(35.1, 140.1)
T.equal(rt:get(ALT), 42, "back near the origin: kept once switched")

-- the flight completion: no route, none; a new route near the origin: the
-- departure's again
fms.ns.B747_fms_flight_complete()
frames(1.2)
T.equal(rt:get(VALID), 0, "after the flight completion: none")
route()
T.equal(rt:get(VALID), 1, "a new route: a landing altitude")
T.equal(rt:get(ALT), 100, "the switch reset: the origin's again")
T.done()
