-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Exercise production LEGS, step advisory, ECON caller and optional automation.
-- Simulator interfaces are mocks; this does not validate flight dynamics.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    if first_marker then
        local first = assert(source:find(first_marker, 1, true))
        local last = assert(source:find(last_marker, first, true))
        source = source:sub(first, last-1)
    end
    setfenv(assert(loadstring(source, "@"..path)), runtime)()
end
local function environment(values)
    values = values or {}
    values.print = function() end
    return setmetatable(values, {__index=_G})
end

local json = dofile(FMS.."json/json.lua")
local step = dofile(FMS.."B744.fms.step.lua")
local route = {
    {0,0,0,0,0,0,0,"START",29000,true},
    {0,0,0,0,0,1,0,"ALPHA",29000,false},
    {0,0,0,0,0,2,0,"BRAVO",29000,false},
    {0,0,0,0,0,3,0,"CHARL",29000,false},
    {0,0,0,0,0,4,0,"DELTA",29000,false}
}
local steps = step.upsert({}, "BRAVO", "FL310", 3)
local modified = false
local r = environment({
    B747_fms_step=step, json=json, fmsPages={}, fmsFunctionsDefs={LEGS={},VNAV={}},
    createPage=function(name) return {name=name} end,
    cleanFMSLine=function(line) return line end,
    string=setmetatable({starts=function(value,prefix) return value:sub(1,#prefix)==prefix end},
        {__index=string}),
    fmsFlightPlan=json.encode(route), fmsJSON="[]",
    fmsModules={data={crzalt="FL290"}}, B747BR_cruiseAlt=29000,
    B747DR_srcfms={fmsL={}},
    B747_hasPlannedStepModification=function() return modified end,
    B747_getDisplayedPlannedSteps=function() return steps end,
    B747_getPlannedSteps=function() return steps end
})
local native = r.B747DR_srcfms.fmsL
for i=1,14 do native[i] = string.rep(" ",24) end
native[1] = "  MOD RTE 1 LEGS    1/1 "
for i=1,5 do native[2*i+1] = string.format("%-18s%6s", route[i][8], "FL290") end
load_in(FMS.."activepages/B744.fms.pages.legs.lua", r)
for _,constraint in ipairs({"FL290B", "FL290A", "FL290", "28000", "A/BWIN"}) do
    native[9] = string.format("%-18s%6s", "CHARL", constraint)
    local page = r.fmsPages.LEGS:getPage(1, "fmsL")
    equal(page[9], native[9], "preserve downstream native altitude field "..constraint)
    equal(page[7]:sub(19), "FL310S", "explicit step retains S marker")
    equal(page[1], native[1], "native route MOD survives without a custom step MOD")
end
native[1] = "  ACT RTE 1 LEGS    1/1 "
modified = true
local page = r.fmsPages.LEGS:getPage(1, "fmsL")
check(page[1]:find("MOD",1,true) ~= nil, "custom step edit still shows MOD")
check(page[13]:find("<ERASE",1,true) ~= nil, "custom step edit still exposes ERASE")
modified = false
equal(r.fmsPages.LEGS:getPage(1,"fmsL")[1], native[1], "unmodified ACT title is preserved")

-- Join the real advisory to the real optional script, and route its ALT press
-- into the actual aircraft command handler. LNAV may sequence a fly-by leg
-- while still 2 NM from the fix, before the 0.5 NM trigger is reached.
r.find_dataref = function() return "[]" end
r.fmsModules.data.stepsize = "ICAO"
r.fmsModules.data.stepto = "*****"
r.fmsModules.data.stepatwpt = ""
r.fmsModules.data.stepalt = "*****"
route[1][10], route[3][10] = false, true
route[3][5], route[3][6] = 2/60, 0
route[4][5], route[4][6] = 52/60, 0
route[5][5], route[5][6] = 102/60, 0
r.fmsFlightPlan = json.encode(route)
steps = step.upsert(steps, "DELTA", "FL330", 5)
r.B747BR_totalDistance, r.B747BR_tod = 1500, 100
r.simDR_groundspeed, r.simDR_GRWT = 230, 400000
r.simDR_latitude, r.simDR_longitude = 0, 0
r.simDR_eng_fuel_flow_kg_sec = {[0]=1,1,1,1}
r.dataref, r.create_command, r.do_every_frame, r.logMsg = function() end, function() end, function() end, function() end
r.getFMSData = function(key) return r.fmsModules.data[key] end
r.setFMSData = function(key,value) r.fmsModules.data[key] = value end
r.B747CMD_fdr_log_altmod = {once=function() end}
r.B747_ap_button_switch_position_target = {[16]=0}
r.simDR_onGround, r.B747DR_ap_vnav_state, r.B747DR_ap_inVNAVdescent = 0, 2, 0
r.simDR_autopilot_alt_hold_status, r.simDR_pressureAlt1, r.simDRTime = 2, 29000, 100
r.update_new_crzalt = function() end
r.is_timer_scheduled = function() return false end
local scheduled_delay
r.run_after_time = function(callback,delay)
    equal(callback, r.update_new_crzalt, "ALT press schedules aircraft cruise-climb callback")
    scheduled_delay = delay
end
load_in(FMS.."activepages/B744.fms.pages.vnav.lua", r)
load_in(AP.."B747.70.xt.autopilot.lua", r,
    "function B747_ap_switch_vnavalt_mode_CMDhandler(phase, duration)",
    "function B747_ap_ias_mach_sel_button_CMDhandler(phase, duration)")
load_in("FlyWithLua/B747_Auto_Step_Climb.lua", r)
local command_count = 0
r.command_once = function(command)
    equal(command, "laminar/B747/button_switch/press_altitude", "use actual ALT-selector command")
    command_count = command_count + 1
    -- Model two Lua namespaces referencing the same aircraft datarefs.
    r.B747DR_autopilot_altitude_ft = r.B747_ASC_mcp_altitude
    r.B747_ap_switch_vnavalt_mode_CMDhandler(0,0)
    r.B747_ap_switch_vnavalt_mode_CMDhandler(2,0)
    r.B747_ASC_cruise_altitude = r.B747BR_cruiseAlt
end
r.B747_ASC_mcp_altitude, r.B747_ASC_cruise_altitude = 29000, 29000
r.B747_ASC_pressure_altitude, r.B747_ASC_radio_altitude = 29000, 20000
r.B747_ASC_on_ground, r.B747_ASC_vnav_state, r.B747_ASC_vnav_descent = 0, 2, 0
r.B747_ASC_alt_hold_status, r.B747_ASC_servos_on, r.B747_ASC_sim_time = 2, 1, 100
local function scan(time)
    r.B747_ASC_sim_time = time
    r.B747_ASC_fms_data = json.encode(r.fmsModules.data)
    r.B747_ASC_update()
end
local advisory = r.B747_getStepClimbAdvisory()
equal(advisory.target, "FL310", "first unaccepted step is offered")
check(advisory.distance > 1.9 and advisory.distance < 2.1, "future step is 2 NM away")
scan(100)
equal(r.B747_ASC.armed_target, 31000, "automation arms future step")
route[3][10], route[4][10] = false, true
r.fmsFlightPlan = json.encode(route)
advisory = r.B747_getStepClimbAdvisory()
equal(advisory.target, "FL310", "sequencing cannot discard unaccepted step")
equal(advisory.distance, 0, "sequenced pending step remains NOW")
scan(101)
equal(r.B747_ASC_mcp_altitude, 31000, "previously armed NOW step sets MCP")
equal(command_count, 0, "ALT press waits for MCP settling")
scan(101.4)
equal(command_count, 1, "sequenced step issues one ALT press")
equal(r.B747BR_cruiseAlt, 31000, "aircraft accepts new cruise altitude")
equal(scheduled_delay, 2, "aircraft schedules cruise-climb transition")
equal(r.B747_ASC.last_executed_target, 31000, "only accepted target is marked executed")
advisory = r.B747_getStepClimbAdvisory()
equal(advisory.target, "FL330", "second step follows acceptance of first")
check(advisory.distance > 101 and advisory.distance < 103, "second step distance is retained")

-- Reuse the public script entry points for crew intervention and refusal.
local function reset_auto()
    r.B747_ASC_disable_command()
    r.B747_ASC_enable_command()
    r.B747_ASC.cooldown_until, r.B747_ASC.last_executed_target = 0, nil
    r.B747_ASC_cruise_altitude, r.B747_ASC_pressure_altitude = 29000, 29000
    r.B747_ASC_alt_hold_status, r.B747_ASC_mcp_altitude = 2, 29000
    r.fmsModules.data.stepto, r.fmsModules.data.stepdistance = "FL310", "2"
end
reset_auto()
r.B747_ASC_pressure_altitude = 29600
scan(200)
equal(r.B747_ASC.armed_target, nil, "do not arm outside aircraft's 500-ft acceptance band")
r.B747_ASC_pressure_altitude, r.B747_ASC_alt_hold_status = 29000, 1
scan(201)
equal(r.B747_ASC.armed_target, nil, "do not arm without altitude hold capture")
reset_auto()
scan(202)
r.fmsModules.data.stepdistance = "0"
scan(203)
r.B747_ASC_mcp_altitude = 30000
scan(203.4)
equal(command_count, 1, "crew MCP change cancels pending ALT press")
equal(r.B747_ASC.last_executed_target, nil, "cancelled target is not executed")
reset_auto()
r.fmsModules.data.stepdistance = "0"
scan(204)
equal(r.B747_ASC.pending_target, nil, "loading/enabling at NOW cannot trigger a climb")
reset_auto()
r.command_once = function() command_count = command_count + 1 end -- Aircraft rejects command.
scan(205)
r.fmsModules.data.stepdistance = "0"
scan(206)
scan(206.4)
equal(r.B747_ASC.awaiting_target, 31000, "dispatched command awaits aircraft acceptance")
equal(r.B747_ASC.last_executed_target, nil, "dispatch alone is not execution")
scan(212)
equal(r.B747_ASC.awaiting_target, nil, "unaccepted command times out")
equal(r.B747_ASC.last_executed_target, nil, "refused command remains unexecuted")

-- Load the production updater and its helper, not a reconstructed input list.
local perf = dofile(FMS.."B744.fms.performance.lua")
local econ = environment({
    fmsPerformance=perf,
    fmsModules={data={clbspdmode="ECON",crzalt="FL200",crzspd="810",costindex="230"}},
    simDR_GRWT=300000, simDR_pressureAlt1=20000, B747BR_toc=0,
    simDR_eng_fuel_flow_kg_sec={[0]=1,1,1,1}, simDR_groundspeed=220,
    simDR_onGround=0, simDR_wind_degrees=0, simDR_wind_speed=0,
    simDR_aircraft_hdg=0, simDR_air_temp=perf.isa_temperature_c(20000)
})
load_in(FMS.."B747.68.xt.fms.lua", econ,
    "local function totalEngineFuelFlowKgSec()", "function getFMSData(id)")
local helper = perf.econ_climb_speed_kcas
local actual_input
perf.econ_climb_speed_kcas = function(input)
    actual_input = input
    return helper(input)
end
econ.B747_updateEconClimbSpeed()
equal(actual_input.cruise_mach, 0.810, "production ECON caller supplies cruise Mach")
-- 349 is this repository's bounded model result, not Boeing calibration data.
equal(tonumber(econ.fmsModules.data.clbspd), 349, "low cruise altitude reaches existing CAS floor")
econ.fmsModules.data.clbspdmode, econ.fmsModules.data.clbspd = "SEL", "312"
econ.B747_updateEconClimbSpeed()
equal(econ.fmsModules.data.clbspd, "312", "manual climb speed is preserved")

print("FMC audit integration tests passed: "..checks)
