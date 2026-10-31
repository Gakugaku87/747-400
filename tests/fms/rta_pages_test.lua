-- Run from the repository root with LuaJIT: luajit tests/fms/rta_pages_test.lua
-- RTA PROGRESS (6-1/6-2 step 9h5a; notes/ATA-34-61-FMC.md §84; FCOM
-- p.1269, p.1354, p.1375, p.1383-1385; FMSPG p.3.4-52~55) in the FMS module
-- as XTLua runs it (tests/lib/xtlua.lua), on the synthetic CIFP of ZZAA's
-- active route: PROGRESS 3/3 by PREV from 1/3, boxes, a FIX's
-- modification (MOD, boxes for the time, ERASE), the time, EXEC (ACT, the
-- EXEC light), ALT/ETA, MAX SPD, DELETE, PRIOR RTA>, the CRZ page's <RTA
-- PROGRESS; none on the 570 (PROGRESS 1/2); with ENG OUT active blank, its
-- execution ending an RTA.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("rta_pages")
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
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
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
local EXEC_LIGHT = "laminar/B747/fms/exec_light_pilot"

-- PERF INIT (ZFW 220 t, cost index 100, CRZ ALT FL350), the route ZZAA to
-- ZZAA (as pred_glue_test.lua), ACTIVATE and EXEC
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
frames(11)
T.check(fms.ns.B747_fmc_route.active, "the route active")

-- PROGRESS 1/3, PREV: RTA PROGRESS 3/3 (FMSPG p.3.4-52); NEXT from it 1/3
key("func_key/prog")
T.check(small(1):find("1/3"), "PROGRESS 1/3: " .. small(1))
key("func_key/prev_pg")
T.check(small(1):find("3/3") and line(1):find("RTA PROGRESS") and not line(1):find("ACT") and not line(1):find("MOD"),
    "PREV: RTA PROGRESS 3/3, no ACT nor MOD: " .. line(1))
T.check(line(3):find("^%*%*%*%*%*"), "1L FIX boxes with an active route (FCOM p.1384): " .. line(3))
T.check(small(2):find("^ FIX") and not small(2):find("RTA"), "1R's title not yet RTA: " .. small(2))
T.check(small(6):find("^ MAX SPD") and small(7):find("^%.880") and not line(7):find("%.880"), "3L MAX SPD .880 small (the default)")
T.equal(line(12), "------------------------", "the line above 6")
T.check(not line(13):find("ERASE") and not line(13):find("PRIOR"), "no ERASE nor PRIOR RTA>: " .. line(13))
key("func_key/next_pg")
T.check(small(1):find("1/3"), "NEXT from 3/3: 1/3")
key("func_key/prev_pg")

