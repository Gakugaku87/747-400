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
--   * the fuel a mile around it from FCTM p.129 (4.10): the LRC gives 1 %
--     less fuel mileage than the best, on the fast side, and 0.01 M above
--     the scheduled speed takes 2 % more fuel. Both at once make a parabola
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

-- the CD taken off at a Mach, a gross weight (kg) and a lift coefficient,
-- on 541.2 m2 (nil: none); below 0 adds drag
function M.cd_mach(mach, weight, cl)
    if not (mach and weight and cl) then return 0 end
    local m = math.min(mach, M.M_TOP)
    local xp = M.XP_SLOPE * math.max(m - xp_onset(weight / 1000), 0)
    return xp - M.cd_fcom(m, cl)
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
