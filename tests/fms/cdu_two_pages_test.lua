-- Run from the repository root with LuaJIT: luajit tests/fms/cdu_two_pages_test.lua
-- Two CDUs on pages of the same name (2026-11-24, stage 4 review CDU-1;
-- notes/ATA-34-61-FMC.md §177.1) in the FMS module (B747.68.xt.fms) as
-- XTLua runs it (tests/lib/xtlua.lua): each CDU's line select keys are its
-- own page's (FMSPG p.49, 2.8.6.1: both pilots on the same or different
-- pages at once). Before, the pages' keys were one table by the page's
-- name, the last drawn CDU's (the right): the left's keys did the right
-- page's functions (an ENG OUT modification from DES's FORECAST>, CLB's
-- SEL SPD into the descent's, POS REF> KEY/FUNCTION INOP).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("cdu_two_pages")
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
rt:set("laminar/B747/engines/type", 0)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:set("laminar/B747/gps/valid", 0, 1)
rt:set("laminar/B747/gps/valid", 1, 1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
for i = 0, 3 do rt:set("laminar/B747/engines/inop", i, 0) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the left CDU: keys fms1, lines fms3; the right: keys and lines fms2
local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
             R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function pad(c) return (line(c, 14):gsub("%s+$", "")) end
local function key(c, k) rt:command(CDU[c].keys .. k) frames(0.3) end
local function type_in(c, text)
    for _ = 1, 30 do rt:command(CDU[c].keys .. "key/clear") end
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(CDU[c].keys .. k)
    end
    frames(0.1)
end
local function enter(c, text, lsk) type_in(c, text) key(c, "ls_key/" .. lsk) end
local function data(k) return (fms.ns.fmsModules.data[k]:gsub("%s+$", "")) end
local function shown(id)
    local o = fms.ns.fmsModules[id]
    return o.currentPage .. " " .. o.pgNo
end

-- PERF INIT and an active route ZZAA-ZZBB (tests/fms/data/navdb)
key("L", "func_key/index")
enter("L", "220", "L3") enter("L", "100", "L5") enter("L", "FL250", "R1") enter("L", "10", "L4")
key("L", "func_key/fpln")
enter("L", "ZZAA", "L1") enter("L", "ZZBB", "R1")
key("L", "ls_key/R6") key("L", "key/execute")
frames(1)
T.check(fms.ns.B747_fmc_route.active, "the route active")
key("R", "func_key/fix") key("R", "ls_key/L1")      -- the right CDU: MENU, <FMC

-- 1. VNAV: the left on CLB (1/3), the right on DES (3/3); the left's 2L SEL SPD
key("R", "func_key/des") key("R", "func_key/next_pg") key("R", "func_key/next_pg")
key("L", "func_key/des")
T.check(shown("fmsL") == "VNAV 1" and shown("fmsR") == "VNAV 3", "left CLB, right DES: " .. shown("fmsL") .. ", " .. shown("fmsR"))
local desBefore = data("desspd")
enter("L", "280", "L2")
T.check(data("clbspd") == "280" and data("clbspdmode") == "S", "left 2L 280 on CLB: the climb's SEL SPD 280 (before: the descent's): "
    .. data("clbspd") .. " " .. data("clbspdmode"))
T.check(data("desspd") == desBefore and data("desspdmode") == "E", "the descent's speed unchanged: " .. data("desspd") .. " " .. data("desspdmode"))
T.check(line("L", 1):find("280KT CLB"), "the left's title: " .. line("L", 1))
T.check(line("R", 1):find("ECON DES"), "the right's title still ECON DES: " .. line("R", 1))
key("L", "ls_key/L5")                                 -- <ECON back

-- 2. VNAV: the left on DES (3/3), the right on CRZ (2/3); the left's 5R
-- FORECAST> (before: the CRZ page's ENG OUT>, an ENG OUT modification)
key("R", "func_key/des") key("R", "func_key/next_pg")
key("L", "func_key/des") key("L", "func_key/next_pg") key("L", "func_key/next_pg")
T.check(shown("fmsL") == "VNAV 3" and shown("fmsR") == "VNAV 2", "left DES, right CRZ: " .. shown("fmsL") .. ", " .. shown("fmsR"))
key("L", "ls_key/R5")
T.equal(shown("fmsL"), "DESFORECAST 1", "left 5R on DES: DESCENT FORECAST")
T.equal(fms.ns.B747_fms_eo().mod, nil, "no ENG OUT modification")
T.check(not line("R", 1):find("MOD") and not line("R", 1):find("E/O"), "the right's CRZ title unchanged: " .. line("R", 1))

-- 3. VNAV: the left on CRZ (2/3), the right on DES (3/3); the left's 6R
-- LRC> and 1L CRZ ALT (before: KEY/FUNCTION INOP, the DES page's)
key("R", "func_key/des") key("R", "func_key/next_pg") key("R", "func_key/next_pg")
key("L", "func_key/des") key("L", "func_key/next_pg")
T.check(shown("fmsL") == "VNAV 2" and shown("fmsR") == "VNAV 3", "left CRZ, right DES: " .. shown("fmsL") .. ", " .. shown("fmsR"))
key("L", "ls_key/R6")
T.equal(data("crzspdmode"), "L", "left 6R on CRZ: LRC")
T.equal(pad("L"), "", "no message")
enter("L", "270", "L1")
T.equal(data("crzalt"), "FL270", "left 1L on CRZ: CRZ ALT FL270")

-- 4. PROGRESS: the left on 1/3, the right on 3/3 (RTA PROGRESS); the left's
-- 6R POS REF> (before: RTA PROGRESS's 6R, KEY/FUNCTION INOP), also within
-- the second its lines are kept for
key("R", "func_key/prog") key("R", "func_key/prev_pg")
key("L", "func_key/prog")
T.check(shown("fmsL") == "PROGRESS 1" and shown("fmsR") == "PROGRESS 3", "left PROGRESS 1/3, right 3/3: " .. shown("fmsL") .. ", " .. shown("fmsR"))
frames(0.5)
key("L", "ls_key/R6")
T.equal(shown("fmsL"), "POSINIT 2", "left 6R on PROGRESS 1/3: POS REF")
T.equal(pad("L"), "", "no KEY/FUNCTION INOP")

-- 5. RTE: the left on page 1, the right on page 2 (VIA/TO): the left's 1R
-- DEST (before: the right page's TO, INVALID ENTRY for an airport there)
key("R", "func_key/fpln") key("R", "func_key/next_pg")
key("L", "func_key/fpln")
T.check(shown("fmsL") == "RTE1 1" and shown("fmsR") == "RTE1 2", "left RTE 1/2, right 2/2: " .. shown("fmsL") .. ", " .. shown("fmsR"))
enter("L", "ZZAA", "R1")
local mod = fms.ns.B747_fmc_route.mod
T.check(mod ~= nil and mod.dest and mod.dest.ident == "ZZAA", "left 1R: a new DEST ZZAA (MOD RTE 1): " .. tostring(mod and mod.dest and mod.dest.ident))
T.check(line("R", 1):find("RTE 1"), "the right's page still RTE 1: " .. line("R", 1))

-- 6. one CDU alone: its keys as before (a page drawn, its key)
key("R", "func_key/prog")
key("L", "func_key/des")
enter("L", "300", "L2")
T.check(data("clbspd") == "300" and data("clbspdmode") == "S", "the left alone on CLB: 2L SEL SPD 300: " .. data("clbspd"))

T.done()
