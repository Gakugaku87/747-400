-- Yaw dampers (upper and lower rudder): the yaw and sideslip inputs and the damper law.
-- Moved unchanged out of B747.19.xt.hydraulics_override.lua (docs/overhaul/PLAN.md R-1).
-- B747.19.xt.hydraulicsmodel.lua loads it after pid.lua; flight_controls_override()
-- calls yaw_damper_system(doCompute) every frame.
-- 6-3 step 6a: the yaw damper modules' modes, engagement and INOP from the
-- model (B747.19.yd_model.lua): the switches, their power, the IRUs, the
-- ADCs, the air/ground, the failures in; INOP out (laminar/B747/flt_ctrls/
-- yaw_damper_upr_on, lwr_on: 1 engaged; before, the flight controls module
-- wrote them) and the mode; the law's command faded in and out by it.
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
end
local director_yawRecord={}
local director_currentyawRecord=1
local director_lastyawRecordUpdate=0
for i=1,30,1 do
    director_yawRecord[i]=0
end
local directoryawSampleRate=0.03
function ap_director_yaw()
    if math.abs(simDR_AHARS_roll_heading_deg_pilot)>5 then 
        return -simDR_sideslip
    else
        return simDR_AHARS_heading_deg_pilot
    end
end
function dampSlip()
    --[[local retval=0
    for i=1,30,1 do
        local tVal=director_yawRecord[i]
        retval=retval+tVal
       --if displayUpdate then print("i "..i.." = " ..pitchRecord[i].. " " ..retval) end
    end
    retval=retval/30]]
    return ap_director_yaw()--retval
end
function dampYaw()
    --local displayUpdate=false
    
    
    local retval=director_yawRecord[1]
    local left=0
    if retval>270 then left=1 end
    for i=2,30,1 do
        local tVal=director_yawRecord[i]
        if left==1 and tVal<90 then tVal=tVal+360 end
        if left==0 and tVal>270 then tVal=tVal-360 end
        retval=retval+tVal
       --if displayUpdate then print("i "..i.." = " ..pitchRecord[i].. " " ..retval) end
    end
    retval=retval/30
    if retval<0 then retval=retval+360 end

    retval=getHeadingDifference(retval,simDR_AHARS_heading_deg_pilot)
    --if displayUpdate then print("ap_director_yaw_integral "..retval.." simDR_AHARS_heading_deg_pilot "..simDR_AHARS_heading_deg_pilot) end
    return retval
end
function clearYawIntegral()
    local val=0
    if math.abs(simDR_AHARS_roll_heading_deg_pilot)<5 then 
        val=simDR_AHARS_heading_deg_pilot
    end
    for i=1,30,1 do
        director_yawRecord[i]=val
    end
end
local lastDamperSystem=0 --0 == slip, 1==yaw
local current_yaw_intregal=0
function ap_director_yaw_integral()
    if (simDRTime-director_lastyawRecordUpdate)>directoryawSampleRate then
         director_lastyawRecordUpdate=simDRTime
         director_yawRecord[director_currentyawRecord]=ap_director_yaw()
         director_currentyawRecord=director_currentyawRecord+1

         if director_currentyawRecord>30 then
             director_currentyawRecord=1
         end
        if math.abs(simDR_AHARS_roll_heading_deg_pilot)>5 then 
            if lastDamperSystem~=0 then clearYawIntegral() end
            lastDamperSystem=0
            current_yaw_intregal= dampSlip()
        else
            if lastDamperSystem~=1 then clearYawIntegral() end
            lastDamperSystem=1
            current_yaw_intregal= dampYaw()
        end
     end
    
    return current_yaw_intregal
end
local yawPid = newPid()
yawPid.minout=-1
yawPid.maxout=1
yawPid.target=0
yawPid.input = 0
yawPid:compute()

function get_damper_value(currentValue)
    local target=yawPid.output
    
    local speed=0.4
    
    --[[if math.abs(simDR_AHARS_roll_heading_deg_pilot)<5 and math.abs(yawPid.input)<0.35 then
        speed=2
        target=0
    end]]
    local mult=1
    if math.abs(simDR_AHARS_roll_heading_deg_pilot)<5 then
        mult=B747_rescale(0,0,0.35,1,yawPid.input)
    end
    
    if mult==0 or target==nil then
        return 0
    end
    --print("mult "..mult)
    --print("target "..target)
    target=target*mult
    return target --B747_interpolate_value(currentValue,target,-1,1,speed)
end

function yaw_damper_system(doCompute)
    if math.abs(simDR_AHARS_roll_heading_deg_pilot)<5 then
        B747DR_pidyawP = B747_rescale(3000, B747DR_pidyawProllL,30000, B747DR_pidyawProllH,B747DR_autopilot_altitude_ft_pfd)
        B747DR_pidyawI = 0.000003
        B747DR_pidyawD = B747_rescale(3000,B747DR_pidyawDrollL,30000,B747DR_pidyawDrollH,B747DR_autopilot_altitude_ft_pfd)
    else
        B747DR_pidyawP = B747_rescale(3000, B747DR_pidyawPslipL,30000, B747DR_pidyawPslipH,B747DR_autopilot_altitude_ft_pfd)
        B747DR_pidyawI = 0.000003
        B747DR_pidyawD = B747_rescale(3000,B747DR_pidyawDslipL,30000,B747DR_pidyawDslipH,B747DR_autopilot_altitude_ft_pfd)
    end

    yawPid.kp=B747DR_pidyawP
    yawPid.ki=B747DR_pidyawI
    yawPid.kd=B747DR_pidyawD
    yawPid.input = ap_director_yaw_integral()
    if doCompute==1 then
        yawPid:compute()
    end
    --print(B747DR_yaw_damper_lwr.." "..get_damper_value())
    -- the modules' modes (6-3 step 6a): INOP, and the command faded in the
    -- air, none in the ground operation
    yd_read(yd_inputs)
    local yd = YD.update(yd_state, yd_inputs, SIM_PERIOD)
    for i = 1, 2 do
        local v = yd.inop[i] and 0 or 1
        if i == 1 and B747DR_yaw_damper_upr_on ~= v then B747DR_yaw_damper_upr_on = v end
        if i == 2 and B747DR_yaw_damper_lwr_on ~= v then B747DR_yaw_damper_lwr_on = v end
        if B747DR_yd_mode[i - 1] ~= yd.mode[i] then B747DR_yd_mode[i - 1] = yd.mode[i] end
    end
    -- the dampers' actuators need their hydraulic system through the tail
    -- shutoff valve (upper 3, lower 2: FCOM p.949). Without it they stop and
    -- no INOP shows (the modules inhibit the faults a lack of hydraulic power
    -- causes: ATA27 p.40). 4-1 step 4
    if yd.engaged[1] and B747_fcsov_yaw_damper_hyd(3) then
        B747DR_yaw_damper_upr=B747_interpolate_value(B747DR_yaw_damper_upr,get_damper_value(B747DR_yaw_damper_upr)*yd.fade[1],-1,1,0.3)
    else
        B747DR_yaw_damper_upr=B747_interpolate_value(B747DR_yaw_damper_upr,0,-1,1,0.3)
    end

    if yd.engaged[2] and B747_fcsov_yaw_damper_hyd(2) then
        B747DR_yaw_damper_lwr=B747_interpolate_value(B747DR_yaw_damper_lwr,get_damper_value(B747DR_yaw_damper_lwr)*yd.fade[2],-1,1,0.3)
    else
        B747DR_yaw_damper_lwr=B747_interpolate_value(B747DR_yaw_damper_lwr,0,-1,1,0.3)
    end
end
