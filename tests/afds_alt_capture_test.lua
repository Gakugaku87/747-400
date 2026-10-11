-- Run from the repository root with Lua 5.1 or LuaJIT.
-- ALT capture and ALT hold in the hydraulics flight director. Loads the
-- production ap_director_pitch with mocked simulator interfaces; this checks
-- the pitch-target logic, not flight dynamics.
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

-- ap_director_pitch and its locals, and B747_rescale from the hydraulics script.
local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")
local rescale_source = slice(HYD.."B747.19.xt.hydraulicsmodel.lua",
    "function B747_rescale(", "B747DR_switching_servos_on")

-- A fresh director (fresh file locals) in level flight at FL310 holding ALT.
-- B747_afds_controls and the pitch-target records are file locals above the
-- slice, so here they are globals of the environment.
local function new_director(values)
    local env = {
        print=function() end,
        B747_afds_controls=controls,
        B747_interpolate_value=function(current, target) return target end,
        debug_flight_directors=0, B747DR_ap_autoland=0, B744DR_autolandPitch=0,
        B747DR_flap_ratio=0, B747DR_flap_lever_detent=0, simDR_radarAlt1=30000,
        simDR_AHARS_pitch_heading_deg_pilot=0, simDR_flight_director_pitch=0,
        B747DR_airspeed_Vmc=174, B747DR_airspeed_Vmax=349,
        simDR_ind_airspeed_kts_pilot=313, simDR_autopilot_airspeed_kts=313,
        simDR_vvi_fpm_pilot=0, simDR_autopilot_vs_fpm=0,
        B747DR_ap_flightPhase=2, B747DR_autopilot_TOGA_status=0,
        B747DR_alt_capture_window=200,
        simDR_pressureAlt1=31000.2, simDR_autopilot_altitude_ft=31000,
        simDR_autopilot_hold_altitude_ft=31000, simDR_autopilot_alt_hold_status=2,
        simDR_autopilot_flch_status=0, simDR_autopilot_vs_status=0,
        simDR_groundspeed=70, simDR_glideslope1=3, simDR_hsi_vdef_dots_pilot=0,
        B747_afds_pitch_target_before_blend=0, B747_afds_pitch_target_after_blend=0,
        simDRTime=3600
    }
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index=_G})
    setfenv(assert(loadstring(rescale_source)), env)()
    setfenv(assert(loadstring(director_source)), env)()
    return env
end

-- One director update 0.1 s after the previous one. The attitude follows the
-- previous raw target, as the servo loop would, so the pitch-error guards in
-- ap_director_pitch stay open. Returns the change of the raw pitch target.
-- The first update of a director only resets it (more than 5 s since the last).
local function update(env, pitch_mode)
    env.simDRTime = env.simDRTime + 0.1
    env.simDR_AHARS_pitch_heading_deg_pilot = env.B747_afds_pitch_target_before_blend
    local before = env.B747_afds_pitch_target_before_blend
    env.ap_director_pitch(pitch_mode)
    return env.B747_afds_pitch_target_before_blend - before
end

-- ALT branch step size above 10,000 ft: 0.0001 + 0.00001 * |VS - target VS|.
local function alt_step(vs_fpm, target_fpm)
    return 0.0001 + 0.00001 * math.abs(vs_fpm - target_fpm)
end

-- [a-1] FLCH pushed in ALT at FL310 with the MCP at 27000: the handler writes
-- dial=hold=27000, alt_hold=0 and FLCH=2, but the FMA is still ALT (9) until
-- the autopilot script runs. That update must not capture 27000.
local env = new_director()
for _ = 1, 15 do update(env, 9) end
equal(env.simDR_autopilot_alt_hold_status, 2, "ALT hold before the FLCH push")
env.simDR_autopilot_altitude_ft = 27000
env.simDR_autopilot_hold_altitude_ft = 27000
env.simDR_autopilot_alt_hold_status = 0
env.simDR_autopilot_flch_status = 2
local change = update(env, 9)
equal(env.simDR_autopilot_alt_hold_status, 0, "stale ALT FMA does not capture over a FLCH push")
equal(env.simDR_autopilot_flch_status, 2, "stale ALT FMA keeps the FLCH request")
equal(change, 0, "stale ALT FMA leaves the pitch target alone")
equal(env.simDR_autopilot_hold_altitude_ft, 27000, "FLCH hold altitude unchanged")
update(env, 8)
equal(env.simDR_autopilot_alt_hold_status, 0, "FLCH FMA on the next update flies FLCH")
equal(env.simDR_autopilot_flch_status, 2, "FLCH request survives to the FLCH FMA")

