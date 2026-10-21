-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-10] The 747's yaw dampers (yaw_damper_system, B747.19.xt.hydraulics_override.lua; X-Plane's own yaw damper is
-- off): the production flight_controls_override drives them frame by frame with the bank, heading, sideslip, yaw rate
-- and airspeed of a Dutch-roll-like motion, a steady turn and a roll-in through 5 deg of bank. The dampers must
-- oppose the yaw rate the same way at every bank and both ways, keep no rudder in a steady turn, not jump as the bank
-- crosses 5 deg, stay within their authority and give the same output at any frame rate; and in a Dutch roll model
-- they must damp it. Before, the law switched between a sideslip law and a heading law at |bank| 5 deg and cleared
-- its memory at each switch (TST744L: the output jumped up to 0.29 of its +-1 there), worked one way only below
-- 5 deg and differentiated an input held for 0.03 s; in p9-L1 a ~5 s roll and yaw oscillation of +-19 deg of bank,
-- crossing 5 deg four times a cycle, ran for 62 min.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local helpers = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")

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
local function slice(source, first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local model_source = read(HYD.."B747.19.xt.hydraulicsmodel.lua")

-- The override file in a namespace of its own, as XTLua loads it into the hydraulics script's: unbound simulator
-- names read 0; flight_controls_override's other work (steering, slats, the AP pitch and roll assists) is stubbed.
local function new_runtime()
    local env = setmetatable({}, {__index = function(_, key)
        local value = _G[key]
        if value ~= nil then return value end
        return 0
    end})
    env.print = function() end
    env.find_dataref = function() return 0 end
    env.deferred_dataref = function() return 0 end
    env.create_command = function() return {} end
    env.find_command = function() return {once = function() end, start = function() end, stop = function() end} end
    env.replace_command = env.create_command
    env.wrap_command = env.create_command
    env.dofile = function(path)
        if path == "pid.lua" then return setfenv(assert(loadfile(HYD.."pid.lua")), env)() end
        assert(path:find("afds_helpers", 1, true), "unexpected dofile "..tostring(path))
        return helpers
    end
    setfenv(assert(loadstring(slice(model_source, "function getHeadingDifference(",
        "--simDR_autopilot_nav_status"))), env)()
    setfenv(assert(loadstring(slice(model_source, "function B747_animate_value(",
        "B747DR_switching_servos_on = deferred_dataref"))), env)()
    -- the tuning values hydraulicsmodel.lua gives the old law at start
    for name, value in pairs({B747DR_pidyawPslipH = 0.02, B747DR_pidyawPslipL = 0.02, B747DR_pidyawDslipH = 0.1,
            B747DR_pidyawDslipL = 0.1, B747DR_pidyawProllH = 0.1, B747DR_pidyawProllL = 0.1,
            B747DR_pidyawDrollH = 0.1, B747DR_pidyawDrollL = 0.1}) do
        env[name] = value
    end
    env.simDR_steering = {[0] = 0, 0, 0}
    env.SIM_PERIOD = 1 / 30
    setfenv(assert(loadfile(HYD.."B747.19.xt.hydraulics_override.lua")), env)()
    -- the hydraulic systems pressurised (pressure_input fills the override file's local pressure table)
    env.B747DR_hyd_sys_pressure_1, env.B747DR_hyd_sys_pressure_2 = 3000, 3000
    env.B747DR_hyd_sys_pressure_3, env.B747DR_hyd_sys_pressure_4 = 3000, 3000
    env.pressure_input()
    env.B747_slats = function() end
    env.ap_pitch_assist = function() return 0 end
    env.ap_roll_assist = function() return 0 end
    env.B747DR_yaw_damper_upr_on, env.B747DR_yaw_damper_lwr_on = 1, 1
    env.B747DR_yaw_damper_upr, env.B747DR_yaw_damper_lwr = 0, 0
    return env
end

local TAS = 300 * 0.514444 * 1.6         -- 300 kt IAS at FL310, m/s

-- Drive the dampers through motion(t) -> {bank, rate (the body axes' yaw rate, deg/s), beta (deg), p (the roll rate,
-- deg/s, 0 without), alpha (deg, 0 without)} at fps frames a second (IAS 300 kt, FL310, or opts.ias and opts.tas,
-- m/s; on the ground with opts.on_ground), the heading following the yaw rate. Returns the upper damper's output each
-- frame; with opts.chain the rudder it moves through X-Plane's chain instead, in its +-4 deg (section 9's way).
local function fly(motion, seconds, fps, opts)
    opts = opts or {}
    local ias, tas = opts.ias or 300, opts.tas or TAS
    local env = new_runtime()
    if opts.chain then
        env.B747DR_spoilers, env.B747DR_outer_spoilers = {}, {[0] = 0, 0}
        for k = 1, 12 do env.B747DR_spoilers[k] = 0 end
        env.B747DR_flaps = {[0] = 0, 0, 0, 0, 0}
        env.B747DR_rudder_lwr_pos, env.B747DR_rudder_upr_pos = 0, 0
    end
    local dt = 1 / fps
    local heading = 90
    local out = {}
    for i = 1, math.floor(seconds * fps + 0.5) do
        local t = i * dt
        local m = motion(t)
        heading = (heading + m.rate * dt) % 360
        env.simDRTime, env.SIM_PERIOD = t, dt
        local surface
        if opts.chain then
            surface = env.B747DR_rudder_upr_pos / 4
            env.B747_controls_lower_rudder = 4 * env.B747DR_yaw_damper_lwr
            env.B747_controls_upper_rudder = 4 * env.B747DR_yaw_damper_upr
            env.pressure_input()
            env.pressure_output()
        end
        env.simDR_AHARS_roll_heading_deg_pilot = m.bank
        env.simDR_AHARS_heading_deg_pilot = heading
        env.simDR_sideslip = m.beta
        env.simDR_yaw_rate = m.rate
        env.simDR_roll_rate, env.simDR_alpha_deg = m.p or 0, m.alpha or 0
        env.simDR_touchGround = opts.on_ground and 1 or 0
        env.simDR_ind_airspeed_kts_pilot, env.simDR_ias_pilot, env.simDR_TAS_mps = ias, ias, tas
        env.simDR_flap_ratio = opts.flaps or 0
        env.B747DR_autopilot_altitude_ft_pfd = 31000
        env.flight_controls_override()
        out[#out + 1] = {t = t, u = surface or env.B747DR_yaw_damper_upr, lower = env.B747DR_yaw_damper_lwr,
            rate = m.rate, bank = m.bank}
    end
    return out
end

local function window(out, t0, t1)
    local w = {}
    for _, q in ipairs(out) do if q.t >= t0 and q.t <= t1 then w[#w + 1] = q end end
    return w
end
local function correlation(w, a, b)
    local n, sa, sb = #w, 0, 0
    for _, q in ipairs(w) do sa, sb = sa + q[a], sb + q[b] end
    local ma, mb = sa / n, sb / n
    local cov, va, vb = 0, 0, 0
    for _, q in ipairs(w) do
        cov = cov + (q[a] - ma) * (q[b] - mb)
        va, vb = va + (q[a] - ma) ^ 2, vb + (q[b] - mb) ^ 2
    end
    if va <= 0 or vb <= 0 then return 0 end
    return cov / math.sqrt(va * vb)
end
local function extremes(w, key)
    local lo, hi = math.huge, -math.huge
    for _, q in ipairs(w) do lo, hi = math.min(lo, q[key]), math.max(hi, q[key]) end
    return lo, hi
end
local function largest_kink(w)
    -- the largest change of slope from one frame to the next (a jump, not the motion's own curve)
    local worst = 0
    for i = 2, #w - 1 do worst = math.max(worst, math.abs(w[i + 1].u - 2 * w[i].u + w[i - 1].u)) end
    return worst
end
local function largest_step(w, seconds)
    -- the largest change of the output within `seconds`
    local worst = 0
    for i = 1, #w do
        for j = i + 1, #w do
            if w[j].t - w[i].t > seconds then break end
            worst = math.max(worst, math.abs(w[j].u - w[i].u))
        end
    end
    return worst
end

local OMEGA = 2 * math.pi / 5.1          -- p9-L1's oscillation, 5.1 s
-- X-Plane's yaw rate (sim/flightmodel/position/R) is the body axes': in a coordinated turn g sin(bank) / TAS (the
-- heading's rate g tan(bank) / TAS, times cos(bank); recorded at 19.9 deg, FL310, 301 kt: 0.77-0.78 deg/s, g sin 0.78,
-- g tan 0.83)
local function turn_rate(bank, tas) return math.deg(9.80665 * math.sin(math.rad(bank)) / (tas or TAS)) end

-- 1. A Dutch-roll-like yaw motion wings level (+-2 deg of bank, yaw rate +-1 deg/s): the output opposes the yaw rate,
-- the same both ways.
local dutch_level = function(t)
    return {bank = 2 * math.sin(OMEGA * t), rate = 1.0 * math.sin(OMEGA * t + math.rad(100)),
        beta = 0.4 * math.sin(OMEGA * t + math.rad(10))}
end
local out = fly(dutch_level, 40, 30)
local w = window(out, 20, 40)
local lo, hi = extremes(w, "u")
local r = correlation(w, "u", "rate")
check(hi - lo >= 0.1, string.format("wings level the dampers act on a yaw rate of +-1 deg/s (output %.3f..%.3f)", lo, hi))
check(math.abs(hi + lo) <= 0.15 * (hi - lo), string.format(
    "wings level the output is the same both ways (%.3f..%.3f)", lo, hi))
check(r <= -0.8, string.format("wings level the output opposes the yaw rate (correlation %.2f)", r))

-- 2. The same at +-19 deg of bank, crossing 5 deg four times a cycle (p9-L1, yaw rate +-2.4 deg/s): opposing the yaw
-- rate, and no jump at the crossings.
local dutch_banked = function(t)
    return {bank = 19 * math.sin(OMEGA * t), rate = 2.4 * math.sin(OMEGA * t + math.rad(101)),
        beta = 1.0 * math.sin(OMEGA * t + math.rad(10))}
end
out = fly(dutch_banked, 40, 30)
w = window(out, 20, 40)
r = correlation(w, "u", "rate")
local kink = largest_kink(w)
lo, hi = extremes(w, "u")
check(r <= -0.8, string.format("at +-19 deg of bank the output opposes the yaw rate (correlation %.2f)", r))
check(math.abs(hi + lo) <= 0.15 * (hi - lo), string.format(
    "at +-19 deg of bank the output is the same both ways (%.3f..%.3f)", lo, hi))
check(kink <= 0.1, string.format(
    "at +-19 deg of bank the output does not jump: its slope changes at most 0.1 from frame to frame (%.3f)", kink))

-- 3. A roll-in through 5 deg of bank into a steady turn (TST744L, 0.15 deg of sideslip): no jump at 5 deg.
local roll_in = function(t)
    local bank = math.min(8, 2 + t)          -- 2 to 8 deg over 6 s, 5 deg at 3 s
    return {bank = bank, rate = turn_rate(bank), beta = 0.15}
end
out = fly(roll_in, 10, 30)
step = largest_step(window(out, 2.0, 4.5), 0.125)
check(step <= 0.02, string.format("rolling in through 5 deg of bank the output moves at most 0.02 in 0.125 s (%.3f)", step))

-- 3b. A roll-in to 30 deg at 3 deg/s at 160 kt (TAS 82 m/s), coordinated: no rudder into the turn. Taking the
-- heading's rate for the coordinated turn the dampers put in up to +0.24 of their command (0.8 deg of rudder; a
-- review). At an angle of attack the roll is about the flight path, and X-Plane's body axes yaw by its rate times
-- sin(alpha) (p11-L1: +0.040 p above 270 kt, +0.077 p below 200 kt): at 6 deg, as at 160 kt, the dampers put in up to
-- -0.29 against the roll (1 deg of rudder; a review). With alpha 0 and 6 deg.
local slow_tas = 160 * 0.514444
for _, alpha in ipairs({0, 6}) do
    local slow_roll = function(t)
        local bank = math.min(30, 3 * math.max(0, t - 1))
        local p = (t > 1 and t < 11) and 3 or 0
        local a = math.rad(alpha)
        return {bank = bank, rate = turn_rate(bank, slow_tas) * math.cos(a) + p * math.sin(a), beta = 0,
            p = p * math.cos(a), alpha = alpha}
    end
    out = fly(slow_roll, 20, 30, {ias = 160, tas = slow_tas})
    lo, hi = extremes(out, "u")
    check(math.max(-lo, hi) <= 0.03, string.format(
        "rolling into a 30 deg turn at 160 kt, alpha %d deg, the output stays within 0.03 (%.3f..%.3f)", alpha, lo, hi))
end

-- 3c. On the ground no rudder from the dampers: taxi turns at 1, 3 and 5 deg/s at 15 kt and a heading correction of
-- +-0.5 deg/s on the takeoff roll at 120 kt. Below 50 m/s there is no coordinated turn to take away and the gain is at
-- its largest: the taxi turns drove the output to -0.90, -1.0 and -1.0 (the whole +-3.5 deg of rudder), the
-- correction to -0.46 against the steering (a review).
for _, c in ipairs({{1, 15}, {3, 15}, {5, 15}, {0.5, 120}}) do
    local taxi = c[2] < 50
    out = fly(function(t)
        return {bank = 0, rate = taxi and math.min(c[1], c[1] * t / 2) or c[1] * math.sin(2 * math.pi * t / 6), beta = 0}
    end, 12, 30, {ias = c[2], tas = c[2] * 0.514444, on_ground = true})
    lo, hi = extremes(out, "u")
    check(math.max(-lo, hi) <= 0.01, string.format("on the ground at %d kt, a yaw rate of %s%.1f deg/s: no rudder (%.3f..%.3f)",
        c[2], taxi and "" or "+-", c[1], lo, hi))
end

-- 4. A steady 20 deg turn: no rudder from the dampers once the turn is steady (the yaw rate washed out).
local steady = function() return {bank = 20, rate = turn_rate(20), beta = 0} end
out = fly(steady, 30, 30)
check(math.abs(out[#out].u) <= 0.02, string.format("in a steady 20 deg turn the output fades out (%.3f)", out[#out].u))

-- 5. The same rudder at 45, 50 and 60 frames a second through X-Plane's chain (motion 2; section 9), and the same
-- output at 20 and 30, where the chain's 11 frames leave the law no lag of its own.
local function at(trace, t)
    for _, q in ipairs(trace) do if q.t >= t - 1e-9 then return q.u end end
    return trace[#trace].u
end
local function spread_of(list)
    local spread = 0
    for t = 10, 30, 0.5 do
        local lo, hi = math.huge, -math.huge
        for _, trace in ipairs(list) do lo, hi = math.min(lo, at(trace, t)), math.max(hi, at(trace, t)) end
        spread = math.max(spread, hi - lo)
    end
    return spread
end
local spread = spread_of({fly(dutch_banked, 30, 45, {chain = true}), fly(dutch_banked, 30, 50, {chain = true}),
    fly(dutch_banked, 30, 60, {chain = true})})
check(spread <= 0.05, string.format("the rudder is the same at 45, 50 and 60 fps (spread %.3f of +-4 deg)", spread))
spread = spread_of({fly(dutch_banked, 30, 20), fly(dutch_banked, 30, 30)})
check(spread <= 0.05, string.format("the output is the same at 20 and 30 fps (spread %.3f)", spread))

-- 6. Within the dampers' authority, and both dampers alike: a yaw rate of 10 deg/s.
out = fly(function(t) return {bank = 0, rate = 10 * math.sin(OMEGA * t), beta = 0} end, 20, 30)
lo, hi = extremes(out, "u")
local same = true
for _, q in ipairs(out) do if math.abs(q.u - q.lower) > 1e-9 then same = false end end
check(lo >= -1 and hi <= 1 and same, string.format("the output stays within +-1, both dampers alike (%.3f..%.3f)", lo, hi))

-- 6b. One frame of a yaw rate that is no number (NaN) in motion 1: the output stays a number within +-1 and the
-- dampers act again after it. LuaJIT's math.min and math.max pass NaN through: the filter kept it until a gap of more
-- than a second, and the slew never left it, so the rudder command was NaN (a review).
out = fly(function(t)
    local m = dutch_level(t)
    if math.abs(t - 10) < 0.5 / 30 then m.rate = 0 / 0 end
    return m
end, 40, 30)
local finite = true
for _, q in ipairs(out) do
    if q.u ~= q.u or q.lower ~= q.lower or math.abs(q.u) > 1 then finite = false end
end
r = correlation(window(out, 20, 40), "u", "rate")
check(finite and r <= -0.8, string.format(
    "one NaN yaw rate: the output stays a number within +-1 (%s) and opposes the yaw rate again after it (%.2f)",
    tostring(finite), r))
-- an infinite one too, either sign: inf - inf left NaN in the filter, and the output stayed 0 (LuaJIT) or +1 (Lua 5.1,
-- the whole 3.5 deg of rudder) until a gap of more than a second (a review)
for _, value in ipairs({math.huge, -math.huge}) do
    out = fly(function(t)
        local m = dutch_level(t)
        if math.abs(t - 10) < 0.5 / 30 then m.rate = value end
        return m
    end, 40, 30)
    finite = true
    for _, q in ipairs(out) do
        if q.u ~= q.u or q.lower ~= q.lower or math.abs(q.u) > 1 then finite = false end
    end
    r = correlation(window(out, 20, 40), "u", "rate")
    check(finite and r <= -0.8, string.format(
        "one yaw rate of %s: the output stays a number within +-1 (%s) and opposes the yaw rate again after it (%.2f)",
        tostring(value), tostring(finite), r))
end

-- 7. A Dutch roll model (yaw and sideslip, 5.1 s, bare damping 0.03; the rudder +-4 deg, the dampers' authority, its
-- yaw acceleration 0.2-0.6 rad/s2 per rad): from 2 deg of sideslip the dampers take three cycles' amplitude below 35 %;
-- without them it stays above 70 %.
local function dutch_roll(rudder_effect, dampers_on)
    local env = new_runtime()
    env.B747DR_yaw_damper_upr_on, env.B747DR_yaw_damper_lwr_on = dampers_on and 1 or 0, dampers_on and 1 or 0
    local fps, dt = 30, 1 / 30
    local n_beta, n_r, y_beta = OMEGA * OMEGA, -2 * 0.03 * OMEGA, 0
    local beta, rate = math.rad(2), 0
    local heading = 90
    local first, peak = nil, 0
    for i = 1, math.floor(3 * 5.1 * fps + 0.5) do
        local t = i * dt
        local rudder = math.rad(4 * env.B747DR_yaw_damper_upr)
        local beta_dot = y_beta * beta - rate
        local rate_dot = n_beta * beta + n_r * rate + rudder_effect * rudder
        beta, rate = beta + beta_dot * dt, rate + rate_dot * dt
        heading = (heading + math.deg(rate) * dt) % 360
        env.simDRTime, env.SIM_PERIOD = t, dt
        env.simDR_AHARS_roll_heading_deg_pilot = 0
        env.simDR_AHARS_heading_deg_pilot = heading
        env.simDR_sideslip = math.deg(beta)
        env.simDR_yaw_rate = math.deg(rate)
        env.simDR_ind_airspeed_kts_pilot, env.simDR_ias_pilot, env.simDR_TAS_mps = 300, 300, TAS
        env.B747DR_autopilot_altitude_ft_pfd = 31000
        env.flight_controls_override()
        if t >= 2 * 5.1 then peak = math.max(peak, math.abs(math.deg(beta))) end
    end
    return peak / 2
end
for _, effect in ipairs({0.2, 0.4, 0.6}) do
    local with = dutch_roll(effect, true)
    local without = dutch_roll(effect, false)
    check(with <= 0.35 and without >= 0.7, string.format(
        "a Dutch roll (rudder %.1f rad/s2 per rad): three cycles on %.0f %% of the sideslip with the dampers, %.0f %% without",
        effect, 100 * with, 100 * without))
end

-- 8. [P25] The 747's law (NASA CR-2144, Heffley and Jewell 1972, Fig IX-4, from Boeing's 747 simulator description
-- D6-30643): flaps up 1.37 deg of rudder per deg/s of yaw rate through a 2.72 s washout and a 0.27 s lag (1.23 at the
-- Dutch roll's 0.9 rad/s), whatever the airspeed, doubled with the flaps out; each damper +-4 deg of rudder command at
-- any airspeed (FAA NPRM FAA-2011-0571, 76 FR 36391: "Yaw damper authority is limited to +/- 4 degrees of rudder
-- command"; the damper's piston in each rudder PCM - taken past the pedals' ratio changer). A yaw rate of +-0.3 deg/s at
-- 0.9 rad/s wings level: the rudder (4 deg x the output) per deg/s within 10 % of 1.23 flaps up at 180, 300 and 350 kt,
-- of 2.47 with the flaps at 20 at 180 kt; the dampers' rows in hydraulicsmodel.lua +-4 deg without the rudder ratio.
local function rudder_per_rate(ias, flaps)
    local w = 0.9
    local o = fly(function(t) return {bank = 0, rate = 0.3 * math.sin(w * t), beta = 0} end, 60, 30,
        {ias = ias, tas = ias * 0.514444 * 1.4, flaps = flaps})
    local l, h = extremes(window(o, 30, 60), "u")
    return 4 * (h - l) / 2 / 0.3
end
for _, c in ipairs({{180, 0, 1.23}, {300, 0, 1.23}, {350, 0, 1.23}, {180, 20 / 30, 2.47}}) do
    local k = rudder_per_rate(c[1], c[2])
    check(math.abs(k - c[3]) <= 0.1 * c[3], string.format(
        "at %d kt with the flap handle at %.2f: %.2f deg of rudder per deg/s of yaw rate at 0.9 rad/s (%.2f +- 10 %%)",
        c[1], c[2], k, c[3]))
end
local rows, plain = 0, true
for row in model_source:gmatch("B747DR_controlOverrides = '([^']*)'") do
    if row:find("yaw_damper_", 1, true) then
        rows = rows + 1
        plain = plain and row:find('"minout":-4,', 1, true) ~= nil and row:find('"maxout":4,', 1, true) ~= nil
            and row:find("scaledref", 1, true) == nil
    end
end
check(rows == 2 and plain, string.format(
    "each yaw damper's command is +-4 deg of rudder, not scaled by the rudder ratio (%d rows, %s)", rows, tostring(plain)))

-- 9. [review 23] The rudder the dampers move, through X-Plane's chain: their output to the cable controls (the control
-- override rows, a frame), pressure_input and pressure_output (B747_animate_value: a tenth of the way a frame) to the
-- rudder's position, and to the flight model (the rows, a frame). A yaw rate of +-0.3 deg/s at 0.9 rad/s wings level at
-- 300 kt, flaps up: the rudder per deg/s and its phase against the yaw rate's (the rudder against it) as CR-2144's law
-- has them (1.23 deg per deg/s, 8.5 deg ahead: the washout's 22.2 ahead, the lag's 13.7 behind) within 5 % and 2 deg at
-- 45, 50 and 60 fps, and within 7 deg at 30 fps. The law's 0.27 s lag on top of the chain (0.19 s at 50 fps, 0.32 s at
-- 30 fps, and the frames) put the rudder 3.3 deg behind the yaw rate at 50 fps and 11 deg behind at 30 fps.
local function chain_rudder(fps)
    local env = new_runtime()
    -- pressure_output's surfaces (only the rudder's is looked at here)
    env.B747DR_spoilers, env.B747DR_outer_spoilers = {}, {[0] = 0, 0}
    for k = 1, 12 do env.B747DR_spoilers[k] = 0 end
    env.B747DR_flaps = {[0] = 0, 0, 0, 0, 0}
    env.B747DR_rudder_lwr_pos, env.B747DR_rudder_upr_pos = 0, 0
    local dt, w = 1 / fps, 0.9
    local heading, yd = 90, 0
    local sa, ca, sr, cr, n = 0, 0, 0, 0, 0
    local surface = 0
    for i = 1, math.floor(80 * fps + 0.5) do
        local t = i * dt
        local rate = 0.3 * math.sin(w * t)
        heading = (heading + rate * dt) % 360
        env.simDRTime, env.SIM_PERIOD = t, dt
        -- the rudder the flight model has this frame: its position at the end of the last one (the rows)
        surface = env.B747DR_rudder_lwr_pos or 0
        -- the cable controls from the dampers' output of the last frame (the rows), then the frame's order
        env.B747_controls_lower_rudder, env.B747_controls_upper_rudder = 4 * yd, 4 * yd
        env.pressure_input()
        env.pressure_output()
        env.simDR_AHARS_roll_heading_deg_pilot = 0
        env.simDR_AHARS_heading_deg_pilot = heading
        env.simDR_sideslip, env.simDR_yaw_rate = 0, rate
        env.simDR_roll_rate, env.simDR_alpha_deg = 0, 0
        env.simDR_touchGround = 0
        env.simDR_ind_airspeed_kts_pilot, env.simDR_ias_pilot, env.simDR_TAS_mps = 300, 300, TAS
        env.simDR_flap_ratio = 0
        env.B747DR_autopilot_altitude_ft_pfd = 31000
        env.flight_controls_override()
        yd = env.B747DR_yaw_damper_lwr
        -- the last 20 s: whole cycles' sine and cosine parts of the rudder and of the yaw rate
        if t > 80 - 2 * math.pi / w * 2.865 then
            sa, ca = sa - surface * math.sin(w * t), ca - surface * math.cos(w * t)
            sr, cr = sr + rate * math.sin(w * t), cr + rate * math.cos(w * t)
            n = n + 1
        end
    end
    local amp = math.sqrt(sa * sa + ca * ca) / math.sqrt(sr * sr + cr * cr)
    local phase = math.deg(math.atan2(ca, sa) - math.atan2(cr, sr))
    return amp, (phase + 180) % 360 - 180
end
local law_phase = math.deg(math.atan(1 / (0.9 * 2.72)) - math.atan(0.9 * 0.272))
for _, c in ipairs({{45, 2}, {50, 2}, {60, 2}, {30, 7}}) do
    local amp, phase = chain_rudder(c[1])
    check(math.abs(amp - 1.23) <= 0.05 * 1.23 and math.abs(phase - law_phase) <= c[2], string.format(
        "at %d fps the rudder through X-Plane's chain: %.2f deg per deg/s (1.23 +- 5 %%), %.1f deg ahead of the yaw rate"
        .. " (CR-2144's law %.1f +- %d)", c[1], amp, phase, law_phase, c[2]))
end

print("yaw damper tests passed: "..checks)
