-- mSparks 2022/01/07

--sim/operation/override/override_wheel_steer
--
--sim/operation/override/override_control_surfaces
--sim/multiplayer/controls/yoke_pitch_ratio	float[20]	y	[-1..1]	The deflection of the axis controlling pitch.
--sim/multiplayer/controls/yoke_roll_ratio	float[20]	y	[-1..1]	The deflection of the axis controlling roll.
--sim/multiplayer/controls/yoke_heading_ratio	float[20]	y	[-1..1]	The deflection of the axis controlling yaw.
--sim/operation/override/override_joystick_roll
--sim/operation/override/override_joystick_pitch
--sim/operation/override/override_joystick_heading
--sim/flightmodel2/wing/aileron2_deg[]
--sim/flightmodel2/wing/aileron1_deg[]
--sim/flightmodel2/wing/flap1_deg[]
--sim/flightmodel2/wing/flap2_deg[]
--sim/flightmodel2/controls/slat2_deploy_ratio
--sim/flightmodel2/controls/slat1_deploy_ratio
dofile("pid.lua")
local B747_afds_controls = dofile("B747.19.xt.hydraulics_afds_helpers.lua")

-- Set true only while collecting AFDS tuning data.  Output is rate limited below.
local AFDS_CONTROL_DIAGNOSTICS_ENABLED = false
local AFDS_CONTROL_DIAGNOSTIC_INTERVAL_SEC = 1.0
local B747_afds_last_control_diagnostic_time = -AFDS_CONTROL_DIAGNOSTIC_INTERVAL_SEC
local B747DR_afds_armed_roll_mode = find_dataref("laminar/B747/autopilot/FMA/armed_roll_mode")
local B747DR_afds_armed_pitch_mode = find_dataref("laminar/B747/autopilot/FMA/armed_pitch_mode")
local B747_afds_pitch_target_before_blend = 0
local B747_afds_pitch_target_after_blend = 0

B747DR_ap_AFDS_mode_box_status_pilot = find_dataref("laminar/B747/autopilot/AFDS/mode_box_status_pilot")
B747DR_ap_AFDS_mode_box_status_copilot =find_dataref("laminar/B747/autopilot/AFDS/mode_box_status_copilot")
lastBraking=0
lastPitch=0
lastRoll=0
lastYaw=0
lastFlaps=0
numSurfaces=26
lastControlValue={}
for i=0,numSurfaces,1 do
    lastControlValue[i]=0
end

-- 1 rudder lower 2,4
-- 2 rudder upper 1,2
-- 3 l elev inner
-- 4 r elev inner
-- 5 l elev outer
-- 6 r elev outer
-- 7 l ail inner sim/flightmodel/controls/wing2l_ail1def[0]
-- 8 r ail inner sim/flightmodel/controls/wing4r_ail1def[0]
-- 9 l ail outer sim/flightmodel/controls/wing4l_ail2def[0]
-- 10 r ail outer sim/flightmodel/controls/wing2r_ail2def[0]
brakeConsumption=0
local B747_pressureDRs={}
local controlRatios={}
controlRatios[0]=0
B747_pressureDRs[0]=0
local computeRate=0.0333 -- handle low FPS
local lastCompute=0
local doCompute=0
function pressure_input()
    B747_pressureDRs[1]=B747DR_hyd_sys_pressure_1
    B747_pressureDRs[2]=B747DR_hyd_sys_pressure_2
    B747_pressureDRs[3]=B747DR_hyd_sys_pressure_3
    B747_pressureDRs[4]=B747DR_hyd_sys_pressure_4
    
    controlRatios[1]=B747_controls_lower_rudder--simDR_rudder[10]
    controlRatios[2]=B747_controls_upper_rudder--simDR_rudder[10]

    controlRatios[3]=B747_controls_left_inner_elevator-- -simDR_elevator[0]
    controlRatios[4]=B747_controls_right_inner_elevator-- -simDR_elevator[0]
    controlRatios[5]=B747_controls_left_outer_elevator-- -simDR_elevator[0]
    controlRatios[6]=B747_controls_right_outer_elevator-- -simDR_elevator[0]

    controlRatios[7]=B747_controls_left_inner_aileron--simDR_left_aileron_inner
    controlRatios[8]=B747_controls_right_inner_aileron--simDR_right_aileron_inner
    controlRatios[9]=B747_controls_left_outer_aileron--simDR_left_aileron_outer
    controlRatios[10]=B747_controls_right_outer_aileron--simDR_right_aileron_outer

    --left wing
    controlRatios[11]=B747DR_spoiler1
    controlRatios[12]=B747DR_spoiler2
    controlRatios[13]=B747DR_spoiler3
    controlRatios[14]=B747DR_spoiler4
    controlRatios[15]=B747DR_spoiler5--simDR_spoiler5
    controlRatios[16]=B747DR_speedbrake3--simDR_spoiler67[0]

    --right wing
    controlRatios[17]=B747DR_speedbrake3--simDR_spoiler67[1]
    controlRatios[18]=B747DR_spoiler8--simDR_spoiler8
    controlRatios[19]=B747DR_spoiler9--simDR_spoiler910
    controlRatios[20]=B747DR_spoiler10--simDR_spoiler910
    controlRatios[21]=B747DR_spoiler11--simDR_spoiler1112
    controlRatios[22]=B747DR_spoiler12--simDR_spoiler1112

    --flaps left outer to right outer
    controlRatios[23]=B747DR_flap1--simDR_flap1
    controlRatios[24]=B747DR_flap2--simDR_flap2
    controlRatios[25]=B747DR_flap3--simDR_flap3
    controlRatios[26]=B747DR_flap4--simDR_flap4
    
end

function pressure_output()
    if B747DR_hyd_sys_restotal_1>0.1 then
        B747DR_hyd_sys_pressure_1=B747_pressureDRs[1]
    else
        B747DR_hyd_sys_pressure_1=0
    end
    if B747DR_hyd_sys_restotal_2>0.1 then
        B747DR_hyd_sys_pressure_2=B747_pressureDRs[2]
    else
        B747DR_hyd_sys_pressure_2=0
    end
    if B747DR_hyd_sys_restotal_3>0.1 then
        B747DR_hyd_sys_pressure_3=B747_pressureDRs[3]
    else
        B747DR_hyd_sys_pressure_3=0
    end
    if B747DR_hyd_sys_restotal_4>0.1 then
        B747DR_hyd_sys_pressure_4=B747_pressureDRs[4]
    else
        B747DR_hyd_sys_pressure_4=0
    end

    B747DR_rudder_lwr_pos=B747_animate_value(B747DR_rudder_lwr_pos,controlRatios[1],-100,100,20)
    B747DR_rudder_upr_pos=B747_animate_value(B747DR_rudder_upr_pos,controlRatios[2],-100,100,20)
    --B747_interpolate_value
    --[[B747DR_l_elev_inner   = B747_animate_value(B747DR_l_elev_inner,controlRatios[3],-100,100,20)
    B747DR_r_elev_inner   = B747_animate_value(B747DR_r_elev_inner,controlRatios[4],-100,100,20)
    B747DR_l_elev_outer   = B747_animate_value(B747DR_l_elev_outer,controlRatios[5],-100,100,20)
    B747DR_r_elev_outer   = B747_animate_value(B747DR_r_elev_outer,controlRatios[6],-100,100,20)]]--
    B747DR_l_elev_inner   = B747_interpolate_value(B747DR_l_elev_inner,controlRatios[3],-22,17,0.75)
    B747DR_r_elev_inner   = B747_interpolate_value(B747DR_r_elev_inner,controlRatios[4],-22,17,0.75)
    B747DR_l_elev_outer   = B747_interpolate_value(B747DR_l_elev_outer,controlRatios[5],-22,17,0.75)
    B747DR_r_elev_outer   = B747_interpolate_value(B747DR_r_elev_outer,controlRatios[6],-22,17,0.75)

    --[[B747DR_l_aileron_inner   = B747_animate_value(B747DR_l_aileron_inner,controlRatios[7],-100,100,10)
    B747DR_r_aileron_inner   = B747_animate_value(B747DR_r_aileron_inner,controlRatios[8],-100,100,10)
    B747DR_l_aileron_outer   = B747_animate_value(B747DR_l_aileron_outer,controlRatios[9],-100,100,10)
    B747DR_r_aileron_outer   = B747_animate_value(B747DR_r_aileron_outer,controlRatios[10],-100,100,10)]]
    B747DR_l_aileron_inner   = B747_interpolate_value(B747DR_l_aileron_inner,controlRatios[7],-20,20,0.75)
    B747DR_r_aileron_inner   = B747_interpolate_value(B747DR_r_aileron_inner,controlRatios[8],-20,20,0.75)
    B747DR_l_aileron_outer   = B747_interpolate_value(B747DR_l_aileron_outer,controlRatios[9],-25,15,0.75)
    B747DR_r_aileron_outer   = B747_interpolate_value(B747DR_r_aileron_outer,controlRatios[10],-25,15,0.75)


    --spoilers
    for i=1,12,1 do
        B747DR_spoilers[i]=B747_animate_value(B747DR_spoilers[i],controlRatios[i+10],-100,100,10)
    end
    simDR_spoiler12=(B747DR_spoilers[1]+B747DR_spoilers[2])/2
    simDR_spoiler34=(B747DR_spoilers[3]+B747DR_spoilers[4])/2
    simDR_spoiler5=(B747DR_spoilers[5])

    simDR_spoiler8=(B747DR_spoilers[8])
    simDR_spoiler910=(B747DR_spoilers[9]+B747DR_spoilers[10])/2
    simDR_spoiler1112=(B747DR_spoilers[11]+B747DR_spoilers[12])/2
    --spoiler stat
    outleft_spoilers=0
    for i=1,5,1 do
        outleft_spoilers=outleft_spoilers+B747DR_spoilers[i]
    end
    outright_spoilers=0
    for i=8,12,1 do
        outright_spoilers=outright_spoilers+B747DR_spoilers[i]
    end
    B747DR_outer_spoilers[0]=B747_animate_value(B747DR_outer_spoilers[0],outleft_spoilers/5,-100,100,10)
    B747DR_outer_spoilers[1]=B747_animate_value(B747DR_outer_spoilers[1],outright_spoilers/5,-100,100,10)

    --flaps
    --[[B747DR_flaps[1]=B747_animate_value(B747DR_flaps[1],controlRatios[23],-100,100,0.08)
    B747DR_flaps[2]=B747_animate_value(B747DR_flaps[2],controlRatios[24],-100,100,0.08)
    B747DR_flaps[3]=B747_animate_value(B747DR_flaps[3],controlRatios[25],-100,100,0.08)
    B747DR_flaps[4]=B747_animate_value(B747DR_flaps[4],controlRatios[26],-100,100,0.08)]]

    B747DR_flaps[1]=B747_interpolate_value(B747DR_flaps[1],controlRatios[23],0,30,45)
    B747DR_flaps[2]=B747_interpolate_value(B747DR_flaps[2],controlRatios[24],0,30,45)
    B747DR_flaps[3]=B747_interpolate_value(B747DR_flaps[3],controlRatios[25],0,30,45)
    B747DR_flaps[4]=B747_interpolate_value(B747DR_flaps[4],controlRatios[26],0,30,45)
    simDR_flap1=B747DR_flaps[1]
    simDR_flap2=B747DR_flaps[2]
    simDR_flap3=B747DR_flaps[3]
    simDR_flap4=B747DR_flaps[4]
