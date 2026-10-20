-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P43] Speed on pitch (FLCH SPD and VNAV SPD outside the capture window): a flight path law on the acceleration
-- error every 0.1 s (hydraulics_afds_helpers.lua's SPEED_PITCH_* and speed_pitch_*, hydraulics_override.lua's
-- ap_director_speed_on_pitch). The law it replaced moved the pitch by increments 0.3-0.5 s apart, none while the
-- attitude was 0.5 deg behind, averaged over 10 updates: resuming the climb at 8,950 ft on p35-line1 (EIDW, 233 t,
-- 2026-10-20) it pitched up at about 0.4 deg/s 4-6 s after the A/T added climb thrust and the IAS went from 251 to
-- 271 kt; FLCH at idle from FL310 on p34-L1 (TST744L) pitched down at 0.08 deg/s and fell 26 kt below M .84's speed;
-- accelerating from 250 to 326 kt at 10,000 ft on p34-L1 it kept 22-31 % of the 2,234 fpm climb, where 744s in ADS-B
-- keep 40-55 % (median 47 %) at 0.45-0.77 kt/s.
-- [P45] The thrust's lead: the integrator also turns the path with the thrust over the weight (T/W) through a 2 s
-- filter, except with the A/T in SPD. On its own the integrator followed a thrust ramp with a steady error: resuming
-- the climb with the A/T's 20 s to climb thrust (P44) the IAS 11 kt over the target, 9.4 kt with 30 s, where 744s in
-- ADS-B are 3 kt (0-6) over.
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
-- [P45] T/W and the thrust's lead
local tw_of, lead = controls.speed_pitch_thrust_weight, controls.speed_pitch_thrust_lead
if type(tw_of) ~= "function" or type(lead) ~= "function" then
    check(false, "the thrust lead's helpers (speed_pitch_thrust_weight, speed_pitch_thrust_lead)")
