-- Run from the repository root with LuaJIT: luajit tests/eec/epr_model_test.lua
-- The P&W EPR the EICAS shows (plugins/xtlua/scripts/B747.42.xt.EEC/
-- B747.42.epr_model.lua, ENG-33) against the points it was made from: the
-- FCOM's EPR (PW4056, PI.10.36-10.40 p.262-266, PI.11.2 p.268) at the thrust
-- the custom acf needs there, and the ICAO rated thrust (ICAO_EEDB 1PW041).
local T = dofile("tests/lib/check.lua")("epr_model")
local P = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.epr_model.lua")

-- standard atmosphere pressure ratio at a pressure altitude (ft)
local function delta(h) return (1 - 6.87559e-6 * h) ^ 5.25588 end

-- the points: per engine thrust kN, pressure altitude ft, Mach, FCOM EPR
local POINTS = {
    {252.4, 0, 0.0, 1.51, "takeoff standing at sea level (ICAO rated thrust, go-around table)"},
    {152.7, 0, 0.438, 1.25, "max climb, sea level, 290 KIAS"},
    {44.8, 0, 0.438, 0.984, "level, sea level, 290 KIAS"},
    {128.0, 10000, 0.523, 1.35, "max climb, 10,000 ft"},
    {44.2, 10000, 0.523, 0.988, "level, 10,000 ft"},
    {100.9, 20000, 0.631, 1.43, "max climb, 20,000 ft"},
    {43.3, 20000, 0.631, 1.006, "level, 20,000 ft"},
    {74.6, 30000, 0.766, 1.57, "max climb, 30,000 ft"},
    {42.6, 30000, 0.766, 1.094, "level, 30,000 ft"},
    {62.7, 35000, 0.840, 1.64, "max climb, 35,000 ft (.84)"},
    {44.45, 29412, 0.797, 1.07, "long range cruise, 29,000 ft"},
    {43.86, 30999, 0.813, 1.10, "long range cruise, 31,000 ft"},
    {43.10, 32999, 0.830, 1.135, "long range cruise, 33,000 ft"},
    {43.82, 34999, 0.843, 1.18, "long range cruise, 35,000 ft"},
}
for _, p in ipairs(POINTS) do
    T.near(P.epr(p[1], delta(p[2]), p[3]), p[4], 0.006, "EPR: " .. p[5])
end

-- points it was not made from, within the FCOM's rounding and the fit
T.near(P.epr(40.4, delta(10000), 0.400), 1.025, 0.02, "EPR: holding, 10,000 ft (PI.11.6)")
T.near(P.epr(40.09, delta(5000), 0.382), 1.034, 0.02, "EPR: terminal area flaps up, 5,000 ft (PI.10.40)")

-- the way back, and the shape
for _, M in ipairs({0, 0.2, 0.438, 0.6, 0.8, 0.85}) do
    local ok, mono, prev = true, true, -1
    for f = 20, 300, 10 do
        local e = P.epr(f, 1, M)
        if e > P.zero(M) + 0.001 then ok = ok and math.abs(P.thrust(e, 1, M) - f) < 0.05 end
        mono = mono and e >= prev
        prev = e
    end
    T.check(ok, string.format("thrust from EPR undoes EPR from thrust at M%.2f", M))
    T.check(mono, string.format("EPR rises with thrust at M%.2f", M))