end


function hydraulics_consumer(src,consumption)
    local take_index=0
    if consumption==0  then
        consumption=0.001
    end
    --print("consume "..src[1].." "..src[2].." "..src[3].." "..src[4].." "..consumption)
    for i=1,4,1 do
        if src[i]==1 and B747_pressureDRs[i]>consumption and B747_pressureDRs[i]>B747_pressureDRs[take_index] and B747_pressureDRs[i]>900 then
            take_index=i
        end

    end
    if take_index>0 then
        B747_pressureDRs[take_index]=B747_pressureDRs[take_index]-consumption
        return consumption
    else
        return 0
    end
end

function brake_accumulator()
    if simDR_parking_brake_ratio>lastBraking then
        brakeDiff=(simDR_parking_brake_ratio-lastBraking)*400
    else
        brakeDiff=0
    end
    if brakeDiff<simDR_hyd_press_1_2 then
        simDR_hyd_press_1_2=simDR_hyd_press_1_2-brakeDiff
    else
        simDR_hyd_press_1_2=0
    end
    brakeConsumption=brakeConsumption+brakeDiff
    lastBraking=simDR_parking_brake_ratio

    brakeConsumption=brakeConsumption-hydraulics_consumer({1,1,0,1},brakeConsumption)  
end
function flap_consumption(controlDiff)
    if hydraulics_consumer({0,0,0,1},controlDiff[23]*10)==0 then
        controlRatios[23]=lastControlValue[23]
    end
    if hydraulics_consumer({1,0,0,0},controlDiff[24]*10)==0 then
        controlRatios[24]=lastControlValue[24]
    end
    if hydraulics_consumer({1,0,0,0},controlDiff[25]*10)==0 then
        controlRatios[25]=lastControlValue[25]
    end
    if hydraulics_consumer({0,0,0,1},controlDiff[26]*10)==0 then
        controlRatios[26]=lastControlValue[26]
    end
end
function spoiler_consumption(controlDiff)
    --system 2, spoilers 2,3,10,11
    if hydraulics_consumer({0,1,0,0},controlDiff[12]/3)==0 then
        controlRatios[12]=B747_animate_value(lastControlValue[12],0,-100,100,1)
    end
    if hydraulics_consumer({0,1,0,0},controlDiff[13]/3)==0 then
        controlRatios[13]=B747_animate_value(lastControlValue[13],0,-100,100,1)
    end
    if hydraulics_consumer({0,1,0,0},controlDiff[20]/3)==0 then
        controlRatios[20]=B747_animate_value(lastControlValue[20],0,-100,100,1)
    end
    if hydraulics_consumer({0,1,0,0},controlDiff[21]/3)==0 then
        controlRatios[21]=B747_animate_value(lastControlValue[21],0,-100,100,1)
    end
    --system 3, spoilers 1,4,9,12
    if hydraulics_consumer({0,0,1,0},controlDiff[11]/3)==0 then
        controlRatios[11]=B747_animate_value(lastControlValue[11],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,1,0},controlDiff[14]/3)==0 then
        controlRatios[14]=B747_animate_value(lastControlValue[14],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,1,0},controlDiff[19]/3)==0 then
        controlRatios[19]=B747_animate_value(lastControlValue[19],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,1,0},controlDiff[22]/3)==0 then
        controlRatios[22]=B747_animate_value(lastControlValue[22],0,-100,100,1)
    end

    --system 4, spoilers 5,6,7,8
    if hydraulics_consumer({0,0,0,1},controlDiff[15]/3)==0 then
        controlRatios[15]=B747_animate_value(lastControlValue[15],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,0,1},controlDiff[16]/3)==0 then
        controlRatios[16]=B747_animate_value(lastControlValue[16],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,0,1},controlDiff[17]/3)==0 then
        controlRatios[17]=B747_animate_value(lastControlValue[17],0,-100,100,1)
    end
    if hydraulics_consumer({0,0,0,1},controlDiff[1]/3)==0 then
        controlRatios[18]=B747_animate_value(lastControlValue[18],0,-100,100,1)
    end
end

function flight_controls_consumption()
    controlDiff={}
    for i=1,numSurfaces,1 do
        --print(i.." getting")
        --print(controlRatios[i])
        --print(lastControlValue[i])
        if controlRatios[i]>lastControlValue[i] then
            controlDiff[i]=(controlRatios[i]-lastControlValue[i])
        else
            controlDiff[i]=(lastControlValue[i]-controlRatios[i])
        end
        
    end

    -- steering 
    hydraulics_consumer({1,0,0,0},controlDiff[1]*5)
    --rudder lower 
    if hydraulics_consumer({0,1,0,1},controlDiff[1]*3)==0 then
        controlRatios[1]=B747_animate_value(lastControlValue[1],0,-100,100,10)
    end

    --[[if hydraulics_consumer({0,1,0,1},controlDiff[1]*3)==0 then
        controlRatios[1]=B747_animate_value(lastControlValue[1],0,-100,100,1)
    end]]
    -- rudder upper 
    if hydraulics_consumer({1,1,0,0},controlDiff[2]*3)==0 then
        controlRatios[2]=B747_animate_value(lastControlValue[2],0,-100,100,10)
    end
    
    --1,2 L inboard elev
    if hydraulics_consumer({1,1,0,0},controlDiff[3]*3)==0 then
        controlRatios[3]=B747_animate_value(lastControlValue[3],0,-100,100,20)
    end
    --3,4 R inboard elev
    if hydraulics_consumer({0,0,1,1},controlDiff[4]*3)==0 then
        controlRatios[4]=B747_animate_value(lastControlValue[4],0,-100,100,20)
    end
    --1 L outboard elev
    if hydraulics_consumer({1,0,0,0},controlDiff[5]*3)==0 then
        controlRatios[5]=B747_animate_value(lastControlValue[5],0,-100,100,20)
    end
    --4 R outboard elev
    if hydraulics_consumer({0,0,0,1},controlDiff[6]*3)==0 then
        controlRatios[6]=B747_animate_value(lastControlValue[6],0,-100,100,20)
    end


    --1,2 L inboard aileron
    if hydraulics_consumer({1,1,0,0},controlDiff[7]*3)==0 then
        controlRatios[7]=B747_animate_value(lastControlValue[7],0,-100,100,1)
    end
    --2,4 R inboard aileron
    if hydraulics_consumer({0,1,0,1},controlDiff[8]*3)==0 then
        controlRatios[8]=B747_animate_value(lastControlValue[8],0,-100,100,1)
    end
    --1,2 L outboard aileron
    if hydraulics_consumer({1,1,0,0},controlDiff[9]*3)==0 then
        controlRatios[9]=B747_animate_value(lastControlValue[9],0,-100,100,1)
    end
    --2,3,4 R outboard aileron
    if hydraulics_consumer({0,1,1,1},controlDiff[10]*3)==0 then
        controlRatios[10]=B747_animate_value(lastControlValue[10],0,-100,100,1)
    end

    spoiler_consumption(controlDiff)
    flap_consumption(controlDiff)
    for i=1,numSurfaces,1 do
        lastControlValue[i]=controlRatios[i]
    end
