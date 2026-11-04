-- Run from the repository root with LuaJIT: luajit tests/fms/fuel_pages_test.lua
-- PERF INIT's FUEL and PROGRESS 2 with the FMC's fuel monitoring (6-1/6-2
-- step 11a; notes/ATA-34-61-FMC.md §90; FCOM p.1273-1274, p.1310,
-- p.1377-1382, p.1432) in the FMS module as XTLua runs it (tests/lib/
-- xtlua.lua): CALC, the start and FUEL USED, the wind, TAS and SAT lines,
-- a leak's FUEL DISAGREE - PROG 2 and <USE TOTALIZER (SENSED, CALCULATED
-- and FUEL USED blank, no entry), MANUAL, INSUFFICIENT FUEL.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("fuel_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_fuel_total", 150000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
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
local function pad() return (line(14):gsub("%s+$", "")) end
local TOT = "laminar/B747/fuel/totaliser"
local FF = "sim/cockpit2/engine/indicators/fuel_flow_kg_sec"

-- PERF INIT before the start: the totalizer's, CALC
key("func_key/index")
T.check(line(1):find("PERF INIT", 1, true) ~= nil, "PERF INIT")
T.check(line(5):find("^150%.0") ~= nil and small(5):find("CALC", 1, true) ~= nil, "FUEL 150.0 CALC: " .. line(5) .. "|" .. small(5))

-- the start and 10 t burnt
for i = 0, 3 do rt:set(FF, i, 1) end
frames(0.5)
for i = 0, 3 do rt:set(TOT, i, 2500) end
rt:set(TOT, 4, 10000)
rt:set("sim/flightmodel/weight/m_fuel_total", 140000)
-- the wind from 080 at 57 kt, heading 340: a tailwind 10, from the right 56
rt:set("sim/cockpit2/gauges/indicators/wind_heading_deg_mag", 80)
rt:set("sim/cockpit2/gauges/indicators/wind_speed_kts", 57)
rt:set("sim/flightmodel/position/psi", 340)
rt:set("sim/flightmodel/position/mag_psi", 340)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", -25)
frames(1.5)
key("func_key/prog")
key("func_key/next_pg")
T.check(small(1):find("2/3", 1, true) ~= nil, "PROGRESS 2/3")
T.equal(small(2), " T/WIND   WIND    X/WIND", "T/WIND (FCOM p.1380)")
T.equal(line(3), " 10     080`/ 57  R 56  ", "the tailwind 10, 080`/ 57, R 56")
T.check(small(3):sub(4, 5) == "KT" and small(3):sub(23, 24) == "KT", "KT small")
T.check(line(5):find("^%s*$") ~= nil, "no active route: XTK blank; no descent: VTK blank")
T.check(line(7):find("^%s*%d+ ") ~= nil and small(7):sub(4, 5) == "KT" and line(7):find("%-25` $") ~= nil and small(7):sub(24, 24) == "C",
    "TAS and KT small, SAT -25`C (the FMS's TAS from the Mach): " .. line(7))
T.check(small(7):find("TOT 10%.0") ~= nil, "FUEL USED TOT 10.0 small: " .. small(7))
T.equal(line(9), "  2.5   2.5    2.5   2.5", "each engine 2.5")
T.check(line(13):find("^140%.0") ~= nil and line(13):find("140%.0$") ~= nil, "TOTALIZER 140.0, CALCULATED 140.0: " .. line(13))
T.check(not line(11):find("USE", 1, true), "no <USE without a disagreement")

-- a leak: FUEL DISAGREE - PROG 2, <USE TOTALIZER
rt:set("sim/flightmodel/weight/m_fuel_total", 134000)
frames(1.5)
T.equal(pad(), "FUEL DISAGREE - PROG 2", "6 t apart: FUEL DISAGREE - PROG 2 (FCOM p.1432)")
key("func_key/prog")
key("func_key/next_pg")
T.equal(line(11), "<USE                USE>", "<USE and USE> (FCOM p.1380)")
clear()
key("ls_key/L5")
frames(1.5)
T.check(line(13):find("^134%.0") ~= nil and not line(13):find("140", 1, true), "USE TOTALIZER: CALCULATED blank: " .. line(13))
T.check(line(9):find("^%s*$") ~= nil and not small(7):find("TOT", 1, true), "FUEL USED blank (FCOM p.1381)")
T.check(not line(11):find("USE", 1, true), "the prompts gone")
key("func_key/index")
T.check(line(5):find("^134%.0") ~= nil and small(5):find("SENSED", 1, true) ~= nil, "PERF INIT: 134.0 SENSED")
enter("130", "L2")
T.equal(pad(), "INVALID ENTRY", "no entry when SENSED (FCOM p.1310)")
clear()

-- the shutdown: CALC again; MANUAL
for i = 0, 3 do rt:set(FF, i, 0) end
frames(1.5)
key("func_key/index")
T.check(small(5):find("CALC", 1, true) ~= nil, "shut down: CALC")
enter("120", "L2")
frames(0.5)
T.check(line(5):find("^120%.0") ~= nil and small(5):find("MANUAL", 1, true) ~= nil, "120 entered: MANUAL")
key("func_key/prog")
key("func_key/next_pg")
T.check(line(13):find("^%s+120%.0$") ~= nil, "TOTALIZER blank with a manual entry (FCOM p.1378): " .. line(13))
T.done()
