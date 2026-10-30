-- Run from the repository root with LuaJIT: luajit tests/fms/perf_init_test.lua
-- PERF INIT and the INIT REF key (6-1/6-2 step 3a; FCOM p.1285,
-- p.1307-1312, p.1409) in the FMS module (B747.68.xt.fms) as XTLua runs it
-- (tests/lib/xtlua.lua): the INIT REF key's page by context; GR WT or ZFW
-- entered, the other from FUEL; FUEL CALC or MANUAL; RESERVES; COST INDEX;
-- CRZ ALT kept by the FMC; the weights in the display units.
local T = dofile("tests/lib/check.lua")("perf_init")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local function new_rt(units)
    local rt = xtlua.new{types = types}
    rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
    rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"' .. units .. '","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
    rt:set("laminar/B747/newsimconfig", 1)
    rt:set("sim/operation/prefs/startup_running", 1)
    for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 135)
    -- no takeoff speeds selected (X-Plane's 999; the mock's 0 would be speeds)
    for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
    rt:callout("flight_start")
    for _, cdu in ipairs({"cdu1", "cdu2"}) do
        for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
    end
    for _ = 1, 120 do rt:frame(1 / 30) end
    return rt
end
local rt = new_rt("KGS")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function small(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_S", n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.1) end
local function type_in(text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end

-- the INIT REF key
rt:set("laminar/B747/irs/set_pos", 1)
frames(0.1)
key("func_key/index")
T.check(line(1):find("POS INIT"), "on the ground, the IRS position wanted: POS INIT: " .. line(1))
rt:set("laminar/B747/irs/set_pos", 0)
frames(0.1)
key("func_key/index")
T.check(line(1):find("PERF INIT"), "on the ground, the position in: PERF INIT (before: INIT/REF INDEX): " .. line(1))

-- PERF INIT: boxes, then ZFW and the GR WT from it
T.check(line(3):find("^%*%*%*%.%*"), "GR WT boxes: " .. line(3))
T.check(line(7):find("^%*%*%*%.%*"), "ZFW boxes: " .. line(7))
T.check(line(5):find("^100%.0") and small(5):find("CALC"), "FUEL 100.0 CALC: " .. line(5) .. "|" .. small(5))
type_in("220")
key("ls_key/L3")
T.check(line(7):find("^220%.0"), "ZFW 220.0 entered, large: " .. line(7))
T.check(small(3):find("^320%.0") and not line(3):find("%d"), "GR WT 320.0 from ZFW and FUEL, small: " .. small(3))
-- GR WT entered: the ZFW follows; the GR WT goes down with the fuel
type_in("330.5")
key("ls_key/L1")
T.check(line(3):find("^330%.5"), "GR WT 330.5 entered, large: " .. line(3))
T.check(small(7):find("^230%.5"), "ZFW 230.5 from it, small: " .. small(7))
rt:set("sim/flightmodel/weight/m_fuel_total", 90000)
frames(0.2)
T.check(line(3):find("^320%.5") and line(5):find("^ 90%.0"), "10 t burnt: GR WT 320.5, FUEL 90.0: " .. line(3) .. "|" .. line(5))
type_in("120")
key("ls_key/L1")
T.equal(pad(), "INVALID ENTRY", "GR WT 120 (below the airplane's): INVALID ENTRY")
clear()
key("key/del")
key("ls_key/L3")
T.equal(pad(), "INVALID DELETE", "ZFW DELETE: INVALID DELETE")
clear()
-- FUEL MANUAL
type_in("95")
key("ls_key/L2")
T.check(line(5):find("^ 95%.0") and small(5):find("MANUAL"), "FUEL 95.0 MANUAL: " .. line(5) .. "|" .. small(5))
T.check(line(3):find("^325%.5"), "the GR WT with the manual fuel: " .. line(3))
key("key/del")
key("ls_key/L2")
T.check(line(5):find("^ 90%.0") and small(5):find("CALC"), "FUEL deleted: CALC again: " .. small(5))
key("key/del")
key("ls_key/L2")
T.equal(pad(), "INVALID DELETE", "FUEL CALC: INVALID DELETE")
clear()
-- RESERVES and COST INDEX
type_in("12.5")
key("ls_key/L4")
T.check(line(9):find("^ 12%.5"), "RESERVES 12.5: " .. line(9))
type_in("ABC")
key("ls_key/L4")
T.equal(pad(), "INVALID ENTRY", "RESERVES ABC: INVALID ENTRY")
clear()
type_in("120")
key("ls_key/L5")
T.check(line(11):find("^120 "), "COST INDEX 120: " .. line(11))
type_in("10000")
key("ls_key/L5")
T.equal(pad(), "INVALID ENTRY", "COST INDEX 10000: INVALID ENTRY (0 to 9999)")
clear()
-- CRZ ALT kept by the FMC
type_in("350")
key("ls_key/R1")
T.check(line(3):find("FL350$"), "CRZ ALT 350: FL350: " .. line(3))
T.equal(rt:get("laminar/B747/autopilot/dist/cruise_alt"), 35000, "the FMC's cruise altitude 35,000 ft (before: through X-Plane's FMS)")
type_in("460")
key("ls_key/R1")
T.equal(pad(), "INVALID ENTRY", "CRZ ALT 460: above 45,100 ft: INVALID ENTRY")
clear()
type_in("FL370")
key("ls_key/R1")
T.equal(rt:get("laminar/B747/autopilot/dist/cruise_alt"), 37000, "FL370 on the ground")
T.equal(pad(), "MAX ALT FL367", "above the maximum altitude at 320.5 t: taken with MAX ALT FL367 (6-1/6-2 step 8b2; FMSPG p.131)")
clear()
rt:set("laminar/B747/autopilot/dist/cruise_alt", 39000)
frames(0.2)
T.check(line(3):find("FL390$"), "the cruise altitude changed elsewhere (MCP): FL390 shown: " .. line(3))
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(0.2)
type_in("FL410")
key("ls_key/R1")
T.equal(pad(), "INVALID ENTRY", "in the air PERF INIT's CRZ ALT is not changed (the CLB and CRZ pages)")
clear()
key("func_key/index")
T.check(line(1):find("APPROACH REF"), "in the air the INIT REF key: APPROACH REF: " .. line(1))

-- the weights in pounds
rt = new_rt("LBS")
key("func_key/index")
type_in("500")
key("ls_key/L3")
T.check(line(7):find("^500%.0"), "ZFW 500.0 (thousands of pounds): " .. line(7))
T.check(math.abs((tonumber(rt:get("laminar/B747/fms/data"):match('"zfw":"%s*([%d.]+)')) or 0) - 226.8) < 0.1,
    "kept as 226.8 thousands of kilograms")

T.done()