end

function normal_slats()
    if simDR_flap_ratio > 0.166 then
        simDR_innerslats_ratio  	= B747_interpolate_value(simDR_innerslats_ratio,1,0,1,8.5)
    elseif simDR_flap2+simDR_flap3 <2 then
        simDR_innerslats_ratio  	= B747_interpolate_value(simDR_innerslats_ratio,0,0,1,8.5)
    end
    if simDR_flap_ratio > 0.332 then
        simDR_outerslats_ratio  	= B747_interpolate_value(simDR_outerslats_ratio,1,0,1,8.5)
    elseif  simDR_flap2+simDR_flap3 <8 then
        simDR_outerslats_ratio  	= B747_interpolate_value(simDR_outerslats_ratio,0,0,1,8.5)
    end
end
local slatsRetract=false
function B747_slats()
    
    if simDR_flap_ratio==0 and simDR_innerslats_ratio==0 and simDR_outerslats_ratio==0 then
         return;
    elseif (B747DR_speedbrake_lever >0.5 and (simDR_prop_mode[0] == 3 or simDR_prop_mode[1] == 3 or simDR_prop_mode[2] == 3 or simDR_prop_mode[3] == 3)) 
        or (slatsRetract==true and B747DR_speedbrake_lever >0.5) then	
      simDR_innerslats_ratio = B747_interpolate_value(simDR_innerslats_ratio, 0.0, 0.0, 1.0, 8.5)
      slatsRetract=true
    else 
      slatsRetract=false
      normal_slats()
    end
   
 end
 local lastTrimmed=0
 local lastUp=0
 local lastDown=0
local pitchRecord={}
local currentPitchRecord=1
local lastPitchRecordUpdate=0
for i=1,10,1 do
    pitchRecord[i]=0
end


local director_pitchRecord={}
local director_currentPitchRecord=1
local director_lastPitchRecordUpdate=0
for i=1,10,1 do
    director_pitchRecord[i]=0
end
local last_simDR_ind_airspeed_kts_pilot=0
local last_simDR_AHARS_pitch_heading_deg_pilot=0
local last_altitude=0
--speed target at the previous FLCH/VNAV SPD update, whether the aircraft is
--still accelerating to a raised target (update_speed_target_acceleration) and
--the speed that acceleration started from
local last_speedPitchTarget=nil
local speedPitchAccelerating=false
local speedPitchAcceleratedFrom=nil
local directorSampleRate=0.02
local lastAPTargetRoll=0
local capturedLocTime=0
local hasLoc=false
function ap_director_roll()
   if simDR_autopilot_nav_status ==2 and hasLoc==false then
        capturedLocTime=simDRTime
        hasLoc=true
        print("autoland capturedLocTime")
    elseif simDR_autopilot_nav_status ~=2 then
        hasLoc=false
    end
    if math.abs(B747DR_ap_ATT)>=5 then
        return B747DR_ap_ATT
    elseif (simDR_autopilot_nav_status ~=2 and B747DR_autopilot_nav_status==2) or 5>(simDRTime-capturedLocTime) then
        print("autoland estimating roll capturedLocTime "..capturedLocTime.. " simDRTime "..simDRTime .. " simDR_autopilot_nav_status "..simDR_autopilot_nav_status)
        return lastAPTargetRoll
    else
        lastAPTargetRoll=B747DR_ap_target_roll
        return B747DR_ap_target_roll
   end
end
local lastPitchMode=0
local lastPitchModeChange=0
local lastRetVal=0
local pitchTransitionFrom=0
local pitchTransitionActive=false
local PITCH_TRANSITION_SAMPLE_INTERVAL_SEC=0.05

local function B747_pitch_transition_is_protected(pitchMode)
    return B747DR_ap_autoland==1 or pitchMode==1 or pitchMode==2 or pitchMode==3
end

function B747_pitch_transition_active()
    return pitchTransitionActive
end

function B747_reset_pitch_transition()
    pitchTransitionActive=false
    lastPitchMode=0
    lastPitchModeChange=simDRTime
    lastRetVal=simDR_AHARS_pitch_heading_deg_pilot
    pitchTransitionFrom=lastRetVal
    B747_afds_pitch_target_before_blend=lastRetVal
    B747_afds_pitch_target_after_blend=lastRetVal
end

function ap_director_pitch_retVal(pitchMode,retVal)
    B747_afds_pitch_target_before_blend=retVal
    if pitchMode==nil or pitchMode<=0 then
        pitchTransitionActive=false
        lastPitchMode=0
        lastRetVal=retVal
        B747_afds_pitch_target_after_blend=retVal
        return retVal
    end

    if pitchMode~=lastPitchMode then
        lastPitchModeChange=simDRTime
        if B747_pitch_transition_is_protected(pitchMode) then
            pitchTransitionActive=false
        else
            if lastPitchMode==0 then
                pitchTransitionFrom=simDR_AHARS_pitch_heading_deg_pilot
            else
                pitchTransitionFrom=lastRetVal
            end
            pitchTransitionActive=true
        end
        lastPitchMode=pitchMode
    end

    local result=retVal
    if pitchTransitionActive then
        local elapsed_sec=math.max(simDRTime-lastPitchModeChange,0)
        result=B747_afds_controls.pitch_transition_value(pitchTransitionFrom, retVal, elapsed_sec,
            B747_afds_controls.PITCH_TRANSITION_DURATION_SEC)
        if elapsed_sec>=B747_afds_controls.PITCH_TRANSITION_DURATION_SEC then
            pitchTransitionActive=false
        end
        if debug_flight_directors==1 then
            print("blend ap_director_pitch_retVal "..pitchTransitionFrom .." retVal "..retVal
                .." result "..result.." pitchMode "..pitchMode)
        end
    end
    if debug_flight_directors==1 then
        print("ap_director_pitch_retVal "..result.." retVal "..retVal .." pitchMode "..pitchMode)
    end
    lastRetVal=result
    B747_afds_pitch_target_after_blend=result
    return result

end
local thisTargetGlideslipeFPM=-800
local last_simDR_hsi_vdef_dots_pilot=0
local lastSimDRTime=0
local last_speed_delta=0


function getGlideSlopeFPM()
    local diff=simDRTime-lastSimDRTime
    --[[if diff<1 then
        return thisTargetGlideslipeFPM
    end]]
    local speed_fpm=simDR_groundspeed*196.85
    thisTargetGlideslipeFPM=-math.tan(math.rad(simDR_glideslope1))*speed_fpm
    local nextVdef=simDR_hsi_vdef_dots_pilot
   -- local correction=(8*nextVdef*nextVdef*nextVdef)
    -- the deviation in feet is about dots x 0.1 x the height (0.3 deg a dot on a 3 deg slope): 0.25 x the
    -- radio altitude fpm a dot takes it out in about 24 s at any height, 75 fpm a dot near the ground as
    -- before, at most 1,000 fpm; 75 everywhere left a capture 0.75 dot above (190 ft at 8 nm) there to 500 ft.
    -- [P37] Not tripled beyond 2 dots: 2.3 dots below at 447 ft on EHAM's ILS 18R (p32-line1, 2026-10-20) that
    -- asked for +76 fpm, the 747 climbed at 430 ft to 2.5 dots above and went through 200 ft at -1,250 fpm
    local correction=nextVdef*math.max(75,0.25*simDR_radarAlt1)
    correction=math.max(-1000,math.min(1000,correction))
    local resultTargetGlideslipeFPM=thisTargetGlideslipeFPM-correction --was 75 last testing
    --print("fin thisTargetGlideslipeFPM "..thisTargetGlideslipeFPM.." correction "..correction.." resultTargetGlideslipeFPM "..resultTargetGlideslipeFPM)
    if debug_flight_directors==1 then
        print("fin simDR_glideslope1 "..simDR_glideslope1.."thisTargetGlideslipeFPM "..thisTargetGlideslipeFPM.." correction "..correction.." resultTargetGlideslipeFPM "..resultTargetGlideslipeFPM)
    end
    return resultTargetGlideslipeFPM
  
end


