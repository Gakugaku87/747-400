-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The G/S law of the hydraulics flight director. getGlideSlopeFPM: the V/S
-- of the glide slope at the ground speed, corrected by the deviation in feet
-- - about dots x 0.1 x the height on a 3 deg slope (0.3 deg a dot) - so that
-- a deviation goes in about 24 s at any height: 0.25 x the radio altitude fpm
-- a dot, at least 75 (near the ground, as before) and at most 1,000 fpm in
-- all, not tripled beyond 2 dots (2.3 dots below at 447 ft on EHAM's ILS 18R,
-- p32-line1, that asked for a climb and the 747 went 2.5 dots above). With 75
-- fpm a dot everywhere, a capture 0.75 dot above the beam (190 ft at 8 nm)
-- stayed 0.8 dot above to 500 ft in the approach model.
-- [P37] The director flies that V/S as a flight path angle by a PI law: every
-- 0.1 s the path angle the 747 is short of (glide_slope_path_error_deg: the
-- target V/S at the ground speed against the V/S from the elevation's rate
-- since the last update, at most GS_MAX_PATH_ERROR_DEG) moves an integrator
-- by GS_PATH_KI of it a second, from the director's pitch when G/S began (its
-- first update holds that pitch), and the pitch is the integrator plus
-- GS_PATH_KP of it, less GS_PITCH_RATE_DAMPING x the attitude's rate; it
-- starts again after a second without G/S, and with the servos off the
-- integrator stays within 2 deg of the attitude. The VSI-step law it replaces
-- hunted around the beam with the pitch loop; local_vy, which it used first,
-- is tilted from the vertical in X-Plane's local frame (review 43).
-- The production code runs with mocked simulator interfaces.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function near(actual, expected, tolerance, message)
    check(type(actual) == "number" and math.abs(actual - expected) <= tolerance,
        message..": expected "..tostring(expected).." +/- "..tostring(tolerance)..", got "..tostring(actual))
end
local function slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")

-- The director at 150 kt ground speed on a 3 deg glide slope, height ft above the runway, dots above the beam.
local function glide_slope_fpm(height, dots)
    local env = setmetatable({print = function() end, B747_afds_controls = controls, debug_flight_directors = 0,
        simDRTime = 3600, simDR_groundspeed = 150 * 0.514444, simDR_glideslope1 = 3,
        simDR_hsi_vdef_dots_pilot = dots, simDR_radarAlt1 = height}, {__index = _G})
    setfenv(assert(loadstring(director_source)), env)()
    return env.getGlideSlopeFPM()
end
local NOMINAL = -math.tan(math.rad(3)) * 150 * 0.514444 * 196.85

near(glide_slope_fpm(2000, 0), NOMINAL, 0.01, "on the beam: its V/S")
near(glide_slope_fpm(2000, 1), NOMINAL - 500, 0.01, "1 dot above at 2,000 ft: 500 fpm more")
near(glide_slope_fpm(1000, -1), NOMINAL + 250, 0.01, "1 dot below at 1,000 ft: 250 fpm less")
near(glide_slope_fpm(200, 1), NOMINAL - 75, 0.01, "200 ft: 75 fpm a dot, as before")
near(glide_slope_fpm(3000, 1.5), NOMINAL - 1000, 0.01, "1.5 dots at 3,000 ft: at most 1,000 fpm")
near(glide_slope_fpm(1000, -2.5), NOMINAL + 625, 0.01, "full scale below at 1,000 ft: 625 fpm less, not tripled")
near(glide_slope_fpm(447, -2.3), NOMINAL + 2.3 * 0.25 * 447, 0.01, "2.3 dots below at 447 ft: 257 fpm less, not tripled")

