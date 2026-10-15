-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The AP pitch servo loop of the hydraulics model: ap_pitch_assist
-- (B747.19.xt.hydraulics_override.lua) turns the flight-director pitch into
-- the elevator command with the pitch PID (pid.lua), its altitude gain
-- schedule and rate limit, and flight_controls_override applies the command
-- only from 2 s after the servos came on. The production functions fly a
-- longitudinal model: point mass with the flaps 20 polar of the 2026-10-10
-- climb (CL 0.827 + 0.064 alpha, CD 0.053 + 0.063 CL^2) at 155 kt, 300 t,
-- 3,000 ft, the A/T holding the speed, and a pitch moment fitted (output
-- error) to the elevator, alpha and pitch rate the kit recorded in the
-- 2026-10-10 circuits (fix-f, 17:41 and 17:59): at flaps 20 and 159-171 kt
-- -0.88 deg/s^2 per deg of alpha, -0.68 /s of pitch rate, +0.48 per deg of
-- elevator (22 deg x the command nose-up, 17 deg nose-down), at flaps 5
-- -1.24, -0.55 and +0.53, scaled with dynamic pressure; the stab trim
-- (doTrim) moves the stabilizer, worth 14 deg of elevator per unit.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local function slice(path, first_marker, last_marker)
    local source = read(path)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last-1)
end

-- the gains flight_start sets (B747.19.xt.hydraulicsmodel.lua)
local model_file = read(HYD.."B747.19.xt.hydraulicsmodel.lua")
local start_at = assert(model_file:find("function flight_start()", 1, true))
local start_source = model_file:sub(start_at)
local GAINS = {}
for _, name in ipairs({"PL", "PH", "I", "D"}) do
    GAINS[name] = tonumber(start_source:match("B747DR_pidPitch"..name.."%s*=%s*([%d%.]+)"))
    assert(GAINS[name], "flight_start sets B747DR_pidPitch"..name)
end
-- flight_controls_override applies the command only 2 s after the servos came on
local override_source = slice(HYD.."B747.19.xt.hydraulics_override.lua", "function flight_controls_override()",
    "yaw_damper_system()\n\nend")
check(override_source:find("if((simDRTime - B747DR_switching_servos_on)<2) then\n        ap_pitch_assist()", 1, true)
    and override_source:find("B747DR_sim_pitch_ratio=ap_pitch_assist()", 1, true),
    "flight_controls_override: the pitch command is applied 2 s after the servos came on (as modelled here)")

