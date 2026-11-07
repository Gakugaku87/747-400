-- Run from the repository root with LuaJIT: luajit tests/eec/sfc_corr_model_test.lua
-- (2026-11-07) The engines' fuel per thrust above FL370
-- (plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua, 補正)
-- against FCOM PI.11.2 (p.268, the PW4056's long range cruise): each cell
-- from FL390 up against X-Plane's fuel flow at the drag the correction gives
-- (the polar and B747.45.aero_corr_model.lua's cd_fcom) and the perf kit's
-- fuel per thrust for that thrust (notes/AERO.md §3.18).
local T = dofile("tests/lib/check.lua")("sfc_corr_model")
local S = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua")
local A = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua")

-- the factor's shape
T.equal(S.factor(nil), 1, "no altitude: 1")
T.equal(S.factor(0), 1, "sea level: 1")
T.equal(S.factor(31000), 1, "FL310: 1")
T.equal(S.factor(37000), 1, "FL370: 1")
T.near(S.factor(38000), 1.009, 1e-12, "FL380: half way to FL390's")
T.near(S.factor(39000), 1.018, 1e-12, "FL390: +1.8 %")
T.near(S.factor(41000), 1.029, 1e-12, "FL410: +2.9 %")
T.near(S.factor(43000), 1.036, 1e-12, "FL430: +3.6 %")
T.near(S.factor(45000), 1.036, 1e-12, "FL450: FL430's")
local up = true
local last = 0
for ft = 0, 50000, 100 do
    local f = S.factor(ft)
    if f < last then up = false end
    last = f
end
T.check(up, "never less with more altitude")

-- the FCOM's cells (FF/ENG, kg/h) above FL370 against X-Plane's at the
-- correction's drag: each within 1.0 % of the factor (the cells' spread with
-- the lift and the thrust: from 2026-11-07 the drag correction v4 leaves
-- the cells of CL 0.5 and more up to 0.8 % short, 240 t FL430 needs +4.5 %),
-- and the cells' mean at each level within 0.15 %
local G, AREA = 9.80665, 541.2
local function p_isa(ft)
    if ft <= 36089 then return 101325 * (1 - 6.87559e-6 * ft) ^ 5.25588 end
    return 22632.06 * math.exp(-4.80634e-5 * (ft - 36089))
end
-- X-Plane's fuel per thrust, lb/lbf/h, at a thrust an engine (kN): the perf
-- kit's points (0.516 to 40 kN, 0.00035 more a kN above)
local function sfc_of(tkn) return 0.516 + 0.00035 * math.max(tkn - 40, 0) end
local cells = {
    {280, 39, .860, 2472}, {260, 39, .861, 2252}, {240, 39, .859, 2074}, {220, 39, .846, 1901}, {200, 39, .829, 1740},
    {260, 41, .860, 2341}, {240, 41, .861, 2102}, {220, 41, .860, 1921}, {200, 41, .846, 1755},
    {240, 43, .860, 2196}, {220, 43, .861, 1943}, {200, 43, .860, 1760},
    {200, 45, .861, 1775},
}
local sum, n = {}, {}
for _, c in ipairs(cells) do
    local w, fl, m, ff = c[1], c[2], c[3], c[4]
    local qS = 0.7 * p_isa(fl * 1000) * m * m * AREA
    local cl = w * 1000 * G / qS
    local t = (0.0171 + 0.055 * cl * cl + A.cd_fcom(m, cl)) * qS / 4
    local need = ff / (sfc_of(t / 1000) / G * t)
    T.near(S.factor(fl * 1000), need, 0.010,
        string.format("FCOM %d t FL%d M%.3f: %.1f %% needed", w, fl * 10, m, (need - 1) * 100))
    sum[fl] = (sum[fl] or 0) + need
    n[fl] = (n[fl] or 0) + 1
end
for _, fl in ipairs({39, 41, 43}) do
    T.near(S.factor(fl * 1000), sum[fl] / n[fl], 0.0015, string.format("FL%d: the cells' mean", fl * 10))
end

T.done()
