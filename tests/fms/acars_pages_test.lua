-- Run from the repository root with LuaJIT: luajit tests/fms/acars_pages_test.lua
-- (2026-11-05 review 4) The ACARS pages (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/acars) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), AutoATC's datarefs mocked:
--  - INITIALIZE: DEP/DES from the FMC's route, X-Plane's flight plan JSON not
--    read (before, decoded at each draw: a bad one left the page blank);
--  - WEATHER REQUEST: its own airport (ORIGIN, DESTINATION, AIRPORT), the
--    ATC logon untouched (before, the logon's facility: a request logged on
--    there, an entry not of four letters logged ATC COMM off);
--  - the uplink list: L1-L4 the lines of the pressing CDU's page, an empty
--    line nothing (before, bound at each draw: a shorter last page kept the
--    page before's), a message at its page 1 (before, the list's page).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("acars_pages")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["autoatc/acars/in"] = "string",
    ["autoatc/acars/out"] = "string", ["autoatc/cdu"] = "string", ["autoatc/networking/url"] = "string",
    ["autoatc/networking/data"] = "string", ["autoatc/networking/urlstatus"] = "number",
    ["autoatc/acars/online"] = "number", ["autoatc/hasMobile"] = "number", ["autoatc/com_power"] = "number",
    ["autoatc/com_frequency_override"] = "number", ["autoatc/com_frequency_hz_833"] = "number",
    ["autoatc/com_standby_frequency_hz_833"] = "number", ["autoatc/comChannel"] = "number"}
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
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.7) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do rt:command(K .. (ch == "/" and "key/slash" or "alphanum_key/" .. ch)) end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local data = fms.ns.fmsModules.data
local cdu = fms.ns.fmsModules.fmsL

-- INITIALIZE (MENU, <ACARS, <PREFLIGHT, <INITIALIZE)
key("func_key/fix")
key("ls_key/L2")
key("ls_key/L1")
key("ls_key/L2")
T.check(page("ACARS-INITIALIZATION"), "INITIALIZE: " .. line(1))
T.check(line(5):find("^<%*%*%*%*/%*%*%*%*"), "no route: DEP/DES boxes: " .. line(5))
local rte = fms.ns.B747_fmc_route.rte
rte.origin, rte.dest = {ident = "ZZAA"}, {ident = "ZZBB"}
frames(0.5)
T.check(line(5):find("^<ZZAA/ZZBB"), "DEP/DES the FMC's route's (before: X-Plane's flight plan's): " .. line(5))
rte.origin, rte.dest = nil, nil

-- WEATHER REQUEST with ATC COMM established at RJAA (MENU, <ACARS, WXR REQ>)
rt:set("autoatc/acars/online", 1)
local logon = fms.ns.B747_fms_atc_logon()
logon.comm, logon.act = true, "RJAA"
fms.ns.setFMSData("atc", "RJAA")
frames(1)
T.check(logon.comm and logon.act == "RJAA", "(ATC COMM with RJAA)")
key("func_key/fix")
key("ls_key/L2")
key("ls_key/R3")
T.check(page("ACARS WEATHER REQUEST"), "WEATHER REQUEST: " .. line(1))
key("ls_key/L1")
T.equal(data.wxapt, "ZZAA", "ORIGIN: the request's airport the origin")
T.check(logon.comm and logon.act == "RJAA" and logon.ctr == nil,
    "ORIGIN: ATC COMM with RJAA kept, no logon (before: a logon to ZZAA)")
enter("AB1", "R2")
T.check(pad() == "INVALID ENTRY" and logon.comm, "AIRPORT AB1: INVALID ENTRY, ATC COMM kept (before: logged off): " .. pad())
clear()
enter("RJTT", "R2")
T.equal(data.wxapt, "RJTT", "AIRPORT RJTT: the request's airport")
T.check(data.atc == "RJAA" and logon.comm and logon.act == "RJAA", "the ATC facility RJAA kept")
T.check(line(5):find("RJTT>$"), "AIRPORT shown: " .. line(5))

-- the uplink list (MENU, <ACARS, MSGS>, <UPLINK): five telexes as the
-- provider stores them (autoatcProvider.lua), the newest first, four a page
local msgs = fms.ns.acarsSystem.messages
for i = 1, 5 do msgs[#msgs.values + 1] = {type = "telex", title = "MSG " .. i, msg = "TEXT " .. i, read = false, rr = "N",
    time = "10:0" .. i} end
key("func_key/fix")
key("ls_key/L2")
key("ls_key/R1")
key("ls_key/L2")
T.check(page("ACARS-UPLINK MSG"), "the uplink list: " .. line(1))
T.check(line(3):find("^<MSG 5"), "page 1's first line the newest: " .. line(3))
key("func_key/next_pg")
T.equal(cdu.pgNo, 2, "NEXT PAGE: page 2")
T.check(line(3):find("^<MSG 1"), "page 2: the oldest: " .. line(3))
key("ls_key/L2")
T.check(cdu.currentPage == "VIEWUPACARS" and cdu.pgNo == 2,
    "page 2's empty L2: nothing (before: page 1's MSG 4 opened): " .. tostring(cdu.currentPage))
key("ls_key/L1")
T.equal(cdu.currentPage, "VIEWACARSMSG", "page 2's L1: its message")
T.equal(fms.ns.acarsSystem.getCurrentMessage("fmsL"), 1, "MSG 1")
T.equal(cdu.pgNo, 1, "at its page 1 (before: the list's page 2)")
T.done()
