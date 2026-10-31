-- Run from the repository root with LuaJIT: luajit tests/fms/takeoff_ref_test.lua
-- THRUST LIM on the ground and the TAKEOFF REF lines (6-1/6-2 step 3b-2;
-- FCOM p.1312-1321) in the FMS and flight instruments modules as XTLua
-- runs them (tests/lib/xtlua.lua): SEL (C or F, the OAT in its unit), a
-- new rating deleting the selected speeds; FLAP/ACCEL HT, E/O ACCEL HT,
-- THR REDUCTION, WIND/SLOPE (into V1), CG, POS SHIFT and PRE-FLT.
local T = dofile("tests/lib/check.lua")("takeoff_ref")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
types["laminar/B747/engines/ref_thr_limit_mode"] = "string"
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/weather/temperature_ambient_c", 15)
rt:set("laminar/B747/irs/mode", 0, 2)
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
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.2) end
local function type_in(text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or ch == "-" and "key/minus" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function invalid(what)
    T.equal(pad(), "INVALID ENTRY", what)
    clear()
end

-- PERF INIT's ZFW, then THRUST LIM
key("func_key/index")
type_in("220")
key("ls_key/L3")
key("ls_key/R6")                                       -- THRUST LIM>
T.check(line(1):find("THRUST LIM"), "THRUST LIM: " .. line(1))
type_in("26")
key("ls_key/L1")
T.check(line(3):find("^26`C"), "SEL 26 C, large: " .. line(3))
T.check(small(3):find("15`C"), "the OAT 15 C, small: " .. small(3))
-- (step 9g3) SEL over the OAT: D-TO (FCOM p.1314), the SEL for the EEC
frames(0.2)
T.equal(rt:get("laminar/B747/engines/ref_thr_limit_mode"), "D-TO", "SEL 26 over the OAT 15: D-TO")
T.check(small(2):find("D%-TO EPR$"), "the title: D-TO EPR: " .. small(2))
T.equal(rt:get("laminar/B747/fms/thrlim/sel"), 26, "the SEL for the EEC: 26 C")
type_in("75F")
key("ls_key/L1")
T.check(line(3):find("^75`F") and small(3):find("59`F"), "SEL 75 F: the OAT in F (FCOM p.1315): " .. line(3) .. "|" .. small(3))
type_in("100")
key("ls_key/L1")
invalid("SEL 100 C: INVALID ENTRY (0 to 99)")
type_in("250F")
key("ls_key/L1")
invalid("SEL 250 F: INVALID ENTRY (32 to 210)")
key("key/del")
key("ls_key/L1")
T.check(not line(3):find("%d"), "SEL deleted: blank: " .. line(3))
frames(0.2)
T.check(rt:get("laminar/B747/engines/ref_thr_limit_mode") == "TO" and rt:get("laminar/B747/fms/thrlim/sel") == -99,
    "SEL deleted: TO, no SEL for the EEC")
T.check(small(3):find("15`C"), "the OAT back in C")

-- TAKEOFF REF's defaults
key("ls_key/R6")                                       -- TAKEOFF>
T.check(line(1):find("TAKEOFF REF"), "TAKEOFF REF: " .. line(1))
T.check(small(3):find("^  /1000FT"), "ACCEL HT 1000 FT, small (FCOM's figure): " .. small(3))
T.check(small(5):find("^1000FT"), "E/O ACCEL HT 1000 FT, small: " .. small(5))
T.check(small(7):find("^FLAPS 5"), "THR REDUCTION FLAPS 5, small: " .. small(7))
T.check(line(9):find("^%-%-%-/%-%-%-%-"), "WIND/SLOPE dashes: " .. line(9))
T.check(line(11):find("RW%*%*%* %-%-00M"), "POS SHIFT dashes: " .. line(11))
T.check(small(12):find("PRE%-FLT$") and line(13):find("ROUTE>$"), "PRE-FLT: ROUTE (no route): " .. line(13))
-- the entries
type_in("10/1500")
key("ls_key/L1")
T.check(line(3):find("^10/1500FT"), "FLAP 10 and ACCEL HT 1500 FT, large: " .. line(3))
T.equal(rt:get("laminar/B747/airspeed/flapsRef"), 10, "flaps 10")
type_in("/300")
key("ls_key/L1")
invalid("ACCEL HT 300: INVALID ENTRY (400 to 9999)")
type_in("15")
key("ls_key/L1")
invalid("FLAP 15: INVALID ENTRY (10 or 20)")
type_in("1200")
key("ls_key/L2")
T.check(line(5):find("^1200FT"), "E/O ACCEL HT 1200 FT, large: " .. line(5))
type_in("1500")
key("ls_key/L3")
T.check(line(7):find("^1500FT   CLB"), "THR REDUCTION 1500 FT: " .. line(7))
type_in("5")
key("ls_key/L3")
T.check(line(7):find("^FLAPS 5  CLB"), "THR REDUCTION FLAPS 5, large: " .. line(7))
local v1calm = rt:get("laminar/B747/airspeed/V1_ref")
type_in("H40/U1.0")
key("ls_key/L4")
T.check(line(9):find("^H40/U1%.0"), "WIND/SLOPE H40/U1.0: " .. line(9))
T.check(rt:get("laminar/B747/airspeed/V1_ref") > v1calm, "a headwind raises the computed V1: " .. v1calm .. " to " .. rt:get("laminar/B747/airspeed/V1_ref"))
type_in("T05")
key("ls_key/L4")
T.check(line(9):find("^T05/U1%.0"), "the wind alone: T05: " .. line(9))
type_in("/D0.5")
key("ls_key/L4")
T.check(line(9):find("^T05/D0%.5"), "the slope alone with its slash: D0.5: " .. line(9))
type_in("/3.0")
key("ls_key/L4")
invalid("SLOPE 3.0: INVALID ENTRY (0.0 to 2.0)")
-- the wind deletes the selected speeds
key("ls_key/R1")
key("ls_key/R2")
key("ls_key/R3")
T.check(rt:get("laminar/B747/airspeed/V1") < 999, "the speeds selected")
type_in("H10")
key("ls_key/L4")
T.equal(pad(), "TAKEOFF SPEEDS DELETED", "a new wind deletes them (the performance data changed)")
clear()
-- CG and POS SHIFT
type_in("25")
key("ls_key/R4")
T.check(line(9):find("25%%$"), "CG 25 %, large: " .. line(9))
type_in("45")
key("ls_key/R4")
invalid("CG 45: INVALID ENTRY (0 to 40)")
key("key/del")
key("ls_key/R4")
T.check(small(9):find("%-%-%%"), "CG deleted: dashes: " .. small(9))
type_in("3")
key("ls_key/R5")
T.check(line(11):find("%+0300M"), "POS SHIFT 3: +0300M: " .. line(11))
type_in("-03")
key("ls_key/R5")
T.check(line(11):find("%-0300M"), "POS SHIFT -03: -0300M: " .. line(11))
-- PRE-FLT to the page not complete
key("ls_key/R6")
T.check(line(1):find("RTE"), "PRE-FLT ROUTE>: the RTE page: " .. line(1))
-- a new takeoff rating deletes the selected speeds
key("func_key/index")                                  -- PERF INIT
key("ls_key/L6")
key("ls_key/L5")                                       -- TAKEOFF
key("ls_key/R1")
key("ls_key/R2")
key("ls_key/R3")
key("ls_key/L6")
key("ls_key/L4")                                       -- THRUST LIM
key("ls_key/L3")                                       -- <TO 1
T.equal(pad(), "TAKEOFF SPEEDS DELETED", "TO 1 after the selection: TAKEOFF SPEEDS DELETED (FCOM p.1315)")
T.equal(rt:get("laminar/B747/engine/derate/TO"), 1, "TO 1 selected")
-- (step 9g1) the FMC's thrust limit (laminar/B747/engines/
-- ref_thr_limit_mode): TO 1, CLB 1 armed with its 8 % (FCOM p.1273); in
-- the air with VNAV at flaps 20 TO 1, at THR REDUCTION's flaps 5 the
-- armed CLB 1 (FCOM p.667); the flaps up, then out to 1: GA (p.672); the
-- THR switch: CLB 1 (p.642); on the ground TO 1 again
local LIM = "laminar/B747/engines/ref_thr_limit_mode"
frames(0.2)
-- (step 9g2) the page (FCOM p.1314): the mode and its limit's unit at the
-- title's right, TO 1's 8 % under its label with <SEL>, CLB 1 <ARM>
T.check(small(2):find("^ SEL      OAT +TO 1 EPR$"), "SEL, OAT, TO 1 EPR: " .. small(2))
T.equal(line(7), "<-8 % <SEL> <ARM> CLB 1>", "TO 1's row (FCOM p.1314)")
T.check(small(6):find("^ TO 1") and small(8):find("^ TO 2") and line(9):find("^<%-20 %%"), "the labels TO 1, TO 2, <-20 %: " .. line(9))
T.equal(rt:get(LIM), "TO 1", "the thrust limit: TO 1")
T.equal(rt:get("laminar/B747/engine/derate/CLB"), 1, "CLB 1 armed (TO 1's 8 %)")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/controls/flap_ratio", 4 / 6)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 1000)
rt:set("laminar/B747/autopilot/vnav_state", 2)
frames(0.2)
T.equal(rt:get(LIM), "TO 1", "in the air at flaps 20 with VNAV: TO 1")
rt:set("sim/cockpit2/controls/flap_ratio", 2 / 6)
frames(0.2)
T.equal(rt:get(LIM), "CLB 1", "flaps 5 (THR REDUCTION's default) with VNAV: CLB 1")
-- (step 9g2) the page in the air (FCOM p.1339): the active mode and its
-- limit, <SEL> at CLB 1; <CON, <CRZ select
T.check(small(2):find("CLB 1 EPR$") and line(7) == "<CON        <SEL> CLB 1>", "in the air: CLB 1 EPR, <SEL> at CLB 1: " .. small(2) .. "|" .. line(7))
key("ls_key/L3")
T.check(rt:get(LIM) == "CON" and line(7) == "<CON  <SEL>       CLB 1>", "<CON: CON: " .. line(7))
key("ls_key/L4")
T.check(rt:get(LIM) == "CRZ" and line(9):find("^<CRZ  <SEL>") ~= nil, "<CRZ: CRZ: " .. line(9))
key("ls_key/R3")
T.equal(rt:get(LIM), "CLB 1", "CLB 1> again: CLB 1")
rt:set("sim/cockpit2/controls/flap_ratio", 0)
frames(0.2)
rt:set("sim/cockpit2/controls/flap_ratio", 1 / 6)
frames(0.2)
T.equal(rt:get(LIM), "GA", "the flaps up, then out to 1: GA")
rt:set("laminar/B747/autopilot/thr_pushes", rt:get("laminar/B747/autopilot/thr_pushes") + 1)
frames(0.2)
T.equal(rt:get(LIM), "CLB 1", "the THR switch: CLB 1")
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.2)
T.equal(rt:get(LIM), "TO 1", "on the ground: TO 1 again")

T.done()