local model_sources = {
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_interpolate_value("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_interpolate_value(", "function B747_rescale("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")
}
local loop_source = slice(HYD.."B747.19.xt.hydraulics_override.lua", "local trimrate=25",
    "local previous_simDR_AHARS_roll_heading_deg_pilot=0").."\nreturn pitchPid"

local FPS = 44
local G, KT, S = 9.80665, 0.514444, 541.2
local CLIMB20 = {alt=3000, ias=155, mass=300e3, cl0=0.827, cla=0.064, cd0=0.053, k=0.063,
                 Ma=-0.88, Mq=-0.68, Md=0.48}
-- flaps 5 at 200 kt: the fitted moment on a polar shifted to flaps 5's lift and drag
local CLIMB5 = {alt=3000, ias=200, mass=300e3, cl0=0.45, cla=0.064, cd0=0.034, k=0.063,
                Ma=-1.24, Mq=-0.55, Md=0.53}
local TRIM_AS_ELEVATOR = 14

-- One flight: the AP off for 1 s, then CMD at t = 1 s with the flight
-- director fd_offset deg above the attitude (fix-f: 6.6 deg against 10.9).
-- Returns the history {t, pitch change, command, PID integral, PID output}
-- and the PID integral and servo command at the end of the 2 s.
local function fly(c, fd_offset, seconds, engaged, autoland)
    local env = setmetatable({print=function() end, SIM_PERIOD=1/FPS, simDRTime=0}, {__index=_G})
    setfenv(assert(loadfile(HYD.."pid.lua")), env)()
    for _, source in ipairs(model_sources) do setfenv(assert(loadstring(source)), env)() end
    local pid = setfenv(assert(loadstring(loop_source)), env)()
    env.B747DR_pidPitchPL, env.B747DR_pidPitchPH = GAINS.PL, GAINS.PH
    env.B747DR_pidPitchI, env.B747DR_pidPitchD = GAINS.I, GAINS.D
    env.B747DR_ap_AFDS_mode_box_status_pilot, env.B747DR_ap_AFDS_mode_box_status_copilot = 0, 0
    env.simDR_electric_trim, env.B744DR_autolandPitch, env.B747DR_ap_autoland = 1, 0, autoland and 1 or 0
    env.B747DR_ap_FMA_active_pitch_mode = 8
    env.simDR_autopilot_alt_hold_status, env.B747DR_ap_inVNAVdescent = 0, 0
    env.lastTrimmed = 0
    env.B747_reset_pitch_transition = function() end
    env.B747DR_autopilot_altitude_ft_pfd = c.alt

    local T0 = 288.15 - 0.0019812*c.alt
    local rho = 1.225*(T0/288.15)^4.2559
    local V = c.ias*KT*math.sqrt(1.225/rho)
    local W = c.mass*G
    local qbar0 = 0.5*rho*V*V
    local CLtrim = W/(qbar0*S)
    local alpha = (CLtrim - c.cl0)/c.cla
    local gamma, q, theta = 0, 0, alpha
    local thrust = qbar0*S*(c.cd0 + c.k*CLtrim^2)
    local V0, alpha_ref, theta0 = V, alpha, alpha
    env.B747DR_sim_pitch_ratio, env.B747DR_custom_pitch_ratio, env.simDR_elevator_trim = 0, 0, 0
    env.simDR_ind_airspeed_kts_pilot = c.ias
    env.simDR_radarAlt1 = c.alt
    local fd = theta0 + fd_offset
    env.ap_director_pitch_integral = function() return fd end

    local dt, lastCompute, t = 1/FPS, -1, 0
    local history, held = {}, nil
    env.B747DR_switching_servos_on = 0
    while t < 1 + seconds do
        env.simDRTime = t
        if engaged then
            env.simDR_autopilot_servos_on = 1
            env.B747DR_switching_servos_on = -100
            fd = theta0 + (t < 1 and 0 or fd_offset)
        elseif t < 1 then
            env.simDR_autopilot_servos_on = 0
            env.B747DR_switching_servos_on = t     -- B747_ap_afds keeps it at the time while no AP is on
        else
            env.simDR_autopilot_servos_on = 1
            env.B747DR_switching_servos_on = 1
        end
        env.simDR_AHARS_pitch_heading_deg_pilot = theta
        if t - lastCompute > 0.0333 then env.doCompute = 1; lastCompute = t else env.doCompute = 0 end
        if t - env.B747DR_switching_servos_on < 2 then
            env.ap_pitch_assist()
        else
            if not held then held = {iterm=pid._Iterm, servo=env.B747DR_sim_pitch_ratio, output=pid.output} end
            env.B747DR_sim_pitch_ratio = env.ap_pitch_assist()
        end
        env.B747DR_custom_pitch_ratio = env.B747DR_sim_pitch_ratio
        local u = env.B747DR_sim_pitch_ratio
        local elevator = u > 0 and 22*u or 17*u
        local qbar = 0.5*rho*V*V
        local scale = qbar/qbar0
        local CL = c.cl0 + c.cla*alpha
        local lift, drag = qbar*S*CL, qbar*S*(c.cd0 + c.k*CL*CL)
        thrust = thrust + (math.max(0, thrust + (V0 - V)*c.mass*0.15) - thrust)*dt/4
        local a = math.rad(alpha)
        local Vdot = (thrust*math.cos(a) - drag - W*math.sin(gamma))/c.mass
        local gdot = (lift + thrust*math.sin(a) - W*math.cos(gamma))/(c.mass*V)
        local qdot = scale*(c.Ma*(alpha - alpha_ref) + c.Md*(elevator + TRIM_AS_ELEVATOR*env.simDR_elevator_trim))
            + c.Mq*math.sqrt(scale)*q
        V = V + Vdot*dt; gamma = gamma + gdot*dt; q = q + qdot*dt; theta = theta + q*dt
        alpha = theta - math.deg(gamma)
        env.simDR_ind_airspeed_kts_pilot = V*math.sqrt(rho/1.225)/KT
        history[#history+1] = {t - 1, theta - theta0, u, pid._Iterm or 0, pid.output or 0, pid.kd}
        t = t + dt
    end
    return history, held, env
end

-- 1. CMD with the attitude 4.3 deg below the flight director, as at the
-- 2026-10-10 fix-f circuit's 400 ft hand-off (pitch 6.6, FD 10.9 deg). The
-- PID used to integrate the error through the 2 s in which its command is
-- not applied (0.07 x 4.3 deg x 2 s = 0.6), so the first applied command was
-- near full nose-up (X-Plane: 1.00 reconstructed, pitch 6.6 -> 15.7 deg,
-- then a 5-6 s hunt for 30 s). Its integral must stay at the servo's
-- position until the command is applied.
local history, held = fly(CLIMB20, 4.3, 30)
check(held and math.abs(held.iterm - held.servo) <= 0.01, string.format(
    "CMD 4.3 deg below the FD: PID integral %.3f at the end of the 2 s, servo %.3f (no windup)",
    held and held.iterm or -1, held and held.servo or -1))
local kp = GAINS.PL   -- the schedule gives PL at and below 3,000 ft
local first_output = held.output
check(first_output - held.servo <= kp*4.3 + 0.05, string.format(
    "CMD 4.3 deg below the FD: PID output %.3f when the command is first applied, servo %.3f "
    .."(at most the proportional part %.3f above it)", first_output, held.servo, kp*4.3))
local highest, peak = -1, -1e9
for _, h in ipairs(history) do
    if h[1] >= 0 and h[1] <= 10 then highest = math.max(highest, h[3]) end
    if h[1] >= 0 then peak = math.max(peak, h[2]) end
end
check(highest <= 0.7, string.format("CMD 4.3 deg below the FD: highest command %.2f in the first 10 s (1 = 22 deg up)",
    highest))
check(peak <= 4.3 + 5.0, string.format("CMD 4.3 deg below the FD: attitude peaks %.1f deg above the start "
    .."(target 4.3)", peak))

-- 2. The hunt: with the AP on, a 1 deg flight-director step at flaps 20
-- (155 kt) and flaps 5 (200 kt). The PID's integral gain equals its
-- proportional gain and its derivative was 0.0002 (nothing), so the attitude
-- swung around the target for 20 s and more (X-Plane, the 2026-10-10
-- circuits: 18 swings beyond 0.3 deg in the 65 s of FLCH climb after the
-- hand-off, a 7.4 s period; here 25 % back below the step after the first
-- overshoot, and 7 and 9 turning points). At most 4 turning points beyond
-- 5 % of the step, and at most 10 % below it in the 10 s after the first
-- overshoot. The first overshoot itself (45 % at flaps 20) is the integral's
-- and stays; so does the slow 10 % swing over 25 s that follows, the speed
-- and path settling under the A/T with either gain.
local function figures(history, step)
    local turns, peak, peak_at = 0, -math.huge, 0
    for i, h in ipairs(history) do
        if h[1] >= 0 then
            if h[1] <= 8 and h[2] > peak then peak, peak_at = h[2], h[1] end
            if i > 1 and i < #history and h[1] > 0.5 then
                local e0, e1, e2 = history[i-1][2] - step, h[2] - step, history[i+1][2] - step
                if ((e1 > e0 and e1 >= e2) or (e1 < e0 and e1 <= e2)) and math.abs(e1) > 0.05*step then
                    turns = turns + 1
                end
            end
        end
    end
    local back = math.huge
    for _, h in ipairs(history) do
        if h[1] > peak_at and h[1] <= peak_at + 10 then back = math.min(back, h[2]) end
    end
    return turns, (step - back)/step
end
for _, case in ipairs({{"flaps 20, 155 kt", CLIMB20}, {"flaps 5, 200 kt", CLIMB5}}) do
    local turns, below = figures(fly(case[2], 1.0, 40, true), 1.0)
    check(turns <= 4, string.format("1 deg FD step, %s: %d turning points beyond 5 %%", case[1], turns))
    check(below <= 0.1, string.format("1 deg FD step, %s: %.0f %% below the step in the 10 s after the first "
        .."overshoot", case[1], 100*below))
end

-- 3. AUTOLAND (below 100 ft RA) keeps the derivative the flare law was tuned
-- with (2026-10-10, P3): 0.0002.
local landing = fly(CLIMB20, 1.0, 3, true, true)
check(math.abs(landing[#landing][6] - 0.0002) < 1e-9, string.format(
    "AUTOLAND: pitch PID derivative %.4f (the flare's 0.0002)", landing[#landing][6]))
local flying = fly(CLIMB20, 1.0, 3, true, false)
check(math.abs(flying[#flying][6] - GAINS.D) < 1e-9, string.format(
    "outside AUTOLAND: pitch PID derivative %.4f (flight_start's %.4f)", flying[#flying][6], GAINS.D))

print("AP pitch loop tests passed: "..checks)
