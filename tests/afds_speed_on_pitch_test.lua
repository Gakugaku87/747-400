-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P43] Speed on pitch (FLCH SPD and VNAV SPD outside the capture window): a flight path law on the acceleration
-- error every 0.1 s (hydraulics_afds_helpers.lua's SPEED_PITCH_* and speed_pitch_*, hydraulics_override.lua's
-- ap_director_speed_on_pitch). The law it replaced moved the pitch by increments 0.3-0.5 s apart, none while the
-- attitude was 0.5 deg behind, averaged over 10 updates: resuming the climb at 8,950 ft on p35-line1 (EIDW, 233 t,
-- 2026-10-20) it pitched up at about 0.4 deg/s 4-6 s after the A/T added climb thrust and the IAS went from 251 to
-- 271 kt; FLCH at idle from FL310 on p34-L1 (TST744L) pitched down at 0.08 deg/s and fell 26 kt below M .84's speed;
-- accelerating from 250 to 326 kt at 10,000 ft on p34-L1 it kept 22-31 % of the 2,234 fpm climb, where 744s in ADS-B
-- keep 40-55 % (median 47 %) at 0.45-0.77 kt/s.
-- 1. the helpers; 2. the production director with mocked datarefs; 3. climb_model (the production director and pitch
-- loop on a point mass fitted to those flights) on their recorded thrust and targets (tests/data/p35-line1_speed_pitch.csv,
-- tests/data/p34-L1_speed_pitch.csv), at 15, 20 and 34 fps.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
local CM = dofile("tests/climb_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function near(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": "..tostring(actual).." ~= "..tostring(expected).." +/- "..tostring(tolerance))
end

-- 1. The helpers
local accel, wanted, path = controls.speed_pitch_accel, controls.speed_pitch_wanted_accel,
    controls.speed_pitch_path_error_deg
local max_rate = controls.speed_pitch_max_rate_deg
if type(accel) ~= "function" or type(wanted) ~= "function" or type(path) ~= "function"
    or type(max_rate) ~= "function" then
    check(false, "the speed-on-pitch helpers (speed_pitch_accel, speed_pitch_wanted_accel, speed_pitch_path_error_deg, "
        .."speed_pitch_max_rate_deg)")
else
    -- the pitch rate that turns the path with 0.1 g: 0.37 deg/s at 150 m/s TAS, 0.23 at 245 m/s, 0.94 without a TAS
    -- (60 m/s)
    near(max_rate(150), math.deg(0.1 * 9.80665 / 150), 1e-9, "the pitch rate of 0.1 g at 150 m/s")
    near(max_rate(245), math.deg(0.1 * 9.80665 / 245), 1e-9, "the pitch rate of 0.1 g at 245 m/s")
    near(max_rate(nil), math.deg(0.1 * 9.80665 / 60), 1e-9, "the pitch rate of 0.1 g without a TAS")
    -- the IAS's rate through a 1 s first order: 1 kt/s for 0.1 s from 0 is 0.1; a 30 kt jump (a first read of 0) and no
    -- time or no change keep the last
    near(accel(0, 0.1, 0.1), 0.1, 1e-9, "IAS rate filter: 0.1 of 1 kt/s in 0.1 s")
    near(accel(0.5, 0.1, 1.0), 0.1, 1e-9, "IAS rate filter: the whole change after 1 s")
    near(accel(0.4, 30, 0.1), 0.4, 1e-9, "IAS rate filter: a jump of 300 kt/s is left out")
    near(accel(0.4, -250, 0.1), 0.4, 1e-9, "IAS rate filter: a first read of 0 is left out")
    near(accel(0.4, 0.1, 0), 0.4, 1e-9, "IAS rate filter: no time")
    near(accel(0.4, nil, 0.1), 0.4, 1e-9, "IAS rate filter: no change")
    near(accel(0.4, 0/0, 0.1), 0.4, 1e-9, "IAS rate filter: NaN")
    -- the acceleration wanted: the error over 20 s within +-1 kt/s
    near(wanted(326, 250, false, 0, 0, 150), 1.0, 1e-9, "wanted: 76 kt below, at most 1 kt/s")
    near(wanted(255, 250, false, 0, 0, 150), 0.25, 1e-9, "wanted: 5 kt below, 0.25 kt/s")
    near(wanted(250, 270, true, 0, 4000, 150), -1.0, 1e-9, "wanted: 20 kt above, -1 kt/s (climbing too)")
    near(wanted(250, 255, true, 0, 4000, 150), -0.25, 1e-9, "wanted: 5 kt above, -0.25 kt/s")
    -- climbing, at most 0.6 of the energy rate: 2,263 fpm at 150 m/s TAS and 250 kt is g sin(path) = 1.253 kt/s of
    -- IAS, 0.752 of it; with the IAS rising 0.3 kt/s 0.932; none with no energy
    local climb = (9.80665 / 0.514444) * (2263 * 0.00508 / 150) * (250 * 0.514444 / 150)
    near(wanted(326, 250, true, 0, 2263, 150), 0.6 * climb, 1e-9, "wanted climbing: 0.6 of the energy rate")
    near(wanted(326, 250, true, 0.3, 2263, 150), 0.6 * (climb + 0.3), 1e-9, "wanted climbing: with the IAS's rate")
    near(wanted(326, 250, true, 0, 0, 150), 0, 1e-9, "wanted climbing: no energy, no acceleration")
    near(wanted(326, 250, true, -0.2, 0, 150), 0, 1e-9, "wanted climbing: losing energy, no acceleration")
    near(wanted(255, 250, true, 0, 2263, 150), 0.25, 1e-9, "wanted climbing: less than the share")
    near(wanted(nil, 250, true, 0, 2263, 150), 0, 1e-9, "wanted: no target")
    -- no TAS: taken as 30 m/s, where 2,263 fpm is 31 kt/s of energy: the 1 kt/s limit
    near(wanted(326, 250, true, 0, 2263, nil), 1.0, 1e-9, "wanted climbing: no TAS (30 m/s)")
    -- the path error: 1 kt/s of IAS more than wanted at 150 m/s TAS and 250 kt is 3.006 x TAS/IAS deg of path
    local k = math.deg(0.514444 / 9.80665)
    near(path(1, 0, 150, 250), k * 150 / (250 * 0.514444), 1e-9, "path error: 1 kt/s too much")
    near(path(-0.5, 0.5, 150, 250), -k * 150 / (250 * 0.514444), 1e-9, "path error: 1 kt/s too little")
    near(path(0.3, 0.3, 150, 250), 0, 1e-12, "path error: as wanted")
    near(path(1, 0, nil, nil), k, 1e-9, "path error: no TAS and IAS (30 m/s each)")
end

-- 2. The production director (ap_director_pitch with its file locals; B747_afds_controls and the pitch records are
-- file locals above the slice, so here globals of the environment), the attitude where the test puts it.
local function slice(path_name, first_marker, last_marker)
    local file = assert(io.open(path_name))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")
local rescale_source = slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")
-- VNAV SPD climbing at 250 kt through 9,000 ft (MCP FL370), 5 deg, 250 kt IAS at 150 m/s TAS, 2,000 fpm
local function new_director(values)
    local env = {
        print = function() end, B747_afds_controls = controls,
        B747_interpolate_value = function(current, target) return target end,
        debug_flight_directors = 0, B747DR_ap_autoland = 0, B744DR_autolandPitch = 0,
        B747DR_flap_ratio = 0, B747DR_flap_lever_detent = 0, simDR_radarAlt1 = 9000,
        simDR_AHARS_pitch_heading_deg_pilot = 5, simDR_flight_director_pitch = 5, simDR_AHARS_roll_heading_deg_pilot = 0,
        B747DR_airspeed_Vmc = 190, B747DR_airspeed_Vmax = 365,
        simDR_ind_airspeed_kts_pilot = 250, simDR_autopilot_airspeed_kts = 250, simDR_TAS_mps = 150, simDR_alpha_deg = 3,
        simDR_vvi_fpm_pilot = 2000, simDR_autopilot_vs_fpm = 0,
        B747DR_ap_flightPhase = 1, B747DR_autopilot_TOGA_status = 0, B747DR_alt_capture_window = 600,
        simDR_pressureAlt1 = 9000, simDR_autopilot_altitude_ft = 37000, simDR_autopilot_hold_altitude_ft = 37000,
        simDR_autopilot_alt_hold_status = 0, simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 0,
        simDR_autopilot_servos_on = 1, simDR_elevation = 9000 * 0.3048, simDR_groundspeed = 150,
        simDR_glideslope1 = 3, simDR_hsi_vdef_dots_pilot = 0,
        B747_afds_pitch_target_before_blend = 5, B747_afds_pitch_target_after_blend = 5, simDRTime = 1000}
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index = _G})
    setfenv(assert(loadstring(rescale_source)), env)()
    -- the director has been flying this attitude
    local source = director_source:gsub("local last_simDR_AHARS_pitch_heading_deg_pilot=0",
        "local last_simDR_AHARS_pitch_heading_deg_pilot="..env.simDR_AHARS_pitch_heading_deg_pilot, 1)
    setfenv(assert(loadstring(source)), env)()
    return env
