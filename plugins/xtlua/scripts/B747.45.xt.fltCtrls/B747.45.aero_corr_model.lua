-- Drag the custom acf cannot give X-Plane, added through a drag figure X-Plane
-- reads every step (補正: CLAUDE.md allows system-side corrections for
-- aerodynamics the acf cannot reproduce; notes/AERO.md §3.16). The 3D and
-- the displays keep the actual values; only X-Plane's drag changes.
--
--   local A = B747_aero_corr_model       -- in XTLua, after dofile
--   local A = dofile(".../B747.45.aero_corr_model.lua")   -- in the tests

local M = setmetatable({}, {})
B747_aero_corr_model = M

-- The gear: FCOM PI.16.3 (p.303, the gear down long range cruise, 270 t,
-- 10,000 ft, M.45: EPR 1.14, 3,630 kg/h an engine) against the custom acf
-- with the gear down and up at the same lift (aero_gear_down, 2026-11-02):
-- X-Plane's gear adds CD 0.0219 (the wing's 541.2 m2), the FCOM's EPR (the
-- EPR model, calibrated there) 0.0260 and its fuel flow 0.0265, so 0.0044
-- more (X-Plane's gear 17 % short). The acf has no gear drag figure: X-Plane
-- takes it from the gear's size, a visual item. The same at every flap
-- setting (estimate: the approach tables, PI.10.39-10.40, are within their
-- own spread with the gear down)
M.CD_GEAR = 0.0044

-- It goes on the fuselage's drag coefficient (sim/aircraft/bodies/
-- acf_fuse_cd), which X-Plane keeps from step to step: 1 there is CD 0.0664
-- (measured in flight, 248 kt, 10,150 ft, 2026-11-02; a body's drag goes
-- with the dynamic pressure, so the same at any low Mach). X-Plane's plugin
-- forces (faxil_plug_acf) worked at about half the force written (XTLua
-- writes once a frame; X-Plane clears them each physics step) and would
-- change with the frame rate. The drag acts at the fuselage, near the
-- centre of gravity: the gear's moment below it is left out (about 0.002 of
-- the pitching moment coefficient: estimate)
M.CD_PER_FUSE_CD = 0.0664

