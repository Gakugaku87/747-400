-- Run from the repository root with LuaJIT: luajit tests/fms/company_simbrief_test.lua
-- SimBrief's latest OFP by the Pilot ID (notes/ATA-34-61-FMC.md §131; the
-- user's request, 2026-11-02) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), the FMS bridge's datarefs played by the test:
-- SIM CONFIG page 2's 5L (the Pilot ID: digits, INVALID ENTRY, DELETE),
-- RTE REQUEST's fetch request (the request number, none with a CO ROUTE
-- or without the bridge), the answer waiting for the fetch, the fetch's
-- failures in the company's ACARS text with the folder's files used, and
-- the wait's end after 60 s.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("company_simbrief")
local xtlua = dofile("tests/lib/xtlua.lua")

local DATA = "tests/fms/data/simbrief/"
B747_COMPANY_FOLDER = DATA
local function newest(fms_name, ofp_name)
    local f = assert(io.open(DATA .. "_newest.txt", "wb"))
    f:write("FMS " .. (fms_name or "") .. "\nOFP " .. (ofp_name or "") .. "\n")
    f:close()
end
newest("ZZAAZZBB01.fms", "ofp_zzaa_zzbb.xml")
local ID, FETCH = "laminar/B747/options/simbrief_id", "laminar/B747/fms/company/simbrief_fetch"
local DONE, STATUS = "laminar/B747/fms/company/simbrief_done", "laminar/B747/fms/company/simbrief_status"
local BRIDGE = "laminar/B747/fms/xp/bridge"
local types = {["xtlua/loadtoFMS"] = "string", [ID] = "number", [FETCH] = "number", [DONE] = "number",
    [STATUS] = "number", [BRIDGE] = "number"}
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
rt:set(BRIDGE, 1)
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
    for ch in text:gmatch(".") do rt:command(K .. "alphanum_key/" .. ch) end
    frames(0.2)
end
local function clear_all()
    for _ = 1, 40 do rt:command(K .. "key/clear") end
    frames(0.2)
end

-- SIM CONFIG page 2 (MENU's R6, NEXT): 5L, SimBrief's Pilot ID
key("func_key/fix")
key("ls_key/R6")
key("func_key/next_pg")
T.equal(small(10):gsub("%s+$", ""), " SIMBRIEF PILOT ID", "page 2's 5L: SIMBRIEF PILOT ID")
T.equal(line(11):gsub("%s+$", ""), "--------", "none yet: dashes")
type_in("262051")
key("ls_key/L5")
T.equal(rt:get(ID), 262051, "5L: the Pilot ID to the bridge's dataref")
frames(0.5)
T.equal(line(11):gsub("%s+$", ""), "262051", "and on the page")
T.equal(pad(), "", "the scratchpad cleared")
type_in("12AB")
key("ls_key/L5")
T.equal(pad(), "INVALID ENTRY", "not digits: INVALID ENTRY")
T.equal(rt:get(ID), 262051, "the Pilot ID kept")
clear_all()
type_in("1234567890")
key("ls_key/L5")
T.equal(pad(), "INVALID ENTRY", "10 digits: INVALID ENTRY")
clear_all()
rt:command(K .. "key/del")
frames(0.2)
key("ls_key/L5")
T.equal(rt:get(ID), 0, "DELETE: none")
type_in("262051")
key("ls_key/L5")
T.equal(rt:get(ID), 262051, "again: 262051")

-- FMC COMM 2/2's RTE REQUEST <SEND: the fetch's request number, the
-- answer waiting for it
key("func_key/hold")
key("func_key/next_pg")
local n0 = rt:get(FETCH)
key("ls_key/L1")
T.equal(rt:get(FETCH), n0 + 1, "SEND with a Pilot ID: the bridge's fetch request number + 1")
frames(4.5)
frames(25)
T.equal(fms.ns.B747_fms_company().up, nil, "the fetch not done 25 s after SENT: no answer yet")
-- the bridge's fetch done: its files in the folder's list, the request done
newest("ZZAAZZBB01.fms", "ofp_zzaa_zzbb.xml")
rt:set(STATUS, 2)
rt:set(DONE, n0 + 1)
local before = #fms.ns.acarsSystem.messages.values
frames(1)
T.check(fms.ns.B747_fms_company().up ~= nil, "the fetch done: the uplink at once")
local m = fms.ns.acarsSystem.messages
for i = before + 1, #m.values do
    T.check(m[i].title ~= "SIMBRIEF", "a fetch done: no SIMBRIEF text")
end
key("func_key/hold")
key("ls_key/L1")
frames(0.5)
for _ = 1, 3 do key("key/clear") end
fms.ns.B747_fms_company_purge(1)
frames(0.5)

-- a failed fetch (no answer from SimBrief): the company's text, the
-- folder's newest files used
key("func_key/hold")
key("func_key/next_pg")
local n1 = rt:get(FETCH)
key("ls_key/L1")
T.equal(rt:get(FETCH), n1 + 1, "SEND again: + 1")
rt:set(STATUS, 4)
rt:set(DONE, n1 + 1)
before = #fms.ns.acarsSystem.messages.values
frames(4.5)
frames(21)
m = fms.ns.acarsSystem.messages
local said = false
for i = before + 1, #m.values do
    if m[i].title == "SIMBRIEF" and m[i].msg:find("SIMBRIEF: NO ANSWER", 1, true) then said = true end
end
T.check(said, "status 4: the company's SIMBRIEF text, NO ANSWER")
T.check(fms.ns.B747_fms_company().up ~= nil, "and the uplink from the folder's files")
fms.ns.B747_fms_company_purge(1)
frames(0.5)

-- the bridge never done: the answer after 60 s, NO ANSWER
key("func_key/hold")
key("func_key/next_pg")
local n2 = rt:get(FETCH)
key("ls_key/L1")
before = #fms.ns.acarsSystem.messages.values
frames(4.5)
frames(50)
T.equal(fms.ns.B747_fms_company().up, nil, "not done 50 s after SENT: still waiting")
frames(11)
m = fms.ns.acarsSystem.messages
said = false
for i = before + 1, #m.values do
    if m[i].title == "SIMBRIEF" and m[i].msg:find("NO ANSWER", 1, true) then said = true end
end
T.check(said and fms.ns.B747_fms_company().up ~= nil, "60 s: NO ANSWER and the folder's files")
T.equal(rt:get(FETCH), n2 + 1, "(that request's number)")
fms.ns.B747_fms_company_purge(1)
frames(0.5)

-- a CO ROUTE names a file of the folder's: no fetch
key("func_key/hold")
key("func_key/next_pg")
type_in("ZZAAZZBB03")
key("ls_key/R1")
local n3 = rt:get(FETCH)
key("ls_key/L1")
T.equal(rt:get(FETCH), n3, "with a CO ROUTE: no fetch request")
frames(4.5)
frames(21)
T.check(fms.ns.B747_fms_company().up ~= nil, "the CO ROUTE's file at 20 s as before")
fms.ns.B747_fms_company_purge(1)
rt:command(K .. "key/del")
frames(0.2)
key("ls_key/R1")
frames(0.5)

-- no bridge: no fetch
rt:set(BRIDGE, 0)
local n4 = rt:get(FETCH)
key("ls_key/L1")
T.equal(rt:get(FETCH), n4, "without the FMS bridge: no fetch request")

T.done()