end
-- one director call dt s after the last, the IAS changing at ias_rate kt/s; returns the raw pitch target
local function step(env, mode, dt, ias_rate)
    env.simDRTime = env.simDRTime + dt
    env.simDR_ind_airspeed_kts_pilot = env.simDR_ind_airspeed_kts_pilot + (ias_rate or 0) * dt
    env.ap_director_pitch(mode)
    return env.B747_afds_pitch_target_before_blend
end
for _, mode in ipairs({4, 8}) do
    local name = mode == 4 and "VNAV SPD" or "FLCH SPD"
    local env = new_director({simDR_autopilot_flch_status = mode == 8 and 2 or 0})
    step(env, mode, 0.1)                          -- the first update only starts the law, at the director's pitch
    near(env.B747_afds_pitch_target_before_blend, 5, 1e-9, name..": the first update holds the pitch")
    for _ = 1, 30 do step(env, mode, 0.1) end     -- on speed, steady: held
    near(env.B747_afds_pitch_target_before_blend, 5, 1e-6, name..": on speed and steady, held")
    -- the IAS rising 1.5 kt/s on target (the A/T adding thrust): up, at most 0.1 g's 0.37 deg/s plus 0.3 x 1 deg
    local before = env.B747_afds_pitch_target_before_blend
    local up = {}
    for i = 1, 20 do up[i] = step(env, mode, 0.1, 1.5) end
    check(up[3] > before + 0.25, name..": the pitch rises at once with the IAS (0.3 s: "..up[3] - before.." deg)")
    local limit = math.deg(0.1 * 9.80665 / 150)
    check(up[20] - before <= limit * 2 + 0.3 + 1e-6,
        name..": at most 0.1 g and 0.3 deg ("..up[20] - before.." deg in 2 s)")
    check(up[20] - before >= limit * 1.5, name..": the rate limit reached ("..up[20] - before.." deg in 2 s)")
    -- a gap of more than a second: the law starts again from the director's pitch
    local held = env.B747_afds_pitch_target_before_blend
    step(env, mode, 2.0, 0)
    near(env.B747_afds_pitch_target_before_blend, held, 1e-9, name..": after a gap the first update holds")
