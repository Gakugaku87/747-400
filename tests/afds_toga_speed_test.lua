-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P39] TO/GA in the air by the speed-on-pitch law (P43) to TO/GA's speed (hydraulics_afds_helpers.lua's
-- toga_target_speed; FCOM vol 2, quoted by a BA 744 captain and confirmed by Aerowinx, topic 2796.20 reply 24):
-- after takeoff the greater of V2 + 10 kt and the IAS at rotation (the pitch passing 2 deg) + 10 kt; above it for 5 s
-- the IAS, at most V2 + 25 kt; the IAS/MACH window's speed when set above. In a go-around the window's speed, the
-- IAS above it for 5 s, at most the window's + 25 kt. It was an attitude for the speed, fltInst02's
-- rescale(Vs -> 2 deg, V2 + 10 -> 12 deg) at 2 deg/s, never above 12 deg: on p35-line1 (EIDW, 233 t, 2026-10-20) the
-- kit flew 19.8 deg at V2 + 4 by hand and the F/D showed 10.7-14.1 deg; VNAV SPD at 577 ft took it from there and the
-- attitude went from 19.8 to 4.7 deg, the IAS to 175 kt for 154 (V2 + 10) and the climb from 3,700 to 970 fpm.
-- 1. toga_target_speed; 2. the production director with mocked datarefs; 3. climb_model on p35-line1's climb-out
-- (tests/data/p35-line1_takeoff.csv) with the A/P in TO/GA from 400 ft and VNAV SPD from 577 ft, at 15, 20 and
-- 34 fps.
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

-- 1. TO/GA's speed
local speed = controls.toga_target_speed
if type(speed) ~= "function" then
    check(false, "toga_target_speed")
else
    -- the takeoff roll (V2 144, the window at V2), rotation at 124 kt, liftoff: V2 + 10
    local s, t = {}, 100
    local function at(on_ground, pitch, ias, v2, window, dt)
        t = t + (dt or 0.1)
        return speed(s, on_ground, pitch, ias, v2 or 144, window or 144, t)
    end
    check(at(true, 0, 30) == nil, "on the ground: no target")
    at(true, 0, 100)
    at(true, 2.5, 124)
    near(s.rotation_ias, 124, 1e-9, "the IAS at rotation (pitch past 2 deg)")
    at(true, 8, 140)
    near(s.rotation_ias, 124, 1e-9, "the IAS at rotation is kept")
    near(at(false, 10, 142), 154, 1e-9, "after liftoff V2 + 10 (rotation + 10 = 134)")
    -- above for 5 s: the IAS; at most V2 + 25
    for _ = 1, 48 do at(false, 15, 158) end
    near(at(false, 15, 158), 154, 1e-9, "4.8 s above: still V2 + 10")
    for _ = 1, 3 do at(false, 15, 158) end
    near(at(false, 15, 158), 158, 1e-9, "5.2 s above: the IAS")
    for _ = 1, 48 do at(false, 15, 175) end
    near(at(false, 15, 175), 158, 1e-9, "175 kt for 4.8 s: still 158")
    for _ = 1, 3 do at(false, 15, 175) end
    near(at(false, 15, 175), 169, 1e-9, "175 kt for 5.2 s: at most V2 + 25")
    -- below again: kept; the window's speed set above it
    near(at(false, 15, 165), 169, 1e-9, "below: kept")
    near(at(false, 15, 165, 144, 180), 180, 1e-9, "the window's speed above it")
    -- a late rotation: the IAS at rotation + 10
    s, t = {}, 100
    at(true, 0, 100)
    at(true, 3, 150)
    near(at(false, 9, 152), 160, 1e-9, "rotation at 150 kt: 160")
    -- no FMC V2 (0, or 999 deleted): the window's speed
    s, t = {}, 100
    at(true, 0, 100, 0, 150)
    at(true, 3, 130, 0, 150)
    near(at(false, 9, 140, 0, 150), 160, 1e-9, "no FMC V2: the window's 150 + 10")
    s, t = {}, 100
    at(true, 3, 130, 999, 146)
    near(at(false, 9, 140, 999, 146), 156, 1e-9, "V2 999: the window's 146 + 10")
    -- a go-around (TO/GA on in the air): the window's speed; above it for 5 s the IAS, at most the window + 25
    s, t = {}, 100
    near(at(false, 2, 145, 144, 150), 150, 1e-9, "go-around at 145 kt, window 150: 150")
    s, t = {}, 100
    near(at(false, 2, 160, 144, 150), 150, 1e-9, "go-around at 160 kt, window 150: 150 at first")
    for _ = 1, 51 do at(false, 5, 160, 144, 150) end
    near(at(false, 5, 160, 144, 150), 160, 1e-9, "go-around 160 kt for 5.2 s: 160")
    for _ = 1, 52 do at(false, 10, 190, 144, 150) end
    near(at(false, 10, 190, 144, 150), 175, 1e-9, "go-around 190 kt for 5.2 s: at most the window + 25")
    s, t = {}, 100
    near(at(false, 2, 155, 144, 0), 155, 1e-9, "go-around with the window read as 0: the IAS")
    -- TO/GA again after more than a second: a go-around after the takeoff
    s, t = {}, 100
    at(true, 3, 130)
    near(at(false, 9, 140), 154, 1e-9, "takeoff")
    near(at(false, 3, 160, 144, 165, 30), 165, 1e-9, "TO/GA 30 s later in the air: a go-around (window 165)")
