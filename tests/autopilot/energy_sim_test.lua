-- Run from the repository root with LuaJIT: luajit tests/autopilot/energy_sim_test.lua
-- The tests' airplane on its energy with the pitch laws and the A/T closed
-- on it (tests/lib/energy_sim.lua, 2026-11-12; docs/overhaul/TESTING.md
-- §3): the model itself (the speeds by the ISA, the energy kept without
-- thrust, the thrust's excess as an acceleration in level flight and as a
-- rate of climb, the engines' lag), then what it was made for:
--  - the user's flight (notes/ATA-22.md §62): VNAV SPD and THR REF climbing
--    at 347.5 t through 10,000 ft, the target 272 to 340 kt: with the speed
--    law's way no descent, without it the flight's;
--  - FLCH's climb entry with the A/T's THR (flch_entry_test.lua's case);
--  - the driftdown: the A/T's THR holding the energy's rate at the FMC's
--    -300 fpm with a Mach for a target, its IAS rising in the descent;
--  - the thrust's excess from the FMC's performance database by weight,
--    altitude, temperature factor and engines inoperative.
local T = dofile("tests/lib/check.lua")("energy_sim")
local Sim = dofile("tests/lib/energy_sim.lua")
local A, D = Sim.A, Sim.D
local KT, G, FT = 1852 / 3600, 9.80665, 0.3048

-- the speeds at the start: the ISA's (the FMC's performance database's)
local m = Sim.new{alt = 10000, ias = 272}
T.near(m.mach, D.cas_to_mach(272, 10000), 1e-9, "272 kt at 10,000 ft: its Mach")
T.near(m.tas / m.ias, 1.156, 0.01, "its TAS 1.16 times the IAS")
T.near(m.pitch, 2, 1e-9, "level: the attitude the angle of attack")
m = Sim.new{alt = 35000, mach = 0.84, isa_dev = 10}
T.near(m.ias, D.mach_to_cas(0.84, 35000), 1e-9, "M.84 at FL350: its IAS")
T.near(m.tas, D.tas(0.84, 35000, 10), 1e-9, "its TAS at ISA + 10")
m = Sim.new{alt = 20000, ias = 300, vs = 1500}
T.near(m.gam, math.deg(math.asin(1500 * FT / 60 / (m.tas * KT))), 1e-9, "a start in a climb: its path")
T.near(m.vs, 1500, 1e-9, "and its vertical speed")

-- no thrust's excess, no law, no A/T: the attitude 3 degrees up, the speed
-- pays for the height: the energy height (h + V^2 / 2g) stays
m = Sim.new{alt = 10000, ias = 300, at = false, law = false, ps = function() return 0 end}
local function energy(x) return x.alt * FT + (x.tas * KT) ^ 2 / (2 * G) end
local e0 = energy(m)
m.pitch = m.alpha + 3
m:run(40)
T.check(m.alt > 10000 + 800 and m.ias < 290, ("a zoom: up %.0f ft, the speed %.1f kt"):format(m.alt - 10000, m.ias))
T.near(energy(m), e0, 3, "the energy height kept within 3 m")

-- the thrust's excess: 1 kt/s of true airspeed in level flight, and the
-- same excess as a steady climb at a constant true airspeed
local tas0 = Sim.new{alt = 10000, ias = 272}.tas
local ps = Sim.ps_of_accel(1.0, tas0)
T.near(Sim.accel_of_ps(ps, tas0), 1.0, 1e-9, "the excess of 1 kt/s and back")
T.near(ps, 1.0 * KT * tas0 * KT / G / FT * 60, 1e-6, "as a rate of climb: a V / g")
m = Sim.new{alt = 10000, ias = 272, at = false, law = false, ps = function() return ps end}
m:run(5)
T.near((m.tas - tas0) / 5, 1.0, 0.02, "level flight: the true airspeed up 1 kt a second")
m = Sim.new{alt = 10000, ias = 272, at = false, law = false, ps = function() return ps end}
m.pitch = m.alpha + math.deg(math.asin(ps * FT / 60 / (m.tas * KT)))
m:run(60)
T.near(m.vs, ps, ps * 0.03, ("the same excess climbing at a constant speed: %.0f fpm for %.0f"):format(m.vs, ps))
T.near(m.tas, tas0, 4, ("the true airspeed kept but for the path's lag at the start (%.1f kt more)"):format(m.tas - tas0))

-- the engines behind the levers: 3 s
m = Sim.new{alt = 10000, ias = 272, at = false, law = false, ps_idle = -2000, ps_ref = 2000, lever = 0.415}
T.near(m.ps, 0, 1e-6, "the levers halfway to the reference: no excess")
m.lever = m.lever_ref
m:run(3)
T.near(m.thr, 0.415 + 0.415 * (1 - math.exp(-1)), 0.01, "3 s after the levers: 63 % of the way")
T.near(m.ps, -2000 + 4000 * m.thr / m.lever_ref, 1e-6, "the excess with the engines, in a line")
-- the start's levers: where the thrust holds the start's path
m = Sim.new{alt = 10000, ias = 272, vs = 1000, ps_idle = -2000, ps_ref = 2000}
T.near(m.ps, 1000, 1e-6, "a start climbing 1,000 fpm: the thrust that holds it")
T.near(m.lever, 0.75 * 0.83, 1e-9, "its levers")

-- the user's flight: 347.5 t, VNAV SPD and THR REF, 272 kt through 10,000 ft
-- on about 2,100 fpm of excess, the FMC's target to 340 kt
local function climb(way)
    local x = Sim.new{alt = 9000, ias = 272, vs = 2100, ps_ref = 2100, ps_idle = -1800}
    x.pitch_inp.mode, x.pitch_inp.vnav_law, x.pitch_inp.way = "VNAV", "FLCH", way
    x.at_inp.pitch, x.at_inp.vnav_at = "VNAV", A.THR_REF
    x.target = {ias = 272}
    x:run(60)
    local r = {vs0 = x.vs, ias0 = x.ias, lever0 = x.lever, fma = x.fma, lo = x.vs, top = x.alt, lost = 0}
    x.target = {ias = 340}
    local t0 = x.t
    x:run(180, function(s)
        r.lo = math.min(r.lo, s.vs)
        r.top = math.max(r.top, s.alt)
        r.lost = math.max(r.lost, r.top - s.alt)
        if not r.t1 and math.abs(s.ias - 340) <= 1 then r.t1 = s.t - t0 end
        r.vmax = math.max(r.vmax or 0, s.ias)
    end)
    r.ias, r.vs, r.lever = x.ias, x.vs, x.lever
    return r
end
local r = climb(1)
T.equal(r.fma, A.THR_REF, "VNAV SPD's climb: the A/T in THR REF")
T.near(r.lever0, 0.83, 0.01, "its levers at the reference thrust")
T.near(r.ias0, 272, 1, ("on the speed before the step (%.1f kt)"):format(r.ias0))
T.near(r.vs0, 2100 * 0.88, 150, ("climbing on the excess, a part of it for the true airspeed of a constant IAS (%.0f fpm of 2,100)"):format(r.vs0))
T.check(r.lo > 30, ("272 to 340 kt with the way: not under near level (%.0f fpm at the least)"):format(r.lo))
T.near(r.lost, 0, 5, ("no altitude lost (%.0f ft)"):format(r.lost))
T.check(r.t1 and r.t1 > 60 and r.t1 < 120, ("340 kt within a knot after %.0f s (the lagged airplane of the pitch law's test: 85)"):format(r.t1 or -1))
T.check(r.vmax < 343, ("no overshoot over 3 kt (%.1f)"):format(r.vmax))
T.near(r.vs, 2100 * 272 / 340, 400, ("then climbing again (%.0f fpm)"):format(r.vs))
local r0 = climb(0)
T.check(r0.lo < -500, ("without the way, the flight's: down to %.0f fpm (the record: -839)"):format(r0.lo))
T.check(r0.lost > 200 and r0.lost < 800, ("  and %.0f ft lost (the record: some 300 ft)"):format(r0.lost))
T.check(r0.t1 and r0.t1 < r.t1, ("  340 kt sooner, %.0f s"):format(r0.t1 or -1))

-- FLCH's climb entry with the A/T's THR: flch_entry_test.lua's airplane
-- (270 t, 10,100 ft, 250 kt: the engines 222 kN a unit of lever, level
-- flight at 0.52, 8 kN at idle), the MCP 5,000 ft up
local function flch(mcp, target)
    local W, V = 270000 * G, 290 * KT
    local x = Sim.new{alt = 10100, ias = 250, alpha = 4.4, lever = 0.52,
        ps = function(s) return math.max(8e3 - 33e3, (s.thr - 0.52) * 222e3) * 4 / W * V / FT * 60 end}
    x.pitch_inp.mode = "FLCH"
    x.pitch_inp.way = mcp > x.alt and 1 or -1
    x.at_inp.pitch = "FLCH"
    x.servo_inp.mcp_alt, x.servo_inp.v_min = mcp, 220
    x.target = {ias = target or 250}
    local q = {vmax = 0, vmin = 999, lmax = 0}
    x:run(90, function(s)
        q.vmax, q.vmin, q.lmax = math.max(q.vmax, s.ias), math.min(q.vmin, s.ias), math.max(q.lmax, s.lever)
    end)
    q.vs, q.ias, q.fma, q.lever = x.vs, x.ias, x.fma, x.lever
    return q
end
r = flch(15100)
T.equal(r.fma, A.THR, "FLCH 5,000 ft up: the A/T in THR")
T.check(r.vmax < 262 and r.vmin > 245, ("the speed within -5/+12 kt (%.1f..%.1f; flch_entry_test: +10)"):format(r.vmin, r.vmax))
T.near(r.vs, 5000 / 125 * 60, 500, ("the V/S settling on the 125 s rate (%.0f fpm)"):format(r.vs))
T.check(r.lmax < 0.83, ("the levers short of the reference (%.2f)"):format(r.lmax))
T.near(r.ias, 250, 2, ("on the speed at 90 s (%.1f)"):format(r.ias))
r = flch(5100)
T.equal(r.fma, A.HOLD, "FLCH 5,000 ft down: HOLD at the aft stop")
T.check(r.vs < -800 and r.vmin > 243, ("descending at idle on the speed (%.0f fpm, %.1f kt at the least)"):format(r.vs, r.vmin))

-- the driftdown (FCOM p.1268; notes/ATA-22.md §62): VNAV SPD with the
-- FMC's driftdown, the A/T's THR to the energy's rate of the FMC's -300
-- fpm (the thrust at the reference would hold more than that), the target
-- a Mach: its IAS rises going down, the speed law's way down at 300 fpm
local function driftdown(slow)
    local x = Sim.new{alt = 33000, mach = 0.80 - slow, ps_ref = 200, ps_idle = -2600, lever = 0.83}
    x.pitch_inp.mode, x.pitch_inp.vnav_law, x.pitch_inp.way, x.pitch_inp.way_fpm = "VNAV", "FLCH", -1, 300
    x.at_inp.pitch, x.at_inp.vnav_at, x.at_inp.vnav_dd = "VNAV", A.THR, true
    x.servo_inp.vnav_vs, x.servo_inp.vnav_dd = -300, true
    x.target = {mach = 0.80}
    local ias0 = x.ias
    local q = {lo = 0}
    x:run(600, function(s)
        q.lo = math.min(q.lo, s.vs)
        if s.t > 300 then
            q.vlo, q.vhi = math.min(q.vlo or s.vs, s.vs), math.max(q.vhi or s.vs, s.vs)
            q.mlo, q.mhi = math.min(q.mlo or s.mach, s.mach), math.max(q.mhi or s.mach, s.mach)
        end
    end)
    q.fma, q.alt, q.ias, q.ias0, q.lever, q.tgt = x.fma, x.alt, x.ias, ias0, x.lever, D.mach_to_cas(0.80, x.alt)
    return q
end
r = driftdown(0)
T.equal(r.fma, A.THR, "the driftdown: the A/T stays in THR (no HOLD at the FMC's V/S)")
T.check(r.vlo > -360 and r.vhi < -240, ("from 5 minutes on within 60 fpm of -300 (%.0f..%.0f)"):format(r.vlo, r.vhi))
T.check(r.mlo > 0.795 and r.mhi < 0.805, ("the Mach held (%.3f..%.3f)"):format(r.mlo, r.mhi))
T.check(r.alt < 33000 - 2500 and r.ias > r.ias0 + 5, ("%.0f ft down in 10 minutes, the IAS up %.1f kt with the Mach's"):format(33000 - r.alt, r.ias - r.ias0))
T.near(r.ias, r.tgt, 1.5, "the IAS the Mach's at the altitude")
T.check(r.lever < 0.83 and r.lever > 0.05, ("the levers back from the reference, not at the aft stop (%.2f)"):format(r.lever))
-- from 12 kt slow (s157's entry): down for the speed first, then the same
r = driftdown(0.022)
T.check(r.lo < -600, ("12 kt under the target: steeper for the speed first (%.0f fpm)"):format(r.lo))
T.check(r.vlo > -360 and r.vhi < -240 and r.mlo > 0.795, ("then -300 fpm on the Mach (%.0f..%.0f fpm, M %.3f)"):format(r.vlo, r.vhi, r.mlo))

-- the thrust's excess from the FMC's performance database (the drag's
-- model and the max climb thrust; no temperature effect: the caller's factor)
local function excess(o, alt, ias, mach)
    local x = Sim.new{alt = alt, ias = ias, mach = mach, weight = o.weight, isa_dev = o.isa_dev, ps = Sim.perf_ps(o), lever = 0.83}
    return x.ps, x
end
local heavy = excess({weight = 347500}, 10000, 272)
T.check(heavy > 1500 and heavy < 3300, ("347.5 t at 10,000 ft and 272 kt on the max climb thrust: %.0f fpm (the flight: 1,975 to 2,226)"):format(heavy))
local light = excess({weight = 238000}, 10000, 272)
T.check(light > heavy * 1.5, ("238 t: more (%.0f fpm)"):format(light))
T.check(Sim.accel_of_ps(light, D.tas(D.cas_to_mach(272, 10000), 10000)) > 1.5, "  more than the speed law's 1.5 kt/s in level flight")
local high = excess({weight = 347500}, 31000, nil, 0.84)
T.check(high < heavy * 0.5, ("347.5 t at FL310 and M.84: much less (%.0f fpm)"):format(high))
local hot = excess({weight = 347500, thrust_k = 0.9}, 10000, 272)
T.check(hot < heavy and hot > heavy * 0.6, ("nine tenths of the thrust: less (%.0f fpm)"):format(hot))
local eo = excess({weight = 347500, inop = 1}, 10000, 272)
T.check(eo < heavy * 0.75 and eo > 0, ("an engine inoperative: less still (%.0f fpm)"):format(eo))
local idle, x = excess({weight = 300000}, 20000, 300)
x.lever, x.thr = 0, 0
T.check(x.ps_fn(x) < -1000, ("the levers at the aft stop at 300 t, 20,000 ft and 300 kt: %.0f fpm"):format(x.ps_fn(x)))
-- with it, the user's flight again: the levers at the reference, no descent
m = Sim.new{alt = 9000, ias = 272, weight = 347500, ps = Sim.perf_ps({weight = 347500}), lever = 0.83, vs = heavy}
m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", A.THR_REF
m.target = {ias = 272}
m:run(40)
m.target = {ias = 340}
local lo = m.vs
m:run(150, function(s) lo = math.min(lo, s.vs) end)
T.check(lo > 30, ("the database's airplane at 347.5 t, 272 to 340 kt: not under near level (%.0f fpm)"):format(lo))
T.near(m.ias, 340, 2, ("at 340 kt after 150 s (%.1f)"):format(m.ias))

T.done()
