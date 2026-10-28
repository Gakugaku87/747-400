-- AFDS control laws: the flight director pitch and roll commands, the
-- autopilot's pitch and roll servo commands and its autotrim command.
-- Moved unchanged out of B747.19.xt.hydraulics_override.lua (docs/overhaul/PLAN.md R-1).
-- B747.19.xt.hydraulicsmodel.lua loads it after pid.lua; flight_controls_override()
-- calls ap_pitch_assist(doCompute) and ap_roll_assist(doCompute) every frame.
-- The autotrim command goes to the SRMs, which move the stabilizer
-- (B747.45.xt.srm.lua, 4-1 step 2b; before, doTrim wrote X-Plane's trim).
B747DR_ap_AFDS_mode_box_status_pilot = find_dataref("laminar/B747/autopilot/AFDS/mode_box_status_pilot")
B747DR_ap_AFDS_mode_box_status_copilot =find_dataref("laminar/B747/autopilot/AFDS/mode_box_status_copilot")
-- the roll laws' command (6-3 step 2a, the autopilot module's
-- B747.70.afds_roll_model.lua): the bank to fly when roll_law is 1
B747DR_ap_roll_cmd = find_dataref("laminar/B747/autopilot/roll_cmd")
B747DR_ap_roll_law = find_dataref("laminar/B747/autopilot/roll_law")
-- the pitch laws' command (6-3 step 3a, B747.70.afds_pitch_model.lua): the
-- attitude to fly when pitch_law is 1
B747DR_ap_pitch_cmd = find_dataref("laminar/B747/autopilot/pitch_cmd")
B747DR_ap_pitch_law = find_dataref("laminar/B747/autopilot/pitch_law")
-- the elevator's travel (degrees up and down) for the autotrim's band
simDR_ap_elev_up = find_dataref("sim/aircraft/controls/acf_elev_up")
simDR_ap_elev_dn = find_dataref("sim/aircraft/controls/acf_elev_dn")
-- the pitch rate (the IRUs': X-Plane's body rate, degrees a second)
simDR_ap_pitch_rate = find_dataref("sim/flightmodel/position/Q")
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
local director_rollRecord={}
local director_currentrollRecord=1
local director_lastrollRecordUpdate=0
for i=1,10,1 do
    director_rollRecord[i]=0
