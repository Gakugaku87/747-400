-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Autoland flare law, touchdown derotation and the flare thrust retard height.
-- Part A checks the pure flare helpers. Part B flies the production
-- B747.autoland.lua from 300 ft RA to 8 s after touchdown against a
-- point-mass model fitted to the X-Plane circuits of 2026-10-10 (forces,
-- angle of attack and flight-director columns of the kit): flaps 30
-- polar, ground effect, thrust spooling down after the retard, the VSI
-- lagging the flight path, and the attitude following the autoland target
-- through the lightly damped, delayed AFDS pitch loop. Part D flies two
-- autolands in one session. These are regressions on a fitted model, not
-- flight-model tests.
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
equal(afds.FLARE_HEIGHT_FT, 43, "FLARE engages at 43 ft RA")

-- Commanded sink rate: 60*(RA + 20)/5.5 fpm, never deeper than the sink rate
-- at flare entry and never shallower than 60 fpm.
near(afds.flare_vspeed_command_fpm(20, -700), -60*40/5.5, 1e-9, "sink command shrinks with height")
equal(afds.flare_vspeed_command_fpm(60, -640), -640, "sink command is not deeper than at flare entry")
near(afds.flare_vspeed_command_fpm(0, -640), -60*20/5.5, 1e-9, "sink command at touchdown height (-218 fpm)")
equal(afds.flare_vspeed_command_fpm(-20, -640), -60, "sink command keeps 60 fpm so the aircraft does not float")

-- Pitch target: rate limited to 1.3 deg/s up and down, and kept between
-- base - 0.5 and min(base + 3.5, 7.5).
local state = {tp=3.0}
near(afds.flare_pitch_target(state, 2.5, 30, 2000, 155, 0, 0.1), 2.87, 1e-9,
    "a climbing aircraft lowers the pitch target at 1.3 deg/s")
for _ = 1, 100 do
    local target = afds.flare_pitch_target(state, 2.5, 30, 2000, 155, 0, 0.1)
    check(target >= 2.0 - 1e-9 and target <= 6.0 + 1e-9, "pitch target stays inside the flare limits: "..target)
end
near(state.tp, 2.0, 1e-9, "the pitch target bottoms out at base - 0.5")
state = {tp=3.0}
near(afds.flare_pitch_target(state, 2.5, 30, -3000, 155, 0, 0.1), 3.13, 1e-9,
    "a sinking aircraft raises the pitch target at 1.3 deg/s")
for _ = 1, 100 do
    local target = afds.flare_pitch_target(state, 2.5, 30, -3000, 155, 0, 0.1)
    check(target >= 2.0 - 1e-9 and target <= 6.0 + 1e-9, "pitch target stays inside the flare limits: "..target)
end
near(state.tp, 6.0, 1e-9, "the pitch target tops out at base + 3.5")
-- The pitch rate damps the target: 2.4 s x the pitch rate. The raw targets
-- are 2.33 deg without and 2.0 deg (the lower limit) with 0.5 deg/s here, both
-- within the 0.13 deg the rate limit allows in 0.1 s from 2.4 deg.
local a, b = {tp=2.4, entry_vs=-600, trim=0}, {tp=2.4, entry_vs=-600, trim=0}
local still = afds.flare_pitch_target(a, 2.5, 30, -500, 155, 0, 0.1)
local rising = afds.flare_pitch_target(b, 2.5, 30, -500, 155, 0.5, 0.1)
near(still, 2.332, 0.001, "pitch target without pitch rate")
check(rising < still, "a pitch rate of 0.5 deg/s lowers the pitch target: "..rising.." vs "..still)

-- A sink rate of 0 taken at flare entry is not one: XTLua gave start_flare 0 for its
-- first read of vh_ind_fpm in X-Plane on 2026-10-10, which held the command at
-- -100 fpm from 48 ft. The first descending sample replaces it.
state = {tp=2.2, entry_vs=0, trim=0}
afds.flare_pitch_target(state, 2.2, 42, 0, 153, 0, 0.05)
equal(state.entry_vs, nil, "a 0 fpm sink rate is not kept as the flare entry")
afds.flare_pitch_target(state, 2.2, 41, -630, 153, 0, 0.05)
equal(state.entry_vs, -630, "the first descending sample is the flare entry")
afds.flare_pitch_target(state, 2.2, 30, -600, 153, 0, 0.05)
equal(state.entry_vs, -630, "the flare entry then stays")
near(afds.flare_vspeed_command_fpm(30, state.entry_vs), -60*50/5.5, 1e-9, "so the command follows the height profile")

