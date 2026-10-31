-- Run from the repository root with LuaJIT: luajit tests/fms/rta_speed_test.lua
-- The RTA's speed (6-1/6-2 step 9h5b; notes/ATA-34-61-FMC.md §85; FCOM
-- p.1269, p.1354, p.1372, p.1383-1384, p.1434) in the FMS module as XTLua
-- runs it (tests/lib/xtlua.lua), on the synthetic CIFP of ZZAA's active
-- route in the cruise at FL350: an RTA a minute after the predicted time
-- at a fix: a slower cruise Mach that meets it within 30 s, VNAV's target,
-- the CRZ page's ACT RTA CRZ and RTA SPD, PROGRESS's RTA SPD, RTA
-- PROGRESS's RTA SPD; a time too early: the Mach at its bound and UNABLE
-- RTA; <ECON ends it; DELETE of the time: ECON again.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("rta_speed")
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
rt:set("sim/flightmodel/weight/m_total", 270000)
rt:set("sim/flightmodel/weight/m_fuel_total", 70000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
rt:set("sim/cockpit2/clock_timer/zulu_time_hours", 16)
rt:set("sim/cockpit2/clock_timer/zulu_time_minutes", 30)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
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
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
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
local function delete(lsk) clear() rt:command(K .. "key/del") frames(0.1) key("ls_key/" .. lsk) end
local function pad() return (line(14):gsub("%s+$", "")) end
local P = fms.ns.B747_perf_db
local R = fms.ns.B747_rta_model

-- PERF INIT (ZFW 200 t: 270 t, cost index 100, CRZ ALT FL350), the route
-- ZZAA to ZZAA (as pred_glue_test.lua), ACTIVATE and EXEC
key("func_key/index")
enter("200", "L3")
enter("100", "L5")
enter("350", "R1")
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
T.check(fms.ns.B747_fmc_route.active, "the route active")

-- in the air at FL350, the cruise
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 35)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 280)
frames(11)
T.equal(fms.ns.B747_fms_vnav_phase(), "CRZ", "FL350: the cruise")
local pred = fms.ns.B747_fms_preds()
T.check(pred ~= nil, "the predictions")
-- the RTA's fix: the last leg ahead in the cruise (before the T/D)
local legs = fms.ns.B747_fmc_route.rte.legs
local fixI, fix
for i, l in ipairs(legs) do
    local p = pred.pts[i]
    if l.fix and p and (not pred.td_t or p.t < pred.td_t - 60) then fixI, fix = i, l.fix.ident end
end
T.check(fix ~= nil, "a fix in the cruise: " .. tostring(fix))
local now = 16 * 60 + 30
local eta = now + pred.pts[fixI].t / 60
local base = fms.ns.B747_pred_model.crz_mach(P, select(3, fms.ns.B747_fms_schedules(fms.ns.B747_fms_perf(), true)), 35000, 270000)
print(string.format("fix %s at %.1f min (%.1f min from now), T/D at %.1f min, base M%.3f", fix, eta, pred.pts[fixI].t / 60,
    (pred.td_t or 0) / 60, base))

-- an RTA a minute after its time: slower, met within 30 s (FCOM p.1269)
local function hhmm(t) return R.time_text(t):sub(1, 6) end
key("func_key/prog")
key("func_key/prev_pg")
enter(fix, "L1")
enter(hhmm(eta + 1), "R1")
key("key/execute")
frames(11)
local s = fms.ns.B747_fms_rta()
T.check(s.active and s.mach, "the RTA active, its Mach")
pred = fms.ns.B747_fms_preds()
local d = now + pred.pts[fixI].t / 60 - s.active.time
print(string.format("RTA %.1f: M%.3f, predicted %.2f min off", s.active.time, s.mach or -1, d))
T.check(s.mach < base - 0.01, string.format("slower than the base M%.3f: M%.3f", base, s.mach))
T.check(math.abs(d) <= R.TOL_MIN, string.format("the predicted time within 30 s: %.2f min", d))
T.equal(rt:get("laminar/B747/fms/notification", 48), 0, "not UNABLE RTA")
-- VNAV's target, the pages
T.near(rt:get("laminar/B747/fms/vnav/mach"), s.mach, 1e-4, "VNAV's target the RTA's Mach")
local mt = string.format(".%03d", math.floor(s.mach * 1000 + 0.5))
T.check(line(5):find("^%" .. mt), "RTA PROGRESS's 2L RTA SPD " .. mt .. ": " .. line(5))
key("func_key/des")
T.check(line(1):find("ACT RTA CRZ"), "the CRZ page: ACT RTA CRZ (FCOM p.1354): " .. line(1))
T.check(line(5):find("^%" .. mt) and small(4):find("^ RTA SPD"), "2L RTA SPD " .. mt .. ": " .. line(5))
T.check(line(11):find("^<ECON"), "5L <ECON: " .. line(11))
key("func_key/prog")
T.check(small(10):find("^ RTA SPD"), "PROGRESS 5L RTA SPD (FCOM p.1372): " .. small(10))

-- a time 5 min early: the Mach at its bound (MAX SPD .880 or VMO/MMO
-- less 16 kt), UNABLE RTA (FCOM p.1434)
key("func_key/prev_pg")
enter(hhmm(eta - 5), "R1")
key("key/execute")
frames(11)
frames(11)
print(string.format("early: M%.3f, UNABLE %d", s.mach or -1, rt:get("laminar/B747/fms/notification", 48)))
T.check(s.mach > 0.87, string.format("at the bound: M%.3f", s.mach))
T.equal(rt:get("laminar/B747/fms/notification", 48), 1, "UNABLE RTA")
T.check(pad():find("UNABLE RTA"), "the message: " .. pad())
clear()
-- <ECON (5L on the CRZ page) ends it (FCOM p.1354)
key("func_key/des")
key("ls_key/L5")
T.check(s.active == nil, "<ECON: the RTA ended")
T.check(line(1):find("ECON CRZ") and not line(1):find("RTA"), "ACT ECON CRZ: " .. line(1))
frames(11)
T.equal(rt:get("laminar/B747/fms/notification", 48), 0, "UNABLE RTA gone")
-- PRIOR RTA> and EXEC, then DELETE of the time: ECON again (FCOM p.1384)
key("func_key/prog")
key("func_key/prev_pg")
key("ls_key/R6")
key("key/execute")
T.check(s.active ~= nil, "PRIOR RTA> and EXEC: active again")
key("func_key/des")
enter(".80", "L2")
T.check(s.active == nil, "a crew's speed on the CRZ page: ended (estimate)")
key("func_key/prog")
key("func_key/prev_pg")
key("ls_key/R6")
key("key/execute")
frames(11)
delete("R1")
T.check(s.active == nil and rt:get("laminar/B747/fms/vnav/mach") ~= s.mach, "DELETE of the time: ended")
T.equal(fms.ns.fmsModules["data"]["crzspdmode"], "E", "ECON again (FCOM p.1384)")
T.done()
