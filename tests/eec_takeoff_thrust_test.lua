-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The autothrottle setting takeoff thrust (THR REF on the takeoff roll): the
-- production EEC ecc_throttle moves the thrust levers until the lever's
-- command meets the takeoff reference (PW/RR: EPR; GE: N1). A real 747-400's
-- A/T sets takeoff thrust within seconds of TO/GA, before HOLD at 65 kt; the
-- crew checks it by 80 kt. Here the lever target moved by 0.0001 a frame plus
-- 0.0005 of the error a second (PW: a time constant of about 15 s), so it took
-- 30-40 s and depended on the frame rate, and HOLD froze the levers short of
-- takeoff thrust (EIDW-EHAM: 0.846-0.856 at HOLD, N1 still rising).
-- Simulator interfaces are mocks; this does not validate engine dynamics.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.lua"
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    setfenv(assert(loadstring(source:sub(first, last-1), "@"..path)), runtime)()
end

local EPR_MAX, EPR_TO = 1.60, 1.52
-- the PW lever's command (B747.42.xt.EEC.PW.lua throttle_resolver_angle_PW): EPR 0.95 at idle to the maximum at full
local function pw_command(throttle) return 0.95 + (EPR_MAX - 0.95) * throttle end
-- the GE one (B747.42.xt.EEC.GE.lua: B747_rescale(0, 25, 1, 116))
local function ge_command(throttle) return 25 + 91 * throttle end

-- A takeoff roll from a lever at `throttle`, THR REF, at a frame time of dt: the seconds until the lever's command is
-- within the A/T's deadband of the takeoff reference, the highest command seen (nil if not within 30 s) and the lowest
-- lever before takeoff thrust. after_landing: the A/T had taken the levers to idle (IDLE) before it was off.
local function takeoff(engine, throttle, dt, after_landing)
    local runtime = {
        print=function() end,
        SIM_PERIOD=dt,
        simDRTime=100,
        B747DR_airspeed_Vmc=120,
        simDR_autopilot_airspeed_kts=160,
        B747DR_engineType=engine,
        B747DR_ref_thr_limit_mode="TO",
        B747DR_vnav_energy_active=0,
        B747DR_vnav_energy_thrust_policy=0,
        B747DR_ap_FMA_autothrottle_mode=5,
        B747DR_ap_autoland=0,
        simDR_onGround=1,
        simDR_radarAlt1=0,
        simDR_ind_airspeed_kts_pilot=0,
        simDR_ias_pilot=0,
        throttle_resolver_angle_GE=function(i) return 0 end,
        B747DR_throttle_resolver_angle={[0]=0, 0, 0, 0},
        simDR_N1_target_bug={[0]=95, 95, 95, 95},
        simDR_EPR_target_bug={[0]=EPR_TO, EPR_TO, EPR_TO, EPR_TO},
        B747DR_display_EPR_max={[0]=EPR_MAX, EPR_MAX, EPR_MAX, EPR_MAX},
    }
    runtime.B747DR_throttle = {[0]=throttle, throttle, throttle, throttle}
    runtime.simDR_engine_throttle_jet_all = throttle
    setmetatable(runtime, {__index=_G})
    load_in(EEC, runtime, "function B747_animate_value", "function B747_setMaxThrust")
    load_in(EEC, runtime, "function B747_interpolate_value", "local previous_altitude = 0")
    local command = engine == 1 and ge_command or pw_command
    local target = engine == 1 and 95 or EPR_TO
    local band = engine == 1 and 0.2 or 0.005     -- the A/T's deadband (input and target within 1 of each other)
    local function refresh()
        for i = 0, 3 do runtime.B747DR_throttle_resolver_angle[i] = command(runtime.B747DR_throttle[i]) end
    end
    refresh()
    if after_landing then
        -- the landing: the A/T at IDLE takes the levers to idle, then it is off (ecc_throttle not called) and the levers
        -- are moved by hand to where the takeoff starts
        runtime.B747DR_ap_FMA_autothrottle_mode = 2
        runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_ias_pilot = 200, 200   -- in the air: no low-speed recovery
        for _ = 1, math.floor(5 / dt) do
            runtime.simDRTime = runtime.simDRTime + dt
            runtime.ecc_throttle()
        end
        runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_ias_pilot = 0, 0
        for i = 0, 3 do runtime.B747DR_throttle[i] = throttle end
        runtime.simDR_engine_throttle_jet_all = throttle
        runtime.simDRTime = runtime.simDRTime + 60
        refresh()
    end
    -- TO/GA pushed: THR REF, as in production (ecc_throttle runs only while the A/T has the levers)
    runtime.B747DR_ap_FMA_autothrottle_mode = 5
    runtime.ecc_throttle() -- the first call after the A/T was off: no step
    local t, reached, highest, lowest = 0, nil, -1e9, 1e9
    while t < 30 do
        t = t + dt
        runtime.simDRTime = runtime.simDRTime + dt
        -- the roll: 3 kt/s from brake release
        runtime.simDR_ind_airspeed_kts_pilot, runtime.simDR_ias_pilot = 3 * t, 3 * t
        refresh()
        runtime.ecc_throttle()
        refresh()
        local c = command(runtime.B747DR_throttle[0])
        highest = math.max(highest, c)
        if reached == nil then lowest = math.min(lowest, runtime.B747DR_throttle[0]) end
        if reached == nil and math.abs(c - target) <= band then reached = t end
    end
    return reached, highest, target, band, lowest