local previous_pitchTime=0
local last_simDR_vvi_fpm_pilot=0
local last_vvi_update=0
local prev_vvi_update=0.5
local fpmBias=0
local lastFlapsFPM=0
local fpmBiasRunStart=nil   -- first call of the current run of calls (the ALT, V/S or VNAV PTH branch)
local lastFPMBiasTime=nil
-- a longer gap between calls ends a run: the ALT branch calls every 0.1 s, the
-- V/S and VNAV PTH branch every 1.0 s (plus a frame) when on target (G/S no longer calls it, P37)
local FPM_BIAS_RUN_GAP_SEC=2.5
-- The bias answers a flap handle move seen while this director runs above
-- 3,000 ft RA. The reference follows the handle whenever a move cannot be
-- one: for the first 0.5 s of a run of calls (a fresh load has no reference,
-- and FLCH, VNAV SPD and TO/GA do not call this, so the handle may have moved
-- in between) and below 3,000 ft RA. ap_pitch_assist reads the handle every
-- frame, as XTLua gives 0 for the first read of a dataref. A bias left from an earlier run is dropped. Before, the
-- reference started at 0 and moved only inside the condition below, so the
-- first ALT/VNAV PTH update above 3,000 ft with flaps out added 6000 x the
-- handle ratio (+4,000 fpm at flaps 20) and pitched the 747 down at the
-- capture (flight tests 2026-10-10).
function get_FPM_bias()
    local fpmBiasMax=6000
    if lastFPMBiasTime==nil or simDRTime-lastFPMBiasTime>FPM_BIAS_RUN_GAP_SEC or simDRTime<lastFPMBiasTime then
        fpmBiasRunStart=simDRTime
        fpmBias=0
    end
    lastFPMBiasTime=simDRTime
    if simDRTime-fpmBiasRunStart<0.5 or simDR_radarAlt1<=3000 then
        lastFlapsFPM=B747DR_flap_ratio
    end
    if B747DR_flap_ratio~=lastFlapsFPM and B747DR_flap_lever_detent==0 and simDR_radarAlt1>3000 then
        local Flaps_change=B747DR_flap_ratio-lastFlapsFPM
        print("Flaps_change "..Flaps_change)
        fpmBias=fpmBias+fpmBiasMax*Flaps_change
        lastFlapsFPM=B747DR_flap_ratio
    end
    fpmBias=B747_interpolate_value(fpmBias,0.0,-fpmBiasMax,fpmBiasMax,10)
   -- print("fpmBias "..fpmBias)
    return fpmBias
end
-- lowest pitch target of V/S, VNAV PTH, G/S and ALT: the 747 flies level at about -2 deg with flaps 20
-- at 210 kt, and the -3.5 deg it was left VNAV PTH at -300 to -850 fpm on EHAM's approach (2026-10-16)
local AFDS_MIN_PITCH_DEG=-10
-- [P37] G/S's PI law (B747_afds_controls.GS_PATH_KP, GS_PATH_KI, GS_PITCH_RATE_DAMPING): its integrator, from the
-- director's pitch when G/S began (again after a second without a G/S update), and the attitude and the elevation
-- at the last update
local glideSlopePitchBase=0
local lastGlideSlopeUpdate=-100
local lastGlideSlopePitch=0
local lastGlideSlopeElevation=0
-- [P43] FLCH SPD and VNAV SPD outside the capture window: the flight path law on the acceleration error
-- (hydraulics_afds_helpers.lua's SPEED_PITCH_* and speed_pitch_*), every 0.1 s; its pitch (the integrator) from the
-- director's pitch when the law began (in TO/GA the attitude: the F/D is parked at 8 deg on the ground; again after
-- a second without an update, or when another branch of the director ran after its last update: the first update
-- holds it), the IAS's rate and the attitude at the last update; then
-- limit_speed_pitch_target's guards (climbing: no pitch-down while the VSI shows +100 fpm or less, not below the level
-- attitude; descending, the mirror; the severe underspeed and overspeed exceptions), which move the integrator with
-- what they take. With the flight director alone (servos off) the integrator stays within 2 deg of the attitude.
-- lastDirectorUpdate: the time of the director's update before this one; targetSpeed: the speed to fly (the AFDS's,
-- simDR_autopilot_airspeed_kts, when nil; TO/GA's, P39).
local speedPitchBase=0
local lastSpeedPitchUpdate=-100
local lastSpeedPitchIAS=0
local speedPitchAccel=0
local lastSpeedPitchAttitude=0
local function ap_director_speed_on_pitch(pitchMode,holdAlt,lastDirectorUpdate,targetSpeed)
    local C=B747_afds_controls
    directorSampleRate=0.1
    local ias=simDR_ind_airspeed_kts_pilot
    local target=targetSpeed or simDR_autopilot_airspeed_kts
    local verticalDirection=C.vertical_direction_for_altitude(simDR_pressureAlt1,holdAlt,B747DR_alt_capture_window)
    -- TO/GA always climbs, whatever the MCP altitude (with it below, a non-ILS approach's minima, the descent guards
    -- pitched a go-around down to -4.5 deg and back below its altitude at 230 kt: review 45)
    if pitchMode==1 then verticalDirection=C.VERTICAL_DIRECTION_CLIMB end
    local dt=simDRTime-lastSpeedPitchUpdate
    local pathError,pitchRate=0,0
    if dt>1 or dt<=0 or lastSpeedPitchUpdate<lastDirectorUpdate-0.001 then
        speedPitchBase=last_simDR_AHARS_pitch_heading_deg_pilot
        if pitchMode==1 then speedPitchBase=simDR_AHARS_pitch_heading_deg_pilot end
        speedPitchAccel=0
        dt=0
    else
        speedPitchAccel=C.speed_pitch_accel(speedPitchAccel,ias-lastSpeedPitchIAS,dt)
        local wanted=C.speed_pitch_wanted_accel(target,ias,verticalDirection==C.VERTICAL_DIRECTION_CLIMB,
            speedPitchAccel,simDR_vvi_fpm_pilot,simDR_TAS_mps)
        local errorDeg=C.speed_pitch_path_error_deg(speedPitchAccel,wanted,simDR_TAS_mps,ias)
        local maxRate=C.speed_pitch_max_rate_deg(simDR_TAS_mps)
        speedPitchBase=speedPitchBase+math.max(-maxRate,math.min(maxRate,C.SPEED_PITCH_KI*errorDeg))*math.min(dt,0.5)
        pathError=math.max(-C.SPEED_PITCH_P_LIMIT_DEG,math.min(C.SPEED_PITCH_P_LIMIT_DEG,errorDeg))
        pitchRate=(simDR_AHARS_pitch_heading_deg_pilot-lastSpeedPitchAttitude)/dt
    end
    if simDR_autopilot_servos_on==0 then
        speedPitchBase=math.max(simDR_AHARS_pitch_heading_deg_pilot-2,
            math.min(simDR_AHARS_pitch_heading_deg_pilot+2,speedPitchBase))
    end
    local requested=speedPitchBase+C.SPEED_PITCH_KP*pathError-C.SPEED_PITCH_RATE_DAMPING*pitchRate
    --a raised speed target (or, when this mode engages, a target above the speed) is flown by accelerating without
    --descending until the speed is within 5 kt (update_speed_target_acceleration); lastPitchMode is the pitch mode
    --of the previous director update
    local minSafeSpeed=B747DR_airspeed_Vmc+10
    local maxSafeSpeed=B747DR_airspeed_Vmax
    local speedReference=last_speedPitchTarget
    local wasAccelerating=speedPitchAccelerating
    if pitchMode~=lastPitchMode or speedReference==nil then
        speedReference=ias
        wasAccelerating=false
    end
    speedPitchAccelerating=C.update_speed_target_acceleration(wasAccelerating,speedReference,target,ias,minSafeSpeed)
    if not speedPitchAccelerating then
        speedPitchAcceleratedFrom=nil
    elseif not wasAccelerating then
        speedPitchAcceleratedFrom=ias
    end
    last_speedPitchTarget=target
    --in a climb that has stopped climbing, not below the attitude that flies level at this angle of attack
    local climbPathPitch=C.climb_path_pitch_deg(simDR_alpha_deg,simDR_TAS_mps,simDR_AHARS_roll_heading_deg_pilot)
    local limited=C.limit_speed_pitch_target(requested,last_simDR_AHARS_pitch_heading_deg_pilot,verticalDirection,
        simDR_vvi_fpm_pilot,ias,target,minSafeSpeed,maxSafeSpeed,dt,
        speedPitchAccelerating and (speedPitchAcceleratedFrom or true),climbPathPitch)
    speedPitchBase=speedPitchBase+(limited-requested)
    lastSpeedPitchUpdate=simDRTime
    lastSpeedPitchIAS=ias
    lastSpeedPitchAttitude=simDR_AHARS_pitch_heading_deg_pilot
    last_simDR_AHARS_pitch_heading_deg_pilot=limited
    return ap_director_pitch_retVal(pitchMode,limited)
