-- Run from the repository root with LuaJIT: luajit tests/fltctrls/aero_corr_model_test.lua
-- The drag corrections (plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua,
-- 補正) against FCOM PI.16.3 (p.303) and the custom acf's gear
-- (docs/overhaul/notes/AERO.md §3.16).
local T = dofile("tests/lib/check.lua")("aero_corr_model")
local A = dofile("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.aero_corr_model.lua")

-- the gear: X-Plane's CD 0.0219 to the FCOM's 0.0260 (EPR) and 0.0265 (fuel flow)
T.near(0.0219 + A.CD_GEAR, 0.02625, 0.0003, "X-Plane's gear and the correction: between the EPR's and the fuel flow's")

-- the fuselage's drag coefficient (the custom acf's 0.085)
T.equal(A.fuse_cd(0.085, 0), 0.085, "gear up: the acf's own")
T.near(A.fuse_cd(0.085, 1), 0.085 + 0.0044 / 0.0664, 1e-12, "gear down: + CD 0.0044 over 0.0664 a unit")
T.near(A.fuse_cd(0.085, 1), 0.1513, 0.0001, "gear down: 0.151")
T.near((A.fuse_cd(0.085, 1) - 0.085) * A.CD_PER_FUSE_CD, 0.0044, 1e-12, "the CD added: 0.0044")
T.near(A.fuse_cd(0.085, 0.5) - 0.085, (A.fuse_cd(0.085, 1) - 0.085) / 2, 1e-12, "half out: half")
T.near(A.fuse_cd(0.1, 1) - 0.1, A.fuse_cd(0.085, 1) - 0.085, 1e-12, "the same increment on another acf's value")

-- (2026-11-07) the cruise above about M.83 (notes/AERO.md §3.17), on the
-- 541.2 m2 area of the correction's figures: the standard atmosphere's
-- pressure, the dynamic pressure and the lift coefficient at a flight level
local function p_isa(ft)
    if ft <= 36089 then return 101325 * (1 - 6.87559e-6 * ft) ^ 5.25588 end
    return 22632.06 * math.exp(-4.80634e-5 * (ft - 36089))
end
local function q_of(m, ft) return 0.7 * p_isa(ft) * m * m end
local function cl_of(t, m, ft) return A.cl(t * 1000, q_of(m, ft)) end
local function corr(t, ft, m) return A.cd_mach(m, t * 1000, cl_of(t, m, ft)) end
T.near(cl_of(340, 0.860, 35000), 0.499, 0.001, "340 t FL350 M.860: CL 0.499")
T.equal(A.cl(300000, 0), nil, "no dynamic pressure (on the ground): no CL")
-- the FCOM's part at its long range cruise cells (PI.11.2, p.268; the
-- fuel flow at X-Plane's SFC for the thrust, over the polar), within
-- 0.0002: the fit's 0.0001 rms
local function rt(t, ft, m) return A.cd_fcom(m, cl_of(t, m, ft)) end
for _, p in ipairs({
    {300, 35000, 0.861, 0.00112}, {320, 35000, 0.861, 0.00172}, {340, 35000, 0.860, 0.00267},
    {360, 35000, 0.860, 0.00407}, {300, 37000, 0.861, 0.00230}, {320, 37000, 0.860, 0.00357},
    {260, 37000, 0.857, 0.00099}, {340, 31000, 0.855, 0.00074}, {380, 33000, 0.860, 0.00314},
}) do
    T.near(rt(p[1], p[2], p[3]), p[4], 0.0002,
        string.format("FCOM %d t FL%d M%.3f: %.5f", p[1], p[2] / 100, p[3], p[4]))