end
local last_simDR_ind_airspeed_kts_pilot=0
local last_simDR_AHARS_pitch_heading_deg_pilot=0
local last_altitude=0
local directorSampleRate=0.02
local directorRollSampleRate=0.1
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
function ap_director_pitch_retVal(pitchMode,retVal)
    if pitchMode~=lastPitchMode then
        lastPitchModeChange=simDRTime
        lastPitchMode=pitchMode
        
    end
    local diff=simDRTime-lastPitchModeChange
    if diff<0.7 then
        if debug_flight_directors==1 then
            print("last ap_director_pitch_retVal "..lastRetVal .." retVal "..retVal .." pitchMode "..pitchMode)
        end
        last_simDR_AHARS_pitch_heading_deg_pilot=lastRetVal
        return lastRetVal
    end
    if debug_flight_directors==1 then
        print("ap_director_pitch_retVal "..retVal.." retVal "..retVal .." pitchMode "..pitchMode)
    end
    lastRetVal=retVal
    return retVal

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
    if math.abs(nextVdef)>2.0 then
        nextVdef=nextVdef*3
    end
    local correction=(75*nextVdef)
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
function get_FPM_bias()
    local fpmBiasMax=6000
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
function ap_director_pitch(pitchMode)
    time=simDRTime-previous_pitchTime
    previous_pitchTime=simDRTime
    --print("ap_director_pitch" ..time.. " "..directorSampleRate)
    if time>5 or time==0 or B747DR_ap_pitch_mode_box_status==1 then
        return simDR_AHARS_pitch_heading_deg_pilot
    end
   -- print("ap_director_pitc go")
    local alt_delta=simDR_pressureAlt1-last_altitude
    last_altitude=simDR_pressureAlt1
    local holdAlt=simDR_autopilot_altitude_ft 
    local refreshHoldAlt=simDR_autopilot_hold_altitude_ft
    local refreshfd=simDR_flight_director_pitch
    if simDR_autopilot_alt_hold_status==2 and (pitchMode~=5 and pitchMode~=6 and pitchMode~=9) then
        simDR_autopilot_alt_hold_status=0
    end
    -- no pitch mode (everything off: the AFDS model, 6-3 step 1a): no
    -- command, and no capture (the window below latched ALT HOLD without a
    -- mode)
    if pitchMode == 0 then
        return simDR_AHARS_pitch_heading_deg_pilot
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
    if ((pitchMode==4 and B747DR_ap_flightPhase ~= 3) or pitchMode==8) 
    and (simDR_pressureAlt1> holdAlt+B747DR_alt_capture_window or simDR_pressureAlt1< holdAlt-B747DR_alt_capture_window) then
        --local pitchError=math.abs(simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot)
        local pitchError=simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot

        local speed_delta=simDR_ind_airspeed_kts_pilot-last_simDR_ind_airspeed_kts_pilot
        --FLCH
        if debug_flight_directors==1 then
            print("ap_director_pitch for FLCH "..B747DR_ap_flightPhase)
        end
        last_simDR_ind_airspeed_kts_pilot=simDR_ind_airspeed_kts_pilot
        if (math.abs(simDR_autopilot_airspeed_kts-simDR_ind_airspeed_kts_pilot)>5) and math.abs(simDR_vvi_fpm_pilot)>100 then
            directorSampleRate=0.3
        else
            directorSampleRate=0.5
        end

        local rog=0.01+math.abs(0.5*speed_delta)
        if rog>0.3 then rog=0.3 end
        if simDR_pressureAlt1>29000 or simDR_ind_airspeed_kts_pilot<simDR_autopilot_airspeed_kts then
            rog=rog/3
        end
        local min_speedDelta=0
        local max_speedDelta=0
        local minSafeSpeed = B747DR_airspeed_Vmc + 10
        local speedDiff=math.abs(simDR_ind_airspeed_kts_pilot-simDR_autopilot_airspeed_kts)
        local canDescend = true
        local canAscend = true
       -- if simDR_pressureAlt1> holdAlt and simDR_vvi_fpm_pilot > -200 and simDR_ind_airspeed_kts_pilot<B747DR_airspeed_Vmax-10 then canAscend = false end
        --if simDR_pressureAlt1< holdAlt and simDR_vvi_fpm_pilot < 200 and simDR_ind_airspeed_kts_pilot>minSafeSpeed then canDescend = false end

        if simDR_vvi_fpm_pilot > 200 and (simDR_ind_airspeed_kts_pilot<simDR_autopilot_airspeed_kts-5) then canAscend = false end
        if simDR_vvi_fpm_pilot < -200 and (simDR_ind_airspeed_kts_pilot>simDR_autopilot_airspeed_kts+5) then canDescend = false end
        if B747DR_ap_inVNAVdescent>0 and simDR_vvi_fpm_pilot < -500 and simDR_autopilot_airspeed_kts< simDR_ind_airspeed_kts_pilot+5 then canDescend = false end
        if  speedDiff > 1 then
            if (simDR_autopilot_airspeed_kts< simDR_ind_airspeed_kts_pilot-1) then
                max_speedDelta=0.001+speedDiff/250
            else
                max_speedDelta=0.001+speedDiff/25
            end
            min_speedDelta=max_speedDelta/3
        end

        if ((simDR_autopilot_airspeed_kts> simDR_ind_airspeed_kts_pilot+1) and speed_delta<max_speedDelta 
            or (simDR_autopilot_airspeed_kts< simDR_ind_airspeed_kts_pilot-1) and speed_delta<-max_speedDelta) and pitchError<0.5 and canDescend
        then
            if debug_flight_directors==1 then
                print("-simDR_AHARS_pitch_heading_deg_pilot "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_autopilot_airspeed_kts "..simDR_autopilot_airspeed_kts.." simDR_ind_airspeed_kts_pilot "..simDR_ind_airspeed_kts_pilot.." speed_delta "..speed_delta.." min_speedDelta "..min_speedDelta.." max_speedDelta "..max_speedDelta.." rog "..rog)
            end
            last_simDR_AHARS_pitch_heading_deg_pilot= (last_simDR_AHARS_pitch_heading_deg_pilot-rog)
        elseif ((simDR_autopilot_airspeed_kts< simDR_ind_airspeed_kts_pilot-1) and speed_delta>-min_speedDelta 
            or (simDR_autopilot_airspeed_kts> simDR_ind_airspeed_kts_pilot+1) and speed_delta>min_speedDelta ) and pitchError>-0.5 and canAscend
        then
            if debug_flight_directors==1 then
                print("+simDR_AHARS_pitch_heading_deg_pilot "..simDR_AHARS_pitch_heading_deg_pilot.." simDR_autopilot_airspeed_kts "..simDR_autopilot_airspeed_kts.." simDR_ind_airspeed_kts_pilot "..simDR_ind_airspeed_kts_pilot.." speed_delta "..speed_delta.." min_speedDelta "..min_speedDelta.." max_speedDelta "..max_speedDelta.." rog "..rog)
            end
            last_simDR_AHARS_pitch_heading_deg_pilot= (last_simDR_AHARS_pitch_heading_deg_pilot+rog)
        end

        last_altitude=simDR_pressureAlt1
        if last_simDR_AHARS_pitch_heading_deg_pilot<-3.5 then
            last_simDR_AHARS_pitch_heading_deg_pilot=-3.5
        elseif last_simDR_AHARS_pitch_heading_deg_pilot>15 then 
            last_simDR_AHARS_pitch_heading_deg_pilot=15
        end
        retval=last_simDR_AHARS_pitch_heading_deg_pilot
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        
        return ap_director_pitch_retVal(pitchMode,retval)
    elseif pitchMode~=2 and 
    (pitchMode==5 or pitchMode==9 or 
    (simDR_autopilot_alt_hold_status==2) or 
    (simDR_pressureAlt1< holdAlt+B747DR_alt_capture_window and simDR_pressureAlt1> holdAlt-B747DR_alt_capture_window)) then
        --ALT
        if debug_flight_directors==1 then
            print("ap_director_pitch for ALT")

        end 
        if simDR_autopilot_alt_hold_status~=2 then
            simDR_autopilot_hold_altitude_ft=simDR_autopilot_altitude_ft
            simDR_autopilot_alt_hold_status=2
            simDR_autopilot_vs_status=0
            simDR_autopilot_flch_status=0
            holdAlt=simDR_autopilot_hold_altitude_ft
        end
        local fpmBias=get_FPM_bias()
        local altDiff=math.abs(simDR_pressureAlt1-holdAlt+fpmBias*40)
        local targetFPM=(holdAlt-simDR_pressureAlt1)*2 --target alt in 30 secs
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
        if last_simDR_AHARS_pitch_heading_deg_pilot<-3.5 then
            last_simDR_AHARS_pitch_heading_deg_pilot=-3.5
        elseif last_simDR_AHARS_pitch_heading_deg_pilot>15 then 
            last_simDR_AHARS_pitch_heading_deg_pilot=15
        end
        retval=last_simDR_AHARS_pitch_heading_deg_pilot
        last_simDR_AHARS_pitch_heading_deg_pilot=retval
        return ap_director_pitch_retVal(pitchMode,retval)
    
    elseif pitchMode==4 or pitchMode==7 or pitchMode==6 or pitchMode==2 then --pitchMode==2 GLIDESLOPE
        local pitchError=simDR_AHARS_pitch_heading_deg_pilot-last_simDR_AHARS_pitch_heading_deg_pilot
        
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
        if pitchMode==2 then --set FPM based on glideslope
            targetFPM=getGlideSlopeFPM()
        --    print("getGlideSlopeFPM="..targetFPM.." dots="..simDR_hsi_vdef_dots_pilot)
             --minUpdateRate=B747_rescale(0,0.5,2.5,0.1,math.abs(simDR_hsi_vdef_dots_pilot)) -- be faster on glideslope
        --else
        --    print("standard FPM="..targetFPM.." dots="..simDR_hsi_vdef_dots_pilot)
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
        if last_simDR_AHARS_pitch_heading_deg_pilot<-3.5 then
            last_simDR_AHARS_pitch_heading_deg_pilot=-3.5
        elseif last_simDR_AHARS_pitch_heading_deg_pilot>10 then 
            last_simDR_AHARS_pitch_heading_deg_pilot=10
        end
        retval=last_simDR_AHARS_pitch_heading_deg_pilot
        last_simDR_AHARS_pitch_heading_deg_pilot=ap_director_pitch_retVal(pitchMode,retval)--retval
        --
        --if pitchMode==2 then
        --    ap_director_pitch_retVal(pitchMode,retval)--log it
        --    return retval
        --else
            return last_simDR_AHARS_pitch_heading_deg_pilot--ap_director_pitch_retVal(pitchMode,retval)
        --end
    elseif pitchMode==1 then
        -- TO/GA: the pitch laws' since 6-3 step 3b; X-Plane's TOGA pitch
        -- (the instruments' 8 degrees) only without them
        if debug_flight_directors==1 then
            print("ap_director_pitch for TOGA")
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
        last_simDR_AHARS_pitch_heading_deg_pilot=0
        return 0
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
local current_roll_intregal=0
function ap_director_roll_integral()
    --return B747DR_ap_target_roll
    local displayUpdate=false
    --[[if math.abs(simDR_AHARS_roll_heading_deg_pilot)>5 then
        directorRollSampleRate=0.1
    else
        directorRollSampleRate=1
    end]]
    directorRollSampleRate=B747_rescale(0,1,10,0.3,math.abs(simDR_AHARS_roll_heading_deg_pilot))
    
    if (simDRTime-director_lastrollRecordUpdate)>directorRollSampleRate then
        displayUpdate=true
        director_lastrollRecordUpdate=simDRTime
        director_rollRecord[director_currentrollRecord]=ap_director_roll()
        director_currentrollRecord=director_currentrollRecord+1
        --print("currentPitchRecord "..director_currentPitchRecord)
        if director_currentrollRecord>10 then
            director_currentrollRecord=1
        end
        current_roll_intregal=0
        for i=1,10,1 do
            current_roll_intregal=current_roll_intregal+director_rollRecord[i]
           --if displayUpdate then print("i "..i.." = " ..pitchRecord[i].. " " ..retval) end
        end
    end
    local retval=current_roll_intregal/10
    B747DR_flight_director_roll=retval
   -- if displayUpdate then print("retval "..retval.." "..simDRTime) end
    return retval
end

local current_pitch_intregal=0
function ap_director_pitch_integral()
    local displayUpdate=false
    if (simDRTime-director_lastPitchRecordUpdate)>directorSampleRate then
        displayUpdate=true
        director_lastPitchRecordUpdate=simDRTime
        director_pitchRecord[director_currentPitchRecord]=ap_director_pitch(B747DR_ap_FMA_active_pitch_mode)
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

-- the A/P not controlling: its elevator and aileron commands go back to
-- neutral at this rate, per second of the full travel (estimate; before,
-- they stayed at their last values and offset the pilots' controls)
local AP_RELEASE_PER_S = 1
local function ap_release(v)
    local step = AP_RELEASE_PER_S * SIM_PERIOD
    if v > step then return v - step elseif v < -step then return v + step end
    return 0
end

-- autotrim (ATA22 p.147): the FCC commands nose up or down trim while its
-- elevator servo command is out of neutral, from 0.4 degrees (0.6 with the
-- G/S captured) until it is back within 0.25 (ATA22 p.149: notes/ATA-22.md
-- §4.8; before, windows by mode from 0.1 degree in ALT HOLD to 4 in FLCH,
-- no band); the SRM trims after 3.5 s, at its rate and limits
-- (B747.45.xt.srm.lua). No trim command below 500 ft RA, as before (the
-- old flare tuning): the sources trim down to touchdown, with full-rate
-- autotrim below 120 ft in LAND 2 and a nose-up bias (ATA22 p.147), which
-- waits for the AFDS's rebuild (6-3 step 6). The full-rate request goes out
-- by its own condition
function setAutotrim(cmd)
    if B747DR_autotrim_cmd ~= cmd then B747DR_autotrim_cmd = cmd end
    local frat = 0
    if cmd ~= 0 and B747DR_ap_autoland == 1 and simDR_radarAlt1 < 120 then frat = 1 end
    if B747DR_autotrim_frat ~= frat then B747DR_autotrim_frat = frat end
end
local AUTOTRIM_ON_DEG, AUTOTRIM_ON_GS_DEG, AUTOTRIM_OFF_DEG = 0.4, 0.6, 0.25
local autotrim_dir = 0
function doTrim()
    local cmd = 0
    if simDR_radarAlt1 >= 500 then
        -- the servo command in degrees of the elevator's travel
        local r = B747DR_sim_pitch_ratio
        local deg = r >= 0 and r * simDR_ap_elev_up or r * simDR_ap_elev_dn
        local on = B747DR_ap_FMA_active_pitch_mode == 2 and AUTOTRIM_ON_GS_DEG or AUTOTRIM_ON_DEG
        if autotrim_dir ~= 0 and deg * autotrim_dir > AUTOTRIM_OFF_DEG then
            cmd = autotrim_dir
        elseif deg > on then
            cmd = 1
        elseif deg < -on then
            cmd = -1
        end
    end
    autotrim_dir = cmd
    setAutotrim(cmd)
end
local previous_simDR_AHARS_pitch_heading_deg_pilot=0

local pitchPid = newPid()
pitchPid.minout=-1
pitchPid.maxout=1
pitchPid.target=0
pitchPid.input = 0
pitchPid:compute()

-- the elevator trim integrator's stabilizer input (ATA22 p.330, p.333):
-- as the stabilizer trims, the integrator gives back the elevator the
-- stabilizer now stands for, X-Plane's stabilizer (its trim ratio) being
-- AP_STAB_PER_ELEV times as strong as the elevator (its ratio): 1.7 clean
-- at FL350, 2.35 with flaps 20 at 170 kt, fitted to s07's, s53's and
-- s109's recordings (estimate). Without it the autotrim and the integrator
-- took turns: at FL350 in ALT HOLD the pitch swung 1.3 degrees, 740 fpm
-- and 0.16 g every 17 s (s53), which a model of those recordings
-- reproduced; with it, from 1.2 to 2.2, the model holds level
local AP_STAB_PER_ELEV = 1.9
local ap_trim_last = nil

-- the inner loop's attitude rate (ATA22 p.330: the attitude error and the
-- attitude rate make the command): AP_PITCH_RATE_K of the elevator's ratio
-- against each degree a second of pitch rate, damping the short period
-- (X-Plane's 747 at FL350: 1.7 rad/s damped 0.28, fitted to s07's
-- recording) under the attitude error's gain, now 0.1 at all altitudes
-- (B747.19.xt.hydraulicsmodel.lua; notes/ATA-22.md §21). Alone with the
-- old gain it did not help (FL350: 250 to 340 fpm); with 0.1, ALT HOLD at
-- FL350 within 12 fpm and 0.01 g. Before, the attitude error only
-- (estimate)
local AP_PITCH_RATE_K = 0.03

-- the old law's state on the new law's command (6-3 step 3a): its last
-- command and its 10 samples, so that it goes on from there (G/S after V/S)
local function ap_director_pitch_sync(p)
    last_simDR_AHARS_pitch_heading_deg_pilot=p
    lastRetVal=p
    for i=1,10,1 do director_pitchRecord[i]=p end
    current_pitch_intregal=10*p
end

-- the pitch command: the pitch laws' (6-3 steps 3a and 3b: V/S, ALT and
-- its capture, FLCH, T/O, G/A, the old VNAV's), else the old one (G/S,
-- FLARE until steps 3c and 4)
function ap_pitch_assist(doCompute)
    local flight_director_pitch
    if B747DR_ap_pitch_law==1 then
        flight_director_pitch=B747DR_ap_pitch_cmd
        B747DR_flight_director_pitch=flight_director_pitch
        ap_director_pitch_sync(flight_director_pitch)
    else
        flight_director_pitch=ap_director_pitch_integral()
    end
    local target=0
    local retval=B747DR_sim_pitch_ratio--B747_interpolate_value(B747DR_sim_pitch_ratio,0,-1,1,20)
    local refreshsimDR_electric_trim=simDR_electric_trim
    local refresh_trim=simDR_elevator_trim

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
    pitchPid.kd=B747DR_pidPitchD
    
    if simDR_autopilot_servos_on>0 and (B747DR_ap_FMA_active_pitch_mode>0 or B747DR_ap_autoland == 1) then
        simDR_electric_trim=0
        local trim = simDR_elevator_trim
        if ap_trim_last and pitchPid._Iterm then
            pitchPid._Iterm = pitchPid._Iterm - AP_STAB_PER_ELEV * (trim - ap_trim_last)
        end
        ap_trim_last = trim
        pitchPid.input = simDR_AHARS_pitch_heading_deg_pilot
        pitchPid.target= flight_director_pitch
        if doCompute==1 then
            pitchPid:compute()
        end
        local speed=B747_rescale(1,3,10,10,math.abs(flight_director_pitch-simDR_AHARS_pitch_heading_deg_pilot))
        if pitchPid.output==nil then return 0 end
        local out = math.max(-1, math.min(1, pitchPid.output - AP_PITCH_RATE_K * simDR_ap_pitch_rate))
        retval=B747_interpolate_value(B747DR_sim_pitch_ratio,out,-1,1,speed) 
        
        --retval=pitchPid.output

       -- print("elevatorRequest "..elevatorRequest .." pitchChange "..pitchChange .." targetElevator "..targetElevator .." elevatorRate "..elevatorRate)
        doTrim()
       -- print("flight_director_pitch "..flight_director_pitch .." simDR_AHARS_pitch_heading_deg_pilot "..simDR_AHARS_pitch_heading_deg_pilot .." retval "..retval)
    else
        pitchPid:compute(true)
        ap_trim_last = nil
        autotrim_dir = 0
        simDR_electric_trim=1
        setAutotrim(0)
        retval=ap_release(B747DR_sim_pitch_ratio)
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

-- the roll command: the roll laws' (6-3 steps 2a and 2b: HDG SEL, HDG
-- HOLD, ATT, LNAV, TO/GA, LOC; not X-Plane's heading modes' averaged roll),
-- else the old one (no mode of the AFDS model's: the old autoland until
-- step 4)
function ap_roll_assist(doCompute)
    local retval=B747DR_sim_roll_ratio--B747_interpolate_value(B747DR_sim_roll_ratio,0,-1,1,20)
    local flight_director_roll
    if B747DR_ap_roll_law==1 then
        flight_director_roll=B747DR_ap_roll_cmd
        B747DR_flight_director_roll=flight_director_roll
    else
        flight_director_roll=ap_director_roll_integral()
    end
    rollPid.kp=B747DR_pidRollP
    rollPid.ki=B747DR_pidRollI
    B747DR_pidRollD=B747_rescale(3000,B747DR_pidRollDL,30000,B747DR_pidRollDH,B747DR_autopilot_altitude_ft_pfd)
    rollPid.kd=B747DR_pidRollD
    if simDR_autopilot_servos_on>0 and (B747DR_ap_FMA_active_roll_mode>0) then
        rollPid.input = simDR_AHARS_roll_heading_deg_pilot
        rollPid.target= flight_director_roll
        if doCompute==1 then
            rollPid:compute()
        end
        local speed=B747_rescale(0.1,3,10,5,math.abs(flight_director_roll-simDR_AHARS_roll_heading_deg_pilot))
        if rollPid.output==nil then return 0 end
        retval=B747_interpolate_value(B747DR_sim_roll_ratio,rollPid.output,-1,1,speed)
        --print("flight_director_roll "..flight_director_roll.." speed "..speed .." simDR_AHARS_roll_heading_deg_pilot "..simDR_AHARS_roll_heading_deg_pilot .." retval "..retval)
    else
        rollPid:compute(true)
        retval=ap_release(B747DR_sim_roll_ratio)
    end
    return retval
end
