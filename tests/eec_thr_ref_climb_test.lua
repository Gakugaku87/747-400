-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [P44] The A/T advancing the thrust levers to the climb reference in flight (THR REF with CLB, CLB 1, CLB 2 or CRZ:
-- a VNAV climb resumed from a level-off, a FLCH climb, a step climb): at most THR_REF_FLIGHT_ADVANCE_PER_SEC of the
-- levers' range a second. The production EEC ecc_throttle moved the lever target by 0.003 + 0.005 x the reference's
-- error a second (EPR x 200: 0.35 a second from EPR 1.05 to 1.40) and the levers over their range in 1 s, so climb
-- thrust came in 4-6 s: on p35-line1 (EIDW, 233 t, 2026-10-20) resuming the climb at 8,948 ft the levers went from
-- 0.16 to 0.54 in 2 s and 0.67 in 4 s, the thrust from 51 to 114 kN an engine in 6 s, and the IAS from 251 to 271 kt.
-- Real 744s (ADS-B, research_reclimb.md, 18 climb resumptions): the IAS over the target by 3 kt (0 to 6), the climb
-- 1,000 fpm after about 9 s, 2,000 after 15 s, the climb thrust in about 20-25 s at a medium weight. On the ground
-- (the takeoff) and with the TO and GA references the levers move as before.
-- [review 45, M3] Only with the pitch in VNAV SPD or FLCH SPD: a go-around's reference is CLB a quarter of a second
-- after TO/GA when the MCP altitude is more than 1,000 ft above (flight phase 1; the A/P off: autoland -2 for a frame;
-- the A/P on above 1,500 ft RA: cleared at once), and its thrust must come as fast as GA's.
-- Simulator interfaces are mocks; this does not validate engine dynamics.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.lua"
local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    setfenv(assert(loadstring(source:sub(first, last-1), "@"..path)), runtime)()
end

local EPR_MAX = 1.60
-- the PW lever's command (B747.42.xt.EEC.PW.lua throttle_resolver_angle_PW): EPR 0.95 at idle to the maximum at full
local function pw_command(throttle) return 0.95 + (EPR_MAX - 0.95) * throttle end

