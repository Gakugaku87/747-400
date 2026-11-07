-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_targets_test.lua
-- VNAV's FMC altitude from the route's constraints (6-1/6-2 step 9i, its
-- second patch; notes/ATA-34-61-FMC.md §150) in the FMS module as XTLua
-- runs it (tests/lib/xtlua.lua): the predictions' legs with their
-- procedures (ZZAA's ZULU1 SID, ZZBB's R09 approach); the climb's target
-- (laminar/B747/fms/vnav/alt) from the climb's list (vnav_geo_set): an
-- arrival's AT OR BELOW under the airplane, in the list by the half of the
-- way, not the target (FCOM p.1258: an arrival's waypoints the descent's;
-- a first patch of step 9i kept it at any altitude and the climb stopped
-- under it until its waypoint), an enroute one (the crew's) before the T/C
-- the target at any altitude (FMSPG p.128 (3.3-19)); the descent's FMC
-- altitude for an AT OR BELOW above the path: the lower of it and the path
-- at its point (FMSPG p.227 (4-16); a first patch gave its altitude, above
-- the airplane: the AFDS levelled under it).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("vnav_targets")
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
rt:set("sim/cockpit2/clock_timer/zulu_time_hours", 16)
rt:set("sim/cockpit2/clock_timer/zulu_time_minutes", 30)
rt:set("sim/flightmodel/weight/m_total", 260000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
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
local function preds() fms.ns.B747_fms_preds_now() frames(0.5) end
local ALT = "laminar/B747/fms/vnav/alt"
local PHASE = "laminar/B747/fms/vnav/phase"

-- PERF INIT: ZFW 220 t, CI 100, CRZ ALT FL350; ZZAA BRAVO ZZBB, ZZAA's
-- ZULU1 (RW34L, ALPHA) and ZZBB's R09, active
key("func_key/index")
enter("220", "L3")
enter("100", "L5")
enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
key("func_key/next_pg")
enter("BRAVO", "R1")
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
local R, st = fms.ns.B747_route_model, fms.ns.B747_fmc_route
T.equal(R.set_departure(st, "ZULU1", "RW34L", "ALPHA"), nil, "ZULU1 RW34L ALPHA")
T.equal(R.set_arrival(st, nil, {id = "R09"}), nil, "R09")
key("key/execute")
frames(0.5)
T.check(st.active, "the route active")

-- the predictions' legs carry their procedures (for the climb's list)
local s = fms.ns.B747_fms_pred_input(35000)
local procs = {}
for _, l in ipairs(s.legs) do procs[l.name] = l.proc or "-" end
T.equal(procs.ZZV, "SID", "ZZV: the SID's")
T.equal(procs.BRAVO, "-", "BRAVO: enroute")
T.equal(procs.ZB002, "APPR", "ZB002: the approach's")

-- the climb at 15,000 ft (FL350 CRZ ALT, the MCP at FL360), VNAV not engaged
-- (no CHECK ALT TGT); the climb's list made here (vnav_geo_set, as the
-- predictions make it; no SID ahead: the half of the way): an AT OR BELOW
-- 12,000 ft 30 NM ahead
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 15000)
rt:set("sim/flightmodel2/position/pressure_altitude", 15000)
rt:set("sim/flightmodel/position/elevation", 15000 * 0.3048)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 36000)
rt:set("laminar/B747/autopilot/vnav_state", 0)
preds()
local F1 = {ident = "TF1", lat = 35, lon = 140}
local F2 = {ident = "TF2", lat = 35, lon = 140.6}
local F3 = {ident = "TF3", lat = 35, lon = 141.2}
local function legs(proc2, con2, con3)
    return {{name = "TF1", dist = 0, p1 = F1}, {name = "TF2", dist = 30, con = con2, p1 = F2, proc = proc2},
        {name = "TF3", dist = 30, con = con3, p1 = F3, proc = proc2}}
end
-- an arrival's (STAR): not the target, CRZ ALT
fms.ns.vnav_geo_set({legs = legs("STAR", {kind = "B", a = 12000}, {kind = "AT", a = 3000}), ed = 3}, {tc = 45})
frames(0.2)
T.equal(rt:get(PHASE), 1, "the climb")
T.equal(rt:get(ALT), 35000, "an arrival's AT OR BELOW 12,000 under the airplane: not the target, CRZ ALT (FCOM p.1258)")
-- an enroute one (the crew's) before the T/C at 45 NM: the target at any
-- altitude (FMSPG p.128 (3.3-19): VNAV levels until its waypoint)
fms.ns.vnav_geo_set({legs = legs(nil, {kind = "B", a = 12000}, {kind = "AT", a = 3000}), ed = 3}, {tc = 45})
frames(0.2)
T.equal(rt:get(ALT), 12000, "an enroute AT OR BELOW 12,000 before the T/C: the target (the AFDS's level)")
-- after the T/C (at 20 NM): not the target
fms.ns.vnav_geo_set({legs = legs(nil, {kind = "B", a = 12000}, {kind = "AT", a = 3000}), ed = 3}, {tc = 20})
frames(0.2)
T.equal(rt:get(ALT), 35000, "after the T/C: not the target")

-- the descent at 28,000 ft on the path (10,000 ft at the E/D 60 NM out,
-- 28,000 ft here), the MCP at 10,000: an AT OR BELOW 24,000 ft at TF2, 30 NM
-- on, where the path is at 19,000 ft: the FMC altitude 19,000 (FMSPG p.227
-- (4-16)); an AT OR ABOVE there: its 24,000
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 28000)
rt:set("sim/flightmodel2/position/pressure_altitude", 28000)
rt:set("sim/flightmodel/position/elevation", 28000 * 0.3048)
rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 10000)
preds()
local dp = {x = {60, 0}, h = {10000, 28000}, k = {"idle", "idle"}}
fms.ns.vnav_geo_set({legs = legs("STAR", {kind = "B", a = 24000}, {kind = "AT", a = 10000}), ed = 3, clb_last = 0},
    {dp = dp, ed = 60, td = 0})
frames(0.2)
T.equal(rt:get(PHASE), 3, "the descent")
T.near(rt:get(ALT), 19000, 5, "an AT OR BELOW 24,000 over the path's 19,000 ft at its point: the FMC altitude 19,000 (before: 24,000)")
fms.ns.vnav_geo_set({legs = legs("STAR", {kind = "A", a = 24000}, {kind = "AT", a = 10000}), ed = 3, clb_last = 0},
    {dp = dp, ed = 60, td = 0})
frames(0.2)
T.equal(rt:get(ALT), 24000, "an AT OR ABOVE 24,000 there: its altitude (a floor)")
T.done()
