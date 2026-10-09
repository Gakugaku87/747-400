-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Autoland flare law, touchdown derotation and the flare thrust retard height.
-- Part A checks the pure flare helpers. Part B flies the production
-- B747.autoland.lua from 300 ft RA to 8 s after touchdown against a simple
-- point-mass model (second-order pitch loop, 1.5 s flight-path lag, angle of
-- attack proportional to 1/V^2, deceleration once the autothrottle retards).
-- Part D flies two autolands in one session.
-- These are logic regressions on a simple model, not flight-model tests.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
end
local function near(actual, expected, tolerance, message)
    checks = checks + 1
    assert(math.abs(actual - expected) <= tolerance,
        message..": "..tostring(actual).." is not within "..tolerance.." of "..tostring(expected))
end
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

-- Part A: pure helpers.
equal(afds.FLARE_RETARD_FT, 25, "the flare retards the thrust at 25 ft RA, the EEC SPD cut height")

-- Commanded sink rate: 60*(RA + 12)/5 fpm, never deeper than the sink rate at
-- flare entry and never shallower than 100 fpm.
equal(afds.flare_vspeed_command_fpm(40, -640), -624, "sink command shrinks with height")
equal(afds.flare_vspeed_command_fpm(60, -640), -640, "sink command is not deeper than at flare entry")
equal(afds.flare_vspeed_command_fpm(0, -640), -144, "sink command at touchdown height")
equal(afds.flare_vspeed_command_fpm(-12, -640), -100, "sink command keeps 100 fpm so the aircraft does not float")

-- Pitch target: rate limited to 1.5 deg/s up and 1.0 deg/s down, and kept
-- between base - 0.5 and min(base + 4, 7.5).
local state = {tp=3.0}
near(afds.flare_pitch_target(state, 2.5, 30, 2000, 155, 0, 0.1), 2.9, 1e-9,
    "a climbing aircraft lowers the pitch target at 1.0 deg/s")
for _ = 1, 100 do
    local target = afds.flare_pitch_target(state, 2.5, 30, 2000, 155, 0, 0.1)
    check(target >= 2.0 - 1e-9 and target <= 6.5 + 1e-9, "pitch target stays inside the flare limits: "..target)
end
near(state.tp, 2.0, 1e-9, "the pitch target bottoms out at base - 0.5")
state = {tp=3.0}
near(afds.flare_pitch_target(state, 2.5, 30, -3000, 155, 0, 0.1), 3.15, 1e-9,
    "a sinking aircraft raises the pitch target at 1.5 deg/s")
for _ = 1, 100 do
    local target = afds.flare_pitch_target(state, 2.5, 30, -3000, 155, 0, 0.1)
    check(target >= 2.0 - 1e-9 and target <= 6.5 + 1e-9, "pitch target stays inside the flare limits: "..target)
end
near(state.tp, 6.5, 1e-9, "the pitch target tops out at base + 4")

-- Base pitch: the measured approach pitch, or the current pitch when no
-- steady sample was taken (instead of 0/0).
equal(afds.flare_base_pitch(0, 0, 2.7), 2.7, "no measurement uses the current pitch")
near(afds.flare_base_pitch(22.9, 10, 9), 2.29, 1e-9, "measured approach pitch is the average")

-- Derotation after main gear touchdown: 1.0 deg/s down to -0.5 deg.
near(afds.derotation_pitch_target(3.0, 0.1), 2.9, 1e-9, "derotation lowers the nose at 1.0 deg/s")
near(afds.derotation_pitch_target(-0.45, 0.1), -0.5, 1e-9, "derotation stops at -0.5 deg")

-- Part B: production autoland logic against the point-mass model.
local function load_in(path, runtime)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    setfenv(assert(loadstring(source, "@"..path)), runtime)()
end
local function command_mock()
    return {once=function() end}
