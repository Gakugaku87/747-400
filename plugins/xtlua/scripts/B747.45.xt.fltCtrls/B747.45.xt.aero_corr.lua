-- The drag corrections (B747.45.aero_corr_model.lua, 補正) in the aircraft:
-- X-Plane's fuselage drag coefficient from the acf's own value (read on the
-- first frame after the aircraft loads, before anything is written) and the
-- gear's mean extension (its five legs), every frame. (2026-11-20) The flaps'
-- pitch down through X-Plane's stabilizer (stab_flap) by the FCU's trailing
-- edge angle (the mean of its four: B747.45.xt.fcu.lua's B747DR_fcu_te_deg),
-- which the hydraulics' control mapping adds to the trim's angle.
-- laminar/B747/debug/aero_corr_off 1 leaves the correction out, for
-- comparing in X-Plane. B747.45.xt.fltCtrls.lua loads it.
dofile("B747.45.aero_corr_model.lua")
local A = B747_aero_corr_model

simDR_ac_fuse_cd                = find_dataref("sim/aircraft/bodies/acf_fuse_cd")
simDR_ac_gear                   = find_dataref("sim/flightmodel2/gear/deploy_ratio")
B747DR_ac_off                   = find_dataref("laminar/B747/debug/aero_corr_off")
-- (2026-11-07) the cruise's drag above about M.83 by the Mach, the weight
-- and the lift (the dynamic pressure, in Pa: notes/ATA-22.md §53)
simDR_ac_mach                   = find_dataref("sim/flightmodel/misc/machno")
simDR_ac_weight                 = find_dataref("sim/flightmodel/weight/m_total")
simDR_ac_q                      = find_dataref("sim/flightmodel/misc/Qstatic")
B747DR_ac_stab_corr             = find_dataref("laminar/B747/flt_ctrls/stab_corr_deg")

local fuse_cd_acf = nil         -- the acf's fuselage drag coefficient

function B747_aero_corr()
    local te = 0
    if B747DR_ac_off == 0 then
        for i = 0, 3 do te = te + B747DR_fcu_te_deg[i] end
        te = te / 4
    end
    local stab = A.stab_flap(te)
    if math.abs(B747DR_ac_stab_corr - stab) > 1e-6 then B747DR_ac_stab_corr = stab end
    if fuse_cd_acf == nil then
        if simDR_ac_fuse_cd <= 0 then return end    -- not read yet (or none)
        fuse_cd_acf = simDR_ac_fuse_cd
    end
    local gear, mach, weight, q = 0, nil, nil, nil
    if B747DR_ac_off == 0 then
        for i = 0, 4 do gear = gear + simDR_ac_gear[i] end
        gear = gear / 5
        mach, weight, q = simDR_ac_mach, simDR_ac_weight, simDR_ac_q
    end
    simDR_ac_fuse_cd = A.fuse_cd(fuse_cd_acf, gear, mach, weight, q)
end

-- (2026-11-11 review) the acf's own back as the scripts go (XTLua's
-- aircraft_unload: B747.45.xt.fltCtrls.lua). XTLua's Reload Scripts keeps
-- X-Plane's coefficient; the reloaded module took the corrected one for the
-- acf's own and corrected it again (the cruise's drag less again, the
-- gear's term added on top)
function B747_aero_corr_unload()
    if fuse_cd_acf ~= nil then simDR_ac_fuse_cd = fuse_cd_acf end
end
