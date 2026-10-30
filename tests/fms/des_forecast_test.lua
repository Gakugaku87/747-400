-- Run from the repository root with LuaJIT: luajit tests/fms/des_forecast_test.lua
-- The DESCENT FORECAST page (6-1/6-2 step 8e2; notes/ATA-34-61-FMC.md §52;
-- FCOM p.1393, p.1395-1397) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua): from the DES page's FORECAST> (5R; not from the
-- CLB or CRZ page's 5R), its layout (FCOM p.1396's figure, the 109's),
-- TRANS LVL (FL180 by default, the altitudes' FL above it), TAI/ON ALT,
-- four descent winds in any order (the first entry direction and speed,
-- later ones either), DELETE, the 570's DES>.
local T = dofile("tests/lib/check.lua")("des_forecast")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 135)
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
local function enter(text, lsk)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function delete(lsk) clear() rt:command("laminar/B747/fms1/key/del") frames(0.1) key("ls_key/" .. lsk) end
local function lr(l, r) return l .. string.rep(" ", 24 - #l - #r) .. r end
local function vnav(page)
    key("func_key/des")
    for _ = 2, page do key("func_key/next_pg") end
end

-- the CLB and CRZ pages' 5R: nothing
vnav(1)
key("ls_key/R5")
T.check(line(1):find("CLB"), "CLB 5R: still CLB: " .. line(1))
vnav(2)
key("ls_key/R5")
T.check(line(1):find("CRZ"), "CRZ 5R: still CRZ: " .. line(1))
T.equal(pad(), "KEY/FUNCTION INOP", "KEY/FUNCTION INOP")
clear()
-- the DES page's FORECAST> (FCOM p.1393)
vnav(3)
T.check(line(1):find("DES") and line(11):find("FORECAST>$"), "DES: FORECAST> at 5R: " .. line(11))
key("ls_key/R5")
T.equal(line(1), "    DESCENT FORECAST    ", "DESCENT FORECAST")
T.equal(small(2), " TRANS LVL    TAI/ON ALT", "1's titles")
T.equal(line(3), lr("FL180", "-----"), "TRANS LVL FL180 (the default), TAI/ON ALT dashed")
T.equal(small(4), " ALT        WIND DIR/SPD", "2's titles")
for row = 1, 4 do
    T.equal(line(3 + row * 2), "-----         ---`/---  ", "line " .. (row + 1) .. ": dashed")
    T.equal(small(3 + row * 2), string.rep(" ", 22) .. "KT", "and its KT small")
end
T.equal(line(12), string.rep("-", 24), "the line above 6")
T.equal(line(13), lr("<OFFPATH DES", "DES DIR>"), "the 109's 6th line (FCOM p.1396)")

-- winds in any order (FCOM p.1396's figure: FL290, FL210, 5000)
enter("FL290", "L2")
enter("090/105", "R2")
enter("FL210", "L3")
enter("078/69", "R3")
enter("5000", "L4")
enter("130/29", "R4")
T.equal(line(5), "FL290         090`/105  ", "FL290 090/105")
T.equal(line(7), "FL210         078`/ 69  ", "FL210 078/69")
T.equal(line(9), "5000          130`/ 29  ", "5000 130/29")
-- later entries either part; the first both, on a line with an altitude
enter("/80", "R4")
T.equal(line(9), "5000          130`/ 80  ", "/80: the speed only")
enter("140/", "R4")
T.equal(line(9), "5000          140`/ 80  ", "140/: the direction only")
enter("100/40", "R5")
T.equal(pad(), "INVALID ENTRY", "a wind without an altitude: INVALID ENTRY")
clear()
enter("FL350", "L5")
enter("100/", "R5")
T.equal(pad(), "INVALID ENTRY", "the first entry with the direction only: INVALID ENTRY")
clear()
enter("100/251", "R5")
T.equal(pad(), "INVALID ENTRY", "251 kt: INVALID ENTRY (FMSPG p.179: 0 to 250)")
clear()
enter("90/40", "R5")
T.equal(pad(), "INVALID ENTRY", "a two-digit direction: INVALID ENTRY (three digits: FMSPG p.179)")
clear()
enter("100/40", "R5")
local fc = fms.ns.B747_fms_des_forecast()
T.check(fc.slots[4].ft == 35000 and fc.slots[4].dir == 100 and fc.slots[4].kt == 40, "the fourth: FL350 100/40")
enter("FL210", "L5")
T.equal(pad(), "INVALID ENTRY", "FL210 on another line too: INVALID ENTRY (FMSPG p.179)")
clear()
-- TRANS LVL: the altitudes' FL above it; no DELETE (FMSPG p.179)
T.equal(fms.ns.B747_fms_trans_lvl(), 18000, "no destination: the transition level FL180")
enter("4000", "L1")
T.equal(line(3):sub(1, 5), "FL040", "TRANS LVL 4000: FL040")
T.equal(line(9):sub(1, 5), "FL050", "5000 above it: FL050")
delete("L1")
T.equal(pad(), "INVALID DELETE", "DELETE: INVALID DELETE")
clear()
enter("FL180", "L1")
T.equal(line(3):sub(1, 5), "FL180", "FL180 again")
T.equal(line(9):sub(1, 5), "5000 ", "5000 again")
T.equal(fms.ns.B747_fms_trans_lvl(), 18000, "the transition level 18,000 ft")
-- TAI/ON ALT
enter("FL150", "R1")
T.equal(line(3), lr("FL180", "15000"), "TAI/ON ALT FL150: 15000 below TRANS LVL")
T.equal(fc.tai, 15000, "its altitude")
delete("R1")
T.equal(line(3), lr("FL180", "-----"), "DELETE: dashed")
-- DELETE a line: its altitude and wind
delete("L2")
T.equal(line(5), "-----         ---`/---  ", "line 2 deleted")
T.check(fc.slots[1].ft == nil and fc.slots[1].dir == nil, "its altitude and wind gone")
delete("R3")
T.equal(line(7), "FL210         ---`/---  ", "a wind deleted")

-- the 570 (the GE airplane): DES> at 6R to the DES page
rt:set("laminar/B747/engines/type", 1)
frames(0.3)
T.equal(line(13), lr("", "DES>"), "the 570: DES>")
key("ls_key/R6")
frames(0.6)
T.check(line(1):find("DES"), "DES>: the DES page: " .. line(1))

T.done()
