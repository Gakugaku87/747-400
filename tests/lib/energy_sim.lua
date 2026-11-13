-- A lagged airplane on its energy, with the AFDS's pitch laws and the A/T
-- closed on it, for the tests (2026-11-12; docs/overhaul/TESTING.md §3).
-- The pitch laws' tests fly a lagged airplane whose thrust is a rate of the
-- speed (kt a second: afds_pitch_model_test.lua's fly_spd); the FLCH
-- entry's test closes the A/T on one airplane (flch_entry_test.lua). This
-- is the two as one model, with what the driftdown's analysis needed
-- (notes/ATA-22.md §62: the A/T's THR holding the energy's rate at the
-- FMC's -300 fpm, the target a Mach, its IAS rising in the descent):
--  - the thrust as specific energy: the thrust's excess over the drag as
--    the rate of climb it gives at a constant true airspeed (fpm), by the
--    levers through the engines' lag; from two numbers (at the aft stop
--    and at the reference thrust), from a function, or from the FMC's
--    performance database (the drag by weight, altitude and Mach, the max
--    climb thrust: perf_ps);
--  - the true airspeed on that energy, the altitude on the path; the IAS
--    and the Mach by the ISA at the altitude (the FMC's performance
--    database's atmosphere), so a Mach target's IAS moves with the altitude;
--  - the attitude behind the pitch law's command (2 s), the flight path
--    behind the attitude less the angle of attack (3 s): as X-Plane's 747
--    at 10,000 ft (s107, s108);
--  - the A/T's own model: its modes by the pitch mode and the FMC's
--    (update), its servo on the levers (THR on the energy's rate at the
--    target speed, SPD, THR REF to the reference thrust, IDLE, HOLD).
-- Run from the repository's root:
--   local Sim = dofile("tests/lib/energy_sim.lua")
--   local m = Sim.new{alt = 10000, ias = 272, ps_ref = 2100, ps_idle = -1800}
--   m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
--   m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", Sim.A.THR_REF
--   m.target = {ias = 340}                  -- or {mach = 0.84}
--   m:run(120, function(m) ... m.vs, m.ias, m.alt, m.lever ... end)
-- The fields (all may be changed between steps):
--   m.alt (ft), m.ias (kt), m.mach, m.tas (kt), m.vs (fpm), m.pitch,
--   m.gam (the flight path), m.lever (0..1), m.thr (the engines': the
--   lever behind their lag), m.ps (the thrust's excess now, fpm), m.t (s),
--   m.cmd (the pitch law's command; nil without a law), m.fma (the A/T's
--   mode number, 0 not engaged), m.accel (the IAS's rate, kt/s, over 0.5 s)
--   m.target        {ias = } or {mach = }: the speed of the pitch law
--                   (spd_sel, mcp_ias) and of the A/T (target, the energy
--                   rate's measure); nil: the caller sets the inputs
--   m.pitch_inp     the pitch law's inputs (B747.70.afds_pitch_model.lua's
--                   inputs(): mode, vnav_law, way, way_fpm, v_min, v_max...;
--                   the airplane's state is filled in each step)
--   m.at_inp        the A/T's update inputs (arm, ok, pitch, vnav_at,
--                   vnav_level, vnav_phase, vnav_dd, the pushes toga, spd,
--                   thr, disc: a push is cleared after the step)
--   m.servo_inp     the A/T's servo inputs (thrust_ref, v_min, v_max,
--                   vnav_vs, vnav_dd, mcp_alt, n1; the rest filled in)
--   m.at = false    no A/T: the levers stay where the caller puts them
--   m.law = false   no pitch law: the attitude stays the caller's (m.pitch)
--   m.gust          (2026-11-13, B3) a function of the model giving a gust,
--                   kt of airspeed, that the IAS and the TAS the laws see
--                   carry (the airplane's own speed unchanged: the air's
--                   short gust); nil: none
--   m.accel_in      the inertial acceleration along the air path the laws
--                   get (kt/s of TAS: the last step's, as the IRU's; false:
--                   none, the laws on the IAS's rate as before 2026-11-13)
local M = {}

M.P = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")
M.A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")
M.D = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local P, A, D = M.P, M.A, M.D
local KT, G, FT = 1852 / 3600, 9.80665, 0.3048
-- (2026-11-13, B4) the zero-lift angle of attack (the body's) for
-- new{alpha_q = true}: X-Plane's 747 in s313, 4.04 degrees at 241.6 kt and
-- 0.967 g, 3.56 at 249.3 kt and 0.946 g (the lift by n over the IAS squared)
M.ALPHA0_LIFT = -1.9

-- the rate of climb (fpm) at a constant true airspeed that an acceleration
-- in level flight (kt of true airspeed a second) is, at a true airspeed
-- (kt), and back: the pitch laws' tests give the thrust as that acceleration
function M.ps_of_accel(kt_s, tas_kt) return kt_s * KT * tas_kt * KT / G / FT * 60 end
function M.accel_of_ps(fpm, tas_kt) return fpm * FT / 60 * G / (tas_kt * KT) / KT end

-- The thrust's excess from the FMC's performance database, for new{ps = }:
-- o.engine (laminar/B747/engines/type: 0 PW, 1 GE), o.weight (kg),
-- o.isa_dev, o.inop (engines inoperative: their thrust gone, the database's
-- engine-out drag), o.thrust_k (the reference thrust's factor, 1: the max
-- climb thrust of the database, which has no temperature effect - a hot
-- day's thrust is the caller's factor), o.idle_n (the thrust of an engine at
-- the aft stop, N: 8,000 as flch_entry_test.lua's, an estimate). The levers
-- at the reference position (the model's lever_ref) give the reference
-- thrust, in a line from the aft stop.
function M.perf_ps(o)
    o = o or {}
    local t = D.tables(o.engine or 0)
    local inop = o.inop or 0
    local n = 4 - inop
    return function(m)
        local w = m.weight or o.weight or 300000
        local mach = math.max(m.mach, 0.2)
        local drag = inop > 0 and D.eo_drag(t, inop, w, m.alt, mach) or D.drag(t, w, m.alt, mach)
        local ref = D.climb_thrust(t, m.alt) * (o.thrust_k or 1) * n / 4
        local idle = (o.idle_n or 8000) * n
        local thrust = idle + (ref - idle) * m.thr / m.lever_ref
        return (thrust - drag) / (w * G) * m.tas * KT / FT * 60
    end
end

local Sim = {}
Sim.__index = Sim

-- o: alt (ft), ias (kt) or mach, vs (fpm, 0), lever (the levers at the
-- start: where the thrust holds the start's path, else 0.5), isa_dev,
-- weight (kg; for perf_ps and the pitch law's ALT gain),
-- ps (a function of the model: fpm) or ps_idle and ps_ref (fpm at the aft
-- stop and at the reference thrust; -1,800 and 2,000), lever_ref (the
-- levers at the reference thrust, 0.83), thrust_ref (the A/T's reference
-- on its display, 1.5: an EPR, 1.0 at the aft stop),
-- tau_pitch (2), tau_path (3), tau_engine (3), alpha (the angle of attack,
-- 2 degrees), dt (0.05), at (false: no A/T), law (false: no pitch law),
-- q (true: the pitch law gets the dynamic pressure and the weight, ALT's
-- gain by the lift coefficient: B747.70.afds_pitch_model.lua's path_gain;
-- 2026-11-13, the 2026-11-12 review's B4), alpha_q (true: the angle of
-- attack by the dynamic pressure, the start's above ALPHA0_LIFT by the
-- square of the IAS's ratio; else constant: B4, X-Plane's s313)
function M.new(o)
    o = o or {}
    local m = setmetatable({}, Sim)
    m.dt = o.dt or 0.05
    m.isa_dev = o.isa_dev or 0
    m.weight = o.weight
    m.alt = o.alt or 10000
    if o.mach then m.mach = o.mach else m.mach = D.cas_to_mach(o.ias or 250, m.alt) end
    m.tas = D.tas(m.mach, m.alt, m.isa_dev)
    m.ias = D.mach_to_cas(m.mach, m.alt)
    m.vs = o.vs or 0
    m.gam = math.deg(math.asin(m.vs * FT / 60 / (m.tas * KT)))
    m.alpha = o.alpha or 2
    m.pitch = m.gam + m.alpha
    m.tau_pitch, m.tau_path, m.tau_engine = o.tau_pitch or 2, o.tau_path or 3, o.tau_engine or 3
    m.lever_ref = o.lever_ref or 0.83
    m.ps_idle, m.ps_ref = o.ps_idle or -1800, o.ps_ref or 2000
    m.ps_fn = o.ps or function(x) return x.ps_idle + (x.ps_ref - x.ps_idle) * x.thr / x.lever_ref end
    m.t, m.accel, m.cmd, m.fma = 0, 0, nil, 0
    -- the levers where the thrust holds the start's path (a steady climb,
    -- descent or level flight), within their travel
    m.lever, m.thr = 0, 0
    local lo = m.ps_fn(m)
    m.thr = m.lever_ref
    local hi = m.ps_fn(m)
    local lever = o.lever
    if not lever then
        lever = (hi ~= lo) and (m.vs - lo) / (hi - lo) * m.lever_ref or 0.5
        lever = math.max(0, math.min(1, lever))
    end
    m.lever, m.thr = lever, lever
    m.ps = m.ps_fn(m)
    m.law = o.law ~= false
    m.give_q = o.q == true
    m.alpha_q = o.alpha_q == true
    m.alpha_k = (m.alpha - M.ALPHA0_LIFT) * m.ias * m.ias
    m.pitch_state, m.pitch_inp = P.new(), P.inputs()
    m.pitch_inp.active = true
    m.at = o.at ~= false
    m.at_state = A.new()
    m.at_inp = {arm = true, ok = true, ground = false, ra = 10000, flaps_up = true, reverse = false}
    m.servo_inp = {n1 = false, thrust_ref = o.thrust_ref or 1.5, v_max = 365, v_min = 0, flaps_up = true}
    m.target = nil
    m.last_ias = m.ias
    m.accel_in = 0
    return m
end

-- the A/T's display of the thrust (an EPR: 1.0 at the aft stop, the
-- reference at the levers' reference position; no lag: the EEC's command)
function Sim:display()
    return 1.0 + ((self.servo_inp.thrust_ref or 1.5) - 1.0) * self.lever / self.lever_ref
end

function Sim:step()
    local m, dt = self, self.dt
    -- the target speed: an IAS, or a Mach's IAS at the altitude
    local tgt_ias, is_mach
    if m.target then
        is_mach = m.target.mach ~= nil
        tgt_ias = is_mach and D.mach_to_cas(m.target.mach, m.alt) or m.target.ias
        m.pitch_inp.spd_sel, m.pitch_inp.mcp_ias = tgt_ias, tgt_ias
        m.servo_inp.target = tgt_ias
    end
    -- the airspeeds the laws see: the air's gust on them (B3)
    local g = m.gust and m.gust(m) or 0
    local ias, tas = m.ias + g, m.tas + g * m.tas / m.ias
    local acc_in = m.accel_in or nil
    m.accel = m.accel + ((ias - m.last_ias) / dt - m.accel) * math.min(1, dt / 0.5)
    m.last_ias = ias
    -- the A/T
    if m.at then
        local ai, si, s = m.at_inp, m.servo_inp, m.at_state
        ai.cas, ai.lever_idle = ias, m.lever <= 0.001
        A.update(s, ai)
        ai.toga, ai.spd, ai.thr, ai.disc = nil, nil, nil, nil
        si.dt, si.ias, si.accel, si.vs, si.ivs, si.alt, si.lever = dt, ias, m.accel, m.vs, m.vs, m.alt, m.lever
        si.tas, si.accel_in = tas, acc_in
        si.thrust = m:display()
        si.evs = A.target_vs(s, m.vs, m.tas * KT, is_mach and m.mach or m.ias, is_mach or false, dt)
        A.servo(s, si)
        if s.servo then m.lever = s.cmd end
        m.fma = A.fma(s)
    end
    -- the engines behind the levers, the thrust's excess
    m.thr = m.thr + (m.lever - m.thr) * math.min(1, dt / m.tau_engine)
    m.ps = m.ps_fn(m)
    -- the pitch law, the attitude behind its command
    if m.law then
        local pi = m.pitch_inp
        pi.ias, pi.tas, pi.alt, pi.pitch, pi.vs, pi.weight = ias, tas, m.alt, m.pitch, m.vs, m.weight
        pi.accel_in = acc_in
        if m.give_q then pi.q = 0.7 * D.atmos(m.alt, m.isa_dev) * m.mach * m.mach end
        m.cmd = P.update(m.pitch_state, pi, dt)
        if m.cmd then m.pitch = m.pitch + (m.cmd - m.pitch) * math.min(1, dt / m.tau_pitch) end
    end
    -- (B4) the angle of attack by the dynamic pressure: the speed's change
    -- turns the path as the attitude's does
    if m.alpha_q then m.alpha = M.ALPHA0_LIFT + m.alpha_k / (m.ias * m.ias) end
    m.gam = m.gam + ((m.pitch - m.alpha) - m.gam) * math.min(1, dt / m.tau_path)
    -- the energy: the true airspeed on the thrust's excess less the climb
    local v = m.tas * KT
    local sin = math.sin(math.rad(m.gam))
    local a = G * (m.ps * FT / 60 / v - sin)
    v = v + a * dt
    if m.accel_in ~= false then m.accel_in = a / KT end
    m.alt = m.alt + v * sin / FT * dt
    m.vs = v * sin / FT * 60
    local _, temp = D.atmos(m.alt, m.isa_dev)
    m.mach = v / math.sqrt(1.4 * 287.053 * temp)
    m.tas = v / KT
    m.ias = D.mach_to_cas(m.mach, m.alt)
    m.t = m.t + dt
    return m
end

-- seconds of steps; cb(m) after each
function Sim:run(seconds, cb)
    for _ = 1, math.floor(seconds / self.dt + 0.5) do
        self:step()
        if cb then cb(self) end
    end
    return self
end

return M