-- The same race with V/S pushed in ALT.
env = new_director()
for _ = 1, 15 do update(env, 9) end
env.simDR_autopilot_altitude_ft = 27000
env.simDR_autopilot_hold_altitude_ft = 27000
env.simDR_autopilot_alt_hold_status = 0
env.simDR_autopilot_vs_status = 2
change = update(env, 9)
equal(env.simDR_autopilot_alt_hold_status, 0, "stale ALT FMA does not capture over a V/S push")
equal(env.simDR_autopilot_vs_status, 2, "stale ALT FMA keeps the V/S request")
equal(change, 0, "stale ALT FMA leaves the pitch target alone after V/S")

-- FLCH pushed inside the capture window is still captured at the MCP altitude.
env = new_director({simDR_pressureAlt1=27150, simDR_autopilot_altitude_ft=27150,
    simDR_autopilot_hold_altitude_ft=27150, B747DR_alt_capture_window=600})
update(env, 9)
env.simDR_autopilot_altitude_ft = 27000
env.simDR_autopilot_hold_altitude_ft = 27000
env.simDR_autopilot_alt_hold_status = 0
env.simDR_autopilot_flch_status = 2
update(env, 8)
equal(env.simDR_autopilot_alt_hold_status, 2, "FLCH inside the window captures")
equal(env.simDR_autopilot_hold_altitude_ft, 27000, "FLCH inside the window captures the MCP altitude")
equal(env.simDR_autopilot_flch_status, 0, "capture clears the FLCH request")

-- Recorded case t=3614.6: V/S pushed in ALT at 30900.3 ft, 99.7 ft below the
-- MCP altitude and inside the 200.6 ft window. Captured by design.
env = new_director({simDR_pressureAlt1=30900.3, simDR_autopilot_altitude_ft=30900,
    simDR_autopilot_hold_altitude_ft=30900, B747DR_alt_capture_window=200.6})
update(env, 9)
env.simDR_autopilot_altitude_ft = 31000
env.simDR_autopilot_hold_altitude_ft = 31000
env.simDR_autopilot_alt_hold_status = 0
env.simDR_autopilot_vs_status = 2
update(env, 9)
equal(env.simDR_autopilot_alt_hold_status, 2, "V/S inside the window captures")
equal(env.simDR_autopilot_hold_altitude_ft, 31000, "V/S inside the window captures the MCP altitude")
equal(env.simDR_autopilot_vs_status, 0, "capture clears the V/S request")

-- A stale ALT FMA with no request outside the window holds the current altitude
-- instead of flying to a far MCP altitude.
env = new_director({simDR_pressureAlt1=31000})
update(env, 9)
env.simDR_autopilot_altitude_ft = 27000
env.simDR_autopilot_alt_hold_status = 0
change = update(env, 9)
equal(env.simDR_autopilot_alt_hold_status, 2, "unrequested ALT FMA holds")
equal(env.simDR_autopilot_hold_altitude_ft, 31000, "unrequested ALT FMA holds the current altitude")
near(change, 0, 1e-9, "holding the current altitude needs no pitch change")

-- Capture target when the director enters the ALT branch without an
-- ALT hold: the MCP altitude inside the capture window, nothing while FLCH or
-- V/S is requested outside it, otherwise the current altitude.
equal(controls.implicit_altitude_capture_target(2, 0, 31000, 27000, 200), nil,
    "FLCH requested outside the window is not captured")
equal(controls.implicit_altitude_capture_target(0, 2, 31000, 27000, 200), nil,
    "V/S requested outside the window is not captured")
equal(controls.implicit_altitude_capture_target(2, 0, 27150, 27000, 200), 27000,
    "inside the window the MCP altitude is captured")
equal(controls.implicit_altitude_capture_target(0, 0, 31000, 27000, 200), 31000,
    "without a request the current altitude is held")
equal(controls.implicit_altitude_capture_target(2, 0, 27200, 27000, 200), nil,
    "the window edge is outside, as in the director's window test")

-- [a-5] ALT, VNAV ALT and VNAV PTH never release the ALT hold; FLCH, V/S and
-- VNAV SPD release it only when the FMA agrees with a FLCH or V/S request.
for _, mode in ipairs({9, 5, 6}) do
    equal(controls.altitude_hold_release_allowed(mode, 0, 0), false,
        "pitch mode "..mode.." keeps ALT hold")
