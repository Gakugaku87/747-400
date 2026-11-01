-- Run from the repository root with LuaJIT: luajit tests/fms/fmc_link_glue_test.lua
-- The two FMCs and the CDUs' connection in the FMS module as XTLua runs it
-- (6-1/6-2 step 11d1; notes/ATA-34-61-FMC.md §98; FCOM p.1275, p.1422,
-- p.1429, p.1434; ATA34_2 p.629; tests/lib/xtlua.lua): the left FMC failed
-- (laminar/B747/fms/fail[0]) on the ground: the left and centre CDUs on the
-- MENU page with TIMEOUT - RESELECT, <FMC without <ACT>, the FMC keys
-- dead, the right CDU on its page with SINGLE FMC OPERATION, >FMC MESSAGE,
-- FMC LEFT after the delay; <FMC connects to the right FMC; the left FMC
-- back: the messages go, the CDUs stay; the Captain's NAV source selector
-- connects the left CDU to the left FMC; in flight the master FMC's loss
-- takes every CDU, MENU without <FMC until the FMC master selector is at
-- the other; a power cycle: the MENU page, connected, no message.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("fmc_link_glue")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
local POWER = "laminar/B747/electrical/display_has_power"
local BUSES = {"xfr_capt", "xfr_fo", "stby_apu"}
local function power(on)
    for i = 6, 8 do rt:set(POWER, i, on and 6 or 0) end
    for _, b in ipairs(BUSES) do rt:set("laminar/B747/electrical/bus/" .. b, on and 1 or 0) end