-- the path angle the 747 is short of: the target V/S (fpm) at the ground speed (m/s) against the inertial V/S (m/s)
local GS = 150 * 0.514444
local path_error = controls.glide_slope_path_error_deg
check(type(path_error) == "function", "glide_slope_path_error_deg")
if type(path_error) == "function" then
    near(path_error(-800, -800 * 0.00508, GS), 0, 1e-9, "on the target V/S: no path error")
    near(path_error(-800, -900 * 0.00508, GS), math.deg(math.atan2(-800 * 0.00508, GS) - math.atan2(-900 * 0.00508, GS)),
        1e-9, "100 fpm too steep: the angle up")
    check(path_error(-800, -900 * 0.00508, GS) > 0.36 and path_error(-800, -900 * 0.00508, GS) < 0.38,
        "100 fpm too steep at 150 kt: about 0.37 deg up")
    check(path_error(-800, 0, GS) < -2.9, "level against the beam's V/S: about 3 deg down")
    near(path_error(-800, -4, 0), path_error(-800, -4, 30), 1e-9, "the ground speed at least 30 m/s")
    near(path_error(nil, nil, nil), 0, 1e-9, "no numbers: no path error")
end
check(controls.GS_PATH_KP == 0.3 and controls.GS_PATH_KI == 0.3 and controls.GS_PITCH_RATE_DAMPING == 1.0
    and controls.GS_MAX_PATH_ERROR_DEG == 1.5,
    "the PI law's gains 0.3 and 0.3 a second, the pitch rate's 1.0 s, the path error at most 1.5 deg")

