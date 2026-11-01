-- Run from the repository root with LuaJIT: luajit tests/fms/atc_uplink_pages_test.lua
-- The ATC uplinks' pages (6-1/6-2 step 12f; notes/ATA-34-61-FMC.md §114;
-- FCOM p.752-765; FMSPG p.286-291) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), AutoATC mocked and logged on: the ATC key to an
-- uplink, its page and status, ACCEPT and VERIFY RESPONSE's SEND (the
-- reply through the provider), REJECT DUE TO, STANDBY, ROGER only, two new
-- ones to the ATC LOG, a long one's pages, ABORTED when ATC COMM ends.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("atc_uplink_pages")
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
frames(4)

local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", D, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do rt:command(K .. (ch == " " and "key/space" or "alphanum_key/" .. ch)) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local msgs = fms.ns.acarsSystem.messages
local nid = 100
local function uplink(text, time)
    nid = nid + 1
    msgs[#msgs.values + 1] = {type = "cpdlc", title = string.sub(text, 1, 19), msg = text, read = false,
        time = time or "14:28", srcID = nid, messageID = nid, REPLIED = false}
    frames(0.3)
    return #msgs.values
end
-- the provider's send queue (read afresh: it may make a new one)
local function sentList() return rawget(fms.ns.acarsSystem.messageSendQueue, "values") end
local function lastSent() local v = sentList() return v[#v] or "" end
local MEMO = "laminar/B747/CAS/memo_status"

-- logged on to KZAK
rt:set("autoatc/acars/online", 1)
frames(0.3)
key("func_key/crz")
enter("TBC123", "L2")
enter("KZAK", "L1")
key("ls_key/R1")
msgs[#msgs.values + 1] = {type = "cpdlc", title = "LOGON ACCEPTED", msg = "KZAK", read = true, time = "14:20", messageID = 99}
frames(0.3)
clear()
T.check(fms.ns.B747_fms_atc_logon().comm, "logged on to KZAK")

-- an instruction: the ATC key to its page (FMSPG p.288)
local a = uplink("CLIMB TO AND MAINTAIN FL350")
T.equal(rt:get(MEMO, 46), 1, "ATC MESSAGE (step 12d1)")
key("func_key/crz")
T.equal(line(1), "    1428Z ATC UPLINK    ", "ATC: XXXXZ ATC UPLINK (only one new)")
T.equal(small(2), "                  STATUS", "STATUS")
T.equal(line(3), "                    OPEN", "reviewed: OPEN")
T.equal(line(4), "CLIMB TO AND MAINTAIN   ", "the text from line 2")
T.equal(line(5), "FL350                   ", "its second line")
T.equal(line(9), "<STANDBY                ", "STANDBY")
T.equal(line(11), "<REJECT          ACCEPT>", "REJECT and ACCEPT (WILCO/UNABLE)")
T.equal(line(13), "                    LOG>", "LOG>")
frames(0.3)
T.equal(rt:get(MEMO, 46), 0, "reviewed: no ATC MESSAGE")
-- ACCEPT: VERIFY RESPONSE WILCO, SEND
key("ls_key/R5")
T.check(page("VERIFY RESPONSE"), "ACCEPT: VERIFY RESPONSE")
T.equal(line(3):sub(1, 5), "WILCO", "WILCO (FCOM p.764)")
T.equal(line(11), "                   SEND>", "RESPONSE SEND>")
T.equal(small(10), "                RESPONSE", "RESPONSE")
T.equal(line(13), "<UPLINK                 ", "<UPLINK")
local n0 = #sentList()
key("ls_key/R5")
T.equal(#sentList(), n0 + 1, "SEND: a downlink through the provider")
T.check(lastSent():find('"msg":"WILCO"', 1, true) and lastSent():find('"RT":' .. (nid), 1, true), "WILCO to the uplink's ID: " .. lastSent())
T.equal(line(11), "                    SENT", "SENT (the network's acknowledgement: estimate)")
T.equal(line(3), "WILCO           ACCEPTED", "STATUS ACCEPTED (FCOM p.764)")
key("ls_key/L6")
T.equal(line(3), "                ACCEPTED", "the uplink ACCEPTED")
T.equal(line(9), "                        ", "no responses after")
key("func_key/crz")
T.check(page("ATC INDEX"), "nothing pending: the ATC key to ATC INDEX")

-- a question: REJECT, REJECT DUE TO, VERIFY, NEGATIVE
local b = uplink("CAN YOU ACCEPT FL370 AT 1500Z")
key("func_key/crz")
T.equal(line(11), "<REJECT          ACCEPT>", "AFFIRM/NEGATIVE: REJECT and ACCEPT")
key("ls_key/L5")
T.check(page("REJECT DUE TO"), "REJECT: REJECT DUE TO (FCOM p.762)")
T.equal(small(3), "<PERFORMANCE    WEATHER>", "PERFORMANCE and WEATHER small")
T.equal(line(5), "<                       ", "free text: a caret")
key("ls_key/L1")
T.equal(line(3), "<PERFORMANCE            ", "PERFORMANCE selected: large")
enter("TURBULENCE", "L2")
T.equal(line(5), "TURBULENCE              ", "free text")
T.equal(line(7), "<                       ", "the next caret")
key("ls_key/R6")
T.check(page("VERIFY RESPONSE"), "VERIFY>")
T.equal(line(3):sub(1, 8), "NEGATIVE", "NEGATIVE")
T.equal(line(4), "DUE TO AIRCRAFT         ", "the reason")
T.equal(line(13), "<REJECT DUE TO          ", "<REJECT DUE TO")
key("ls_key/R5")
T.check(lastSent():find("NEGATIVE DUE TO AIRCRAFT PERFORMANCE TURBULENCE", 1, true), "the reply: " .. lastSent())
key("ls_key/L6")
key("ls_key/L6")
T.equal(line(3), "                REJECTED", "REJECTED")

-- EXPECT: ROGER only; STANDBY keeps it OPEN
local c = uplink("EXPECT FL390 AT 1600Z")
key("func_key/crz")
T.equal(line(11), "                 ACCEPT>", "ROGER only: no REJECT")
key("ls_key/L4")
T.equal(line(3):sub(1, 7), "STANDBY", "STANDBY (FCOM p.765)")
key("ls_key/R5")
key("ls_key/L6")
T.equal(line(3), "                    OPEN", "STANDBY sent: OPEN still (FMSPG p.290)")
key("ls_key/R5")
T.equal(line(3):sub(1, 5), "ROGER", "ACCEPT: ROGER")

-- two new: the ATC key to the ATC LOG
uplink("REPORT REACHING FL390")
uplink("TURBULENCE REPORTED AHEAD")
key("func_key/crz")
T.check(page("ATC LOG"), "two new: ATC LOG (FCOM p.752): " .. line(1) .. "|" .. tostring(fms.ns.B747_fms_atc_route()))

-- a long one: two pages, CONTINUED
local long = uplink("PROCEED DIRECT TO SEA AT DUVAL CLIMB TO AND MAINTAIN FL310 MAINTAIN MACH .80 "
    .. "EXPECT CRUISE CLIMB TO FL350 AT 1605Z REPORT REACHING FL350")
fms.ns.acarsSystem.setCurrentMessage("fmsL", long)
fms.ns.fmsFunctions.setpage(fms.ns.fmsL, "ATCUPLINK")
frames(0.6)
T.check(page("ATC UPLINK"), "the long uplink's page: " .. line(1))
T.equal(small(1):gsub("%s+$", ""), "                    1/2", "page 1/2")
T.equal(small(12), "-------CONTINUED--------", "CONTINUED")
T.equal(line(9):sub(1, 8) ~= "<STANDBY" and "none" or "standby", "none", "no responses on page 1")
key("func_key/next_pg")
T.equal(line(9), "<STANDBY                ", "the last page: STANDBY")

-- (step 12g1) the ATC LOG: newest first, the uplinks and the responses
-- sent, the right key to an uplink, DELETE, ERASE LOG and CONFIRM
key("ls_key/L6")
key("func_key/crz")
T.check(page("ATC LOG"), "the ATC key with several pending: ATC LOG")
T.equal(line(1), "        ATC LOG         ", "the title")
T.equal(line(3):sub(1, 19), "PROCEED DIRECT TO S", "the newest first: the long uplink")
T.equal(line(3):sub(20, 24), "..  >", "cut with two periods, the caret")
T.equal(small(2):sub(1, 6), " 1428Z", "its time")
T.equal(small(2):sub(21, 24), "OPEN", "OPEN (its pages seen above)")
T.equal(small(1):gsub("%s+$", ""), "                    1/2", "eleven entries over two pages")
key("func_key/next_pg")
local found = false
for n = 3, 11, 2 do
    if line(n):find("^WILCO") then found = n end
end
T.check(found, "the WILCO response sent: a downlink entry (FCOM p.765)")
if found then T.equal(small(found - 1):sub(21, 24), "SENT", "SENT") end
key("func_key/prev_pg")
key("ls_key/R1")
T.check(page("ATC UPLINK"), "the right key: the uplink's page")
key("ls_key/R6")
T.check(page("ATC LOG"), "LOG> back")
local first = line(3)
clear()
rt:command(K .. "key/del")
frames(0.1)
key("ls_key/L1")
T.check(line(3) ~= first, "DELETE on the left key: the entry gone")
T.equal(line(13), "<INDEX        ERASE LOG>", "ERASE LOG>")
key("ls_key/R6")
T.equal(line(13), "<INDEX          CONFIRM>", "CONFIRM>")
key("ls_key/L6")
key("ls_key/L4")
T.equal(line(13), "<INDEX        ERASE LOG>", "leaving the page: ERASE LOG again (FMSPG p.358)")
key("ls_key/R6")
key("ls_key/R6")
local pend = 0
for _, e in ipairs(fms.ns.B747_fms_atc_log_entries()) do
    if not e.pending then pend = pend + 1 end
end
T.equal(pend, 0, "CONFIRM: every non-pending entry erased")
T.equal(line(13), "<INDEX                  ", "nothing to erase: blank")
-- ATC COMM ends: the pending ones ABORTED
key("ls_key/L6")
fms.ns.B747_fms_atc_off()
frames(0.3)
local s = fms.ns.B747_fms_atc_uplink(long)
T.equal(fms.ns.B747_atc_uplink_model.status(s), "ABORTED", "ATC COMM ended: the pending ABORTED (FCOM p.753)")
T.done()
