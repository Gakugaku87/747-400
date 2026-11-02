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

-- the fuselage's drag coefficient for the acf's own one and the gear's mean
-- extension (0-1)
function M.fuse_cd(acf_cd, gear)
    return acf_cd + M.CD_GEAR / M.CD_PER_FUSE_CD * gear
end

return M
