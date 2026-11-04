-- Run from the repository root with LuaJIT: luajit tests/fms/company_route_test.lua
-- The company datalink's flight plan (6-1/6-2 step 12h1; notes/
-- ATA-34-61-FMC.md §122; FCOM p.771-774, p.1288-1291; FMSPG p.367-376,
-- p.382) in the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic navigation data in tests/fms/data/navdb and SimBrief's sample
-- files in tests/fms/data/simbrief (the native plugin's _newest.txt
-- written by the test): FMC COMM 1/2 and 2/2, RTE REQUEST's SENDING and SENT, the
-- uplink (ROUTE 1 UPLINK READY, UPLINK, FLT NUMBER UPLINK), ROUTE UPLINK
-- with LOAD and PURGE, LOADING, the loaded route (SID, airway, approach),
-- the active route's modification, PURGE, a CO ROUTE's file, no file,
-- INVALID ROUTE UPLINK, the inactive route in the air.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("company_route")
local xtlua = dofile("tests/lib/xtlua.lua")

local DATA = "tests/fms/data/simbrief/"
B747_COMPANY_FOLDER = DATA
-- the native plugin's list of the folder's newest files
local function newest(fms_name, ofp_name)
    local f = assert(io.open(DATA .. "_newest.txt", "wb"))
    f:write("FMS " .. (fms_name or "") .. "\nOFP " .. (ofp_name or "") .. "\n")
    f:close()
end
newest(nil, nil)
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
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
-- the 570 (GE): the FMC's datalink (step 12a)
rt:set("laminar/B747/engines/type", 1)
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
local function type_in(text)
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.2)
end
local function clear_all()
    for _ = 1, 40 do rt:command(K .. "key/clear") end
    frames(0.2)
end
local function data(k) return (fms.ns.fmsModules.data[k]:gsub("%s+$", "")) end

-- FMC COMM 1/2 (FCOM p.771-772)
key("func_key/hold")
T.check(line(1):find("FMC COMM") and small(1):find("1/2"), "FMC COMM 1/2: " .. line(1))
T.equal(line(3), "<RTE 1       POS REPORT>", "<RTE 1 and POS REPORT> (FMSPG p.368)")
T.equal(line(5):gsub("%s+$", ""), "<DES FORECAST", "<DES FORECAST")
T.equal(line(7):gsub("%s+$", ""), "", "no <RTE DATA without an active route (FMSPG p.369)")
T.equal(small(12):gsub("^%s+", ""), "DATA LINK", "DATA LINK")
T.equal(line(13):gsub("^%s+", ""), "READY", "READY: the sim's company (no AutoATC)")
T.equal(small(2):gsub("%s+$", ""), "", "no UPLINK")

-- FMC COMM 2/2 (FCOM p.773-774)
key("func_key/next_pg")
T.check(small(1):find("2/2"), "FMC COMM 2/2")
T.equal(small(2), " RTE REQUEST    CO ROUTE", "RTE REQUEST and CO ROUTE")
T.equal(line(3), "<SEND         ----------", "<SEND, CO ROUTE dashes")
T.equal(small(4):gsub("%s+$", ""), " WIND REQUEST", "WIND REQUEST")
type_in("ZZAAZZBB0123")
key("ls_key/R1")
T.equal(pad(), "INVALID ENTRY", "CO ROUTE: 10 characters at most")
clear_all()