end
-- another branch of the director in between (V/S for 0.5 s, as an ALT capture inside the window would): the next
-- speed update holds the director's pitch, not the law's from before
do
    local env = new_director({simDR_autopilot_vs_fpm = -3000})
    step(env, 4, 0.1)
    for _ = 1, 20 do step(env, 4, 0.1, 1.5) end
    for _ = 1, 5 do step(env, 7, 0.1) end
    local other = env.B747_afds_pitch_target_before_blend
    step(env, 4, 0.1)
    near(env.B747_afds_pitch_target_before_blend, other, 1e-9, "after another branch the first speed update holds")
end
-- climbing at +2,000 fpm 20 kt below the target and steady: down at most 0.1 g's rate; at +50 fpm (the VSI's +100 fpm
-- guard) not down at all
do
    local env = new_director({simDR_autopilot_airspeed_kts = 270})
    step(env, 4, 0.1)
    local before = env.B747_afds_pitch_target_before_blend
    for _ = 1, 20 do step(env, 4, 0.1, 0) end
    local down = before - env.B747_afds_pitch_target_before_blend
    check(down > 0.3 and down <= math.deg(0.1 * 9.80665 / 150) * 2 + 0.3 + 1e-6,
        "20 kt slow at +2,000 fpm: down at most 0.1 g's rate and 0.3 deg ("..down..")")
    env = new_director({simDR_autopilot_airspeed_kts = 270, simDR_vvi_fpm_pilot = 50})
    step(env, 4, 0.1)
    for _ = 1, 20 do step(env, 4, 0.1, 0) end
    check(env.B747_afds_pitch_target_before_blend >= 5 - 1e-9, "20 kt slow at +50 fpm: the climb guard holds the pitch ("
        ..env.B747_afds_pitch_target_before_blend..")")
