-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_turns_test.lua
-- The turn transitions in VNAV's distance (step LF2; notes/
-- ATA-34-61-FMC.md §127; the FMC's path joins the legs with its turns:
-- ATA34_2 p.615, p.626): B747.68.lnav_model.lua's transition (a fly-by
-- turn's arc against the tangents it cuts, a turn flown over its fix or
-- (step 6d3) a conditional leg's end as LNAV steers it, the path model's
-- turn into a leg), B747.68.vnav_model.lua's turn_dist (the distance flown
-- through a turn flown over its fix), and in the FMS module as XTLua runs
-- it (tests/lib/xtlua.lua): the predictions' leg after a turn the longer or
-- shorter by it, the ND's points on the great circles, VNAV's distance to
-- go not dropping when the fix is sequenced and taken down by the distance
-- flown until LNAV is on the leg. Test line flight s198 (2026-11-01):
-- ATMUG's 157-degree turn at 370 kt added about 12 NM, VNAV 2,000 ft under
-- its path.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("vnav_turns")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")
local V = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vnav_model.lua")

local function line(a, b)
    local c, d = P.course(a, b)
    return {kind = "line", a = a, b = b, crs = c, len = d, term = "fix"}
end
-- a fly-by turn of 90 degrees at 300 kt: r (25 degrees of bank) 2.81 NM,
-- the arc's 4.42 NM against the tangents' 5.66 NM
local A = {lat = 35, lon = 135}
local B = P.point(A, 90, 30)
local C = P.point(B, 0, 30)
local tr = P.turn(line(A, B), line(B, C), 300)
T.near(L.transition(P, line(A, B), line(B, C), 300), tr.r * math.abs(tr.delta) * math.pi / 180 - 2 * tr.d, 1e-9, "a fly-by turn: its arc less the tangents")
T.near(L.transition(P, line(A, B), line(B, C), 300), -1.22, 0.02, "90 degrees at 300 kt: 1.22 NM shorter")
T.equal(L.transition(P, line(A, B), line(B, P.point(B, 90, 30)), 300), 0, "straight on: none")
-- s198's ATMUG: from XAC (268 degrees) onto ATMUG-SAKVA (111 degrees), a
-- left turn of 157 degrees flown over the fix
local XAC = {lat = 34.712252778, lon = 139.414016667}
local ATMUG = {lat = 34.558322222, lon = 134.127066667}
local SAKVA = {lat = 34.3705, lon = 134.723722222}
local e1, e2 = line(XAC, ATMUG), line(ATMUG, SAKVA)
local flown, dtg = L.flyover(P, e2, ATMUG, P.end_course(e1), 370)
T.check(flown and dtg and dtg < e2.len, string.format("over ATMUG at 370 kt: on the leg after %.1f NM flown, %.1f NM to go", flown or -1, dtg or -1))
local x370 = L.transition(P, e1, e2, 370)
T.check(x370 > 10 and x370 < 15, string.format("its turn %.1f NM longer (s198: about 12 NM)", x370))
local x250 = L.transition(P, e1, e2, 250)
T.check(x250 > 3 and x250 < x370, string.format("at 250 kt shorter: %.1f NM", x250))
T.equal(L.transition(P, {kind = "hold", b = ATMUG, term = "fix"}, e2, 370), 0, "after a hold: none")
T.equal(L.transition(P, e1, {kind = "disc"}, 370), 0, "into a discontinuity: none")
local fo = line(XAC, ATMUG)
fo.term = "alt"
T.near(L.transition(P, fo, e2, 370), x370, 1e-9, "a conditional leg's end: as a fly-over fix (step 6d3)")
fo.term = "intc"
T.equal(L.transition(P, fo, e2, 370), 0, "an intercept's end: none (its turn begins before it)")
-- (step 6d3) the path model's turn into a heading leg: its arc (3 NM) and
-- the leg from its end (10 NM) against the great circle from the turn's
-- start to the leg's end
local tA = P.point(ATMUG, 90, 2)
local hB = P.point(tA, 180, 10)
local _, ab = P.course(ATMUG, hB)
local hd = {kind = "heading", a = tA, b = hB, hdg = 180, len = 10, term = "radial",
    turn_in = {from = ATMUG, len = 3}}
T.near(L.transition(P, e1, hd, 370), 3 + 10 - ab, 1e-9, "a turn into a leg: its arc and the leg against the great circle")
hd.b = nil
T.equal(L.transition(P, e1, hd, 370), 0, "no end: none")

-- turn_dist: 20 NM to go as the fix is sequenced, 360 kt (0.1 NM a second)
local t = {d = 20, t = 0}
local d, on = V.turn_dist(t, 8, 360, 10, false)
T.near(d, 19, 1e-9, "10 s on: 1 NM flown off the 20 NM")
T.check(on, "the turn still counts")
d = V.turn_dist(t, 12, 360, 50, false)
T.near(d, 15, 1e-9, "50 s: 5 NM flown off (the great circles' 12 NM under it)")
d, on = V.turn_dist(t, 14.95, 360, 51, false)
T.near(d, 14.9, 1e-9, "the great circles' distance back up to it: the flown one's last")
T.check(on, "blending")
d, on = V.turn_dist(t, 14.85, 360, 52, false)
T.near(d, 14.85 - 0.05 * (1 - 1 / V.TURN_BLEND_S), 1e-9, "then the great circles' with the difference blended out")
d, on = V.turn_dist(t, 14, 360, 51 + V.TURN_BLEND_S, false)
T.near(d, 14, 1e-9, "after TURN_BLEND_S the great circles' alone")
T.check(not on, "over")
local t2 = {d = 20, t = 0}
d, on = V.turn_dist(t2, 15, 360, 30, true)
T.near(d, 17, 1e-9, "on the leg before: the flown distance's difference (2 NM) blended out from 17")
d = V.turn_dist(t2, 14.5, 360, 30 + V.TURN_BLEND_S / 2, true)
T.near(d, 15.5, 1e-9, "half way: 1 NM of it")

