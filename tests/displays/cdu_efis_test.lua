-- Run from the repository root with LuaJIT: luajit tests/displays/cdu_efis_test.lua
-- The CDUs' alternate EFIS control (5-2 step 5c) in the FMS module
-- (B747.68.xt.fms) as XTLua runs it (tests/lib/xtlua.lua): the MENU page's
-- EFIS CP and EICAS CP SELECT only with that control panel failed (FCOM
-- p.1060-1061, CDU-152), the left CDU for the Captain's panel and the right
-- one for the F/O's; the EFIS CONTROL page's range, DH RESET, STD and CTR
-- (FCOM p.1062-1063) and the EFIS OPTIONS page (FCOM p.1065) on that CDU's
-- side. The panel side of STD and DH RESET is tested in
-- display_module_test.lua.
local T = dofile("tests/lib/check.lua")("cdu_efis")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
-- the CDUs' power (no keys without it: 6-1/6-2 step 2)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the CDUs' keys and lines (setDREFs in B747.68.xt.fms.lua)
local CDU = {
    L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
    R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"},
    C = {keys = "laminar/B747/fms3/", lines = "laminar/B747/fms1/"},
}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function key(c, k)
    rt:command(CDU[c].keys .. k)
    frames(1)
end
local function type_in(c, text)
    for ch in text:gmatch(".") do rt:command(CDU[c].keys .. "alphanum_key/" .. ch) end
end
local function ran(name)
    for _, e in ipairs(rt.command_log) do
        if e.name == name and e.phase == "once" then return true end
    end
    return false
end
local EF, ND = "laminar/B747/efis/", "laminar/B747/nd/"

-- the MENU page: no SELECT while the panels work (before, always)
key("L", "func_key/fix")
T.equal(line("L", 1), "          MENU          ", "the left CDU's MENU page")
T.equal(line("L", 3), "<FMC    <ACT>           ", "the EFIS control panel works: no EFIS CP SELECT")
T.check(not line("L", 5):find("SELECT"), "the display select panel works: no EICAS CP SELECT")
key("L", "ls_key/R1")
T.equal(line("L", 1), "          MENU          ", "EFIS CP pushed: the MENU page stays")

-- the Captain's panel fails: the left CDU's SELECT, not the right's or centre's
rt:set(EF .. "fail", 0, 1)
frames(0.5)
T.equal(line("L", 3), "<FMC    <ACT>    SELECT>", "the Captain's panel failed: the left CDU's EFIS CP SELECT")
key("R", "func_key/fix")
T.equal(line("R", 3), "<FMC    <ACT>           ", "not the right CDU's")
key("C", "func_key/fix")
T.equal(line("C", 3), "<FMC    <ACT>           ", "nor the centre's")
key("L", "ls_key/R1")
T.equal(line("L", 1), "      EFIS CONTROL      ", "the left CDU's EFIS CONTROL page")

-- range: that side only, with X-Plane's map range (before, both sides)
rt:set(ND .. "range/capt/sel_dial_pos", 2)
rt:set(ND .. "range/fo/sel_dial_pos", 4)
key("L", "ls_key/L5")
T.equal(rt:get(ND .. "range/capt/sel_dial_pos"), 3, "RANGE INCR: the Captain's range 80 NM")
T.equal(rt:get("sim/cockpit2/EFIS/map_range"), 0,
    "X-Plane's map range left to the display glue (MAP CTR one up, 2026-10-28: display_module_test.lua)")
T.equal(rt:get(ND .. "range/fo/sel_dial_pos"), 4, "the F/O's range stays")
key("L", "ls_key/L6")
key("L", "ls_key/L6")
T.equal(rt:get(ND .. "range/capt/sel_dial_pos"), 1, "RANGE DECR twice: 20 NM")
for _ = 1, 3 do key("L", "ls_key/L6") end
T.equal(rt:get(ND .. "range/capt/sel_dial_pos"), 0, "not below 10 NM")
-- DH RESET and STD through the CDU's own commands (the panel's ignore a
-- failed panel)
key("L", "ls_key/L3")
T.check(ran(EF .. "dh/capt/cdu_reset"), "DH RESET: the Captain's alert reset")
T.check(not ran(EF .. "dh/capt/reset_switch"), "not through the failed panel's MINS RST")
type_in("L", "STD")
key("L", "ls_key/L1")
T.check(ran(EF .. "baro_std/capt/cdu"), "STD entered: the Captain's STD")
-- CTR as the CTR switch: APP, VOR and MAP only
rt:set(ND .. "mode/capt/sel_dial_pos", 2)
rt:set(ND .. "map_center/capt", 0)
key("L", "ls_key/R5")
T.equal(rt:get(ND .. "map_center/capt"), 1, "MAP: CTR centres it")
key("L", "ls_key/R2")
T.equal(rt:get(ND .. "mode/capt/sel_dial_pos"), 3, "PLN selected")
key("L", "ls_key/R5")
T.equal(rt:get(ND .. "map_center/capt"), 1, "PLN: CTR does nothing")

