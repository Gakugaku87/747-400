-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The flap-movement vertical-speed bias of the hydraulics flight director
-- (get_FPM_bias in B747.19.xt.hydraulics_override.lua). Unlike
-- afds_alt_capture_test.lua this loads the production B747_interpolate_value
-- and B747_animate_value with an X-Plane frame period, so a bias that decays
-- over seconds shows up as it does in the simulator.
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function slice(path, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last-1)
end

local director_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local last_simDR_ind_airspeed_kts_pilot=0", "local filteredDirectorRoll=0")
local model_sources = {
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "function B747_interpolate_value("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_interpolate_value(", "function B747_rescale("),
    slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_rescale(", "B747DR_switching_servos_on")
}
local DT = 0.1           -- director update interval in the ALT branch
local SIM_PERIOD = 0.0225 -- frame period seen in the flight-test kit's runs (about 44 fps)

-- A fresh director (fresh file locals, as after an aircraft load) at the
-- 10,000 ft VNAV capture of the 2026-10-10 fix-b-std run: 9,427 ft, MCP
-- 10,000, +1,459 fpm, 169.5 kt for 183, flaps 20 (flap ratio 0.667), RA
-- 9,140 ft, VNAV SPD pitch target 6.72 deg.
local function new_director(values, seed_pitch)
    local env = {
        print=function() end, SIM_PERIOD=SIM_PERIOD,
        B747_afds_controls=controls,
        debug_flight_directors=0, B747DR_ap_autoland=0, B744DR_autolandPitch=0,
        B747DR_flap_ratio=0.667, B747DR_flap_lever_detent=0, simDR_radarAlt1=9140,
        simDR_AHARS_pitch_heading_deg_pilot=6.72, simDR_flight_director_pitch=6.72,
        B747DR_airspeed_Vmc=158.1, B747DR_airspeed_Vmax=250,
        simDR_ind_airspeed_kts_pilot=169.5, simDR_autopilot_airspeed_kts=183,
        simDR_vvi_fpm_pilot=1459, simDR_autopilot_vs_fpm=0,
        B747DR_ap_flightPhase=1, B747DR_autopilot_TOGA_status=0,
        B747DR_alt_capture_window=589,
        simDR_pressureAlt1=9427, simDR_autopilot_altitude_ft=10000,
        simDR_autopilot_hold_altitude_ft=10000, simDR_autopilot_alt_hold_status=0,
        simDR_autopilot_flch_status=0, simDR_autopilot_vs_status=0,
        simDR_groundspeed=90, simDR_glideslope1=3, simDR_hsi_vdef_dots_pilot=0,
        B747_afds_pitch_target_before_blend=6.72, B747_afds_pitch_target_after_blend=6.72,
        simDRTime=394.0
    }
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index=_G})
    for _, source in ipairs(model_sources) do setfenv(assert(loadstring(source)), env)() end
    local seeded = director_source:gsub("local last_simDR_AHARS_pitch_heading_deg_pilot=0",
        "local last_simDR_AHARS_pitch_heading_deg_pilot="..(seed_pitch or 6.72), 1)
    setfenv(assert(loadstring(seeded)), env)()
    return env
end

-- calls of get_FPM_bias every DT seconds of simulator time, as the ALT branch
-- makes them; returns the last bias
local function bias_for(env, seconds)
    local bias
    for _ = 1, math.floor(seconds/DT + 0.5) do
        env.simDRTime = env.simDRTime + DT
        bias = env.get_FPM_bias()
    end
    return bias
end

-- 1. A fresh 747 that reaches its first ALT/VNAV PTH capture above 3,000 ft
-- RA with flaps 20 has seen no flap movement there. The previous code added
-- 6000 x 0.667 = 4,000 fpm on that first call (the reference started at 0).
local env = new_director()
env.simDRTime = env.simDRTime + DT
local bias = env.get_FPM_bias()
check(math.abs(bias) <= 50, "first call with flaps 20 after a fresh load: bias "..bias.." fpm (no flap movement)")

-- 2. The same capture through ap_director_pitch: one update resets the
-- director (first call), then 1 s of ALT-branch updates with the attitude
-- held at 6.72 deg. Without the bias the target moves about 0.1 deg in 1 s;
-- with the previous code's +4,000 fpm it fell about 1 deg (6.72 -> 5.71).
env = new_director()
env.ap_director_pitch(4)
local target
for _ = 1, 10 do
    env.simDRTime = env.simDRTime + DT
    env.simDR_AHARS_pitch_heading_deg_pilot = 6.72
    target = env.ap_director_pitch(6)
end
check(target >= 6.72 - 0.3, "10,000 ft capture with flaps 20 after a fresh load: pitch target "..target
    .." after 1 s (no false climb rate)")

-- 3. Flaps retracted from 20 to up while the director did not use the bias
-- (VNAV SPD or FLCH: no ALT branch for a minute). The next ALT capture must
-- not see the whole retraction at once (previous code: -4,000 fpm).
env = new_director()
bias_for(env, 1.0)                 -- reference taken at flaps 20
env.simDRTime = env.simDRTime + 60 -- a minute of speed-on-pitch climb
env.B747DR_flap_ratio = 0
env.simDRTime = env.simDRTime + DT
bias = env.get_FPM_bias()
check(math.abs(bias) <= 50, "first call after the flaps came up unseen: bias "..bias.." fpm")

-- 4. Flaps 20 -> 10 below 3,000 ft RA while the director runs (ALT hold at
-- 2,500 ft RA, no bias there), then the climb above 3,000 ft RA with flaps
-- 10: no bias for the movement made below 3,000 ft (previous code: the whole
-- change since the last update above 3,000 ft, here +3,000 fpm from 0).
env = new_director({simDR_radarAlt1=2500})
bias_for(env, 1.0)
env.B747DR_flap_ratio = 0.5
bias_for(env, 2.0)
env.simDR_radarAlt1 = 3100
bias = bias_for(env, DT)
check(math.abs(bias) <= 50, "flaps moved below 3,000 ft RA, then above it: bias "..bias.." fpm")

-- 5. A bias left from flap movement in an earlier ALT hold is not carried
-- into a capture a minute later (the bias decays only while the director
-- calls get_FPM_bias, so the previous code kept it across the pause).
env = new_director({B747DR_flap_ratio=0})
bias_for(env, 1.0)
env.B747DR_flap_ratio = 0.167      -- flaps 1 in ALT hold: +1,000 fpm
bias_for(env, DT)
env.simDRTime = env.simDRTime + 60 -- a minute in FLCH or VNAV SPD
bias = bias_for(env, DT)
check(math.abs(bias) <= 50, "bias left from an earlier ALT hold after a minute's pause: "..bias.." fpm")

-- 6. Guard (passes before and after): flaps moving while the director runs
-- above 3,000 ft RA still give the designed bias. Flaps up -> 1 over 1 s in
-- ALT hold: 6000 x 0.167 = +1,000 fpm, decaying by 1200 fpm per second of
-- frames (27 fpm per update here).
env = new_director({B747DR_flap_ratio=0})
bias_for(env, 1.0)
local highest = 0
for step = 1, 10 do
    env.B747DR_flap_ratio = 0.167*step/10
    highest = math.max(highest, bias_for(env, DT))
end
check(highest >= 500, "flaps moving above 3,000 ft RA in ALT: bias up to "..highest.." fpm (designed)")

-- 7. The same designed bias in a steady V/S. The V/S, VNAV PTH and G/S
-- branch updates the director every 1.0 s when the vertical speed is on
-- target (directorSampleRate rescale(0,1,500,0.2,error)), so its calls of
-- get_FPM_bias come 1.0 s plus a frame apart; a run of calls must not end
-- between them. Driven through ap_director_pitch_integral at the frame rate:
-- a minute of V/S -1,500 fpm on target at 12,000 ft RA, then flaps 1 -> 5
-- (6000 x 0.167 = +1,000 fpm).
local integral_source = slice(HYD.."B747.19.xt.hydraulics_override.lua",
    "local director_pitchRecord={}", "local trimrate=25")
for _, vs_error in ipairs({0, 5}) do
    env = {
        print=function() end, SIM_PERIOD=SIM_PERIOD,
        B747_afds_controls=controls,
        debug_flight_directors=0, B747DR_ap_autoland=0, B744DR_autolandPitch=0, simDR_touchGround=0,
        B747DR_flap_ratio=0.167, B747DR_flap_lever_detent=0, simDR_radarAlt1=12000,
        simDR_AHARS_pitch_heading_deg_pilot=1.0, simDR_flight_director_pitch=1.0,
        B747DR_airspeed_Vmc=180, B747DR_airspeed_Vmax=300,
        simDR_ind_airspeed_kts_pilot=230, simDR_autopilot_airspeed_kts=230,
        simDR_vvi_fpm_pilot=-1500+vs_error, simDR_autopilot_vs_fpm=-1500,
        B747DR_ap_flightPhase=3, B747DR_autopilot_TOGA_status=0,
        B747DR_alt_capture_window=600, B747DR_ap_FMA_active_pitch_mode=7,
        simDR_pressureAlt1=13000, simDR_autopilot_altitude_ft=5000,
        simDR_autopilot_hold_altitude_ft=5000, simDR_autopilot_alt_hold_status=0,
        simDR_autopilot_flch_status=0, simDR_autopilot_vs_status=2,
        simDR_groundspeed=130, simDR_glideslope1=3, simDR_hsi_vdef_dots_pilot=0,
        B747_afds_pitch_target_before_blend=1.0, B747_afds_pitch_target_after_blend=1.0,
        B747DR_flight_director_pitch=1.0, simDRTime=1000.0
    }
    setmetatable(env, {__index=_G})
    for _, source in ipairs(model_sources) do setfenv(assert(loadstring(source)), env)() end
    setfenv(assert(loadstring(integral_source)), env)()
    local get_bias = env.get_FPM_bias
    highest = 0
    env.get_FPM_bias = function()
        local value = get_bias()
        highest = math.max(highest, value)
        return value
    end
    local function frames(seconds)
        for _ = 1, math.floor(seconds/SIM_PERIOD + 0.5) do
            env.simDRTime = env.simDRTime + SIM_PERIOD
            env.ap_director_pitch_integral()
        end
    end
    frames(60)
    check(highest <= 50, "steady V/S with flaps 1, error "..vs_error.." fpm: bias up to "..highest.." fpm (no move)")
    highest = 0
    env.B747DR_flap_ratio = 0.333
    frames(3)
    check(highest >= 500, "flaps 1 -> 5 above 3,000 ft RA in a steady V/S (error "..vs_error
        .." fpm): bias up to "..highest.." fpm (designed)")
end

print("FPM bias tests passed: "..checks)
