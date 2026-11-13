-- Run from the repository root with LuaJIT: luajit tests/autopilot/alt_capture_test.lua
-- (2026-11-13; the 2026-11-12 review AFDS-6, B4) The MCP altitude's capture
-- from fast climbs (B747.70.afds_pitch_model.lua's CAPTURE_G): VNAV SPD's
-- climb at the reference thrust on tests/lib/energy_sim.lua's airplane with
-- its lags 1.35 times the tests' (the attitude 2.7 s behind the command, the
-- path 4.05 s more: X-Plane's 747 in the review's records) and ALT's gain by
-- the lift coefficient (the law gets the dynamic pressure: 0.7 to 0.83
-- here), captured as the glue does (the capture's distance), then ALT with
-- the A/T's SPD. From 3,500 to 5,000 fpm within 50 ft past the altitude
-- (before: 87 to 282 ft; s139 92 and 94 ft from 3,500 fpm at 346 kt), the
-- load factor within the capture's 0.05 g (ATA22 p.286); 2,000 fpm as
-- before (within 5 ft past, within 20 ft of it in 60 s).
local T = dofile("tests/lib/check.lua")("alt_capture")
local Sim = dofile("tests/lib/energy_sim.lua")
local P, A = Sim.P, Sim.A
local G, FT = 9.80665, 0.3048

local function capture(o)
    local vfs = o.vs / 60
    local below = vfs * vfs / (2 * 0.04 * 32.174) + 10 * vfs + 2500
    local m = Sim.new{alt = o.level - below, ias = o.ias, vs = o.vs, weight = o.weight, q = true,
        ps_ref = o.vs * 1.12, ps_idle = -2200, lever = 0.83, tau_pitch = 2 * o.lag, tau_path = 3 * o.lag}
    m.pitch_inp.mode, m.pitch_inp.vnav_law, m.pitch_inp.way = "VNAV", "FLCH", 1
    m.at_inp.pitch, m.at_inp.vnav_at = "VNAV", A.THR_REF
    m.target = {ias = o.ias}
    local r = {peak = -1e9, nz = 0, cap_vs = nil, t_cap = nil, t_in = nil}
    local last_vs = m.vs
    for _ = 1, math.floor((60 + below / vfs + 200) / m.dt + 0.5) do
        local pi = m.pitch_inp
        if not r.t_cap then
            pi.alt, pi.vs = m.alt, m.vs
            if P.capture(pi, o.level) then
                r.t_cap, r.cap_vs = m.t, m.vs
                pi.mode, pi.vnav_law, pi.hold_alt, pi.way = "ALT", nil, o.level, 0
                m.at_inp.pitch, m.at_inp.vnav_at = "ALT", nil
            end
        end
        m:step()
        if r.t_cap then
            r.peak = math.max(r.peak, m.alt - o.level)
            r.nz = math.max(r.nz, math.abs((m.vs - last_vs) / 60 * FT / m.dt / G))
            if not r.t_in and math.abs(m.alt - o.level) < 20 then r.t_in = m.t - r.t_cap end
        end
        last_vs = m.vs
    end
    return r
end

local CASES = {
    {ias = 346, level = 17000, weight = 269000, name = "346 kt to 17,000 ft, 269 t"},
    {ias = 250, level = 10000, weight = 238000, name = "250 kt to 10,000 ft, 238 t"},
}
for _, c in ipairs(CASES) do
    for _, vs in ipairs({3500, 4000, 5000}) do
        local r = capture{ias = c.ias, level = c.level, weight = c.weight, vs = vs, lag = 1.35}
        T.check(r.peak <= 50, string.format("%s from %d fpm (%d at the capture): within 50 ft past the altitude: %.0f ft", c.name, vs, r.cap_vs, r.peak))
        T.check(r.nz <= 0.055, string.format("  and within the capture's 0.05 g: %.3f g", r.nz))
    end
    local r = capture{ias = c.ias, level = c.level, weight = c.weight, vs = 2000, lag = 1.35}
    T.check(r.peak <= 5, string.format("%s from 2,000 fpm: within 5 ft past the altitude: %.0f ft", c.name, r.peak))
    T.check(r.t_in and r.t_in <= 60, string.format("  within 20 ft of it in 60 s: %s s", tostring(r.t_in and math.floor(r.t_in + 0.5))))
end

-- (2026-11-13) X-Plane's s313: V/S +5,000 fpm to 10,000 ft at 238 t, the
-- A/T's SPD 250 kt at the thrust's limit (the climb beyond it: the speed 8
-- kt short and decaying at the capture); 108.5 ft past at 0.0425 g. The
-- speed's recovery in the level-off took the angle of attack down (4.1 to
-- 3.56 degrees), the path turning at 0.038 g under the attitude's 0.05 g.
-- On the angle of attack by the dynamic pressure (energy_sim's alpha_q),
-- from X-Plane's state at the capture (4,941 fpm, 241.6 kt, 4.04 degrees),
-- the thrust's excess that loses 6 kt as there: within 50 ft past (0.0425
-- g: 67 to 99 ft)
local function vs_capture(o)
    local vfs = o.vs / 60
    local d = vfs * vfs / (2 * P.CAPTURE_G * G / FT) + vfs * P.CAPTURE_LAG_S
    local m = Sim.new{alt = o.level - d - 5, ias = o.ias, vs = o.vs, weight = o.weight, q = true,
        alpha_q = true, alpha = o.alpha, ps_ref = o.ps_ref, ps_idle = -2200, lever = 0.83,
        tau_pitch = 2 * o.lag, tau_path = 3 * o.lag}
    local pi = m.pitch_inp
    pi.mode, pi.vs_sel = "VS", o.vs
    m.at_inp.pitch, m.at_inp.spd = "VS", true
    m.target = {ias = o.tgt}
    local r = {peak = -1e9, nz = 0, lo = 1e9}
    local last_vs = m.vs
    for _ = 1, math.floor(300 / m.dt + 0.5) do
        if not r.t_cap then
            pi.alt, pi.vs = m.alt, m.vs
            if P.capture(pi, o.level) then
                r.t_cap = m.t
                pi.mode, pi.hold_alt, pi.way = "ALT", o.level, 0
                m.at_inp.pitch = "ALT"
            end
        end
        m:step()
        if r.t_cap then
            r.peak = math.max(r.peak, m.alt - o.level)
            r.nz = math.max(r.nz, math.abs((m.vs - last_vs) / 60 * FT / m.dt / G))
            r.lo = math.min(r.lo, m.ias)
            if not r.t_in and math.abs(m.alt - o.level) < 20 then r.t_in = m.t - r.t_cap end
        end
        last_vs = m.vs
    end
    return r
end
for _, c in ipairs({{ps = 4470, lag = 1.35}, {ps = 4300, lag = 1.35}, {ps = 4700, lag = 1.6}}) do
    local r = vs_capture{vs = 4941, ias = 241.6, tgt = 250, alpha = 4.04, level = 10000, weight = 238000,
        ps_ref = c.ps, lag = c.lag}
    T.check(r.t_cap ~= nil and r.peak <= 50, string.format("s313's V/S climb (the thrust's excess %d fpm, the lags %.2f times, down to %.1f kt): within 50 ft past: %.0f ft",
        c.ps, c.lag, r.lo, r.peak))
    T.check(r.nz <= 0.055, string.format("  and within the capture's 0.05 g: %.3f g", r.nz))
    T.check(r.t_in and r.t_in <= 120, string.format("  within 20 ft of it in 120 s: %s s", tostring(r.t_in and math.floor(r.t_in + 0.5))))
end
T.done()
