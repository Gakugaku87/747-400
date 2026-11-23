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
-- (2026-11-22) the downwash's or the thrust's correction alone left out
B747DR_ac_dw_off                = find_dataref("laminar/B747/debug/aero_dw_off")
B747DR_ac_tm_off                = find_dataref("laminar/B747/debug/aero_tm_off")
-- (2026-11-24) the downwash's correction in percent of its own (0: its own)
B747DR_ac_dw_pct                = find_dataref("laminar/B747/debug/aero_dw_pct")
B747DR_ac_tm_pct                = find_dataref("laminar/B747/debug/aero_tm_pct")
-- (2026-11-07) the cruise's drag above about M.83 by the Mach, the weight
-- and the lift (the dynamic pressure, in Pa: notes/ATA-22.md §53)
simDR_ac_mach                   = find_dataref("sim/flightmodel/misc/machno")
simDR_ac_weight                 = find_dataref("sim/flightmodel/weight/m_total")
simDR_ac_q                      = find_dataref("sim/flightmodel/misc/Qstatic")
B747DR_ac_stab_corr             = find_dataref("laminar/B747/flt_ctrls/stab_corr_deg")
-- (2026-11-20, N19-AERO-02) the downwash at the tail by the body's alpha
simDR_ac_alpha                  = find_dataref("sim/flightmodel/position/alpha")
simDR_ac_ias                    = find_dataref("sim/flightmodel/position/indicated_airspeed")
-- (2026-11-20, N19-AERO-01) the thrust's pitching moment: each engine's
-- thrust, the dynamic pressure from the air's density and the true
-- airspeed, the ground (X-Plane's onground_any, bound in
-- B747.45.xt.fltCtrls.lua) blended over about 2 s on X-Plane's clock
simDR_ac_thrust                 = find_dataref("sim/flightmodel/engine/POINT_thrust")
-- (2026-11-24) X-Plane's own engines' pitching moment about its centre of
-- gravity (N m, nose up plus), taken off the 747-100's
simDR_ac_mprop                  = find_dataref("sim/flightmodel/forces/M_prop")
simDR_ac_rho                    = find_dataref("sim/weather/rho")
simDR_ac_tas                    = find_dataref("sim/flightmodel/position/true_airspeed")
simDR_ac_time                   = find_dataref("sim/time/total_running_time_sec")
local AC_ETA_RATE = 0.5         -- of the air-ground blend a second
local ac_eta, ac_last = nil, nil
local ac_thrust = {0, 0, 0, 0}

function B747_aero_corr()
    local te = 0
    local dw, tm = 0, 0
    -- the air-ground blend for the thrust's arms
    local now = simDR_ac_time
    local dt = ac_last and math.max(0, math.min(0.2, now - ac_last)) or 0
    ac_last = now
    local gnd = simDR_all_wheels_on_ground == 1 and 1 or 0
    if ac_eta == nil then ac_eta = gnd end
    ac_eta = ac_eta + math.max(-AC_ETA_RATE * dt, math.min(AC_ETA_RATE * dt, gnd - ac_eta))
    if B747DR_ac_off == 0 then
        for i = 0, 3 do te = te + B747DR_fcu_te_deg[i] end
        te = te / 4
        if B747DR_ac_dw_off ~= 1 then dw = A.stab_downwash(simDR_ac_alpha, simDR_ac_ias, simDR_ac_mach) end
        if B747DR_ac_dw_pct > 0 then dw = dw * B747DR_ac_dw_pct / 100 end
        for i = 1, 4 do ac_thrust[i] = simDR_ac_thrust[i - 1] end
        local q = 0.5 * simDR_ac_rho * simDR_ac_tas * simDR_ac_tas
        if B747DR_ac_tm_off ~= 1 then tm = A.stab_thrust(A.thrust_moment(ac_thrust, ac_eta, simDR_ac_mprop), q, simDR_ac_ias) end
        if B747DR_ac_tm_pct > 0 then tm = tm * B747DR_ac_tm_pct / 100 end
    end
    local stab = A.stab_flap(te) + dw + tm
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