-- the FMS module: ZZAA RW34L ZULU1, ALPHA, DELTA, the STAR ALPHA1 from
-- DELTA back south to ALPHA (DELTA's turn of 180 degrees flown over the
-- fix), ILS16R
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local K = "laminar/B747/fms1/"
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do rt:command(K .. "alphanum_key/" .. ch) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
key("func_key/index")
enter("100", "L5")
enter("100", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("DELTA", "R2")
key("func_key/clb")
key("ls_key/L1")                 -- DEPARTURES
key("ls_key/L1")                 -- ZULU1
key("ls_key/R2")                 -- 34L
key("ls_key/L2")                 -- ALPHA
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ARRIVALS
key("ls_key/L1")                 -- ALPHA1
key("ls_key/L2")                 -- DELTA
key("ls_key/R1")                 -- ILS16R
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1)
local st = fms.ns.B747_fmc_route
T.check(st.active, "the route active")

-- the airplane at 10,000 ft (CRZ ALT), 250 kt, 20 NM south of DELTA heading
-- north, DIRECT TO DELTA; LNAV and VNAV engaged
local DELTA, ALPHA = {lat = 37.0, lon = 140.5}, {lat = 35.5, lon = 140.5}
local c1 = P.course(ALPHA, DELTA)
local function at(p, trk)
    rt:set("sim/flightmodel/position/latitude", p.lat)
    rt:set("sim/flightmodel/position/longitude", p.lon)
    rt:set("sim/flightmodel/position/hpath", trk)
    rt:set("sim/flightmodel/position/psi", trk)
    rt:set("sim/flightmodel2/position/groundspeed", 128.6)
    rt:set("sim/flightmodel/position/true_airspeed", 128.6)
end
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 10000)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 250)
local p20 = P.point(DELTA, (c1 + 180) % 360, 20)
at(p20, c1)
frames(0.5)
key("func_key/legs")
enter("DELTA", "L1")
key("key/execute")
rt:set("laminar/B747/autopilot/lnav_state", 2)
rt:set("laminar/B747/autopilot/vnav_state", 2)
fms.ns.B747_fms_preds_now()
frames(1)
local legs = st.rte.legs
T.check(legs[1].fix and legs[1].fix.ident == "DELTA" and legs[2].fix and legs[2].fix.ident == "ALPHA",
    "DIRECT TO DELTA, then the STAR's ALPHA back south")
local s = fms.ns.B747_fms_pred_input(10000)
local lD = s.legs[2]
T.check(lD.turn and lD.turn > 3, string.format("the leg after DELTA the longer by its turn flown over it: %.1f NM", lD.turn or -1))
local _, geo = P.course(DELTA, ALPHA)
T.near(lD.dist, geo + lD.turn, 0.01, "its distance the great circle's and the turn's")
local d0 = rt:get("laminar/B747/fms/vnav/dist")
T.check(d0 > 20, string.format("VNAV's distance to go %.1f NM", d0))
-- 20.1 NM on: just past DELTA, sequenced
at(P.point(DELTA, c1, 0.1), c1)
frames(0.2)
T.equal(st.rte.legs[1].fix and st.rte.legs[1].fix.ident, "ALPHA", "DELTA sequenced")
local d1 = rt:get("laminar/B747/fms/vnav/dist")
T.near(d1, d0 - 20.1, 0.3, string.format("the distance to go on through the sequencing: %.1f NM (the great circles' %.1f less)", d1, lD.turn))
-- 10 s on at 250 kt (0.69 NM), still turning away
frames(10)
local d2 = rt:get("laminar/B747/fms/vnav/dist")
T.near(d2, d1 - 250 * 10 / 3600, 0.05, string.format("in the turn the distance flown taken off: %.2f NM", d2))
-- on the leg to ALPHA, on its track: the difference left blended out, then
-- the great circles' alone
local cA = P.course(DELTA, ALPHA)
local p5 = P.point(DELTA, cA, 5)
at(p5, cA)
frames(0.2)
local d3 = rt:get("laminar/B747/fms/vnav/dist")
T.near(d3, d2 - 250 * 0.2 / 3600, 0.2, string.format("on the leg: from the flown distance (%.2f NM) as the blend starts", d3))
frames(V.TURN_BLEND_S + 1)
local d4 = rt:get("laminar/B747/fms/vnav/dist")
local _, toA = P.course(p5, ALPHA)
T.near(d4, toA + (d0 - 20 - geo - lD.turn), 0.3, string.format("after the blend the great circles' %.1f NM", d4))

T.done()
