-- Run from the repository root with LuaJIT: luajit tests/displays/hdg_ref_test.lua
-- The heading reference (5-2 step 5d, FCOM p.998, p.1046, p.1110, p.1142):
-- the model (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/
-- B747.60.hdg_ref_model.lua: the polar areas, TRU's box amber in a descent,
-- MAG's box after TRU), the display glue in the flight instruments module
-- (each side's heading and track in the reference, the labels, the ND
-- model's wind) and the AFDS (B747.70.xt.autopilot.lua: the MCP heading
-- made magnetic for X-Plane's heading mode in TRUE, HDG HOLD when the
-- switch moves in HDG SEL), as XTLua runs them (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("hdg_ref")
local HR = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.hdg_ref_model.lua")
local xtlua = dofile("tests/lib/xtlua.lua")
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= tol end

-- the polar areas (FCOM p.1046)
T.check(HR.polar(83, 0) and HR.polar(-83, 10), "north of 82N, south of 82S")
T.check(not HR.polar(81, 0) and not HR.polar(-81, 0), "not short of them")
T.check(HR.polar(75, -100) and not HR.polar(75, -60) and not HR.polar(69, -100), "north of 70N between 80W and 130W only")
T.check(HR.polar(-65, 140) and not HR.polar(-65, 100) and not HR.polar(-59, 140), "south of 60S between 120E and 160E only")
-- a heading in the reference (mag_diff: magnetic less true, -4 for 4E)
T.check(HR.heading(10, -4, true) == 14 and HR.heading(358, -4, true) == 2, "TRU: magnetic made true")
T.check(HR.heading(10, -4, false) == 10 and HR.heading(-5, -4, false) == 355, "MAG: magnetic, 0 to 360")

-- the labels and the boxes
local s = HR.new()
local i = {switch_true = false, lat = 50, lon = 8, alt_ft = 30000, vs_fpm = 0}
local function step(seconds, dt)
    dt = dt or 0.1
    local o
    for _ = 1, math.floor(seconds / dt + 0.5) do
        i.alt_ft = i.alt_ft + i.vs_fpm / 60 * dt
        o = HR.update(s, i, dt)
    end
    return o
end
local o = step(1)
T.check(not o.true_ref and o.nd == HR.ND_MAG and o.pfd == HR.PFD_MAG, "NORM at 50N: MAG on both")
i.switch_true = true
o = step(0.1)
T.check(o.true_ref and o.nd == HR.ND_TRU and o.pfd == HR.PFD_TRU, "TRUE: TRU in a white box on the ND, boxed on the PFD")
i.vs_fpm = -700
o = step(240)
T.equal(o.nd, HR.ND_TRU, "2,800 ft down at 700 fpm: still white (more than 800 fpm wanted)")
i.vs_fpm = -1000
o = step(119)
T.equal(o.nd, HR.ND_TRU, "1,980 ft down at 1,000 fpm: white")
o = step(1.2)
T.check(o.nd == HR.ND_TRU_AMBER or o.nd == HR.ND_TRU_OFF, "2,000 ft down at 1,000 fpm: the box amber (FCOM p.1110)")
local seen = {}
for _ = 1, 20 do seen[step(0.1).nd] = true end
T.check(seen[HR.ND_TRU_AMBER] and seen[HR.ND_TRU_OFF], "flashing")
o = step(10)
T.equal(o.nd, HR.ND_TRU_AMBER, "after 10 s amber, steady")
i.vs_fpm = 400
o = step(360)
T.equal(o.nd, HR.ND_TRU_AMBER, "2,400 ft up at 400 fpm: still amber (more than 500 fpm wanted)")
i.vs_fpm = 600
o = step(199)
T.equal(o.nd, HR.ND_TRU_AMBER, "1,990 ft up at 600 fpm: amber")
o = step(2)
T.equal(o.nd, HR.ND_TRU, "2,000 ft up at 600 fpm: white again")
i.vs_fpm = 0
i.switch_true = false
o = step(0.1)
T.check(not o.true_ref and o.nd == HR.ND_MAG_BOX and o.pfd == HR.PFD_MAG, "back to NORM: MAG in a box (FCOM p.1142)")
o = step(9.7)
T.equal(o.nd, HR.ND_MAG_BOX, "for 10 s")
o = step(0.5)
T.equal(o.nd, HR.ND_MAG, "then MAG alone")
i.lat = 83
o = step(0.1)
T.check(o.true_ref and o.nd == HR.ND_TRU, "NORM north of 82N: true north by itself")

-- the display glue: the heading and track in the reference
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
local function frames(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
local I = "sim/cockpit2/gauges/indicators/"
rt:set("sim/flightmodel/position/latitude", 50)
rt:set("sim/flightmodel/position/longitude", 8)
rt:set("sim/flightmodel/position/psi", 104)
rt:set("sim/flightmodel/position/mag_psi", 100)                 -- 4E
rt:set(I .. "heading_AHARS_deg_mag_pilot", 100)
rt:set(I .. "ground_track_mag_pilot", 106)
rt:set(I .. "heading_AHARS_deg_mag_copilot", 101)
rt:set(I .. "ground_track_mag_copilot", 107)
rt:set(I .. "wind_heading_deg_mag", 270)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)             -- MAP
rt:callout("flight_start")
frames(0.5)
local P, E = "laminar/B747/pfd/", "laminar/B747/efis/hdg_ref/"
T.check(near(rt:get(P .. "capt/hdg_deg"), 100, 1e-6) and near(rt:get(P .. "capt/trk_deg"), 106, 1e-6),
    "NORM: the Captain's heading and track magnetic")
T.check(rt:get(E .. "true") == 0 and rt:get(E .. "nd_label") == HR.ND_MAG and rt:get(E .. "pfd_label") == HR.PFD_MAG, "MAG")
local wind_mag = rt:get("laminar/B747/nd/capt/wind_deg")
rt:set("laminar/B747/toggle_switch/position", 30, 1)             -- HDG REF TRUE
frames(0.5)
T.check(near(rt:get(P .. "capt/hdg_deg"), 104, 1e-6) and near(rt:get(P .. "capt/trk_deg"), 110, 1e-6),
    "TRUE: the Captain's heading and track true (4E)")
T.check(near(rt:get(P .. "fo/hdg_deg"), 105, 1e-6) and near(rt:get(P .. "fo/trk_deg"), 111, 1e-6), "the F/O's too")
T.check(rt:get(E .. "true") == 1 and rt:get(E .. "nd_label") == HR.ND_TRU and rt:get(E .. "pfd_label") == HR.PFD_TRU, "TRU")
T.equal(rt:get(E .. "nd_plan_label"), HR.ND_TRU_OFF, "PLN: TRU without the box (FCOM p.1142)")
T.check(near(rt:get("laminar/B747/nd/capt/wind_deg"), wind_mag, 1e-6),
    "the wind arrow where it was: its direction and the display's top both true")

-- the AFDS: the MCP heading in the reference
local ra = xtlua.new()
ra:load("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua")
ra:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
ra:set("laminar/B747/newsimconfig", 1)
ra:set("xtlua/fms", "[]")
ra:set("sim/time/total_running_time_sec", 10)
ra:callout("flight_start")
ra:set("sim/flightmodel/position/psi", 104)
ra:set("sim/flightmodel/position/mag_psi", 100)
ra:set("sim/cockpit2/autopilot/heading_status", 2)               -- X-Plane's HDG SEL
-- HDG SEL with a F/D ON (neither the A/P nor a F/D: no modes at all, FCOM
-- p.660; the roll modes the AFDS model's: 6-3 steps 1a, 1b)
ra:set("laminar/B747/toggle_switch/position", 23, 1)
ra:set("laminar/B747/autopilot/heading/target", -1)              -- no slew of the MCP heading (made at 0 here)
ra:set("laminar/B747/autopilot/heading/degrees", 90)
for _ = 1, 3 do ra:frame(1 / 30) end
ra:command("laminar/B747/autopilot/button_switch/heading_select")
for _ = 1, 30 do ra:frame(1 / 30) end
T.check(near(ra:get("sim/cockpit/autopilot/heading_mag"), 90, 1e-6), "MAG: X-Plane's heading mode on the MCP's 090")
ra:set("laminar/B747/efis/hdg_ref/true", 1)
for _ = 1, 30 do ra:frame(1 / 30) end
T.check(near(ra:get("sim/cockpit/autopilot/heading_mag"), 86, 1e-6),
    "TRU: the MCP's 090 true is 086 magnetic for X-Plane (ATA22 p.358: on the true heading)")
local ROLL = "laminar/B747/autopilot/FMA/active_roll_mode"
T.equal(ra:get(ROLL), 6, "HDG SEL")
ra:set("laminar/B747/toggle_switch/position", 30, 1)             -- the switch moved in HDG SEL
for _ = 1, 5 do ra:frame(1 / 30) end
T.equal(ra:get(ROLL), 7, "the HDG REF switch moved in HDG SEL: HDG HOLD (FCOM p.1046, ATA22 p.352)")
ra:command("laminar/B747/autopilot/button_switch/LNAV")
ra:set("laminar/B747/toggle_switch/position", 30, 0)
for _ = 1, 5 do ra:frame(1 / 30) end
T.equal(ra:get(ROLL), 7, "not out of HDG SEL (HDG HOLD, LNAV armed): nothing")

T.done()
