-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The flight-director pitch target while no pitch mode is active. After an
-- ALT selector push the FMA shows no pitch mode (NONE) for about 0.5 s until
-- the autopilot monitor sets the FLCH request; ap_director_pitch reset its
-- pitch memory to 0 degrees there, so the next VNAV SPD or VNAV PTH update
-- started from level attitude and the aircraft sank. Loads the production
-- ap_director_pitch with mocked simulator interfaces; this checks the
-- pitch-target logic, not flight dynamics.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
local checks = 0
local function equal(actual, expected, message)
    checks = checks + 1
    assert(actual == expected, message..": "..tostring(actual).." ~= "..tostring(expected))
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

-- ap_director_pitch and its file locals. B747_afds_controls and the
-- pitch-target records are file locals above the slice (hydraulics_override.lua
-- :19 and :27), so here they are globals of the environment.
local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")

-- Recorded step climb at t=6258 (TST744L): VNAV SPD toward FL350 at 32,994 ft,
-- 299.3 kt against a 295.2 kt target, +65 fpm, attitude 1.66 degrees.
local function new_director(values)
    local env = {
        print=function() end,
        B747_afds_controls=controls,
        B747_interpolate_value=function(current, target) return target end,
        debug_flight_directors=0, B747DR_ap_autoland=0, B744DR_autolandPitch=0,
        B747DR_flap_ratio=0, B747DR_flap_lever_detent=0, simDR_radarAlt1=30000,
        simDR_AHARS_pitch_heading_deg_pilot=1.66, simDR_flight_director_pitch=0,
        B747DR_airspeed_Vmc=215, B747DR_airspeed_Vmax=365,
        simDR_ind_airspeed_kts_pilot=299.3, simDR_autopilot_airspeed_kts=295.2,
        simDR_vvi_fpm_pilot=65, simDR_autopilot_vs_fpm=0,
        B747DR_ap_flightPhase=2, B747DR_autopilot_TOGA_status=0,
        B747DR_alt_capture_window=400,
        simDR_pressureAlt1=32994, simDR_autopilot_altitude_ft=35000,
        simDR_autopilot_hold_altitude_ft=35000, simDR_autopilot_alt_hold_status=0,
        simDR_autopilot_flch_status=2, simDR_autopilot_vs_status=0,
        B747_afds_pitch_target_before_blend=0, B747_afds_pitch_target_after_blend=0,
        simDRTime=100
    }
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index=_G})
    setfenv(assert(loadstring(director_source)), env)()
    return env
end

-- One director update at simulator time t. The attitude stays at 1.66
-- degrees, as in the 0.9 s of the recorded case.
local function update(env, t, pitch_mode)
    env.simDRTime = t
    return env.ap_director_pitch(pitch_mode)
end

-- [g-4] VNAV SPD, NONE for one update after the ALT selector push, VNAV SPD.
local env = new_director()
update(env, 100, 4)   -- first update only resets the director
update(env, 100.3, 4)
local none_pitch = update(env, 100.6, 0)
near(none_pitch, 1.66, 1e-6, "no pitch mode holds the attitude")
near(env.B747_afds_pitch_target_before_blend, 1.66, 1e-6,
    "no pitch mode records the attitude as the raw pitch target")
local spd_pitch = update(env, 100.9, 4)
near(spd_pitch, 1.66, 0.01, "VNAV SPD after NONE starts from the attitude")
local check_raw = env.B747_afds_pitch_target_before_blend
checks = checks + 1
assert(check_raw > 1.5, "VNAV SPD after NONE continues from the held pitch, not 0 degrees: "..check_raw)
-- Speed 4.1 kt fast and steady: one pitch-up step of rog/3 above FL290.
near(check_raw, 1.66 + 0.01/3, 1e-6, "VNAV SPD after NONE pitches up from the held pitch")

-- The same when VNAV PTH then holds 33,000 ft (ALT branch): above 10,000 ft
-- the ALT branch changes the pitch by only about 0.0006 degrees per update
-- here, so it must not start from 0 degrees.
env = new_director({simDR_autopilot_flch_status=0})
update(env, 100, 6)
update(env, 100.3, 0)
env.simDR_autopilot_alt_hold_status = 2
env.simDR_autopilot_hold_altitude_ft = 33000
update(env, 100.6, 6)
equal(env.simDR_autopilot_alt_hold_status, 2, "VNAV PTH keeps the hold at 33,000 ft")
checks = checks + 1
assert(env.B747_afds_pitch_target_before_blend > 1.5,
    "VNAV PTH after NONE continues from the held pitch, not 0 degrees: "
        ..env.B747_afds_pitch_target_before_blend)

-- The held attitude is limited to the director's pitch range.
near(controls.inactive_mode_pitch_target(1.66), 1.66, 1e-9, "attitude inside the range is held")
equal(controls.inactive_mode_pitch_target(20), 15, "nose-up attitude is limited to 15 degrees")
equal(controls.inactive_mode_pitch_target(-6), -3.5, "nose-down attitude is limited to -3.5 degrees")
equal(controls.inactive_mode_pitch_target(nil), 0, "missing attitude gives level pitch")
env = new_director({simDR_AHARS_pitch_heading_deg_pilot=18})
update(env, 100, 0)
equal(update(env, 100.3, 0), 15, "no pitch mode at 18 degrees holds 15 degrees")

print("AFDS FMA NONE pitch memory tests passed: "..checks)