end
equal(controls.altitude_hold_release_allowed(8, 0, 0), false, "stale FLCH FMA keeps ALT hold")
equal(controls.altitude_hold_release_allowed(7, 0, 0), false, "stale V/S FMA keeps ALT hold")
equal(controls.altitude_hold_release_allowed(8, 2, 0), true, "requested FLCH releases ALT hold")
equal(controls.altitude_hold_release_allowed(7, 0, 2), true, "requested V/S releases ALT hold")
-- The FMA shows VNAV SPD (4) only with a FLCH or V/S request (autopilot.lua
-- pitch-mode FMA), so without one it is stale as well.
equal(controls.altitude_hold_release_allowed(4, 0, 0), false, "stale VNAV SPD FMA keeps ALT hold")
equal(controls.altitude_hold_release_allowed(4, 2, 0), true, "VNAV SPD with FLCH releases ALT hold")
equal(controls.altitude_hold_release_allowed(4, 0, 2), true, "VNAV SPD with V/S releases ALT hold")
equal(controls.altitude_hold_release_allowed(2, 0, 0), true, "G/S releases ALT hold")
equal(controls.altitude_hold_release_allowed(0, 0, 0), true, "no pitch mode releases ALT hold")
equal(controls.altitude_hold_release_allowed(1, 0, 0), true, "TOGA releases ALT hold")

-- ALT HOLD pushed in a FLCH climb (FL290, MCP 31000): the handler writes
-- alt_hold=2, hold=current altitude and clears FLCH, while the FMA is still
-- FLCH (8). That update must keep the ALT hold and fly the ALT branch.
env = new_director({simDR_pressureAlt1=29000, simDR_autopilot_altitude_ft=31000,
    simDR_autopilot_hold_altitude_ft=31000, simDR_autopilot_alt_hold_status=0,
    simDR_autopilot_flch_status=2, B747DR_alt_capture_window=600, simDR_vvi_fpm_pilot=300})
for _ = 1, 5 do update(env, 8) end
env.simDR_autopilot_alt_hold_status = 2
env.simDR_autopilot_flch_status = 0
env.simDR_autopilot_hold_altitude_ft = 29000
change = update(env, 8)
equal(env.simDR_autopilot_alt_hold_status, 2, "stale FLCH FMA keeps a pushed ALT hold")
equal(env.simDR_autopilot_hold_altitude_ft, 29000, "pushed ALT hold altitude kept")
near(change, -alt_step(300, 0), 1e-9, "stale FLCH FMA flies the ALT branch")

-- The same with ALT HOLD pushed in V/S.
env = new_director({simDR_pressureAlt1=29000, simDR_autopilot_altitude_ft=31000,
    simDR_autopilot_hold_altitude_ft=31000, simDR_autopilot_alt_hold_status=0,
    simDR_autopilot_vs_status=2, simDR_autopilot_vs_fpm=300,
    B747DR_alt_capture_window=600, simDR_vvi_fpm_pilot=300})
for _ = 1, 5 do update(env, 7) end
env.simDR_autopilot_alt_hold_status = 2
env.simDR_autopilot_vs_status = 0
env.simDR_autopilot_hold_altitude_ft = 29000
change = update(env, 7)
equal(env.simDR_autopilot_alt_hold_status, 2, "stale V/S FMA keeps a pushed ALT hold")
equal(env.simDR_autopilot_hold_altitude_ft, 29000, "pushed ALT hold altitude kept after V/S")
near(change, -alt_step(300, 0), 1e-9, "stale V/S FMA flies the ALT branch")

-- The same with ALT HOLD pushed in a VNAV SPD climb (FMA 4, FLCH requested).
env = new_director({simDR_pressureAlt1=29000, simDR_autopilot_altitude_ft=31000,
    simDR_autopilot_hold_altitude_ft=31000, simDR_autopilot_alt_hold_status=0,
    simDR_autopilot_flch_status=2, B747DR_alt_capture_window=600, simDR_vvi_fpm_pilot=300})
for _ = 1, 5 do update(env, 4) end
env.simDR_autopilot_alt_hold_status = 2
env.simDR_autopilot_flch_status = 0
env.simDR_autopilot_hold_altitude_ft = 29000
change = update(env, 4)
equal(env.simDR_autopilot_alt_hold_status, 2, "stale VNAV SPD FMA keeps a pushed ALT hold")
equal(env.simDR_autopilot_hold_altitude_ft, 29000, "pushed ALT hold altitude kept after VNAV SPD")
near(change, -alt_step(300, 0), 1e-9, "stale VNAV SPD FMA flies the ALT branch")

-- G/S capture still releases the ALT hold, as before.
env = new_director({simDR_pressureAlt1=3000, simDR_autopilot_altitude_ft=3000,
    simDR_autopilot_hold_altitude_ft=3000, simDR_radarAlt1=2900, simDR_ind_airspeed_kts_pilot=160,
    simDR_autopilot_airspeed_kts=160})
update(env, 9)
update(env, 2)
equal(env.simDR_autopilot_alt_hold_status, 0, "G/S releases ALT hold")

