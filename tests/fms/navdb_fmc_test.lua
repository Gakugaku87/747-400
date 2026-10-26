-- Run from the repository root with LuaJIT: luajit tests/fms/navdb_fmc_test.lua
-- The FMC's navigation database in the FMS module (6-1/6-2 step 4;
-- notes/ATA-34-61-FMC.md §17) as XTLua runs it (tests/lib/xtlua.lua), on
-- the synthetic files in tests/fms/data/navdb (cycle 2610, airports ZZAA
-- and ZZBB): read a block a frame; IDENT's NAV DATA and ACTIVE (FCOM
-- p.1283-1284); NAV DATA OUT OF DATE when the clock's date is past the
-- cycle (FCOM p.1433); POS INIT's REF AIRPORT (FCOM p.1285) and its
-- blanking at lift-off; the CLB page's TRANS ALT from the origin (FCOM
-- p.1329).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("navdb_fmc")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["laminar/B747/irs/aligning"] = "number", ["laminar/B747/irs/set_pos"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
for _, side in ipairs({"capt", "fo"}) do
    for _, f in ipairs({"on", "day", "month", "year"}) do types["laminar/B747/fltInst/" .. side .. "/clock_" .. f] = "number" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
local function clock(side, on, y, m, d)
    local p = "laminar/B747/fltInst/" .. side .. "/clock_"
    rt:set(p .. "on", on)
    rt:set(p .. "year", y % 100)
    rt:set(p .. "month", m)
    rt:set(p .. "day", d)
end
clock("capt", 1, 2026, 10, 26)
clock("fo", 1, 2026, 10, 26)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end

local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
             R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function pad(c) return (line(c, 14):gsub("%s+$", "")) end
local function key(c, k, held)
    rt:command(CDU[c].keys .. k, held)
    frames(0.3)
end
local function type_in(c, text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(CDU[c].keys .. k)
    end
    frames(0.1)
end
local function clear(c) key(c, "key/clear", 1.2) end
local function fmsdata(k) return rt:get("laminar/B747/fms/data"):match('"' .. k .. '":"([^"]*)"') end

-- a block a frame (32 KB): the small files are read in a few frames
frames(4)

-- IDENT
key("L", "func_key/fix")
key("L", "ls_key/L1")
T.check(line("L", 1):find("IDENT"), "IDENT: " .. line("L", 1))
T.equal(line("L", 5), "AIRAC 2610 OCT01OCT29/26", "NAV DATA: the cycle; ACTIVE: its first day and the next cycle's (FCOM p.1283)")
T.equal(line("L", 7), "+0.0/-0.0               ", "DRAG/FF on line 3 (FCOM p.1283; before line 5)")
T.check(rt:get("laminar/B747/fms3/Line06_S"):find("DRAG/FF"), "its title")
T.check(rt:get("laminar/B747/fms3/Line10_S"):find("CO DATA"), "CO DATA on line 5")
T.equal(pad("L"), "", "26 October: the database in date, no message")

-- NAV DATA OUT OF DATE: the clock's date past the cycle (28 October)
clock("capt", 1, 2026, 10, 29)
frames(0.5)
T.equal(pad("L"), "NAV DATA OUT OF DATE", "29 October: NAV DATA OUT OF DATE (FCOM p.1433)")
T.equal(pad("R"), "NAV DATA OUT OF DATE", "an FMC alert: on every CDU")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 145), 1, ">FMC MESSAGE (an alert)")
key("L", "key/clear")
T.equal(pad("L"), "", "CLR clears it")
T.equal(pad("R"), "", "from every CDU")
frames(1)
T.equal(pad("L"), "", "not again while the date holds")
clock("capt", 1, 2026, 10, 28)
frames(0.5)
T.equal(rt:get("laminar/B747/fms/notification", 55), 0, "28 October: the last day of the cycle, no condition")
clock("capt", 0, 2026, 10, 28)
clock("fo", 1, 2026, 11, 30)
frames(0.5)
T.equal(pad("L"), "NAV DATA OUT OF DATE", "the Captain's clock off: the F/O's date (FCOM p.1285)")
key("L", "key/clear")
clock("capt", 1, 2026, 10, 26)
frames(0.5)
T.equal(rt:get("laminar/B747/fms/notification", 55), 0, "the Captain's clock back: in date")

-- POS INIT's REF AIRPORT from the database (the IRUs aligning)
rt:set("laminar/B747/irs/aligning", 1)
key("L", "ls_key/R6")
T.check(line("L", 1):find("POS INIT"), "POS INIT: " .. line("L", 1))
type_in("L", "ZZAA")
key("L", "ls_key/L2")
T.equal(fmsdata("airportpos"), "ZZAA", "REF AIRPORT ZZAA")
T.check(line("L", 5):find("^ZZAA N35"), "its position on the line (FCOM p.1285): " .. line("L", 5))
T.check(line("L", 5):find("E140"), "east 140: " .. line("L", 5))
type_in("L", "ZZXX")
key("L", "ls_key/L2")
T.equal(pad("L"), "NOT IN DATA BASE", "ZZXX: NOT IN DATA BASE (before: taken)")
clear("L")
clear("L")
type_in("L", "ZZ1")
key("L", "ls_key/L2")
T.equal(pad("L"), "INVALID ENTRY", "not four letters: INVALID ENTRY")
clear("L")
clear("L")
T.equal(fmsdata("airportpos"), "ZZAA", "REF AIRPORT stays")
key("L", "key/del")
key("L", "ls_key/L2")
T.equal(fmsdata("airportpos"), "----", "DELETE: dashes")
T.check(fmsdata("airportgate"):find("^%s*$"), "GATE blank too (before: REF AIRPORT set to the gate's default)")
type_in("L", "ZZBB")
key("L", "ls_key/L2")
T.equal(fmsdata("airportpos"), "ZZBB", "REF AIRPORT ZZBB")
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(0.5)
T.equal(fmsdata("airportpos"), "----", "blank at lift-off (FCOM p.1285)")
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(0.3)

-- TRANS ALT from the origin (RTE's ORIGIN; FCOM p.1329); X-Plane's CDU on
-- its RTE page 1
rt:set("sim/cockpit2/radios/indicators/fms_cdu1_text_line0", string.format("%-20s 1/1", " ACT FPLN"))
key("L", "func_key/fpln")
T.equal(fmsdata("transalt"), "18000", "no origin: 18,000 ft")
type_in("L", "ZZAA")
key("L", "ls_key/L1")
T.equal(fmsdata("fltdep"), "ZZAA", "ORIGIN ZZAA")
T.equal(fmsdata("transalt"), "14000", "TRANS ALT: ZZAA's 14,000 ft from the database (before 18,000 always)")
type_in("L", "ZZBB")
key("L", "ls_key/L1")
T.equal(fmsdata("transalt"), "6000 ", "ZZBB's 6,000 ft")
type_in("L", "KXXX")
key("L", "ls_key/L1")
T.equal(fmsdata("transalt"), "18000", "an origin not in the database: 18,000 ft")
key("L", "key/del")
key("L", "ls_key/L1")
T.equal(fmsdata("transalt"), "18000", "ORIGIN deleted: 18,000 ft")

T.done()
