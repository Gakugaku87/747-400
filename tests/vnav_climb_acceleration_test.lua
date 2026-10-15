-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The speed-on-pitch climb (VNAV SPD and FLCH SPD) away from its target
-- speed. The production flight director (ap_director_pitch through the
-- 10-sample average of ap_director_pitch_integral,
-- B747.19.xt.hydraulics_override.lua) flies a simple point-mass model:
-- lift and drag from flap-dependent polars, climb thrust falling with air
-- density, the attitude following the flight-director pitch through a
-- delayed second-order loop, and the VSI lagging the flight path by 1.2 s.
-- The flaps 20 polar (CL = 0.827 + 0.064 x alpha, CD = 0.053 + 0.063 x CL^2),
-- the thrust (498 kN at 0.931 kg/m3, x density^1.13; takeoff thrust 1.10 x)
-- and the loop (damping 0.1, 1.1 rad/s, 0.2 s; the attitude hunts +/-1 deg
-- around the flight-director pitch after the 400 ft handoff) were fitted to
-- the force, alpha and flight-director columns of the 2026-10-10 fix-p4-fpm
-- takeoff; the other flap polars are estimates. These are logic regressions
-- on a simple model, not flight-model tests.
--
-- In X-Plane on 2026-10-10 (fix-g-to, P3 9bb688e3, EINN 23, 259.5 t, flaps
-- 20) VNAV raised the target from 156 to 182 kt at the 1,500 ft acceleration
-- height and the speed stayed at 161-169 kt for the 250 s to the 10,000 ft
-- capture: below the target the pitch moved (0.01 + 0.5 x the speed change)/3
-- degrees per update, about 0.01 deg/s at a steady speed, so the flaps stayed
-- at 20 (the kit retracts at Vf10 + 5 = 172 kt).
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function near(actual, expected, tolerance, message)
    checks = checks + 1
    assert(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": "..tostring(actual).." ~= "..tostring(expected).." +/- "..tostring(tolerance))
end
local function slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last-1)
end

