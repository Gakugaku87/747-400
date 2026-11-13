-- Run from the repository root with LuaJIT: luajit tests/autopilot/at_spd_gain_test.lua
-- (2026-11-13; the 2026-11-12 review AT-3, AT-4, AT-6, B5) The A/T's SPD
-- with the flaps up (B747.70.at_model.lua's G_TGT, lever_accel,
-- SPD_DOWN_UP, the thrust following the path's V/S change) and FLCH's
-- descents on the energy's rate:
--  - in level flight on tests/lib/cruise_sim.lua (the EEC's and the
--    engines' models): s262's +21 kt at 307 t and FL370, +10 kt steps from
--    10,000 ft to FL290, a 10 kt shear at FL370 - no more the swing of the
--    gains tuned low (+2.42 kt and back -0.70 for s262, +4.1 kt for the step
--    at FL250), and no limit cycle of the levers (G's own scale swung them
--    every 22 s at FL370);
--  - the altitude capture from THR REF's climb into ALT and SPD on
--    tests/lib/energy_sim.lua: within 5 kt over the target (before 8 to 11);
--  - FLCH's 1,000 ft descent of a light airplane at 180 kt: the V/S settles
--    (before it swung -744 to -201 fpm for -480);
--  - with the flaps out SPD as before (the approach's tuning).
local T = dofile("tests/lib/check.lua")("at_spd_gain")
local C = dofile("tests/lib/cruise_sim.lua")
local Sim = dofile("tests/lib/energy_sim.lua")
local A, D = C.A, C.D

-- level flight: a target step; the overshoot, the error's least after it,
-- the time back within 1 kt for good, the levers' travel
local function level(o)
    local r = {hi = -99, lo = 99, travel = 0}
    local last
    local t_step = o.t_step or 60
    C.run({alt = o.alt, weight = o.weight, ias0 = o.ias0, seconds = o.seconds, v_min = o.v_min, v_max = o.v_max,
        wind = o.wind,
        target = function(t) return t < t_step and o.tgt0 or o.tgt0 + (o.dv or 0) end,
        cb = function(m)
            if m.t >= t_step then
                local e = m.ias - m.target
                r.hi = math.max(r.hi, e)
                -- the least once the speed has reached the target
                if e >= 0 then r.reached = true end
                if r.reached then r.lo = math.min(r.lo, e) end
                if math.abs(e) > 1 then r.t1 = m.t - t_step end
            end
            if last then r.travel = r.travel + math.abs(m.lever - last) end
            last = m.lever
        end})
    return r
end

-- s262 (307 t, FL370, 257 kt to 278.2 kt from the air start: X-Plane +3.0,
-- -1.0, +0.85 kt over 280 s; the model before +2.42, -0.70, +0.53)
local r = level({alt = 37000, weight = 307300, ias0 = 257, tgt0 = 278.2, t_step = 0, seconds = 420, v_min = 275.5, v_max = 291})
T.check(r.hi <= 1 and r.lo >= -1, string.format("s262 (307 t, FL370, 257 to 278.2 kt): within 1 kt of the target past it: %+.2f..%+.2f kt (before +2.42 and -0.70)", r.hi, r.lo))
T.check(r.t1 and r.t1 <= 180, string.format("  back within 1 kt for good in 180 s: %.0f s (before 229)", r.t1 or -1))

-- +10 kt steps in level flight
for _, c in ipairs({
    {270000, 10000, nil, 250, "270 t, 10,000 ft, 250 kt", 1.09},
    {300000, 25000, nil, 300, "300 t, FL250, 300 kt", 4.12},
    {397000, 29000, 0.84, nil, "397 t, FL290, M.84", 2.98},
}) do
    local w, alt, mach, ias = c[1], c[2], c[3], c[4]
    if mach then ias = D.mach_to_cas(mach, alt) end
    local s = level({alt = alt, weight = w, ias0 = ias, tgt0 = ias, dv = 10, seconds = 400})
    T.check(s.hi <= 1, string.format("%s, +10 kt: within 1 kt over: %+.2f kt (before %+.2f)", c[5], s.hi, c[6]))
    T.check(s.t1 and s.t1 <= 90, string.format("  within 1 kt for good in 90 s: %.0f s", s.t1 or -1))
    T.check(s.travel <= 1.0, string.format("  the levers' travel %.2f (no swing)", s.travel))
end

-- a 10 kt shear at FL370 (the headwind 10 kt more over 30 s)
local sh = level({alt = 37000, weight = 307000, ias0 = D.mach_to_cas(0.85, 37000), tgt0 = D.mach_to_cas(0.85, 37000),
    seconds = 600, t_step = 60, wind = function(t) return 10 * math.max(0, math.min(1, (t - 60) / 30)) end})
T.check(sh.hi <= 5, string.format("307 t, FL370, a 10 kt shear: %+.1f kt over at most (before +5.6)", sh.hi))
T.check(sh.t1 and sh.t1 <= 90, string.format("  back within 1 kt in 90 s: %.0f s (before 168)", sh.t1 or -1))
T.check(sh.travel <= 1.0, string.format("  the levers' travel %.2f over 600 s (before 0.59; on G's own scale 11.7: a limit cycle)", sh.travel))

-- the altitude capture from THR REF's climb (VNAV SPD) into ALT and SPD
local function capture(o)
    local m = Sim.new{alt = o.cap_alt - 3000, ias = o.ias, weight = o.weight,
        ps = Sim.perf_ps({weight = o.weight}), lever = 0.83}
    m.vs = math.max(0, m.ps * 0.85)
    m.gam = math.deg(math.asin(m.vs * 0.3048 / 60 / (m.tas * 1852 / 3600)))
    m.pitch = m.gam + m.alpha
    m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
    m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", A.THR_REF
    m.target = {ias = o.ias}
    m.servo_inp.v_max = 365
    local over, captured = -99, false
    m:run(400, function(s)
        if not captured then
            local pi = s.pitch_inp
            pi.alt, pi.vs = s.alt, s.vs
            if Sim.P.capture(pi, o.cap_alt) then
                captured = true
                pi.mode, pi.hold_alt, pi.way = "ALT", o.cap_alt, 0
                s.at_inp.pitch = "ALT"
            end
        else
            over = math.max(over, s.ias - s.servo_inp.target)
        end
    end)
    return over, captured
end
for _, c in ipairs({{270000, 10000, 250, 9.9}, {238000, 25000, 310, 8.7}, {347500, 17000, 340, 8.5}}) do
    local over, cap = capture({weight = c[1], cap_alt = c[2], ias = c[3]})
    T.check(cap and over <= 5, string.format("%.0f t, the capture at %d ft from %d kt THR REF: %+.1f kt over the target (before %+.1f)", c[1] / 1000, c[2], c[3], over, c[4]))
end

-- FLCH's 1,000 ft descent, 210 t at 4,000 ft and 180 kt (a partial
-- thrust's descent: 1,200 fpm down at the aft stop, 4,000 up at the
-- reference): from 30 s on the V/S within 150 fpm of the 125 s rate's
do
    local m = Sim.new{alt = 4000, ias = 180, ps_idle = -1200, ps_ref = 4000, weight = 210000}
    m.pitch_inp.mode, m.pitch_inp.hold_alt = "ALT", 4000
    m.at_inp.pitch, m.at_inp.spd = "ALT", true
    m.target = {ias = 180}
    m.servo_inp.v_min = 140
    m:run(20)
    m.pitch_inp.mode, m.pitch_inp.way = "FLCH", -1
    m.at_inp.pitch = "FLCH"
    m.servo_inp.mcp_alt = 3000
    local t0, lo, hi = m.t, 1e9, -1e9
    m:run(125, function(s) if s.t - t0 > 30 then lo, hi = math.min(lo, s.vs), math.max(hi, s.vs) end end)
    T.check(lo >= -630 and hi <= -330, string.format("210 t, 180 kt, FLCH 1,000 ft down: the V/S %.0f..%.0f fpm after 30 s for -480 (before -744..-201)", lo, hi))
end

-- the flaps out: SPD's gains and its reduction near the target as before
do
    local function rate(flaps_up)
        local s = A.new()
        A.update(s, {arm = true, ok = true, ground = false, cas = 170, ra = 2000, flaps_up = flaps_up, reverse = false,
            limit_to = false, limit_ga = false, pitch = "ALT", spd = true, lever_idle = false})
        A.servo(s, {dt = 0.05, ias = 172, accel = 0.2, target = 170, v_max = 365, v_min = 0, flaps_up = flaps_up,
            vs = 0, ivs = 0, alt = 2000, mcp_alt = 2000, thrust = 1.1, thrust_ref = 1.5, n1 = false, lever = 0.4,
            tas = 175, mach = 0.27, weight = 250000})
        return (s.cmd - 0.4) / 0.05
    end
    local want = (A.K_SPD * (170 - 172) - A.K_ACC * 0.2) * A.SPD_DOWN
    T.near(rate(false), want, 1e-9, "the flaps out, 2 kt over at 0.2 kt/s: the lever's rate as before (the gains 1, SPD_DOWN)")
    T.check(rate(true) < rate(false), "  the flaps up: the reduction cut less (SPD_DOWN_UP)")
end
T.done()