end
-- (2026-10-31) the least EPR that of no net thrust at the Mach (NPR 1;
-- before, 0.97 at any Mach: at FL300, M.78 no thrust under 34 kN an engine
-- but X-Plane's idle could be set)
T.near(P.epr(0, 1, 0.5), 1 / (1 + 0.2 * 0.25) ^ 3.5, 1e-9, "EPR: no thrust, the exhaust at the ambient pressure (0.843 at M.5)")
-- (2026-11-05) under no net thrust (X-Plane's idle in a fast descent) the
-- law mirrored: on from zero(M) without a step, falling with the thrust,
-- held at NPR 1 - NEG_NPR. Before, every negative thrust read zero(M)
T.near(P.epr(-0.001, 1, 0.66), P.zero(0.66), 1e-4, "EPR: a hair under no net thrust, zero(M) still (no step)")
T.check(P.epr(-5, 1, 0.66) < P.zero(0.66) - 0.005 and P.epr(-15, 1, 0.66) < P.epr(-5, 1, 0.66) - 0.01,
    string.format("EPR: falls with the thrust under none (M.66: -5 kN %.4f, -15 kN %.4f, zero %.4f)",
        P.epr(-5, 1, 0.66), P.epr(-15, 1, 0.66), P.zero(0.66)))
T.near(P.epr(-1000, 1, 0.8), (1 - P.NEG_NPR) * P.zero(0.8), 1e-9, "EPR: held at NPR 1 - NEG_NPR far under none")
T.near(P.thrust(P.epr(-10, 0.5, 0.7), 0.5, 0.7), -10, 1e-6, "thrust from EPR undoes EPR from thrust under none too")
-- (2026-11-05) the idle end's command (B747_epr_model.idle_command): under
-- X-Plane's idle at every Mach the flight tests flew (the most negative
-- corrected net thrust by Mach, 2026-10-31 to 11-05, POINT_thrust over the
-- pressure ratio), by at least 0.015; no net thrust under M.3 (standing 1.00)
for _, p in ipairs({{0.50, 4.4}, {0.55, -0.1}, {0.60, -5.2}, {0.637, -8.5}, {0.70, -12.3},
        {0.737, -14.2}, {0.75, -13.2}, {0.80, -4.3}}) do
    local xp, cmd = P.epr(p[2], 1, p[1]), P.idle_command(p[1])
    T.check(cmd < xp - 0.015, string.format("idle command under X-Plane's idle at M%.3f (%.1f kN): %.4f < %.4f",
        p[1], p[2], cmd, xp))
end
T.near(P.idle_command(0), 1.0, 1e-9, "idle command standing: no net thrust (1.00, under the ground idle's 1.01)")
T.near(P.idle_command(0.3), P.zero(0.3), 1e-9, "idle command at M.3: no net thrust still")
T.check(P.idle_command(0.45) < P.zero(0.45) and P.idle_command(0.45) > P.idle_command(0.6),
    "idle command: faded in between M.3 and M.6")
T.check(P.idle_command(0.78) < P.epr(2, delta(30000), 0.78) - 0.03,
    string.format("idle command at FL300, M.78 %.3f under X-Plane's idle (2 kN) %.3f",
        P.idle_command(0.78), P.epr(2, delta(30000), 0.78)))
local dl300 = delta(30000)
T.check(P.epr(2, dl300, 0.78) < 0.70 and P.epr(26, dl300, 0.78) > 0.85 and P.epr(26, dl300, 0.78) < 0.90
    and P.epr(34, dl300, 0.78) > 0.95,
    string.format("FL300, M.78: X-Plane's idle 2 kN %.3f, 26 kN %.3f, 34 kN %.3f (before 0.97 for all)",
        P.epr(2, dl300, 0.78), P.epr(26, dl300, 0.78), P.epr(34, dl300, 0.78)))
T.near(P.epr(10.3, 1, 0), 1.01, 0.001, "ground idle 10.3 kN: 1.01 still")
-- the takeoff run at EPR 1.51 (no figures: the interpolation, estimate)
local lapse = P.thrust(1.51, 1, 0.2) / P.thrust(1.51, 1, 0)
T.check(lapse > 0.90 and lapse < 0.97, string.format("takeoff: thrust at EPR 1.51 and M.2 is %.1f %% of standing", lapse * 100))

-- (2026-11-03) the N1 from the EPR against the FCOM's Alt Mode %N1 (PW4056,
-- Flight With Unreliable Airspeed, PI.10.38-10.40 p.264-266), ISA: pressure
-- altitude ft, KIAS (M.84 above 30,000 ft: the lower of the two), EPR, N1
local N1_POINTS = {
    -- cruise .84/290, level (PI.10.38)
    {40000, 290, 1.16, 83.2}, {40000, 290, 1.31, 88.0},
    {35000, 290, 1.08, 80.6}, {35000, 290, 1.14, 83.0}, {35000, 290, 1.24, 86.3}, {35000, 290, 1.43, 92.2},
    {30000, 290, 1.02, 77.3}, {30000, 290, 1.07, 79.8}, {30000, 290, 1.13, 82.6}, {30000, 290, 1.21, 85.7}, {30000, 290, 1.32, 89.3},
    {20000, 290, 0.97, 70.5}, {20000, 290, 0.99, 72.7}, {20000, 290, 1.03, 75.3}, {20000, 290, 1.07, 78.1}, {20000, 290, 1.11, 80.8},
    {10000, 290, 0.96, 64.3}, {10000, 290, 0.98, 66.3}, {10000, 290, 1.00, 68.7}, {10000, 290, 1.02, 71.1}, {10000, 290, 1.04, 73.3},
    {0, 290, 0.97, 55.6}, {0, 290, 0.98, 57.8}, {0, 290, 0.99, 60.4}, {0, 290, 1.00, 63.2}, {0, 290, 1.01, 65.7},
    -- holding, 10,000 ft (PI.10.39)
    {10000, 208, 1.01, 55.9}, {10000, 224, 1.02, 61.4}, {10000, 242, 1.03, 66.5}, {10000, 266, 1.04, 70.5}, {10000, 283, 1.04, 73.3},
    -- terminal area, 5,000 ft, flaps up, 1, 5, 10, 20 (PI.10.39)
    {5000, 208, 1.01, 51.4}, {5000, 224, 1.03, 57.5}, {5000, 239, 1.04, 62.5}, {5000, 253, 1.06, 67.1}, {5000, 266, 1.07, 70.8}, {5000, 269, 1.08, 71.5},
    {5000, 188, 1.03, 53.9}, {5000, 204, 1.05, 60.2}, {5000, 219, 1.06, 64.8}, {5000, 233, 1.08, 68.9}, {5000, 246, 1.10, 72.7}, {5000, 249, 1.10, 73.4},
    {5000, 168, 1.06, 57.9}, {5000, 184, 1.08, 63.6}, {5000, 199, 1.10, 68.4}, {5000, 213, 1.12, 72.7}, {5000, 226, 1.15, 76.5}, {5000, 229, 1.15, 77.2},
    {5000, 148, 1.07, 57.8}, {5000, 164, 1.09, 63.8}, {5000, 179, 1.11, 68.8}, {5000, 193, 1.14, 73.1}, {5000, 206, 1.16, 77.0}, {5000, 209, 1.17, 77.7},
    {5000, 138, 1.10, 64.0}, {5000, 154, 1.13, 69.9}, {5000, 169, 1.17, 75.2}, {5000, 183, 1.21, 79.9}, {5000, 196, 1.25, 83.7}, {5000, 199, 1.26, 84.4},
    -- final approach, 1,500 ft, flaps 25 and 30 (PI.10.40)
    {1500, 143, 1.05, 48.8}, {1500, 159, 1.06, 54.8}, {1500, 175, 1.07, 59.7}, {1500, 189, 1.08, 63.7}, {1500, 203, 1.10, 67.2}, {1500, 205, 1.10, 67.9},
    {1500, 138, 1.07, 55.8}, {1500, 154, 1.09, 61.8}, {1500, 168, 1.11, 66.8},
}
local function mach_of(h, kias)
    local qc = (1 + 0.2 * (kias / 661.4786) ^ 2) ^ 3.5 - 1
    return math.min(0.84, math.sqrt(5 * ((qc / delta(h) + 1) ^ (1 / 3.5) - 1)))