end
-- [P39] TO/GA's speed (B747_afds_controls.toga_target_speed)
local togaSpeedState={}
function ap_director_pitch(pitchMode)
    time=simDRTime-previous_pitchTime
    previous_pitchTime=simDRTime
    --print("ap_director_pitch" ..time.. " "..directorSampleRate)
    if time>5 then
        B747_reset_pitch_transition()
        return simDR_AHARS_pitch_heading_deg_pilot
    end
    if time==0 then
        return ap_director_pitch_retVal(pitchMode,simDR_AHARS_pitch_heading_deg_pilot)
    end
   -- print("ap_director_pitc go")
    local alt_delta=simDR_pressureAlt1-last_altitude
    last_altitude=simDR_pressureAlt1
    local holdAlt=simDR_autopilot_altitude_ft 
    local refreshHoldAlt=simDR_autopilot_hold_altitude_ft
    local refreshfd=simDR_flight_director_pitch
    --keep a just-pushed ALT HOLD while the FMA still shows the previous FLCH/V/S/VNAV SPD mode
    if simDR_autopilot_alt_hold_status==2 and B747_afds_controls.altitude_hold_release_allowed(
        pitchMode,simDR_autopilot_flch_status,simDR_autopilot_vs_status) then
        simDR_autopilot_alt_hold_status=0
    end
    if simDR_autopilot_alt_hold_status==2 then
        holdAlt=simDR_autopilot_hold_altitude_ft
    end
    if debug_flight_directors==1 then
        print("ap_director_pitch for "..pitchMode.." holdAlt "..holdAlt)
    end
    if B747DR_ap_autoland == 1 then 
        if debug_flight_directors==1 then
            print("pitching for autoland "..B744DR_autolandPitch .. " simDR_AHARS_pitch_heading_deg_pilot "..simDR_AHARS_pitch_heading_deg_pilot.. "simDR_touchGround "..simDR_touchGround)
        end
        directorSampleRate=0.02
        return ap_director_pitch_retVal(pitchMode,B744DR_autolandPitch)
    end
    --B747DR_ap_flightPhase == 3 and simDR_autopilot_vs_fpm == -500
    if (pitchMode==4 or pitchMode==8)
    and (simDR_pressureAlt1> holdAlt+B747DR_alt_capture_window or simDR_pressureAlt1< holdAlt-B747DR_alt_capture_window) then
        --FLCH SPD, VNAV SPD (P43)
        if debug_flight_directors==1 then
            print("ap_director_pitch for speed "..B747DR_ap_flightPhase)
        end
        return ap_director_speed_on_pitch(pitchMode,holdAlt,simDRTime-time)
    elseif pitchMode~=2 and 
    (pitchMode==5 or pitchMode==9 or 
    (simDR_autopilot_alt_hold_status==2) or 
    (simDR_pressureAlt1< holdAlt+B747DR_alt_capture_window and simDR_pressureAlt1> holdAlt-B747DR_alt_capture_window
    and (pitchMode~=1 or holdAlt>simDR_pressureAlt1))) then
        --ALT (TO/GA captures only an altitude above it: a go-around inside the window above an MCP left at the
        --minima levelled there, review 45b)
        if debug_flight_directors==1 then
            print("ap_director_pitch for ALT")

        end 
        if simDR_autopilot_alt_hold_status~=2 then
            --a FLCH/V/S push outside the capture window is waiting for the FMA to update: do not capture over it
            local captureAlt=B747_afds_controls.implicit_altitude_capture_target(simDR_autopilot_flch_status,
                simDR_autopilot_vs_status,simDR_pressureAlt1,simDR_autopilot_altitude_ft,B747DR_alt_capture_window)
            if captureAlt==nil then
                return ap_director_pitch_retVal(pitchMode,last_simDR_AHARS_pitch_heading_deg_pilot)
            end
            simDR_autopilot_hold_altitude_ft=captureAlt
            simDR_autopilot_alt_hold_status=2
            simDR_autopilot_vs_status=0
            simDR_autopilot_flch_status=0
            --cancel TOGA pitch
            B747DR_autopilot_TOGA_status=0 
            holdAlt=simDR_autopilot_hold_altitude_ft
        end
        local fpmBias=get_FPM_bias()
        local previousPitch=last_simDR_AHARS_pitch_heading_deg_pilot
        local altDiff=math.abs(simDR_pressureAlt1-holdAlt+fpmBias*40)
        --target alt in 30 secs, limited to 2000 fpm and slowed when the speed runs away
        local targetFPM=B747_afds_controls.altitude_hold_target_fpm(holdAlt,simDR_pressureAlt1,
            simDR_ind_airspeed_kts_pilot,simDR_autopilot_airspeed_kts,B747DR_airspeed_Vmc + 10,B747DR_airspeed_Vmax)
        --local pitchError=math.abs(simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot)
        local pitchError=simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot

        directorSampleRate=0.1
        local currentFPM=simDR_vvi_fpm_pilot+fpmBias
        local rog=0.001+0.00003*math.abs(currentFPM-targetFPM)
        --if simDR_pressureAlt1>29000 or (altDiff<B747DR_alt_capture_window) then
        if simDR_pressureAlt1>10000 or math.abs(currentFPM)<100 then
            rog=0.0001+0.00001*math.abs(currentFPM-targetFPM)
        end
        if currentFPM>targetFPM  and (pitchError<0.5 or (math.abs(fpmBias)>50 and pitchError<1.0)) then
            last_simDR_AHARS_pitch_heading_deg_pilot=last_simDR_AHARS_pitch_heading_deg_pilot-rog
            if debug_flight_directors==1 then
                print("-last_altitude "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." targetFPM "..targetFPM)
            end
        elseif currentFPM<targetFPM and pitchError>-0.5 or (math.abs(fpmBias)>50 and pitchError>-1.0) then
            if debug_flight_directors==1 then 
                print("+last_altitude "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." targetFPM "..targetFPM)
            end
            last_simDR_AHARS_pitch_heading_deg_pilot=last_simDR_AHARS_pitch_heading_deg_pilot+rog
        else
            if debug_flight_directors==1 then
                print("=last_altitude "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." targetFPM "..targetFPM.. " pitchError "..pitchError)
            end
        end
        local cap,floor=B747_afds_controls.pitch_cap_approach(15,previousPitch,time,simDR_TAS_mps)
        if last_simDR_AHARS_pitch_heading_deg_pilot<AFDS_MIN_PITCH_DEG then
            last_simDR_AHARS_pitch_heading_deg_pilot=AFDS_MIN_PITCH_DEG
        elseif last_simDR_AHARS_pitch_heading_deg_pilot>cap then
            last_simDR_AHARS_pitch_heading_deg_pilot=cap
        end
        if last_simDR_AHARS_pitch_heading_deg_pilot<floor then last_simDR_AHARS_pitch_heading_deg_pilot=floor end
        retval=last_simDR_AHARS_pitch_heading_deg_pilot
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        return ap_director_pitch_retVal(pitchMode,retval)

    elseif pitchMode==2 then --GLIDESLOPE
        -- [P37] the beam's V/S (getGlideSlopeFPM) as a flight path angle by a PI law: every 0.1 s the path angle
        -- the 747 is short of (glide_slope_path_error_deg, against the V/S from the elevation's rate since the
        -- last update, at most GS_MAX_PATH_ERROR_DEG) moves the integrator by GS_PATH_KI of it a second, and the
        -- pitch is the integrator plus GS_PATH_KP of it, less GS_PITCH_RATE_DAMPING x the attitude's rate since
        -- the last update; the first update holds the director's pitch. The pitch moved by steps for the VSI's
        -- error as V/S does, and with the pitch loop as X-Plane flies it that hunted around the beam (p32-line1:
        -- +-0.6 deg at 13-16 s) and came late slowing down on it: at idle from 167 to 139 kt below AM622 on EHAM's
        -- ILS 18R, -1,300 fpm and 2.3 dots below by 450 ft. local_vy is in X-Plane's local frame, tilted by up to
        -- 0.6 deg from the vertical away from its reference point (-17 fpm on EHAM's final, up to +-150 fpm
        -- elsewhere; review 43), the VSI and vh_ind lag the elevation by about a second.
        directorSampleRate=0.1
        local dt=simDRTime-lastGlideSlopeUpdate
        local pathError=0
        local pitchRate=0
        if dt>1 then
            glideSlopePitchBase=last_simDR_AHARS_pitch_heading_deg_pilot
        else
            local limit=B747_afds_controls.GS_MAX_PATH_ERROR_DEG
            pathError=B747_afds_controls.glide_slope_path_error_deg(getGlideSlopeFPM(),
                (simDR_elevation-lastGlideSlopeElevation)/dt,simDR_groundspeed)
            pathError=math.max(-limit,math.min(limit,pathError))
            glideSlopePitchBase=glideSlopePitchBase+B747_afds_controls.GS_PATH_KI*pathError*math.min(dt,0.5)
            pitchRate=(simDR_AHARS_pitch_heading_deg_pilot-lastGlideSlopePitch)/dt
        end
        glideSlopePitchBase=math.max(AFDS_MIN_PITCH_DEG,math.min(10,glideSlopePitchBase))
        if simDR_autopilot_servos_on==0 then
            -- the flight director alone: the integrator kept near the attitude the pilot flies
            glideSlopePitchBase=math.max(simDR_AHARS_pitch_heading_deg_pilot-2,
                math.min(simDR_AHARS_pitch_heading_deg_pilot+2,glideSlopePitchBase))
        end
        lastGlideSlopeUpdate=simDRTime
        lastGlideSlopePitch=simDR_AHARS_pitch_heading_deg_pilot
        lastGlideSlopeElevation=simDR_elevation
        retval=glideSlopePitchBase+B747_afds_controls.GS_PATH_KP*pathError
            -B747_afds_controls.GS_PITCH_RATE_DAMPING*pitchRate
        retval=math.max(AFDS_MIN_PITCH_DEG,math.min(10,retval))
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        return ap_director_pitch_retVal(pitchMode,retval)

    elseif pitchMode==4 or pitchMode==7 or pitchMode==6 then
        local pitchError=simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot
        local previousPitch=last_simDR_AHARS_pitch_heading_deg_pilot
        
        if debug_flight_directors==1 then
            print("ap_director_pitch for VS pitchError="..pitchError)
        end

        local targetFPM=simDR_autopilot_vs_fpm
        local currentFPM=simDR_vvi_fpm_pilot+get_FPM_bias()
        local minUpdateRate=2.0
        local vviDiff=simDRTime-last_vvi_update
        if vviDiff>2 and prev_vvi_update < 1 then
            prev_vvi_update=2.0 --give two seconds before reducing sample rate
            if debug_flight_directors==1 then
                print("prev_vvi_update=2.0") --recover overshoots
            end
        end
        if debug_flight_directors==1 then
            print("autopilot FPM="..currentFPM.." target="..targetFPM)
        end
        local vviError=math.abs(currentFPM-targetFPM)
        --[[if ((pitchError<0.3 and vviError<50) or simDR_autopilot_alt_hold_status==2) and pitchMode~=2 then
            directorSampleRate=0.5
        elseif pitchError<0.3 then
            directorSampleRate=minUpdateRate
        end]]--
        --if pitchError<1.3 then
        directorSampleRate=math.min(B747_rescale(0,1,500,0.2,math.abs(vviError)),minUpdateRate,prev_vvi_update)
        prev_vvi_update=directorSampleRate
        --end
       
        --local rog=0.001+0.00004*vviError/(time*30)
        local rog=0.001+0.000003*math.abs(currentFPM-targetFPM)
        local div=B747_rescale(100,30,300,0.3,simDR_ind_airspeed_kts_pilot)
        if debug_flight_directors==1 then
            print("directorSampleRate "..directorSampleRate.." div "..div)
        end
        --[[if simDR_pressureAlt1>29000 then
            rog=rog/3
        elseif vviError>400 then
                rog=rog*15
        elseif simDR_pressureAlt1<12000 then
                rog=rog*3
        end]]
        rog=rog*div
        local speed_delta=(currentFPM-last_simDR_vvi_fpm_pilot)/(time*30)
        last_simDR_vvi_fpm_pilot=currentFPM
        local min_speedDelta=0
        local max_speedDelta=0
        if  vviError > 10 then
            max_speedDelta=vviError/5
            min_speedDelta=vviError/50
        end

        --if pitchError<0.5 then
            if (currentFPM>targetFPM and speed_delta>-min_speedDelta and pitchError<0.5) --primary
            or (currentFPM<targetFPM and speed_delta<-max_speedDelta and pitchError<0.5) then
                last_simDR_AHARS_pitch_heading_deg_pilot=last_simDR_AHARS_pitch_heading_deg_pilot-rog
                last_vvi_update=simDRTime
                if debug_flight_directors==1 then
                    print("-last_simDR_AHARS_pitch_heading_deg_pilot "..last_simDR_AHARS_pitch_heading_deg_pilot)
                    print("-simDR_vvi_fpm_pilot "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." speed_delta "..speed_delta.." min_speedDelta "..min_speedDelta.." max_speedDelta "..max_speedDelta)
                end
            elseif (simDR_vvi_fpm_pilot<targetFPM and speed_delta<min_speedDelta and pitchError>-0.5) --primary
            or (currentFPM>targetFPM and speed_delta>max_speedDelta and pitchError>-0.5)  then
                if debug_flight_directors==1 then 
                    print("+last_simDR_AHARS_pitch_heading_deg_pilot "..last_simDR_AHARS_pitch_heading_deg_pilot)
                    print("+simDR_vvi_fpm_pilot "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." speed_delta "..speed_delta.." min_speedDelta "..min_speedDelta.." max_speedDelta "..max_speedDelta)
                end
                last_vvi_update=simDRTime
                last_simDR_AHARS_pitch_heading_deg_pilot=last_simDR_AHARS_pitch_heading_deg_pilot+rog
            elseif debug_flight_directors==1 then 
                print("=simDR_vvi_fpm_pilot "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_vvi_fpm_pilot "..currentFPM.." rog "..rog.." speed_delta "..speed_delta.." min_speedDelta "..min_speedDelta.." max_speedDelta "..max_speedDelta)
            end
       -- end
        local cap,floor=B747_afds_controls.pitch_cap_approach(10,previousPitch,time,simDR_TAS_mps)
        if last_simDR_AHARS_pitch_heading_deg_pilot<AFDS_MIN_PITCH_DEG then
            last_simDR_AHARS_pitch_heading_deg_pilot=AFDS_MIN_PITCH_DEG
        elseif last_simDR_AHARS_pitch_heading_deg_pilot>cap then
            last_simDR_AHARS_pitch_heading_deg_pilot=cap
        end
        if last_simDR_AHARS_pitch_heading_deg_pilot<floor then last_simDR_AHARS_pitch_heading_deg_pilot=floor end
        retval=last_simDR_AHARS_pitch_heading_deg_pilot
        local blendedRetval=ap_director_pitch_retVal(pitchMode,retval)
        --
        --if pitchMode==2 then
        --    ap_director_pitch_retVal(pitchMode,retval)--log it
        --    return retval
        --else
            return blendedRetval
        --end
    elseif pitchMode==1 then
       -- print("simDR_autopilot_TOGA_pitch_deg ="..simDR_autopilot_TOGA_pitch_deg)
        if debug_flight_directors==1 then
            print("ap_director_pitch for TOGA")
        end
        -- [P39] in the air speed on pitch to TO/GA's speed; on the ground parked at fltInst's TO/GA pitch (8 deg)
        -- the window's speed only in knots (in Mach it shows the hundredths: 84 for M .84, review 45); a go-around's
        -- target at least B747DR_airspeed_Vmc, fltInst02's minimum manoeuvring speed for the flaps (the takeoff's stays
        -- V2 + 10: with takeoff flaps that speed is above V2, and Vmc + 10 flew 310 t at V2 + 14, review 45b)
        local window=B747DR_ap_ias_dial_value
        if simDR_autopilot_airspeed_is_mach==1 then window=nil end
        local togaSpeed=B747_afds_controls.toga_target_speed(togaSpeedState,simDR_touchGround==1,
            simDR_AHARS_pitch_heading_deg_pilot,simDR_ind_airspeed_kts_pilot,B747DR_airspeed_V2,window,simDRTime)
        if togaSpeed~=nil then
            if togaSpeedState.go_around then togaSpeed=math.max(togaSpeed,B747DR_airspeed_Vmc) end
            return ap_director_speed_on_pitch(pitchMode,holdAlt,simDRTime-time,togaSpeed)
        end
        directorSampleRate=0.1
        retval=B747_interpolate_value(last_simDR_AHARS_pitch_heading_deg_pilot,simDR_autopilot_TOGA_pitch_deg,2,12,5)
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        ap_director_pitch_retVal(pitchMode,retval) --make sure pitch retval is fresh
        return retval--ap_director_pitch_retVal(pitchMode,retval)
    --elseif pitchMode==2 then
     --   directorSampleRate=0.5
    else
        --print("ap_director_pitch for off")
        --no pitch mode (NONE after an ALT selector push, FLARE without autoland):
        --hold the attitude so that the next mode starts from it, not from 0 degrees
        retval=B747_afds_controls.inactive_mode_pitch_target(simDR_AHARS_pitch_heading_deg_pilot)
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        return ap_director_pitch_retVal(pitchMode,retval)
    end
    local retval=simDR_flight_director_pitch
    if debug_flight_directors==1 then
        print("+simDR_flight_director_pitch "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_flight_director_pitch "..simDR_flight_director_pitch.." B747DR_ap_FMA_active_pitch_mode "..B747DR_ap_FMA_active_pitch_mode.." holdAlt "..holdAlt)
    end
    if retval<simDR_AHARS_pitch_heading_deg_pilot-5 then
        retval=simDR_AHARS_pitch_heading_deg_pilot-5
    elseif retval>simDR_AHARS_pitch_heading_deg_pilot+5 then 
        retval=simDR_AHARS_pitch_heading_deg_pilot+5
    end

    if pitchMode==5 or pitchMode==9 then
        directorSampleRate=1.0
        if retval<-1.5 then
            retval=-1.5
        elseif retval>10 then 
            retval=10
        end
    else
        --if B747DR_ap_FMA_active_pitch_mode==2 then
            directorSampleRate=1.0
        --else
        --    directorSampleRate=0.5
       -- end
        if retval<-10 then
            retval=-10
        elseif retval>10 then 
            retval=10
        end
    end
    last_altitude=simDR_pressureAlt1
    last_simDR_AHARS_pitch_heading_deg_pilot=retval
    return ap_director_pitch_retVal(pitchMode,retval)
end
local filteredDirectorRoll=0
local director_lastRollFilterUpdate=0
local director_rollFilterInitialized=false

local function B747_roll_approach_protected()
    return B747DR_ap_autoland==1 or B747DR_ap_FMA_active_roll_mode==3
        or simDR_autopilot_nav_status==2 or B747DR_autopilot_nav_status==2
end

function ap_director_roll_integral()
    local rawDirectorRoll=ap_director_roll()
    local rollMode=B747DR_ap_FMA_active_roll_mode
    local elapsedSec=simDRTime-director_lastRollFilterUpdate
    if not director_rollFilterInitialized or elapsedSec>1 or rollMode==0 then
        filteredDirectorRoll=(rollMode==0) and rawDirectorRoll or simDR_AHARS_roll_heading_deg_pilot
        director_rollFilterInitialized=true
        director_lastRollFilterUpdate=simDRTime
    elseif elapsedSec>0 then
        filteredDirectorRoll=B747_afds_controls.adaptive_roll_filter(filteredDirectorRoll,rawDirectorRoll,
            elapsedSec,B747_roll_approach_protected())
        director_lastRollFilterUpdate=simDRTime
    end
    B747DR_flight_director_roll=filteredDirectorRoll
    return filteredDirectorRoll
end

local current_pitch_intregal=0
local directorLastPitchMode=0
local directorLastRawPitch=0
local director_lastPitchControlUpdate=0
function ap_director_pitch_integral()
    local displayUpdate=false
    local pitchMode=B747DR_ap_FMA_active_pitch_mode
    local modeChanged=pitchMode~=directorLastPitchMode
    local effectiveSampleRate=directorSampleRate
    if modeChanged or B747_pitch_transition_active() then
        effectiveSampleRate=math.min(effectiveSampleRate,PITCH_TRANSITION_SAMPLE_INTERVAL_SEC)
    end
    if modeChanged or (simDRTime-director_lastPitchRecordUpdate)>effectiveSampleRate then
        displayUpdate=true
        director_lastPitchRecordUpdate=simDRTime
        -- Transition blending needs a fast display refresh, but the underlying
        -- pitch controller must keep its normal sample rate.  Calling the
        -- controller at the blend rate multiplies its per-update correction
        -- during FLCH/VNAV handoffs and can produce a sharp pitch-down.
        local controllerUpdateDue=B747_afds_controls.pitch_controller_update_due(modeChanged,
            simDRTime-director_lastPitchControlUpdate,directorSampleRate)
        local directorPitch
        if controllerUpdateDue then
            directorPitch=ap_director_pitch(pitchMode)
            directorLastRawPitch=B747_afds_pitch_target_before_blend
            director_lastPitchControlUpdate=simDRTime
        else
            directorPitch=ap_director_pitch_retVal(pitchMode,directorLastRawPitch)
        end
        if modeChanged and B747_pitch_transition_active() then
            -- The transition itself supplies damping; discard stale samples from the old mode.
            for i=1,10,1 do
                director_pitchRecord[i]=directorPitch
            end
        else
            director_pitchRecord[director_currentPitchRecord]=directorPitch
        end
        directorLastPitchMode=pitchMode
        director_currentPitchRecord=director_currentPitchRecord+1
        --print("currentPitchRecord "..director_currentPitchRecord)
        if director_currentPitchRecord>10 then
            director_currentPitchRecord=1
        end
        current_pitch_intregal=0
        for i=1,10,1 do
            current_pitch_intregal=current_pitch_intregal+director_pitchRecord[i]
        -- if displayUpdate then print("i "..i.." = " ..pitchRecord[i].. " " ..current_pitch_intregal) end
        end
    end
    
    local retval=current_pitch_intregal/10
    B747DR_flight_director_pitch=retval
    --if displayUpdate then print("retval "..retval.." "..simDRTime) end
    return retval
end

local trimrate=25
function doTrim()

    if simDRTime-lastTrimmed<0.2 or simDR_radarAlt1<500 then return end
    lastTrimmed=simDRTime
    local ratioWindow=0.05
    if simDR_autopilot_alt_hold_status==2 then
        ratioWindow=0.005
    elseif B747DR_ap_FMA_active_pitch_mode==2 then
        ratioWindow=0.01 --quick trim on glideslope and alt hold
    elseif B747DR_ap_FMA_active_pitch_mode==4 or B747DR_ap_FMA_active_pitch_mode==8 or (B747DR_ap_FMA_active_pitch_mode==6 and B747DR_ap_inVNAVdescent>0) then
        ratioWindow=0.2 --limit trim activity when pitching for speed
    end

    
    if simDR_ind_airspeed_kts_pilot>230 then
        trimrate=60
    elseif simDR_ind_airspeed_kts_pilot<220 then
        trimrate=30
    end
    if B747DR_custom_pitch_ratio>ratioWindow then
        simDR_elevator_trim=B747_interpolate_value(simDR_elevator_trim,1.0,-1,1,trimrate)
        lastTrimmed=simDRTime+1 
        --print("up trim "..ratioWindow)
    elseif B747DR_custom_pitch_ratio<-ratioWindow then
        simDR_elevator_trim=B747_interpolate_value(simDR_elevator_trim,-1.0,-1,1,trimrate) 
        lastTrimmed=simDRTime+1 
        --print("down trim "..ratioWindow)
   -- else
   --     print("no trim "..ratioWindow.." "..B747DR_sim_pitch_ratio)
    end

end
local previous_simDR_AHARS_pitch_heading_deg_pilot=0

-- the pitch PID derivative while AUTOLAND flies the flare (below 100 ft RA): the flare law
-- (B747.autoland.lua) was tuned in X-Plane with this nearly undamped loop
local AUTOLAND_PITCH_KD=0.0002
local pitchPid = newPid()
pitchPid.minout=-1
pitchPid.maxout=1
pitchPid.target=0
pitchPid.input = 0
pitchPid:compute()

function ap_pitch_assist()
    local flight_director_pitch=ap_director_pitch_integral()
    local target=0
    local retval=B747DR_sim_pitch_ratio--B747_interpolate_value(B747DR_sim_pitch_ratio,0,-1,1,20)
    local refreshsimDR_electric_trim=simDR_electric_trim
    local refresh_trim=simDR_elevator_trim
    -- read by get_FPM_bias only while the director runs ALT, V/S or VNAV PTH
    local refreshFlapRatio=B747DR_flap_ratio
    local refreshFlapDetent=B747DR_flap_lever_detent
    -- read by the director only once AUTOLAND engages; XTLua gives 0 for a dataref's first read
    local refreshAutolandPitch=B744DR_autolandPitch
    -- [P37] read by the director only in G/S (getGlideSlopeFPM, glide_slope_path_error_deg): a 0 elevation would be
    -- a dive of the whole altitude, 0s for the others a level path and a pitch down
    local refreshElevation=simDR_elevation
    local refreshGroundspeed=simDR_groundspeed
    local refreshGlideslope=simDR_glideslope1
    -- [P43] read by the speed-on-pitch law at its updates (a 0 IAS would be a jump of the IAS's rate, a 0 TAS a
    -- level path)
    local refreshIAS=simDR_ind_airspeed_kts_pilot
    local refreshTAS=simDR_TAS_mps
    local refreshVVI=simDR_vvi_fpm_pilot
    local refreshAlpha=simDR_alpha_deg
    -- [P39] read by TO/GA's speed at a go-around (a 0 window's speed would be a target of 25 kt)
    local refreshV2=B747DR_airspeed_V2
    local refreshWindow=B747DR_ap_ias_dial_value
    local refreshWindowMach=simDR_autopilot_airspeed_is_mach

    B747DR_pidPitchP=B747_rescale(3000,B747DR_pidPitchPL,40000,B747DR_pidPitchPH,B747DR_autopilot_altitude_ft_pfd)
    if B747DR_ap_AFDS_mode_box_status_pilot==1 or B747DR_ap_AFDS_mode_box_status_copilot==1 then
        B747DR_pidPitchI=B747DR_pidPitchP*0.1
        --print("pitching for change")
    else
        B747DR_pidPitchI=B747DR_pidPitchP
    end
    B747DR_pidPitchI=B747DR_pidPitchP--*0.1 --scale this with P
    pitchPid.kp=B747DR_pidPitchP
    pitchPid.ki=B747DR_pidPitchI
    pitchPid.kd=B747DR_ap_autoland==1 and AUTOLAND_PITCH_KD or B747DR_pidPitchD
    
    if simDR_autopilot_servos_on>0 and (B747DR_ap_FMA_active_pitch_mode>0 or B747DR_ap_autoland == 1) then
        simDR_electric_trim=0
        pitchPid.input = simDR_AHARS_pitch_heading_deg_pilot
        pitchPid.target= flight_director_pitch
        if doCompute==1 then
            if simDRTime-B747DR_switching_servos_on<2 then
                -- flight_controls_override applies the command only 2 s after the servos came on: until
                -- then keep the integral at the servo's position instead of winding it up on the
                -- engagement error (2026-10-10, circuit hand-off 4.3 deg below the FD: the first applied
                -- command was full nose-up and the attitude overshot by 4.7 deg)
                pitchPid.output=B747DR_sim_pitch_ratio
                pitchPid:compute(true)
            else
                pitchPid:compute()
            end
        end
        local speed=B747_rescale(1,3,10,10,math.abs(flight_director_pitch-simDR_AHARS_pitch_heading_deg_pilot))
        if pitchPid.output==nil then return 0 end
        retval=B747_interpolate_value(B747DR_sim_pitch_ratio,pitchPid.output,-1,1,speed) 
        
        --retval=pitchPid.output

       -- print("elevatorRequest "..elevatorRequest .." pitchChange "..pitchChange .." targetElevator "..targetElevator .." elevatorRate "..elevatorRate)
        doTrim()
       -- print("flight_director_pitch "..flight_director_pitch .." simDR_AHARS_pitch_heading_deg_pilot "..simDR_AHARS_pitch_heading_deg_pilot .." retval "..retval)
    else
        pitchPid:compute(true)
        simDR_electric_trim=1
        B747_reset_pitch_transition()
        directorLastPitchMode=0
        directorLastRawPitch=simDR_AHARS_pitch_heading_deg_pilot
        director_lastPitchControlUpdate=simDRTime
    end
    if retval==nil then return 0 end
    return retval
