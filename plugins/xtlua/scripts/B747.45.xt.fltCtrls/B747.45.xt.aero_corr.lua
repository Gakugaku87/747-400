-- The drag corrections (B747.45.aero_corr_model.lua, 補正) in the aircraft:
-- X-Plane's fuselage drag coefficient from the acf's own value (read on the
-- first frame after the aircraft loads, before anything is written) and the
-- gear's mean extension (its five legs), every frame.
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

local fuse_cd_acf = nil         -- the acf's fuselage drag coefficient

function B747_aero_corr()
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
