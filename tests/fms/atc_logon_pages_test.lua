-- Run from the repository root with LuaJIT: luajit tests/fms/atc_logon_pages_test.lua
-- ATC LOGON/STATUS (6-1/6-2 step 12e; notes/ATA-34-61-FMC.md §113; FCOM
-- p.755-757, p.1211, p.1431, p.1433, p.1436; FMSPG p.258, p.277-280, p.286)
-- in the FMS module as XTLua runs it (tests/lib/xtlua.lua), AutoATC's
-- datarefs and its answers mocked: the ATC key, the page's lines, SEND and
-- the logon's states, LOGON ACCEPTED's connection (ATC COMM ESTABLISHED),
-- NEXT CTR, SELECT OFF (ATC COMM TERMINATED), the provider's transfer,
-- REJECTED and the timeout (RE-LOGON TO ATC COMM), FLT NO's change, TAIL NO
-- (VERIFY TAIL NUMBER), ADS.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("atc_logon_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["autoatc/acars/in"] = "string", ["autoatc/acars/out"] = "string",
    ["autoatc/cdu"] = "string", ["autoatc/networking/url"] = "string", ["autoatc/networking/data"] = "string",
    ["autoatc/networking/urlstatus"] = "number", ["autoatc/acars/online"] = "number", ["autoatc/hasMobile"] = "number",
    ["autoatc/com_power"] = "number", ["autoatc/com_frequency_override"] = "number",
    ["autoatc/com_frequency_hz_833"] = "number", ["autoatc/com_standby_frequency_hz_833"] = "number",
    ["autoatc/comChannel"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"N1","engines":"CF6-80C2-B1F","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 1)
rt:set("sim/aircraft/view/acf_tailnum", "N747BO")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
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
local function seconds(n) for _ = 1, n do rt:frame(1) end end
frames(4)

local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", D, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do rt:command(K .. (ch == "/" and "key/slash" or "alphanum_key/" .. ch)) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local function data(k) return (rt:get("laminar/B747/fms/data"):match('"' .. k .. '":"([^"]*)"') or ""):gsub("%s+$", "") end
local ONLINE = "autoatc/acars/online"
local msgs = fms.ns.acarsSystem.messages
-- AutoATC's answer: a cpdlc message as its provider stores it
local function answer(title) msgs[#msgs.values + 1] = {type = "cpdlc", title = title, msg = title, read = true, time = "10:00"} end
local logon = fms.ns.B747_fms_atc_logon()

-- the ATC key without ATC COMM: LOGON/STATUS (FMSPG p.277)
key("func_key/crz")
T.check(page("ATC LOGON/STATUS"), "ATC: LOGON/STATUS")
T.equal(line(3), "****                    ", "LOGON TO boxes, no SEND")
T.equal(small(2), " LOGON TO          LOGON", "LOGON TO, LOGON")
T.equal(line(5), "********                ", "FLT NO boxes")
T.equal(line(7), "N747BO                  ", "TAIL NO: the FMC's (X-Plane's tail number)")
T.equal(small(6), " TAIL NO                ", "TAIL NO; no ACT CTR header")
T.equal(line(9), "                        ", "ATC COMM blank without a connection")
T.equal(line(11), "<SELECT OFF   SELECT ON>", "ADS (ARM) <SELECT OFF, ADS EMERG SELECT ON>")
T.equal(small(10), " ADS (ARM)     ADS EMERG", "ADS (ARM)")
T.equal(line(13), "<INDEX           NO COMM", "DATALINK NO COMM (no provider)")
T.equal(small(12), "--------------  DATALINK", "the DATALINK header")

-- LOGON TO, FLT NO; SEND only when READY
enter("KZAK", "L1")
T.equal(line(3), "KZAK                    ", "LOGON TO KZAK; no FLT NO, no SEND")
enter("TBC123", "L2")
T.equal(line(5), "TBC123                  ", "FLT NO TBC123 (RTE's)")
T.equal(line(3):sub(13), "            ", "NO COMM: no SEND")
rt:set(ONLINE, 1)
frames(0.3)
T.equal(line(13), "<INDEX             READY", "DATALINK READY")
T.equal(line(3), "KZAK               SEND>", "SEND> (FCOM p.755)")
key("ls_key/R1")
T.equal(data("atc"), "KZAK", "the provider's address KZAK")
T.check(line(3):find("SENT", 1, true) ~= nil, "SENT after the network (the provider takes it): " .. line(3))
-- LOGON ACCEPTED: the connection
answer("LOGON ACCEPTED")
frames(0.3)
T.equal(line(3), "----                    ", "connected: LOGON TO dashes, LOGON blank (FMSPG p.278-279)")
T.equal(line(7), "N747BO              KZAK", "ACT CTR KZAK")
T.equal(small(6), " TAIL NO         ACT CTR", "ACT CTR header")
T.equal(line(9):sub(1, 11), "<SELECT OFF", "ATC COMM <SELECT OFF")
T.equal(pad(), "ATC COMM ESTABLISHED", "ATC COMM ESTABLISHED (FCOM p.1431)")
clear()
rt:set("laminar/B747/fms/data", rt:get("laminar/B747/fms/data"))
fms.ns.setFMSData("nextCTR", "PANC")
frames(0.3)
T.equal(line(9), "<SELECT OFF         PANC", "NEXT CTR PANC")
key("ls_key/L6")
key("func_key/crz")
T.check(page("ATC INDEX"), "the ATC key with ATC COMM: ATC INDEX (FMSPG p.286)")
key("ls_key/L5")
T.check(page("ATC LOGON/STATUS"), "ATC INDEX's <LOGON/STATUS")

-- SELECT OFF: ATC COMM TERMINATED
key("ls_key/L4")
T.equal(pad(), "ATC COMM TERMINATED", "SELECT OFF: ATC COMM TERMINATED (FCOM p.1431)")
clear()
T.equal(line(3), "****                    ", "boxes again")
T.equal(data("atc"), "****", "the provider's address cleared")
key("func_key/crz")
T.check(page("ATC LOGON/STATUS"), "ATC key: LOGON/STATUS again")

-- the provider's transfer to NEXT CTR: no TERMINATED, the new ESTABLISHED
enter("KZAK", "L1")
key("ls_key/R1")
answer("LOGON ACCEPTED")
frames(0.3)
clear()
fms.ns.setFMSData("nextCTR", "PANC")
-- as the provider does with SERVICE TERMINATED: the address cleared, the
-- message stored, the logon to the next facility
fms.ns.setFMSData("atc", "****")
answer("SERVICE TERMINATED")
fms.ns.fmsFunctions.acarsLogonATC(fms.ns.fmsL, "PANC")
frames(0.3)
T.check(pad() ~= "ATC COMM TERMINATED", "the transfer: no ATC COMM TERMINATED")
answer("LOGON ACCEPTED")
frames(0.3)
T.equal(line(7), "N747BO              PANC", "ACT CTR PANC")
T.equal(pad(), "ATC COMM ESTABLISHED", "control passed: ATC COMM ESTABLISHED")
clear()

-- FLT NO's change ends ATC COMM (FMSPG p.278)
enter("TBC456", "L2")
T.equal(pad(), "ATC COMM TERMINATED", "a new FLT NO: ATC COMM ends")
clear()
T.equal(line(3), "****                    ", "boxes")

-- REJECTED and the timeout: RE-LOGON TO ATC COMM (FMSPG p.258)
enter("KZOA", "L1")
key("ls_key/R1")
answer("LOGON REJECTED")
frames(0.3)
T.equal(line(3), "KZOA            REJECTED", "REJECTED (estimate: AutoATC's word)")
T.equal(pad(), "RE-LOGON TO ATC COMM", "RE-LOGON TO ATC COMM")
clear()
enter("KZOA", "L1")
key("ls_key/R1")
seconds(119)
T.check(line(3):find("SENT", 1, true) ~= nil, "119 s: SENT still")
seconds(2)
T.equal(line(3), "KZOA             RESEND>", "no answer: RESEND> (the time an estimate)")
T.equal(pad(), "RE-LOGON TO ATC COMM", "RE-LOGON TO ATC COMM")
clear()
T.equal(data("atc"), "****", "no logon: the provider's address cleared")

-- TAIL NO (FCOM p.757, p.1436)
enter("JA8071", "L3")
T.equal(line(7):sub(1, 6), "JA8071", "TAIL NO JA8071")
T.equal(pad(), "VERIFY TAIL NUMBER", "not the FMC's: VERIFY TAIL NUMBER")
clear()
enter("N747BO", "L3")
T.equal(pad(), "", "the FMC's: no message")
enter("ABCDEFGH", "L3")
T.equal(pad(), "INVALID ENTRY", "eight characters: INVALID ENTRY")
clear()

-- ADS
key("ls_key/L5")
T.equal(line(11), "<SELECT ARM             ", "ADS SELECT OFF: <SELECT ARM, no ADS EMERG")
T.equal(small(10):sub(1, 10), " ADS (OFF)", "ADS (OFF)")
key("ls_key/L5")
key("ls_key/R5")
T.equal(line(11), "<SELECT OFF  SELECT OFF>", "ADS EMERG on: SELECT OFF>")
T.done()
