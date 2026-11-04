-- Run from the repository root with LuaJIT: luajit tests/fms/datalink_keys_test.lua
-- The FMC's datalink keys (6-1/6-2 step 12a; notes/ATA-34-61-FMC.md §105;
-- FCOM p.725, p.1211): the 109 (PW, RR) has no FMC datalink, its ATC and
-- FMC COMM keys give KEY/FUNCTION INOP; the 570 (GE) opens the ATC pages
-- and FMC COMM pages. The simconfig's SIM.fmc_datalink (a sim option)
-- AUTO, ON or OFF, cycled on SIM CONFIG page 2's 4L.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("datalink_keys")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
local CFG = "laminar/B747/simconfig"
local function simconfig(datalink)
    -- a livery's SIM keys (the SIM CONFIG pages read them), without fmc_datalink
    local sim = '"weight_display_units":"KGS","kgs_to_lbs":2.20462,"irs_align_time":600,'
        .. '"std_pax_weight":120,"auto_fuel_mgmt":"NO","baro_indicator":"IN","baro_sync":"NO",'
        .. '"capt_inbd":"NORM","capt_lwr":"NORM","fo_inbd":"NORM","fo_lwr":"NORM"'
    if datalink then sim = sim .. ',"fmc_datalink":"' .. datalink .. '"' end
    rt:set(CFG, '{"SIM":{' .. sim .. '},'
        .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
        .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
    rt:set("laminar/B747/newsimconfig", 1)
end
simconfig(nil)
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

-- the left CDU: keys laminar/B747/fms1/, display fms3 (B747.68.xt.fms.lua)
local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function page(text) return line(1):find(text, 1, true) ~= nil end
local ENGINE = "laminar/B747/engines/type"
local INOP = "KEY/FUNCTION INOP"

key("ls_key/L1")
T.check(page("IDENT"), "MENU's <FMC: IDENT")

-- the 109 (PW): no FMC datalink
rt:set(ENGINE, 0)
key("func_key/crz")
T.equal(pad(), INOP, "PW (109): ATC KEY/FUNCTION INOP (FCOM p.1211)")
T.check(page("IDENT"), "the page stays")
key("key/clear")
key("func_key/hold")
T.equal(pad(), INOP, "PW: FMC COMM KEY/FUNCTION INOP")
key("key/clear")
rt:set(ENGINE, 2)
key("func_key/crz")
T.equal(pad(), INOP, "RR (109): ATC KEY/FUNCTION INOP")
key("key/clear")

-- the 570 (GE): the datalink's pages
rt:set(ENGINE, 1)
key("func_key/crz")
T.check(page("ATC LOGON/STATUS"), "GE (570): ATC opens the ATC pages (FCOM p.1211): LOGON/STATUS without ATC COMM (step 12e, FMSPG p.277)")
T.equal(pad(), "", "no message")
key("func_key/hold")
T.check(page("FMC COMM"), "GE: FMC COMM opens its page")

-- the simconfig: ON on the 109, OFF on the 570
rt:set(ENGINE, 0)
simconfig("ON")
frames(0.5)
key("func_key/crz")
T.check(page("ATC LOGON/STATUS"), "PW with fmc_datalink ON: the ATC pages")
rt:set(ENGINE, 1)
simconfig("OFF")
frames(0.5)
key("func_key/hold")
T.equal(pad(), INOP, "GE with fmc_datalink OFF: FMC COMM KEY/FUNCTION INOP")
key("key/clear")
simconfig("AUTO")
frames(0.5)
key("func_key/hold")
T.check(page("FMC COMM"), "GE with AUTO: FMC COMM")

-- SIM CONFIG page 2 (MENU's R6, NEXT): 4L cycles AUTO, ON, OFF
rt:set(ENGINE, 0)
key("func_key/fix")
key("ls_key/R6")
T.check(page("SIM CONFIG"), "MENU's R6: SIM CONFIG")
key("func_key/next_pg")
local function cfgLine() return (line(9):gsub("%s+$", "")) end
T.equal(cfgLine(), "<FMC DATALINK       AUTO", "page 2's 4L: AUTO")
key("ls_key/L4")
T.check(rt:get(CFG):find('"fmc_datalink":"ON"', 1, true) ~= nil, "4L: the simconfig ON")
frames(1.5)
T.equal(cfgLine(), "<FMC DATALINK         ON", "4L: ON")
key("ls_key/L4")
frames(1.5)
T.equal(cfgLine(), "<FMC DATALINK        OFF", "4L again: OFF")
key("ls_key/L4")
frames(1.5)
T.equal(cfgLine(), "<FMC DATALINK       AUTO", "4L again: AUTO")
key("ls_key/R1")
T.equal(cfgLine(), "<FMC DATALINK       AUTO", "page 1's R1 does nothing on page 2")

T.done()
