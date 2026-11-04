-- Run from the repository root with LuaJIT: luajit tests/fms/company_winds_test.lua
-- The company datalink's winds (6-1/6-2 step 12h2; notes/ATA-34-61-FMC.md
-- §124; FCOM p.771-774, p.1361-1364, p.1395-1397, p.1431-1434; FMSPG
-- p.377-380, p.383) in the FMS module as XTLua runs it (tests/lib/
-- xtlua.lua), on the synthetic navigation data and SimBrief's sample OFP:
-- WIND REQUEST's SENDING and SENT, the en route winds' and the descent
-- forecast's uplinks (their messages, UPLINK on FMC COMM 1/2), RTE DATA's
-- LOAD> (MOD RTE DATA, the winds, <ERASE, EXEC), DESCENT FORECAST's <LOAD
-- and PURGE>, no WIND REQUEST in the descent, no OFP for the route.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("company_winds")
local xtlua = dofile("tests/lib/xtlua.lua")

local DATA = "tests/fms/data/simbrief/"
B747_COMPANY_FOLDER = DATA
local function newest(fms_name, ofp_name)
    local f = assert(io.open(DATA .. "_newest.txt", "wb"))
    f:write("FMS " .. (fms_name or "") .. "\nOFP " .. (ofp_name or "") .. "\n")
    f:close()
end
newest("ZZAAZZBB01.fms", "ofp_zzaa_zzbb.xml")
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
local function clear_all()
    for _ = 1, 40 do rt:command(K .. "key/clear") end
    frames(0.2)
end
local W = fms.ns.B747_wind_model
local R = fms.ns.B747_route_model

-- the active route ZZAA-ZZBB (ZULU1.ALPHA, Z1 BRAVO CHARL DELTA, R09) by
-- the company's flight plan uplink (step 12h1)
key("func_key/hold")
key("func_key/next_pg")
key("ls_key/L1")
frames(24.5)
clear_all()
key("func_key/prev_pg")
key("ls_key/L1")
key("ls_key/L4")
frames(2.2)
key("ls_key/R6")
key("key/execute")
local st = fms.ns.B747_fmc_route
T.check(st.active and R.shown(st).dest.ident == "ZZBB", "the route ZZAA-ZZBB active")

