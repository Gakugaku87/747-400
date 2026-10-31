-- Run from the repository root with LuaJIT: luajit tests/fms/eo_dd_test.lua
-- The engine-out driftdown (6-1/6-2 step 9h4b; notes/ATA-34-61-FMC.md §82;
-- FCOM p.1268, p.1353, p.1372-1373; FCTM p.4.11; FMSPG p.3.4-2, p.3.4-19)
-- in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic CIFP of ZZAA's active route: ENG OUT executed on the CLB page
-- at 33,500 ft over the engine-out MAX (CRZ ALT lowered to it): VNAV's
-- driftdown (laminar/B747/fms/vnav/dd for the A/T, VNAV SPD with THR at
-- 300 fpm down at least, E/O LRC at CRZ ALT), its level off in the
-- predictions: the CRZ page's ACT E/O LRC D/D and AT, PROGRESS's E/O SPD
-- and LEVEL AT; the engine-out fuel; at CRZ ALT the cruise, no LEVEL AT.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("eo_dd")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

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
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
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
local function enter(text, lsk)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local VN = "laminar/B747/fms/vnav/"

-- PERF INIT (ZFW 220 t: 300 t with the 80 t of fuel, cost index 100, CRZ
-- ALT FL350), the route ZZAA to ZZAA (DIRECT ALPHA, DELTA; ZULU1 from 34L
-- by ALPHA; ALPHA1 by DELTA to the ILS 16R), ACTIVATE and EXEC (as
-- pred_glue_test.lua)
key("func_key/index")
enter("220", "L3")
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

-- in the air at 33,500 ft, 300 t, ISA: the climb to FL350
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 33500)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 33.5)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 280)
frames(2)
T.equal(fms.ns.B747_fms_vnav_phase(), "CLB", "33,500 ft under CRZ ALT FL350: the climb")
local gw = fms.ns.B747_fms_gw_kg()
local pw = P.tables(0)
local lrcMax, ddMax = P.eo_max_alt(pw, 1, gw, 0, 0)
T.check(lrcMax < 33000 and ddMax < 33300, string.format("%.0f t: the E/O MAX %.0f ft (driftdown %.0f) under the airplane", gw / 1000, lrcMax, ddMax))

-- ENG OUT> on the CLB page and EXEC: CRZ ALT the E/O MAX (the CLB page's
-- lower one), the driftdown (FCOM p.1266, p.1268)
key("func_key/des")
T.check(line(1):find("CLB"), "the VNAV CLB page: " .. line(1))
key("ls_key/R5")
key("key/execute")
frames(1)
local crz = rt:get("laminar/B747/autopilot/dist/cruise_alt")
T.equal(crz, math.floor(math.min(lrcMax, ddMax) / 100) * 100, "CRZ ALT lowered to the E/O MAX: " .. crz)
T.equal(fms.ns.B747_fms_vnav_phase(), "CRZ", "over CRZ ALT: the cruise phase")
T.equal(rt:get(VN .. "dd"), 1, "laminar/B747/fms/vnav/dd: the driftdown")
T.check(rt:get(VN .. "mode") == 1 and rt:get(VN .. "at") == 4, "VNAV SPD (1), the A/T's THR (4)")
T.equal(rt:get(VN .. "vs"), -300, "300 fpm down at least (FCOM p.1268)")
local m = P.eo_lrc(pw, 1, gw, crz)
T.check(rt:get(VN .. "mach_mode") == 1 and math.abs(rt:get(VN .. "mach") - m) < 1e-6,
    string.format("E/O LRC at CRZ ALT as the Mach: M%.3f (%.3f)", rt:get(VN .. "mach"), m))
T.equal(rt:get("laminar/B747/fms/thrlim/code"), 40, "the reference thrust limit CON")

-- the predictions: the level off at CRZ ALT at once (made again as the
-- driftdown starts: s157's first ones before it had none), the engine-out
-- fuel
local pred = fms.ns.B747_fms_preds()
T.check(pred and pred.lvl_dd and pred.lvl and pred.lvl_t, "the predictions' driftdown level off, a second after EXEC")
local s = fms.ns.B747_fms_pred_input(crz)
T.check(s.eo == 1 and s.crz_des == "dd" and s.steps == nil, "their input: one engine out, the driftdown, no step climbs")
T.check(pred.lvl_t >= (33500 - crz) / 1250 * 60 and pred.lvl_t <= (33500 - crz) / 300 * 60 + 1,
    string.format("%.0f ft down in %.1f min, %.1f NM", 33500 - crz, pred.lvl_t / 60, pred.lvl))
-- the CRZ page: ACT E/O LRC D/D, AT its level off (FCOM p.1268, p.1353)
key("func_key/des")
T.check(line(1):find("ACT E/O LRC D/D"), "ACT E/O LRC D/D: " .. line(1))
T.check(small(4):find("AT$"), "2R's label AT: " .. small(4))
local at = line(5):match("(%d%d%d%dz/ *%d+NM)$")
T.check(at ~= nil, "2R the level off's ETA and distance: " .. line(5))
T.equal(tonumber(at and at:match("/ *(%d+)NM")), math.floor(pred.lvl + 0.5), "its distance the predictions'")
-- PROGRESS: E/O SPD and LEVEL AT (FCOM p.1372-1373; FMSPG p.3.4-19)
key("func_key/prog")
T.check(small(10):find("^ E/O SPD") and small(10):find("LEVEL AT$") and not small(10):find("TO LEVEL"),
    "5L E/O SPD, 5R LEVEL AT: " .. small(10))
local lv = line(11):match("(%d%d%d%dz/%d+NM)$")
T.check(lv ~= nil and tonumber(lv:match("/(%d+)NM")) == math.floor(pred.lvl + 0.5), "LEVEL AT's ETA and distance: " .. line(11))
-- 5L's Mach as .XXX (FCOM p.1371; before, 0.827)
rt:set("sim/cockpit2/autopilot/airspeed_is_mach", 1)
rt:set("sim/cockpit2/autopilot/airspeed_dial_kts_mach", 0.8274)
frames(1.5)
key("func_key/prog")
T.check(line(11):find("^%.827 "), "5L the MCP's Mach .827: " .. line(11))

-- levelled at CRZ ALT: the cruise (E/O LRC CRZ), no LEVEL AT
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", crz + 20)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * crz / 1000)
frames(1)
T.equal(rt:get(VN .. "dd"), 0, "within 50 ft of CRZ ALT: the driftdown over")
T.equal(rt:get(VN .. "mode"), 2, "VNAV PTH")
pred = fms.ns.B747_fms_preds()
T.check(pred and pred.lvl == nil, "the predictions made again: no level off")
key("func_key/prog")
T.check(not small(10):find("LEVEL AT"), "PROGRESS: no LEVEL AT: " .. small(10))
T.check(small(10):find("TO T/D$") or small(10):find("TO E/D$") or small(10):find("^ E/O SPD *$"),
    "5R the next point's (or blank without one): " .. small(10))
key("func_key/des")
T.check(line(1):find("ACT E/O LRC CRZ"), "ACT E/O LRC CRZ: " .. line(1))
T.done()
