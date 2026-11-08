-- Run from the repository root with LuaJIT: luajit tests/eec/sfc_corr_model_test.lua
-- (2026-11-07) The engines' fuel per thrust above FL370 and (2026-11-08) at
-- high thrust in the cruise
-- (plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua, 補正)
-- against FCOM PI.11.2 (p.268, the PW4056's long range cruise): each cell
-- from FL390 up against X-Plane's fuel flow at the drag the correction gives
-- (the polar and B747.45.aero_corr_model.lua's cd_fcom, v6) and the perf
-- kit's fuel per thrust for that thrust (notes/AERO.md §3.18).
local T = dofile("tests/lib/check.lua")("sfc_corr_model")
local S = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua")
local A = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua")

-- the altitude factor's shape
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

-- (2026-11-08) the thrust factor: v6 0.00082 a kN of corrected thrust from
-- 200 kN an engine (the PI.11.2 cells' fuel flow over their EPR's thrust);
-- v7 (the same night) 0.0005 a kN from 175 kN, refitted on X-Plane's fuel
-- per thrust as the perf runs measured it (a curve in N1, not the perf
-- kit's law in the thrust: the heavy cells below FL370 need 0.5-2.5 % more
-- than v6 gave); capped at 280 (+5.25 %, v6 +6.6 %), none under M.70 and
-- whole from M.80 (the takeoff's and the low climb's fuel kept)
T.equal(S.thrust_factor(nil, 0.86), 1, "no thrust: 1")
T.equal(S.thrust_factor(250, nil), 1, "no Mach: 1")
T.equal(S.thrust_factor(150, 0.86), 1, "F/d 150 kN: 1")
T.equal(S.thrust_factor(175, 0.86), 1, "F/d 175 kN: 1 (the line's start)")
T.near(S.thrust_factor(200, 0.86), 1.0125, 1e-12, "F/d 200 kN: +1.25 % (v6: none; 353 t FL310's cell at 199 kN burned 1.45 % less per thrust than the FCOM's)")
T.near(S.thrust_factor(250, 0.86), 1.0375, 1e-12, "F/d 250 kN at M.86: +3.75 % (v6 +4.1)")
T.near(S.thrust_factor(260, 0.86), 1.0425, 1e-12, "F/d 260 kN (the heaviest cell, 360 t FL350): +4.25 % (v6 +4.9)")
T.near(S.thrust_factor(280, 0.86), 1.0525, 1e-12, "F/d 280 kN: +5.25 % (the cap; v6 +6.6)")
T.near(S.thrust_factor(300, 0.86), S.thrust_factor(280, 0.86), 1e-12, "F/d 300 kN: the cap's")
T.equal(S.thrust_factor(252.4, 0.25), 1, "the takeoff (252.4 kN standing, M.25): 1")
T.equal(S.thrust_factor(252.4, 0.70), 1, "M.70: 1")
T.near(S.thrust_factor(252.4, 0.75), 1 + 0.0005 * 77.4 / 2, 1e-12, "M.75: half of it")
T.near(S.thrust_factor(252.4, 0.80), 1 + 0.0005 * 77.4, 1e-12, "M.80: all of it")
T.near(S.thrust_factor(252.4, 0.90), S.thrust_factor(252.4, 0.80), 1e-12, "M.90: the same")
up = true
last = 0
for fd = 0, 400, 1 do
    local f = S.thrust_factor(fd, 0.86)
    if f < last then up = false end
    last = f
end
T.check(up, "never less with more thrust")
-- the two together
T.near(S.total(43000, 250, 0.86), 1.036 * 1.0375, 1e-12, "FL430, 250 kN, M.86: the altitude's times the thrust's")
T.equal(S.total(30000, 170, 0.86), 1, "FL300, 170 kN: neither")
T.equal(S.total(nil, nil, nil), 1, "nothing known: 1")

-- the FCOM's cells (FF/ENG, kg/h) above FL370 against X-Plane's at the
-- correction's drag and the thrust factor: each within 2.5 % of the two
-- factors (the cells' spread with the lift and the thrust: from 2026-11-07
-- the drag correction leaves the cells of CL 0.5 and more up to 0.8 %
-- short; v6, 2026-11-08: 200 t FL410 needed +1.2 % on the perf kit's law),
-- and the cells' mean at each level within 1.5 % (v6 on the law: +0.25,
-- +0.35 and +0.18 % at FL390, FL410 and FL430; v7 on the measured curve:
-- -1.0, -0.8 and -0.9 %, the worst cell -1.75 % (200 t FL390, the LRC
-- M.829 outside the curve's Machs): the altitude table of 2026-11-07 is left as it
-- is, X-Plane's own drag at 237 t FL390 sits 1 % under the models' line in
-- every cruise run (B747.45.aero_corr_model.lua's v7), which the fuel flow
-- there carries; to be seen in X-Plane)
local G, AREA = 9.80665, 541.2
local function p_isa(ft)
    if ft <= 36089 then return 101325 * (1 - 6.87559e-6 * ft) ^ 5.25588 end
    return 22632.06 * math.exp(-4.80634e-5 * (ft - 36089))
end
-- X-Plane's fuel per thrust, lb/lbf/h, at a thrust an engine (kN): from v7
-- the perf kit's five cruise runs' curve in N1, N1 from the corrected
-- thrust, the Mach and sqrt(theta) (tests/fltctrls/aero_corr_model_test.lua
-- has the same); to v6 the perf kit's law (0.516 to 40 kN, 0.00035 more a
-- kN above)
local function sfc_of(tkn, ft, m)
    local fd = tkn / (p_isa(ft) / 101325)
    local th = (ft <= 36089 and (288.15 - 0.0019812 * ft) or 216.65) / 288.15
    local n1 = (96.120 + 0.14637 * (fd - 200) - 0.0000636 * (fd - 200) ^ 2 - 1.540 * (m - 0.86)) * math.sqrt(th)
    return 0.51749 - 0.0004279 * (n1 - 84) + 0.00037642 * (n1 - 84) ^ 2 + 0.0888 * (m - 0.86)
end
local cells = {
    {280, 39, .860, 2472}, {260, 39, .861, 2252}, {240, 39, .859, 2074}, {220, 39, .846, 1901}, {200, 39, .829, 1740},
    {260, 41, .860, 2341}, {240, 41, .861, 2102}, {220, 41, .860, 1921}, {200, 41, .846, 1755},
    {240, 43, .860, 2196}, {220, 43, .861, 1943}, {200, 43, .860, 1760},
    {200, 45, .861, 1775},
}
local sum, n = {}, {}
for _, c in ipairs(cells) do
    local w, fl, m, ff = c[1], c[2], c[3], c[4]
    local p = p_isa(fl * 1000)
    local qS = 0.7 * p * m * m * AREA
    local cl = w * 1000 * G / qS
    local t = (0.0171 + 0.055 * cl * cl + A.cd_fcom(m, cl) + A.cd_low(m, cl)) * qS / 4
    local need = ff / (sfc_of(t / 1000, fl * 1000, m) / G * t)
    local have = S.total(fl * 1000, t / 1000 / (p / 101325), m)
    T.near(have, need, 0.025,
        string.format("FCOM %d t FL%d M%.3f: %.1f %% needed, %.1f %% given", w, fl * 10, m, (need - 1) * 100, (have - 1) * 100))
    sum[fl] = (sum[fl] or 0) + need / have
    n[fl] = (n[fl] or 0) + 1
end
for _, fl in ipairs({39, 41, 43}) do
    T.near(sum[fl] / n[fl], 1, 0.015, string.format("FL%d: the cells' mean over the model's %+.2f %%", fl * 10, (sum[fl] / n[fl] - 1) * 100))
end

T.done()