end
-- the correction against what the perf kit's points need (PERF_SIMBRIEF
-- phase 1, no correction: X-Plane's fuel flow over the FCOM's at the cells
-- between its weights, as CD at X-Plane's SFC there), and today's two cells
-- not used in any fit, within 0.0005 (about 1.6 % of the fuel flow). At
-- FL390 the drag's: the fuel flow's 0.00185 and the FCOM's fuel per thrust
-- there 1.2 % over FL370's (its EPR column: the perf session) on CD 0.0286
for _, p in ipairs({
    {237, 39000, 0.857, 0.00185 + 0.012 * 0.0286, "237 t FL390 M.857 (+6.5 % before)"},
    {306, 33000, 0.8527, 0.00240, "306 t FL330 M.853 (+8.7 %)"},
    {306, 35000, 0.861, 0.00333, "306 t FL350 M.861 (+11.3 %)"},
    {306, 37000, 0.8607, 0.00229, "306 t FL370 M.861 (+7.0 %)"},
    {353, 31000, 0.8589, 0.00428, "353 t FL310 M.859 (+15.2 %)"},
    {353, 33000, 0.8614, 0.00396, "353 t FL330 M.861 (+12.8 %)"},
    {260, 37000, 0.857, 0.00288, "260 t FL370 M.857 (aero_lrc_check, raw from the drag)"},
    {340, 35000, 0.860, 0.00185, "340 t FL350 M.860 (aero_lrc_check: v2 left -7.1 %)"},
}) do
    local got = corr(p[1], p[2], p[3])
    T.near(got, p[4], 0.0005, p[5] .. ": " .. string.format("%.5f taken off", got))
end
-- X-Plane's onset by the weight: the table's at its weights, between them in
-- proportion; the correction there none
for _, p in ipairs(A.XP_M0) do
    T.near(A.cd_mach(p[2], p[1] * 1000, 0.45), 0, 1e-12, p[1] .. " t at its onset M" .. p[2] .. ": none")
end
-- 270 t, the long range cruise of §3.9 (aero_lrc_cruise 2026-11-07: -1.2,
-- 0.0, +0.4 and +1.0 % of the FCOM's fuel flow at M.797, .814, .831, .840
-- at FL290-FL350)
T.equal(corr(270, 29000, 0.797), 0, "270 t M.797: none")
T.equal(corr(270, 31000, 0.814), 0, "270 t M.814: none")
T.equal(corr(270, 33000, 0.831), 0, "270 t M.831: none")
T.near(corr(270, 35000, 0.840), 0.0003, 0.0001, "270 t M.840: about 0.0003 (+1.0 % to about 0)")
T.equal(A.cd_mach(0.80, 353000, 0.5), 0, "353 t M.80: none")
T.equal(A.cd_mach(nil, 300000, 0.45), 0, "no Mach: none")
T.equal(A.cd_mach(0.86, nil, 0.45), 0, "no weight: none")
T.near(A.cd_mach(0.86, 300000, nil), A.cd_mach(0.86, 300000, A.RT_CL_MIN), 1e-12, "no CL: RT_CL_MIN's")
T.near(A.cd_mach(0.88, 300000, 0.45), A.cd_mach(A.M_TOP, 300000, 0.45), 1e-12, "the same above M_TOP")
T.near(A.cd_mach(0.95, 300000, 0.45), A.cd_mach(A.M_TOP, 300000, 0.45), 1e-12, "and at M.95")
T.equal(A.cd_mach(0.86, 380000, 0.60), 0, "never negative (CL 0.60: the FCOM's more than X-Plane's)")
T.check(A.cd_mach(0.85, 50000, 0.2) >= 0, "never negative (a light airplane)")
-- below the cells' lift (RT_CL_MIN): the FCOM's onset later by RT_KORN a
-- unit of CL (Korn's CL term, 0.1 / cos^3 37.5 deg), at RT_CL_MIN's CL
T.near(A.RT_KORN, 0.1 / math.cos(math.rad(37.5)) ^ 3, 0.001, "RT_KORN: 0.1 / cos^3 37.5 deg")
T.near(A.cd_fcom(0.86, 0.29), A.RT_K * (0.86 - A.RT_KORN * (A.RT_CL_MIN - 0.29) - A.RT_M0) * (A.RT_CL_MIN / 0.45) ^ A.RT_N, 1e-12,
    "CL 0.29 (237 t FL310, M.86): the onset 0.018 later")
T.near(A.cd_fcom(0.86, A.RT_CL_MIN - 1e-9), A.cd_fcom(0.86, A.RT_CL_MIN), 1e-9, "joined at RT_CL_MIN")
T.equal(A.cd_fcom(0.86, 0.10), 0, "CL 0.10: none (the onset above M.86), never below")
local up = true
for _, m in ipairs({0.84, 0.85, 0.86, 0.87}) do
    local last = -1
    for c = 0.10, 0.60, 0.005 do
        local v = A.cd_fcom(m, c)
        if v < last - 1e-12 then up = false end
        last = v
    end
end
T.check(up, "the FCOM's part never less with more lift, CL 0.10 to 0.60")
-- no altitude's part (above FL370 the FCOM's more fuel is the fuel per
-- thrust, its EPR column: notes/AERO.md §3.17)
T.equal(A.cd_alt, nil, "no altitude term")
-- never a dip in the drag force with the Mach where the airplane flies
-- (the first shape, from M.843 only, left 307 t 3.6 % less thrust at M.855
-- than at M.844; v2 had 340 t at FL350 0.5 % less at M.861 than at M.852):
-- X-Plane's own CD (the polar and XP_SLOPE from its onset: the perf kit's
-- to M.873, not stopped at M_TOP as the correction is) less the
-- correction, times M^2, at 200 to 400 t and FL290 to FL430, M.83 to .88,
-- on the front of the drag curve (CL to 0.50)
local function xp_onset(t)                -- XP_M0's, as the module has it
    local p = A.XP_M0
    local a, b = p[1], p[2]
    if t > p[2][1] then a, b = p[2], p[3] end
    return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
