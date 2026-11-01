-- Run from the repository root with LuaJIT: luajit tests/fms/maint_pages_test.lua
-- The maintenance pages' rest (6-1/6-2 step 12c2; notes/ATA-34-61-FMC.md
-- §110; FMSPG p.264, p.269; ATA34_2 p.676-677, p.682, p.684-685) in the FMS
-- module as XTLua runs it (tests/lib/xtlua.lua): IRS MONITOR's position
-- error rates after a flight (shown about 45 s after the shutdown, cleared
-- in the air), NAV DATA CROSSLOAD's ARM, TRANSMIT and RECEIVE on two CDUs
-- and the transfer's status, the BITE REPORT page.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("maint_pages")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
local IRS = "laminar/B747/irs/"
for i = 0, 2 do
    rt:set(IRS .. "nav_valid", i, 1)
    rt:set(IRS .. "lat", i, 35)
    rt:set(IRS .. "lon", i, 140)
end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function seconds(n) for _ = 1, n do rt:frame(1) end end
frames(4)

-- the left CDU (keys fms1, display fms3) and the right (fms2, fms2)
local CDU = {L = {"laminar/B747/fms1/", "laminar/B747/fms3/"}, R = {"laminar/B747/fms2/", "laminar/B747/fms2/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c][2], n)) end
local function small(c, n) return rt:get(string.format("%sLine%02d_S", CDU[c][2], n)) end
local function key(c, k) rt:command(CDU[c][1] .. k) frames(0.3) end
local function clear(c) for _ = 1, 30 do rt:command(CDU[c][1] .. "key/clear") end frames(0.1) end
local function enter(c, text, lsk)
    clear(c)
    for ch in text:gmatch(".") do rt:command(CDU[c][1] .. "alphanum_key/" .. ch) end
    frames(0.1)
    key(c, "ls_key/" .. lsk)
end
local function page(c, text) return line(c, 1):find(text, 1, true) ~= nil end
-- the MAINTENANCE INDEX: INIT REF (PERF INIT on the ground), <INDEX, MAINT>
local function maint(c)
    key(c, "func_key/index")
    if not page(c, "INIT/REF INDEX") then key(c, "ls_key/L6") end
    key(c, "ls_key/R6")
end
local INOP = "laminar/B747/engines/inop"
for i = 0, 3 do rt:set(INOP, i, 0) end

-- IRS MONITOR before a flight: the labels, no rates
maint("L")
key("L", "ls_key/L3")
T.equal(line("L", 1), "      IRS MONITOR       ", "<IRS MONITOR: IRS MONITOR (FMSPG p.269)")
T.equal(small("L", 4), " IRS L                  ", "IRS L")
T.equal(small("L", 6), " IRS C                  ", "IRS C")
T.equal(small("L", 8), " IRS R                  ", "IRS R")
T.equal(line("L", 5), "                        ", "no rate before a flight")
T.equal(line("L", 12), "------------------------", "the line above <INDEX")
T.equal(line("L", 13), "<INDEX                  ", "<INDEX")

-- a flight of an hour: at the liftoff the IRUs at the airplane's position;
-- at the landing IRU L 2 NM north of it, C 1 NM east, R not navigating
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(1)
for _ = 1, 360 do rt:frame(10) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set(IRS .. "lat", 0, 35 + 2 / 60)
rt:set(IRS .. "lon", 1, 140 + 1 / 60 / math.cos(math.rad(35)))
rt:set(IRS .. "nav_valid", 2, 0)
seconds(5)
for i = 0, 3 do rt:set(INOP, i, 1) end
seconds(31)
T.check(fms.ns.B747_fms_irs_monitor() == nil, "the flight complete (30 s): not yet shown")
seconds(15)
T.equal(line("L", 5), "2.0                     ", "IRS L 2.0 (2 NM in an hour)")
T.equal(small("L", 5), "   NM/HR                ", "NM/HR small after it")
T.equal(line("L", 7), "1.0                     ", "IRS C 1.0")
T.equal(line("L", 9), "                        ", "IRS R not navigating: blank (estimate)")
-- cleared in the air
rt:set("sim/flightmodel/failures/onground_any", 0)
frames(1)
T.equal(line("L", 5), "                        ", "airborne: cleared (FMSPG p.269)")
rt:set("sim/flightmodel/failures/onground_any", 1)
frames(1)
for i = 0, 2 do
    rt:set(IRS .. "nav_valid", i, 1)
    rt:set(IRS .. "lat", i, 35)
    rt:set(IRS .. "lon", i, 140)
end

-- BITE REPORT: the CDU's FMC; no data loader, no caret
key("L", "ls_key/L6")
key("L", "ls_key/R1")
T.equal(line("L", 1), "   FMC L BITE REPORT    ", "the left CDU: FMC L BITE REPORT (ATA34_2 p.685)")
T.equal(line("L", 3), " DATA LOADER            ", "DATA LOADER without the caret (no data loader)")
key("L", "ls_key/L1")
T.equal(line("L", 3), " DATA LOADER            ", "1L does nothing")
maint("R")
key("R", "ls_key/R1")
T.equal(line("R", 1), "   FMC R BITE REPORT    ", "the right CDU: FMC R BITE REPORT")

-- NAV DATA CROSSLOAD: ARM on both CDUs, TRANSMIT on the left, RECEIVE on
-- the right (ATA34_2 p.676)
key("L", "ls_key/L6")
key("L", "ls_key/L1")
T.equal(line("L", 1), "   NAV DATA CROSSLOAD   ", "<CROSS LOAD: NAV DATA CROSSLOAD")
T.check(line("L", 5):find("^AIRAC ") ~= nil, "2L the navigation database's identifier: " .. line("L", 5))
T.equal(line("L", 7), "<TRANSMIT       RECEIVE>", "<TRANSMIT and RECEIVE>")
T.equal(line("L", 13), "<INDEX               ---", "6R ---")
key("L", "ls_key/L3")
T.equal(line("L", 9), "                        ", "TRANSMIT without ARM: nothing")
enter("L", "ARM", "R6")
T.equal(line("L", 13), "<INDEX               ARM", "ARM")
key("L", "ls_key/L3")
key("R", "ls_key/L6")
key("R", "ls_key/L1")
key("R", "ls_key/R3")
T.equal(line("R", 9), "                        ", "RECEIVE without ARM: nothing")
enter("R", "ARM", "R6")
key("R", "ls_key/R3")
T.equal(line("R", 9), "  TRANSFER IN PROGRESS  ", "RECEIVE on the other: TRANSFER IN PROGRESS")
T.equal(line("L", 9), "  TRANSFER IN PROGRESS  ", "on both CDUs")
seconds(31)
T.equal(line("L", 9), "   TRANSFER COMPLETE    ", "then TRANSFER COMPLETE (the time: estimate)")
-- leaving the page cancels the ARM
key("L", "ls_key/L6")
key("L", "ls_key/L1")
T.equal(line("L", 13), "<INDEX               ---", "back on the page: --- again")
-- an FMC stopping during a transfer: TRANSFER ABORTED
enter("L", "ARM", "R6")
key("L", "ls_key/L3")
key("R", "ls_key/R3")
T.equal(line("R", 9), "  TRANSFER IN PROGRESS  ", "a second transfer")
rt:set("laminar/B747/fms/fail", 1, 1)
seconds(2)
T.equal(line("L", 9), "    TRANSFER ABORTED    ", "the right FMC failed: TRANSFER ABORTED")
T.done()
