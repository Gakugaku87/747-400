-- Drag the custom acf cannot give X-Plane, added through a drag figure X-Plane
-- reads every step (補正: CLAUDE.md allows system-side corrections for
-- aerodynamics the acf cannot reproduce; notes/AERO.md §3.16). The 3D and
-- the displays keep the actual values; only X-Plane's drag changes. Since
-- 2026-11-20 also the flaps' pitch down, through the stabilizer's angle
-- (stab_flap: notes/AERO.md §3.23).
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
--
-- (v6, 2026-11-08) The same again at high thrust, whatever the altitude:
-- the cells' EPR column, through the EPR model (B747.42.epr_model.lua,
-- whose high side the FCOM pins without any fuel figure: PI.10.38's climb
-- rates against its cruise EPR at .84 and PI.13.4's one-engine-inoperative
-- LRC on three engines, both within 2 %), gives 0 to 5.5 % less thrust
-- than the fuel flow does at the perf
-- kit's fuel per thrust: 0.00082 a kN of corrected thrust from 200 kN an
-- engine up (31 cells with the LRC from M.85, rms 0.6 %; the same against
-- the lift, nothing against the altitude). v4 and v5 had put that fuel
-- into this drag. It is now the engine's (B747.42.sfc_corr_model.lua's
-- thrust factor) and C_A is refitted on v4's targets (the same 32 cells
-- and the FCTM's shape along each cell's line) with that factor in the
-- fuel flow: 0.00146 to 0.00105, C_KC, C_S and cd_low as they were (C_KC
-- free comes to 0.245; C_S free to 0.0254 with C_KC 0.284, a little
-- closer to the FCTM's +2.0 % over the LRC, not taken: the Mach shape
-- X-Plane confirmed for v4 stays). The fit: the LRC's fuel flow rms
-- 0.49 %, at worst -1.3 % (400 t FL270); the fuel a mile 0.01 M under the
-- LRC -0.84 %, over it +2.53 % on the mean (the FCTM's -0.93 and +2.0; v4
-- +1.9: the fuel per thrust now rises with the thrust along the line).
-- The FCOM's part at M.86: CL 0.44 0.0009 (v5 0.0013), 0.52 0.0024
-- (0.0034), 0.546 0.0033 (0.0047). Estimates (推定): as v4's, and that the
-- cells' excess is the fuel per thrust's and not the drag's above CL 0.53
-- (the ceilings, PI.11.1, need 2.4 to 4 % less thrust than the cells'
-- EPR and the Max Climb EPR give through the model: an inconsistency of
-- the FCOM's own, left where it is; offline the ceilings at ISA+10 come
-- out 475 ft above the FCOM's at 240 t, 328 ft at 280 t, within 170 ft
-- from 300 t: v5 +69 to -533 ft)
--
-- (v7, 2026-11-08 night) The perf kit's cruise with v6 (runs/20261108_114312)
-- burned 1.6-1.7 % less than the FCOM's LRC at 306 t FL330, 353 t FL310 and
-- 238 t FL390 (CL 0.41-0.43) and -0.2 to -0.4 % at CL 0.45-0.49. Set
-- against the FCOM EPR's thrust the two light-lift cells were short of
-- drag (-1.2 and -2.4 %), 353 t FL310 short of fuel per thrust (-1.45 %).
-- Two things the offline fits of v4-v6 had wrong about X-Plane itself, from
-- the five cruise runs (158 points, the same acf): its fuel per thrust in
-- the cruise is not the perf kit's law in thrust (0.516 + 0.00035 a kN
-- over 40) but a curve in N1 with its least near N1 84.6 % (0.5175 lb/lbf/h,
-- +0.000376 (N1 - 84)^2 - 0.00043 (N1 - 84) + 0.089 (M - 0.86); rms 0.3 %
-- against the law's 1.0 %): the law overstated it by 0.4-0.8 % at the
-- heavy cells below FL370 (N1 85-88) and understated it by 1.6-1.9 % light
-- and low (N1 79-80); and its own drag at 237 t FL390 sits 0.0002-0.0003
-- under the polar + XP_SLOPE line (every run; elsewhere within the runs'
-- 0.0002 scatter: left, 推定 that it is noise). With the measured curve the
-- FCOM's fuel asks about 0.6 % more thrust at the CL 0.41-0.43 cells than
-- the law said, and the cells' EPR agrees (B747.42.sfc_corr_model.lua's
-- thrust factor is refitted on the same curve and carries most of it). So
-- C_S 0.0207 -> 0.0230: the exponential wall a little wider, the FCOM's
-- part at CL 0.41-0.43 and M.853-.860 up by 0.00005-0.0001 (+0.2..+0.4 % of
-- drag), at CL 0.48 unchanged, above it a little less (CL 0.53 at M.86:
-- 0.00276 -> 0.00251, -0.7 % of drag, the thrust-limited ceilings of
-- PI.11.1 at ISA+10 about 120-170 ft higher offline, 240 t +475 -> +595 ft
-- over the FCOM's, 400 t -8 -> +163; 0.0260 would have fitted the cells
-- better but put them 250 ft higher still, and the perf run already has
-- them 650-1,090 ft over the FCOM's); C_A, C_KC, C_M0 and cd_low as they
-- were. Along a weight's
-- line the Mach shape gets a little gentler: the fuel a mile 0.01 M under
-- the LRC -0.85 %, over it +2.19 % on the mean (v6 -1.05 and +2.57 with the
-- measured curve; the FCTM's -0.93 and +2.0; the perf run's shape above the
-- LRC was 0.14 % steeper than the FCTM's parabola on the mean, rms 0.37 %).
-- Offline with the measured N1 curve as X-Plane's fuel per thrust (the
-- figures of v7 here and in the two tests): the 32 cells' fuel flow rms
-- 0.97 -> 0.70 % (the CL 0.41-0.43 cells -1.0 -> 0.0 % on the mean, CL
-- 0.475+ +0.5 -> +0.1 %), the EPR rms 0.011 -> 0.009 (max +0.027 ->
-- -0.020); at the six measured cells the expected fuel flow -0.7, +0.6,
-- -0.2, -0.5, +0.2 and -0.5 % (238 t FL390 carries its X-Plane drag
-- shortfall). On the old perf kit's law instead (v4-v6's fitting tool,
-- once, for the record) the same 32 cells read rms 0.49 -> 0.61 %: that
-- tool's X-Plane burns 0.4-0.8 % too much per thrust at the heavy cells
-- below FL370, so it has v6 closer and v7 farther than the airplane does. Estimates
-- (推定): C_S free with the other three held; the N1 curve outside M.85-.87
-- and N1 79-89
M.XP_SLOPE = 0.17
M.XP_M0 = {{237, 0.8373}, {305, 0.8342}, {353, 0.8289}}
M.C_A, M.C_M0, M.C_KC, M.C_S, M.C_CL_MAX = 0.00105, 0.860, 0.25, 0.0230, 0.65
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

