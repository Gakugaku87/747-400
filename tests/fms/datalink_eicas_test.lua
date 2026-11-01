-- Run from the repository root with LuaJIT: luajit tests/fms/datalink_eicas_test.lua
-- The datalink's EICAS messages (6-1/6-2 step 12d1; notes/ATA-34-61-FMC.md
-- §111; FCOM p.725, p.775-776) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), AutoATC's datarefs mocked: with the FMC's
-- datalink (the 570, GE) ATC MESSAGE for an unread ATC uplink and its chime,
-- ACARS MESSAGE for an unread ACARS message; the 109 (PW) ACARS MESSAGE for
-- any; no ACARS NO COMM memo; >DATALINK LOST after a loss of the
-- connection, >DATALINK AVAIL for a minute when it comes back.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("datalink_eicas")
local xtlua = dofile("tests/lib/xtlua.lua")

-- AutoATC's datarefs (the plugin creates them in X-Plane)
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

local MEMO, ADV = "laminar/B747/CAS/memo_status", "laminar/B747/CAS/advisory_status"
local ACARS_MSG, NO_COMM, ATC_MSG = 0, 40, 46
local DL_AVAIL, DL_LOST = 55, 56
local CHIME, ENGINE, ONLINE = "laminar/B747/fms/atc_chime", "laminar/B747/engines/type", "autoatc/acars/online"
local function memo(i) return rt:get(MEMO, i) end
local function adv(i) return rt:get(ADV, i) end
local msgs = fms.ns.acarsSystem.messages
local function add(kind) msgs[#msgs.values + 1] = {type = kind, read = false, title = "TEST", time = "10:00"} return #msgs.values end

-- never connected: no >DATALINK LOST, no ACARS NO COMM
seconds(2)
T.equal(adv(DL_LOST), 0, "never connected: no >DATALINK LOST (no loss)")
T.equal(memo(NO_COMM), 0, "no ACARS NO COMM memo (not the FCOM's)")

-- the 570 (GE): the FMC's datalink
rt:set(ENGINE, 1)
local a = add("cpdlc")
frames(0.2)
T.equal(memo(ATC_MSG), 1, "570, an unread ATC uplink: ATC MESSAGE (FCOM p.776)")
T.equal(memo(ACARS_MSG), 0, "not ACARS MESSAGE")
T.equal(rt:get(CHIME), 1, "the chime as it comes (FCOM p.725)")
seconds(2)
T.equal(rt:get(CHIME), 0, "the chime a second only")
T.equal(memo(ATC_MSG), 1, "the memo stays while unread")
local b = add("telex")
frames(0.2)
T.equal(memo(ACARS_MSG), 1, "an unread ACARS message: ACARS MESSAGE")
T.equal(rt:get(CHIME), 0, "no chime for an ACARS message")
msgs[a]["read"] = true
frames(0.2)
T.equal(memo(ATC_MSG), 0, "the uplink read: no ATC MESSAGE")
T.equal(memo(ACARS_MSG), 1, "ACARS MESSAGE still")
msgs[b]["read"] = true
frames(0.2)
T.equal(memo(ACARS_MSG), 0, "read: no ACARS MESSAGE")

-- the 109 (PW): no FMC datalink, ACARS MESSAGE for an ATC one too
rt:set(ENGINE, 0)
local c = add("cpdlc")
frames(0.2)
T.equal(memo(ACARS_MSG), 1, "109, an unread ATC message: ACARS MESSAGE")
T.equal(memo(ATC_MSG), 0, "109: no ATC MESSAGE")
T.equal(rt:get(CHIME), 0, "109: no ATC chime")
msgs[c]["read"] = true
frames(0.2)

-- the connection: lost after it was there, available again for a minute
rt:set(ONLINE, 1)
seconds(2)
T.equal(adv(DL_LOST), 0, "connected: no >DATALINK LOST")
T.equal(adv(DL_AVAIL), 0, "the first connection: no >DATALINK AVAIL")
rt:set(ONLINE, 0)
seconds(2)
T.equal(adv(DL_LOST), 1, "the connection lost: >DATALINK LOST (FCOM p.775)")
rt:set(ONLINE, 1)
seconds(2)
T.equal(adv(DL_LOST), 0, "back: no >DATALINK LOST")
T.equal(adv(DL_AVAIL), 1, "back after a loss: >DATALINK AVAIL")
seconds(60)
T.equal(adv(DL_AVAIL), 0, "a minute on: >DATALINK AVAIL gone (estimate)")
T.equal(memo(NO_COMM), 0, "never ACARS NO COMM")
T.done()
