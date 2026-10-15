-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV's speed with the route's speed constraints from the CIFP
-- (B747_route_constraints). The 747 got no speed with the route (xtlua/fms),
-- so VNAV flew EIDW 28R ENDE3J at 230-235 kt past DW129 (at or below 210 kt)
-- and at 316 kt past ENDEQ (at or below 290 kt). In the climb a SID's at or
-- below (or at) speed now holds from the departure until its fix is passed -
-- a fix LNAV sequenced early for its turn until past the turn's bisector - as
-- the FMC keeps a climb speed constraint over the legs before its fix; it caps
-- the climb's CAS targets (laminar/B747/autopilot/vnav/constraint_speed),
-- never below the manoeuvring speed of the flaps set, so the flaps stay out
-- for a slow one (the kit retracts a step at its manoeuvring speed + 5 kt).
-- The production B747_update_constraint_speed (B747.70.xt.autopilot.lua)
-- and VNAV speed state machine (vnavspd.lua) run against mocked datarefs.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        checks = checks + 1
        failures[#failures + 1] = name..": "..tostring(err)
    end
end

local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end
local function eidw()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("RW28R", 53.435203, -6.244964),
        entry("DE28R", 53.437394, -6.284811), entry("(650)", 53.4395, -6.2970, 650, 2048),
        entry("DW128", 53.465722, -6.352278), entry("DW129", 53.526722, -6.348806),
        entry("DW124", 53.522306, -6.073889), entry("ATGOW", 53.488944, -5.842361),
        entry("ENDEQ", 53.445661, -5.5), entry("RULAV", 53.437319, -5.167014, 37000),
        entry("ABGEP", 53.427589, -4.861031, 37000), entry("EHAM", 52.3175, 4.7716, -11, 1)}
end
local CA, DW128, DW129, DW124, ATGOW, ENDEQ, RULAV = 4, 5, 6, 7, 8, 9, 10
local function ende3j()
    return {[CA] = {alt_desc = "+", floor = 650, speed_desc = "-", speed = 210, phase = "climb"},
        [DW128] = {speed_desc = "-", speed = 210, phase = "climb"},
        [DW129] = {speed_desc = "-", speed = 210, phase = "climb"},
        [DW124] = {alt_desc = "-", ceiling = 9000, phase = "climb"},
        [ENDEQ] = {alt_desc = "-", ceiling = 23000, speed_desc = "-", speed = 290, phase = "climb"}}
end

-- 1. The speed the constraints allow now (B747.70.xt.autopilot.lua).
local function autopilot()
    local file = assert(io.open(AP.."B747.70.xt.autopilot.lua"))
    local source = file:read("*a")
    file:close()
    local first = source:find("function B747_update_constraint_speed(fmsO)", 1, true)
    if first == nil then return nil end
    local last = assert(source:find("function B747_getCurrentWayPoint_default(fmsO)", first, true))
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    local geo_first = assert(source:find("function getDistance(lat1, lon1, lat2, lon2)", 1, true))
    local geo_last = assert(source:find("function movePoint(", geo_first, true))
    setfenv(assert(loadstring(source:sub(geo_first, geo_last - 1))), env)()
    setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
    env.B747DR_ap_inVNAVdescent, env.B747DR_vnav_hold_index, env.B747DR_vnav_constraint_speed = 0, 0, -1
    env.simDR_latitude, env.simDR_longitude, env.simDR_groundspeed, env.simDR_ind_airspeed_kts_pilot = 53.44, -6.3, 90, 180
    return env
end
case("the climb's speed now", function()
    local env = autopilot()
    check(env ~= nil, "B747_update_constraint_speed exists")
    local route = eidw()
    env.B747_route_constraints = ende3j()
    local function at(active, held)
        env.B747DR_fmscurrentIndex, env.B747DR_vnav_hold_index = active, held or 0
        env.B747_update_constraint_speed(route)
        return env.B747DR_vnav_constraint_speed
    end
    check(at(2) == 210, "on the runway: 210 (the CA leg, DW128, DW129), got "..tostring(at(2)))
    check(at(CA) == 210, "on the CA leg: 210, got "..tostring(at(CA)))
    check(at(DW129) == 210, "to DW129: 210, got "..tostring(at(DW129)))
    check(at(DW124) == 290, "DW129 passed: ENDEQ's 290, got "..tostring(at(DW124)))
    check(at(DW124, DW129) == 210, "DW129 sequenced early, held: 210, got "..tostring(at(DW124, DW129)))
    check(at(RULAV) == 0, "ENDEQ passed: none, got "..tostring(at(RULAV)))
    env.B747_route_constraints = {}
    check(at(DW129) == 0, "no constraints: none, got "..tostring(at(DW129)))
    env.B747_route_constraints = {[DW129] = {speed_desc = "+", speed = 160, phase = "climb"}}
    check(at(DW128) == 0, "an at or above speed is no limit, got "..tostring(at(DW128)))
end)

