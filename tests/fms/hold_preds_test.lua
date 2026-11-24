-- Run from the repository root with LuaJIT: luajit tests/fms/hold_preds_test.lua
-- RTE HOLD's FIX ETA, HOLD AVAIL and BEST SPEED (2026-11-24, stage 4 review
-- CDU-4; notes/ATA-34-61-FMC.md §177.7) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), on the synthetic navigation data: from the
-- predictions and the performance data (FCOM p.1415, p.1417's figures,
-- p.1419 (11.43.31) items 8, 10, 11; FMSPG p.161-162, p.223; ATA34_2
-- p.574). Before, dashes always.
--  - a hold ahead (BRAVO): FIX ETA the predictions' time there, with an EFC
--    TIME the first crossing at or after it; HOLD AVAIL the predictions'
--    fuel at the destination less RESERVES at the holding table's fuel flow
--    (four engines) at the weight and altitude there; BEST SPEED the
--    holding table's at the FMC's gross weight and the present altitude,
--    limited by the speed transition below its altitude;
--  - a hold LNAV flies (PPOS in the air): FIX ETA within the racetrack's
--    loop;
--  - without predictions nor PERF INIT: dashes (hold_pages_test).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("hold_preds")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local pw = P.tables(0)

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
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:set("sim/cockpit2/clock_timer/zulu_time_hours", 8)
rt:set("sim/cockpit2/clock_timer/zulu_time_minutes", 0)
rt:set("sim/cockpit2/clock_timer/zulu_time_seconds", 0)
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
local function enter(text, lsk)
    for _ = 1, 30 do rt:command(K .. "key/clear") end
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function right(n) return (line(n):match("(%S+)%s*$")) end
local st = fms.ns.B747_fmc_route
-- "HHMM.T" for a time t s from now, and the time of day (minutes)
local function eta(t)
    local _, h, m, f = fms.ns.get_ETA_for_Distance(0, t)
    return string.format("%02d%02d.%d", h, m, math.min(9, math.floor(f * 10))), h * 60 + m + f
end

