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
    local first = source:find("local VNAV_CONSTRAINT_DECEL_KT_PER_SEC", 1, true)
        or source:find("function B747_update_constraint_speed(fmsO)", 1, true)
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

-- 3. The descent (EHAM LAMS2A, ILS 18R via SUG1D): a STAR's or an approach's at or below (or at) speed
-- holds from its fix on, and before it from where VNAV has to start slowing to have it at the fix -
-- (IAS - speed) at 0.5 kt/s (the 747 slowed 0.6 kt/s on its path, idle, the descent shallowed) at the
-- ground speed, plus 1 nm. The kit's flights passed NIRSI (at or below 220 kt) at 233 kt.
local function eham()
    return {entry("EIDW", 53.4213, -6.2703, 242, 1), entry("LAMSO", 52.732889, 2.994361, 21438),
        entry("ETPOS", 52.585122, 3.414178, 16752), entry("SUGOL", 52.525511, 3.96735, 11315),
        entry("NETOM", 52.422444, 4.387917, 7849), entry("NIRSI", 52.583878, 4.513372, 5563),
        entry("AM607", 52.583889, 4.646889, 4272), entry("AM608", 52.539417, 4.728139, 3400),
        entry("AM621", 52.462694, 4.721111, 2000), entry("AM622", 52.426722, 4.717806, 1310),
        entry("RW18R", 52.360258, 4.711725, 37), entry("EHAM", 52.3175, 4.7716, -11, 1)}
end
local SUGOL, NETOM, NIRSI, AM607, AM622 = 4, 5, 6, 7, 10
local function sug1d()
    return {[2] = {alt_desc = "-", ceiling = 23000, phase = "descent"},
        [SUGOL] = {alt_desc = "B", floor = 10000, ceiling = 14000, phase = "descent"},
        [NETOM] = {alt_desc = "+", floor = 7000, speed_desc = "-", speed = 250, phase = "descent"},
        [NIRSI] = {alt_desc = "+", floor = 5500, speed_desc = "-", speed = 220, phase = "descent"},
        [AM622] = {alt_desc = "H", floor = 1310, speed_desc = "+", speed = 160, phase = "descent"}}
