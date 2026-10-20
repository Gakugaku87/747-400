-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The AFDS pitch target's limits in the hydraulics flight director: V/S,
-- VNAV PTH and G/S, and ALT, may pitch down to -10 deg. They stopped at
-- -3.5 deg, and the 747 flies level at about -2 deg with flaps 20 at 210 kt:
-- on p6-line1 and p6-line2 (EHAM, 2026-10-16) VNAV PTH asked for -1,700 to
-- -2,500 fpm and got -300 to -850 fpm at the floor, stayed high and captured
-- a false glide slope lobe. The upper limits (+10, ALT +15) stay.
-- The production ap_director_pitch runs with mocked simulator interfaces, the
-- attitude following its target; this checks the limits, not the dynamics.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
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
local rescale_source = slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")

-- A director at 3,600 ft and 210 kt with flaps 20 (the flap bias steady), descending at -300 fpm.
local function new_director(values)
    local env = {
        print = function() end, B747_afds_controls = controls,
        B747_interpolate_value = function(current, target) return target end,
        debug_flight_directors = 0, B747DR_ap_autoland = 0, B744DR_autolandPitch = 0,
        B747DR_flap_ratio = 4 / 6, B747DR_flap_lever_detent = 0, simDR_radarAlt1 = 3550,
        simDR_AHARS_pitch_heading_deg_pilot = 0, simDR_flight_director_pitch = 0,
        B747DR_airspeed_Vmc = 140, B747DR_airspeed_Vmax = 365,
        simDR_ind_airspeed_kts_pilot = 210, simDR_autopilot_airspeed_kts = 210,
        simDR_vvi_fpm_pilot = -300, simDR_autopilot_vs_fpm = -1500,
        B747DR_ap_flightPhase = 3, B747DR_autopilot_TOGA_status = 0, B747DR_alt_capture_window = 300,
        simDR_pressureAlt1 = 3600, simDR_autopilot_altitude_ft = 2000, simDR_autopilot_hold_altitude_ft = 2000,
        simDR_autopilot_alt_hold_status = 0, simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 2,
        simDR_groundspeed = 210 * 0.514444, simDR_glideslope1 = 3, simDR_hsi_vdef_dots_pilot = 0,
        simDR_elevation = 3600 * 0.3048, simDR_autopilot_servos_on = 1,
        B747_afds_pitch_target_before_blend = 0, B747_afds_pitch_target_after_blend = 0, simDRTime = 3600}
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index = _G})
    setfenv(assert(loadstring(rescale_source)), env)()
    setfenv(assert(loadstring(director_source)), env)()
    return env
end
-- updates every 0.1 s, the attitude following the target (held where it is with hold: G/S damps the attitude's rate,
-- which an attitude jumping to the target each update would drive), the elevation going at the VSI's rate (G/S
-- takes its V/S from the elevation); returns the last raw target
local function fly(env, pitch_mode, updates, hold)
    for _ = 1, updates do
        env.simDRTime = env.simDRTime + 0.1
        env.simDR_elevation = env.simDR_elevation + env.simDR_vvi_fpm_pilot * 0.00508 * 0.1
        if not hold then env.simDR_AHARS_pitch_heading_deg_pilot = env.B747_afds_pitch_target_before_blend end
        env.ap_director_pitch(pitch_mode)
    end
    return env.B747_afds_pitch_target_before_blend
end

-- VNAV PTH (and V/S) asking for -1,500 fpm while the 747 goes down at -300: down to -10 deg, no lower.
local pitch = fly(new_director(), 6, 600)
check(math.abs(pitch + 10) < 1e-9, "VNAV PTH: down to -10 deg, got "..pitch)
pitch = fly(new_director(), 7, 600)
check(math.abs(pitch + 10) < 1e-9, "V/S: down to -10 deg, got "..pitch)
-- G/S 2.5 dots above at 210 kt, the attitude held: its integrator down to -10 deg (P37; the VSI-step law it replaced
-- stepped only while the attitude was within 0.5 deg of its target)
pitch = fly(new_director({simDR_hsi_vdef_dots_pilot = 2.5}), 2, 600, true)
check(math.abs(pitch + 10) < 1e-9, "G/S: down to -10 deg, got "..pitch)
-- ALT 600 ft above the altitude held, level: down to -10 deg
pitch = fly(new_director({simDR_vvi_fpm_pilot = 0, simDR_autopilot_alt_hold_status = 2,
    simDR_autopilot_altitude_ft = 3000, simDR_autopilot_hold_altitude_ft = 3000, simDR_autopilot_vs_status = 0}), 9, 2000)
check(math.abs(pitch + 10) < 1e-9, "ALT: down to -10 deg, got "..pitch)
-- the upper limits stay: V/S +10, ALT +15
pitch = fly(new_director({simDR_vvi_fpm_pilot = 300, simDR_autopilot_vs_fpm = 1500}), 7, 600)
check(math.abs(pitch - 10) < 1e-9, "V/S: up to +10 deg, got "..pitch)
pitch = fly(new_director({simDR_vvi_fpm_pilot = 0, simDR_autopilot_alt_hold_status = 2,
    simDR_autopilot_altitude_ft = 4200, simDR_autopilot_hold_altitude_ft = 4200, simDR_autopilot_vs_status = 0}), 9, 2000)
check(math.abs(pitch - 15) < 1e-9, "ALT: up to +15 deg, got "..pitch)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS pitch limit tests passed: "..checks)