-- The flight director from its pitch records to the pitch integral, with the
-- production B747_interpolate_value family it uses.
local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local director_pitchRecord={}", "local trimrate=25")
local model_sources = {
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_interpolate_value("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_interpolate_value(", "function B747_rescale("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")
}

local G = 9.80665
local KT = 0.514444      -- m/s per knot
local FPM = 196.850394   -- ft/min per m/s
local S = 541.2          -- wing area, m2
local DT = 0.0225        -- X-Plane frame period in the kit's runs (about 44 fps)
local function isa_rho(altitude_ft)
    return 1.225*((288.15 - 0.0019812*altitude_ft)/288.15)^4.2559
end
-- CL = cl0 + 0.064 x alpha(deg), CD = cd0 + 0.063 x CL^2
local AERO = {
    [20]={cl0=0.827, cd0=0.053}, [10]={cl0=0.62, cd0=0.042}, [5]={cl0=0.45, cd0=0.034},
    [1]={cl0=0.22, cd0=0.026}, [0]={cl0=0.10, cd0=0.020},
}
local CLB_THRUST_N, CLB_THRUST_RHO = 498e3, 0.9314
-- Vf of the 259.5 t takeoff (laminar/B747/airspeed/Vf*): VNAV targets Vf(next
-- detent) + 15 kt, the kit retracts at Vf(next) + 5 kt
local VF = {[0]=227, [1]=207, [5]=187, [10]=167, [20]=157}
local NEXT_FLAP = {[20]=10, [10]=5, [5]=1, [1]=0}

local function new_director(pitch_deg)
    local env = {
        print=function() end, SIM_PERIOD=DT,
        B747_afds_controls=controls, PITCH_TRANSITION_SAMPLE_INTERVAL_SEC=0.05,
        debug_flight_directors=0, B747DR_ap_autoland=0, B744DR_autolandPitch=0, simDR_touchGround=0,
        B747DR_flap_ratio=0.667, B747DR_flap_lever_detent=0, simDR_radarAlt1=1000,
        simDR_AHARS_pitch_heading_deg_pilot=pitch_deg, simDR_flight_director_pitch=pitch_deg,
        B747DR_airspeed_Vmc=150, B747DR_airspeed_Vmax=250,
        simDR_ind_airspeed_kts_pilot=170, simDR_autopilot_airspeed_kts=170,
        simDR_vvi_fpm_pilot=0, simDR_autopilot_vs_fpm=0,
        B747DR_ap_flightPhase=1, B747DR_autopilot_TOGA_status=0,
        B747DR_alt_capture_window=1000, B747DR_ap_FMA_active_pitch_mode=4,
        simDR_pressureAlt1=1000, simDR_autopilot_altitude_ft=10000,
        simDR_autopilot_hold_altitude_ft=10000, simDR_autopilot_alt_hold_status=0,
        simDR_autopilot_flch_status=0, simDR_autopilot_vs_status=0,
        B747_afds_pitch_target_before_blend=pitch_deg, B747_afds_pitch_target_after_blend=pitch_deg,
        B747DR_flight_director_pitch=pitch_deg,
        simDRTime=1000
    }
    setmetatable(env, {__index=_G})
    for _, source in ipairs(model_sources) do setfenv(assert(loadstring(source)), env)() end
    -- the director has been flying this mode at this attitude
    local source = director_source:gsub("local last_simDR_AHARS_pitch_heading_deg_pilot=0",
        "local last_simDR_AHARS_pitch_heading_deg_pilot="..pitch_deg, 1)
    source = source:gsub("director_pitchRecord%[i%]=0", "director_pitchRecord[i]="..pitch_deg, 1)
    setfenv(assert(loadstring(source)), env)()
    return env
end

-- Flies case from its initial state for case.duration seconds (or to
-- case.stop_ft) and returns the time the speed first came within 2 kt of a
-- raised target, the lowest VS and the highest speed above the target after
-- that, the flap retractions and the end state.
-- loop = {zeta, wn, delay}: the attitude response to the flight-director pitch.
-- case.bank(t) rolls the model (deg; the lift tilts with it) and
-- case.lift_loss(t) is a lift coefficient change (roll spoilers); the director
-- reads the model's angle of attack, true airspeed and bank.
local function fly(case, loop, thrust_factor)
    loop = loop or {0.1, 1.1, 0.2}
    local zeta, wn = loop[1], loop[2]
    local delay_steps = math.floor(loop[3]/DT + 0.5)
    local mass = case.mass
    local altitude = case.altitude
    local rho = isa_rho(altitude)
    local tas = case.ias*KT/math.sqrt(rho/1.225)
    local gamma = math.asin(case.vs/FPM/tas)
    local pitch, pitch_rate = case.pitch, 0
    local vsi = case.vs
    local flaps = case.flaps
    local cl0, cd0 = AERO[flaps].cl0, AERO[flaps].cd0
    local cla, kind = 0.064, 0.063
    if case.polar then cl0, cla, cd0, kind = case.polar.cl0, case.polar.cla, case.polar.cd0, case.polar.k end
    local flap_move
    local thrust_scale = case.takeoff_thrust or 1.0
    local env = new_director(case.pitch)
    env.B747DR_airspeed_Vmc = case.vmc
    env.B747DR_airspeed_Vmax = case.vmax
    env.simDR_autopilot_altitude_ft = case.mcp
    env.simDR_autopilot_hold_altitude_ft = case.mcp
    local commands = {}
    local result = {min_vs=math.huge, overshoot=-math.huge, retractions={}}
    local t = 0
    while t < case.duration do
        t = t + DT
        rho = isa_rho(altitude)
        local ias = tas*math.sqrt(rho/1.225)/KT
        local vs = tas*math.sin(gamma)*FPM
        vsi = vsi + (vs - vsi)*DT/1.2
        local target = case.target(t, flaps, altitude)
        -- pitch = flight path + alpha x cos bank
        local bank = math.rad(case.bank and case.bank(t) or 0)
        env.simDRTime = env.simDRTime + DT
        env.simDR_pressureAlt1 = altitude
        env.simDR_radarAlt1 = altitude - 19
        env.simDR_ind_airspeed_kts_pilot = ias
        env.simDR_vvi_fpm_pilot = vsi
        env.simDR_AHARS_pitch_heading_deg_pilot = pitch
        env.simDR_AHARS_roll_heading_deg_pilot = math.deg(bank)
        env.simDR_alpha_deg = (pitch - math.deg(gamma))/math.cos(bank)
        env.simDR_TAS_mps = tas
        env.simDR_autopilot_airspeed_kts = target
        env.B747DR_alt_capture_window = 200 + math.min(math.abs(vsi), 3000)*800/3000
        commands[#commands + 1] = env.ap_director_pitch_integral()
        local command = commands[math.max(1, #commands - delay_steps)]
        pitch_rate = pitch_rate + (wn*wn*(command - pitch) - 2*zeta*wn*pitch_rate)*DT
        pitch = pitch + pitch_rate*DT
        -- takeoff thrust is reduced to climb thrust over 20 s from the step
        if t > case.step_t then
            thrust_scale = math.max(1.0, thrust_scale - ((case.takeoff_thrust or 1.0) - 1.0)*DT/20)
        end
        local thrust = CLB_THRUST_N*(rho/CLB_THRUST_RHO)^1.13*thrust_scale*(thrust_factor or 1)
        if case.thrust then thrust = case.thrust(t, rho)*(thrust_factor or 1) end
        -- the kit's flap retraction at Vf(next) + 5 kt; the flaps run for 10 s
        if case.retract and not flap_move and NEXT_FLAP[flaps] and ias >= VF[NEXT_FLAP[flaps]] + 5 then
            flap_move = {from=flaps, to=NEXT_FLAP[flaps], start=t}
            flaps = flap_move.to
            result.retractions[#result.retractions + 1] = {flaps=flaps, t=t, altitude=altitude}
        end
        if flap_move then
            local f = math.min(1, (t - flap_move.start)/10)
            cl0 = AERO[flap_move.from].cl0 + (AERO[flap_move.to].cl0 - AERO[flap_move.from].cl0)*f
            cd0 = AERO[flap_move.from].cd0 + (AERO[flap_move.to].cd0 - AERO[flap_move.from].cd0)*f
            if f >= 1 then flap_move = nil end
        end
        local alpha = (pitch - math.deg(gamma))/math.cos(bank)
        local cl = cl0 + cla*alpha + (case.lift_loss and case.lift_loss(t) or 0)
        local cd = cd0 + kind*cl*cl
        local qs = 0.5*rho*tas*tas*S
        local a = math.rad(alpha)
        local dtas = (thrust*math.cos(a) - qs*cd)/mass - G*math.sin(gamma)
        local dgamma = ((qs*cl + thrust*math.sin(a))*math.cos(bank) - mass*G*math.cos(gamma))/(mass*tas)
        tas = tas + dtas*DT
        gamma = gamma + dgamma*DT
        altitude = altitude + tas*math.sin(gamma)*DT/0.3048
        if t > case.step_t then
            result.min_pitch = math.min(result.min_pitch or math.huge, pitch)
            result.max_pitch = math.max(result.max_pitch or -math.huge, pitch)
        end
        if t > case.step_t + 1 then
            result.min_vs = math.min(result.min_vs, vs)
            result.max_vs = math.max(result.max_vs or -math.huge, vs)
            result.min_ias = math.min(result.min_ias or math.huge, ias)
            if t > case.step_t + (case.speed_error_after or 0) then
                result.min_speed_error = math.min(result.min_speed_error or math.huge, ias - target)
            end
            if result.reached then result.overshoot = math.max(result.overshoot, ias - target) end
        end
        if not result.reached and t > case.step_t and ias >= target - 2 then result.reached = t - case.step_t end
        result.ias, result.target, result.altitude, result.pitch, result.flaps = ias, target, altitude, pitch, flaps
        if case.stop_ft and altitude >= case.stop_ft then break end
    end
    result.t = t
    return result
end

-- fix-g-to #1 at t=130 s: 1,150 ft, 168 kt for 156, +2,996 fpm, 11.85 deg,
-- takeoff thrust; at 1,500 ft (8 s) the target rises to 182 kt and the
-- thrust comes back to climb thrust. Vmc + 10 kt = 160 kt.
local function takeoff(retract)
    return {mass=259500, altitude=1150, ias=168, vs=2996, pitch=11.85, flaps=20, vmc=150, vmax=250,
        mcp=10000, takeoff_thrust=1.10, step_t=8, duration=retract and 300 or 120, stop_ft=9300, retract=retract,
        target=function(t, flaps)
            if t < 8 then return 156 end
            if flaps == 0 then return 250 end
            return VF[NEXT_FLAP[flaps]] + 15
        end}
end
-- master-L1 t=598.9: VNAV SPD at 10,000 ft, 300 t, clean, 249 kt; the target
-- rises from 250 to the 326 kt ECON climb speed (master: -2,832 fpm).
local ten_thousand = {mass=300000, altitude=10000, ias=249, vs=1800, pitch=6.0, flaps=0, vmc=200, vmax=365,
    mcp=31000, step_t=2, duration=200,
    target=function(t) return t < 2 and 250 or 326 end}

local function where(name, r)
    return string.format("%s: reached %s s, lowest VS %.0f fpm, overshoot %.1f kt, end %.1f kt for %.0f at %.0f ft",
        name, r.reached and string.format("%.0f", r.reached) or "never", r.min_vs, r.overshoot,
        r.ias, r.target, r.altitude)
end

-- 1. The fix-g-to takeoff with the flaps left at 20: the 182 kt target is
-- reached within 90 s of the acceleration height without the climb dropping
-- below +1,000 fpm. Previous law: 159-161 kt after 120 s.
local r = fly(takeoff(false))
check(r.reached and r.reached <= 90, where("flaps 20, 156 -> 182 kt at 1,500 ft", r))
check(r.min_vs >= 1000, where("flaps 20, 156 -> 182 kt at 1,500 ft (climb kept)", r))
check(r.overshoot <= 3, where("flaps 20, 156 -> 182 kt at 1,500 ft (no overshoot)", r))

-- 2. The same with the kit's flap retraction (Vf(next) + 5 kt): flaps up
-- below 6,500 ft, 250 kt reached without passing 256 kt, the climb never
-- below +800 fpm. Previous law: no retraction before 9,300 ft.
r = fly(takeoff(true))
local up = r.retractions[#r.retractions]
check(up and up.flaps == 0 and up.altitude <= 6500,
    where("takeoff with flap retraction", r).."; flaps up at "..(up and string.format("%d at %.0f ft", up.flaps, up.altitude) or "never"))
check(r.reached and r.overshoot <= 6, where("takeoff with flap retraction (250 kt)", r))
check(r.min_vs >= 800, where("takeoff with flap retraction (climb kept)", r))

-- 3. 250 -> 326 kt at 10,000 ft: reached within 150 s without descending
-- (the climb nearly stops near 300 kt, as climb thrust gives little more
-- there) and not more than 3 kt past it. Previous law: a descent to
-- -282 fpm.
r = fly(ten_thousand)
check(r.reached and r.reached <= 150, where("10,000 ft 250 -> 326 kt", r))
check(r.min_vs >= 0, where("10,000 ft 250 -> 326 kt (no descent)", r))
check(r.overshoot <= 3, where("10,000 ft 250 -> 326 kt (no overshoot)", r))

-- 4. A step climb at altitude with the target above the speed: the
-- 2026-10-10 TST744L step 2 (P3, fix-h2), FL330 -> FL350 at 282 t, M .816
-- (291 kt) and the VNAV climb target M .829 (297 kt, falling with height),
-- clean polar and thrust fitted to that flight above FL250 (M .82:
-- CL = 0.273 + 0.0793 alpha, CD = 0.0264 + 0.043 CL^2; 225 kN level, climb
-- thrust 270 kN reached over the first 30 s). In X-Plane the law pitched
-- down until the 747 descended (-851 fpm, 54 ft lost inside the climb), the
-- climb guard then raised the target at 1 deg/s and the attitude went from
-- 0.8 to 7.4 deg (+3,800 fpm); this model repeats that cycle every 22 s
-- (-803 fpm, 0.3..6.0 deg). Climb thrust gives only about +700 fpm at a
-- steady speed there, so the acceleration has to come slowly: no descent,
-- the attitude kept within 2 deg, the target reached within 120 s.
local function mach_to_ias(mach, altitude_ft)
    local T = 288.15 - 0.0019812*math.min(altitude_ft, 36089)
    local p = 101325*(T/288.15)^5.2559
    local qc = p*((1 + 0.2*mach*mach)^3.5 - 1)
    return 661.47*math.sqrt(5*((qc/101325 + 1)^(1/3.5) - 1))
end
local step_fl330 = {mass=282400, altitude=32998, ias=291.1, vs=-70, pitch=1.84, flaps=0, vmc=230, vmax=365,
    mcp=35000, step_t=2, duration=180, stop_ft=34990,
    polar={cl0=0.273, cla=0.0793, cd0=0.0264, k=0.043},
    thrust=function(t, rho)
        local level, climb = 225e3, 270e3*(rho/0.4135)^0.8
        if t < 2 then return level end
        return level + (climb - level)*math.min(1, (t - 2)/30)
    end,
    target=function(t, flaps, altitude)
        if t < 2 then return 290.4 end
        return mach_to_ias(0.829, altitude)
    end}
r = fly(step_fl330)
check(r.min_vs >= 0, where("FL330 -> FL350, M .829 above M .816 (no descent)", r))
check(r.max_pitch - r.min_pitch <= 2, where("FL330 -> FL350, M .829 above M .816 (attitude within 2 deg)", r)
    ..string.format("; pitch %.2f..%.2f", r.min_pitch, r.max_pitch))
check(r.reached and r.reached <= 120, where("FL330 -> FL350, M .829 above M .816 (target reached)", r))

-- 4b. Thrust lost while a step is still accelerating to its raised target
-- (latched, update_speed_target_acceleration): the 2026-10-10 final-L1 step 1
-- at FL310 (294 t, M .82, 306.7 kt; polar and thrust fitted to it: CL =
-- 0.2406 + 0.0724 x alpha, CD = 0.0181 + 0.0808 x CL^2, 231 kN level, 57 kN
-- more over 7 s), the target 305.9 -> 312.5 kt, MCP FL370 and 25 % of the
-- thrust lost 5 s in, so not even level flight can be held at the speed the
-- acceleration started from. While latched only the minimum safe speed
-- (Vmc + 10 = 221 kt) was a severe underspeed: the climb guard held the
-- aircraft up (+4,862 fpm) until the speed was down to 202 kt, and it stayed
-- at 202-207 kt. 15 kt below the speed the acceleration started from is one
-- too: not below 265 kt, above 285 kt after 15 min (272.9, then 288.1 kt).
local rho_fl310 = isa_rho(31000)
local step_thrust_lost = {mass=294300, altitude=31000, ias=306.7, vs=0, pitch=1.51, flaps=0, vmc=211, vmax=349,
    mcp=37000, step_t=0, duration=900, stop_ft=36990,
    polar={cl0=0.2406, cla=0.0724, cd0=0.0181, k=0.0808},
    thrust=function(t, rho)
        local thrust = 231.3e3
        if t >= 1.4 then thrust = thrust + 57e3*(1 - math.exp(-(t - 1.4)/7)) end
        if t >= 5 then thrust = thrust*(1 - 0.25*math.min(1, (t - 5)/3)) end
        return thrust*(rho/rho_fl310)^0.8
    end,
    target=function(t, flaps, altitude)
        if t < 1.5 then return 305.9 end
        return 312.5 - 0.0069*(altitude - 31000)
    end}
r = fly(step_thrust_lost, {0.28, 0.5, 0.0})
check(r.min_ias >= 265 and r.ias >= 285, where("thrust lost 5 s into a step", r)
    ..string.format("; lowest %.1f kt", r.min_ias))

-- 5. Other pitch loops and 15 % less or more thrust: the targets are still
-- reached, without descending by more than 200 fpm and without passing them
-- by more than 9 kt.
for _, variant in ipairs({
        {"slow pitch loop", {0.5, 0.5, 0.8}, 1.0}, {"oscillatory pitch loop", {0.2, 0.8, 0.5}, 1.0},
        {"fast pitch loop", {0.7, 1.2, 0.2}, 1.0}, {"thrust -15 %", nil, 0.85}, {"thrust +15 %", nil, 1.15}}) do
    for _, c in ipairs({{"takeoff with flap retraction", takeoff(true)}, {"10,000 ft 250 -> 326 kt", ten_thousand}}) do
        r = fly(c[2], variant[2], variant[3])
        local name = c[1]..", "..variant[1]
        check(r.reached and r.min_vs >= -200 and r.overshoot <= 9, where(name, r))
    end
end

-- 6. The pitch step itself (afds_controls.climb_speed_pitch_target).
local f = controls.climb_speed_pitch_target
local CLIMB, LEVEL, DESCENT = controls.VERTICAL_DIRECTION_CLIMB, controls.VERTICAL_DIRECTION_LEVEL,
    controls.VERTICAL_DIRECTION_DESCENT
-- 21 kt slow and not accelerating: 1 kt/s wanted, 0.6 deg/s per kt/s of
-- shortfall, at most 0.5 deg/s, here 0.15 deg in 0.3 s
near(f(10, 0, 0.3, 161, 182, CLIMB, 0), 9.85, 1e-9, "21 kt slow, steady speed")
-- 3 kt slow and steady: 0.15 kt/s wanted, 0.09 deg/s
near(f(10, 0, 0.5, 179, 182, CLIMB, 0), 10 - 0.6*0.15*0.5, 1e-9, "3 kt slow, steady speed")
-- accelerating 1.05 kt/s, inside the 1.0..1.1 kt/s band: held
near(f(10, 0.315, 0.3, 161, 182, CLIMB, 0), 10, 1e-9, "accelerating as wanted")
-- accelerating 1.5 kt/s: up by 0.6 x 0.4 deg/s
near(f(10, 0.45, 0.3, 161, 182, CLIMB, 0), 10 + 0.6*0.4*0.3, 1e-9, "accelerating faster than wanted")
-- decelerating 2 kt/s: down by at most 0.5 deg/s
near(f(10, -0.6, 0.3, 161, 182, CLIMB, 0), 10 - 0.5*0.3, 1e-9, "decelerating, limited to 0.5 deg/s")
-- the attitude is still 0.5 deg above the last target: no further step down,
-- 0.5 deg below it: no step up
near(f(10, 0, 0.3, 161, 182, CLIMB, 0.5), 10, 1e-9, "attitude behind a lower target")
near(f(10, 0.45, 0.3, 161, 182, CLIMB, -0.5), 10, 1e-9, "attitude behind a higher target")
-- 5 kt fast and steady: -0.25 kt/s wanted, up by 0.6 x 0.25 deg/s
near(f(10, 0, 0.3, 255, 250, CLIMB, 0), 10 + 0.6*0.25*0.3, 1e-9, "5 kt fast, steady speed")
-- 5 kt fast and slowing 0.3 kt/s, inside -0.35..-0.25: held; slowing 0.6 kt/s: down
near(f(10, -0.09, 0.3, 255, 250, CLIMB, 0), 10, 1e-9, "5 kt fast, slowing as wanted")
near(f(10, -0.18, 0.3, 255, 250, CLIMB, 0), 10 - 0.6*0.25*0.3, 1e-9, "5 kt fast, slowing faster than wanted")
-- within 2 kt, not climbing, or no speed: the speed law is unchanged (nil)
check(f(10, 0, 0.3, 180.5, 182, CLIMB, 0) == nil, "within 2 kt of the target")
check(f(10, 0, 0.3, 161, 182, LEVEL, 0) == nil, "level (inside the capture window)")
check(f(10, 0, 0.3, 161, 182, DESCENT, 0) == nil, "descending")
check(f(10, 0, 0.3, nil, 182, CLIMB, 0) == nil, "no airspeed")
-- no time since the last update: unchanged
near(f(10, 0, 0, 161, 182, CLIMB, 0), 10, 1e-9, "no elapsed time")
-- the climb floor: 21 kt slow and steady at +2,000 fpm, down at the usual
-- 0.5 deg/s; at +500 fpm at most 0.5 x 0.2 = 0.1 deg/s; at or below
-- +300 fpm, or descending, held; the pitch still goes up when the aircraft
-- accelerates faster than wanted
near(f(10, 0, 0.3, 161, 182, CLIMB, 0, 2000), 10 - 0.5*0.3, 1e-9, "21 kt slow at +2,000 fpm")
near(f(10, 0, 0.3, 161, 182, CLIMB, 0, 500), 10 - 0.1*0.3, 1e-9, "21 kt slow at +500 fpm")
near(f(10, 0, 0.3, 161, 182, CLIMB, 0, 300), 10, 1e-9, "21 kt slow at +300 fpm: held")
near(f(10, 0, 0.3, 161, 182, CLIMB, 0, -500), 10, 1e-9, "21 kt slow, descending: held")
near(f(10, 0.45, 0.3, 161, 182, CLIMB, 0, 100), 10 + 0.6*0.4*0.3, 1e-9, "accelerating faster than wanted at +100 fpm")

-- 7. A step climb that starts in a turn: the 2026-10-10 final-L1 step 1 (P4
-- 0dd3b35d), FL310 -> FL330 at 294 t and M .82 (306.7 kt). The step began at a
-- waypoint where LNAV rolled into a 20 deg bank (the roll spoilers took about
-- 7 % of the lift for 1.5 s), VNAV SPD raised the target to 312.5 kt (falling
-- 0.0069 kt/ft) and the thrust rose from 231 kN by 57 kN over about 20 s.
-- Polar and attitude loop fitted to that climb: CL = 0.2406 + 0.0724 x alpha,
-- CD = 0.0181 + 0.0808 x CL^2 (q from the IAS, as everywhere here), damping
-- 0.28, 0.5 rad/s, no delay. In X-Plane the turn sank the aircraft to -300 fpm
-- and the climb guard raised the target at 1 deg/s for as long as the VSI
-- showed more than 100 fpm down: 7.6 deg, +4,229 fpm and 18 kt lost; the speed
-- law then pitched down to -815 fpm and the guard zoomed again to +4,745 fpm,
-- 24 kt below the target at the level-off (step 2 at FL330 after a 5 deg roll:
-- -725/+4,687 fpm). This model with the guard: -550..+5,031 fpm, 1.2..8.7 deg,
-- down to 280 kt. Held at or above the attitude that flies level at the angle
-- of attack once the VSI shows +100 fpm or less instead: no descent below -200
-- fpm, no zoom above +2,000 fpm, the attitude within 2 deg, no speed lost and
-- the climb going on (-124..+1,112 fpm, 1.5..2.8 deg); with the other pitch
-- loops and 15 % less or more thrust within -200..+2,500 fpm and 2.5 deg, and
-- not more than 5 kt below the speed at the start (-146..+1,977 fpm, 2.2 deg,
-- 303.4 kt).
local rho_fl310 = isa_rho(31000)
local step_in_turn = {mass=294300, altitude=31000, ias=306.7, vs=0, pitch=1.51, flaps=0, vmc=211, vmax=349,
    mcp=33000, step_t=0, duration=120, stop_ft=32990,
    polar={cl0=0.2406, cla=0.0724, cd0=0.0181, k=0.0808},
    thrust=function(t, rho)
        local level = 231.3e3
        if t < 1.4 then return level*(rho/rho_fl310)^0.8 end
        return (level + 57e3*(1 - math.exp(-(t - 1.4)/7)))*(rho/rho_fl310)^0.8
    end,
    bank=function(t)
        local f = math.min(1, t/3.5)
        return 20*f*f*(3 - 2*f)
    end,
    lift_loss=function(t)
        if t > 2 then return 0 end
        return -0.025*math.sin(math.pi*t/2)
    end,
    target=function(t, flaps, altitude)
        if t < 1.5 then return 305.9 end
        return 312.5 - 0.0069*(altitude - 31000)
    end}
local function turn_where(name, r)
    return string.format("%s: VS %.0f..%.0f fpm, pitch %.2f..%.2f, lowest %.1f kt, end %.0f ft %.1f kt for %.1f",
        name, r.min_vs, r.max_vs, r.min_pitch, r.max_pitch, r.min_ias, r.altitude, r.ias, r.target)
end
r = fly(step_in_turn, {0.28, 0.5, 0.0})
check(r.min_vs >= -200, turn_where("step climb in a turn (no descent)", r))
check(r.max_vs <= 2000, turn_where("step climb in a turn (no zoom)", r))
check(r.max_pitch - r.min_pitch <= 2, turn_where("step climb in a turn (attitude within 2 deg)", r))
check(r.min_ias >= 304.7, turn_where("step climb in a turn (no speed lost)", r))
check(r.altitude >= 31500, turn_where("step climb in a turn (climbing)", r))
for _, variant in ipairs({
        {"takeoff pitch loop", {0.1, 1.1, 0.2}}, {"slow pitch loop", {0.5, 0.5, 0.8}},
        {"oscillatory pitch loop", {0.2, 0.8, 0.5}}, {"fast pitch loop", {0.7, 1.2, 0.2}}}) do
    for _, factor in ipairs({0.85, 1.0, 1.15}) do
        r = fly(step_in_turn, variant[2], factor)
        local name = string.format("step climb in a turn, %s, thrust x %.2f", variant[1], factor)
        check(r.min_vs >= -200 and r.max_vs <= 2500 and r.max_pitch - r.min_pitch <= 2.5 and r.min_ias >= 301.7,
            turn_where(name, r))
    end
end

-- 8. The level attitude itself (afds_controls.climb_path_pitch_deg and the
-- climb_path_pitch_deg argument of limit_speed_pitch_target).
local path = controls.climb_path_pitch_deg
-- level: the attitude is the angle of attack, banked alpha x cos bank
near(path(1.5, 252, 0), 1.5, 1e-9, "level attitude, wings level")
near(path(2.0, 252, 20), 2.0*math.cos(math.rad(20)), 1e-9, "level attitude in a 20 deg bank")
check(path(nil, 252, 0) == nil and path(1.5, nil, 0) == nil and path(1.5, 0, 0) == nil,
    "no level attitude without the angle of attack or the airspeed")
local limit = controls.limit_speed_pitch_target
-- at +100 fpm or less on the VSI the target rises to it at 1 deg/s at most;
-- above it a descent on the VSI no longer raises the target
near(limit(1.5, 1.5, CLIMB, -300, 306, 312, 221, 349, 0.3, true, 1.62), 1.62, 1e-9,
    "target raised to the level attitude")
near(limit(1.5, 1.5, CLIMB, -300, 306, 312, 221, 349, 0.3, true, 3.0), 1.8, 1e-9,
    "level attitude approached at 1 deg/s")
near(limit(4.0, 4.0, CLIMB, -300, 306, 312, 221, 349, 0.3, true, 1.62), 4.0, 1e-9,
    "above the level attitude a descent on the VSI does not raise the target")
near(limit(1.0, 2.0, CLIMB, 50, 306, 312, 221, 349, 0.3, true, 2.5), 2.3, 1e-9,
    "+50 fpm below the level attitude: held, then raised at 1 deg/s")
-- climbing at more than +100 fpm (the angle of attack of a hunting attitude
-- would ratchet the target up), in a severe underspeed or in a descent it
-- does nothing; without it the VSI recovery (+1 deg/s below -100 fpm) is
-- unchanged
near(limit(1.0, 2.0, CLIMB, 500, 306, 312, 221, 349, 0.3, true, 1.62), 1.0, 1e-9,
    "climbing at +500 fpm: no level attitude")
near(limit(1.0, 2.0, CLIMB, 50, 215, 312, 221, 349, 0.3, true, 1.62), 1.0, 1e-9,
    "severe underspeed: no level attitude")
near(limit(1.0, 2.0, DESCENT, -500, 306, 300, 221, 349, 0.3, false, 1.62), 1.0, 1e-9,
    "descending: no level attitude")
near(limit(1.5, 1.5, CLIMB, -300, 306, 312, 221, 349, 0.3, true), 1.8, 1e-9,
    "no level attitude: VSI recovery")
-- the director passes the bank: an angle of attack of 2 deg in a 60 deg bank
-- is a level attitude of 1 deg (already flown), wings level 2 deg
local function director_level_target(bank_deg)
    local env = new_director(1.0)
    env.B747DR_airspeed_Vmc, env.B747DR_airspeed_Vmax = 211, 349
    env.simDR_autopilot_altitude_ft, env.simDR_autopilot_hold_altitude_ft = 33000, 33000
    env.simDR_pressureAlt1, env.simDR_radarAlt1 = 31000, 30981
    env.simDR_ind_airspeed_kts_pilot, env.simDR_autopilot_airspeed_kts = 300, 300
    env.simDR_vvi_fpm_pilot, env.B747DR_alt_capture_window = -300, 400
    env.simDR_alpha_deg, env.simDR_TAS_mps, env.simDR_AHARS_roll_heading_deg_pilot = 2.0, 252, bank_deg
    local command
    for _ = 1, 200 do
        env.simDRTime = env.simDRTime + DT
        command = env.ap_director_pitch_integral()
    end
    return command
end
local banked, wings_level = director_level_target(60), director_level_target(0)
check(wings_level > banked + 0.5 and math.abs(banked - 1.0) < 0.2,
    string.format("the director passes the bank: %.2f deg wings level, %.2f deg in a 60 deg bank", wings_level, banked))

-- 9. Climbs that thrust limits (review of the first version of 7, which held
-- +100 fpm instead of level: it climbed on through the thrust-limited ceiling
-- by giving up speed, while accelerating to a raised target - every VNAV
-- step - down to the minimum safe speed, 221 kt here, before 4b). The
-- section 7 polar, MCP FL370, wings level, climb thrust 231 kN + the margin:
-- (a) +15 kN, the target 308 -> 309 kt (not latched): the climb stops at the
-- ceiling on speed (lowest IAS - target after a minute -0.1 kt; +100 fpm: -9.3
-- kt after 30 min); (b) +8 kN, the target 10 kt up (latched): level at the
-- ceiling without losing speed (lowest 306.7 kt, the speed at the start; +100
-- fpm: 295.0 after 15 min and falling); (c) an engine failure 60 s into the
-- section 7 step (75 % thrust): no zoom, not below 287 kt (-371..+1,200 fpm,
-- 289.4 kt; the VSI guard: +4,507 fpm and 273.6 kt; +100 fpm: 285.4 kt).
local function limited(margin, from_kt, to_kt, fail_t, duration)
    return {mass=294300, altitude=31000, ias=306.7, vs=0, pitch=1.51, flaps=0, vmc=211, vmax=349,
        mcp=37000, step_t=0, duration=duration, stop_ft=36990,
        polar={cl0=0.2406, cla=0.0724, cd0=0.0181, k=0.0808},
        thrust=function(t, rho)
            local level = 231.3e3
            local thrust = level*(rho/rho_fl310)^0.8
            if t >= 1.4 then thrust = (level + margin*(1 - math.exp(-(t - 1.4)/7)))*(rho/rho_fl310)^0.8 end
            if fail_t and t >= fail_t then thrust = thrust*(1 - 0.25*math.min(1, (t - fail_t)/3)) end
            return thrust
        end,
        target=function(t, flaps, altitude)
            if t < 1.5 then return from_kt end
            return to_kt - 0.0069*(altitude - 31000)
        end,
        speed_error_after=60}
end
r = fly(limited(15e3, 308.0, 309.0, nil, 1800), {0.28, 0.5, 0.0})
check(r.min_speed_error >= -2, turn_where("thrust-limited ceiling", r)
    ..string.format("; lowest IAS - target %.1f kt", r.min_speed_error))
r = fly(limited(8e3, 306.7, 316.7, nil, 900), {0.28, 0.5, 0.0})
check(r.min_ias >= 305, turn_where("thrust-limited ceiling, accelerating to a raised target", r))
r = fly(limited(57e3, 305.9, 312.5, 60, 900), {0.28, 0.5, 0.0})
check(r.max_vs <= 2000 and r.min_ias >= 287, turn_where("engine failure in a step climb", r))

print("VNAV climb acceleration tests passed: "..checks)