end

-- 2. The production director (ap_director_pitch with its file locals; B747_afds_controls and the pitch records are
-- file locals above the slice, so here globals of the environment)
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
local function new_director(values)
    local env = {
        print = function() end, B747_afds_controls = controls, SIM_PERIOD = 0.1,
        debug_flight_directors = 0, B747DR_ap_autoland = 0, B744DR_autolandPitch = 0,
        B747DR_flap_ratio = 0.67, B747DR_flap_lever_detent = 0, simDR_radarAlt1 = 0, simDR_touchGround = 1,
        simDR_AHARS_pitch_heading_deg_pilot = 0, simDR_flight_director_pitch = 0, simDR_AHARS_roll_heading_deg_pilot = 0,
        B747DR_airspeed_Vmc = 130, B747DR_airspeed_Vmax = 230, B747DR_airspeed_V2 = 144, B747DR_ap_ias_dial_value = 144,
        simDR_autopilot_TOGA_pitch_deg = 8, simDR_ind_airspeed_kts_pilot = 100, simDR_autopilot_airspeed_kts = 144,
        simDR_TAS_mps = 52, simDR_alpha_deg = 0, simDR_vvi_fpm_pilot = 0, simDR_autopilot_vs_fpm = 0,
        B747DR_ap_flightPhase = 0, B747DR_autopilot_TOGA_status = 1, B747DR_alt_capture_window = 300,
        simDR_pressureAlt1 = 200, simDR_autopilot_altitude_ft = 10000, simDR_autopilot_hold_altitude_ft = 10000,
        simDR_autopilot_alt_hold_status = 0, simDR_autopilot_flch_status = 0, simDR_autopilot_vs_status = 0,
        simDR_autopilot_servos_on = 1, simDR_elevation = 200 * 0.3048, simDR_groundspeed = 52,
        simDR_glideslope1 = 3, simDR_hsi_vdef_dots_pilot = 0,
        B747_afds_pitch_target_before_blend = 0, B747_afds_pitch_target_after_blend = 0, simDRTime = 1000}
    for name, value in pairs(values or {}) do env[name] = value end
    setmetatable(env, {__index = _G})
    local rescale = slice(HYD.."B747.19.xt.hydraulicsmodel.lua", "function B747_animate_value(", "B747DR_switching_servos_on")
    setfenv(assert(loadstring(rescale)), env)()
    setfenv(assert(loadstring(director_source)), env)()
    return env
end
local function step(env, dt)
    env.simDRTime = env.simDRTime + dt
    env.ap_director_pitch(1)
    return env.B747_afds_pitch_target_before_blend