-- Base pitch: the measured approach pitch, or the current pitch when no
-- steady sample was taken (instead of 0/0).
equal(afds.flare_base_pitch(0, 0, 2.7), 2.7, "no measurement uses the current pitch")
near(afds.flare_base_pitch(22.9, 10, 9), 2.29, 1e-9, "measured approach pitch is the average")

-- Derotation after main gear touchdown: 1.0 deg/s down to -0.5 deg.
near(afds.derotation_pitch_target(3.0, 0.1), 2.9, 1e-9, "derotation lowers the nose at 1.0 deg/s")
near(afds.derotation_pitch_target(-0.45, 0.1), -0.5, 1e-9, "derotation stops at -0.5 deg")

-- Part B: production autoland logic against the fitted point-mass model.
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

-- The model, fitted to the kit's 10 Hz recording of the fix-f circuit
-- (2026-10-10, EINN 06, 257 t, flaps 30, 152.7 kt):
-- - free-air polar CL = 0.878 + 0.0651 alpha, CD = 0.0835 + 0.0659 CL^2
--   (all flaps 30 samples above 300 ft RA);
-- - ground effect: lift x (1 + 0.20/(1 + RA/18)) and drag -0.045/(1 + RA/15)
--   (1.006 at 275 ft, 1.06 at 42 ft, 1.11 at 15 ft, 1.16 at 3 ft);
-- - X-Plane's alpha is pitch minus flight path minus 0.15 deg, and a pitch
--   rate costs 0.0084 of lift coefficient per deg/s (elevator download);
-- - approach thrust trimmed for the glide, spooling to an 85 kN idle with a
--   2.6 s time constant from 0.8 s after the A/T retard (224 -> 92 kN);
-- - the VSI lagging the flight-path vertical speed by 1.2 s;
-- - the attitude following the autoland target through a second-order loop
--   with a delay: damping 0.15, 0.8 rad/s, 0.8 s, with ground effect x 0.8,
--   fitted to four P3 landings, and three other loops.
-- At EINN 06 the ground under the flare falls about 25 ft over 600 m to the
-- touchdown zone (radio altitude against the flight-path vertical speed),
-- so the flare starts some 25 ft higher above the touchdown zone than its
-- radio altitude says.
local G, KT, FPM, S, RHO = 9.80665, 0.514444, 196.850394, 541.2, 1.225
local CL0, CLA, CD0, KIND = 0.878, 0.0651, 0.0835, 0.0659
local ALPHA_OFFSET, CL_Q = -0.15, -0.0084
local DT = 0.02
local GROUND_SECONDS = 8