-- [a-3] Shared severe-underspeed threshold: target - 15 kt, not below the
-- minimum safe speed. The FLCH pitch limiter uses the same rule.
equal(controls.severe_underspeed_threshold(313, 184), 298, "underspeed threshold below target")
equal(controls.severe_underspeed_threshold(200, 190), 190, "underspeed threshold at minimum safe speed")
equal(controls.severe_underspeed_threshold(313, nil), 298, "missing minimum safe speed is ignored")
equal(controls.severe_underspeed_threshold(313, 0), 298, "zero minimum safe speed is ignored")

-- [a-3, a-4] ALT target vertical speed: 2 x altitude error, limited to
-- +/-2000 fpm, then to +/-500 fpm while the speed is running away in that
-- direction. Arguments: hold, altitude, IAS, target IAS, Vmc + 10, Vmax.
equal(controls.altitude_hold_target_fpm(27000, 30200, 330, 313, 184, 352), -500,
    "descent at target + 15 kt is slowed")
equal(controls.altitude_hold_target_fpm(31000, 30000, 290, 313, 184, 349), 500,
    "climb at target - 15 kt is slowed")
equal(controls.altitude_hold_target_fpm(30000, 31000, 290, 313, 184, 349), -2000,
    "descent that recovers the speed is not slowed")
equal(controls.altitude_hold_target_fpm(31000, 31050, 335, 313, 184, 349), -100,
    "small descent error is unchanged when fast")
equal(controls.altitude_hold_target_fpm(27000, 30200, 345, 340, 184, 349), -500,
    "descent at Vmax - 5 kt is slowed")
equal(controls.altitude_hold_target_fpm(31000, 22086.7, 310.13, 327, 224.15, 365), 500,
    "recorded VNAV CRZ climb at t=1365.3 is slowed")
equal(controls.altitude_hold_target_fpm(27000, 31000, 313, 313, 184, 348.6), -2000,
    "4000 ft error is limited to 2000 fpm")
equal(controls.altitude_hold_target_fpm(31000, 30002, 317.6, 320.1, 184, 355), 1996,
    "recorded capture at t=2293 is unchanged")
near(controls.altitude_hold_target_fpm(31000, 30900.3, 313.9, 313, 184, 349.3), 199.4, 1e-6,
    "recorded capture at t=3614.6 is unchanged")
equal(controls.altitude_hold_target_fpm(31000, 21232.8, 327.15, 327, 224.17, 365), 2000,
    "recorded VNAV CRZ hold at t=1347.75 is limited to 2000 fpm")

-- The director flies those targets. Each case: one reset update, then one
-- ALT-hold update whose raw pitch-target change is checked.
local function alt_hold_change(values)
    values.simDR_autopilot_alt_hold_status = 2
    local director = new_director(values)
    update(director, 9)
    return update(director, 9)
end
near(alt_hold_change({simDR_autopilot_hold_altitude_ft=27000, simDR_pressureAlt1=30200,
    simDR_vvi_fpm_pilot=-3000, simDR_ind_airspeed_kts_pilot=330}),
    alt_step(-3000, -500), 1e-6, "fast ALT descent pitches up toward -500 fpm")
near(alt_hold_change({simDR_autopilot_hold_altitude_ft=31000, simDR_pressureAlt1=30000,
    simDR_vvi_fpm_pilot=3000, simDR_ind_airspeed_kts_pilot=290}),
    -alt_step(3000, 500), 1e-6, "slow ALT climb pitches down toward +500 fpm")
near(alt_hold_change({simDR_autopilot_hold_altitude_ft=31000, simDR_pressureAlt1=22086.7,
    simDR_vvi_fpm_pilot=6772, simDR_ind_airspeed_kts_pilot=310.1, simDR_autopilot_airspeed_kts=327,
    B747DR_airspeed_Vmc=214.15, B747DR_airspeed_Vmax=365}),
    -alt_step(6772, 500), 1e-6, "recorded t=1365.3 climb pitches down instead of up")
near(alt_hold_change({simDR_autopilot_hold_altitude_ft=27000, simDR_pressureAlt1=31000}),
    -alt_step(0, -2000), 1e-6, "4000 ft above the hold pitches for -2000 fpm")
near(alt_hold_change({simDR_autopilot_hold_altitude_ft=31000, simDR_pressureAlt1=21232.8,
    simDR_vvi_fpm_pilot=847, simDR_ind_airspeed_kts_pilot=327.15, simDR_autopilot_airspeed_kts=327,
    B747DR_airspeed_Vmc=214.17, B747DR_airspeed_Vmax=365}),
    alt_step(847, 2000), 1e-6, "recorded t=1347.75 hold pitches for 2000 fpm")

print("AFDS ALT capture tests passed: "..checks)
