-- Yaw dampers (upper and lower rudder): the yaw damper model
-- (B747.19.yd_model.lua) in the aircraft. B747.19.xt.hydraulicsmodel.lua
-- loads it; flight_controls_override() calls yaw_damper_system(doCompute)
-- every frame. 6-3 step 6a: the modules' modes, engagement and INOP: the
-- switches, their power, the IRUs, the ADCs, the air/ground, the failures
-- in; INOP out (laminar/B747/flt_ctrls/yaw_damper_upr_on, lwr_on: 1
-- engaged; before, the flight controls module wrote them) and the modes.
-- Step 6b: their command from the sensors (X-Plane's values for the IRUs'
-- and ADCs') to each rudder (laminar/B747/flt_ctrls/yaw_damper_upr, lwr:
-- the ratio of 4 degrees, which the hydraulics module adds to the pedals'
-- rudder after the ratio changers: ATA27 p.656). Before, a law of its own
-- (the heading's 0.9 s average below 5 degrees of bank, the sideslip
-- through a PID above, gains by the MCP altitude) scaled by the ratio
-- changers.
dofile("B747.19.yd_model.lua")
local YD = B747_yd_model
B747DR_yd_bus_stby              = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_yd_bus_bat               = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_yd_bus_ac                = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_yd_bus_dc                = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_yd_iru_att               = find_dataref("laminar/B747/irs/att_valid")
B747DR_yd_iru_nav               = find_dataref("laminar/B747/irs/nav_valid")
B747DR_yd_adc_valid             = find_dataref("laminar/B747/airdata/valid")
B747DR_yd_pseu_air              = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_yd_fail                  = find_dataref("laminar/B747/flt_ctrls/fail/yaw_damper")
B747DR_yd_mode                  = find_dataref("laminar/B747/flt_ctrls/yaw_damper_mode")
-- the command's sensors (step 6b)
simDR_yd_cas                    = find_dataref("sim/flightmodel/position/indicated_airspeed")
simDR_yd_tas                    = find_dataref("sim/flightmodel/position/true_airspeed")
simDR_yd_gs                     = find_dataref("sim/flightmodel/position/groundspeed")
simDR_yd_alpha                  = find_dataref("sim/flightmodel/position/alpha")
simDR_yd_pitch                  = find_dataref("sim/flightmodel/position/theta")
simDR_yd_roll                   = find_dataref("sim/flightmodel/position/phi")
simDR_yd_p                      = find_dataref("sim/flightmodel/position/P")
simDR_yd_r                      = find_dataref("sim/flightmodel/position/R")
simDR_yd_ny                     = find_dataref("sim/flightmodel/forces/g_side")
local yd_state = YD.new()
local yd_inputs = YD.inputs()
local function yd_read(inp)
    inp.switch[1] = B747DR_button_switch_position[82] > 0.95
    inp.switch[2] = B747DR_button_switch_position[83] > 0.95
    -- the upper's FCE power supplies: the AC standby bus and the battery
    -- bus; the lower's: AC 1, and DC 1 or 2 (ATA22 p.60-62: "DC bus 1 and
    -- bus 2", either: an estimate)
    inp.power[1] = B747DR_yd_bus_stby > 0.5 and B747DR_yd_bus_bat > 0.5
    inp.power[2] = B747DR_yd_bus_ac[0] > 0.5 and (B747DR_yd_bus_dc[0] > 0.5 or B747DR_yd_bus_dc[1] > 0.5)
    inp.air = B747DR_yd_pseu_air > 0.5
    local iru, nav = 0, 0
    for i = 0, 2 do
        if B747DR_yd_iru_att[i] > 0.5 then iru = iru + 1 end
        if B747DR_yd_iru_nav[i] > 0.5 then nav = nav + 1 end
    end
    inp.iru, inp.iru_nav = iru, nav
    -- the two ADCs, L and R (ATA27 p.42)
    inp.adc = (B747DR_yd_adc_valid[0] > 0.5 and 1 or 0) + (B747DR_yd_adc_valid[2] > 0.5 and 1 or 0)
    inp.fault[1] = B747DR_yd_fail[0] > 0.5
    inp.fault[2] = B747DR_yd_fail[1] > 0.5
    inp.cas, inp.tas, inp.gs = simDR_yd_cas, simDR_yd_tas, simDR_yd_gs
    inp.alpha, inp.pitch, inp.roll = simDR_yd_alpha, simDR_yd_pitch, simDR_yd_roll
    inp.p, inp.r, inp.ny = simDR_yd_p, simDR_yd_r, simDR_yd_ny
end

function yaw_damper_system(doCompute)
    yd_read(yd_inputs)
    local yd = YD.update(yd_state, yd_inputs, SIM_PERIOD)
    for i = 1, 2 do
        local v = yd.inop[i] and 0 or 1
        if i == 1 and B747DR_yaw_damper_upr_on ~= v then B747DR_yaw_damper_upr_on = v end
        if i == 2 and B747DR_yaw_damper_lwr_on ~= v then B747DR_yaw_damper_lwr_on = v end
        if B747DR_yd_mode[i - 1] ~= yd.mode[i] then B747DR_yd_mode[i - 1] = yd.mode[i] end
    end
    -- each actuator needs its hydraulic system through the tail shutoff
    -- valve (upper 3, lower 2: FCOM p.949). Without it it stops and no INOP
    -- shows (the modules inhibit the faults a lack of hydraulic power
    -- causes: ATA27 p.40). 4-1 step 4. Disengaged, its springs center it
    -- (ATA22 p.90). The ratio of the 4 degrees, at most 2 a 0.3 s (the
    -- actuator's speed: an estimate)
    local upr, lwr = 0, 0
    if yd.engaged[1] and B747_fcsov_yaw_damper_hyd(3) then upr = yd.cmd[1] / YD.AUTH_FULL end
    if yd.engaged[2] and B747_fcsov_yaw_damper_hyd(2) then lwr = yd.cmd[2] / YD.AUTH_FULL end
    B747DR_yaw_damper_upr = B747_interpolate_value(B747DR_yaw_damper_upr, upr, -1, 1, 0.3)
    B747DR_yaw_damper_lwr = B747_interpolate_value(B747DR_yaw_damper_lwr, lwr, -1, 1, 0.3)
end