end
-- the flight director alone (servos off): the law's pitch stays within 2 deg of the attitude
do
    local env = new_director({simDR_autopilot_servos_on = 0, simDR_autopilot_airspeed_kts = 200})
    step(env, 4, 0.1)
    for _ = 1, 100 do step(env, 4, 0.1, 0) end
    local fd = env.B747_afds_pitch_target_before_blend
    check(fd <= 5 + 2 + 0.3 + 1e-6 and fd > 5 + 1, "flight director alone, 50 kt fast: within 2 deg (and P) of the attitude ("..fd..")")
end

-- 3. Closed loop on the flights' recorded thrust and targets
local function load_csv(name)
    local rows, head = {}, nil
    for line in io.lines(name) do
        if not head then head = {} for field in line:gmatch("[^,]+") do head[#head + 1] = field end
        else
            local r, i = {}, 0
            for v in line:gmatch("[^,]+") do i = i + 1 r[head[i]] = tonumber(v) end
            rows[#rows + 1] = r
        end
    end
    return rows
end
local function interp(rows, t, key)
    local lo, hi = 1, #rows
    if t <= rows[1].t then return rows[1][key] end
    if t >= rows[hi].t then return rows[hi][key] end
    while hi - lo > 1 do
        local mid = math.floor((lo + hi) / 2)
        if rows[mid].t <= t then lo = mid else hi = mid end
    end
    local a, b = rows[lo], rows[hi]
    return a[key] + (b[key] - a[key]) * (t - a.t) / (b.t - a.t)
end
-- climb_model's summary counts the F/D's direction changes of more than 0.2 deg however slowly it moves: a 1 deg
-- sine of 20 s over 60 s has 6 (the count let its extreme follow the F/D both ways until a move of 0.2 deg within a
-- 0.25 s sample, and gave 0 here; p35-line1's flap steps with 4 counted 0)
do
    local track = {}
    for k = 0, 239 do
        local t = k * 0.25
        track[#track + 1] = {t = t, fd = math.sin(2 * math.pi * t / 20), ias = 250, target = 250, nz = 0, q = 0}
    end
    local s = CM.summary({track = track}, 0)
    check(s.reversals == 6, "summary: a slow 1 deg sine's 6 reversals: "..s.reversals)
    s = CM.summary({track = track}, 0, 30)
    check(s.reversals == 3, "summary: 3 of them in its first 30 s: "..s.reversals)
end
local P35 = load_csv("tests/data/p35-line1_speed_pitch.csv")
local P34 = load_csv("tests/data/p34-L1_speed_pitch.csv")
-- a recorded stretch from t0 for span s: the thrust an engine, the targets (at most cap_kt below cap_ft), the flaps,
-- the pitch mode, the MCP altitude and the capture window as recorded
local function fly(rows, t0, span, fps, cap_kt, cap_ft)
    local first
    for _, r in ipairs(rows) do if r.t >= t0 then first = r break end end
    local function target(t, h)
        local tgt = interp(rows, t0 + t, "tgt")
        if cap_kt and h < cap_ft then tgt = math.min(tgt, cap_kt) end
        return tgt
    end
    return CM.fly({alt_ft = first.alt, ias_kt = first.ias, vs_fpm = first.vs, weight_kg = first.weight,
        flaps = first.flap, pitch_mode = first.fma, target_kt = target(0, first.alt), mcp_alt_ft = first.mcp_alt,
        capture_window_ft = first.window, seconds = span, dt = 1 / fps,
        thrust = function(t) return interp(rows, t0 + t, "thrust") end,
        frame = function(m, t)
            m.target_kt = target(t, m.state.h)
            m.state.flap = interp(rows, t0 + t, "flap")
            local d, mode, mcp = m.d, math.floor(interp(rows, t0 + t, "fma") + 0.5), interp(rows, t0 + t, "mcp_alt")
            d.B747DR_ap_FMA_active_pitch_mode = mode
            d.simDR_autopilot_altitude_ft, d.B747DR_autopilot_altitude_ft = mcp, mcp
            d.simDR_autopilot_hold_altitude_ft = mcp
            d.simDR_autopilot_flch_status = (mode == 8) and 2 or 0
            d.B747DR_alt_capture_window = interp(rows, t0 + t, "window")
        end})
end
for _, fps in ipairs({15, 20, 34}) do
    local at = string.format(" (%d fps)", fps)
    -- a. p35-line1 resuming the climb at 8,948 ft: VNAV PTH -> VNAV SPD, the A/T to THR REF (the thrust from 48 to
    -- 114 kN an engine in 6 s), VNAV's 250 kt (P42 caps it there; it rose to 255 kt with the IAS). The old law: the
    -- attitude up 0.9 deg in the first 8 s, the IAS to 271.1 kt.
    local m = fly(P35, 505, 70, fps, 250, 10100)
    local s = CM.summary(m, 0, 50)
    near(m.hyd.MODEL_director_state().sample_rate, 0.1, 1e-9, "VNAV SPD: the director samples every 0.1 s"..at)
    local base, rise = CM.at(m, 0).theta, CM.at(m, 8).theta
    check(rise - base >= 1.5, "re-climb: the attitude up 1.5 deg within 8 s"..at..string.format(": %.2f", rise - base))
    check(s.over <= 18.5, "re-climb: the IAS at most 18.5 kt over 250"..at..string.format(": %+.1f kt", s.over))
    check(s.reversals <= 1 and s.rate <= 0.6 and s.nz <= 0.16, "re-climb: smooth"..at
        ..string.format(": %d F/D reversals, %.2f deg/s, %.3f g", s.reversals, s.rate, s.nz))
    -- b. p34-L1 FLCH SPD from ALT at FL310 (MCP FL270), the A/T at idle from 2 s, M .84's speed rising 302 -> 310 kt
    -- as it descends, then 283 kt from 48 s. The old law: 25.5 kt below.
    m = fly(P34, 2094, 82, fps)
    local lowest, highest_vs = math.huge, -math.huge
    for _, p in ipairs(m.track) do
        if p.t < 47 then lowest = math.min(lowest, p.ias - p.target) end
        if p.t > 5 then highest_vs = math.max(highest_vs, p.vs) end
    end
    check(lowest >= -10, "FLCH at idle: within 10 kt of M .84's speed"..at..string.format(": %.1f kt", lowest))
    check(highest_vs <= 200, "FLCH at idle: no climbing"..at..string.format(": %+.0f fpm", highest_vs))
    -- c. p34-L1 VNAV SPD at 10,105 ft, 250 -> 326 kt (from 7 s) at +2,263 fpm: 40 % of the climb or more from 15 s
    -- after the step until 5 kt from the target, no overshoot. The old law: 22 % (500 fpm), 0.95 kt/s.
    m = fly(P34, 520, 195, fps)
    local share, reached = math.huge, nil
    for _, p in ipairs(m.track) do
        if p.t > 22 and p.target - p.ias > 5 then share = math.min(share, p.vs / 2263) end
        if not reached and p.t > 7 and p.ias >= p.target - 2 then reached = p.t end
    end
    s = CM.summary(m, 7)
    check(share >= 0.40, "10,000 ft: 40 % of the climb kept accelerating"..at..string.format(": %.0f %%", share * 100))
    check(s.over <= 3 and s.reversals <= 1, "10,000 ft: no overshoot, smooth"..at
        ..string.format(": %+.1f kt, %d reversals", s.over, s.reversals))
    -- (ADS-B: 55-80 kt in 75-170 s)
    check(reached and reached <= 7 + 170, "10,000 ft: 326 kt within 170 s"..at..": "..tostring(reached))
    -- d. p35-line1's flap retraction steps (154 -> 192 kt at 1,723 ft with flaps 20 -> 10, 192 -> 210 at 2,940 ft):
    -- the IAS 3 kt up within 20 s of the step, the thrust coming back to CLB in it. The old law: 23 s.
    m = fly(P35, 280, 60, fps)
    local step_t, ias0, up_t
    for _, p in ipairs(m.track) do
        if not step_t and p.target >= 190 then step_t, ias0 = p.t, p.ias end
        if step_t and not up_t and p.ias >= ias0 + 3 then up_t = p.t - step_t end
    end
    check(up_t and up_t <= 20, "flaps up: accelerating within 20 s of the step"..at..": "..tostring(up_t))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS speed on pitch tests passed: "..checks)