-- approach: mass (kg), ias (kt), glide slope (deg), terrain {drop_ft, drop_m}
-- under the flare. model: zeta, wn (rad/s), delay (s), ge (ground effect
-- scale). vvi_noise: the VSI reads +20/-20/0 fpm off in turn, so the
-- steady-descent pitch sampler never takes a sample. runtime: an autoland
-- already loaded and flown (a later landing in the same session).
-- vy_zero_at_flare_entry: the vertical speed reads 0 until FLARE has engaged,
-- as XTLua gave start_flare in X-Plane on 2026-10-10 (a dataref's first read).
-- input_noise(step, time): m/s and deg/s added to the flare law's inputs, the
-- flight-path vertical speed (local_vy) and the pitch rate (Q).
-- Returns the runtime and the landing figures.
local function fly(label, approach, model, vvi_noise, runtime, vy_zero_at_flare_entry, input_noise)
    local r = runtime
    if r == nil then
        r = autoland_runtime()
        load_in(AP.."B747.autoland.lua", r)
    end
    local start_time = rawget(r, "simDRTime") or 1000
    local zeta, wn = model.zeta, model.wn
    local delay_steps = math.floor(model.delay/DT + 0.5)
    local ge_a = 0.20*model.ge
    local function ge_lift(h) return 1 + ge_a/(1 + math.max(h, 0)/18) end
    local function ge_drag(h) return -0.045/(1 + math.max(h, 0)/15) end
    local mass = approach.mass
    local W = mass*G
    local V = approach.ias*KT
    local gamma = -math.rad(approach.slope)
    local drop_ft = approach.drop_ft or 0
    local drop_m = approach.drop_m or 600
    local x, x_flare = 0, nil
    local function ground(position)
        if x_flare == nil then return drop_ft end
        return drop_ft*math.max(0, 1 - (position - x_flare)/drop_m)
    end
    local height = 300 + drop_ft -- above the touchdown zone
    -- trim for the glide: alpha (deg) for the lift with the thrust's share,
    -- then the thrust for a steady speed
    local function trim_alpha(ra, vel, gam, thrust)
        local qS = 0.5*RHO*vel*vel*S
        local alpha = 5
        for _ = 1, 4 do
            local need = (W*math.cos(gam) - thrust*math.sin(math.rad(alpha)))/(qS*ge_lift(ra))
            alpha = (need - CL0)/CLA - ALPHA_OFFSET
        end
        return alpha
    end
    local thrust = 230e3
    local alpha = trim_alpha(300, V, gamma, thrust)
    for _ = 1, 3 do
        local qS = 0.5*RHO*V*V*S
        local cl = CL0 + CLA*(alpha + ALPHA_OFFSET)
        thrust = (qS*(CD0 + KIND*cl*cl + ge_drag(300)) + W*math.sin(gamma))/math.cos(math.rad(alpha))
        alpha = trim_alpha(300, V, gamma, thrust)
    end
    local pitch = alpha + math.deg(gamma)
    local q = 0
    local vs = V*math.sin(gamma)*FPM
    local vsi = vs
    local commands = {}
    local retard_time
    local result = {float_s=0, max_vs=-math.huge}
    local retard_checked, seen_below_25 = false, false
    local flare_time, base, touchdown_time, touchdown_pitch
    local previous_target, ground_steps = nil, 0
    for step = 1, 6000 do
        local time = start_time + step*DT
        local ra = height - ground(x)
        if touchdown_time then ra = 0 end
        r.simDRTime = time
        r.simDR_radarAlt1 = math.max(ra, 0)
        r.simDR_AHARS_pitch_heading_deg_pilot = pitch
        r.simDR_ind_airspeed_kts_pilot = V/KT
        vsi = vsi + (vs - vsi)*DT/1.2
        r.simDR_vh_ind_fpm = vsi
        r.simDR_local_vy = vs/FPM
        if vy_zero_at_flare_entry and flare_time == nil then r.simDR_vh_ind_fpm, r.simDR_local_vy = 0, 0 end
        r.simDR_pitch_rate_deg_sec = q
        if input_noise then
            local dvy, dq = input_noise(step, time)
            r.simDR_local_vy = r.simDR_local_vy + dvy
            r.simDR_pitch_rate_deg_sec = q + dq
        end
        r.simDR_vvi_fpm_pilot = vsi
        if vvi_noise then r.simDR_vvi_fpm_pilot = vsi + ({20, -20, 0})[step % 3 + 1] end
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
        if not retard_time and r.B747DR_ap_FMA_autothrottle_mode == 2 then retard_time = time end

        if flare_time == nil and r.B747DR_ap_FMA_active_pitch_mode == 3 then
            flare_time, x_flare = time, x
            base = target -- the measured approach pitch written above the flare height
            result.flare_ra = ra
        end
        if flare_time and not touchdown_time then
            check(target <= math.min(base + 3.5, 7.5) + 1e-9, where..": flare target "..target.." above its limit")
            check(target >= base - 0.5 - 1e-9, where..": flare target "..target.." lowered the nose before main gear touchdown")
            if vsi >= -100 and ra > 5 then result.float_s = result.float_s + DT end
            result.max_vs = math.max(result.max_vs, vs)
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
                return r, result
            end
        end
        previous_target = target

        -- G/S holds the glide (the trim attitude for it) until AUTOLAND
        -- engages below 100 ft; then the attitude follows the autoland target.
        local command = trim_alpha(ra, V, -math.rad(approach.slope), thrust) - approach.slope
        if r.B747DR_ap_autoland == 1 then command = target end
        commands[#commands + 1] = command
        local delayed = commands[math.max(1, #commands - delay_steps)]
        q = q + (wn*wn*(delayed - pitch) - 2*zeta*wn*q)*DT
        pitch = pitch + q*DT
        if retard_time and time > retard_time + 0.8 then thrust = thrust + (85e3 - thrust)*DT/2.6 end
        if not touchdown_time then
            alpha = pitch - math.deg(gamma)
            local qS = 0.5*RHO*V*V*S
            local cl = CL0 + CLA*(alpha + ALPHA_OFFSET)
            local lift = qS*(cl*ge_lift(ra) + CL_Q*q)
            local drag = qS*(CD0 + KIND*cl*cl + ge_drag(ra))
            local a = math.rad(alpha)
            V = V + ((thrust*math.cos(a) - drag)/mass - G*math.sin(gamma))*DT
            gamma = gamma + ((lift + thrust*math.sin(a) - W*math.cos(gamma))/(mass*V))*DT
            vs = V*math.sin(gamma)*FPM
            height = height + vs/60*DT
        end
        x = x + V*math.cos(gamma)*DT
        if not touchdown_time and height - ground(x) <= 0 then
            touchdown_time, touchdown_pitch = time, pitch
            check(flare_time ~= nil, label..": touchdown without a flare")
            result.td_vsi, result.td_vs = vsi, vs
            result.flare_s = touchdown_time - (flare_time or touchdown_time)
            result.td_m = x - (x_flare or x)
            vs = 0
        end
    end
    check(false, label..": no touchdown within 120 s")
end

-- The plan's criteria for both landings of a circuit, as the flight-test kit
-- measures them: touchdown VSI -300 fpm or less, float (VSI at or above
-- -100 fpm above 5 ft RA) 0.5 s or less, FLARE to touchdown 11 s or less, and
-- touchdown within 1,000 m of the threshold (here 900 m from the FLARE
-- point, which is about at the threshold at EINN 06). Not a skim either: the
-- VSI at touchdown -50 fpm or more and no climb in the flare.
local function judge(label, result, limits)
    limits = limits or {}
    local text = string.format("%s: TD VSI %.0f (flight path %.0f) fpm, float %.2f s, FLARE->TD %.1f s, %.0f m",
        label, result.td_vsi, result.td_vs, result.float_s, result.flare_s, result.td_m)
    check(result.td_vsi >= (limits.vsi or -300) and result.td_vsi <= -50, text.." (touchdown VSI)")
    check(result.float_s <= 0.5, text.." (float)")
    check(result.flare_s <= (limits.flare_s or 11), text.." (FLARE to touchdown)")
    check(result.td_m <= (limits.td_m or 900), text.." (touchdown distance)")
    check(result.max_vs < 0, text.." (climbed in the flare: "..string.format("%.0f", result.max_vs).." fpm)")
end

local approaches = {
    {name="257 t/152.7 kt EINN 06 ground", mass=257000, ias=152.7, slope=3.0, drop_ft=25, drop_m=600},
    {name="300 t/158 kt EINN 06 ground", mass=300000, ias=158, slope=3.0, drop_ft=25, drop_m=600},
    {name="220 t/145 kt EINN 06 ground", mass=220000, ias=145, slope=3.0, drop_ft=25, drop_m=600},
    {name="257 t/152.7 kt level ground", mass=257000, ias=152.7, slope=3.0},
    {name="300 t/158 kt level ground", mass=300000, ias=158, slope=3.0},
    {name="220 t/145 kt level ground", mass=220000, ias=145, slope=3.0},
}
local fitted = {zeta=0.15, wn=0.8, delay=0.8, ge=0.8, name="fitted loop"}
local others = {
    {zeta=0.10, wn=0.9, delay=0.6, ge=1.0, name="zeta 0.10, 0.9 rad/s, 0.6 s, ground effect x1.0"},
    {zeta=0.20, wn=0.8, delay=1.0, ge=1.2, name="zeta 0.20, 0.8 rad/s, 1.0 s, ground effect x1.2"},
    {zeta=0.30, wn=1.0, delay=0.4, ge=0.8, name="zeta 0.30, 1.0 rad/s, 0.4 s, ground effect x0.8"},
}
for _, approach in ipairs(approaches) do
    local _, result = fly(approach.name..", "..fitted.name, approach, fitted)
    judge(approach.name..", "..fitted.name, result)
    -- the other loops: the same, with 20 fpm and 0.5 s more room
    for _, model in ipairs(others) do
        _, result = fly(approach.name..", "..model.name, approach, model)
        judge(approach.name..", "..model.name, result, {vsi=-320, flare_s=11.5})
    end
end
local _, noisy = fly("VSI noise, no steady sample", approaches[1], fitted, true)
judge("VSI noise, no steady sample", noisy)
-- Noise on the flare law's own inputs (the VSI above is no longer one of
-- them). X-Plane's local_vy and Q are smooth in calm air (fix-f, 300 ft to
-- touchdown: 0.004 m/s and 0.004 deg/s about a 5-sample mean at 8 Hz); these
-- are 12 to 25 times rougher: +/-0.1 m/s (20 fpm) and +/-0.1 deg/s
-- alternating each frame, and 0.05 m/s at 0.7 Hz with 0.05 deg/s at 1.1 Hz.
-- (With 0.15 of both at those frequencies the level-ground case climbs 23 fpm
-- in the flare and touches down at -32 fpm VSI: the law is not tuned for
-- noise that large.)
local input_noises = {
    {name="local_vy and Q frame-to-frame noise", fn=function(step)
        local k = ({1, -1, 0})[step % 3 + 1]
        return 0.1*k, 0.1*k
    end},
    {name="local_vy and Q low-frequency noise", fn=function(_, time)
        return 0.05*math.sin(2*math.pi*0.7*time), 0.05*math.sin(2*math.pi*1.1*time + 1)
    end},
}
for _, noise in ipairs(input_noises) do
    for _, approach in ipairs({approaches[1], approaches[4]}) do
        local _, result = fly(approach.name..", "..noise.name, approach, fitted, false, nil, false, noise.fn)
        judge(approach.name..", "..noise.name, result)
    end
end
-- X-Plane 2026-10-10 (P3 circuit): with a sink rate of 0 taken at flare entry the
-- command stayed at -100 fpm from 48 ft, the aircraft ballooned to +58 fpm at 31 ft
-- and touched down at -504 fpm 14 s after FLARE.
for _, approach in ipairs({approaches[1], approaches[4]}) do
    local _, result = fly(approach.name..", vertical speed 0 at flare entry", approach, fitted, false, nil, true)
    judge(approach.name..", vertical speed 0 at flare entry", result)
end

-- Part D: a second autoland in the same session. The first rollout ends below
-- 65 kt (AUTOLAND and the autopilots off), and nothing on the ground resets
-- active_land, so the next approach must start a new flare instead of flying
-- the -0.5 deg derotation target of the first landing from 100 ft.
local session = fly("first landing of the session", approaches[1], fitted)
session.simDRTime = session.simDRTime + DT
session.simDR_ind_airspeed_kts_pilot = 60
session.runAutoland()
equal(session.B747DR_ap_autoland, 0, "AUTOLAND ends below 65 kt")
-- the next flight: G/S captured and LAND 3 again on the approach
session.B747DR_ap_FMA_active_pitch_mode, session.B747DR_ap_FMA_armed_pitch_mode = 2, 3
session.B747DR_ap_FMA_active_roll_mode, session.B747DR_ap_FMA_armed_roll_mode = 3, 4
session.B747DR_ap_FMA_autothrottle_mode = 3
local _, second = fly("second landing of the session", approaches[1], fitted, false, session)
judge("second landing of the session", second)

print("Autoland flare regression tests passed: "..checks)
