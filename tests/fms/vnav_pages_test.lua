-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_pages_test.lua
-- The VNAV pages' speeds (6-1/6-2 step 8b; notes/ATA-34-61-FMC.md §45) in
-- the FMS module (B747.68.xt.fms) as XTLua runs it (tests/lib/xtlua.lua):
-- ECON from the cost index by the performance database's cruise model into
-- the CLB, CRZ and DES pages (FCOM p.1327-1328, p.1347-1350, p.1391-1392;
-- FMSPG p.112-113, p.131-134, p.192-193); a crew's entry makes SEL SPD,
-- <ECON (5L) gives ECON back, LRC> (CRZ 6R) the table's long range cruise;
-- the CLB page's MAX ANGLE; the FMC's data the A/P reads.
local T = dofile("tests/lib/check.lua")("vnav_pages")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local pw = P.tables(0)

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local GW, ALT, CI = 300000, 135, 100
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/flightmodel/weight/m_total", GW)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", ALT)
-- ISA: the FMC's deviation (B747_fms_isa_dev) 0
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * ALT / 1000)
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
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.1) end
local function type_in(text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function data(id) return (fms.ns.fmsModules.data[id]:gsub("%s+$", "")) end
local function vnav(page)
    key("func_key/des")
    for _ = 2, page do key("func_key/next_pg") end
end

-- before a cost index: the speeds as they were (the defaults)
vnav(2)
T.check(line(1):find("ECON CRZ"), "CRZ: ECON CRZ: " .. line(1))
T.check(line(5):find("^%.810"), "before a cost index: .810 (the default): " .. line(5))
T.check(not line(11):find("<ECON") and line(13):find("LRC>"), "ECON: no <ECON, LRC>: " .. line(11) .. "|" .. line(13))

-- CRZ ALT FL350 and COST INDEX 100 on PERF INIT: ECON at once
key("func_key/index")
T.check(line(1):find("PERF INIT"), "PERF INIT: " .. line(1))
type_in("350")
key("ls_key/R1")
type_in(tostring(CI))
key("ls_key/L5")
frames(0.2)
local crz = P.econ_cruise(pw, GW, 35000, CI, 0, 0)
local clbCas, clbMach = P.econ_climb(pw, GW, 35000, CI, 0)
local desMach, desCas = P.econ_descent(pw, GW, 35000, CI, 0)
local function m3(m) return string.format("%03d", math.floor(m * 1000 + 0.5)) end
local function k3(v) return string.format("%3d", math.floor(v + 0.5)) end
T.equal(data("crzspd"), m3(crz), "the FMC's cruise speed: the cruise model's ECON at 300 t, FL350, CI 100")
T.check(data("clbspd") == k3(clbCas) and data("clbspdmach") == m3(clbMach), "the climb's CAS and Mach")
T.check(data("desspd") == k3(desCas) and data("desspdmach") == m3(desMach), "the descent's")
T.check(crz > 0.85 and crz < 0.86, string.format("(ECON M%.3f between the maximum range and the long range cruise)", crz))
vnav(2)
T.check(line(5):find("^%." .. m3(crz)), "CRZ: ECON SPD ." .. m3(crz) .. ": " .. line(5))
T.check(small(4):find("^ ECON SPD"), "its label: " .. small(4))

-- CLB: ECON SPD as CAS/Mach (FMSPG p.113: 358/.853); MAX ANGLE the
-- minimum drag speed here
vnav(1)
T.check(line(1):find("ECON CLB") and not line(1):find("ACT"), "CLB: ECON CLB (not active on the ground): " .. line(1))
T.check(line(5):find("^" .. k3(clbCas) .. "/%." .. m3(clbMach)), "ECON SPD " .. k3(clbCas) .. "/." .. m3(clbMach) .. ": " .. line(5))
local _, vmd = P.min_drag(pw, GW, ALT)
T.check(line(9):find(k3(vmd) .. "$"), "MAX ANGLE: the minimum drag speed " .. k3(vmd) .. " kt (before, V2 + 80): " .. line(9))
-- SEL SPD 320/.840: 320KT CLB below .840, <ECON
type_in("320/.840")
key("ls_key/L2")
T.check(line(1):find("320KT CLB"), "320/.840: 320KT CLB: " .. line(1))
T.check(small(4):find("^ SEL SPD") and line(5):find("^320/%.840"), "SEL SPD 320/.840: " .. small(4) .. "|" .. line(5))
T.check(line(11):find("^<ECON"), "<ECON: " .. line(11))
T.check(data("clbspdmode") == "S" and data("clbspd") == "320" and data("clbspdmach") == "840", "the FMC's climb: SEL, 320, .840")
frames(6)
T.equal(data("clbspd"), "320", "ECON's updates leave it")
-- a CAS alone: the cruise's Mach above
type_in("300")
key("ls_key/L2")
T.check(data("clbspd") == "300" and data("clbspdmach") == "", "300 alone: no climb Mach (the cruise's)")
T.check(line(5):find("^300 "), "SEL SPD 300: " .. line(5))
key("ls_key/L5")
T.check(line(1):find("ECON CLB") and not line(11):find("<ECON"), "<ECON: ECON CLB again: " .. line(1))
T.check(data("clbspd") == k3(clbCas) and data("clbspdmach") == m3(clbMach), "ECON's speeds back")
for _, bad in ipairs({"99", "401", ".05", "320/.840/1", "320/330"}) do
    type_in(bad)
    key("ls_key/L2")
    T.equal(pad(), "INVALID ENTRY", bad .. ": INVALID ENTRY")
    clear()
end

-- CRZ: SEL .840 and 300 kt, <ECON, LRC> (the table's long range cruise)
vnav(2)
type_in(".84")
key("ls_key/L2")
T.check(line(1):find("M%.840 CRZ") and line(5):find("^%.840"), ".84: M.840 CRZ, .840: " .. line(1) .. "|" .. line(5))
T.check(small(4):find("^ SEL SPD") and line(11):find("^<ECON") and line(13):find("LRC>"), "SEL SPD, <ECON, LRC>")
type_in("300")
key("ls_key/L2")
T.check(line(1):find("300KT CRZ") and line(5):find("^300"), "300: 300KT CRZ: " .. line(1) .. "|" .. line(5))
T.check(data("crzcas") == "300" and data("crzspd") == "840", "the FMC's cruise CAS 300 (the Mach kept for the climb)")
for _, bad in ipairs({"840", "300/.840"}) do
    type_in(bad)
    key("ls_key/L2")
    T.equal(pad(), "INVALID ENTRY", bad .. ": INVALID ENTRY (a CAS of 100 to 400 or a Mach)")
    clear()
end
key("ls_key/R6")
local lrc = P.lrc(pw, GW, 35000)
T.check(line(1):find("LRC CRZ") and small(4):find("^ LRC SPD"), "LRC>: LRC CRZ, LRC SPD: " .. line(1))
T.check(line(5):find("^%." .. m3(lrc)), "the table's long range cruise ." .. m3(lrc) .. ": " .. line(5))
T.check(data("crzcas") == "" and not line(13):find("LRC>") and line(11):find("^<ECON"), "no CAS, no LRC>, <ECON")
key("ls_key/L5")
T.check(line(1):find("ECON CRZ") and line(5):find("^%." .. m3(crz)), "<ECON: ECON CRZ ." .. m3(crz) .. ": " .. line(5))

-- DES: ECON .Mach/CAS, SEL, <ECON
vnav(3)
T.check(line(1):find("ECON DES"), "DES: ECON DES: " .. line(1))
T.check(line(5):find("^%." .. m3(desMach) .. "/" .. k3(desCas)), "ECON SPD ." .. m3(desMach) .. "/" .. k3(desCas) .. ": " .. line(5))
type_in(".800/300")
key("ls_key/L2")
T.check(line(1):find("300KT DES") and line(5):find("^%.800/300"), ".800/300: 300KT DES (below .800): " .. line(1) .. "|" .. line(5))
T.check(small(4):find("^ SEL SPD") and line(11):find("^<ECON") and line(11):find("FORECAST>"), "SEL SPD, <ECON, FORECAST>: " .. line(11))
type_in("280")
key("ls_key/L2")
T.check(data("desspd") == "280" and data("desspdmach") == "800", "280 alone: the CAS, the Mach kept")
key("ls_key/L5")
T.check(line(1):find("ECON DES") and data("desspd") == k3(desCas), "<ECON: ECON DES again")

-- the cost index changed: ECON at once, faster
key("func_key/index")
type_in("500")
key("ls_key/L5")
frames(0.2)
T.equal(data("crzspd"), m3(P.econ_cruise(pw, GW, 35000, 500, 0, 0)), "CI 500: the faster ECON at once")
T.check(tonumber(data("crzspd")) > tonumber(m3(crz)), "faster than CI 100's")
-- the weight burnt down 40 t: ECON follows within 5 s
rt:set("sim/flightmodel/weight/m_total", GW - 40000)
frames(6)
T.equal(data("crzspd"), m3(P.econ_cruise(pw, GW - 40000, 35000, 500, 0, 0)), "260 t: ECON's for the weight")

-- the first value after an entry exactly, even within the 2 kt left later
-- (s129: 270 t, CI 100 gave 341 kt, the page showed 340)
rt:set("sim/flightmodel/weight/m_total", 270058)
key("func_key/index")
type_in("100")
key("ls_key/L5")
frames(0.2)
local c270 = P.econ_climb(pw, 270058, 35000, 100, 0)
T.equal(data("clbspd"), k3(c270), "270 t, CI 100: the climb's " .. k3(c270) .. " kt at once")
rt:set("sim/flightmodel/weight/m_total", 269000)
frames(6)
T.equal(data("clbspd"), k3(c270), "1 t burnt: a change under 2 kt left")

-- the CRZ page (6-1/6-2 step 8b2; notes §46): STEP TO by ICAO's levels in
-- the direction of the CRZ ALT before takeoff (FL350: west; FCOM p.1349),
-- AT the optimum step point (OPT halfway: FCOM p.1257), EPR for level
-- flight, STEP SIZE, a crew's STEP TO, AVAIL AT, TO T/D, MAX ALT FLXXX
local C = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.crz_model.lua")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 36.089)
rt:set("sim/cockpit2/gauges/indicators/wind_speed_kts", 0)
rt:set("laminar/B747/autopilot/flightPhase", 2)
rt:set("sim/flightmodel/weight/m_total", 270000)
frames(0.2)
vnav(2)
T.equal((line(3):gsub("%s+$", "")), "FL350", "no active route: no STEP TO")
fms.ns.B747_fmc_route.active = true
frames(0.2)
local opt270 = P.opt_alt(pw, 270000)
T.check(line(3):find("FL390$"), "OPT FL" .. math.floor(opt270 / 100) .. ", west: STEP TO FL390: " .. line(3))
local light = pw.MAX_ALT_W[#pw.MAX_ALT_W] * 1000 * pw.wf
local function opt(kg) return P.opt_alt(pw, kg) end
local w = C.step_weight(35000, 39000, opt, light, 270000)
local m = tonumber(data("crzspd")) / 1000
local hrs = (270000 - w) / (4 * P.cruise_ff(pw, (270000 + w) / 2, 35000, m, 0))
local nm = math.floor(hrs * P.tas(m, 35000, 0) + 0.5)
T.check(small(4):find("AT$") and line(5):find(string.format("z/%4dNM$", nm)), string.format("AT: the step point at %.1f t, %d NM: %s", w / 1000, nm, line(5)))
local epr = P.level_setting(pw, 270000, 35000, m, 0)
T.check(small(6):find("^ EPR") and line(7):find("^" .. string.format("%.2f", epr)), "EPR " .. string.format("%.2f", epr) .. " for level flight (PW): " .. small(6) .. "|" .. line(7))
rt:set("laminar/B747/autopilot/flightPhase", 1)
frames(0.1)
vnav(2)
T.check(line(7):find("^ "), "not the active page (CLB): no EPR: " .. line(7))
rt:set("laminar/B747/autopilot/flightPhase", 2)
-- STEP SIZE 2000: CRZ ALT + 2,000 ft over OPT: FL370; DELETE: ICAO
type_in("2000")
key("ls_key/L4")
T.check(line(9):find("^2000 ") and line(3):find("FL370$"), "STEP SIZE 2000: FL370: " .. line(9) .. "|" .. line(3))
key("key/del")
key("ls_key/L4")
T.check(line(9):find("^ICAO ") and line(3):find("FL390$"), "DELETE: ICAO, FL390 again")
type_in("0")
key("ls_key/L4")
T.check((line(3):gsub("%s+$", "")) == "FL350" and not line(5):find("NM"), "0: no step: " .. line(3))
key("key/del")
key("ls_key/L4")
-- a crew's STEP TO: above CRZ ALT; AVAIL AT where MAX reaches it
type_in("330")
key("ls_key/R1")
T.equal(pad(), "INVALID ENTRY", "STEP TO 330: below CRZ ALT, INVALID ENTRY")
clear()
type_in("450")
key("ls_key/R1")
T.check(line(3):find("FL450$"), "STEP TO 450: FL450: " .. line(3))
local wo = C.step_weight(35000, 45000, opt, light, 270000)
local wa = P.max_alt_weight(pw, 45000, 0)
T.check(P.max_alt(pw, wo, 0) < 45000 and small(4):find("AVAIL AT$"), string.format("MAX at the step point (%.0f t) below FL450: AVAIL AT: %s", wo / 1000, small(4)))
local hrs2 = (270000 - math.min(wo, wa)) / (4 * P.cruise_ff(pw, (270000 + math.min(wo, wa)) / 2, 35000, m, 0))
T.check(line(5):find(string.format("z/%4dNM$", math.floor(hrs2 * P.tas(m, 35000, 0) + 0.5))), "at the weight MAX reaches it (" .. math.floor(math.min(wo, wa) / 1000) .. " t): " .. line(5))
key("key/del")
key("ls_key/R1")
T.check(line(3):find("FL390$") and small(4):find(" AT$"), "DELETE: the FMC's FL390 again")
-- the step point passed: NOW
rt:set("sim/flightmodel/weight/m_total", 250000)
frames(0.1)
vnav(2)
T.check(line(3):find("FL390$") and line(5):find("NOW$"), "250 t: OPT above FL370: NOW: " .. line(5))
-- within 200 NM of the T/D: TO T/D, no STEP TO
rt:set("laminar/B747/autopilot/dist/remaining_distance", 1000)
rt:set("laminar/B747/autopilot/dist/top_of_descent", 850)
frames(0.1)
vnav(2)
T.check(small(4):find("TO T/D$") and line(5):find("z/ 150NM$") and (line(3):gsub("%s+$", "")) == "FL350",
    "150 NM to the T/D: TO T/D, 150 NM, no STEP TO: " .. small(4) .. "|" .. line(5) .. "|" .. line(3))
rt:set("laminar/B747/autopilot/dist/remaining_distance", 0)
rt:set("laminar/B747/autopilot/dist/top_of_descent", 0)
-- CRZ ALT above MAX: taken, MAX ALT FLXXX (FMSPG p.131)
rt:set("sim/flightmodel/weight/m_total", 270000)
local max270 = P.max_alt(pw, 270000, 0)
type_in("430")
key("ls_key/L1")
T.check(pad() == string.format("MAX ALT FL%03d", math.floor(max270 / 100)) and line(3):find("^FL430"),
    "CRZ ALT FL430 above MAX FL" .. math.floor(max270 / 100) .. ": taken with MAX ALT: " .. pad() .. "|" .. line(3))
clear()
type_in("350")
key("ls_key/L1")
T.equal(pad(), "", "FL350: no message")
fms.ns.B747_fmc_route.active = false
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", ALT)
rt:set("laminar/B747/autopilot/flightPhase", 0)
frames(0.2)

-- the FMC's data for the A/P (laminar/B747/fms/data)
local json = rt:get("laminar/B747/fms/data")
T.check(json:find('"crzspd":"' .. data("crzspd")) and json:find('"clbspdmode":"E"'), "the A/P's data: the speeds and their modes")

-- every line of the three pages 24 characters
for _, pg in ipairs({1, 2, 3}) do
    vnav(pg)
    local long = {}
    for n = 1, 13 do
        if string.len(line(n)) > 24 then long[#long + 1] = n .. ":" .. line(n) end
    end
    T.check(#long == 0, "page " .. pg .. ": no line longer than 24: " .. table.concat(long, " | "))
end

T.done()