end
local dip = nil
for t = 200, 400, 20 do
    for ft = 29000, 43000, 2000 do
        local last
        for m = 0.830, 0.8801, 0.001 do
            local c = cl_of(t, m, ft)
            if c <= 0.50 then
                local xp = A.XP_SLOPE * math.max(m - xp_onset(t), 0)
                local cd = 0.0171 + 0.055 * c * c + xp - A.cd_mach(m, t * 1000, c)
                local d = m * m * cd
                if last and d < last * (1 - 1e-9) and not dip then dip = string.format("%d t FL%d M%.3f", t, ft / 100, m) end
                last = d
            else
                last = nil
            end
        end
    end
end
T.check(dip == nil, "the corrected drag force never less with more Mach" .. (dip and (": " .. dip) or ""))
-- on the fuselage's coefficient, with the gear's
local q86 = q_of(0.86, 35000)
local c86 = A.cl(306000, q86)
T.near(A.fuse_cd(0.085, 0, 0.86, 306000, q86), 0.085 - A.cd_mach(0.86, 306000, c86) / A.CD_PER_FUSE_CD, 1e-12, "M.86, 306 t, FL350: the acf's less the excess")
T.near(A.fuse_cd(0.085, 0, 0.86, 306000, q86), 0.0395, 0.001, "about 0.040")
T.near(A.fuse_cd(0.085, 1, 0.86, 306000, q86) - A.fuse_cd(0.085, 0, 0.86, 306000, q86), A.CD_GEAR / A.CD_PER_FUSE_CD, 1e-12, "the gear's on top, the same")
T.equal(A.fuse_cd(0.085, 0, 0.80, 306000, q_of(0.80, 35000)), 0.085, "M.80 at FL350: the acf's own")
T.equal(A.fuse_cd(0.085, 0, 0.80, 237000, q_of(0.80, 39000)), 0.085, "M.80 at FL390: the acf's own (no altitude's part)")
T.equal(A.fuse_cd(0.085, 0, nil, nil, nil), 0.085, "no Mach (the correction off): the acf's own")
T.equal(A.fuse_cd(0.01, 0, 0.90, 400000, q_of(0.90, 31000)), 0, "never below 0")

T.done()
