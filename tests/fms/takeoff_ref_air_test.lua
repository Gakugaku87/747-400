-- (2026-11-24, the 2026-11-23 review's CDU-9) TAKEOFF REF in the air: the
-- TRIM blank after takeoff (ATA34_2 p.540) and the CG when airborne (FMSPG
-- p.107 (3.2-47)), both shown again on the ground (their data kept to the
-- flight complete: ATA34_2 p.540). Before, the crew's CG and its trim stayed
-- on the page in the air. The setup as flight_complete_test's.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("takeoff_ref_air")
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
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:set("laminar/B747/gps/valid", 0, 1)
rt:set("laminar/B747/gps/valid", 1, 1)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function seconds(n) for _ = 1, n do rt:frame(1) end end
frames(4)
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
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
local function data(k) return (rt:get("laminar/B747/fms/data"):match('"' .. k .. '":"([^"]*)"') or ""):gsub("%s+$", "") end
local INOP = "laminar/B747/engines/inop"
local function engines(stopped) for i = 0, 3 do rt:set(INOP, i, stopped and 1 or 0) end end
engines(false)
key("func_key/index")
enter("220", "L3")
enter("100", "L5")
enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1.2)
rt:set("laminar/B747/airspeed/flapsRef", 10)
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function takeoff_page() key("func_key/index") key("ls_key/L6") key("ls_key/L5") end
takeoff_page()
enter("22", "R4")
clear()
T.check(line(9):find("22%%") ~= nil and small(9):sub(17, 20):find("%d%.%d") ~= nil, "on the ground: CG 22 large, its trim small: " .. line(9) .. "|" .. small(9))
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(0.5)
T.check(not line(9):find("%%") and not small(9):find("%%"), "in the air: the CG blank (FMSPG p.107): " .. line(9) .. "|" .. small(9))
T.check(not small(9):sub(17, 20):find("%d"), "in the air: the TRIM blank (ATA34_2 p.540): " .. small(9))
T.check(small(8):find("TRIM") ~= nil and small(8):find("CG") ~= nil, "the labels kept: " .. small(8))
-- (review CDU-12) INIT/REF INDEX in the air: <TAKEOFF still, MAINT> gone
-- (FMSPG p.68 (3.2-8)'s in-flight figure; ATA34_2 p.514). Before, both gone
key("func_key/index")
if not line(1):find("INIT/REF INDEX") then key("ls_key/L6") end
T.check(line(1):find("INIT/REF INDEX") ~= nil, "in the air: INIT/REF INDEX: " .. line(1))
T.check(line(11):find("^<TAKEOFF") ~= nil, "in the air: 5L <TAKEOFF (before: blank): " .. line(11))
T.check(not line(13):find("MAINT"), "in the air: no MAINT>: " .. line(13))
key("ls_key/L5")
T.check(line(1):find("TAKEOFF REF") ~= nil, "in the air: <TAKEOFF opens TAKEOFF REF: " .. line(1))
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
frames(0.5)
T.check(line(9):find("22%%") ~= nil and small(9):sub(17, 20):find("%d%.%d") ~= nil, "on the ground again: CG 22 and its trim back (kept to the flight complete): " .. line(9) .. "|" .. small(9))
key("func_key/index")
if not line(1):find("INIT/REF INDEX") then key("ls_key/L6") end
T.check(line(11):find("^<TAKEOFF") ~= nil and line(13):find("MAINT>$") ~= nil, "on the ground: <TAKEOFF and MAINT>: " .. line(11) .. "|" .. line(13))
T.done()