end
local s2, worst = 0, 0
for _, p in ipairs(N1_POINTS) do
    local m = mach_of(p[1], p[2])
    local tat = (288.15 - 0.0019812 * p[1]) * (1 + 0.2 * m * m) - 273.15
    local r = P.n1(p[3], m, tat) - p[4]
    s2, worst = s2 + r * r, math.max(worst, math.abs(r))
end
T.equal(#N1_POINTS, 70, "N1: the FCOM's 70 points")
T.check(math.sqrt(s2 / #N1_POINTS) < 1.6 and worst < 4.5,
    string.format("N1: the FCOM's Alt Mode %%N1 within rms %.2f, at most %.1f (low power)", math.sqrt(s2 / #N1_POINTS), worst))
T.near(P.n1(1.51, 0, 15), 100.6, 0.3, "N1: takeoff standing at sea level, 15 C (the previous regression's 100.6, estimate)")
T.near(P.n1(1.51, 0, 30) / P.n1(1.51, 0, 15), math.sqrt(303.15 / 288.15), 1e-9, "N1: the temperature once (the square root of theta_t2)")
local mono = true
for _, m in ipairs({0, 0.2, 0.45, 0.6, 0.84, 0.9}) do
    local prev = -math.huge
    for e = 0.9, 1.8, 0.01 do local n = P.n1c(e, m) mono = mono and n >= prev prev = n end
end
T.check(mono, "N1: rises with the EPR at every Mach")
T.near(P.n1c(1.4, 0), P.n1c(1.4, 0.84), 1e-9, "N1: no Mach effect from EPR 1.35 up")
-- the full run's s10 (2026-11-03): max EPR 1.573 at 10,600 ft, M.45, TAT
-- 28 C under the N2 limit's band (the display's N2 of N1, 111.4 - 0.5 - 2)
local n1_s10 = P.n1(1.573, 0.45, 28)
local n2_s10 = (0.000798 * n1_s10 ^ 2 - 0.154 * n1_s10 + 10.2) * n1_s10 * (3600 / 9900)
T.check(n1_s10 > 102 and n1_s10 < 107 and n2_s10 < 108.9,
    string.format("N1: max EPR at 10,600 ft, M.45, TAT 28 C: N1 %.1f, N2 %.1f under the limit's band (before 109 / 116)", n1_s10, n2_s10))

T.done()
