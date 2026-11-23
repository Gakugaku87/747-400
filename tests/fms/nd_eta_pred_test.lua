-- Run from the repository root with LuaJIT: luajit tests/fms/nd_eta_pred_test.lua
-- The ND's active waypoint and route data from the FMC's predictions
-- (2026-11-24, stage 4 review FMC-6 = DSP-2; notes/ATA-34-61-FMC.md §177.5)
-- in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic navigation data: the active waypoint's ETA
-- (laminar/B747/nd/waypoint_eta) and the DATA ETAs (laminar/B747/fms/
-- route_eta) the predictions' times, PROGRESS's and RTE DATA's (FCOM
-- p.1147 (10.40.39): the FMS-calculated ETA; p.1148 (10.40.40)), on the
-- ground too; without predictions, the old estimate in the air (the
-- distance over the greater of the ground speed and 275 kt), none on the
-- ground. Before, that estimate always (early under 275 kt), and dashes on
-- the ground. The test plays X-Plane: xtlua/fms from the rows the FMC
-- loaded (as route_sync_test).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("nd_eta_pred")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["xtlua/fms"] = "string"}
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
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for _ = 1, 30 do rt:command(K .. "key/clear") end
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function xpfms() return rt:get("xtlua/loadtoFMS") or "" end
-- X-Plane with the plan the FMC loaded last (route_sync_test's)
local function xplane(active)
    local out, k = {}, 0
    for t, ident, alt, lat, lon in xpfms():gmatch("\n(%d+) (%S+) %S+ (%S+) (%S+) (%S+)") do
        k = k + 1
        out[k] = string.format('[0,%d,0,0,%s,%s,"%s","%s",%s,%s]', t == "1" and 1 or 2048, lat, lon, ident, ident,
            alt, tostring(k == active))
    end
    rt:set("xtlua/fms", "[" .. table.concat(out, ",") .. "]")
    frames(0.2)
    return k
end
local ND_WPT, ND_DIST, ND_ETA = "laminar/B747/nd/current_waypoint", "laminar/B747/nd/waypoint_distance", "laminar/B747/nd/waypoint_eta"
local ROUTE_ETA = "laminar/B747/fms/route_eta"
local function route_eta()
    local out = {}
    for v in rt:get(ROUTE_ETA):gmatch("%-?%d+") do out[#out + 1] = tonumber(v) end
    return out
end
-- the FMC's ETA for a predicted time t (s from now): "HHMM" and minutes of the day
local function eta(t)
    local _, h, m = fms.ns.get_ETA_for_Distance(0, t)
    return string.format("%02d%02d", h, m), h * 60 + m
end

-- the route ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL, ZZBB; ACTIVATE, EXEC
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("Z1", "L2")
enter("CHARL", "R2")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1.2)
local n = xplane(1)
T.equal(n, 6, "X-Plane's plan: ZZAA RW16R ALPHA BRAVO CHARL ZZBB")
frames(1.2)
local st = fms.ns.B747_fmc_route
T.check(st.active, "the route active")

-- on the ground without predictions (no CRZ ALT): the active waypoint and
-- its distance (before: dashes on the ground), no ETA
T.equal(fms.ns.B747_fms_preds(), nil, "no predictions yet")
T.equal(rt:get(ND_WPT), "ALPHA", "on the ground: the active waypoint ALPHA (before: -----)")
T.check(rt:get(ND_DIST):find("^%s*%d+%.%dnm$"), "its distance: " .. rt:get(ND_DIST))
T.equal(rt:get(ND_ETA), "------Z", "no ETA without predictions on the ground")
T.equal(rt:get(ROUTE_ETA), "[-1,-1,-1,-1,-1,-1]", "nor DATA ETAs")

-- PERF INIT: predictions on the ground; the ND's ETA PROGRESS's TO ETA,
-- the DATA ETAs the predicted times (RTE DATA's)
key("func_key/index")
enter("220", "L3")
enter("100", "L5")
enter("10", "L4")
enter("FL250", "R1")
frames(11)
local pred = fms.ns.B747_fms_preds()
T.check(pred ~= nil and pred.pts[1] ~= nil, "the predictions")
local legs = st.rte.legs
T.equal(legs[1].fix.ident, "ALPHA", "the active leg ALPHA")
local hhmm = eta(pred.pts[1].t)
T.equal(rt:get(ND_ETA):sub(1, 4), hhmm, "on the ground: ALPHA's ETA the predicted one " .. hhmm .. " (before: dashes)")
key("func_key/prog")
T.check(line(5):find("^ALPHA%s+%d+ " .. hhmm .. " "), "PROGRESS's TO row the same: " .. line(5))
local r = route_eta()
local _, m1 = eta(pred.pts[1].t)
local _, m2 = eta(pred.pts[2].t)
local _, md = eta(pred.dest.t)
T.check(r[1] == -1 and r[2] == -1, "DATA: none before the active waypoint (ZZAA, RW16R)")
T.check(r[3] == m1 and r[4] == m2, string.format("ALPHA and BRAVO the predicted %d, %d: %d, %d", m1, m2, r[3] or -9, r[4] or -9))
T.equal(r[6], md, "ZZBB the predictions' destination")

-- in the air at 160 kt 3,000 ft over ZZAA: the ND's ETA PROGRESS's, not
-- the old estimate (distance over 275 kt: early)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 3000)
rt:set("sim/flightmodel2/position/groundspeed", 160 / 1.94384)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 160)
fms.ns.B747_fms_preds_now()
frames(1)
pred = fms.ns.B747_fms_preds()
legs = st.rte.legs
T.equal(legs[1].fix.ident, "ALPHA", "still to ALPHA")
hhmm = eta(pred.pts[1].t)
local nd = rt:get(ND_ETA)
T.equal(nd:sub(1, 4), hhmm, "in the air: the ND's ETA the predicted " .. hhmm)
key("func_key/prog")
T.check(line(5):find(" " .. hhmm .. " "), "PROGRESS's TO the same: " .. line(5))
local dist = tonumber(rt:get(ND_DIST):match("([%d%.]+)"))
local old = eta(dist / 275 * 3600)
T.check(math.abs(pred.pts[1].t - dist / 275 * 3600) > 30, string.format("(the predicted %.0f s, the old estimate %.0f s)", pred.pts[1].t, dist / 275 * 3600))
T.check(old ~= hhmm or nd ~= string.format("%s.0z", old), "not the old estimate " .. old)
r = route_eta()
_, m1 = eta(pred.pts[1].t)
T.equal(r[3], m1, "DATA: ALPHA's the predicted")

-- no predictions in the air (CRZ ALT deleted: none): the old estimate
fms.ns.B747BR_cruiseAlt = 0
fms.ns.B747_fms_preds_now()
frames(1.2)
T.equal(fms.ns.B747_fms_preds(), nil, "no predictions")
dist = tonumber(rt:get(ND_DIST):match("([%d%.]+)"))
T.equal(rt:get(ND_ETA):sub(1, 4), (eta(dist / 275 * 3600)), "without predictions in the air: the old estimate")
T.check(route_eta()[3] > 0, "and DATA's")
T.done()