end
do
    local env = new_director()
    step(env, 0.1)
    for _ = 1, 50 do step(env, 0.1) end
    local parked = env.B747_afds_pitch_target_before_blend
    check(parked > 7 and parked <= 8, "on the ground: parked at 8 deg ("..parked..")")
    -- rotation and liftoff at 12 deg, 150 kt, 1,500 fpm: the IAS 4 kt below V2 + 10 and steady
    env.simDR_ind_airspeed_kts_pilot, env.simDR_AHARS_pitch_heading_deg_pilot = 124, 3
    step(env, 0.1)
    env.simDR_touchGround, env.simDR_ind_airspeed_kts_pilot, env.simDR_AHARS_pitch_heading_deg_pilot = 0, 150, 12
    env.simDR_autopilot_servos_on = 0                 -- the flight director alone after liftoff
    env.simDR_TAS_mps, env.simDR_vvi_fpm_pilot, env.simDR_alpha_deg, env.simDR_pressureAlt1 = 78, 1500, 8, 300
    step(env, 0.1)
    near(env.B747_afds_pitch_target_before_blend, 12, 1e-9, "liftoff: from the attitude, not the parked 8 deg")
    -- 20 kt above V2 + 10 and steady (light, at takeoff thrust), the attitude held at 12 deg: the F/D up past 12 deg
    -- within 10 s, 2 deg above the attitude and the P part at most (it stopped at 12)
    env.simDR_ind_airspeed_kts_pilot = 174
    local pitch
    for _ = 1, 100 do pitch = step(env, 0.1) end
    check(pitch > 13.5 and pitch <= 14.3 + 1e-6, "airborne 20 kt fast: up past 12 deg ("..pitch..")")
end

-- 3. p35-line1's climb-out with the A/P from 400 ft: TO/GA (the takeoff state from the ground: V2 144, no rotation
-- recorded), VNAV SPD from 577 ft (154 kt, V2 + 10) as recorded, the recorded thrust
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
local P35 = load_csv("tests/data/p35-line1_takeoff.csv")
for _, fps in ipairs({15, 20, 34}) do
    local at = string.format(" (%d fps)", fps)
    local t0 = 254.0
    local first
    for _, r in ipairs(P35) do if r.t >= t0 then first = r break end end
    local m = CM.fly({alt_ft = first.alt, ias_kt = first.ias, vs_fpm = first.vs, weight_kg = first.weight,
        flaps = first.flap, pitch_mode = 1, target_kt = 154, mcp_alt_ft = 37000, seconds = 40, dt = 1 / fps,
        vmc_kt = 120, vmax_kt = 230,
        thrust = function(t) return interp(P35, t0 + t, "thrust") end,
        setup = function(mm)
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 144, 144
            mm.d.simDR_touchGround = 1                    -- the takeoff roll's state for the first frame
        end,
        frame = function(mm, t)
            -- the first frame on the ground at the takeoff roll's attitude (no rotation recorded: V2 + 10)
            if t > 0 then mm.d.simDR_touchGround = 0 else mm.d.simDR_AHARS_pitch_heading_deg_pilot = 0 end
            mm.state.flap = interp(P35, t0 + t, "flap")
            local mode = math.floor(interp(P35, t0 + t, "fma") + 0.5)
            mm.d.B747DR_ap_FMA_active_pitch_mode = mode
            mm.target_kt = mode == 1 and 144 or interp(P35, t0 + t, "tgt")
        end})
    local low, high_ias, low_ias, change = math.huge, -math.huge, math.huge, 0
    local p0 = CM.at(m, 0).theta
    for _, p in ipairs(m.track) do
        if p.t <= 13 then low = math.min(low, p.theta) end
        if p.t >= 5 then high_ias, low_ias = math.max(high_ias, p.ias), math.min(low_ias, p.ias) end
    end
    check(low >= p0 - 4, "TO/GA and VNAV SPD after takeoff: the attitude not more than 4 deg below its "
        ..string.format("%.1f in 13 s", p0)..at..string.format(": %.1f", low))
    check(low >= 14, "TO/GA and VNAV SPD after takeoff: not down to 12 deg"..at..string.format(": %.1f", low))
    check(high_ias <= 144 + 25 + 2 and low_ias >= 144 + 5, "after takeoff: V2 + 5 .. V2 + 27"..at
        ..string.format(": %.1f .. %.1f", low_ias, high_ias))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS TO/GA speed tests passed: "..checks)