end

local previous_simDR_AHARS_roll_heading_deg_pilot=0

local rollPid = newPid()
rollPid.minout=-1
rollPid.maxout=1
rollPid.target=0
rollPid.input = 0
rollPid:compute()

local function B747_log_afds_control_diagnostics(flight_director_roll)
    if not AFDS_CONTROL_DIAGNOSTICS_ENABLED
        or simDRTime-B747_afds_last_control_diagnostic_time<AFDS_CONTROL_DIAGNOSTIC_INTERVAL_SEC then
        return
    end
    B747_afds_last_control_diagnostic_time=simDRTime
    print(string.format(
        "[AFDS CTRL] roll=%d/%d pitch=%d/%d bankCmd=%.2f bank=%.2f fdBank=%.2f rollPID=%.3f pitchRaw=%.2f pitchBlend=%.2f",
        B747DR_ap_FMA_active_roll_mode,B747DR_afds_armed_roll_mode,
        B747DR_ap_FMA_active_pitch_mode,B747DR_afds_armed_pitch_mode,
        B747DR_ap_target_roll,simDR_AHARS_roll_heading_deg_pilot,flight_director_roll,
        rollPid.output or 0,B747_afds_pitch_target_before_blend,B747_afds_pitch_target_after_blend))
end

function ap_roll_assist()
    local retval=B747DR_sim_roll_ratio--B747_interpolate_value(B747DR_sim_roll_ratio,0,-1,1,20)
    local flight_director_roll=ap_director_roll_integral()
    -- [P40] the gains fall as the true airspeed rises above 340 kt (roll_gain_scale)
    local gainScale=B747_afds_controls.roll_gain_scale(simDR_TAS_mps)
    rollPid.kp=B747DR_pidRollP*gainScale
    rollPid.ki=B747DR_pidRollI*gainScale
    B747DR_pidRollD=B747_rescale(3000,B747DR_pidRollDL,30000,B747DR_pidRollDH,B747DR_autopilot_altitude_ft_pfd)
    rollPid.kd=B747DR_pidRollD*gainScale
    if simDR_autopilot_servos_on>0 and (B747DR_ap_FMA_active_roll_mode>0) then
        rollPid.input = simDR_AHARS_roll_heading_deg_pilot
        rollPid.target= flight_director_roll
        if doCompute==1 then
            rollPid:compute()
        end
        local bankError=flight_director_roll-simDR_AHARS_roll_heading_deg_pilot
        if rollPid.output==nil then return 0 end
        local responseSec=B747_afds_controls.roll_output_response_sec(bankError,B747DR_sim_roll_ratio,
            rollPid.output,B747_roll_approach_protected())
        retval=B747_interpolate_value(B747DR_sim_roll_ratio,rollPid.output,-1,1,responseSec)
        --print("flight_director_roll "..flight_director_roll.." responseSec "..responseSec .." simDR_AHARS_roll_heading_deg_pilot "..simDR_AHARS_roll_heading_deg_pilot .." retval "..retval)
    else
        rollPid:compute(true)
        director_rollFilterInitialized=false
    end
    B747_log_afds_control_diagnostics(flight_director_roll)
    return retval