-- THR REF from a lever at `from` towards the reference EPR `ref` (mode: the reference's name, on_ground) at a frame time
-- of dt: the seconds until the lever's command is within the A/T's deadband of the reference (nil if not within 60 s)
-- and the largest lever change in any second. opts.pitch_mode: the FMA's pitch mode (4, VNAV SPD, when not given);
-- opts.phase: the reference from ecc_mode_set every frame with this flight phase, starting from `mode`; opts.flaps,
-- opts.radio_alt: for ecc_mode_set.
local function advance(mode, ref, from, dt, on_ground, opts)
    opts = opts or {}
    local runtime = {
        print=function() end, SIM_PERIOD=dt, simDRTime=100,
        B747DR_ap_FMA_active_pitch_mode=opts.pitch_mode or 4,
        B747DR_ap_flightPhase=opts.phase or 1, B747DR_toderate=0, B747DR_clbderate=0,
        simDR_flap_ratio=opts.flaps or 0, simDR_radarAlt1=opts.radio_alt or (on_ground and 0 or 9000),
        B747DR_airspeed_Vmc=150, simDR_autopilot_airspeed_kts=250,
        B747DR_engineType=0, B747DR_ref_thr_limit_mode=mode,
        B747DR_vnav_energy_active=0, B747DR_vnav_energy_thrust_policy=0,
        B747DR_ap_FMA_autothrottle_mode=5, B747DR_ap_autoland=0,
        simDR_onGround=on_ground and 1 or 0,
        simDR_ind_airspeed_kts_pilot=on_ground and 0 or 250, simDR_ias_pilot=on_ground and 0 or 250,
        throttle_resolver_angle_GE=function() return 0 end,
        B747DR_throttle_resolver_angle={[0]=0, 0, 0, 0},
        simDR_N1_target_bug={[0]=95, 95, 95, 95},
        simDR_EPR_target_bug={[0]=ref, ref, ref, ref},
        B747DR_display_EPR_max={[0]=EPR_MAX, EPR_MAX, EPR_MAX, EPR_MAX},
    }
    runtime.B747DR_throttle = {[0]=from, from, from, from}
    runtime.simDR_engine_throttle_jet_all = from
    setmetatable(runtime, {__index=_G})
    load_in(EEC, runtime, "function B747_animate_value", "function B747_setMaxThrust")
    load_in(EEC, runtime, "function B747_interpolate_value", "local previous_altitude = 0")
    if opts.phase then load_in(EEC, runtime, "lastNewTargetModeTime=0", "function B747_interpolate_value") end
    local function refresh()
        for i = 0, 3 do runtime.B747DR_throttle_resolver_angle[i] = pw_command(runtime.B747DR_throttle[i]) end
    end
    refresh()
    runtime.ecc_throttle()                    -- the first call after the levers were the A/T's in SPD: no step
    local t, reached, history, fastest = 0, nil, {}, 0
    while t < 60 do
        t = t + dt
        runtime.simDRTime = runtime.simDRTime + dt
        refresh()
        if opts.phase then runtime.ecc_mode_set() end
        runtime.ecc_throttle()
        refresh()
        history[#history + 1] = {t, runtime.B747DR_throttle[0]}
        for k = #history - 1, 1, -1 do
            if t - history[k][1] >= 1 then
                fastest = math.max(fastest, runtime.B747DR_throttle[0] - history[k][2])
                break
            end
        end
        if reached == nil and math.abs(pw_command(runtime.B747DR_throttle[0]) - ref) <= 0.005 then reached = t end
    end
    return reached, fastest, history
end
-- the lever's travel t seconds into a run's history
local function travel(history, t)
    for _, h in ipairs(history) do
        if h[1] >= t - 1e-9 then return h[2] - history[1][2] end
    end
    return nil
end

-- A1: the climb resumed in flight from level-flight thrust (lever 0.15, EPR 1.05) to CLB (EPR 1.38, lever 0.66): the
-- levers at most 0.025 of their range a second, climb thrust in 18-26 s, the same at 20, 30 and 60 fps.
local CLB_EPR = 0.95 + (EPR_MAX - 0.95) * 0.66
for _, mode in ipairs({"CLB", "CLB 1", "CLB 2", "CRZ"}) do
    for _, fps in ipairs({20, 30, 60}) do
        local reached, fastest = advance(mode, CLB_EPR, 0.15, 1 / fps, false)
        check(fastest <= 0.025 + 0.002, string.format("%s in flight at %d fps: at most 0.025 a second (%.3f)", mode,
            fps, fastest))
        check(reached ~= nil and reached >= 18 and reached <= 26, string.format(
            "%s in flight at %d fps: climb thrust after %s s (18-26)", mode, fps,
            tostring(reached and string.format("%.1f", reached))))
    end
end
-- A2: the takeoff (TO on the ground) and a go-around (GA in flight) as before: within 8 s from the same levers
for _, case in ipairs({{"TO", true}, {"TO 1", true}, {"GA", false}}) do
    local reached = advance(case[1], CLB_EPR, 0.15, 1 / 30, case[2])
    check(reached ~= nil and reached <= 8, string.format("%s%s: thrust after %s s (8, as before)", case[1],
        case[2] and " on the ground" or " in flight", tostring(reached and string.format("%.1f", reached))))
end
-- A3: TO's reference in the air (the takeoff climb before the thrust reduction) moves as before too
local reached = advance("TO", CLB_EPR, 0.15, 1 / 30, false)
check(reached ~= nil and reached <= 8, string.format("TO in flight: thrust after %s s (8, as before)",
    tostring(reached and string.format("%.1f", reached))))

-- A4: FLCH SPD (pitch mode 8) climbing with CLB is limited like VNAV SPD
reached = advance("CLB", CLB_EPR, 0.15, 1 / 30, false, {pitch_mode=8})
check(reached ~= nil and reached >= 18 and reached <= 26, string.format("FLCH SPD with CLB: climb thrust after %s s (18-26)",
    tostring(reached and string.format("%.1f", reached))))

-- A5 [review 45, M3]: the reference from ecc_mode_set. A go-around from approach thrust (lever 0.40; GA on the approach:
-- flight phase 2, the flaps out, below 1,500 ft RA) whose flight phase becomes 1 (the MCP more than 1,000 ft above, the
-- A/T in THR REF): the reference CLB after 0.25 s, the pitch in TO/GA (1). The thrust as fast as GA's: within 8 s.
local GA_EPR = 0.95 + (EPR_MAX - 0.95) * 0.80
for _, fps in ipairs({20, 30, 60}) do
    local reached_ga = advance("GA", GA_EPR, 0.40, 1 / fps, false, {pitch_mode=1, phase=1, flaps=0.5, radio_alt=300})
    check(reached_ga ~= nil and reached_ga <= 8, string.format(
        "a go-around (TO/GA, the reference CLB from flight phase 1) at %d fps: thrust after %s s (8)", fps,
        tostring(reached_ga and string.format("%.1f", reached_ga))))
end
-- a go-around started above 1,500 ft RA in flight phase 2 (the reference CRZ): as fast
reached = advance("CRZ", GA_EPR, 0.40, 1 / 30, false, {pitch_mode=1, phase=2, flaps=0.5, radio_alt=2500})
check(reached ~= nil and reached <= 8, string.format(
    "a go-around above 1,500 ft RA (TO/GA, the reference CRZ): thrust after %s s (8)",
    tostring(reached and string.format("%.1f", reached))))
-- the climb resumed in VNAV SPD and FLCH SPD with the reference from ecc_mode_set (CLB in flight phase 1): limited
for _, pitch_mode in ipairs({4, 8}) do
    reached = advance("CRZ", CLB_EPR, 0.15, 1 / 30, false, {pitch_mode=pitch_mode, phase=1})
    check(reached ~= nil and reached >= 18 and reached <= 26, string.format(
        "pitch mode %d, the reference CLB from flight phase 1: climb thrust after %s s (18-26)", pitch_mode,
        tostring(reached and string.format("%.1f", reached))))
end

-- A6 [P46]: the advance's onset. Real 744s resuming the climb (ADS-B, research_reclimb.md: the V/S 580 / 1,150 /
-- 1,980 / 2,500 fpm 5 / 10 / 15 / 20 s after it starts to rise, median) add excess thrust at about 0.004 W a second
-- from the start; at a steady 0.025 a second p37-line1 (candidate 26) went 703 / 1,457 / 2,469 / 3,476 fpm. The rate
-- comes up from 40 % of it over the first 10 s: the lever about 0.07 up after 5 s (0.125 at the steady rate), 0.175
-- after 10 s (0.25), climb thrust after about 23 s, the same at 20, 30 and 60 fps.
for _, fps in ipairs({20, 30, 60}) do
    local reached, _, history = advance("CLB", CLB_EPR, 0.15, 1 / fps, false)
    local at5, at10 = travel(history, 5), travel(history, 10)
    check(at5 ~= nil and at5 >= 0.060 and at5 <= 0.080, string.format("onset at %d fps: the lever %.3f up after 5 s "
        .."(0.06-0.08)", fps, at5 or -1))
    check(at10 ~= nil and at10 >= 0.160 and at10 <= 0.190, string.format("onset at %d fps: the lever %.3f up after 10 s "
        .."(0.16-0.19)", fps, at10 or -1))
    check(reached ~= nil and reached >= 21 and reached <= 26, string.format("onset at %d fps: climb thrust after %s s "
        .."(21-26)", fps, tostring(reached and string.format("%.1f", reached))))
end

-- A7 [review 48]: an advance's restarts. One runtime through a script of phases {seconds, A/T mode, the reference as a
-- lever ("hold": the levers' position as the phase starts), the levers at the start (the first phase only: the A/T's
-- lever target is the EEC's own, so a later phase's levers would jump back; review 50), a long frame}; spd_throttle
-- (A/T SPD) stubbed: the levers stay. Returns the lever's travel from the start of phase k after s seconds.
local function script_run(phases)
    for k = 2, #phases do assert(phases[k].levers == nil, "script_run: levers in the first phase only") end
    local runtime = {
        print=function() end, SIM_PERIOD=1 / 30, simDRTime=100,
        B747DR_ap_FMA_active_pitch_mode=4, B747DR_ap_flightPhase=1, B747DR_toderate=0, B747DR_clbderate=0,
        simDR_flap_ratio=0, simDR_radarAlt1=9000, B747DR_airspeed_Vmc=150, simDR_autopilot_airspeed_kts=250,
        B747DR_engineType=0, B747DR_ref_thr_limit_mode="CLB", B747DR_vnav_energy_active=0,
        B747DR_vnav_energy_thrust_policy=0, B747DR_ap_FMA_autothrottle_mode=5, B747DR_ap_autoland=0, simDR_onGround=0,
        simDR_ind_airspeed_kts_pilot=250, simDR_ias_pilot=250,
        throttle_resolver_angle_GE=function() return 0 end,
        B747DR_throttle_resolver_angle={[0]=0, 0, 0, 0}, simDR_N1_target_bug={[0]=95, 95, 95, 95},
        simDR_EPR_target_bug={[0]=1, 1, 1, 1},
        B747DR_display_EPR_max={[0]=EPR_MAX, EPR_MAX, EPR_MAX, EPR_MAX},
    }
    local from = phases[1].levers or 0.15
    runtime.B747DR_throttle = {[0]=from, from, from, from}
    runtime.simDR_engine_throttle_jet_all = from
    setmetatable(runtime, {__index=_G})
    load_in(EEC, runtime, "function B747_animate_value", "function B747_setMaxThrust")
    load_in(EEC, runtime, "function B747_interpolate_value", "local previous_altitude = 0")
    runtime.spd_throttle = function() end
    local function refresh()
        for i = 0, 3 do runtime.B747DR_throttle_resolver_angle[i] = pw_command(runtime.B747DR_throttle[i]) end
    end
    refresh()
    runtime.ecc_throttle()
    local starts, history, t = {}, {}, 0
    for k, p in ipairs(phases) do
        if k == 1 then
            for i = 0, 3 do runtime.B747DR_throttle[i] = from end
            runtime.simDR_engine_throttle_jet_all = from
        end
        local ref = pw_command(p.ref == "hold" and runtime.B747DR_throttle[0] or p.ref)
        for i = 0, 3 do runtime.simDR_EPR_target_bug[i] = ref end
        runtime.B747DR_ap_FMA_autothrottle_mode = p.at
        starts[k] = {t, runtime.B747DR_throttle[0]}
        local stop = t + p.seconds
        while t < stop - 1e-9 do
            local dt = (p.long_at and t >= starts[k][1] + p.long_at and not p.long_done) and p.long or (1 / 30)
            if dt == p.long then p.long_done = true end
            t = t + dt
            runtime.SIM_PERIOD = dt
            runtime.simDRTime = runtime.simDRTime + dt
            refresh()
            runtime.ecc_throttle()
            refresh()
            history[#history + 1] = {t, runtime.B747DR_throttle[0], k}
        end
    end
    return function(k, s)
        for _, h in ipairs(history) do
            if h[3] == k and h[1] >= starts[k][1] + s - 1e-9 then return h[2] - starts[k][2] end
        end
        return nil
    end
end
-- a. A second advance after 2 s with the reference at the levers (then a new climb or a step climb): the onset again,
-- the lever 0.06-0.08 up 5 s into it. (A gap test that never restarts passed every check; the first advance stops at
-- 12 s, before climb thrust, so the 2 s are its only quiet time: thresholds of 5 or 8 s fail; review 49.)
local travel_of = script_run({
    {seconds=12, at=5, ref=0.66, levers=0.15},
    {seconds=2, at=5, ref="hold"},
    {seconds=10, at=5, ref=0.96}})
local second = travel_of(3, 5)
check(second ~= nil and second >= 0.060 and second <= 0.080, string.format("a second advance after 2 s at the "
    .."reference: the onset again, the lever %.3f up after 5 s (0.06-0.08)", second or -1))
-- b. One long frame (0.7 s, a scenery-load stutter) 4 s into a climb resumption: no restart, the lever about 0.175 up
-- after 10 s (a restart gave 0.131-0.134 and climb thrust 2.5 s later)
travel_of = script_run({{seconds=12, at=5, ref=0.66, levers=0.15, long_at=4, long=0.7}})
local at10 = travel_of(1, 10)
check(at10 ~= nil and at10 >= 0.165 and at10 <= 0.19, string.format("one 0.7 s frame 4 s into the advance: no restart, "
    .."the lever %.3f up after 10 s (0.165-0.19)", at10 or -1))
-- c. 5 s of an advance, 10 s in IDLE (FLCH descending, the CLB reference above the idle levers), then THR REF (the
-- descent reversed into a climb): the onset, the lever 0.06-0.08 up after 5 s (IDLE's frames counted as advancing,
-- or adding no quiet time: 0.125; review 49)
travel_of = script_run({
    {seconds=5, at=5, ref=0.66, levers=0.15},
    {seconds=10, at=2, ref=0.66},
    {seconds=10, at=5, ref=0.66}})
local out_of_idle = travel_of(3, 5)
check(out_of_idle ~= nil and out_of_idle >= 0.060 and out_of_idle <= 0.080, string.format("an advance out of IDLE: "
    .."the onset, the lever %.3f up after 5 s (0.06-0.08)", out_of_idle or -1))
-- d. 12 s of an advance, 2 s with the A/T in SPD (a capture: the time outside this branch), then a new climb: the onset
-- again, 0.06-0.08 up after 5 s (no time outside counted: 0.125; review 49)
travel_of = script_run({
    {seconds=12, at=5, ref=0.66, levers=0.15},
    {seconds=2, at=3, ref=0.66},
    {seconds=10, at=5, ref=0.96}})
local after_spd = travel_of(3, 5)
check(after_spd ~= nil and after_spd >= 0.060 and after_spd <= 0.080, string.format("a new climb after 2 s in SPD: the "
    .."onset again, the lever %.3f up after 5 s (0.06-0.08)", after_spd or -1))
-- e. 6 s of an advance, 0.3 s in SPD, the same advance again: no restart (0.105-0.13 up 5 s on; a threshold of 0 gives
-- 0.069)
travel_of = script_run({
    {seconds=6, at=5, ref=0.66, levers=0.15},
    {seconds=0.3, at=3, ref=0.66},
    {seconds=10, at=5, ref=0.66}})
local short_spd = travel_of(3, 5)
check(short_spd ~= nil and short_spd >= 0.105 and short_spd <= 0.13, string.format("0.3 s in SPD mid-advance: no "
    .."restart, the lever %.3f up 5 s on (0.105-0.13)", short_spd or -1))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("EEC THR REF climb tests passed: "..checks)
