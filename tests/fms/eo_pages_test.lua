-- Run from the repository root with LuaJIT: luajit tests/fms/eo_pages_test.lua
-- The engine-out pages (6-1/6-2 step 9h4a; notes/ATA-34-61-FMC.md §81; FCOM
-- p.1341-1342, p.1350-1353; FMSPG p.3.3-4, p.3.3-6, p.3.4-5) in the FMS
-- module as XTLua runs it (tests/lib/xtlua.lua): ENG OUT> on the CLB page
-- a modification (MOD E/O CLB: CRZ ALT at most MAX ALT, E/O SPD, MAX ALT,
-- ALL ENG>), EXEC (CRZ ALT lowered, CON), the E/O CRZ page (E/O LRC D/D
-- above MAX, LRC SPD, OPT and MAX, <E/O SPD, LRC>, a crew's speed), ALL
-- ENG> and EXEC back, 2E/O with two engines out, ERASE.
local T = dofile("tests/lib/check.lua")("eo_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 35)   -- ISA
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function small(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_S", n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function vnav(page)
    key("func_key/des")
    for _ = 2, page do key("func_key/next_pg") end
end
local CRZ_ALT = "laminar/B747/autopilot/dist/cruise_alt"

-- CRZ ALT FL350 on the CRZ page (in the air: FMSPG p.3.4-2)
vnav(2)
enter("350", "L1")
T.equal(rt:get(CRZ_ALT), 35000, "CRZ ALT FL350")
-- the engine-out data at 300 t (PW4056, ISA, PI.13.3): MAX at E/O LRC
-- 32,000 ft, at the driftdown speed 32,626; the minimum drag speed 267 kt
local pw = P.tables(0)
local lrcMax, ddMax = P.eo_max_alt(pw, 1, 300000, 0, 0)
T.near(lrcMax, 32000, 1e-6, "(the database: 32,000 ft at E/O LRC)")
-- ENG OUT> on the CLB page: MOD E/O CLB (FCOM p.1341)
vnav(1)
T.check(line(11):find("ENG OUT>$"), "the CLB page's 5R ENG OUT>: " .. line(11))
key("ls_key/R5")
T.check(line(1):find("MOD E/O CLB"), "MOD E/O CLB: " .. line(1))
T.check(line(3):find("^FL320"), "CRZ ALT at most MAX ALT, FL320: " .. line(3))
T.check(line(5):find("^267"), "E/O SPD the minimum drag speed 267: " .. line(5))
T.check(line(9):find("FL320$"), "MAX ALT FL320 (the lower at the E/O climb and cruise speeds): " .. line(9))
T.check(small(4):find("^ E/O SPD") and small(8):find("MAX ALT$"), "the labels E/O SPD and MAX ALT: " .. small(4) .. " / " .. small(8))
T.check(line(11):find("ALL ENG>$"), "ALL ENG> at 5R: " .. line(11))
T.check(line(13):find("^<ERASE"), "<ERASE at 6L: " .. line(13))
T.equal(rt:get("laminar/B747/fms/thrlim/code") ~= 40 and 1 or 0, 1, "not yet CON")
T.equal(rt:get("laminar/B747/fms/exec_light_pilot"), 1, "the EXEC light on")
-- EXEC: CRZ ALT 32,000 ft, CON (FCOM p.1266, p.1341; FMSPG p.3.3-4)
key("key/execute")
T.equal(rt:get(CRZ_ALT), 32000, "EXEC: CRZ ALT the E/O MAX, 32,000 ft")
frames(0.5)
T.equal(rt:get("laminar/B747/fms/thrlim/code"), 40, "the reference thrust limit CON")
T.check(line(1):find("E/O CLB") and not line(1):find("MOD"), "E/O CLB: " .. line(1))
-- the E/O CRZ page: the airplane at FL350 above MAX: E/O LRC D/D (FCOM
-- p.1352); LRC SPD at FL320; OPT and MAX; <E/O SPD, ALL ENG>
vnav(2)
T.check(line(1):find("E/O LRC D/D"), "E/O LRC D/D: " .. line(1))
local m = P.eo_lrc(pw, 1, 300000, 32000)
T.check(line(5):find("^" .. string.format("%%.%03d", math.floor(m * 1000 + 0.5))), string.format("LRC SPD .%03d: ", math.floor(m * 1000 + 0.5)) .. line(5))
T.check(small(4):find("^ LRC SPD"), "the label LRC SPD: " .. small(4))
local opt = P.eo_opt_alt(pw, 1, 300000, 0, 0)
T.check(line(9):find(string.format("FL%03d  FL320$", opt / 100)), string.format("OPT FL%03d, MAX FL320: ", opt / 100) .. line(9))
T.check(line(11):find("^<E/O SPD") and line(11):find("ALL ENG>$"), "<E/O SPD and ALL ENG>: " .. line(11))
T.check(not line(13):find("LRC>$"), "no LRC> in LRC: " .. line(13))
-- <E/O SPD: the minimum drag speed, title E/O CRZ, LRC> back
key("ls_key/L5")
T.check(line(5):find("^267") and line(1):find("E/O CRZ") and not line(1):find("LRC"), "<E/O SPD: 267, E/O CRZ: " .. line(5) .. " / " .. line(1))
T.check(small(4):find("^ E/O SPD") and line(13):find("LRC>$"), "the label E/O SPD, LRC> at 6R")
-- a crew's speed: 280 kt (SEL SPD), .78 (M.780); 450 not
enter("280", "L2")
T.check(line(5):find("^280") and line(1):find("E/O 280KT CRZ"), "280: E/O 280KT CRZ: " .. line(1))
T.check(small(4):find("^ SEL SPD"), "the label SEL SPD")
enter(".78", "L2")
T.check(line(5):find("^%.780") and line(1):find("E/O M.780 CRZ"), ".78: E/O M.780 CRZ: " .. line(1))
enter("450", "L2")
T.equal(pad(), "INVALID ENTRY", "450 kt: INVALID ENTRY")
clear()
key("ls_key/R6")
T.check(line(1):find("E/O LRC"), "LRC>: E/O LRC again: " .. line(1))
-- ALL ENG>: a modification back to all engines; EXEC
key("ls_key/R5")
T.check(line(1):find("MOD") and not line(1):find("E/O") and line(1):find("CRZ"), "ALL ENG>: MOD ... CRZ, all engines: " .. line(1))
key("key/execute")
T.check(not line(1):find("E/O") and not line(1):find("MOD"), "EXEC: the all-engine CRZ page: " .. line(1))
T.check(line(11):find("ENG OUT>$"), "ENG OUT> again: " .. line(11))
-- two engines out: 2E/O and its data (FCOM p.1350)
rt:set("laminar/B747/engines/inop", 0, 1)
rt:set("laminar/B747/engines/inop", 1, 1)
frames(0.5)
key("ls_key/R5")
T.check(line(1):find("MOD 2E/O"), "two engines out: MOD 2E/O: " .. line(1))
local lrc2 = P.eo_max_alt(pw, 2, 300000, 0, 0)
T.check(line(9):find(string.format("FL%03d$", math.floor(lrc2 / 100))), string.format("MAX the two-out FL%03d: ", math.floor(lrc2 / 100)) .. line(9))
key("ls_key/L6")
T.check(not line(1):find("E/O"), "ERASE: dropped: " .. line(1))
T.done()
