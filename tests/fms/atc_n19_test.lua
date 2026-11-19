-- Run from the repository root with LuaJIT: luajit tests/fms/atc_n19_test.lua
-- The ATC uplinks after the 2026-11-19 sources (GAP_ANALYSIS.md §7
-- N19-ATC-01, 02, 04, 05; notes/ATA-34-61-FMC.md §175):
--  - the response a message allows, its elements' highest (CPDLC p.177:
--    WU over AN over R over none), each element by its words after a
--    condition ("AT 1605Z EXPECT ..." an EXPECT: ROGER; "WHEN READY CLIMB"
--    an instruction), ATC's messages needing none (REQUEST FORWARDED,
--    ERROR...: p.179-198); the ground's attribute (AutoATC's and Hoppie's
--    RR) before the words;
--  - the response's network acknowledgement as the provider sends it
--    (SENDING, then SENT and ACCEPTED, the CDU back on the uplink: FMSPG
--    p.297), none in time: RESEND>, NO ACK in the log and ATC MSG NOT
--    ACKNOWLEDGED (FCOM p.753, p.765, p.1431), RESEND;
--  - ATC INDEX's 6L blank as the other ATC pages' PRINT (no printer).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("atc_n19")
local U = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_uplink_model.lua")

-- (N19-ATC-01) the elements and their attributes
local function els(text) return table.concat(U.elements(text), "|") end
T.equal(els("EXPECT FL350 MAINTAIN FL330"), "EXPECT FL350|MAINTAIN FL330", "two elements in a run of words")
T.equal(els("AT 1605Z EXPECT CRUISE CLIMB TO FL350"), "AT 1605Z EXPECT CRUISE CLIMB TO FL350",
    "a condition and its EXPECT: one element (CLIMB inside it)")
T.equal(els("PROCEED DIRECT TO SEA/AT DUVAL CLIMB TO AND MAINTAIN FL310/MAINTAIN .80"),
    "PROCEED DIRECT TO SEA|AT DUVAL CLIMB TO AND MAINTAIN FL310|MAINTAIN .80", "the elements by their / (FCOM p.758)")
T.equal(els("CLIMB TO FL350 REPORT REACHING FL350"), "CLIMB TO FL350|REPORT REACHING FL350", "an instruction and a report")
T.equal(U.response("AT 1605Z EXPECT CRUISE CLIMB TO FL350"), "R", "AT ... EXPECT: ROGER (before WILCO/UNABLE)")
T.equal(U.response("WHEN READY CLIMB TO FL350"), "WU", "WHEN READY CLIMB: WILCO/UNABLE (before ROGER)")
T.equal(U.response("EXPECT FL350 MAINTAIN FL330"), "WU", "EXPECT and MAINTAIN: the highest, WU (before R)")
T.equal(U.response("REQUEST FORWARDED"), "NE", "REQUEST FORWARDED: none (before ROGER)")
T.equal(U.response("REQUEST AGAIN WITH NEXT UNIT"), "NE", "REQUEST AGAIN WITH NEXT UNIT: none")
T.equal(U.response("ERROR INVALID DATA"), "NE", "ERROR: none")
T.equal(U.response("MESSAGE NOT SUPPORTED BY THIS ATC UNIT"), "NE", "MESSAGE NOT SUPPORTED: none")
T.equal(U.response("REQUEST ALREADY RECEIVED"), "NE", "REQUEST ALREADY RECEIVED: none")
T.equal(U.response("PROCEED DIRECT TO SEA/AT DUVAL CLIMB TO AND MAINTAIN FL310/MAINTAIN .80/AT 1605Z "
    .. "EXPECT CRUISE CLIMB TO FL350/REPORT REACHING FL350"), "WU", "FCOM p.758-760's message: WU")
T.equal(U.response("EXPECT CLIMB AT 1605Z"), "R", "EXPECT CLIMB AT: ROGER")
T.equal(U.response("AT DUVAL CLIMB TO FL310"), "WU", "AT DUVAL CLIMB: WU")
T.equal(U.response("AFTER PASSING SEA DESCEND TO FL240"), "WU", "AFTER PASSING SEA DESCEND: WU")
T.equal(U.response("EXPECT FL350/CAN YOU ACCEPT FL370"), "AN", "EXPECT and CAN YOU: AN over R")
T.equal(U.response("UNABLE DUE TO TRAFFIC"), "NE", "UNABLE DUE TO TRAFFIC: none")
T.equal(U.response("CLIMB TO FL350 EXPECT FL370 AT 1600Z"), "WU", "CLIMB and EXPECT: WU")
-- as before
T.equal(U.response("CLIMB TO AND MAINTAIN FL350"), "WU", "CLIMB TO: WU")
T.equal(U.response("CAN YOU ACCEPT FL370 AT 1500Z"), "AN", "CAN YOU: AN")
T.equal(U.response("EXPECT FL390 AT 1600Z"), "R", "EXPECT: R")
T.equal(U.response("REPORT REACHING FL350"), "R", "REPORT: R")
T.equal(U.response("TURBULENCE REPORTED AHEAD"), "R", "free text: R")
T.equal(U.response("WHEN CAN YOU ACCEPT FL370"), "R", "WHEN CAN YOU ACCEPT: R (as before)")
-- (N19-ATC-02) the ground's attribute first
T.equal(U.response("CLIMB TO FL350", "R"), "R", "the ground's R over the words' WU")
T.equal(U.response("TURBULENCE REPORTED AHEAD", "WU"), "WU", "the ground's WU")
T.equal(U.response("TURBULENCE REPORTED AHEAD", "W/U"), "WU", "W/U")
T.equal(U.response("TURBULENCE REPORTED AHEAD", "A/N"), "AN", "A/N")
T.equal(U.response("CLIMB TO FL350", "NE"), "NE", "NE: none")
T.equal(U.response("CLIMB TO FL350", "N"), "NE", "N: none")
T.equal(U.response("CLIMB TO FL350", "Y"), "WU", "Y (any downlink): the words' (estimate)")
T.equal(U.response("CLIMB TO FL350", ""), "WU", "no attribute: the words'")