-- (2026-11-20, N19-FCTL-01) The flaps' pitch down X-Plane leaves out (補正):
-- the stabilizer X-Plane flies is moved leading edge up by these degrees
-- with the flaps out. With the stabilizer at 1 degree a unit (0 units 3
-- degrees leading edge up, 15 units 12 down: ATA22 p.132) and the custom
-- acf's stabilizer incidence set for the cruise (+3.7 degrees: 4.36 units
-- at FL370, M.85 and 237 t; the 747-100's 3.9 to 4.6 at FL350, M.85, 227 t:
-- NASA_SIM p.340), X-Plane balanced the takeoff and the approach several
-- units nose down of the sources: its flaps pitch the airplane down less
-- than the real ones (notes/AERO.md §3.23). The acf's flap pitching moment
-- (_flap1_cm, _flap2_cm) goes with X-Plane's flap angle (15.1 degrees at
-- flaps 20, 30 at 30: the hydraulics' B747_xp_flap) and could not give both
-- (at -1.2 flaps 20 came right and 30 4.3 units too far nose up, and the
-- approach's attitude 1.4 degrees above the FCOM-fitted one: 2026-11-20); it
-- stays the acf's -0.39. Moving the stabilizer instead keeps X-Plane's tail
-- load, so the attitudes fitted to the FCOM (§3.10, §3.12) stay. By the
-- trailing edge flaps' angle (the FCU's, degrees; flaps 1 has the trailing
-- edge up: none), straight between the points:
--   * 10 and 20: the takeoff with max takeoff thrust at 280 t, 13.4 and 26.5
--     % MAC (aero_takeoff_trim_280_13/_29 and their _f10, B747_rotate.lua's
--     2.5 degrees a second at the FPPM's VR): X-Plane's balance in the
--     climb after (V2 + 23 to 29 kt, 1,000 to 1,400 ft) against the FPPM's
--     takeoff trim (p.44: by the weight and the centre of gravity only,
--     every flap setting: p.22; so the 747-100's AFM, NASA_SIM p.442), the
--     two centres of gravity's mean: with 4 degrees flaps 20 came +0.4 and
--     +1.3 units, flaps 10 +2.5 and +3.5;
--   * 30: the approach, gear down, 150 kt, 245 t, 20.6 %: 7.03 units with 4
--     degrees, the 747-100's 7.3 (256 t, 150 kt, 21 %: NASA_SIM p.342; the
--     -100's: a starting point);
--   * 5: straight from none to flaps 10's (estimate).
-- (2026-11-20 afternoon) Fitted again with the downwash's (stab_downwash)
-- and the thrust's (stab_thrust) corrections below, which move the
-- balance nose up where the alpha is over 2 degrees and the thrust high:
-- flaps 10 1.0 -> 5.2, 20 3.2 -> 6.2 (280 t: the two centres of gravity's
-- mean +0.1 units; 220 t +0.8 to +1.2, 340 t -1.7 to +0.4: notes/AERO.md
-- §3.24), 30 4.0 -> 6.05 (7.13 units on the approach; the cruise's 4.36 ->
-- 4.00 units). The stabilizer's units (the SRM, its indicator, the EICAS,
-- the greenband) and the 3D keep the trim's own values
M.STAB_FLAP = {{0, 0}, {10, 5.2}, {20, 6.2}, {30, 6.05}}

-- the degrees (leading edge up) at a trailing edge flap angle
function M.stab_flap(te)
    local t = M.STAB_FLAP
    if not te or te <= t[1][1] then return t[1][2] end
    for i = 2, #t do
        if te <= t[i][1] then
            return t[i - 1][2] + (te - t[i - 1][1]) / (t[i][1] - t[i - 1][1]) * (t[i][2] - t[i - 1][2])
        end
    end
    return t[#t][2]
end

-- (2026-11-20, GAP N19-AERO-02; notes/AERO.md §3.24, 補正) The wing's
-- downwash at the horizontal tail, which X-Plane's tail hardly sees: fitted
-- from A/P-off column steps and doublets (tests/flight/measure/
-- aero_pitch_fl350 and _20k, tests/flight/tools/pitch_fit.lua), X-Plane's
-- static stability came 1.8 to 2.4 times the 747-100's at the same centre
-- of gravity (Cm_alpha -2.46 /rad at FL350 M.84 against about -1.35;
-- -2.32 at 20,000 ft M.63 against -1.04: NASA_HQ p.218 (c.g. 0.25 MAC,
-- Iy 33.1e6 slug ft2), p.236 table IX-4; -100 values), with the lift slope
-- (5.0 /rad), the pitch inertia (46.4e6 kg m2 against 44.9e6) and the
-- elevator about right: the elevator per g came about twice the -100's and
-- the short period about 1.4 times as fast. Lowering the acf's tail 10 ft
-- toward the wing's plane changed neither (2026-11-20). As the downwash
-- does, the tail's incidence goes down as the wing's angle of attack rises:
-- DW_K degrees of stabilizer (leading edge down) a degree of the body's
-- alpha over DW_ALPHA0 (the cruise's, so the cruise's trim stays), DW_K the
-- missing stability over the stabilizer's moment per degree (Cm_delta_s
-- about 2.6 /rad: 2.5 degrees of elevator a unit, §3.23). Under DW_V0 kt
-- none (alpha means nothing at rest), full from DW_V1; within DW_MAX
M.DW_K = 0.50
M.DW_ALPHA0 = 2.0
M.DW_V0, M.DW_V1 = 40, 60
M.DW_MAX = 5
-- (2026-11-20, GAP N19-AERO-03; notes/AERO.md §3.26) Near the ground none
-- of its own: measured level with the A/P at 142 kt, flaps 30, gear down,
-- 256 t, 112 to 19 ft of gear height, X-Plane's own ground effect moved the
-- balance +1.54 units (the stabilizer +1.05 and the elevator), about the
-- 747-100's revised chart's +1.4 (NASA_SIM p.620 (19.0-9) with p.614's
-- K_GE^B, September 1970; p.337's +1.97 is from the chart before). The
-- downwash's correction taken away by (1 - K_GE^B) for a few hours that
-- day took it to +2.30 and grew with the alpha far faster than the revised
-- chart: the rotation's column 0.69 -> 0.96 at liftoff

-- the degrees (leading edge up, as stab_flap) for the body's alpha
-- (degrees) at an indicated airspeed (kt)
function M.stab_downwash(alpha, kt)
    if not alpha or not kt or kt <= M.DW_V0 then return 0 end
    local fade = math.min(1, (kt - M.DW_V0) / (M.DW_V1 - M.DW_V0))
    local d = -M.DW_K * (alpha - M.DW_ALPHA0)
    return math.max(-M.DW_MAX, math.min(M.DW_MAX, d)) * fade
end

-- (2026-11-20, GAP N19-AERO-01; notes/AERO.md §3.25, 補正) The thrust's
-- pitching moment X-Plane leaves out. The 747-100's effective engine moment
-- arms (NASA_SIM p.22 (1.1-3), p.38 (1.3-3): M_T = (T1 + T4) Z_EO + (T2 +
-- T3) Z_EI, nose up; the thrust line 2.5 degrees up; -100 values) are, in
-- the air, 14.6 ft inboard and 5.4 ft outboard, on the ground 9.2 and 7.3
-- ft; the custom acf's engines sit 5.2 and 1.0 ft under its centre of
-- gravity (_engn/n/_part_y -11.2 and -7.0 ft, acf/_cgY -6.0). The rest of
-- each arm (metres, engines 1 to 4) times each engine's forward thrust is
-- a nose-up moment, made through X-Plane's stabilizer as the flaps' and
-- the downwash's: degrees of stabilizer (leading edge down) = the moment
-- over the stabilizer's moment a degree, TM_CMDS / 57.3 per degree times
-- the dynamic pressure, TM_S and TM_C (Cm_delta_s about 2.6 /rad on the
-- -100's 511 m2 and 8.32 m: 2.5 degrees of elevator a unit, §3.23, and the
-- elevator's Cm from the fits of §3.24). The acf cannot carry it: the
-- inboard engines lowered 9.4 ft sit at the ground. Between the air's and
-- the ground's arms by eta (0 in the air, 1 on the ground; the -100 goes by
-- the main gear's compression); faded in from TM_V0 to TM_V1 kt (the
-- stabilizer cannot make a moment at rest), within TM_MAX
M.TM_ARM_AIR = {(5.4 - 1.0) * 0.3048, (14.6 - 5.2) * 0.3048, (14.6 - 5.2) * 0.3048, (5.4 - 1.0) * 0.3048}
M.TM_ARM_GND = {(7.3 - 1.0) * 0.3048, (9.2 - 5.2) * 0.3048, (9.2 - 5.2) * 0.3048, (7.3 - 1.0) * 0.3048}
M.TM_CMDS = 2.6
M.TM_S, M.TM_C = 511, 8.32
M.TM_V0, M.TM_V1 = 40, 60
M.TM_MAX = 5

-- the missing nose-up moment (N m) for the four engines' thrust (N, X-Plane's
-- POINT_thrust: forward plus; reverse counts none) at eta (0 air .. 1 ground)
function M.thrust_moment(thrust, eta)
    if not thrust then return 0 end
    eta = math.max(0, math.min(1, eta or 0))
    local m = 0
    for i = 1, 4 do
        local t = thrust[i] or 0
        if t > 0 then m = m + t * (M.TM_ARM_AIR[i] * (1 - eta) + M.TM_ARM_GND[i] * eta) end
    end
    return m
end

-- the degrees (leading edge up, as stab_flap) giving a nose-up moment (N m)
-- at a dynamic pressure (Pa) and an indicated airspeed (kt)
function M.stab_thrust(moment, q, kt)
    if not moment or not q or not kt or kt <= M.TM_V0 or q <= 100 then return 0 end
    local fade = math.min(1, (kt - M.TM_V0) / (M.TM_V1 - M.TM_V0))
    local d = moment / (M.TM_CMDS / 57.2958 * q * M.TM_S * M.TM_C)
    return -math.max(-M.TM_MAX, math.min(M.TM_MAX, d)) * fade
end

return M
