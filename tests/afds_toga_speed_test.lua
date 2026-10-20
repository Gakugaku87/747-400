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
-- 34 fps; 4. go-arounds in climb_model with the MCP altitude above and below; 5. a steep climb-out into ALT and
-- V/S.
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

-- On the takeoff roll with the MCP set inside the capture window above the field (300 ft at a 46 ft field): TO/GA is
-- kept, nothing is captured until the aircraft is in the air. The ALT branch captured it on the roll within 0.2 s and
-- cancelled TO/GA, and the A/T's monitor then also cleared the engines' TO/GA mode (review 45c's NIT-4).
do
    local env = new_director({simDR_pressureAlt1 = 46, simDR_autopilot_altitude_ft = 300,
        simDR_autopilot_hold_altitude_ft = 300, B747DR_alt_capture_window = 300})
    for _ = 1, 30 do step(env, 0.1) end
    check(env.B747DR_autopilot_TOGA_status == 1 and env.simDR_autopilot_alt_hold_status ~= 2,
        "takeoff roll with the MCP 254 ft above the field: TO/GA kept, nothing captured (TOGA "
        ..tostring(env.B747DR_autopilot_TOGA_status)..", ALT hold "..tostring(env.simDR_autopilot_alt_hold_status)..")")
end

-- TO/GA pushed in a climb at M .84 (the window shows 84, the Mach's hundredths): the window is no speed then, TO/GA
-- flies the IAS (it took 84 kt and pitched up toward 25 deg, review 45's m1); a go-around's window under the add-on's
-- Vmc (fltInst02's minimum manoeuvring speed for the flaps) is that Vmc
do
    local env = new_director({simDR_touchGround = 0, simDR_ind_airspeed_kts_pilot = 290, simDR_TAS_mps = 250,
        simDR_AHARS_pitch_heading_deg_pilot = 4, simDR_pressureAlt1 = 30000, simDR_autopilot_altitude_ft = 37000,
        simDR_autopilot_hold_altitude_ft = 37000, simDR_vvi_fpm_pilot = 1500, simDR_alpha_deg = 2.5,
        B747DR_airspeed_Vmc = 200, B747DR_airspeed_Vmax = 365, B747DR_ap_ias_dial_value = 84,
        simDR_autopilot_airspeed_is_mach = 1, simDR_autopilot_servos_on = 1})
    step(env, 0.1)
    local start = env.B747_afds_pitch_target_before_blend
    local pitch
    for _ = 1, 60 do pitch = step(env, 0.1) end
    check(pitch - start <= 0.5, "TO/GA in a Mach climb: the window's 84 is no speed, the IAS held ("
        ..string.format("%.2f -> %.2f deg", start, pitch)..")")
    env = new_director({simDR_touchGround = 0, simDR_ind_airspeed_kts_pilot = 150, simDR_TAS_mps = 80,
        simDR_AHARS_pitch_heading_deg_pilot = 8, simDR_pressureAlt1 = 1500, simDR_autopilot_altitude_ft = 3000,
        simDR_autopilot_hold_altitude_ft = 3000, simDR_vvi_fpm_pilot = 1000, simDR_alpha_deg = 6,
        B747DR_airspeed_Vmc = 150, B747DR_ap_ias_dial_value = 130, simDR_autopilot_airspeed_is_mach = 0,
        simDR_autopilot_servos_on = 1})
    step(env, 0.1)
    start = env.B747_afds_pitch_target_before_blend
    for _ = 1, 60 do pitch = step(env, 0.1) end
    check(math.abs(pitch - start) <= 0.5, "go-around with the window at 130 below the add-on's Vmc (150): 150 held ("
        ..string.format("%.2f -> %.2f deg", start, pitch)..")")
end

-- A heavy takeoff (EINN, 310 t, flaps 20: V2 159; B747DR_airspeed_Vmc, fltInst02's minimum manoeuvring speed for the
-- flaps, 164.3, above V2 with takeoff flaps): TO/GA flies V2 + 10 = 169 kt. A floor at Vmc + 10 made it 174.3 (review
-- 45b): at 169 kt and steady the director pitched down to gain 5 kt.
do
    local env = new_director({B747DR_airspeed_Vmc = 164.3, B747DR_airspeed_V2 = 159, B747DR_ap_ias_dial_value = 159,
        simDR_autopilot_airspeed_kts = 159, B747DR_airspeed_Vmax = 245})
    step(env, 0.1)
    for _ = 1, 20 do step(env, 0.1) end
    -- the roll, no rotation recorded (the pitch stays below 2 deg): the target V2 + 10
    env.simDR_ind_airspeed_kts_pilot = 150
    step(env, 0.1)
    env.simDR_touchGround, env.simDR_ind_airspeed_kts_pilot, env.simDR_AHARS_pitch_heading_deg_pilot = 0, 169, 14
    env.simDR_TAS_mps, env.simDR_vvi_fpm_pilot, env.simDR_alpha_deg, env.simDR_pressureAlt1 = 89, 2000, 9, 300
    step(env, 0.1)
    local start, pitch = env.B747_afds_pitch_target_before_blend, nil
    for _ = 1, 100 do pitch = step(env, 0.1) end
    check(math.abs(pitch - start) <= 0.4, "heavy takeoff (V2 159, the add-on's Vmc 164.3): V2 + 10 = 169 held at 169 kt ("
        ..string.format("%.2f -> %.2f deg", start, pitch)..")")
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

-- 4. Go-arounds in climb_model: TO/GA pushed at 1,000 ft on a 3 deg approach (250 t, 150 kt, flaps 30 -> 20 at 3 s, the
-- gear up from 8 s), GA thrust in 4.5 s, the window's 150 kt, with the MCP altitude above (3,000 ft) and below (0: a
-- non-ILS approach with the MCP still at the minima, review 45). TO/GA always climbs: in the air it took the speed
-- law's guards from the MCP altitude, so with the MCP below it pitched down to -4.5 deg at +100 fpm and went back
-- down to 923 ft at 230 kt (review 45's B1). With the MCP below but inside the capture window (700 ft, the window
-- 413 ft at -800 fpm) the director's ALT branch captured it at once, cancelled TO/GA and levelled at 700 ft, the IAS
-- to 235 kt (review 45b's MINOR-2): TO/GA captures only an altitude above it. window_ft: the capture window (300).
local AM = dofile("tests/approach_model.lua")
local function go_around(mcp_ft, fps, window_ft)
    local G, KT, S = 9.80665, 0.514444, 541.2
    local alt, weight, ias0 = 1000, 250000, 150
    local gamma = math.rad(-3)
    local rho = 1.225 * ((288.15 - 0.0019812 * alt) / 288.15) ^ 4.2559
    local V = ias0 * KT * math.sqrt(1.225 / rho)
    local p = AM.polar(1.0)
    local q = 0.5 * rho * V * V
    local cl = weight * G * math.cos(gamma) / (q * S)
    local gear = 0.05 * q * S
    local approach = (q * S * (p[3] + p[4] * cl * cl) + weight * G * math.sin(gamma)) / 4 + gear / 4
    return CM.fly({alt_ft = alt, ias_kt = ias0, vs_fpm = V * math.sin(gamma) / 0.3048 * 60, weight_kg = weight,
        flaps = 1.0, pitch_mode = 1, target_kt = ias0, mcp_alt_ft = mcp_ft, seconds = 30, dt = 1 / fps,
        vmc_kt = 130, vmax_kt = 230, capture_window_ft = window_ft,
        thrust = function(t)
            local f = math.max(0, math.min(1, (t - 0.5) / 4.5))
            local gear_drag = gear / 4 * (t < 8 and 1 or math.max(0, 1 - (t - 8) / 10))
            return approach + (185000 - approach) * f - gear_drag
        end,
        setup = function(mm)
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 999, ias0
            mm.d.simDR_touchGround = 0
            mm.d.B747DR_autopilot_TOGA_status = 1
        end,
        frame = function(mm, t)
            if t > 3 then mm.state.flap = 0.667 end
            -- the FMA as fma_PitchModes sets it: TO/GA while TOGA_status is 1, ALT once the director captured
            mm.d.B747DR_ap_FMA_active_pitch_mode = (mm.d.B747DR_autopilot_TOGA_status == 1) and 1
                or (mm.d.simDR_autopilot_alt_hold_status == 2 and 9 or 1)
        end})
end
for _, fps in ipairs({20, 34}) do
    for _, mcp in ipairs({3000, 0, 700}) do
        local m = go_around(mcp, fps, mcp == 700 and 413 or nil)
        local low, high_ias = math.huge, -math.huge
        for _, p in ipairs(m.track) do
            low = math.min(low, p.alt)
            high_ias = math.max(high_ias, p.ias)
        end
        local last = m.track[#m.track]
        local at = string.format(" (MCP %d ft, %d fps)", mcp, fps)
        check(1000 - low <= 100, "go-around: at most 100 ft lost"..at..string.format(": %.0f", 1000 - low))
        check(last.alt >= 1050 and last.vs > 500, "go-around: climbing 30 s later"..at
            ..string.format(": %.0f ft, %+.0f fpm", last.alt, last.vs))
        check(high_ias <= 150 + 25, "go-around: the IAS within 25 kt of the window's 150 (FCOM)"..at
            ..string.format(": %.1f", high_ias))
        check(m.d.B747DR_autopilot_TOGA_status == 1 and m.d.simDR_autopilot_alt_hold_status ~= 2,
            "go-around: still TO/GA, no altitude captured"..at..string.format(": TOGA %s, ALT hold %s at %s ft",
            tostring(m.d.B747DR_autopilot_TOGA_status), tostring(m.d.simDR_autopilot_alt_hold_status),
            tostring(m.d.simDR_autopilot_hold_altitude_ft)))
    end
end

-- 4b. Go-arounds with the FMA as fma_PitchModes sets it (TO/GA while TOGA_status is 1, then ALT with the hold status
-- 2 or the MCP altitude inside the window, else NONE) and the capture window by the VSI as autopilot.lua sets it (200 ft
-- at 0 fpm to 1,000 ft at 3,000 fpm). o: alt (ft), path (deg), mcp (ft), fps, seconds, ias (kt), hold_status and
-- hold_alt (ALT HOLD before TO/GA).
local function rescale(in1, out1, in2, out2, x)
    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)
end
local function go_around_fma(o)
    local G, KT, S = 9.80665, 0.514444, 541.2
    local alt, weight, ias0 = o.alt, 250000, o.ias or 150
    local gamma = math.rad(o.path or -3)
    local rho = 1.225 * ((288.15 - 0.0019812 * alt) / 288.15) ^ 4.2559
    local V = ias0 * KT * math.sqrt(1.225 / rho)
    local p = AM.polar(1.0)
    local q = 0.5 * rho * V * V
    local cl = weight * G * math.cos(gamma) / (q * S)
    local gear = 0.05 * q * S
    local approach = (q * S * (p[3] + p[4] * cl * cl) + weight * G * math.sin(gamma)) / 4 + gear / 4
    return CM.fly({alt_ft = alt, ias_kt = ias0, vs_fpm = V * math.sin(gamma) / 0.3048 * 60, weight_kg = weight,
        flaps = 1.0, pitch_mode = 1, target_kt = ias0, mcp_alt_ft = o.mcp, seconds = o.seconds, dt = 1 / o.fps,
        vmc_kt = 130, vmax_kt = 230, capture_window_ft = 200,
        thrust = function(t)
            local f = math.max(0, math.min(1, (t - 0.5) / 4.5))
            local gear_drag = gear / 4 * (t < 8 and 1 or math.max(0, 1 - (t - 8) / 10))
            return approach + (185000 - approach) * f - gear_drag
        end,
        setup = function(mm)
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 999, ias0
            mm.d.simDR_touchGround = 0
            mm.d.B747DR_autopilot_TOGA_status = 1
            mm.d.simDR_autopilot_alt_hold_status = o.hold_status or 0
            mm.d.simDR_autopilot_hold_altitude_ft = o.hold_alt or o.mcp
        end,
        frame = function(mm, t)
            if t > 3 then mm.state.flap = 0.667 end
            local d = mm.d
            d.B747DR_alt_capture_window = rescale(0, 200, 3000, 1000, math.abs(d.simDR_vvi_fpm_pilot or 0))
            local mode
            if d.B747DR_autopilot_TOGA_status == 1 then mode = 1
            elseif d.simDR_autopilot_alt_hold_status == 2
                or math.abs((d.simDR_pressureAlt1 or alt) - d.simDR_autopilot_altitude_ft) < d.B747DR_alt_capture_window then
                mode = 9
            else mode = 0 end
            d.B747DR_ap_FMA_active_pitch_mode = mode
        end})
end
-- TO/GA pushed level in ALT HOLD at the MCP altitude (a go-around before the G/S capture with the MCP still at the
-- intercept altitude, or at an MDA set in the MCP): it climbs whether the MCP is a few feet above or below. The ALT
-- branch took TO/GA with the MCP above by any amount: 0.5 ft above captured it within 0.1 s and cancelled TO/GA, 0.5 ft
-- below climbed away (review 45c's MINOR-1); now the MCP must be more than 50 ft above.
for _, fps in ipairs({20, 34}) do
    for _, off in ipairs({5, 0.5, 0, -0.5, -5}) do
        local m = go_around_fma({alt = 3000, path = 0, mcp = 3000 + off, fps = fps, seconds = 40, ias = 160,
            hold_status = 2, hold_alt = 3000 + off})
        local last = m.track[#m.track]
        local at = string.format(" (level at the MCP altitude %+.1f ft, %d fps)", off, fps)
        check(m.d.B747DR_autopilot_TOGA_status == 1 and last.alt > 3500 and last.vs > 500,
            "go-around at the MCP altitude: TO/GA climbs"..at..string.format(": TOGA %s, %.0f ft, %+.0f fpm",
            tostring(m.d.B747DR_autopilot_TOGA_status), last.alt, last.vs))
    end
end

-- 5. A steep climb-out into an ALT capture and into V/S (review 45's M1): p35-line1's climb-out at 165 t (16-20 deg in
-- VNAV SPD), the MCP at 3,000 ft (window 1,000), or V/S 1,500 fpm selected 20 s in (after the flaps 20 -> 10 at 14 s,
-- where climb_model switches the polar at once). The speed modes go to 25 deg (P39) but ALT kept its 15 deg limit and
-- V/S its 10 deg, taken in one update, and the V/S law its own steps on: -0.36 to -0.39 g into ALT, -0.40 to -0.43 g
-- into V/S, from the mode change on (review 45b). Now the director comes down to the limit at 0.1 g; what is left is
-- the pitch loop's lag and overshoot after the ramp (the attitude up to 1.8 deg behind it, then about 1 deg past;
-- -0.18 to -0.20 g into ALT, -0.22 to -0.24 g into V/S). With the MCP 1,000 ft above at 6,000 fpm the capture
-- overshoots by 1,100-1,260 ft: the capture window's 1,000 ft (pre-existing).
local function steep(mode_change, fps)
    local t0 = 254.0
    local first
    for _, r in ipairs(P35) do if r.t >= t0 then first = r break end end
    return CM.fly({alt_ft = first.alt, ias_kt = first.ias, vs_fpm = first.vs, weight_kg = 165000,
        flaps = first.flap, pitch_mode = 1, target_kt = 154, mcp_alt_ft = mode_change == "alt" and 3000 or 37000,
        capture_window_ft = 1000, seconds = 40, dt = 1 / fps, vmc_kt = 120, vmax_kt = 230,
        thrust = function(t) return interp(P35, t0 + t, "thrust") end,
        setup = function(mm)
            mm.d.B747DR_airspeed_V2, mm.d.B747DR_ap_ias_dial_value = 144, 144
            mm.d.simDR_touchGround = 1
        end,
        frame = function(mm, t)
            if t > 0 then mm.d.simDR_touchGround = 0 else mm.d.simDR_AHARS_pitch_heading_deg_pilot = 0 end
            mm.state.flap = interp(P35, t0 + t, "flap")
            local mode = math.floor(interp(P35, t0 + t, "fma") + 0.5)
            if mm.d.simDR_autopilot_alt_hold_status == 2 then mode = 9 end
            if mode_change == "vs" and t > 20 then
                mode = 7
                mm.d.simDR_autopilot_vs_status, mm.d.simDR_autopilot_vs_fpm = 2, 1500
            end
            mm.d.B747DR_ap_FMA_active_pitch_mode = mode
            mm.target_kt = mode == 1 and 144 or interp(P35, t0 + t, "tgt")
        end})
end
for _, fps in ipairs({20, 34}) do
    for _, change in ipairs({"alt", "vs"}) do
        local m = steep(change, fps)
        -- the attitude before the mode change, nz and the pitch rate from it on
        local lowest_nz, highest_pitch, worst_rate, changed = math.huge, -math.huge, 0, false
        for _, p in ipairs(m.track) do
            changed = changed or p.mode == 9 or p.mode == 7
            if changed then
                lowest_nz = math.min(lowest_nz, p.nz)
                worst_rate = math.max(worst_rate, -p.q)
            else
                highest_pitch = math.max(highest_pitch, p.theta)
            end
        end
        local at = string.format(" (%s, %d fps)", change == "alt" and "ALT capture at 3,000 ft" or "V/S 1,500", fps)
        local nz_floor = change == "alt" and -0.25 or -0.30
        check(changed, "steep climb-out: the mode changed"..at)
        check(highest_pitch >= 15.5, "steep climb-out: the attitude above 15.5 deg before"..at
            ..string.format(": %.1f", highest_pitch))
        check(lowest_nz >= nz_floor, "steep climb-out: no snap, nz at least "..nz_floor.." g"..at
            ..string.format(": %.3f", lowest_nz))
        check(worst_rate <= 2.5, "steep climb-out: pitching down at most 2.5 deg/s"..at
            ..string.format(": %.2f", worst_rate))
    end
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("AFDS TO/GA speed tests passed: "..checks)
