-- Run from the repository root with LuaJIT: luajit tests/fms/simopts_glue_test.lua
-- The sim's options (2026-11-01 the user; notes/ATA-34-61-FMC.md §126) in
-- the FMS module as XTLua runs it (tests/lib/xtlua.lua): with Plugins >
-- 747-400's auto step climb on, at the CRZ page's AT NOW (FCOM
-- p.1348-1349) with VNAV engaged in the cruise the MCP altitude (the
-- window and the AFDS's) set to STEP TO, the altitude selector's command a
-- second later, and its push making CRZ ALT STEP TO (FCOM p.649); with
-- pause at T/D on, X-Plane's pause command once two minutes before the T/D
-- (FCOM p.1433).
local T = dofile("tests/lib/check.lua")("simopts_glue")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local pw = P.tables(0)

local types = {["laminar/B747/options/auto_step_climb"] = "number", ["laminar/B747/options/pause_at_td"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/flightmodel/weight/m_total", 270000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 135)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.1) end
local function type_in(text)
    for ch in text:gmatch(".") do rt:command("laminar/B747/fms1/alphanum_key/" .. ch) end
    frames(0.1)
end
local function commands(name)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.name == name and e.phase == "once" then n = n + 1 end
    end
    return n
end
local PUSH, PAUSE = "laminar/B747/button_switch/press_altitude", "sim/operation/pause_on"
local MCP, AFDS = "laminar/B747/autopilot/heading/altitude_dial_ft", "laminar/B747/autopilot/altitude_dial_ft"

-- CRZ ALT FL350 on PERF INIT, the cruise at FL350 with an active route,
-- 250 t: OPT above FL370, STEP TO FL390 (ICAO, west) AT NOW
key("func_key/index")
type_in("350")
key("ls_key/R1")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 35000)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 36.089)
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel2/position/groundspeed", 236.6)
fms.ns.B747_fmc_route.active = true
rt:set(MCP, 35000)
rt:set(AFDS, 35000)
frames(1)
T.equal(fms.ns.B747_fms_vnav_page(), 2, "the FMC in the cruise")
local step = fms.ns.B747_fms_crz_step()
T.equal(step.to, 39000, "B747_fms_crz_step: STEP TO FL390 (the CRZ page's)")
T.check(step.now and not step.near_td, "and AT NOW")
key("func_key/des")
T.check(line(3):find("FL390$") and line(5):find("NOW$"), "the CRZ page: STEP TO FL390, NOW: " .. line(3) .. "|" .. line(5))
-- a crew's STEP TO FL390 (the same), for the push's new CRZ ALT below
type_in("390")
key("ls_key/R1")
T.equal((fms.ns.fmsModules.data.stepalt:gsub("%s+$", "")), "FL390", "the crew's STEP TO FL390")

-- the option off: nothing
frames(3)
T.equal(rt:get(MCP), 35000, "the option off: the MCP altitude as it was")
T.equal(commands(PUSH), 0, "and no push")
-- on, VNAV not engaged: nothing
rt:set("laminar/B747/options/auto_step_climb", 1)
frames(3)
T.equal(rt:get(MCP), 35000, "VNAV not engaged: the MCP altitude as it was")
-- VNAV engaged: the MCP altitude, then the push
rt:set("laminar/B747/autopilot/vnav_state", 2)
frames(0.6)
T.equal(rt:get(MCP), 39000, "VNAV engaged: the MCP window STEP TO")
T.equal(rt:get(AFDS), 39000, "and the AFDS's altitude")
T.equal(commands(PUSH), 0, "no push yet")
frames(1.2)
T.equal(commands(PUSH), 1, "a second later the altitude selector's push, once")
frames(2)
T.equal(commands(PUSH), 1, "not again")
-- the push (the autopilot module counts it: B747.70.xt.autopilot.lua):
-- CRZ ALT FL390, the cruise climb (FCOM p.649, p.1257)
rt:set("laminar/B747/autopilot/alt_sel_pushes", (rt:get("laminar/B747/autopilot/alt_sel_pushes") or 0) + 1)
frames(1)
T.equal(rt:get("laminar/B747/autopilot/dist/cruise_alt"), 39000, "the push: CRZ ALT FL390")
T.equal((fms.ns.fmsModules.data.stepalt:gsub("%s+$", "")), "", "the crew's STEP TO gone with the new CRZ ALT (as the CDU's entry)")
local page, chg = fms.ns.B747_fms_vnav_page()
T.check(page == 2 and chg == "CLB", "the cruise climb (CRZ CLB): " .. tostring(page) .. " " .. tostring(chg))
frames(3)
T.equal(commands(PUSH), 1, "in the cruise climb: no more pushes")

-- the MCP altitude set below CRZ ALT (the descent's): no step
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 39000)
rt:set("sim/flightmodel/weight/m_total", 200000)
frames(1)
rt:set(MCP, 10000)
local before = commands(PUSH)
frames(3)
T.equal(rt:get(MCP), 10000, "the MCP altitude below CRZ ALT: left as it is")
T.equal(commands(PUSH), before, "and no push")
rt:set("laminar/B747/options/auto_step_climb", 0)

-- the pause: 460 kt, the T/D 20 NM (2.6 min) then 15 NM (1.96 min) ahead
local td = 20
local realTd = fms.ns.B747_fms_vnav_td
fms.ns.B747_fms_vnav_td = function() return td end
rt:set("laminar/B747/options/pause_at_td", 1)
frames(2)
T.equal(fms.ns.B747_fms_vnav_page(), 2, "the cruise at FL390")
T.equal(commands(PAUSE), 0, "2.6 min to the T/D: no pause")
td = 15
frames(1)
T.equal(commands(PAUSE), 1, "1.96 min: X-Plane's pause command, once")
td = 14
frames(2)
T.equal(commands(PAUSE), 1, "not again")
td = 30
frames(1)
td = 15
frames(1)
T.equal(commands(PAUSE), 2, "the T/D moved 3.9 min away and back: the pause again")
rt:set("laminar/B747/options/pause_at_td", 0)
td = 40
frames(1)
td = 10
frames(1)
T.equal(commands(PAUSE), 2, "the option off: no pause")
fms.ns.B747_fms_vnav_td = realTd

T.done()