-- (2026-11-07) The cruise above about M.83 (notes/AERO.md §3.17): the drag
-- over CD0 0.0171 and 0.055 CL^2 (on the 541.2 m2 area these figures use),
-- X-Plane's and the FCOM's, and the difference taken off.
--
-- X-Plane's: its thrust in level cruise at the perf kit's 30 points
-- (PERF_SIMBRIEF phase 1, 2026-11-06: 236 to 354 t, FL310 to FL390, M.85 to
-- .87, ISA, still air) rises XP_SLOPE a Mach from an onset the gross weight
-- moves: at one weight the same at every altitude, CL 0.28 to 0.49 (XP_M0,
-- in proportion between its weights and on the end slopes beyond them).
-- The three weights were also three centres of gravity (40 t of payload
-- and 15, 84 and 132 t of fuel: 33, 29.5 and 26 % MAC): perhaps the trim's
-- drag (estimate).
--
-- The FCOM's (v4, 2026-11-07, notes/AERO.md §3.19): a drag rise growing
-- exponentially with the Mach from a wall the lift moves earlier (Korn's
-- CL term), C_A exp((M - C_M0 + C_KC (CL - 0.45)) / C_S), fitted along the
-- line of each FCOM PI.11.2 cell (p.268, the PW4056's long range cruise)
-- with its LRC from M.85 (32 cells, FL270-FL450; same weight and level,
-- M from LRC - 0.015 to + 0.012) to:
--   * the cell's fuel flow at its LRC Mach, the thrust from it at X-Plane's
--     SFC for that thrust (the perf kit's: 0.516 lb/lbf/h to 40 kN an
--     engine, 0.00035 more a kN above) and the FL370+ SFC correction
--     (B747.42.sfc_corr_model.lua): all 32 within 1 % (rms 0.5 %);
--   * the fuel a mile around it from the FCTM: the LRC gives 1 % less fuel
--     mileage than the best, on the fast side (p.129, 4.7), and 0.01 M
--     above the scheduled speed takes 2 % more trip fuel (p.132, 4.10;
--     there the LRC about M.86 near the optimum altitude). Both at once make a parabola
--     around the best 0.0137 M under the LRC: at LRC - 0.01 M -0.93 %, at
--     + 0.01 M +2.0 %. The fit: -1.0 and +1.9 % on the mean (+0.5 to +3.5 %:
--     flatter at CL 0.41, steeper at 0.53). X-Plane's fuel per thrust holds
--     along such a line (the perf kit's records: +-0.3 % from M.85 to .87).
-- C_KC 0.25 (0.20-0.30 fit about as well: 0.20 is Korn's 0.1 / cos^3 of the
-- 37.5 deg sweep, 0.30 the least error at the LRC) puts the mean shape on
-- the FCTM's. Above C_CL_MAX (no cell beyond CL 0.53; high lift devices)
-- the lift of C_CL_MAX.
-- v3 (2026-11-07 morning, RT_K (M - 0.820) (CL/0.45)^6.5, 28 cells' fuel
-- flow at the LRC alone) fitted the LRC's fuel flows within 0.0001 rms but
-- along a fixed weight and level the CL power goes as M^-13 and cancelled
-- its own rise: 0.01 M above the LRC -0.2 to +0.8 % of fuel a mile, the
-- best inside M.85-.87 at heavy, high levels (the perf session's phase 1,
-- 2026-11-07; the user's "先に直す"). Before it a form without the lift
-- (0.057 a Mach from M.8368) left 340 t at FL350 7 % short.
--
-- The difference is taken off (more drag where the FCOM's is more than
-- X-Plane's: heavy and high near X-Plane's onset), the same above M_TOP
-- (the FCOM's long range cruise stops at M.862; X-Plane's own rise of
-- 0.17 a Mach goes on above). Under about M.78 the FCOM's part is nothing
-- (under 1e-5). The main wing's airfoils' drag divergence Mach did nothing
-- here from 0.88 to 0.92 (only 0.60 changed the drag): the acf cannot give
-- it. Estimates: the form, C_KC, C_CL_MAX, M_TOP, the onsets between and
-- beyond the three weights; the cells with the LRC under M.85 (CL under
-- 0.41) fit their fuel flow at the LRC but have their best fuel mileage
-- faster than the FCOM's (X-Plane's polar and fuel per thrust there)
--
-- Above FL370 the FCOM's cells take more fuel at the same Mach and CL
-- (FL390 0.00049 of CD, FL430 0.00113, at M.829 too), but its EPR column
-- gives the same drag as at FL370 within 0.3 % to FL410 (+0.6 to 1.0 % at
-- FL430): the fuel per thrust is more up there, the engine's (the perf
-- session, 2026-11-07). Not taken here (it would ask 1.5 to 3 % more thrust
-- and EPR, and lower the thrust's ceiling): notes/AERO.md §3.17
M.XP_SLOPE = 0.17
M.XP_M0 = {{237, 0.8373}, {305, 0.8342}, {353, 0.8289}}
M.C_A, M.C_M0, M.C_KC, M.C_S, M.C_CL_MAX = 0.00146, 0.860, 0.25, 0.0207, 0.65
M.M_TOP = 0.870
M.AREA = 541.2

-- (v5, 2026-11-07 evening, notes/AERO.md §3.20; the user's "先に直す") The
-- light and low cruise: the FCOM PI.11.2 cells with the LRC under M.85 lie
-- on one line in the Mach and the lift (LOW_LINE: CL 0.325 at M.745 to
-- 0.43 at M.86, whatever the weight and level), and v4's best fuel mileage
-- there was 0.02-0.06 M faster than that LRC (the LRC is the fast side's
-- 99 % of the best: FCTM p.129, 4.7). A Mach rise only (the drag's or the
-- fuel per thrust's) cancels against keeping the LRC's fuel flow, so the
-- drag added here grows with how far the Mach is past that line for the
-- lift: LOW_K (a softplus of the Mach past the line + LOW_OFS, LOW_S wide),
-- at most LOW_K LOW_CAP, all of it to LOW_CL[1] and none from LOW_CL[2]
-- (v4's wall up there), none under LOW_M[1] and all of it from LOW_M[2].
-- Fitted offline: the 37 cells with the LRC from M.745 under M.85 have
-- their own LRC within +0.002 to +0.005 M of the FCOM's (v4: +0.02 to
-- +0.06), their LRC's fuel flow up to 0.4 % more; far past the line (light
-- and low at M.85-.87) 2.1-2.4 % more fuel flow, the same at each Mach.
-- The cap: FCOM PI.10.38's climb rates at 290/.84 (200 t at 35,000 ft:
-- 2,900 fpm) leave no room for more drag far past the line (that table's
-- cruise EPR asks 3-7 % more thrust light and low, but its Max Climb
-- points agree with the drag: the EPR model's low thrust side, notes/
-- AERO.md §3.8); 84 fpm less there. Estimates (推定): the line's use as a drag
-- onset, the form, LOW_K, LOW_CAP, LOW_OFS, the fades, the line under CL
-- 0.30 (extended)
M.LOW_LINE = {{0.300, 0.712}, {0.325, 0.745}, {0.348, 0.788}, {0.363, 0.808}, {0.381, 0.827},
    {0.402, 0.845}, {0.410, 0.850}, {0.420, 0.855}, {0.430, 0.860}}
M.LOW_K, M.LOW_OFS, M.LOW_S, M.LOW_CAP = 0.035, 0.002, 0.003, 0.015
M.LOW_CL = {0.40, 0.45}
M.LOW_M = {0.72, 0.76}

-- X-Plane's onset Mach at a gross weight (t)
local function xp_onset(t)
    local p = M.XP_M0
    local a, b = p[1], p[2]
    if t > p[2][1] then a, b = p[2], p[3] end
    return a[2] + (b[2] - a[2]) * (t - a[1]) / (b[1] - a[1])
end

-- the lift coefficient (541.2 m2) of a gross weight (kg) at a dynamic
-- pressure (Pa)
function M.cl(weight, q)
    if not (weight and q) or q < 1000 then return nil end
    return weight * 9.80665 / (q * M.AREA)
end

-- the FCOM's part at a Mach and a lift coefficient, on 541.2 m2 (nil:
-- none)
function M.cd_fcom(mach, cl)
    if not (mach and cl) then return 0 end
    local c = math.min(cl, M.C_CL_MAX)
    return M.C_A * math.exp((mach - M.C_M0 + M.C_KC * (c - 0.45)) / M.C_S)
end

-- (v5) the FCOM's LRC line's Mach at a lift coefficient (LOW_LINE, its
-- first part's slope under it, M.86 above it)
local function low_line(cl)
    local p = M.LOW_LINE
    if cl <= p[1][1] then return p[1][2] + (cl - p[1][1]) * (p[2][2] - p[1][2]) / (p[2][1] - p[1][1]) end
    for i = 2, #p do
        if cl <= p[i][1] then
            local a, b = p[i - 1], p[i]
            return a[2] + (b[2] - a[2]) * (cl - a[1]) / (b[1] - a[1])
        end
    end
    return p[#p][2]
end

-- (v5) the light and low cruise's drag past the FCOM's LRC line at a Mach
-- and a lift coefficient, on 541.2 m2 (nil: none)
function M.cd_low(mach, cl)
    if not (mach and cl) then return 0 end
    local w = math.max(0, math.min(1, (M.LOW_CL[2] - cl) / (M.LOW_CL[2] - M.LOW_CL[1])))
    local f = math.max(0, math.min(1, (mach - M.LOW_M[1]) / (M.LOW_M[2] - M.LOW_M[1])))
    if w <= 0 or f <= 0 then return 0 end
    local x = (math.min(mach, M.M_TOP) - low_line(cl) - M.LOW_OFS) / M.LOW_S
    local past = x > 30 and x or math.log(1 + math.exp(x))
    return M.LOW_K * math.min(M.LOW_S * past, M.LOW_CAP) * w * f
end

-- the CD taken off at a Mach, a gross weight (kg) and a lift coefficient,
-- on 541.2 m2 (nil: none); below 0 adds drag
function M.cd_mach(mach, weight, cl)
    if not (mach and weight and cl) then return 0 end
    local m = math.min(mach, M.M_TOP)
    local xp = M.XP_SLOPE * math.max(m - xp_onset(weight / 1000), 0)
    return xp - M.cd_fcom(m, cl) - M.cd_low(mach, cl)
end

-- The fuselage's drag coefficient for the acf's own one, the gear's mean
-- extension (0-1) and, from 2026-11-07, the Mach, the gross weight (kg) and
-- the dynamic pressure (Pa) (nil: no Mach term), at least 0. The same
-- 0.0664 a unit at M.86 as at M.45: in X-Plane at M.863 and 306 t, 0.060 to
-- 0.066 between the correction on and off (aero_mach_sweep, 2026-11-07; the
-- CD to 4 places)
function M.fuse_cd(acf_cd, gear, mach, weight, q)
    local cd = M.CD_GEAR * gear
    if mach and weight then cd = cd - M.cd_mach(mach, weight, M.cl(weight, q)) end
    return math.max(acf_cd + cd / M.CD_PER_FUSE_CD, 0)
end

return M