end
local function autoland_runtime()
    local runtime = {
        print=function() end,
        find_dataref=function() return 0 end,
        dofile=function(path) return dofile(AP..path) end,
        B747CMD_ap_reset=command_mock(),
        simCMD_autopilot_servos_off=command_mock(),
        B747_set_ap_animation_position=function(current, target) return target end,
        B747_ap_all_cmd_modes_off=function() end,
        isATEnabled=function() return true end,
        B747DR_ap_cmd_L_mode=1, B747DR_ap_cmd_C_mode=1, B747DR_ap_cmd_R_mode=1,
        B747DR_autopilot_nav_status=2, B747DR_autopilot_gs_status=2,
        simDR_autopilot_approach_status=0, B747DR_ap_AFDS_status_annun_pilot=4,
        B747DR_ap_autoland=0, B747DR_ap_active_land=0, B747DR_ap_lastCommand=0,
        B747DR_ap_FMA_active_pitch_mode=2, B747DR_ap_FMA_armed_pitch_mode=3,
        B747DR_ap_FMA_active_roll_mode=3, B747DR_ap_FMA_armed_roll_mode=4,
        B747DR_ap_FMA_autothrottle_mode=3,
        simDR_allThrottle=0.3, simDR_reqHeading=62, simDR_AHARS_heading_deg_pilot=62,
        simDR_AHARS_roll_deg_pilot=0, simDR_rudder=0, simDR_pitch=0,
        simDR_flap_ratio_control=1.0, simDR_autopilot_servos_on=1,
        simDR_onGround=0, simDR_touchGround=0, B744DR_autolandPitch=0
    }
    return setmetatable(runtime, {__index=_G})
end

local KT_FPM = 101.269 -- feet per minute per knot
local DT = 0.05
local GROUND_SECONDS = 8

-- approach: initial vertical speed, airspeed and pitch, and the deceleration
-- once the autothrottle retards (FMA IDLE). model: damping ratio and natural
-- frequency of the closed pitch loop. terrain: the ground at flare start is
-- drop_ft above the touchdown zone and falls to it linearly over drop_m.
-- vvi_noise: the VSI reads +20/-20/0 fpm off in turn, so the steady-descent
-- pitch sampler never takes a sample. runtime: an autoland already loaded and
-- flown (a later landing in the same session); the clock carries on from it.
local function fly(label, approach, model, terrain, vvi_noise, flare_limit_s, runtime)
    local r = runtime
    if r == nil then
        r = autoland_runtime()
        load_in(AP.."B747.autoland.lua", r)
    end
    local start_time = rawget(r, "simDRTime") or 1000
    local zeta, wn = model[1], model[2]
    local ias, pitch, q, vs = approach.ias, approach.pitch, 0, approach.vs
    local gamma = math.deg(math.asin(approach.vs/(approach.ias*KT_FPM)))
    local alpha0 = approach.pitch - gamma
    local drop_ft = terrain and terrain.drop_ft or 0
    local height = 300 + drop_ft -- above the touchdown zone
    local distance, drop_start = 0, nil
    local function ground_at(position)
        if drop_start == nil or terrain == nil then return drop_ft end
        return drop_ft*math.max(0, 1 - (position - drop_start)/terrain.drop_m)
    end
    local retarded, seen_below_25, retard_checked = false, false, false
    local flare_time, base, touchdown_time, touchdown_vs, touchdown_pitch
    local previous_target, ground_steps = nil, 0
    for step = 1, 2400 do
        local time = start_time + step*DT
        local ra = height - ground_at(distance)
        if touchdown_time then ra = 0 end
        r.simDRTime = time
        r.simDR_radarAlt1 = ra
        r.simDR_AHARS_pitch_heading_deg_pilot = pitch
        r.simDR_ind_airspeed_kts_pilot = ias
        r.simDR_vh_ind_fpm = vs
        r.simDR_pitch_rate_deg_sec = q
        r.simDR_vvi_fpm_pilot = vs
        if vvi_noise then r.simDR_vvi_fpm_pilot = vs + ({20, -20, 0})[step % 3 + 1] end
        r.simDR_onGround = touchdown_time and 1 or 0
        r.simDR_touchGround = r.simDR_onGround
        r.runAutoland()
        local target = r.B744DR_autolandPitch
        local where = label.." at RA "..string.format("%.1f", ra)

        if r.B747DR_ap_autoland == 1 then
            check(target == target, where..": autoland pitch target is a number")
        end
        -- The thrust stays in SPD until 25 ft and retards below it.
        if not touchdown_time then
            if ra >= 25 and not seen_below_25 then
                check(r.B747DR_ap_FMA_autothrottle_mode ~= 2, where..": FMA IDLE before 25 ft")
            end
            if ra < 25 then seen_below_25 = true end
            if ra < 24.5 and not retard_checked then
                retard_checked = true
                equal(r.B747DR_ap_FMA_autothrottle_mode, 2, where..": FMA IDLE below 25 ft")
            end
        end
        if r.B747DR_ap_FMA_autothrottle_mode == 2 then retarded = true end

        if flare_time == nil and r.B747DR_ap_FMA_active_pitch_mode == 3 then
            flare_time = time
            base = target -- the measured approach pitch written above 50 ft
            drop_start = distance
        end
        if flare_time and not touchdown_time then
            check(target <= math.min(base + 4, 7.5) + 1e-9, where..": flare target "..target.." above its limit")
            check(target >= base - 0.5 - 1e-9, where..": flare target "..target.." lowered the nose before main gear touchdown")
            check(vs < -50, where..": aircraft floated, VS "..vs)
        end
        if touchdown_time then
            ground_steps = ground_steps + 1
            if ground_steps == 1 then
                near(target, touchdown_pitch, 0.3, where..": derotation starts from the touchdown pitch")
            else
                check(previous_target - target <= 1.0*DT + 1e-6,
                    where..": derotation faster than 1 deg/s ("..previous_target.." -> "..target..")")
            end
            if ground_steps >= GROUND_SECONDS/DT then
                near(target, -0.5, 1e-6, label..": derotation ends at -0.5 deg")
                return r
            end
        end
        previous_target = target

        -- G/S holds the approach attitude until AUTOLAND engages below 100 ft.
        local commanded = approach.pitch
        if r.B747DR_ap_autoland == 1 then commanded = target end
        q = q + (wn*wn*(commanded - pitch) - 2*zeta*wn*q)*DT
        pitch = pitch + q*DT
        if not touchdown_time then
            local alpha = alpha0*(approach.ias/ias)^2
            gamma = gamma + ((pitch - alpha) - gamma)/1.5*DT
            vs = ias*KT_FPM*math.sin(math.rad(gamma))
            height = height + vs/60*DT
        end
        distance = distance + ias*0.5144*DT
        if retarded then ias = ias - approach.decel*DT end
        if not touchdown_time and height - ground_at(distance) <= 0 then
            touchdown_time, touchdown_vs, touchdown_pitch = time, vs, pitch
            vs = 0
            check(flare_time ~= nil, label..": touchdown without a flare")
            check(touchdown_vs >= -250 and touchdown_vs <= -80,
                label..": touchdown VS "..string.format("%.0f", touchdown_vs).." fpm outside -250..-80")
            check(touchdown_time - flare_time <= flare_limit_s,
                label..": FLARE to touchdown took "..string.format("%.1f", touchdown_time - flare_time).." s")
        end
    end
    check(false, label..": no touchdown within 120 s")
