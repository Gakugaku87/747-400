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
-- X-Plane's own CD over the polar (XP_SLOPE from the weight's onset: the
-- perf kit's 30 points to M.873) less the correction: the drag the airplane
-- flies with (above M_TOP X-Plane's own rise goes on)
local function xp_onset(t)                -- XP_M0's, as the module has it
    local p = A.XP_M0
    local a, b = p[1], p[2]
    if t > p[2][1] then a, b = p[2], p[3] end
    return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
end
local function net_cd(t, ft, m)
    local c = cl_of(t, m, ft)
    return 0.0171 + 0.055 * c * c + A.XP_SLOPE * math.max(m - xp_onset(t), 0) - A.cd_mach(m, t * 1000, c)
end
-- (v4, notes/AERO.md §3.19; v6, 2026-11-08) the FCOM PI.11.2 (p.268) cells
-- with the LRC from M.85: their fuel flow an engine at the LRC from that
-- drag, at X-Plane's fuel per thrust for the thrust (the perf kit's: 0.516
-- lb/lbf/h to 40 kN, 0.00035 more a kN above), the FL370+ SFC correction
-- and, from v6, the SFC's thrust factor (B747.42.sfc_corr_model.lua: the
-- fuel the cells burn over their EPR's thrust, 0.00082 a kN of corrected
-- thrust from 200 kN), within 1.4 % each (the fit: 1.3 % the largest, 400 t
-- FL270 at M.852, 0.5 % rms; v4: 1.0 and 0.5 %)
local SC = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.sfc_corr_model.lua")
local CELLS = {     -- t, FL, LRC Mach, FF/ENG kg/h
    {400, 29, .862, 3466}, {400, 31, .861, 3513}, {380, 29, .858, 3274}, {380, 31, .861, 3284},
    {380, 33, .860, 3375}, {360, 29, .850, 3092}, {360, 31, .861, 3092}, {360, 33, .861, 3124},
    {360, 35, .860, 3256}, {340, 31, .855, 2907}, {340, 33, .862, 2912}, {340, 35, .860, 2973},
    {320, 33, .859, 2731}, {320, 35, .861, 2743}, {320, 37, .860, 2850}, {300, 33, .850, 2555},
    {300, 35, .861, 2554}, {300, 37, .861, 2598}, {280, 35, .854, 2378}, {280, 37, .862, 2391},
    {280, 39, .860, 2472}, {260, 37, .857, 2218}, {260, 39, .861, 2252}, {260, 41, .860, 2341},
    {240, 39, .859, 2074}, {240, 41, .861, 2102}, {240, 43, .860, 2196}, {220, 41, .860, 1921},
    {220, 43, .861, 1943}, {200, 43, .860, 1760}, {200, 45, .861, 1775}, {400, 27, .852, 3467},
}
local function ff_of(t, fl, m)
    local ft = fl * 1000
    local qs = q_of(m, ft) * A.AREA
    local thrust = net_cd(t, ft, m) * qs / 4                      -- N an engine
    local sfc = 0.516 + 0.00035 * math.max(thrust / 1000 - 40, 0)  -- lb/lbf/h
    local fd = thrust / 1000 / (p_isa(ft) / 101325)               -- kN of corrected thrust
    return SC.total(ft, fd, m) * sfc / 9.80665 * thrust           -- kg/h
end
-- the fuel a mile at a weight and level (the fuel flow over the Mach: from
-- v6 the fuel per thrust rises with the thrust, so the drag alone no longer
-- gives the shape along a line)
local function fpm(t, fl, m) return ff_of(t, fl, m) / m end
local sse, worst, sdn, sup, nup = 0, nil, 0, 0, 0
local flat, steep = nil, nil
for _, c in ipairs(CELLS) do
    local e = ff_of(c[1], c[2], c[3]) / c[4] - 1
    sse = sse + e * e
    if not worst or math.abs(e) > math.abs(worst[1]) then worst = {e, string.format("%d t FL%d", c[1], c[2] * 10)} end
    -- the fuel a mile around the LRC at one weight and level
    local g0 = fpm(c[1], c[2], c[3])
    local dn = fpm(c[1], c[2], c[3] - 0.01) / g0 - 1
    local upm = fpm(c[1], c[2], c[3] + 0.01) / g0 - 1
    sdn, sup, nup = sdn + dn, sup + upm, nup + 1
    if upm < 0.015 and not flat then flat = string.format("%d t FL%d %+.1f %%", c[1], c[2] * 10, upm * 100) end
    if (upm > 0.04 or dn < -0.025) and not steep then steep = string.format("%d t FL%d %+.1f %%", c[1], c[2] * 10, upm * 100) end
