-- Run from the repository root with LuaJIT: luajit tests/displays/nd_data_test.lua
-- The ND's route data (5-2 step 5c): the lines
-- (plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua; FCOM p.1040,
-- p.1148; FMSPG p.50), then as XTLua runs them (tests/lib/xtlua.lua) the
-- FMC's ETA for each route entry (B747.68.xt.fms.lua,
-- laminar/B747/fms/route_eta) and the ND module's first slots
-- (B747.61.xt.nd.lua: laminar/B747/nd/<side>/text/rdata_color, rdata1_<n>,
-- rdata2_<n>).
local T = dofile("tests/lib/check.lua")("nd_data")
local D = dofile("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua")
local xtlua = dofile("tests/lib/xtlua.lua")

-- the lines
T.equal(D.alt_text(12000, 18000), "12000", "12,000 ft below the transition altitude: 12000 (FMSPG p.50)")
T.equal(D.alt_text(35000, 18000), "FL350", "35,000 ft: FL350")
T.equal(D.alt_text(14000, 14000), "14000", "the transition altitude 14,000 ft itself: 14000 (as the LEGS page)")
T.equal(D.alt_text(14100, 14000), "FL141", "above it: FL141")
T.equal(D.alt_text(0, 18000), nil, "no altitude (X-Plane's 0): none")
T.equal(D.eta_text(8 * 60 + 35), "0835Z", "08:35: 0835Z")
T.equal(D.eta_text(1440 + 5), "0005Z", "past midnight: 0005Z")
T.equal(D.eta_text(-1), nil, "-1: none")
local c, l1, l2 = D.lines(true, true, "12000", "0835Z")
T.check(c == D.MAGENTA and l1 == "12000" and l2 == "0835Z", "the active waypoint: magenta, the altitude, then the ETA")
c, l1, l2 = D.lines(true, false, nil, "0835Z")
T.check(c == D.WHITE and l1 == "0835Z" and l2 == " ", "another without an altitude: white, the ETA on the first line")
c, l1, l2 = D.lines(false, true, "12000", "0835Z")
T.check(c == D.NONE and l1 == " " and l2 == " ", "DATA off: none")
T.equal((D.lines(true, false, nil, nil)), D.NONE, "no data: none")

-- a route north of the airplane at 35N 140E: AAA passed, BBB active (30 NM),
-- CCC 60 NM; xtlua/fms entries: [5] latitude, [6] longitude, [8] identifier,
-- [9] altitude, [10] active
local ROUTE = '[[1,512,0,0,35.1,140.0,0,"AAA",0,false],'
    .. '[2,512,0,0,35.5,140.0,0,"BBB",12000,true],'
    .. '[3,512,0,0,36.0,140.0,0,"CCC",35000,false]]'

-- the FMC: the distance along the route by its ETA (get_ETA_for_Distance:
-- the greater of the groundspeed and its floor, FMC-21)
local fmc = xtlua.new()
fmc:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
fmc:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS"}}')
fmc:set("laminar/B747/newsimconfig", 1)
fmc:set("sim/operation/prefs/startup_running", 1)
fmc:callout("flight_start")
local function run(rt, seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
run(fmc, 2)
fmc:set("xtlua/fms", ROUTE)
fmc:set("sim/flightmodel/position/latitude", 35.0)
fmc:set("sim/flightmodel/position/longitude", 140.0)
fmc:set("sim/flightmodel2/position/groundspeed", 300)                 -- 583 kt
fmc:set("sim/flightmodel/failures/onground_any", 0)
fmc:set("sim/cockpit2/clock_timer/zulu_time_hours", 8)
fmc:set("sim/cockpit2/clock_timer/zulu_time_minutes", 0)
fmc:set("sim/cockpit2/clock_timer/zulu_time_seconds", 0)
run(fmc, 1.2)
-- 30 NM at 583 kt: 3.1 min; 60 NM: 6.2 min
T.equal(fmc:get("laminar/B747/fms/route_eta"), "[-1,483,486]", "the FMC's ETAs: none for AAA (passed), 0803 for BBB, 0806 for CCC")
fmc:set("sim/flightmodel/failures/onground_any", 1)
run(fmc, 1.2)
T.equal(fmc:get("laminar/B747/fms/route_eta"), "[-1,-1,-1]", "on the ground: none (as the active waypoint's ETA)")

-- the ND module's slots (newIcons every 0.2 s; the navigation data files
-- are not read: debug/nd -2)
local rt = xtlua.new()
local nd = rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)                               -- MAP
rt:set("sim/cockpit2/EFIS/map_mode_copilot", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 4)                  -- 160 NM
rt:set("laminar/B747/nd/range/fo/sel_dial_pos", 4)
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:set("laminar/B747/autopilot/ap_monitor/fmscurrentIndex", 2)
rt:set("xtlua/fms", ROUTE)
rt:set("laminar/B747/fms/route_eta", "[-1,515,527]")
rt:set("laminar/B747/fms/data", '{"crzalt":"FL350","transalt":"14000"}')
rt:set("laminar/B747/nd/data/capt/data", 1)
rt:callout("flight_start")
nd.ns.decodeFlightPlan()
run(rt, 0.5)
local C, F = "laminar/B747/nd/capt/text/", "laminar/B747/nd/fo/text/"
T.equal(rt:get(C .. "whitetext0"), "AAA", "slot 0: the passed waypoint AAA")
T.equal(rt:get(C .. "rdata_color", 0), D.NONE, "AAA: no data (no altitude, no ETA)")
T.equal(rt:get(C .. "redtext1"), "BBB", "slot 1: the active waypoint BBB")
T.equal(rt:get(C .. "rdata_color", 1), D.MAGENTA, "BBB's data magenta")
T.equal(rt:get(C .. "rdata1_1"), "12000", "its altitude 12000 (below the FMC's transition altitude 14,000 ft)")
T.equal(rt:get(C .. "rdata2_1"), "0835Z", "its ETA 0835Z")
T.equal(rt:get(C .. "rdata_color", 2), D.WHITE, "CCC's data white")
T.equal(rt:get(C .. "rdata1_2"), "FL350", "its altitude FL350")
T.equal(rt:get(C .. "rdata2_2"), "0847Z", "its ETA 0847Z")
T.equal(rt:get(F .. "redtext1"), "BBB", "the F/O's ND shows the route")
T.equal(rt:get(F .. "rdata_color", 1), D.NONE, "without its DATA switch: no data")
rt:set("laminar/B747/nd/data/fo/data", 1)
rt:set("laminar/B747/nd/data/capt/data", 0)
run(rt, 0.5)
T.equal(rt:get(F .. "rdata_color", 2), D.WHITE, "the F/O's DATA on: CCC's data")
T.equal(rt:get(C .. "rdata_color", 1), D.NONE, "the Captain's DATA off: none")
rt:set("laminar/B747/fms/route_eta", "[-1,-1,-1]")
nd.ns.decodeFlightPlan()
run(rt, 0.5)
T.equal(rt:get(F .. "rdata_color", 1), D.MAGENTA, "no ETA: BBB still has its altitude")
T.equal(rt:get(F .. "rdata1_1"), "12000", "the altitude on the first line")
T.equal(rt:get(F .. "rdata2_1"), " ", "no second line")

T.done()