end
power(true)
for i = 0, 2 do
    rt:set("laminar/B747/irs/nav_valid", i, 1)
    rt:set("laminar/B747/irs/lat", i, 35)
    rt:set("laminar/B747/irs/lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the CDUs' keys and displays (B747.68.xt.fms.lua's setDREFs)
local CDU = {fmsL = {k = "laminar/B747/fms1/", d = "laminar/B747/fms3/"},
    fmsC = {k = "laminar/B747/fms3/", d = "laminar/B747/fms1/"},
    fmsR = {k = "laminar/B747/fms2/", d = "laminar/B747/fms2/"}}
local function line(cdu, n) return rt:get(string.format("%sLine%02d_L", CDU[cdu].d, n)) end
local function pad(cdu) return (line(cdu, 14):gsub("%s+$", "")) end
local function key(cdu, k) rt:command(CDU[cdu].k .. k) frames(0.3) end
local function page(cdu, text) return line(cdu, 1):find(text, 1, true) ~= nil end
local FAIL, OK, LINK = "laminar/B747/fms/fail", "laminar/B747/fms/fmc_ok", "laminar/B747/fms/cdu_link"
local CAS = "laminar/B747/CAS/advisory_status"
local NAV_CAPT = "laminar/B747/flt_inst/nav_src/capt/sel_dial_pos"
local MASTER = "laminar/B747/flt_inst/fmc_master_src/ctr_pnl/sel_dial_pos"
local function links() return string.format("%d,%d,%d", rt:get(LINK, 0), rt:get(LINK, 1), rt:get(LINK, 2)) end
local FMC_ACT, FMC_ONLY, NO_FMC = "<FMC    <ACT>    ", "<FMC             ", string.rep(" ", 17)

-- normal
T.equal(rt:get(OK, 0), 1, "normal: fmc_ok[0] 1")
T.equal(rt:get(OK, 1), 1, "normal: fmc_ok[1] 1")
T.equal(links(), "1,1,2", "normal: cdu_link 1,1,2 (ATA34_2 p.456)")
T.equal(line("fmsL", 3):sub(1, 17), FMC_ACT, "normal: MENU's <FMC <ACT>")
for _, cdu in ipairs({"fmsL", "fmsC", "fmsR"}) do key(cdu, "ls_key/L1") end
T.check(page("fmsL", "IDENT") and page("fmsC", "IDENT") and page("fmsR", "IDENT"), "<FMC: IDENT on the three CDUs")
T.equal(pad("fmsR"), "", "normal: no message")
T.equal(rt:get(CAS, 145), 0, "normal: no >FMC MESSAGE")

-- the left FMC fails on the ground
rt:set(FAIL, 0, 1)
frames(0.2)
T.equal(rt:get(OK, 0), 0, "left FMC failed: fmc_ok[0] 0")
T.equal(links(), "0,0,2", "left FMC failed: the left and centre CDUs not connected")
T.check(page("fmsL", "MENU"), "the left CDU: the MENU page (FCOM p.1275, p.1422)")
T.equal(pad("fmsL"), "TIMEOUT - RESELECT", "the left CDU: TIMEOUT - RESELECT")
T.check(page("fmsC", "MENU"), "the centre CDU: the MENU page")
T.equal(pad("fmsC"), "TIMEOUT - RESELECT", "the centre CDU: TIMEOUT - RESELECT")
T.check(page("fmsR", "IDENT"), "the right CDU: still IDENT")
T.equal(pad("fmsR"), "SINGLE FMC OPERATION", "the right CDU: SINGLE FMC OPERATION (FCOM p.1275, p.1434)")
T.equal(rt:get(CAS, 145), 1, ">FMC MESSAGE (an alert: p.1434)")
T.equal(line("fmsL", 3):sub(1, 17), FMC_ONLY, "MENU's <FMC without <ACT> (the right FMC to connect to)")
T.equal(rt:get(CAS, 144), 0, "no FMC LEFT yet")
key("fmsL", "func_key/index")
T.check(page("fmsL", "MENU"), "INIT REF without an FMC: still MENU")
key("fmsL", "func_key/legs")
T.check(page("fmsL", "MENU"), "LEGS without an FMC: still MENU")
frames(25)
T.equal(rt:get(CAS, 144), 0, "26 s: no FMC LEFT yet")
frames(5)
T.equal(rt:get(CAS, 144), 1, "31 s: FMC LEFT on the EICAS (p.1275, p.1429; LH3460 p.116)")
T.equal(rt:get(CAS, 146), 0, "no FMC RIGHT")

-- CLR and <FMC: the right FMC, its last page
key("fmsL", "key/clear")
T.equal(pad("fmsL"), "", "CLR: TIMEOUT - RESELECT gone; no FMC message unconnected")
key("fmsL", "ls_key/L1")
T.equal(links(), "2,0,2", "<FMC: the left CDU on the right FMC (FCOM p.1275)")
T.check(page("fmsL", "IDENT"), "<FMC: the FMC's last page (IDENT)")
T.equal(pad("fmsL"), "SINGLE FMC OPERATION", "connected: SINGLE FMC OPERATION")
key("fmsC", "key/clear")
key("fmsC", "ls_key/L1")
T.equal(links(), "2,2,2", "<FMC on the centre CDU: the right FMC")
key("fmsL", "func_key/index")
T.check(not page("fmsL", "MENU"), "connected: INIT REF works")

-- the left FMC back: the messages go, the CDUs stay
rt:set(FAIL, 0, 0)
frames(0.2)
T.equal(rt:get(OK, 0), 1, "left FMC back: fmc_ok[0] 1")
T.equal(rt:get(CAS, 144), 0, "left FMC back: no FMC LEFT")
T.equal(pad("fmsR"), "", "left FMC back: SINGLE FMC OPERATION gone")
T.equal(links(), "2,2,2", "left FMC back: the CDUs stay on the right FMC")

-- the Captain's NAV source selector: FMC R, then FMC L (FCOM p.1422)
rt:set(NAV_CAPT, 1)
frames(0.1)
rt:set(NAV_CAPT, 0)
frames(0.1)
T.equal(links(), "1,2,2", "Captain's NAV source selector at FMC L: the left CDU on the left FMC")

-- in flight the master (left) FMC fails: every CDU (FCOM p.1275)
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(0.1)
rt:set(FAIL, 0, 1)
frames(0.2)
T.equal(links(), "0,0,0", "in flight the master FMC fails: no CDU connected")
T.equal(pad("fmsR"), "TIMEOUT - RESELECT", "in flight: TIMEOUT - RESELECT on the right CDU too")
T.check(page("fmsR", "MENU"), "in flight: the right CDU on MENU")
T.equal(line("fmsR", 3):sub(1, 17), NO_FMC, "the FMC master selector at the failed FMC: no <FMC")
key("fmsR", "key/clear")
key("fmsR", "ls_key/L1")
T.equal(links(), "0,0,0", "L1 without the prompt: nothing")
rt:set(MASTER, 1)
frames(0.1)
T.equal(line("fmsR", 3):sub(1, 17), FMC_ONLY, "the FMC master selector at R: <FMC")
key("fmsR", "ls_key/L1")
T.equal(links(), "0,0,2", "<FMC: the right CDU on the right FMC")
T.equal(pad("fmsR"), "SINGLE FMC OPERATION", "SINGLE FMC OPERATION on the CDU with the operative FMC (p.1275)")

-- a power cycle on the ground: the MENU page, connected, no message
key("fmsL", "key/clear")
key("fmsC", "key/clear")
rt:set(FAIL, 0, 0)
rt:set(MASTER, 0)
rt:set("sim/flightmodel/failures/onground_any", 1)
power(false)
frames(0.5)
T.equal(rt:get(OK, 0) + rt:get(OK, 1), 0, "unpowered: fmc_ok 0, 0")
power(true)
frames(0.5)
T.equal(links(), "1,1,2", "power-up: each CDU on its FMC by itself (estimate)")
for _, cdu in ipairs({"fmsL", "fmsC", "fmsR"}) do
    T.check(page(cdu, "MENU"), cdu .. " power-up: the MENU page (FMSPG p.53)")
    T.equal(pad(cdu), "", cdu .. " power-up: no TIMEOUT - RESELECT")
end
T.equal(line("fmsL", 3):sub(1, 17), FMC_ACT, "power-up: <FMC <ACT>")
T.equal(rt:get(CAS, 144) + rt:get(CAS, 146), 0, "power-up: no FMC LEFT, RIGHT")

T.done()