end
T.check(math.abs(worst[1]) < 0.014, string.format("the FCOM's fuel flow at the LRC: the largest %+.1f %% (%s)", worst[1] * 100, worst[2]))
T.check(math.sqrt(sse / #CELLS) < 0.006, string.format("and %.2f %% rms over the %d cells", math.sqrt(sse / #CELLS) * 100, #CELLS))
-- the fuel a mile around the LRC (FCTM p.129, 4.7: the LRC 1 % less fuel
-- mileage than the best, on the fast side; p.132, 4.10: 0.01 M above the schedule 2 %
-- more fuel: -0.93 and +2.0 % at 0.01 M under and over): on the mean within
-- 0.3 % under and 0.6 % over (v5: +2.4 %, the lift of 0.5 and more steeper;
-- v6: -0.84 and +2.28 %, the fuel per thrust's rise with the thrust in it),
-- each 0.01 M over between +1.5 and +4 % (v3: -0.2 to +0.8 %, the
-- best inside M.85-.87 at heavy, high levels; v4: +0.5 % at CL 0.41; v6:
-- +1.9 to +3.1 %)
T.near(sdn / nup, -0.0093, 0.003, string.format("0.01 M under the LRC: %+.2f %% fuel a mile on the mean", sdn / nup * 100))
T.check(sup / nup > 0.017 and sup / nup < 0.026, string.format("0.01 M over the LRC: %+.2f %% fuel a mile on the mean", sup / nup * 100))
T.check(flat == nil, "0.01 M over the LRC never flat (+1.5 % or more)" .. (flat and (": " .. flat) or ""))
T.check(steep == nil, "and never past +4 %, nor -2.5 % under" .. (steep and (": " .. steep) or ""))
-- the best fuel mileage under each such cell's LRC, the 99 % of it within
-- 0.015 M of the FCOM's LRC (v3: 0.02-0.035 under)
local far = nil
for _, c in ipairs(CELLS) do
    local best, mb = math.huge, nil
    for m = 0.78, 0.92, 0.0002 do
        local v = fpm(c[1], c[2], m)
        if v < best then best, mb = v, m end
    end
    local lrc
    for m = mb, 0.92, 0.0002 do
        if fpm(c[1], c[2], m) >= best / 0.99 then lrc = m; break end
    end
    if not (mb < c[3] and lrc and math.abs(lrc - c[3]) <= 0.015) and not far then
        far = string.format("%d t FL%d: best M%.4f, 99 %% at M%.4f, the FCOM's LRC M%.3f", c[1], c[2] * 10, mb, lrc or 0, c[3])
    end
end
T.check(far == nil, "the best under the LRC, the 99 % within 0.015 M of the FCOM's" .. (far and (": " .. far) or ""))
-- X-Plane's onset by the weight: the table's at its weights, between them in
-- proportion; there only the FCOM's part (a little drag added)
for _, p in ipairs(A.XP_M0) do
    T.near(A.cd_mach(p[2], p[1] * 1000, 0.45), -A.cd_fcom(p[2], 0.45), 1e-12, p[1] .. " t at its onset M" .. p[2] .. ": the FCOM's part added")
end
-- 270 t, the long range cruise of §3.9 at FL290-FL350 exactly (M.797,
-- .814, .831, .840): the FCOM's part and v5's cd_low add 0.0002, 0.0001 and
-- 0.0002 in all, 0.0003 to 0.0005 taken off at M.840 (v6: 0.00045, the
-- FCOM's part smaller). The points flown
-- (aero_lrc_cruise, 29,330-33,050 ft) sit on the FCOM's LRC line, where
-- cd_low adds only 0.00003 to 0.00005: 330 ft (1.4 % of lift) moves it by
-- 0.00016 there (X-Plane 2026-11-07 evening: -1.3, -0.6, -0.9 % of the
-- FCOM's fuel flow; notes/AERO.md §3.20)
T.near(corr(270, 29000, 0.797), -0.0002, 0.0001, "270 t M.797: about 0.0002 added")
T.near(corr(270, 31000, 0.814), -0.0001, 0.0001, "270 t M.814: about 0.0001 added")
T.near(corr(270, 33000, 0.831), -0.0002, 0.0001, "270 t M.831: about 0.0002 added")
T.near(corr(270, 35000, 0.840), 0.00045, 0.0001, "270 t M.840: about 0.00045 (+1.0 % to about 0)")
-- (v5) the light and low cruise past the FCOM's LRC line (notes/AERO.md
-- §3.20): on the line little, LOW_K LOW_CAP far past it, none at high lift
-- and at low Mach
T.check(A.cd_low(0.808 + A.LOW_OFS, 0.363) < 0.0001, "on the LRC line (CL 0.363, M.808): under 0.0001")
T.near(A.cd_low(0.86, 0.30), A.LOW_K * A.LOW_CAP, 1e-12, "far past it (CL 0.30, M.86): LOW_K LOW_CAP")
T.near(A.LOW_K * A.LOW_CAP, 0.000525, 1e-9, "at most CD 0.000525")
T.equal(A.cd_low(0.86, A.LOW_CL[2]), 0, "from LOW_CL[2]: none (v4's wall)")
T.equal(A.cd_low(A.LOW_M[1], 0.30), 0, "at LOW_M[1]: none")
T.near(A.cd_low(0.70, 0.25), 0, 1e-12, "M.70 at CL 0.25 (a light descent): none")
T.equal(A.cd_low(0.86, nil), 0, "no CL: none")
T.near(A.cd_low(0.95, 0.30), A.cd_low(A.M_TOP, 0.30), 1e-12, "the same above M_TOP")
-- the FCOM cells with the LRC from M.745 under M.85 (37): their own LRC
-- (the fast side's 99 % of the best fuel mileage, FCTM p.129, 4.7) within
-- 0.0065 M of the FCOM's (v4: 0.02-0.06 faster; v5: +0.004 at most; v6:
-- +0.006 at 200 t FL410, the FCOM's part smaller at CL 0.40 near M.85),
-- their LRC's drag at most 0.5 % more
local LOW_CELLS = {
    {380, 27, .844}, {360, 27, .834}, {340, 27, .824}, {340, 29, .840}, {320, 27, .811}, {320, 29, .829},
    {320, 31, .846}, {300, 27, .797}, {300, 29, .816}, {300, 31, .834}, {280, 27, .782}, {280, 29, .802},
    {280, 31, .821}, {280, 33, .838}, {260, 27, .765}, {260, 29, .786}, {260, 31, .805}, {260, 33, .825},
    {260, 35, .842}, {240, 27, .745}, {240, 29, .767}, {240, 31, .788}, {240, 33, .808}, {240, 35, .827},
    {240, 37, .845}, {220, 29, .746}, {220, 31, .768}, {220, 33, .789}, {220, 35, .810}, {220, 37, .829},
    {220, 39, .846}, {200, 31, .745}, {200, 33, .767}, {200, 35, .789}, {200, 37, .810}, {200, 39, .829},
    {200, 41, .846},
}
local off, more = nil, nil
for _, c in ipairs(LOW_CELLS) do
    local t, ft, ml = c[1], c[2] * 1000, c[3]
    local best, mb = math.huge, nil
    for m = 0.70, 0.88, 0.0002 do
        local v = fpm(t, c[2], m)
        if v < best then best, mb = v, m end
    end
    local lrc
    for m = mb, 0.90, 0.0002 do
        if fpm(t, c[2], m) >= best / 0.99 then lrc = m; break end
    end
    if not (lrc and math.abs(lrc - ml) <= 0.0065) and not off then
        off = string.format("%d t FL%d: the 99 %% at M%.4f, the FCOM's M%.3f", t, c[2] * 10, lrc or 0, ml)
    end
    local cl = cl_of(t, ml, ft)
    local add = A.cd_low(ml, cl) / net_cd(t, ft, ml)
    if add > 0.005 and not more then more = string.format("%d t FL%d: +%.2f %%", t, c[2] * 10, add * 100) end
end
T.check(off == nil, "the light and low cells' own LRC within 0.0065 M of the FCOM's" .. (off and (": " .. off) or ""))
T.check(more == nil, "and their LRC's drag at most 0.5 % more" .. (more and (": " .. more) or ""))
-- FCOM PI.10.38 (p.264) climb at 290/.84, 200 t at 35,000 ft (CL 0.31,
-- 2,900 fpm): the drag added at most 2.5 % (about 84 fpm)
T.check(A.cd_low(0.84, cl_of(200, 0.84, 35000)) / net_cd(200, 35000, 0.84) < 0.025, "200 t, 35,000 ft, M.84: at most 2.5 % more drag")
T.near(A.cd_mach(0.70, 400000, 0.6), 0, 1e-5, "M.70: none (the FCOM's part under 1e-5)")
T.equal(A.cd_mach(nil, 300000, 0.45), 0, "no Mach: none")
T.equal(A.cd_mach(0.86, nil, 0.45), 0, "no weight: none")
T.equal(A.cd_mach(0.86, 300000, nil), 0, "no CL: none")
T.near(A.cd_mach(0.88, 300000, 0.45), A.cd_mach(A.M_TOP, 300000, 0.45), 1e-12, "the same above M_TOP")
T.near(A.cd_mach(0.95, 300000, 0.45), A.cd_mach(A.M_TOP, 300000, 0.45), 1e-12, "and at M.95")
-- more drag than X-Plane's where the FCOM's is more: in the cruise (CL to
-- 0.55, M.70-.90, 200-400 t, FL250-FL450) at most CD 0.0015 (v6: 0.0010;
-- v5: 0.0025)
local most = 0
for t = 200, 400, 20 do
    for ft = 25000, 45000, 2000 do
        for m = 0.70, 0.9001, 0.005 do
            local c = cl_of(t, m, ft)
            if c <= 0.55 then most = math.min(most, A.cd_mach(m, t * 1000, c)) end
        end
    end
end
T.check(most < 0 and most > -0.0015, string.format("drag added at most CD %.4f", -most))
-- Korn's CL term: the wall earlier by C_KC a unit of CL, between Korn's
-- 0.1 / cos^3 37.5 deg (0.20) and the least error at the LRC (0.30)
T.check(A.C_KC >= 0.1 / math.cos(math.rad(37.5)) ^ 3 - 0.001 and A.C_KC <= 0.30, "C_KC between 0.20 and 0.30")
T.near(A.cd_fcom(0.86 + A.C_KC * 0.1, 0.35), A.cd_fcom(0.86, 0.45), 1e-12, "CL 0.10 less: the same 0.1 C_KC later")
T.equal(A.cd_fcom(0.86, 0.9), A.cd_fcom(0.86, A.C_CL_MAX), "above C_CL_MAX its lift's")
T.check(A.cd_fcom(0.25, A.C_CL_MAX) < 1e-12, "M.25 at C_CL_MAX (high lift): none")
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
-- correction, times M^2, at 200 to 400 t and FL290 to FL430, M.80 to .88,
-- on the front of the drag curve (CL to 0.50)
local dip = nil
for t = 200, 400, 20 do
    for ft = 29000, 43000, 2000 do
        local last
        for m = 0.800, 0.8801, 0.001 do
            local c = cl_of(t, m, ft)
            if c <= 0.50 then
                local d = m * m * net_cd(t, ft, m)
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
T.near(A.fuse_cd(0.085, 0, 0.86, 306000, q86), 0.034, 0.001, "about 0.034 (v5: 0.040)")
T.near(A.fuse_cd(0.085, 1, 0.86, 306000, q86) - A.fuse_cd(0.085, 0, 0.86, 306000, q86), A.CD_GEAR / A.CD_PER_FUSE_CD, 1e-12, "the gear's on top, the same")
T.near(A.fuse_cd(0.085, 0, 0.80, 306000, q_of(0.80, 35000)), 0.085, 0.004, "M.80 at FL350 (CL 0.52): about the acf's own (+CD 0.0002)")
T.near(A.fuse_cd(0.085, 0, 0.80, 237000, q_of(0.80, 39000)), 0.085, 0.004, "M.80 at FL390: about the acf's own (no altitude's part)")
T.near(A.fuse_cd(0.085, 0, 0.60, 306000, q_of(0.60, 20000)), 0.085, 1e-6, "M.60: the acf's own")
T.equal(A.fuse_cd(0.085, 0, nil, nil, nil), 0.085, "no Mach (the correction off): the acf's own")
T.equal(A.fuse_cd(0.01, 0, 0.90, 400000, q_of(0.90, 31000)), 0, "never below 0")

T.done()
