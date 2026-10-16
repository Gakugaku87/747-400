-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The G/S law of the hydraulics flight director (getGlideSlopeFPM): the V/S
-- of the glide slope at the ground speed, corrected by the deviation in feet
-- - about dots x 0.1 x the height on a 3 deg slope (0.3 deg a dot) - so that
-- a deviation goes in about 24 s at any height: 0.25 x the radio altitude fpm
-- a dot, at least 75 (near the ground, as before) and at most 1,000 fpm in
-- all. With 75 fpm a dot everywhere, a capture 0.75 dot above the beam
-- (190 ft at 8 nm) stayed 0.8 dot above to 500 ft in the approach model.
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
near(glide_slope_fpm(1000, -2.5), NOMINAL + 1000, 0.01, "full scale below (x3): at most 1,000 fpm")

-- In G/S the director runs every 0.2 s, so its 10-sample filter spans 2 s and the pitch follows the beam
-- as the 747 slows down on it: at 0.8 s for a small V/S error, EHAM's approach in the model went 1.8 dots
-- below the beam by 500 ft, slowing from 160 to 140 kt after AM622. Its other modes keep their rates.
-- (ap_director_pitch_integral as ap_pitch_assist runs it every frame, approach_model.lua's loader)
local model = dofile("tests/approach_model.lua")
local function pitch_change(pitch_mode, seconds, before_mode, before_seconds)
    local d = {}
    local _, hyd = model.load(d)
    model.set_datarefs(d, model.eham(), 0.3)
    d.B747DR_ap_FMA_active_pitch_mode = pitch_mode
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 1500, 1500
    d.simDR_groundspeed, d.simDR_ind_airspeed_kts_pilot = 150 * 0.514444, 150
    d.simDR_hsi_vdef_dots_pilot = 0
    d.simDR_vvi_fpm_pilot = -900                     -- 104 fpm steeper than the beam (and the V/S target)
    d.simDR_autopilot_vs_fpm = NOMINAL
    d.simDR_autopilot_altitude_ft, d.simDR_autopilot_hold_altitude_ft = 0, 0     -- no altitude to capture
    d.B747DR_flap_ratio, d.B747DR_airspeed_Vmc = 1, 130
    hyd.MODEL_init_director(0)
    d.simDR_AHARS_pitch_heading_deg_pilot = 0
    local function fly(mode, duration)
        d.B747DR_ap_FMA_active_pitch_mode = mode
        local t0 = d.simDRTime
        while d.simDRTime < t0 + duration do
            d.simDRTime = d.simDRTime + 0.05
            hyd.ap_director_pitch_integral()
            d.simDR_AHARS_pitch_heading_deg_pilot = hyd.MODEL_director_state().raw
        end
    end
    if before_mode then fly(before_mode, before_seconds) end
    local start = hyd.MODEL_director_state().raw
    fly(pitch_mode, seconds)
    return hyd.MODEL_director_state().raw - start
end
local gs, path = pitch_change(2, 10), pitch_change(6, 10)
check(gs > 0.9, "G/S: 104 fpm too steep at 150 kt, pitched up "..gs.." deg in 10 s (every 0.2 s; 0.3 deg before)")
check(path > 0.2 and path < 0.5, "VNAV PTH: pitched up "..path.." deg in 10 s (every 0.8 s, as before)")
-- VNAV PTH straight after G/S (or after under 2 s in another mode; 2 s in TO/GA already brought the
-- rate back) at its own rate, not G/S's
local after = pitch_change(6, 10, 2, 10)
check(after > 0.2 and after < 0.5, "VNAV PTH after G/S: pitched up "..after.." deg in 10 s (every 0.8 s)")

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS glide slope tests passed: "..checks)