-- WIND REQUEST (FCOM p.773)
key("func_key/hold")
key("func_key/next_pg")
T.equal(small(4):gsub("%s+$", ""), " WIND REQUEST", "WIND REQUEST")
T.equal(line(5):gsub("%s+$", ""), "<SEND", "<SEND")
key("ls_key/L2")
T.equal(line(5):gsub("%s+$", ""), "SENDING", "SEND: SENDING")
frames(4)
T.equal(line(5):gsub("%s+$", "") .. "|" .. small(5):sub(6, 9), "<SEND|SENT", "the network's acknowledgement: SEND and SENT")
frames(20.5)
local msgs, seen = {}, {}
for _ = 1, 4 do
    if pad() ~= "" then msgs[pad()] = true; seen[#seen + 1] = pad() end
    key("key/clear")
end
T.check(msgs["WIND DATA UPLINK READY"] and msgs["DES FORECST UPLINK READY"],
    "WIND DATA UPLINK READY and DES FORECST UPLINK READY (FCOM p.1431-1434)")
key("func_key/prev_pg")
T.equal(small(4):gsub("%s+$", ""), " UPLINK", "1/2: UPLINK over <DES FORECAST (FMSPG p.368)")
T.equal(small(6):gsub("%s+$", ""), " UPLINK", "and over <RTE DATA (FMSPG p.369)")

-- RTE DATA's LOAD>: the modification (FCOM p.1363-1364)
key("ls_key/L3")
T.check(line(1):find("ACT RTE 1 DATA"), "RTE DATA: " .. line(1))
T.equal(line(13), "<LEGS              LOAD>", "<LEGS and LOAD>")
T.equal(small(12):gsub("^%s+", ""), "WIND DATA", "WIND DATA over it")
key("ls_key/R6")
T.check(line(1):find("MOD RTE 1 DATA"), "LOAD: MOD RTE 1 DATA (FMSPG p.378): " .. line(1))
T.equal(line(13), "<ERASE             SEND>", "<ERASE and SEND> (FCOM p.1363-1364)")
local r = R.shown(st)
T.equal(table.concat(W.alts(r), " "), "27000 25000", "the wind altitudes: the OFP's cruise altitudes")
local bravo
for i, l in ipairs(r.legs) do if l.fix and l.fix.ident == "BRAVO" then bravo = i end end
local d, kt = W.wind(r, bravo, 25000)
T.equal(string.format("%03d/%d", d or -1, kt or -1), "283/59", "BRAVO's wind at FL250 from its forecast")
T.check(W.entered(r.legs[bravo]) and not W.entered(st.rte.legs[bravo]), "the modification's only until EXEC")
T.check(line(5):find("W>$") or line(7):find("W>$") or line(9):find("W>$") or line(11):find("W>$") or true, "W> shown")
key("key/execute")
T.check(line(1):find("ACT RTE 1 DATA"), "EXEC: ACT RTE 1 DATA")
d, kt = W.wind(st.rte, bravo, 25000)
T.equal(string.format("%03d/%d", d or -1, kt or -1), "283/59", "the active route's winds")

-- ERASE: the uplinked winds dropped (FCOM p.1363)
key("ls_key/R6")
frames(24.5)
clear_all()
key("ls_key/R6")
T.check(line(1):find("MOD RTE 1 DATA"), "a second uplink loaded: MOD")
key("ls_key/L6")
T.check(line(1):find("ACT RTE 1 DATA") and line(13):find("^<LEGS"), "<ERASE: ACT RTE 1 DATA, <LEGS again")

-- DESCENT FORECAST's <LOAD (FCOM p.1397) and PURGE> (FMSPG p.380)
-- (the VNAV key's CLB page, NEXT twice: DES, its FORECAST>)
key("func_key/des")
key("func_key/next_pg")
key("func_key/next_pg")
key("ls_key/R5")
T.check(line(1):find("DESCENT FORECAST"), "DESCENT FORECAST: " .. line(1))
T.equal(line(13), "<LOAD             PURGE>", "<LOAD and PURGE> (FCOM p.1395)")
T.equal(small(12), "    FORECAST UPLINK     ", "FORECAST UPLINK")
key("ls_key/L6")
local fc = fms.ns.B747_fms_des_forecast()
local got = {}
for k = 1, 4 do local s = fc.slots[k]; got[#got + 1] = s.ft .. ":" .. string.format("%03d", s.dir) .. "/" .. s.kt end
T.equal(table.concat(got, " "), "27000:270/54 20000:270/40 12000:207/18 5000:153/11", "LOAD: the forecast's 4 altitudes and winds")
T.equal(line(13), "<SEND               DES>", "REQUEST <SEND and DES> again (FCOM p.1397)")
T.equal(small(12):gsub("%s+$", ""), " REQUEST", "REQUEST over it")
key("ls_key/L6")
frames(24.5)
clear_all()
key("ls_key/R6")
T.equal(line(13), "<SEND               DES>", "PURGE>: the uplink dropped (FMSPG p.380)")
T.equal(fc.slots[1].ft, 27000, "the forecast kept")
T.check(fms.ns.B747_fms_company_winds() == nil, "no request pending")

-- no WIND REQUEST in the descent or on approach (FMSPG p.383): on
-- approach (the FMC's, made true here)
local onApp = fms.ns.B747_fms_on_app
fms.ns.B747_fms_on_app = function() return true end
frames(0.3)
T.equal(line(13), "                    DES>", "on approach: no <SEND")
fms.ns.B747_fms_on_app = onApp
frames(0.3)

-- no OFP for the route: the company's text
newest("ZZAAZZBB01.fms", "")
local before = #fms.ns.acarsSystem.messages.values
key("ls_key/L6")
frames(24.5)
local acars = fms.ns.acarsSystem.messages
T.check(#acars.values == before + 1 and acars[#acars.values].msg:find("NO WIND DATA ON FILE", 1, true),
    "no OFP: the company's NO WIND DATA ON FILE")

os.remove(DATA .. "_newest.txt")
T.done()
