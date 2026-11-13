-- Run from the repository root with LuaJIT: luajit tests/autopilot/spd_gust_test.lua
-- (2026-11-13; the 2026-11-12 review AFDS-3, B3) The speed laws in the air's
-- gusts (B747.70.afds_pitch_model.lua's GUST_TAU): VNAV SPD's climb at the
-- reference thrust on tests/lib/energy_sim.lua's airplane, the IAS and the
-- TAS the laws see carrying a gust (a band-limited noise, the airplane's
-- own speed unchanged), the inertial acceleration along the air path the
-- laws' (as the IRU's). The gust's share of the pitch (against the same
-- climb in still air) with 0.5 kt rms within 0.4 degree (the review's aim;
-- on the IAS before: 0.78 to 0.97 here, 1.0 to 1.8 in X-Plane's real
-- weather in the KSEA-KLAX records); a sustained shear still answered; the
-- flaps out (T/O, G/A, the approach) the IAS as before.
local T = dofile("tests/lib/check.lua")("spd_gust")
local Sim = dofile("tests/lib/energy_sim.lua")
local P, A = Sim.P, Sim.A

-- a band-limited gust (kt): white noise through two lags of tau s, scaled
-- to rms over the run; a small generator of its own (the same numbers on
-- every machine)
local function gust_series(n, dt, tau, rms, seed)
    local x = seed
    local function rnd()
        x = (x * 1103515245 + 12345) % 2147483648
        return x / 2147483648 * 2 - 1
    end
    local g, a, b, sum = {}, 0, 0, 0
    for i = 1, n do
        a = a + (rnd() - a) * dt / tau
        b = b + (a - b) * dt / tau
        g[i] = b
        sum = sum + b * b
    end
    local k = sum > 0 and rms / math.sqrt(sum / n) or 0
    for i = 1, n do g[i] = g[i] * k end
    return g
end
-- VNAV SPD's climb at the reference thrust (the A/T's THR REF), settled for
-- 300 s, then 120 s in the gust beside the same climb in still air: the
-- gust's share of the pitch and of the V/S (their differences' spread: the
-- climb's own slow trend left out)
local function climb(o)
    local function new()
        local m = Sim.new{alt = o.alt, ias = o.ias, mach = o.mach, weight = o.weight,
            ps = Sim.perf_ps({weight = o.weight}), lever = 0.83, vs = 2000}
        m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
        m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", A.THR_REF
        m.target = o.mach and {mach = o.mach} or {ias = o.ias}
        if o.no_accel then m.accel_in = false end
        if o.flaps_out then m.pitch_inp.flaps_up = false end
        m:run(300)
        return m
    end
    local m, ref = new(), new()
    local n = math.floor(120 / m.dt + 0.5)
    local g = gust_series(n, m.dt, o.tau or 1, o.rms or 0, o.seed or 7)
    local k = 0
    m.gust = function() return g[k] or 0 end
    local st = {p_lo = 1e9, p_hi = -1e9, v_lo = 1e9, v_hi = -1e9, a_lo = 1e9}
    for _ = 1, n do
        k = k + 1
        m:step()
        ref:step()
        local dp, dv = m.pitch - ref.pitch, m.vs - ref.vs
        st.p_lo, st.p_hi = math.min(st.p_lo, dp), math.max(st.p_hi, dp)
        st.v_lo, st.v_hi = math.min(st.v_lo, dv), math.max(st.v_hi, dv)
        st.a_lo = math.min(st.a_lo, m.alt - ref.alt)
    end
    st.pp, st.vpp = st.p_hi - st.p_lo, st.v_hi - st.v_lo
    return st, m
end

local CASES = {
    {name = "300 t, 10,000 ft, 300 kt", weight = 300000, alt = 10000, ias = 300},
    {name = "300 t, 20,000 ft, 320 kt", weight = 300000, alt = 20000, ias = 320},
    {name = "300 t, FL330, M.84", weight = 300000, alt = 33000, mach = 0.84},
}
for _, c in ipairs(CASES) do
    local gust = climb{weight = c.weight, alt = c.alt, ias = c.ias, mach = c.mach, rms = 0.5}
    local gust0 = climb{weight = c.weight, alt = c.alt, ias = c.ias, mach = c.mach, rms = 0.5, no_accel = true}
    local big = climb{weight = c.weight, alt = c.alt, ias = c.ias, mach = c.mach, rms = 1.3}
    local big0 = climb{weight = c.weight, alt = c.alt, ias = c.ias, mach = c.mach, rms = 1.3, no_accel = true}
    print(string.format("%-26s 0.5 kt: pitch %.2f deg (before %.2f), V/S %.0f fpm (before %.0f) | 1.3 kt: pitch %.2f (before %.2f), V/S %.0f (before %.0f)",
        c.name, gust.pp, gust0.pp, gust.vpp, gust0.vpp, big.pp, big0.pp, big.vpp, big0.vpp))
    T.check(gust.pp <= 0.4, c.name .. ": 0.5 kt rms of gust, the pitch's share within 0.4 degree: " .. string.format("%.2f (on the IAS's rate %.2f)", gust.pp, gust0.pp))
    T.check(gust0.pp >= 0.7, c.name .. ": (the gust's measure) on the IAS 0.7 degree or more: " .. string.format("%.2f", gust0.pp))
    if c.alt == 10000 then
        local fo = climb{weight = c.weight, alt = c.alt, ias = c.ias, rms = 0.5, flaps_out = true}
        local fo0 = climb{weight = c.weight, alt = c.alt, ias = c.ias, rms = 0.5, flaps_out = true, no_accel = true}
        T.near(fo.pp, fo0.pp, 1e-9, c.name .. ", the flaps out: the IAS as before (" .. string.format("%.2f", fo.pp) .. ")")
    end
end

-- a sustained shear: the air's speed 10 kt less over 10 s (the airplane's
-- airspeed itself, no inertial acceleration to it), at 300 t, 10,000 ft and
-- 300 kt: the speed's least and the time back within 2 kt of the target
local function shear(no_accel)
    local m = Sim.new{alt = 10000, ias = 300, weight = 300000,
        ps = Sim.perf_ps({weight = 300000}), lever = 0.83, vs = 2000}
    m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
    m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", A.THR_REF
    m.target = {ias = 300}
    if no_accel then m.accel_in = false end
    m:run(300)
    local lo, back, t = 1e9, nil, 0
    local KT = 1852 / 3600
    for _ = 1, math.floor(120 / m.dt + 0.5) do
        if t < 10 then
            m.tas = m.tas - 1 * m.dt * m.tas / m.ias
        end
        m:step()
        t = t + m.dt
        lo = math.min(lo, m.ias - 300)
        if t > 10 and not back and math.abs(m.ias - 300) <= 2 then back = t end
        if back and math.abs(m.ias - 300) > 2 then back = nil end
    end
    return lo, back or 999
end
local lo1, back1 = shear(false)
local lo0, back0 = shear(true)
print(string.format("shear 10 kt over 10 s: least %+.1f kt, back within 2 kt at %.0f s (on the IAS's rate %+.1f kt, %.0f s)", lo1, back1, lo0, back0))
T.check(lo1 >= -11, "a 10 kt shear over 10 s: the speed's least no more than 11 kt under the target: " .. string.format("%+.1f (on the IAS's rate %+.1f)", lo1, lo0))
T.check(back1 <= 45, "and back within 2 kt of it within 45 s: " .. string.format("%.0f s (on the IAS's rate %.0f)", back1, back0))
T.done()
