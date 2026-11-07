-- The engines' fuel per thrust above FL370, which the custom acf cannot give
-- X-Plane (補正: the user, 2026-11-07, "プラグインで直す"; notes/AERO.md
-- §3.18). X-Plane burns the thrust times the acf's jet SFC, four figures by
-- Mach and N1 and none by altitude (§3.9): the light airplane high up runs
-- a lower N1 than the heavy one lower down, so the acf cannot take more fuel
-- high up only. Only the fuel flow changes: the thrust, the EPR and N1 stay
-- X-Plane's.
--
--   local S = B747_sfc_corr_model       -- in XTLua, after dofile
--   local S = dofile(".../B747.42.sfc_corr_model.lua")   -- in the tests

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

return M