end

-- T1: PW from the stabilised lever (EPR 1.10, the FCTM's "about 70% N1"): takeoff thrust within 8 s, the same at 20,
-- 30 and 60 frames a second, and no more than the reference.
local times = {}
for _, fps in ipairs({20, 30, 60}) do
    local reached, highest, target, band = takeoff(0, (1.10 - 0.95) / (EPR_MAX - 0.95), 1 / fps)
    check(reached ~= nil and reached <= 8, string.format("PW from EPR 1.10 at %d fps: takeoff thrust after %s s (8)",
        fps, tostring(reached and string.format("%.1f", reached))))
    check(highest <= target + 2 * band, string.format("PW at %d fps: the lever's command went to EPR %.3f (%.3f)",
        fps, highest, target))
    times[fps == 20 and 1 or fps == 30 and 2 or 3] = reached
end
local all = times[1] and times[2] and times[3]
check(all and math.max(times[1], times[2], times[3]) - math.min(times[1], times[2], times[3]) <= 0.5, string.format(
    "PW: takeoff thrust after %s / %s / %s s at 20 / 30 / 60 fps (within 0.5 s)", tostring(times[1]),
    tostring(times[2]), tostring(times[3])))

-- T2: PW from idle (TO/GA pushed with the levers closed): still within 12 s, before HOLD at 65 kt (about 15 s).
local reached = takeoff(0, 0, 1 / 30)
check(reached ~= nil and reached <= 12, string.format("PW from idle: takeoff thrust after %s s (12)",
    tostring(reached and string.format("%.1f", reached))))

-- T3: GE from about 70% N1: within 8 s and no overshoot.
local highest, target
reached, highest, target = takeoff(1, (70 - 25) / 91, 1 / 30)
check(reached ~= nil and reached <= 8, string.format("GE from 70%% N1: takeoff thrust after %s s (8)",
    tostring(reached and string.format("%.1f", reached))))
check(highest <= target + 0.4, string.format("GE: the lever's command went to %.1f%% N1 (%.1f)", highest, target))

-- T4 [review 21]: the A/T's lever target from the levers when it takes them: from the FCTM's start with the levers at
-- 0.60 (above its 0.5 from load), and after a landing that left it at idle, the levers do not go back first (they went
-- to 0.513, and to idle, before advancing).
for _, after_landing in ipairs({false, true}) do
    local reached4, _, _, _, lowest = takeoff(0, 0.60, 1 / 30, after_landing)
    check(lowest >= 0.595 and reached4 ~= nil and reached4 <= 8, string.format(
        "PW from a lever of 0.60%s: the levers down to %.3f before takeoff thrust (0.595), takeoff thrust after %s s (8)",
        after_landing and " after a landing" or "", lowest, tostring(reached4 and string.format("%.1f", reached4))))
end

print("EEC takeoff thrust tests passed: "..checks)