-- the EFIS OPTIONS page (CDU-152): the 109's options on that side
key("L", "ls_key/R6")
T.equal(line("L", 1), "      EFIS OPTIONS      ", "OPTIONS: the EFIS OPTIONS page")
T.check(line("L", 3):find("^<WXR") and line("L", 3):find("WPT>$"), "WXR and WPT")
T.check(line("L", 5):find("^<POS") and line("L", 5):find("STA>$"), "POS and STA")
T.check(line("L", 7):find("^<MTRS") and line("L", 7):find("ARPT>$"), "MTRS and ARPT (before, TERR)")
T.check(line("L", 9):find("^<FPV") and line("L", 9):find("DATA>$"), "FPV and DATA (before, TFC)")
T.check(line("L", 11):find("^<VOR") and line("L", 11):find("ADF>$"), "VOR and ADF")
T.equal(line("L", 13), "                CONTROL>", "CONTROL")
key("L", "ls_key/L2")
key("L", "ls_key/R4")
key("L", "ls_key/L3")
key("L", "ls_key/L4")
T.equal(rt:get(ND .. "data/capt/pos"), 1, "POS: the Captain's POS selected (before, nothing)")
T.equal(rt:get(ND .. "data/capt/data"), 1, "DATA: the Captain's DATA (before, nothing)")
T.equal(rt:get(EF .. "meters/capt/selected"), 1, "MTRS: the Captain's meters")
T.equal(rt:get(EF .. "fpv/capt/selected"), 1, "FPV: the Captain's flight path vector")
T.equal(line("L", 5), "<POS  <SEL>         STA>", "POS shown selected")
T.equal(line("L", 9), "<FPV  <SEL>  <SEL> DATA>", "FPV and DATA shown selected")
T.check(rt:get(ND .. "data/fo/pos") == 0 and rt:get(ND .. "data/fo/data") == 0
    and rt:get(EF .. "meters/fo/selected") == 0 and rt:get(EF .. "fpv/fo/selected") == 0,
    "the F/O's options stay")
key("L", "ls_key/L1")
T.check(ran("sim/instruments/EFIS_wxr"), "WXR: the Captain's weather radar display")
key("L", "ls_key/L5")
T.check(rt:get("sim/cockpit2/EFIS/EFIS_1_selection_pilot") == 2 and rt:get("sim/cockpit2/EFIS/EFIS_2_selection_pilot") == 2,
    "VOR: both of the Captain's pointers VOR")
T.equal(line("L", 11), "<VOR  <SEL>         ADF>", "VOR shown selected")
key("L", "ls_key/R5")
T.check(rt:get("sim/cockpit2/EFIS/EFIS_1_selection_pilot") == 0 and rt:get("sim/cockpit2/EFIS/EFIS_2_selection_pilot") == 0,
    "ADF: both ADF, the VORs deleted")

-- the F/O's panel fails too: the right CDU on the F/O's side
rt:set(EF .. "fail", 1, 1)
key("R", "func_key/fix")
T.equal(line("R", 3), "<FMC    <ACT>    SELECT>", "the F/O's panel failed: the right CDU's EFIS CP SELECT")
key("C", "func_key/fix")
T.equal(line("C", 3), "<FMC    <ACT>           ", "the centre CDU stands in for neither")
key("C", "ls_key/R1")
T.equal(line("C", 1), "          MENU          ", "its EFIS CP does nothing")
key("R", "ls_key/R1")
key("R", "ls_key/L5")
T.equal(rt:get(ND .. "range/fo/sel_dial_pos"), 5, "the right CDU's RANGE INCR: the F/O's range 320 NM")
T.equal(rt:get("sim/cockpit2/EFIS/map_range_copilot"), 0, "X-Plane's copilot map range left to the display glue")
T.equal(rt:get(ND .. "range/capt/sel_dial_pos"), 0, "the Captain's stays")
key("R", "ls_key/L3")
T.check(ran(EF .. "dh/fo/cdu_reset"), "the right CDU's DH RESET: the F/O's")
key("R", "ls_key/R6")
key("R", "ls_key/L2")
T.equal(rt:get(ND .. "data/fo/pos"), 1, "the right CDU's POS: the F/O's")
T.equal(line("R", 5), "<POS  <SEL>         STA>", "shown selected on the right CDU")
key("R", "ls_key/L1")
T.check(ran("sim/instruments/EFIS_copilot_wxr"), "WXR: the F/O's weather radar display (before, the Captain's)")

-- EICAS CP SELECT with the display select panel failed (FCOM p.1061)
rt:set("laminar/B747/dsp/fail", 1)
key("L", "func_key/fix")
T.check(line("L", 5):find("SELECT>$"), "the display select panel failed: EICAS CP SELECT")
key("L", "ls_key/R2")
T.equal(line("L", 1), "       EICAS MODES      ", "the EICAS MODES page")

T.done()