end
case("the descent's speed now", function()
    local env = autopilot()
    local route = eham()
    env.B747_route_constraints = sug1d()
    env.B747DR_ap_inVNAVdescent = 1
    -- the aircraft dist_nm before the fix on the leg to it, at ias kt and 260 kt over the ground
    local function at(active, dist_nm, ias, held)
        local fix, from = route[active], route[active - 1]
        local d = env.getDistance(from[5], from[6], fix[5], fix[6])
        local f = dist_nm / d
        env.simDR_latitude = fix[5] + (from[5] - fix[5]) * f
        env.simDR_longitude = fix[6] + (from[6] - fix[6]) * f
        env.simDR_ind_airspeed_kts_pilot, env.simDR_groundspeed = ias, 260 / 1.94384
        env.B747DR_fmscurrentIndex, env.B747DR_vnav_hold_index = active, held or 0
        env.B747_update_constraint_speed(route)
        return env.B747DR_vnav_constraint_speed
    end
    -- NETOM, at or below 250: from (260 - 250) / 0.5 s at 260 kt + 1 nm = 2.4 nm
    check(at(NETOM, 10, 260) == 0, "10 nm before NETOM at 260 kt: none yet, got "..tostring(at(NETOM, 10, 260)))
    check(at(NETOM, 2, 260) == 250, "2 nm before NETOM at 260 kt: 250, got "..tostring(at(NETOM, 2, 260)))
    -- NIRSI, at or below 220: from (248 - 220) / 0.5 s at 260 kt + 1 nm = 5.0 nm; NETOM's 250 meanwhile
    check(at(NIRSI, 12, 248) == 250, "12 nm before NIRSI, NETOM passed: 250, got "..tostring(at(NIRSI, 12, 248)))
    check(at(NIRSI, 4.5, 248) == 220, "4.5 nm before NIRSI at 248 kt: 220, got "..tostring(at(NIRSI, 4.5, 248)))
    -- slowing, the distance it needs shrinks below the distance left: the deceleration stays begun
    check(at(NIRSI, 4.3, 232) == 220, "4.3 nm before NIRSI, slowed to 232 kt: still 220, got "
        ..tostring(at(NIRSI, 4.3, 232)))
    check(at(AM607, 8, 222) == 220, "NIRSI passed: 220 on, got "..tostring(at(AM607, 8, 222)))
    check(at(AM607, 3, 225, NIRSI) == 220, "NIRSI held: 220, got "..tostring(at(AM607, 3, 225, NIRSI)))
    -- AM622's at or above 160 is the crew's: still 220
    check(at(AM622, 1, 180) == 220, "before AM622 (at or above 160): 220, got "..tostring(at(AM622, 1, 180)))
    -- the climb takes no descent constraint
    env.B747DR_ap_inVNAVdescent = 0
    check(at(NIRSI, 2, 248) == 0, "climbing: none, got "..tostring(at(NIRSI, 2, 248)))
end)
case("the descent's targets", function()
    local r = speeds()
    r.B747DR_ap_inVNAVdescent, r.simDR_flap_ratio_control = 1, 0
    -- below 10,000 ft: SPD TRANS 240, or NIRSI's 220
    r.simDR_pressureAlt1, r.simDR_ind_airspeed_kts_pilot = 6000, 238
    r.des_aptres_setSpd()
    check(r.B747DR_ap_ias_dial_value == 240, "below 10,000 ft: 240, got "..tostring(r.B747DR_ap_ias_dial_value))
    r.B747DR_vnav_constraint_speed = 220
    r.des_aptres_setSpd()
    check(r.B747DR_ap_ias_dial_value == 220, "at or below 220: 220, got "..tostring(r.B747DR_ap_ias_dial_value))
    -- above 10,000 ft: ECON 270, or a STAR's 250
    r.B747DR_vnav_constraint_speed = 0
    r.simDR_pressureAlt1, r.simDR_ind_airspeed_kts_pilot, r.B747DR_ap_ias_dial_value = 14000, 268, 270
    r.des_src_setSpd()
    check(r.B747DR_ap_ias_dial_value == 270, "above 10,000 ft: ECON 270, got "..tostring(r.B747DR_ap_ias_dial_value))
    r.B747DR_vnav_constraint_speed = 250
    r.des_src_setSpd()
    check(r.B747DR_ap_ias_dial_value == 250, "at or below 250: 250 at once, got "..tostring(r.B747DR_ap_ias_dial_value))
    -- in the Mach part of the descent a constraint ahead turns it to the constraint's CAS
    r.B747DR_vnav_constraint_speed = 0
    r.simDR_pressureAlt1, r.simDR_airspeed_mach, r.simDR_ind_airspeed_kts_pilot = 28000, 0.81, 300
    r.simDR_autopilot_airspeed_is_mach = 1
    r.des_src_setSpd()
    check(r.simDR_autopilot_airspeed_is_mach == 1, "FL280 at M.81: the descent Mach")
    r.B747DR_vnav_constraint_speed = 280
    r.des_src_setSpd()
    check(r.simDR_autopilot_airspeed_is_mach == 0 and r.B747DR_ap_ias_dial_value == 280,
        "FL280 at 300 kt, at or below 280 ahead: 280 kt, got "..tostring(r.B747DR_ap_ias_dial_value)
        .." mach "..tostring(r.simDR_autopilot_airspeed_is_mach))
    -- slowed below it at the next recalculation, still Mach above the descent Mach: the constraint's CAS
    -- stays (it went back to the descent Mach)
    r.simDR_pressureAlt1, r.simDR_airspeed_mach, r.simDR_ind_airspeed_kts_pilot = 30000, 0.82, 276
    r.des_src_setSpd()
    check(r.simDR_autopilot_airspeed_is_mach == 0 and r.B747DR_ap_ias_dial_value <= 280,
        "FL300 at M.82 and 276 kt, at or below 280: CAS, got "..tostring(r.B747DR_ap_ias_dial_value)
        .." mach "..tostring(r.simDR_autopilot_airspeed_is_mach))
    -- with flaps out, never below their manoeuvring speed
    r.simDR_pressureAlt1, r.simDR_ind_airspeed_kts_pilot, r.simDR_airspeed_mach = 4000, 190, 0.3
    r.simDR_flap_ratio_control, r.B747DR_vnav_constraint_speed = 0.25, 160
    r.des_aptres_setSpd()
    check(r.B747DR_ap_ias_dial_value == 179, "flaps 5, at or below 160: flaps 5's 179, got "
        ..tostring(r.B747DR_ap_ias_dial_value))
end)

if #failures > 0 then
    error(string.format("vnav_speed_constraints_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_speed_constraints_test: %d checks passed", checks))