else
    near(tw_of({[0] = 100000, 100000, 100000, 100000}, 200000), 400000 / (200000 * 9.80665), 1e-12,
        "T/W: the four engines' thrust over the weight")
    check(tw_of({[0] = 100000, 100000, 100000, 100000}, 0) == nil, "T/W: no mass (XTLua's first read of 0)")
    check(tw_of(nil, 200000) == nil, "T/W: no thrust dataref")
    -- the four engines together: 4 x the second-highest engine's thrust while the lowest is within 15 % of it (at
    -- least 5 kN); an engine apart (a failure, a lever) leaves T/W unknown and the law flies without the lead, as P43.
    -- Fed the sum an engine failure took the climb to -100 fpm (review 46's MAJOR-1); the two middle engines' mean read
    -- a second failure at twice its size (review 46b's MINOR-1); the second-highest engine's alone read the engines
    -- left at 4/3 after one failure and 2x after two (review 46b's NIT-1, review 46c's MINOR-1)
    near(tw_of({[0] = 95000, 100000, 105000, 108000}, 200000), 420000 / (200000 * 9.80665), 1e-12,
        "T/W: 4 x the second-highest engine (the sum would be 408 kN, the middle pair's 410)")
    near(tw_of({[0] = 3000, 5000, 6000, 6000}, 200000), 24000 / (200000 * 9.80665), 1e-12,
        "T/W: at idle the engines within 5 kN")
    -- an engine failed at idle, at 0 or windmilling below the others: apart beyond the 5 kN (review 47's NIT-3)
    check(tw_of({[0] = 0, 6000, 6000, 6000}, 200000) == nil, "T/W: at idle one engine at 0, none")
    check(tw_of({[0] = -14000, -8000, -8000, -8000}, 200000) == nil, "T/W: at idle one engine windmilling, none")
    check(tw_of({[0] = 100000, 100000, 100000, 0}, 200000) == nil, "T/W: one engine failed, none")
    check(tw_of({[0] = 80000, 100000, 100000, 100000}, 200000) == nil, "T/W: one engine 20 % apart, none")
    check(tw_of({[0] = 0, 100000, 0, 100000}, 200000) == nil, "T/W: two engines failed, none")
    -- an engine apart above the others too (three levers pulled back, one left forward: the three read at 4/3; review
    -- 47's NIT-1): the whole spread within it
    check(tw_of({[0] = 100000, 100000, 100000, 120000}, 200000) == nil, "T/W: one engine 20 % above, none")
    -- once apart, together again only within 8 % (at least 2.5 kN): an engine parked at the 15 % edge turned the lead on
    -- and off with the others' jitter, and every restart left a pitch-down (review 47's MINOR-1)
    local tw, apart = tw_of({[0] = 90000, 100000, 100000, 100000}, 200000, true)
    check(tw == nil and apart == true, "T/W: apart, 10 % is still apart")
    tw, apart = tw_of({[0] = 90000, 100000, 100000, 100000}, 200000, false)
    near(tw, 400000 / (200000 * 9.80665), 1e-12, "T/W: together, 10 % is still together")
    check(apart == false, "T/W: together, 10 %: not apart")
    tw, apart = tw_of({[0] = 93000, 100000, 100000, 100000}, 200000, true)
    near(tw, 400000 / (200000 * 9.80665), 1e-12, "T/W: apart, 7 % is together again")
    -- the rejoin's 2.5 kN floor at idle (review 48's NIT-5): a 3.5 kN spread is together from together, still apart from
    -- apart; 2 kN is together again
    tw = tw_of({[0] = -11500, -8000, -8000, -8000}, 200000, false)
    near(tw, -32000 / (200000 * 9.80665), 1e-12, "T/W: idle, 3.5 kN apart from together: together")
    check(tw_of({[0] = -11500, -8000, -8000, -8000}, 200000, true) == nil, "T/W: idle, 3.5 kN apart from apart: apart")
    tw = tw_of({[0] = -10000, -8000, -8000, -8000}, 200000, true)
    near(tw, -32000 / (200000 * 9.80665), 1e-12, "T/W: idle, 2 kN apart from apart: together again")
    local f, r = lead(nil, nil, 0.2, 0.1)
    check(f == 0.2 and r == 0, "lead: the filter starts from T/W, no rate")
    f, r = lead(0.2, 0.2, 0.21, 0.1)
    near(f, 0.2 + 0.01 * 0.1 / 2, 1e-12, "lead: T/W through a 2 s first order")
    near(r, math.deg(0.01 * 0.1 / 2) / 0.1, 1e-9, "lead: the path's rate from the filtered change")
    -- a decrease leads at half the rate once the filtered T/W is 0.005 below its peak (review 46's MINOR-1), at the
    -- full rate before, so that a jitter is led alike both ways (review 46b's MINOR-2)
    local p
    f, r, p = lead(0.2, 0.2, 0.19, 0.1, 0.2)
    near(r, math.deg(-0.01 * 0.1 / 2) / 0.1, 1e-9, "lead: a dip near the peak at the full rate")
    near(p, 0.2 - 0.005 / 3 * 0.1, 1e-12, "lead: the peak decays 0.005 in 3 s")
    f, r, p = lead(0.194, 0.19, 0.19, 0.1, 0.2)
    near(r, 0.5 * math.deg(-0.004 * 0.1 / 2) / 0.1, 1e-9, "lead: a decrease 0.006 below the peak at half the rate")
    f, r, p = lead(0.2, 0.2, 0.21, 0.1, 0.2)
    near(p, f, 1e-12, "lead: the peak follows a rise")
    f, r = lead(0.2, 0.0, 0.25, 0.1)
    check(f == 0.25 and r == 0, "lead: a first read of 0, then 0.25 in 0.1 s: the filter starts again, no rate")
    f, r = lead(0.2, 0.2, nil, 0.1)
    check(f == nil and r == 0, "lead: no T/W")
    -- the A/T's 20 s to climb thrust at 233 t, 0.0054 T/W a second: after 10 s the path's rate within 1 % of it
    local filtered, previous, tw = 0.10, 0.10, 0.10
    for _ = 1, 100 do
        tw = tw + 0.00054
        filtered, r = lead(filtered, previous, tw, 0.1)
        previous = tw
    end
    near(r, math.deg(0.0054), math.deg(0.0054) * 0.01, "lead: a 20 s thrust ramp's path rate after 10 s")
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
-- [P45] on speed and steady at 233 t, the thrust rising 0.0054 T/W a second (the A/T's 20 s to climb thrust): in THR
-- REF the pitch rises with it, the IAS still (5 s: 0.31 deg/s behind the 2 s filter, about 1 deg); with the A/T in SPD
-- the thrust's lead stays out
-- [review 46 MINOR-2] With the A/T in IDLE the EEC's speed loop (spd_throttle below its minimum safe speed) may add
-- thrust for the speed too: the lead takes only the thrust's decreases there
for _, at_mode in ipairs({5, 3, 2}) do
    local thrust = {[0] = 50000, 50000, 50000, 50000}
    local env = new_director({simDR_engine_thrust_n = thrust, simDR_acf_weight_total_kg = 233000,
        B747DR_ap_FMA_autothrottle_mode = at_mode})
    step(env, 4, 0.1)
    local before = env.B747_afds_pitch_target_before_blend
    for _ = 1, 50 do
        for i = 0, 3 do thrust[i] = thrust[i] + 0.0054 * 233000 * 9.80665 / 4 * 0.1 end
        step(env, 4, 0.1, 0)
    end
    local rise = env.B747_afds_pitch_target_before_blend - before
    if at_mode == 5 then
        check(rise >= 0.85 and rise <= 1.1, "THR REF: the pitch follows the thrust ("..rise.." deg in 5 s)")
    else
        near(rise, 0, 1e-6, (at_mode == 3 and "A/T in SPD" or "A/T in IDLE, the thrust rising")
            ..": the thrust's lead stays out")
    end
end
-- [review 46b NIT-2] ... and in IDLE a falling thrust (the A/T's retard to idle) still leads, down: FLCH SPD descending
-- to an MCP altitude below at -1,500 fpm, the thrust falling 0.0054 T/W a second for 5 s, the pitch down (half the
-- rate once it is a real decrease)
do
    local thrust = {[0] = 150000, 150000, 150000, 150000}
    local env = new_director({simDR_engine_thrust_n = thrust, simDR_acf_weight_total_kg = 233000,
        B747DR_ap_FMA_autothrottle_mode = 2, simDR_vvi_fpm_pilot = -1500, simDR_autopilot_altitude_ft = 3000,
        simDR_autopilot_hold_altitude_ft = 3000, simDR_autopilot_flch_status = 2})
    step(env, 8, 0.1)
    local before = env.B747_afds_pitch_target_before_blend
    for _ = 1, 50 do
        for i = 0, 3 do thrust[i] = thrust[i] - 0.0054 * 233000 * 9.80665 / 4 * 0.1 end
        step(env, 8, 0.1, 0)
    end
    local drop = before - env.B747_afds_pitch_target_before_blend
    -- 0.78 deg: led at the full rate until 0.005 below the peak, then at half (all at the full rate 0.98, all at half
    -- 0.49; review 46c)
    check(drop >= 0.6 and drop <= 0.9, "A/T in IDLE, the thrust falling: the pitch down with it ("..drop.." deg in 5 s)")
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
local function fly(rows, t0, span, fps, cap_kt, cap_ft, thrust)
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
        thrust = thrust or function(t) return interp(rows, t0 + t, "thrust") end,
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
-- [P45] p35-line1's climb resumption with the thrust's rise (48 -> 114 kN an engine from 1.5 s, 4.5 s as recorded)
-- stretched to rise_s, as the A/T brings it in since P44
local function stretched(rise_s)
    return function(t)
        local start, recorded = 1.5, 4.5
        if t <= start then return interp(P35, 505 + t, "thrust") end
        if t <= start + rise_s then return interp(P35, 505 + start + (t - start) * recorded / rise_s, "thrust") end
        return interp(P35, 505 + t - rise_s + recorded, "thrust")
    end
end
for _, fps in ipairs({15, 20, 34}) do
    local at = string.format(" (%d fps)", fps)
    -- a. p35-line1 resuming the climb at 8,948 ft: VNAV PTH -> VNAV SPD, the A/T to THR REF (the thrust from 48 to
    -- 114 kN an engine in 6 s), VNAV's 250 kt (P42 caps it there; it rose to 255 kt with the IAS). The old law: the
    -- attitude up 0.9 deg in the first 8 s, the IAS to 271.1 kt; P43 alone 18.0-18.1 kt over.
    local m = fly(P35, 505, 70, fps, 250, 10100)
    local s = CM.summary(m, 0, 50)
    near(m.hyd.MODEL_director_state().sample_rate, 0.1, 1e-9, "VNAV SPD: the director samples every 0.1 s"..at)
    local base, rise = CM.at(m, 0).theta, CM.at(m, 8).theta
    check(rise - base >= 1.5, "re-climb: the attitude up 1.5 deg within 8 s"..at..string.format(": %.2f", rise - base))
    check(s.over <= 17, "re-climb: the IAS at most 17 kt over 250"..at..string.format(": %+.1f kt", s.over))
    check(s.reversals <= 1 and s.rate <= 0.6 and s.nz <= 0.16, "re-climb: smooth"..at
        ..string.format(": %d F/D reversals, %.2f deg/s, %.3f g", s.reversals, s.rate, s.nz))
    -- a2. [P45] the same with the recorded thrust rise stretched over 20 s (about the A/T's since P44, a lever ramp) and
    -- 30 s: P43 alone 10.9-11.0 and 9.3-9.4 kt over. Over 50 s the largest nz is the 10,000 ft acceleration's pitch-down
    -- at about 40 s (the target 290 kt from 29 s): 0.163 g at 15 fps with the lead, 0.148 without it, 0.13 at 20 and
    -- 34 fps; the resumption's own (0-25 s) is 0.12-0.13 g (review 46).
    for _, case in ipairs({{20, 7.5}, {30, 5.0}}) do
        m = fly(P35, 505, 70, fps, 250, 10100, stretched(case[1]))
        s = CM.summary(m, 0, 50)
        check(s.over <= case[2], string.format("re-climb, the thrust over %d s: the IAS at most %.1f kt over 250%s: %+.1f kt",
            case[1], case[2], at, s.over))
        check(s.reversals <= 1 and s.nz <= 0.17, string.format("re-climb, the thrust over %d s: smooth%s: %d F/D "
            .."reversals, %.3f g", case[1], at, s.reversals, s.nz))
        s = CM.summary(m, 0, 25)
        check(s.nz <= 0.15, string.format("re-climb, the thrust over %d s: the resumption's nz%s: %.3f g", case[1], at,
            s.nz))
    end
    -- b. p34-L1 FLCH SPD from ALT at FL310 (MCP FL270), the A/T at idle from 2 s, M .84's speed rising 302 -> 310 kt
    -- as it descends, then 283 kt from 48 s. The old law: 25.5 kt below; P43 alone 7.9 (the A/T's retard now pitches
    -- down with it, P45).
    m = fly(P34, 2094, 82, fps)
    local lowest, highest_vs = math.huge, -math.huge
    for _, p in ipairs(m.track) do
        if p.t < 47 then lowest = math.min(lowest, p.ias - p.target) end
        if p.t > 5 then highest_vs = math.max(highest_vs, p.vs) end
    end
    check(lowest >= -6.5, "FLCH at idle: within 6.5 kt of M .84's speed"..at..string.format(": %.1f kt", lowest))
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
    -- the IAS 3 kt up within 16 s of the step, the thrust coming back to CLB in it. The old law: 23 s; P43 alone 18.
    m = fly(P35, 280, 60, fps)
    local step_t, ias0, up_t
    for _, p in ipairs(m.track) do
        if not step_t and p.target >= 190 then step_t, ias0 = p.t, p.ias end
        if step_t and not up_t and p.ias >= ias0 + 3 then up_t = p.t - step_t end
    end
    check(up_t and up_t <= 16, "flaps up: accelerating within 16 s of the step"..at..": "..tostring(up_t))
end

-- 4. [P45, review 46] The lead with the thrust going down. trim: the thrust an engine for a steady path (deg) at an IAS,
-- altitude, weight and flaps; path_for: the path a thrust an engine holds.
local AM = dofile("tests/approach_model.lua")
local G, KT, S = 9.80665, 0.514444, 541.2
local function trim(alt, ias, mass, gamma_deg, flaps)
    local temp, _, rho = CM.isa(alt)
    local V = ias * KT * math.sqrt(1.225 / rho)
    local mach = V / math.sqrt(1.4 * 287.05 * temp)
    local p = (flaps and flaps > 0) and AM.polar(flaps) or CM.clean_polar(mach)
    local q = 0.5 * rho * V * V
    local gamma = math.rad(gamma_deg or 0)
    local cl = mass * G * math.cos(gamma) / (q * S)
    return (q * S * (p[3] + p[4] * cl * cl) + mass * G * math.sin(gamma)) / 4, V
end
local function path_for(alt, ias, mass, flaps, thrust_engine)
    local lo, hi = -10, 30
    for _ = 1, 60 do
        local mid = (lo + hi) / 2
        if trim(alt, ias, mass, mid, flaps) > thrust_engine then hi = mid else lo = mid end
    end
    return (lo + hi) / 2
end
-- a steady climb at the target (V2 + 10, flaps 20) on thrust(t) (N an engine or the four engines'), in TO/GA from the
-- takeoff state (a ground frame) or in VNAV SPD
local function climb_on(mode, alt, mass, v2, thrust_engine, thrust, fps, at_mode)
    local target = v2 + 10
    local gamma = path_for(alt, target, mass, 0.667, thrust_engine)
    local _, V = trim(alt, target, mass, gamma, 0.667)
    return CM.fly({alt_ft = alt, ias_kt = target, vs_fpm = V * math.sin(math.rad(gamma)) / 0.3048 * 60, weight_kg = mass,
        flaps = 0.667, pitch_mode = mode, target_kt = target, mcp_alt_ft = 37000, seconds = 60, dt = 1 / fps,
        vmc_kt = v2 - 10, vmax_kt = 250, thrust = thrust, at_mode = at_mode,
        setup = function(mm)
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = v2, v2
            if mode == 1 then mm.d.simDR_touchGround = 1 end
        end,
        frame = function(mm, t)
            if mode == 1 then
                if t > 0 then mm.d.simDR_touchGround = 0 else mm.d.simDR_AHARS_pitch_heading_deg_pilot = 0 end
            end
            mm.d.B747DR_ap_FMA_active_pitch_mode = mode
            mm.target_kt = target
        end})
end
for _, fps in ipairs({20, 34}) do
    -- a. An engine failure at 20 s (its thrust down with a 1.5 s first order) at 397 t, V2 175, 800 ft, the takeoff
    -- thrust such that three engines hold 400 fpm at V2 + 10. Fed the sum of the four, the lead took the director down
    -- at the law's 0.1 g, the attitude past it, and the climb to -90 to -106 fpm in TO/GA and VNAV SPD for about 5 s
    -- (P43 alone: about +200); the speed it keeps is the integrator's (review 46's MAJOR-1).
    local mass, v2, alt = 397000, 175, 800
    local _, V = trim(alt, v2 + 10, mass, 0, 0.667)
    local T = trim(alt, v2 + 10, mass, math.deg(math.asin(400 * 0.3048 / 60 / V)), 0.667) * 4 / 3
    for _, mode in ipairs({1, 4}) do
        local m = climb_on(mode, alt, mass, v2, T, function(t)
            local failed = t < 20 and T or T * math.exp(-(t - 20) / 1.5)
            return {[0] = T, T, T, failed}
        end, fps, mode == 1 and 1 or 5)
        local vs_min = math.huge
        for _, p in ipairs(m.track) do if p.t >= 20 then vs_min = math.min(vs_min, p.vs) end end
        check(vs_min >= 100, string.format("engine failure at 397 t (400 fpm on three, %s, %d fps): still climbing, V/S "
            .."at least %+.0f fpm", mode == 1 and "TO/GA" or "VNAV SPD", fps, vs_min))
    end
    -- a2. Two engines failing on one side, at 20 s and 30 s (each down with a 1.5 s first order), from full takeoff
    -- thrust (230 kN an engine) at 300 t, V2 160, 1,200 ft: the second failure was read at twice its size (the two
    -- middle engines' mean) on top of the integrator's recovery from the first, and the climb went to -1 / -33 fpm
    -- (P43 alone: +271 / +297; review 46b's MINOR-1)
    for _, mode in ipairs({1, 4}) do
        local T2 = 230000
        local m = climb_on(mode, 1200, 300000, 160, T2, function(t)
            local first = t < 20 and T2 or T2 * math.exp(-(t - 20) / 1.5)
            local second = t < 30 and T2 or T2 * math.exp(-(t - 30) / 1.5)
            return {[0] = first, second, T2, T2}
        end, fps, mode == 1 and 1 or 5)
        local vs_min = math.huge
        for _, p in ipairs(m.track) do if p.t >= 30 then vs_min = math.min(vs_min, p.vs) end end
        check(vs_min >= 100, string.format("two engines failing at 300 t (%s, %d fps): still climbing after the second, "
            .."V/S at least %+.0f fpm", mode == 1 and "TO/GA" or "VNAV SPD", fps, vs_min))
    end
    -- a3. Engine-out go-arounds (afds_toga_speed_test's: 1,000 ft on a 3 deg approach, flaps 30 -> 20 at 3 s, the gear
    -- up from 8 s; the running engines from the approach's thrust to 185 kN over 4.5 s): with the engines left read at
    -- 4/3 or 2x, the lead pitched up for thrust it did not have, the IAS 2.4 kt (one engine out, 285 t) and 6.3 kt (two
    -- out, 250 t) lower than P43 alone (reviews 46b, 46c). Without the lead after a failure: as P43, within 1 kt.
    local function go_around_out(out, mass_t, ias0, lead)
        local alt, weight = 1000, mass_t * 1000
        local gamma = math.rad(-3)
        local rho = 1.225 * ((288.15 - 0.0019812 * alt) / 288.15) ^ 4.2559
        local V0 = ias0 * KT * math.sqrt(1.225 / rho)
        local p = AM.polar(1.0)
        local q = 0.5 * rho * V0 * V0
        local cl = weight * G * math.cos(gamma) / (q * S)
        local gear = 0.05 * q * S
        local running = 4 - out
        local approach = ((q * S * (p[3] + p[4] * cl * cl) + weight * G * math.sin(gamma)) + gear) / running
        local m = CM.fly({alt_ft = alt, ias_kt = ias0, vs_fpm = V0 * math.sin(gamma) / 0.3048 * 60, weight_kg = weight,
            flaps = 1.0, pitch_mode = 1, target_kt = ias0, mcp_alt_ft = 3000, seconds = 40, dt = 1 / fps,
            vmc_kt = 130, vmax_kt = 230, at_mode = 5,
            thrust = function(t)
                local x = math.max(0, math.min(1, (t - 0.5) / 4.5))
                local f = x * x * (3 - 2 * x)
                local gear_drag = gear / running * (t < 8 and 1 or math.max(0, 1 - (t - 8) / 10))
                local e = approach + (185000 - approach) * f - gear_drag
                local engines = {[0] = e, e, e, e}
                for i = running, 3 do engines[i] = 0 end
                return engines
            end,
            setup = function(mm)
                if not lead then mm.controls.SPEED_PITCH_THRUST_FEED_FORWARD = 0 end
                mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 999, ias0
                mm.d.simDR_touchGround = 0
                mm.d.B747DR_autopilot_TOGA_status = 1
            end,
            frame = function(mm, t)
                if t > 3 then mm.state.flap = 0.667 end
                mm.d.B747DR_ap_FMA_active_pitch_mode = (mm.d.B747DR_autopilot_TOGA_status == 1) and 1
                    or (mm.d.simDR_autopilot_alt_hold_status == 2 and 9 or 1)
            end})
        local low = math.huge
        for _, pt in ipairs(m.track) do if pt.t <= 39 then low = math.min(low, pt.ias - pt.target) end end
        return low
    end
    for _, case in ipairs({{1, 285, 156}, {2, 250, 150}}) do
        local with_lead, without = go_around_out(case[1], case[2], case[3], true),
            go_around_out(case[1], case[2], case[3], false)
        check(math.abs(with_lead - without) <= 1.0, string.format("go-around with %d engine(s) out at %d t (%d fps): "
            .."the lowest IAS within 1 kt of P43's: %+.1f against %+.1f kt", case[1], case[2], fps, with_lead, without))
    end
    -- b. The takeoff's thrust reduction at 10 s (190 kN an engine -> 82 % over a 1.5 s first order) at 233 t, V2 144,
    -- 1,200 ft, the four engines alike: the lead took the director down at 0.7-1.0 deg/s and the attitude went 1.9 deg
    -- below where it settled, -0.104 g (P43 alone: 0.02 deg, -0.055 g, but the IAS 6.3 kt low; review 46's MINOR-1).
    -- At half the rate once it is a real decrease (0.005 below the peak): 0.8-1.04 deg, -0.084 to -0.089 g.
    for _, mode in ipairs({4, 1}) do
        local T0 = 190000
        local m = climb_on(mode, 1200, 233000, 144, T0, function(t)
            if t < 10 then return T0 end
            return T0 * (0.82 + 0.18 * math.exp(-(t - 10) / 1.5))
        end, fps, 5)
        local low, nz = math.huge, 0
        for _, p in ipairs(m.track) do
            if p.t >= 10 then low, nz = math.min(low, p.theta), math.min(nz, p.nz) end
        end
        local settled = CM.at(m, 50).theta
        check(settled - low <= 1.1 and nz >= -0.095, string.format("thrust reduction at 233 t (%s, %d fps): the attitude "
            .."at most 1.1 deg below where it settles, nz at least -0.095 g: %.2f deg, %+.3f g",
            mode == 1 and "TO/GA" or "VNAV SPD", fps, settled - low, nz))
    end
end

-- c. X-Plane's thrust jitters as the A/T works the levers (p35-line1's takeoff: 1.7 kN rms an engine per 0.25 s, most of
-- it at 0.2-0.6 Hz). A decrease led at half the rate and an increase at the full one turn a jitter into a steady
-- pitch-up, and the integrator holds it with the IAS low: in the takeoff climb (TO/GA, 233 t, V2 144, 1,200 ft,
-- 190 kN an engine) with the recorded jitter at twice its size the mean IAS sat about 2 kt lower than with P43 alone
-- (reviews 46b, 46c). The jitter: tests/data/p35-line1_takeoff.csv's thrust at takeoff thrust (to 283 s, before the
-- thrust reduction at 285-289 s, which the 4 s mean would leave as a +4 / -3 kN doublet; review 47) less its 4 s centred
-- mean, looped, the four engines together.
local TAKEOFF = {}
for _, r in ipairs(load_csv("tests/data/p35-line1_takeoff.csv")) do
    if r.t <= 283 then TAKEOFF[#TAKEOFF + 1] = r end
end
local takeoff_jitter = {}
for i, r in ipairs(TAKEOFF) do
    local sum, n = 0, 0
    for j = math.max(1, i - 8), math.min(#TAKEOFF, i + 8) do sum, n = sum + TAKEOFF[j].thrust, n + 1 end
    takeoff_jitter[i] = r.thrust - sum / n
end
local function recorded_jitter(t)
    local x = (t % (#takeoff_jitter * 0.25)) / 0.25 + 1
    local i = math.floor(x)
    local a, b = takeoff_jitter[i], takeoff_jitter[i % #takeoff_jitter + 1]
    return a + (b - a) * (x - i)
end
local function jitter_climb(fps, lead, parked)
    local T0 = 190000
    local function jitter(t)
        if t < 20 then return 0 end
        return 2 * recorded_jitter(t - 20)
    end
    local target = 154
    local gamma = path_for(1200, target, 233000, 0.667, T0)
    local _, V = trim(1200, target, 233000, gamma, 0.667)
    local m = CM.fly({alt_ft = 1200, ias_kt = target, vs_fpm = V * math.sin(math.rad(gamma)) / 0.3048 * 60,
        weight_kg = 233000, flaps = 0.667, pitch_mode = 1, target_kt = target, mcp_alt_ft = 37000, seconds = 120,
        dt = 1 / fps, vmc_kt = 134, vmax_kt = 250, at_mode = 5,
        thrust = function(t)
            local e = T0 + jitter(t)
            if not parked then return e end
            return {[0] = (1 - parked) * T0, e, e, e}
        end,
        setup = function(mm)
            if not lead then mm.controls.SPEED_PITCH_THRUST_FEED_FORWARD = 0 end
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 144, 144
            mm.d.simDR_touchGround = 1
        end,
        frame = function(mm, t)
            if t > 0 then mm.d.simDR_touchGround = 0 else mm.d.simDR_AHARS_pitch_heading_deg_pilot = 0 end
            mm.d.B747DR_ap_FMA_active_pitch_mode = 1
            mm.target_kt = target
        end})
    local sum, n = 0, 0
    for _, p in ipairs(m.track) do
        if p.t >= 30 then sum, n = sum + (p.ias - target), n + 1 end
    end
    return sum / n
end
for _, fps in ipairs({20, 34}) do
    local with_lead, without = jitter_climb(fps, true), jitter_climb(fps, false)
    check(math.abs(with_lead - without) <= 0.3, string.format("thrust jitter in the takeoff climb (%d fps): the mean IAS "
        .."within 0.3 kt of P43's: %+.2f against %+.2f kt", fps, with_lead, without))
    -- one engine parked 13 % below the others (a partial loss of power, a lever split by hand), the others with the
    -- jitter: at the gate's edge it turned the lead on and off, the IAS 6.4 kt fast (review 47's MINOR-1)
    with_lead, without = jitter_climb(fps, true, 0.13), jitter_climb(fps, false, 0.13)
    check(math.abs(with_lead - without) <= 0.5, string.format("an engine parked 13 %% below, the others jittering (%d "
        .."fps): the mean IAS within 0.5 kt of P43's: %+.2f against %+.2f kt", fps, with_lead, without))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS speed on pitch tests passed: "..checks)