-- The director in G/S and VNAV PTH (ap_director_pitch_integral as ap_pitch_assist runs it every frame,
-- approach_model.lua's loader), at 1,500 ft, 150 kt over the ground, on the beam, the elevation going down 104 fpm
-- steeper than the beam (the VSI too; and the V/S target). The attitude follows the director's raw pitch
-- ("follow"), stays where it is (nil) or is a function of the time in the mode; d.vs_fpm sets the vertical speed.
local model = dofile("tests/approach_model.lua")
local function director(setup)
    local d = {}
    local _, hyd = model.load(d)
    model.set_datarefs(d, model.eham(), 0.3)
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 1500, 1500
    d.simDR_groundspeed, d.simDR_ind_airspeed_kts_pilot = GS, 150
    d.simDR_hsi_vdef_dots_pilot = 0
    d.vs_fpm = -900
    d.simDR_vvi_fpm_pilot, d.simDR_elevation = -900, 1500 * 0.3048
    d.simDR_autopilot_vs_fpm = NOMINAL
    d.simDR_autopilot_altitude_ft, d.simDR_autopilot_hold_altitude_ft = 0, 0     -- no altitude to capture
    d.B747DR_flap_ratio, d.B747DR_airspeed_Vmc = 1, 130
    hyd.MODEL_init_director(0)
    d.simDR_AHARS_pitch_heading_deg_pilot = 0
    if setup then setup(d) end
    local function fly(mode, duration, attitude)
        d.B747DR_ap_FMA_active_pitch_mode = mode
        local t0 = d.simDRTime
        local theta0 = d.simDR_AHARS_pitch_heading_deg_pilot
        while d.simDRTime < t0 + duration - 1e-9 do
            d.simDRTime = d.simDRTime + 0.05
            d.simDR_elevation = d.simDR_elevation + d.vs_fpm * 0.00508 * 0.05
            if type(attitude) == "function" then
                d.simDR_AHARS_pitch_heading_deg_pilot = theta0 + attitude(d.simDRTime - t0)
            end
            hyd.ap_director_pitch_integral()
            if attitude == "follow" then d.simDR_AHARS_pitch_heading_deg_pilot = hyd.MODEL_director_state().raw end
        end
        return hyd.MODEL_director_state().raw
    end
    return fly, d
end
local error104 = path_error and path_error(NOMINAL, -900 * 0.00508, GS) or 0
do
    -- G/S from VNAV PTH's pitch, the attitude held: the first update holds it, then the integrator moves 0.3 x the
    -- error a second, the pitch 0.3 x the error above it
    local fly = director()
    local before = fly(6, 2, "follow")
    local first = fly(2, 0.05)
    near(first - before, 0, 0.001, "G/S's first update: VNAV PTH's pitch")
    local after10 = fly(2, 10)
    near(after10 - before, 0.3 * error104 + 0.3 * error104 * 10, 0.06,
        "G/S, 104 fpm too steep at 150 kt for 10 s: 0.3 x the error + 0.3 x the error a second")
end
do
    -- the error gone: the pitch stays where the integrator is
    local fly, d = director()
    fly(2, 5)
    d.vs_fpm = NOMINAL
    local a = fly(2, 0.3)
    local b = fly(2, 5)
    near(b - a, 0, 0.01, "G/S on the beam's V/S: the pitch holds")
end
do
    -- the attitude rising at 1 deg/s on the beam's V/S: the pitch 1 deg lower than with the attitude held
    local fly, d = director()
    fly(2, 5)
    d.vs_fpm = NOMINAL
    local held = fly(2, 0.5)
    local rising = fly(2, 1, function(t) return t end)
    near(rising - held, -1.0, 0.06, "G/S, the attitude rising at 1 deg/s: 1 deg less pitch")
end
do
    -- level against the beam's V/S (about 3 deg short): at most 1.5 deg of path error, 0.45 deg of pitch at once
    local fly, d = director()
    fly(2, 5)
    d.vs_fpm = NOMINAL
    local held = fly(2, 0.5)
    d.vs_fpm = 0
    local level = fly(2, 0.25)
    check(level - held < -0.4 and level - held > -0.6, string.format(
        "G/S, level against the beam's V/S: the error limited to 1.5 deg, %.2f deg at once (0.89 without)", level - held))
end
do
    -- a second without G/S: it starts again from the director's pitch of the mode in between
    local fly = director()
    fly(2, 5)
    local vnav = fly(6, 1.5, "follow")
    local again = fly(2, 0.05)
    near(again - vnav, 0, 0.001, "G/S again after 1.5 s of VNAV PTH: from VNAV PTH's pitch")
end
do
    -- the integrator held within the director's pitch limits (-10, +10): far too steep for a minute, then level
    local fly, d = director(function(d) d.vs_fpm = -5000 end)
    local long = fly(2, 60)
    near(long, 10, 0.01, "G/S far too steep for a minute: at most 10 deg")
    d.vs_fpm = 0
    local back = fly(2, 0.25)
    near(back, 10 - 0.3 * 1.5 - 0.3 * 1.5 * 0.15, 0.06,
        "then level: at once 0.3 x the limited path error below 10 deg (the integrator not wound up past it)")
end
do
    -- the servos off (the flight director alone), the attitude held at 0: the integrator within 2 deg of it
    local fly, d = director(function(d) d.vs_fpm = -5000; d.simDR_autopilot_servos_on = 0 end)
    local fd = fly(2, 30)
    near(fd, 2 + 0.3 * 1.5, 0.01, "G/S with the servos off, far too steep for 30 s: 2 deg above the attitude + 0.3 x 1.5")
end
-- VNAV PTH keeps its law and rate (every 0.8 s for this error: 0.2-0.5 deg in 10 s), also straight after G/S
do
    local fly = director()
    local start = fly(6, 0.05, "follow")
    local path = fly(6, 10, "follow") - start
    check(path > 0.2 and path < 0.5, "VNAV PTH: pitched up "..path.." deg in 10 s (every 0.8 s, as before)")
    fly = director()
    fly(2, 10)
    start = fly(6, 0.05, "follow")
    local after = fly(6, 10, "follow") - start
    check(after > 0.2 and after < 0.5, "VNAV PTH after G/S: pitched up "..after.." deg in 10 s (every 0.8 s)")
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS glide slope tests passed: "..checks)
