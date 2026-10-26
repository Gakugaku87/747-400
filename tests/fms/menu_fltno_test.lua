-- Run from the repository root with LuaJIT: luajit tests/fms/menu_fltno_test.lua
-- MENU's <FMC and the flight number (6-1/6-2 step 3c; notes/ATA-34-61-FMC.md
-- §16) in the FMS module as XTLua runs it (tests/lib/xtlua.lua): <FMC shows
-- the FMC's last page on that CDU, IDENT the first time, not a page of the
-- other systems behind MENU (FCOM p.1323); a page that shows X-Plane's CDU
-- comes back with its key; RTE page 1's FLT NO is the FMC's flight number,
-- 1 to 8 letters or digits, no deletion (FMSPG p.79, p.278), on the RTE
-- page and in the PROGRESS pages' titles (FCOM p.1289, p.1371).
local T = dofile("tests/lib/check.lua")("menu_fltno")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
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
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the left CDU: keys fms1, lines fms3, X-Plane's CDU 1; the right: fms2
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
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or ch == "-" and "key/minus"
            or "alphanum_key/" .. ch
        rt:command(CDU[c].keys .. k)
    end
    frames(0.1)
end
local function clear(c) key(c, "key/clear", 1.2) end
local function fltno() return rt:get("laminar/B747/fms/data"):match('"fltno":"([^"]*)"') end
local function onces(suffix)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.phase == "once" and tostring(e.name):find(suffix .. "$") then n = n + 1 end
    end
    return n
end

-- the first <FMC: IDENT
key("L", "func_key/fix")
T.check(line("L", 1):find("MENU"), "MENU: " .. line("L", 1))
key("L", "ls_key/L1")
T.check(line("L", 1):find("IDENT"), "the first <FMC: IDENT (FCOM p.1323): " .. line("L", 1))

-- an FMC page reached on the FMC's pages, MENU, <FMC: that page
key("L", "func_key/index")
T.check(line("L", 1):find("PERF INIT"), "INIT REF on the ground: PERF INIT: " .. line("L", 1))
key("L", "ls_key/R6")
T.check(line("L", 1):find("THRUST LIM"), "THRUST LIM>: " .. line("L", 1))
key("L", "func_key/fix")
T.check(line("L", 1):find("MENU"), "MENU again: " .. line("L", 1))
key("L", "ls_key/L1")
T.check(line("L", 1):find("THRUST LIM"), "<FMC: the FMC's last page, THRUST LIM (before: always IDENT): " .. line("L", 1))

-- another system's page (ACMS) in between: still the FMC's last page
key("L", "func_key/fix")
key("L", "ls_key/L5")
T.check(not line("L", 1):find("THRUST LIM") and not line("L", 1):find("MENU"), "ACMS: " .. line("L", 1))
key("L", "func_key/fix")
key("L", "ls_key/L1")
T.check(line("L", 1):find("THRUST LIM"), "<FMC after ACMS: THRUST LIM, not ACMS: " .. line("L", 1))

-- each CDU its own: the right CDU's first <FMC is IDENT
key("R", "func_key/fix")
key("R", "ls_key/L1")
T.check(line("R", 1):find("IDENT"), "the right CDU's first <FMC: IDENT: " .. line("R", 1))
T.check(line("L", 1):find("THRUST LIM"), "the left CDU stays: " .. line("L", 1))

-- a page that shows X-Plane's CDU (RTE): back with its key
key("L", "func_key/fpln")
T.check(line("L", 1):find("RTE 1"), "RTE: " .. line("L", 1))
local before = onces("fpln")
key("L", "func_key/fix")
key("L", "ls_key/L1")
T.check(line("L", 1):find("RTE 1"), "<FMC: the RTE page: " .. line("L", 1))
T.equal(onces("fpln") - before, 1, "X-Plane's CDU back on its RTE page (its key once)")

-- FLT NO on RTE page 1 (X-Plane's CDU on its page 1)
rt:set("sim/cockpit2/radios/indicators/fms_cdu1_text_line0", string.format("%-20s 1/2", "      RTE 1"))
frames(0.3)
T.equal(fltno(), "--------", "no flight number at first")
T.check(line("L", 5):find("%-%-%-%-%-%-%-%-$"), "FLT NO dashes: " .. line("L", 5))
type_in("L", "JL123")
key("L", "ls_key/R2")
T.equal(fltno(), "JL123   ", "FLT NO JL123: the FMC's flight number (before: X-Plane's RTE page only)")
T.check(line("L", 5):find("   JL123$"), "on the RTE page at the right: " .. line("L", 5))
T.equal(pad("L"), "", "the entry taken")
type_in("L", "JL1234567")
key("L", "ls_key/R2")
T.equal(pad("L"), "INVALID ENTRY", "9 characters: INVALID ENTRY (FMSPG p.79: 1 to 8)")
T.equal(fltno(), "JL123   ", "the flight number stays")
clear("L")
clear("L")
type_in("L", "JL-1")
key("L", "ls_key/R2")
T.equal(pad("L"), "INVALID ENTRY", "not a letter or digit: INVALID ENTRY")
clear("L")
clear("L")
key("L", "key/del")
key("L", "ls_key/R2")
T.equal(pad("L"), "INVALID DELETE", "DELETE: INVALID DELETE (FMSPG p.278)")
T.equal(fltno(), "JL123   ", "the flight number stays")
clear("L")
type_in("L", "TBC12345")
key("L", "ls_key/R2")
T.equal(fltno(), "TBC12345", "8 characters")
T.check(line("L", 5):find("TBC12345$"), "all 8 shown (before: the last 7): " .. line("L", 5))

-- the PROGRESS pages' titles (FCOM p.1371: "TBC12345 PROGRESS")
key("L", "func_key/prog")
T.equal(line("L", 1), "TBC12345 PROGRESS       ", "PROGRESS page 1's title: the flight number")

T.done()