end
-- [B-10] The yaw dampers (B747_afds_controls.yaw_damper_command: Dutch roll damping and turn coordination, the rudder
-- against the stability axes' yaw rate less a coordinated turn's, washed out), each channel moving at most over its range in 0.3 s
-- (yaw_damper_slew) and centred when off. It replaced a law that switched between the sideslip (above 5 deg of bank) and the heading's
-- deviation from its 0.9 s mean (below), cleared its memory at each switch, acted one way only below 5 deg and
-- differentiated an input held for 0.03 s: in TST744L its output jumped up to 0.29 at the 5 deg crossings, and with
-- a ~5 s oscillation of +-19 deg of bank it moved with the yaw rate (pumping it; p9-L1, 62 min).
-- On the ground the dampers keep no rudder and their filter starts again at lift-off: below 50 m/s there is no
-- coordinated turn to take away and the gain is at its largest, so taxi turns of 1-5 deg/s drove them to -0.9 to -1
-- (their whole authority, then +-3.5 deg of rudder) and a heading correction of 0.5 deg/s on the takeoff roll at
-- 120 kt to -0.46,
-- against the steering (a review; whether the 747-400's yaw dampers act on the ground is not settled here).
local yawDamperState={}
function yaw_damper_system()
    local command=0
    if simDR_touchGround==1 then
        yawDamperState={}
    else
        command=B747_afds_controls.yaw_damper_command(yawDamperState,simDR_yaw_rate,
            simDR_AHARS_roll_heading_deg_pilot,simDR_TAS_mps,simDR_ind_airspeed_kts_pilot,simDRTime,simDR_roll_rate,
            simDR_alpha_deg,simDR_flap_ratio)
    end
    B747DR_yaw_damper_upr=B747_afds_controls.yaw_damper_slew(B747DR_yaw_damper_upr,
        B747DR_yaw_damper_upr_on==1 and command or 0,SIM_PERIOD)
    B747DR_yaw_damper_lwr=B747_afds_controls.yaw_damper_slew(B747DR_yaw_damper_lwr,
        B747DR_yaw_damper_lwr_on==1 and command or 0,SIM_PERIOD)
end


function flight_controls_override()
    --[[override=1
    for i=1,4,1 do
        if B747_pressureDRs[i]>800 then
            --override=0
        end
    end]] --this ver always overrides
    if (simDRTime-lastCompute)>computeRate then
        doCompute=1
        lastCompute=simDRTime
    else
        doCompute=0
    end  
    simDR_override_control_surfaces=1--override
    

    
    if B747_pressureDRs[1]>1000 then

        if simDR_ias_pilot<20 then
            simDR_override_steering=0
        else
            simDR_override_steering=1
            simDR_steering[0]=B747_rescale(-1,-7,1,7,simDR_total_heading_ratio)
            simDR_steering[1]=B747_interpolate_value(simDR_steering[1],0,-77,77,0.3)
            simDR_steering[2]=B747_interpolate_value(simDR_steering[2],0,-77,77,0.3)
        end
    else

        simDR_override_steering=1
    end
    

    --Rudder ratio changer
    B747DR_rudder_ratio=1.0-B747_rescale(150,0,450,0.84375,simDR_ias_pilot)
    B747DR_elevator_ratio=1.0--(1.0-B747_rescale(150,0,350,0.84375,simDR_ias_pilot))*-1
    B747DR_l_aileron_outer_lockout   = 1.0-B747_rescale(232,0,238,1.0,simDR_ias_pilot)
    B747DR_r_aileron_outer_lockout   = (1.0-B747_rescale(232,0,238,1.0,simDR_ias_pilot))*-1
    B747_slats()
    if((simDRTime - B747DR_switching_servos_on)<2) then
        ap_pitch_assist()
        ap_roll_assist()
    else
        B747DR_sim_pitch_ratio=ap_pitch_assist()
        B747DR_sim_roll_ratio=ap_roll_assist()
    end
    yaw_damper_system()

end