-- the FMS module as XTLua runs it, AutoATC mocked and logged on
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
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
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
local function uplink(text, rr)
    nid = nid + 1
    msgs[#msgs.values + 1] = {type = "cpdlc", title = string.sub(text, 1, 19), msg = text, read = false,
        time = "14:28", srcID = nid, messageID = nid, REPLIED = false, rr = rr}
    frames(0.3)
    return #msgs.values
end
local function down_status(text)
    local latest = nil
    for _, e in ipairs(fms.ns.B747_fms_atc_log_entries()) do
        if not e.up and e.text == text and (not latest or e.seq > latest.seq) then latest = e end
    end
    return latest and latest.status or nil
end
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
frames(16)                                        -- the logon's downlink sent

-- (N19-ATC-02) an instruction the ground marks R: ROGER only
uplink("CLIMB TO AND MAINTAIN FL350", "R")
key("func_key/crz")
T.check(page("ATC UPLINK"), "ATC: its uplink")
T.equal(line(11), "                 ACCEPT>", "the ground's R: ACCEPT (ROGER) only, no REJECT")
-- (N19-ATC-01) "AT ... EXPECT": ROGER only (before REJECT and ACCEPT)
key("ls_key/R5")
key("ls_key/R5")
frames(16)
uplink("AT 1605Z EXPECT CRUISE CLIMB TO FL350")
key("func_key/crz")
T.equal(line(11), "                 ACCEPT>", "AT 1605Z EXPECT ...: ACCEPT (ROGER) only")

-- (N19-ATC-04) ACCEPT, SEND: SENDING until the provider sends it, then
-- SENT, ACCEPTED, the CDU back on the uplink (FMSPG p.297)
key("ls_key/R5")
T.check(page("VERIFY RESPONSE"), "VERIFY RESPONSE")
T.equal(line(3):sub(1, 5), "ROGER", "ROGER")
key("ls_key/R5")
T.equal(line(11), "                 SENDING", "SEND: SENDING (before: SENT at once)")
T.check(not line(3):find("ACCEPTED"), "not ACCEPTED yet")
T.equal(down_status("ROGER"), "SENDING", "its ATC LOG entry SENDING")
frames(16)
T.check(page("ATC UPLINK"), "acknowledged: the CDU back on the uplink (FMSPG p.297): " .. line(1))
T.equal(line(3), "                ACCEPTED", "the uplink ACCEPTED")
T.equal(down_status("ROGER"), "SENT", "the response SENT")

-- no acknowledgement in time: RESEND>, NO ACK, ATC MSG NOT ACKNOWLEDGED
local q = uplink("CLIMB TO AND MAINTAIN FL370")
key("func_key/crz")
key("ls_key/R5")
T.equal(line(3):sub(1, 5), "WILCO", "WILCO")
rt:set("autoatc/acars/online", 0)
frames(0.3)
key("ls_key/R5")
T.equal(line(11), "                 NO COMM", "offline: NO COMM, nothing sent")
clear()
rt:set("autoatc/acars/online", 1)
frames(0.3)
key("ls_key/R5")
T.equal(line(11), "                 SENDING", "SENDING")
rt:set("autoatc/acars/online", 0)
frames(61)
T.equal(down_status("WILCO"), "NO ACK", "no network acknowledgement in 60 s: NO ACK in the log (FCOM p.753)")
T.equal(pad(), "ATC MSG NOT ACKNOWLEDGED", "ATC MSG NOT ACKNOWLEDGED (FCOM p.1431)")
T.equal(fms.ns.B747_atc_uplink_model.status(fms.ns.B747_fms_atc_uplink(q)), "OPEN", "the uplink still OPEN")
T.equal(line(11), "                 NO COMM", "offline still: NO COMM")
clear()
rt:set("autoatc/acars/online", 1)
frames(0.3)
T.equal(line(11), "                 RESEND>", "online: RESEND> (FCOM p.765)")
local n0 = #rawget(fms.ns.acarsSystem.messageSendQueue, "values")
key("ls_key/R5")
T.equal(line(11), "                 SENDING", "RESEND: SENDING")
T.equal(#rawget(fms.ns.acarsSystem.messageSendQueue, "values"), n0 + 1, "sent again through the provider")
local count = 0
for _, e in ipairs(fms.ns.B747_fms_atc_log_entries()) do if not e.up and e.text == "WILCO" then count = count + 1 end end
T.equal(count, 1, "the same ATC LOG entry")
frames(46)
T.equal(down_status("WILCO"), "SENT", "the resent one acknowledged: SENT")
T.equal(fms.ns.B747_atc_uplink_model.status(fms.ns.B747_fms_atc_uplink(q)), "ACCEPTED", "the uplink ACCEPTED")

-- (N19-ATC-05) ATC INDEX: no <PRINT LOG (no printer, as the uplink's PRINT)
key("func_key/crz")
T.check(page("ATC INDEX"), "nothing pending: the ATC key to ATC INDEX: " .. line(1))
T.equal(line(13), string.rep(" ", 24), "6L blank (FMSPG p.366: PRINT LOG and PRINT the printer's states alike)")
T.done()
