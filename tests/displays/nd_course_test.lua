-- Run from the repository root with LuaJIT: luajit tests/displays/nd_course_test.lua
-- The ND's course lines of the manually tuned VORs (5-2 step 5c, FCOM
-- p.1145): the pure functions of
-- plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua (crs_text,
-- crs_label, crs_line), then the ND module (B747.61.xt.nd.lua) as XTLua
-- runs it (tests/lib/xtlua.lua): manual tuning only, MAP and MAP CTR only,
-- the course and the reciprocal, a far station's line across the map.
local T = dofile("tests/lib/check.lua")("nd_course")
local D = dofile("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua")
local xtlua = dofile("tests/lib/xtlua.lua")
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= tol end

T.equal(D.crs_text(70), "070", "course 70: 070")
T.equal(D.crs_text(250), "250", "250")
T.check(D.crs_text(0) == "360" and D.crs_text(359.6) == "360" and D.crs_text(360) == "360", "north: 360, not 000")
local tb, ts = D.crs_label(70)
T.check(near(tb, -20, 1e-9) and ts == 1, "a line to 070: its text turned -20, on its right")
tb, ts = D.crs_label(250)
T.check(near(tb, -20, 1e-9) and ts == 2, "to 250: the same turn, on its left, so both read left to right")

-- the line's nearest point and its dashes (22 px apart, the pattern fixed
-- to the station: a dash's middle at (m + 1/2) x 22 px from it)
local buf = {}
local function count(b, from, n) local c = 0 for j = from, from + n - 1 do c = c + b[j] end return c end
local fx, fy, phase, any = D.crs_line(0, 200, 90, D.EXPANDED, buf, 0)
local function same_phase(p, want) local d = (p - want) % 22 return d < 1e-6 or d > 22 - 1e-6 end
T.check(near(fx, 0, 1e-9) and near(fy, 200, 1e-9) and same_phase(phase, 11),
    "a station 200 px ahead, a line across: nearest at the station, a dash's middle 11 px from it")
T.check(any and count(buf, 0, 85) == 31, "31 dashes across the display's width (329 left, 348 right)")
fx, fy, phase, any = D.crs_line(100, 300, 0, D.EXPANDED, buf, 0)
T.check(near(fx, 100, 1e-9) and near(fy, 0, 1e-9), "a line up the display 100 px right: nearest abeam the airplane")
T.check(near(phase, 3, 1e-9) and count(buf, 0, 85) == 21, "its dashes from 3 px ahead (300 px less 13.5 periods) to the range arc: 21")
T.equal(buf[42], 1, "the dash at the nearest point")
T.equal(buf[41], 0, "none behind the airplane")
fx, fy, phase, any = D.crs_line(1000, 300, 0, D.EXPANDED, buf, 0)
T.check(not any and count(buf, 0, 85) == 0, "a line 1,000 px right: none")

-- the ND module: VOR AAA 9 NM ahead of the airplane at 35N 140E, north
local rt = xtlua.new()
local nd = rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)                   -- MAP
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)                  -- 40 NM
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:callout("flight_start")
rt:set("xtlua/navaids", '[[1,4,11750,0,35.15,140.0,0,"AAA"],[2,4,11300,0,35.0,141.0,0,"BBB"]]')
nd.ns.decodeNAVAIDS()
rt:set("sim/cockpit2/radios/indicators/nav3_nav_id", "AAA")
rt:set("sim/cockpit2/radios/indicators/nav4_nav_id", "BBB")
rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 2, 70)
rt:set("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot", 3, 270)
rt:set("laminar/B747/radio/tuningmodes", " AA")
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
run(1.2)
local C = "laminar/B747/nd/capt/crs/"
local function get(f, k) return rt:get(C .. f, k) end
T.check(get("show", 0) == 0 and get("show", 1) == 0, "autotuned: no course lines")
rt:set("laminar/B747/radio/tuningmodes", " MA")                       -- VOR L tuned on the NAV RADIO page
run(1.2)
T.equal(get("show", 0), 1, "VOR L manually tuned: AAA's course line (FCOM p.1145)")
T.equal(get("show", 1), 0, "VOR R still autotuned: none")
T.check(rt:get(C .. "text0") == "070" and rt:get(C .. "text1") == "250", "the course 070 and the reciprocal 250")
T.check(near(get("dir", 0), 70, 0.1), "turned to 070 (no variation)")
T.check(near(get("lbl_heading", 0), 0, 0.5) and near(get("lbl_distance", 0), 9 * 16, 1), "the numbers at AAA 9 NM ahead")
T.check(near(get("heading", 0), -20, 0.5) and near(get("distance", 0), 135.3, 1.5),
    "the dashes about the line's point nearest the airplane, square to 070")
T.check(get("lbl_show", 0) == 1 and get("lbl_show", 1) == 1, "both numbers on the map")
T.check(get("tside", 0) == 1 and get("tside", 1) == 2, "070 on the line's right, 250 on its left")
local dashes = {}
for j = 0, 169 do dashes[j] = rt:get(C .. "dash", j) end
T.check(count(dashes, 0, 85) > 20 and count(dashes, 85, 85) == 0, "VOR L's dashes on the map, none for VOR R")
-- VOR R manually tuned to BBB 49 NM east, the course 270: its line across
-- the map through the airplane, the station off it
rt:set("laminar/B747/radio/tuningmodes", " MM")
run(1.2)
T.equal(get("show", 1), 1, "BBB off the map: its course line still crosses it")
T.check(get("lbl_show", 2) == 0 and get("lbl_show", 3) == 0, "without its numbers (the station off the map)")
T.check(near(get("distance", 1), 0, 6), "the line through the airplane (49 NM along the great circle: within 3 px)")
-- MAP CTR, VOR mode, the F/O
rt:set("laminar/B747/nd/map_center/capt", 1)
run(0.5)
T.equal(get("show", 0), 1, "MAP CTR: shown")
rt:set("laminar/B747/nd/map_center/capt", 0)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)
run(0.5)
T.check(get("show", 0) == 0 and get("show", 1) == 0, "VOR mode: none (MAP and MAP CTR only)")
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:set("laminar/B747/nd/range/fo/sel_dial_pos", 2)
run(0.5)
T.equal(rt:get("laminar/B747/nd/fo/crs/show", 0), 1, "the F/O's ND in MAP: AAA's line while the Captain's is in VOR")
-- back to autotuning: gone
rt:set("laminar/B747/radio/tuningmodes", " AA")
run(0.5)
T.equal(rt:get("laminar/B747/nd/fo/crs/show", 0), 0, "autotuned again: gone")

T.done()
