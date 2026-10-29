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
        if e > P.IDLE_EPR + 0.001 then ok = ok and math.abs(P.thrust(e, 1, M) - f) < 0.05 end
        mono = mono and e >= prev
        prev = e
    end
    T.check(ok, string.format("thrust from EPR undoes EPR from thrust at M%.2f", M))
    T.check(mono, string.format("EPR rises with thrust at M%.2f", M))
end
T.equal(P.epr(0, 1, 0.5), P.IDLE_EPR, "EPR: no thrust shows the idle EPR")
T.equal(P.epr(-15, 0.3, 0.8), P.IDLE_EPR, "EPR: negative thrust (idle descent) shows the idle EPR")
T.check(P.epr(30, 0.3, 0.8) == P.IDLE_EPR, "EPR: held at the idle EPR at little thrust high and fast")
-- the takeoff run at EPR 1.51 (no figures: the interpolation, estimate)
local lapse = P.thrust(1.51, 1, 0.2) / P.thrust(1.51, 1, 0)
T.check(lapse > 0.90 and lapse < 0.97, string.format("takeoff: thrust at EPR 1.51 and M.2 is %.1f %% of standing", lapse * 100))

T.done()