-- 2. The climb's targets (vnavspd.lua).
local fms = {
    accelht="1500", thrredht="1500", clbrestspd="---", clbrestalt="-----",
    transpd="250", spdtransalt="10000", transalt="18000",
    clbspd="320", clbmach="780", crzspd="810", costindex="200",
    desspd="270", desspdmach="805", destranspd="240", desspdtransalt="10000",
    desrestspd="---", desrestalt="-----", crzalt="FL370"
}
local function speeds()
    local runtime = setmetatable({
        dofile=function(path) return dofile(AP..path) end, print=function() end,
        getFMSData=function(key) return fms[key] end, is_timer_scheduled=function() return false end,
        run_after_time=function() end, isATEnabled=function() return true end,
        B747_rescale=function(x1, y1, x2, y2, x)
            if x1 == x2 then return y2 end
            local fraction = math.max(0, math.min(1, (x - x1) / (x2 - x1)))
            return y1 + (y2 - y1) * fraction
        end,
        B747DR_airspeed_V2=160, B747DR_airspeed_Vmc=135, B747DR_airspeed_Vmo=365, B747DR_airspeed_Mms=0.92,
        -- manoeuvring speeds at 233 t (VREF30 139): up 219, 1 199, 5 179, 10 159, 20 149, 25 144
        B747DR_airspeed_Vf0=219, B747DR_airspeed_Vf1=199, B747DR_airspeed_Vf5=179, B747DR_airspeed_Vf10=159,
        B747DR_airspeed_Vf20=149, B747DR_airspeed_Vf25=144,
        simDR_flap_ratio_control=0.167, simDR_ind_airspeed_kts_pilot=200,
        simDR_airspeed_mach=0.35, simDR_autopilot_airspeed_is_mach=0,
        simDR_pressureAlt1=4000, simDR_radarAlt1=3800, simDR_onGround=0,
        simDR_altimeter_baro_inHg=29.92, B747BR_cruiseAlt=37000,
        B747DR_ap_inVNAVdescent=0, B747DR_ap_vnav_state=2,
        simDR_autopilot_fms_vnav=1, B747DR_fmscurrentIndex=DW129, simDRTime=100,
        B747DR_efis_baro_std_capt_switch_pos=0, B747DR_efis_baro_std_fo_switch_pos=0,
        simDR_altimeter_baro_inHg_fo=29.92, B747DR_alt_capture_window=200,
        simDR_autopilot_altitude_ft=9000, B747DR_autothrottle_active=1,
        B747DR_engine_TOGA_mode=0, B747DR_ap_lastCommand=0,
        B747DR_ap_flightPhase=1, B747DR_ap_vnav_target_alt=9000,
        B747DR_switchingIASMode=0, B747DR_ap_ias_dial_value=0, B747DR_lastap_dial_airspeed=0,
        simDR_autopilot_airspeed_kts_mach=0, B747DR_vnav_constraint_speed=0
    }, {__index=_G})
    local chunk = assert(loadfile(AP.."B747.70.xt.autopilot.vnavspd.lua"))
    setfenv(chunk, runtime)()
    -- past the acceleration height
    runtime.simDR_onGround, runtime.simDR_pressureAlt1, runtime.simDR_ind_airspeed_kts_pilot = 1, 200, 100
    runtime.B747_update_takeoff_profile()
    runtime.simDR_onGround, runtime.simDR_pressureAlt1, runtime.simDR_ind_airspeed_kts_pilot = 0, 4000, 200
    runtime.B747_update_takeoff_profile()
    return runtime
end
local function climb(runtime)
    runtime.B747_invalidate_vnav_speed("test")
    runtime.B747_vnav_setClimbspeed()
    return runtime.B747DR_ap_ias_dial_value, runtime.simDR_autopilot_airspeed_is_mach
end

case("SPD TRANS below 10,000 ft", function()
    local r = speeds()
    check(climb(r) == 234, "flaps 1, no constraint: the flaps 1 target 234 (Vf0 + 15), got "..tostring(climb(r)))
    r.B747DR_vnav_constraint_speed = 210
    check(climb(r) == 210, "flaps 1, at or below 210 to DW129: 210, got "..tostring(climb(r)))
    r.simDR_flap_ratio_control = 0
    check(climb(r) == 219, "flaps up, at or below 210: the flaps up manoeuvring speed 219, got "..tostring(climb(r)))
    r.B747DR_vnav_constraint_speed = 290
    check(climb(r) == 250, "flaps up, at or below 290: SPD TRANS 250, got "..tostring(climb(r)))
end)
case("ECON above 10,000 ft", function()
    local r = speeds()
    r.simDR_flap_ratio_control, r.simDR_pressureAlt1, r.simDR_ind_airspeed_kts_pilot = 0, 11500, 250
    check(climb(r) == 320, "no constraint: ECON 320, got "..tostring(climb(r)))
    r.B747DR_vnav_constraint_speed = 290
    r.simDR_ind_airspeed_kts_pilot = 285
    check(climb(r) == 290, "at or below 290 to ENDEQ: 290, got "..tostring(climb(r)))
    -- high up, where ECON would be the climb Mach: the constraint's CAS
    r.simDR_pressureAlt1, r.simDR_airspeed_mach, r.simDR_ind_airspeed_kts_pilot = 27000, 0.76, 285
    local dial, mach = climb(r)
    check(dial == 290 and mach == 0, "FL270 at or below 290: 290 kt, not the climb Mach, got "
        ..tostring(dial).." mach "..tostring(mach))
end)
case("a change of the constraint recalculates", function()
    local r = speeds()
    r.simDR_flap_ratio_control = 0.167
    r.B747_vnav_speed()
    check(r.B747DR_ap_ias_dial_value == 234, "first: 234, got "..tostring(r.B747DR_ap_ias_dial_value))
    r.B747DR_vnav_constraint_speed = 210
    r.B747_vnav_speed()
    check(r.B747DR_ap_ias_dial_value == 210, "the constraint appears: 210 at once, got "..tostring(r.B747DR_ap_ias_dial_value))
    r.B747DR_vnav_constraint_speed = 0
    r.B747_vnav_speed()
    check(r.B747DR_ap_ias_dial_value == 234, "it goes: 234 at once, got "..tostring(r.B747DR_ap_ias_dial_value))
end)

if #failures > 0 then
    error(string.format("vnav_speed_constraints_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_speed_constraints_test: %d checks passed", checks))