end

local approaches = {
    {name="-640 fpm/155 kt", vs=-640, ias=155, pitch=2.2, decel=0.9},
    {name="-650 fpm/153 kt", vs=-650, ias=153, pitch=2.7, decel=0.9},
    {name="-800 fpm/150 kt", vs=-800, ias=150, pitch=2.5, decel=1.2},
    {name="-500 fpm/160 kt", vs=-500, ias=160, pitch=1.8, decel=0.6}
}
local models = {{0.2, 1.1}, {0.5, 2.0}}
for _, model in ipairs(models) do
    local model_name = " zeta "..model[1].." wn "..model[2]
    for _, approach in ipairs(approaches) do
        fly(approach.name..model_name, approach, model, nil, false, 10)
        fly(approach.name..model_name.." 24 ft terrain", approach, model,
            {drop_ft=24, drop_m=300}, false, 11)
    end
end
fly("VSI noise, no steady sample", approaches[1], models[1], nil, true, 10)

-- Part D: a second autoland in the same session. The first rollout ends below
-- 65 kt (AUTOLAND and the autopilots off), and nothing on the ground resets
-- active_land, so the next approach must start a new flare instead of flying
-- the -0.5 deg derotation target of the first landing from 100 ft.
local session = fly("first landing of the session", approaches[1], models[1], nil, false, 10)
session.simDRTime = session.simDRTime + DT
session.simDR_ind_airspeed_kts_pilot = 60
session.runAutoland()
equal(session.B747DR_ap_autoland, 0, "AUTOLAND ends below 65 kt")
-- the next flight: G/S captured and LAND 3 again on the approach
session.B747DR_ap_FMA_active_pitch_mode, session.B747DR_ap_FMA_armed_pitch_mode = 2, 3
session.B747DR_ap_FMA_active_roll_mode, session.B747DR_ap_FMA_armed_roll_mode = 3, 4
session.B747DR_ap_FMA_autothrottle_mode = 3
fly("second landing of the session", approaches[1], models[1], nil, false, 10, session)

print("Autoland flare regression tests passed: "..checks)