-- PERF INIT (ZFW 220, RESERVES 10, CI 100, FL250) and the route ZZAA
-- RW16R, DIRECT ALPHA, Z1 to CHARL, ZZBB, active; HOLD AT BRAVO, EXEC
key("func_key/index")
enter("220", "L3")
enter("10", "L4")
enter("100", "L5")
enter("FL250", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("Z1", "L2")
enter("CHARL", "R2")
key("ls_key/R6")
key("key/execute")
key("func_key/dep_arr")
enter("BRAVO", "L6")
key("key/execute")
T.check(line(1):find("ACT RTE 1 HOLD") and line(3):find("^BRAVO"), "ACT RTE 1 HOLD at BRAVO: " .. line(1) .. "|" .. line(3))
frames(11)

-- the hold ahead
local pred = fms.ns.B747_fms_preds()
local legs = st.rte.legs
local j
for k, l in ipairs(legs) do if l.pt == "HM" then j = k end end
T.check(pred and j and pred.pts[j], "the predictions at the hold's fix")
local q = pred.pts[j]
local fixEta = eta(q.t)
T.equal(right(5), fixEta, "FIX ETA: the predicted crossing of BRAVO " .. fixEta .. " (before: ----.-)")
T.equal(small(5):sub(-1), "Z", "its Z small")
local inp = fms.ns.B747_fms_pred_input_last()
local kg = inp.gw - (inp.fuel - q.fuel)
local _, ff = P.hold(pw, kg, q.h)
local min = math.floor((pred.dest.fuel - 10000) / (4 * ff) * 60)
local avail = string.format("%d+%02d", math.floor(min / 60), min % 60)
T.equal(right(9), avail, string.format("HOLD AVAIL %s: %.0f kg at ZZBB less 10.0 t RESERVES at %.0f kg/h (before: -+--)", avail, pred.dest.fuel, 4 * ff))
T.check(min > 30 and min < 600, "(a time between half an hour and ten hours: " .. min .. " min)")
local gw = fms.ns.perf_gw_t() * 1000
local best = math.min(P.hold(pw, gw, 100), 240)
T.equal(right(11), string.format("%d", math.floor(best + 0.5)), string.format("BEST SPEED: the holding table at %.0f kg and 100 ft, at most SPD TRANS 240 (before: ---)", gw))
T.equal(small(11):sub(-2), "KT", "its KT small")

-- an EFC TIME 30 minutes after the predicted crossing: the first crossing
-- at or after it (FCOM p.1419 item 8)
local _, fixMin = eta(q.t)
local efcMin = math.floor(fixMin + 30)
local efc = string.format("%02d%02d", math.floor(efcMin / 60) % 24, efcMin % 60)
enter(efc, "R3")
key("key/execute")
T.check(line(7):find(efc .. " $"), "EFC TIME " .. efc .. ": " .. line(7))
local hh, mm, t = right(5):match("^(%d%d)(%d%d)%.(%d)$")
local shown = hh and tonumber(hh) * 60 + tonumber(mm) + tonumber(t) / 10 or -1
T.check(shown >= efcMin - 0.1 and shown < efcMin + 8, string.format("FIX ETA %s: at or after the EFC %s, within a loop", right(5), efc))
enter("DELETE", "R3")
key("key/execute")
T.equal(right(5), fixEta, "EFC deleted: the predicted crossing again")

-- a hold not manually ended (HOLD AT an altitude: HA): no HOLD AVAIL
-- (FMSPG p.223)
legs[j].pt = "HA"
frames(0.2)
T.equal(right(9), "-+--", "HOLD AVAIL only for a manually ended hold: dashes for HA")
legs[j].pt = "HM"
frames(0.2)

-- in the air at 3,000 ft, 210 kt: a PPOS hold, LNAV in its direct entry:
-- FIX ETA about a loop on (the racetrack's 2 legs and 2 turns)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 3000)
rt:set("sim/flightmodel/position/latitude", 35.2)
rt:set("sim/flightmodel/position/longitude", 140.3)
rt:set("sim/flightmodel/position/hpath", 45)
rt:set("sim/flightmodel2/position/groundspeed", 210 / 1.94384)
rt:set("sim/flightmodel/position/true_airspeed", 210 / 1.94384)
frames(0.5)
key("func_key/dep_arr")
key("ls_key/L6")
key("ls_key/R6")
key("key/execute")
frames(1)
T.equal(rt:get("laminar/B747/fms/lnav/hold_phase"), 2, "LNAV: the PPOS hold's direct entry")
local h = fms.ns.B747_fmc_lnav.hp
T.check(h and h.t, "LNAV's racetrack")
local loop = (2 * h.t.l + 2 * math.pi * h.t.r) / 210 * 3600
local _, nowMin = eta(0)
hh, mm, t = right(5):match("^(%d%d)(%d%d)%.(%d)$")
T.check(hh ~= nil, "FIX ETA in the hold: " .. line(5))
shown = hh and tonumber(hh) * 60 + tonumber(mm) + tonumber(t) / 10 or -1
T.check(shown - nowMin > 0.8 * loop / 60 and shown - nowMin < 1.1 * loop / 60,
    string.format("the next crossing a loop on (%.1f min, the loop %.1f min: the turn from the fix, the legs and the other turn)", shown - nowMin, loop / 60))
-- the inbound leg 3 NM before the fix: half a minute or so
h.phase = "inbound"
local fix = h.t.f
rt:set("sim/flightmodel/position/latitude", fix.lat - 3 / 60 * math.cos(math.rad(h.t.u)))
rt:set("sim/flightmodel/position/longitude", fix.lon - 3 / 60 * math.sin(math.rad(h.t.u)) / math.cos(math.rad(fix.lat)))
rt:set("sim/flightmodel/position/hpath", h.t.u)
fms.ns.B747_fmc_lnav.hp.phase = "inbound"
local mins = function()
    hh, mm, t = right(5):match("^(%d%d)(%d%d)%.(%d)$")
    return hh and tonumber(hh) * 60 + tonumber(mm) + tonumber(t) / 10 - nowMin or -1
end
frames(0.1)
if fms.ns.B747_fmc_lnav.hp and fms.ns.B747_fmc_lnav.hp.phase == "inbound" then
    T.check(mins() >= 0.7 and mins() <= 1.0, string.format("inbound 3 NM out at 210 kt: %.1f min", mins()))
end
-- BEST SPEED at 15,000 ft (above the speed transition): the holding
-- table's at the present altitude (ATA34_2 p.574)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 15000)
frames(0.2)
gw = fms.ns.perf_gw_t() * 1000
best = P.hold(pw, gw, 15000)
T.check(best > 240 and best < 300, string.format("(the table: %.0f kt at %.0f kg, FL150)", best, gw))
T.equal(right(11), string.format("%d", math.floor(best + 0.5)), "BEST SPEED at FL150: the table's")
T.done()