-- no file: the company's ACARS text, no uplink
key("ls_key/L1")
T.equal(line(3):sub(1, 7), "SENDING", "SEND: SENDING (FCOM p.773)")
frames(4)
T.equal(line(3):sub(1, 5), "<SEND", "the network's acknowledgement: <SEND")
T.equal(small(3):sub(6, 9), "SENT", "with SENT in small font")
local before = #fms.ns.acarsSystem.messages.values
frames(21)
local acars = fms.ns.acarsSystem.messages
T.equal(#acars.values, before + 1, "no flight plan on file: one ACARS message from the company")
T.check(acars[#acars.values].msg:find("NO FLIGHT PLAN ON FILE", 1, true), "its text: " .. tostring(acars[#acars.values].msg))
T.equal(fms.ns.B747_fms_company().up, nil, "and no uplink")

-- the files: the uplink
newest("ZZAAZZBB01.fms", "ofp_zzaa_zzbb.xml")
key("ls_key/L1")
frames(4.5)
frames(20)
T.check(pad() == "ROUTE 1 UPLINK READY" or pad() == "FLT NUMBER UPLINK", "the uplink's message: " .. pad())
local msgs = {}
for _ = 1, 3 do
    if pad() ~= "" then msgs[pad()] = true end
    key("key/clear")
end
T.check(msgs["ROUTE 1 UPLINK READY"] and msgs["FLT NUMBER UPLINK"], "ROUTE 1 UPLINK READY and FLT NUMBER UPLINK (FCOM p.1433)")
T.equal(data("fltno"), "JAL123", "the flight number from the OFP, at once (FCOM p.1433)")
-- (step 12h3) the OFP's ACARS text with it: the weights, fuel, cruise
-- altitude and step climbs for the crew to enter
do
    local m = fms.ns.acarsSystem.messages
    local last = m[#m.values]
    T.equal(last.title, "OFP ZZAA-ZZBB", "the company's OFP text: " .. tostring(last.title))
    T.check(last.msg:find("CRZ ALT FL250 CI 100", 1, true) and last.msg:find("STEP FL270 AT CHARL", 1, true)
        and last.msg:find("ZFW 225.0", 1, true) and not last.read, "its CRZ ALT, step climb and ZFW, unread")
    -- the ACARS message page's lines (acars.pages.lua's convertToFMSLines):
    -- each text line one (s203: "CRZ ALT FL250 CI" and "100" before)
    local ls = fms.ns.convertToFMSLines(last.msg)
    T.equal(ls[2], "CRZ ALT FL250 CI 100", "the page's second line whole")
    local long = fms.ns.convertToFMSLines("NO WIND DATA ON FILE FOR THE ACTIVE ROUTE@OK")
    T.check(#long == 3 and long[1] == "NO WIND DATA ON FILE FOR" and long[2] == "THE ACTIVE ROUTE" and long[3] == "OK",
        "a line over 24 characters wrapped at a space, then the next: " .. table.concat(long, "|"))
end
T.equal(line(3):gsub("%s+$", ""), "              ----------", "RTE REQUEST blank while the uplink waits (FMSPG p.382)")
T.equal(small(2), "                CO ROUTE", "and its title")
key("func_key/prev_pg")
T.equal(small(2):gsub("%s+$", ""), " UPLINK", "1/2: UPLINK over <RTE 1 (FMSPG p.368)")

-- RTE 1 with the uplink (FCOM p.1291)
key("ls_key/L1")
T.check(line(1):find("RTE 1"), "<RTE 1: RTE 1 page 1: " .. line(1))
T.equal(line(8), "-----              -----", "the ROUTE UPLINK line's dashes")
T.equal(small(8), "      ROUTE UPLINK      ", "ROUTE UPLINK")
T.equal(line(9), "<LOAD             PURGE>", "<LOAD and PURGE> (an inactive route)")
T.equal(line(5):gsub("^%S+%s+", ""), "JAL123", "FLT NO uplinked")
T.equal(line(7):gsub("^%s+", ""), "----------", "CO ROUTE dashes until loaded")
T.equal(line(13), "<RTE 2         ACTIVATE>", "ACTIVATE>")
key("ls_key/L4")
T.equal(pad(), "ROUTE 1 UPLINK LOADING", "LOAD: ROUTE 1 UPLINK LOADING (FCOM p.1291)")
T.equal(line(9):gsub("%s+$", ""), "<LOAD", "PURGE blank while loading")
T.equal(line(13):gsub("%s+$", ""), "<RTE 2", "ACTIVATE blank while loading (FMSPG p.372)")
frames(2.2)
T.equal(pad(), "", "loaded: the message gone")
T.equal(line(3), "ZZAA                ZZBB", "ORIGIN ZZAA, DEST ZZBB")
T.equal(line(5):sub(1, 5), "RW16R", "RUNWAY RW16R")
T.equal(line(7), "<SEND         ZZAAZZBB01", "CO ROUTE: the .fms's name; REQUEST <SEND again")
T.equal(line(8), "------------------------", "the dashes again")
T.equal(line(13), "<RTE 2         ACTIVATE>", "ACTIVATE> again")
local st = fms.ns.B747_fmc_route_num(1)
local R = fms.ns.B747_route_model
local names = {}
for _, s in ipairs(R.segments(R.shown(st))) do names[#names + 1] = (s.disc and "DISC" or (s.via .. " " .. (s.to or "?"))) end
T.equal(table.concat(names, ", "), "ZULU1.ALPHA ALPHA, Z1 DELTA, DISC, RNV09 RW09",
    "the SID and its transition to ALPHA, Z1 to DELTA, the approach (FCOM p.1290)")
T.check(R.shown(st).sid and R.shown(st).sid.name == "ZULU1" and R.shown(st).sid.trans == "ALPHA", "the SID ZULU1.ALPHA")
T.check(R.shown(st).appr and R.shown(st).appr.id == "R09", "the approach R09")
key("ls_key/R6")
key("key/execute")
T.check(st.active and fms.ns.B747_fmc_route.num == 1, "ACTIVATE, EXEC: RTE 1 active")
key("func_key/hold")
T.equal(line(7):gsub("%s+$", ""), "<RTE DATA", "FMC COMM: <RTE DATA with an active route")

-- the active route on the ground: LOAD makes a modification, no PURGE
-- (FMSPG p.376)
key("ls_key/L1")
key("ls_key/L3")
T.equal(line(7):sub(1, 7), "SENDING", "RTE page's REQUEST <SEND: SENDING")
frames(24.5)
T.equal(line(9), "<LOAD                   ", "the active route's uplink: <LOAD, no PURGE")
key("ls_key/R4")
T.check(fms.ns.B747_fms_company().up ~= nil, "PURGE does nothing on the active route")
clear_all()
key("ls_key/L4")
frames(2.2)
T.check(line(1):find("MOD RTE 1"), "LOAD: MOD RTE 1 (FMSPG p.376): " .. line(1))
T.equal(line(13):sub(1, 6), "<ERASE", "ERASE")
key("ls_key/L6")
T.check(line(1):find("ACT RTE 1"), "ERASE: the active route as it was")
T.equal(pad(), "", "the same flight number again: no FLT NUMBER UPLINK (estimate)")

-- RTE 2: a CO ROUTE's file (version 3, every point DIRECT), PURGE
key("ls_key/L6")
T.check(line(1):find("RTE 2"), "RTE 2: " .. line(1))
type_in("ZZAAZZBB03")
key("ls_key/R3")
T.equal(pad(), "NOT IN DATA BASE", "CO ROUTE ZZAAZZBB03: NOT IN DATA BASE, kept (FCOM p.1290)")
clear_all()
T.equal(line(7), "<SEND         ZZAAZZBB03", "the CO ROUTE")
key("ls_key/L3")
frames(24.5)
T.equal(pad(), "ROUTE 2 UPLINK READY", "ROUTE 2 UPLINK READY")
T.equal(line(9), "<LOAD             PURGE>", "LOAD and PURGE on RTE 2")
key("ls_key/R4")
T.equal(fms.ns.B747_fms_company().up, nil, "PURGE: the uplink dropped (FMSPG p.375)")
T.equal(pad(), "", "and its message")
T.equal(line(3), "****                ****", "RTE 2 unchanged")
key("ls_key/L3")
frames(24.5)
key("ls_key/L4")
frames(2.2)
names = {}
for _, s in ipairs(R.segments(R.shown(fms.ns.B747_fmc_route_num(2)))) do names[#names + 1] = s.disc and "DISC" or (s.via .. " " .. (s.to or "?")) end
T.equal(table.concat(names, ", "), "DIRECT ALPHA, DIRECT DELTA, DIRECT N36E141", "the CO ROUTE's file loaded: " .. table.concat(names, ", "))

-- a CO ROUTE not on file
type_in("NOFILE01")
key("ls_key/R3")
clear_all()
before = #fms.ns.acarsSystem.messages.values
key("ls_key/L3")
frames(24.5)
acars = fms.ns.acarsSystem.messages
T.check(#acars.values == before + 1 and acars[#acars.values].msg:find("CO ROUTE NOFILE01 NOT ON FILE", 1, true),
    "a CO ROUTE not on file: the company's text")
key("key/del")
key("ls_key/R3")
T.equal(line(7), "<SEND         ----------", "DELETE: CO ROUTE dashes, SEND (FCOM p.774)")

-- INVALID ROUTE UPLINK: the origin not in the database
type_in("XXXXZZBB01")
key("ls_key/R3")
clear_all()
key("ls_key/L3")
frames(24.5)
T.equal(pad(), "INVALID ROUTE UPLINK", "an origin not in the database: INVALID ROUTE UPLINK (FCOM p.1433)")
clear_all()
T.equal(fms.ns.B747_fms_company().up, nil, "no uplink")

-- in the air: RTE 1's request goes to the inactive RTE 2
key("key/del")
key("ls_key/R3")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(0.5)
key("ls_key/L6")
T.check(line(1):find("ACT RTE 1"), "RTE 1 in the air")
key("ls_key/L3")
frames(24.5)
T.equal(fms.ns.B747_fms_company().up.num, 2, "the uplink to RTE 2, the inactive route (FMSPG p.369: in flight)")

os.remove(DATA .. "_newest.txt")
T.done()