-- a FIX not in the route: INVALID ENTRY; DELTA: MOD, boxes for the time,
-- RTA and ALT/ETA titles, ERASE; no EXEC light until its time
enter("NOFIX", "L1")
T.equal(pad(), "INVALID ENTRY", "a FIX not in the route: INVALID ENTRY")
enter("DELTA", "L1")
T.check(line(1):find("MOD RTA PROGRESS"), "DELTA: MOD RTA PROGRESS: " .. line(1))
T.check(line(3):find("^DELTA") and line(3):find("%*%*%*%*%*%*%*$"), "1L DELTA, 1R boxes: " .. line(3))
T.check(small(2):find("RTA$") and small(4):find("ALT/ETA$"), "the RTA and ALT/ETA titles (FCOM p.1383)")
T.check(line(13):find("^<ERASE"), "6L <ERASE: " .. line(13))
T.equal(rt:get(EXEC_LIGHT), 0, "no EXEC light without the time")
enter("1760", "R1")
T.equal(pad(), "INVALID ENTRY", "1760: INVALID ENTRY")
enter("1740.0B", "R1")
T.check(line(3):find("1740%.0zB$"), "1R 1740.0zB: " .. line(3))
T.equal(rt:get(EXEC_LIGHT), 1, "the EXEC light")
-- ALT/ETA: the predictions' at DELTA
T.check(line(5):find("%d/%d%d%d%d%.%dz$"), "2R ALT/ETA: " .. line(5))
-- EXEC: ACT
key("key/execute")
T.check(line(1):find("ACT RTA PROGRESS"), "EXEC: ACT RTA PROGRESS: " .. line(1))
T.equal(rt:get(EXEC_LIGHT), 0, "the EXEC light off")
local s = fms.ns.B747_fms_rta()
T.check(s.active and s.active.fix == "DELTA" and s.active.time == 1060 and s.active.suffix == "B", "the active RTA: DELTA 17:40 B")
T.check(not line(13):find("ERASE"), "no ERASE: " .. line(13))
-- MAX SPD (FCOM p.1384: .100 to .99 large, DELETE .880 small)
enter(".85", "L3")
T.check(line(7):find("^%.850") and not small(7):find("%.8"), "MAX SPD .850 large: " .. line(7))
enter("1.2", "L3")
T.equal(pad(), "INVALID ENTRY", "1.2: INVALID ENTRY")
delete("L3")
T.check(small(7):find("^%.880") and not line(7):find("%.8"), "DELETE: .880 small again")
-- DELETE on the time: the RTA ended; PRIOR RTA> (FCOM p.1384-1385)
delete("R1")
T.check(s.active == nil and line(1):find("RTA PROGRESS") and not line(1):find("ACT"), "DELETE on the time: ended: " .. line(1))
T.check(line(3):find("^%*%*%*%*%*"), "1L boxes again")
T.check(line(13):find("PRIOR RTA>$"), "6R PRIOR RTA>: " .. line(13))
key("ls_key/R6")
T.check(line(1):find("MOD RTA PROGRESS") and line(3):find("^DELTA") and line(3):find("1740%.0zB$"), "PRIOR RTA>: its FIX and time as a modification: " .. line(3))
T.equal(rt:get(EXEC_LIGHT), 1, "the EXEC light")
key("ls_key/L6")
T.check(s.mod == nil and not line(1):find("MOD"), "ERASE: dropped")
key("ls_key/R6")
key("key/execute")
T.check(s.active and s.active.fix == "DELTA", "PRIOR RTA> and EXEC: active again")
delete("L1")
T.check(s.active == nil and s.mod == nil, "DELETE on the FIX: ended")
delete("L1")
T.equal(pad(), "INVALID DELETE", "DELETE on boxes: INVALID DELETE")
clear()

-- the CRZ page's <RTA PROGRESS (6L): PROGRESS 3/3 (FCOM p.1354)
key("func_key/des")
key("func_key/next_pg")
T.check(line(13):find("^<RTA PROGRESS"), "the CRZ page's 6L <RTA PROGRESS: " .. line(13))
key("ls_key/L6")
T.check(line(1):find("RTA PROGRESS") and small(1):find("3/3"), "6L: RTA PROGRESS 3/3")

-- ENG OUT active: blank, no entries (FCOM p.1269, p.1384); its execution
-- ends an active RTA
enter("DELTA", "L1")
enter("1740", "R1")
key("key/execute")
T.check(s.active ~= nil, "an RTA active")
local eo = fms.ns.B747_fms_eo()
eo.mod, eo.mod_n = "ENG OUT", 1
fms.ns.B747_fms_eo_exec()
frames(0.3)
T.check(s.active == nil and s.prior and s.prior.fix == "DELTA", "ENG OUT executed: the RTA ended")
T.check(not line(3):find("%S"), "with ENG OUT the FIX line blank: " .. line(3))
enter("DELTA", "L1")
T.equal(pad(), "INVALID ENTRY", "a FIX with ENG OUT: INVALID ENTRY")
clear()
eo.active = false
frames(0.3)

-- the 570: PROGRESS 1/2, no RTA PROGRESS, no <RTA PROGRESS (FCOM p.1375)
rt:set("laminar/B747/engines/type", 1)
key("func_key/prog")
T.check(small(1):find("1/2"), "the 570: PROGRESS 1/2: " .. small(1))
key("func_key/prev_pg")
T.check(small(1):find("2/2"), "PREV from 1/2: 2/2: " .. small(1))
key("func_key/next_pg")
T.check(small(1):find("1/2"), "NEXT from 2/2: 1/2")
key("func_key/des")
key("func_key/next_pg")
T.check(not line(13):find("RTA"), "the 570's CRZ page: no <RTA PROGRESS: " .. line(13))
T.done()
