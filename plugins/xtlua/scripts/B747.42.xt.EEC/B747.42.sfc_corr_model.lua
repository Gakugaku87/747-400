-- The engines' fuel per thrust above FL370 and, from 2026-11-08, at high
-- thrust in the cruise, which the custom acf cannot give X-Plane (補正: the
-- user, 2026-11-07, "プラグインで直す"; notes/AERO.md §3.18). X-Plane burns
-- the thrust times the acf's jet SFC, four figures by Mach and N1 and none
-- by altitude (§3.9): the light airplane high up runs a lower N1 than the
-- heavy one lower down, so the acf cannot take more fuel high up only. Only
-- the fuel flow changes: the thrust, the EPR and N1 stay X-Plane's.
--
--   local S = B747_sfc_corr_model       -- in XTLua, after dofile
--   local S = dofile(".../B747.42.sfc_corr_model.lua")   -- in the tests
--   S.total(ft, fd_kn, mach)            -- the factor on the acf's SFC

local M = setmetatable({}, {})
B747_sfc_corr_model = M

-- FCOM PI.11.2 (p.268, the PW4056's long range cruise, fuel flow an
-- engine) above FL370 against X-Plane's fuel flow at the drag its cells give
-- (the polar and the FCOM's part over it, B747.45.aero_corr_model.lua's
-- cd_fcom, fitted on FL270 to FL370) and the fuel per thrust X-Plane gives
-- that thrust (the perf kit's points): more by 1.8 % at FL390 (five cells,
-- 1.4 to 2.2 %), 2.9 % at FL410 (four, 2.5 to 3.6 %), 3.6 % at FL430
-- (three, 3.2 to 4.0 %), 3.7 % at FL450 (one); FL350 -0.1 %, FL370 +0.4 %
-- (the fit's own). The FCOM's EPR column gives the same drag at FL390 and
-- FL410 as at FL370 (the perf session): the engine's, not the drag's (the
-- lower Reynolds number in the engine: estimate). The factor on the acf's
-- SFC: none to FL370, in proportion between the table's altitudes, FL430's
-- above. Estimates: by the pressure altitude alone (the cells' spread, about
-- ±0.5 %, goes with the thrust), the same at every thrust and Mach, above
-- FL430
M.ALT = {{37000, 0}, {39000, 0.018}, {41000, 0.029}, {43000, 0.036}}

-- the factor on the acf's SFC at a pressure altitude (ft); nil: 1
function M.factor(ft)
    local p = M.ALT
    if not ft or ft <= p[1][1] then return 1 end
    for i = 2, #p do
        if ft <= p[i][1] then
            return 1 + p[i - 1][2] + (p[i][2] - p[i - 1][2]) * (ft - p[i - 1][1]) / (p[i][1] - p[i - 1][1])
        end
    end
    return 1 + p[#p][2]
end

-- (2026-11-08) More fuel per thrust at high thrust in the cruise. The FCOM
-- fixes an engine's EPR to its thrust without any fuel figure in two
-- places, and both agree with the EPR model (B747.42.epr_model.lua)
-- within 2 %: the climb rates at the Max Climb EPR and the cruise EPR at
-- .84 on one page (PI.10.38 p.264: from the cruise EPR to the climb EPR
-- the thrust rises 14-46 %, the model 15-45 %), and the one-engine-
-- inoperative LRC on three engines (PI.13.4 p.286: ten cells within
-- ±0.014 through the drag, 4 % added for the windmilling and the trim:
-- estimate). (The thrust-limited ceilings, PI.11.1 p.267, ask 2.4 to 4 %
-- less thrust at the Max Climb EPR than the LRC cells' EPR give: the
-- FCOM's own inconsistency, left: B747.45.aero_corr_model.lua's v6.) The LRC
-- cells (PI.11.2 p.268) read 0.03 to 0.09 more EPR than their fuel flow
-- gives through the perf kit's fuel per thrust (0.516 lb/lbf/h to 40 kN
-- an engine, 0.00035 more a kN above) and the altitude's factor: that
-- fuel flow turned into thrust is more than the EPR's by 0.00082 a kN of
-- corrected thrust F/delta (an engine's net thrust over the pressure
-- ratio) from 200 kN up (31 cells with the LRC from M.85, rms 0.6 %;
-- the same against the lift coefficient, 0.556 a unit from CL 0.44;
-- nothing against the altitude once its factor is in). The engine's fuel
-- per thrust rises with the thrust, then, and the drag correction of
-- v5 (notes/AERO.md §3.19-3.20) had put that fuel into drag: the FCOM's
-- part of the drag is refitted with this factor in (v6). The one-engine-
-- inoperative cells (3 engines, F/delta 226-263 kN at M.78-.84) burn 4 to
-- 9 % more than the perf kit's fuel per thrust at their drag (the
-- windmilling and trim drag 4-7 %: estimate), the same direction and size.
-- The factor: 1 + THRUST.k (F/delta - THRUST.f0), F/delta at least
-- THRUST.f0 and at most THRUST.f0 + THRUST.cap, faded in with the Mach from
-- THRUST_MACH[1] to [2] so the takeoff (M.25: the ICAO 0.343 lb/lbf/h,
-- notes/AERO.md §3.8) and the climb at 290 KIAS below 30,000 ft keep the
-- acf's own. Estimates (推定): the line's slope and start (the cells reach
-- F/delta 260), the cap (the cells' end plus the climb's 270: nothing
-- above), the fade with the Mach (the takeoff's fuel is right without it,
-- the cruise's needs it; between them no figure), that it is the same at
-- every altitude (its product with ALT's factor), that the 3-engine
-- cells' excess is the same effect
M.THRUST = {f0 = 200, k = 0.00082, cap = 80}   -- kN of F/delta
M.THRUST_MACH = {0.70, 0.80}

-- the factor for an engine's corrected thrust F/delta (kN: its net thrust
-- over the ambient pressure's ratio to 101,325 Pa) at a Mach; nil: 1
function M.thrust_factor(fd_kn, mach)
    if not (fd_kn and mach) then return 1 end
    local t = M.THRUST
    local f = fd_kn - t.f0
    if f <= 0 then return 1 end
    if f > t.cap then f = t.cap end
    local w = (mach - M.THRUST_MACH[1]) / (M.THRUST_MACH[2] - M.THRUST_MACH[1])
    if w <= 0 then return 1 end
    if w > 1 then w = 1 end
    return 1 + t.k * f * w
end

-- the factor on the acf's SFC: the altitude's times the thrust's
function M.total(ft, fd_kn, mach)
    return M.factor(ft) * M.thrust_factor(fd_kn, mach)
end

return M
