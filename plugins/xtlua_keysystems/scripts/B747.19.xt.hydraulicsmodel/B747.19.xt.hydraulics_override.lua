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
-- 2 rudder upper 1,3
-- 3 l elev inner
-- 4 r elev inner
-- 5 l elev outer
-- 6 r elev outer
-- 7 l ail inner sim/flightmodel/controls/wing2l_ail1def
-- 8 r ail inner sim/flightmodel/controls/wing2r_ail1def
-- 9 l ail outer sim/flightmodel/controls/wing4l_ail2def
-- 10 r ail outer sim/flightmodel/controls/wing4r_ail2def
-- 11-22 spoilers 1-12
local B747_pressureDRs={}
local controlRatios={}
local spoiler_command={}
controlRatios[0]=0
B747_pressureDRs[0]=0
local computeRate=0.0333 -- handle low FPS
local lastCompute=0
local doCompute=0

-- FLT CONTROL HYD POWER: the flight control shutoff valves (ATA27 p.10-14).
-- A 28V DC motor (the system's DC bus: estimate) drives each valve to its
-- switch's position in VALVE_S (estimate); the surfaces get the system's
-- pressure while its valve is less than half shut (estimate). VALVE CLOSED
-- (the lighting module) and >FLT CONT VLVS while a valve is not fully open
-- (FCOM p.940, p.957). The wing valves feed the ailerons and spoilers, the
-- tail valves the elevators and rudders (and the yaw dampers in the rudder
-- modules); the stabilizer trim and the elevator feel do not go through
-- them (ATA27 p.432, p.532). 4-1 step 4
local VALVE_S = 2
local ADV_FLT_CONT_VLVS = 143
local wing_ok, tail_ok = {1, 1, 1, 1}, {1, 1, 1, 1}
-- each surface's systems, and the same through the valves (the pressure gates)
local FCSOV_SRC = {
    rud_lwr = {0,1,0,1}, rud_upr = {1,0,1,0},
    elev_l_in = {1,1,0,0}, elev_r_in = {0,0,1,1}, elev_l_out = {1,0,0,0}, elev_r_out = {0,0,0,1},
    ail_l_in = {1,0,1,0}, ail_r_in = {0,1,0,1}, ail_l_out = {1,1,0,0}, ail_r_out = {0,0,1,1},
    spl_2 = {0,1,0,0}, spl_3 = {0,0,1,0}, spl_4 = {0,0,0,1},
}
local FCSOV_TAIL = {rud_lwr = true, rud_upr = true, elev_l_in = true, elev_r_in = true, elev_l_out = true, elev_r_out = true}
local fcsov_src = {}
for name, src in pairs(FCSOV_SRC) do fcsov_src[name] = {src[1], src[2], src[3], src[4]} end

local function fcsov_move(shut, valve, n)
    local target, pos = shut[n - 1], valve[n - 1]
    if pos ~= target and B747DR_hyd_elec_dc[n - 1] > 0.5 then
        local step = SIM_PERIOD / VALVE_S
        if target > pos then pos = math.min(target, pos + step) else pos = math.max(target, pos - step) end
        valve[n - 1] = pos
    end
    return pos
end

function B747_fcsov()
    local any = 0
    for n = 1, 4 do
        local w = fcsov_move(B747DR_fcsov_wing_shut, B747DR_fcsov_wing_valve, n)
        local t = fcsov_move(B747DR_fcsov_tail_shut, B747DR_fcsov_tail_valve, n)
        if w < 0.5 then wing_ok[n] = 1 else wing_ok[n] = 0 end
        if t < 0.5 then tail_ok[n] = 1 else tail_ok[n] = 0 end
        if w > 0 or t > 0 then any = 1 end
    end
    for name, src in pairs(FCSOV_SRC) do
        local ok = FCSOV_TAIL[name] and tail_ok or wing_ok
        local m = fcsov_src[name]
        for i = 1, 4 do m[i] = src[i] * ok[i] end
    end
    if B747DR_hyd_CAS_advisory[ADV_FLT_CONT_VLVS] ~= any then B747DR_hyd_CAS_advisory[ADV_FLT_CONT_VLVS] = any end
end

-- the switches (commands: the 3D has none), NORM <-> SHUT OFF
function B747_fcsov_toggle(group, n)
    return function(phase, duration)
        if phase == 0 then
            local sw = B747DR_fcsov_wing_shut
            if group == "tail" then sw = B747DR_fcsov_tail_shut end
            sw[n - 1] = 1 - sw[n - 1]
        end
    end
end

-- a yaw damper's hydraulics: its system through the tail valve (the upper
-- damper on system 3, the lower on 2: FCOM p.949)
function B747_fcsov_yaw_damper_hyd(n)
    return tail_ok[n] == 1 and B747_hyd_power_psi(n) >= B747_hyd_model.POWERED_PSI
end

function B747_fcsov_flight_start()
    for i = 0, 3 do
        B747DR_fcsov_wing_shut[i], B747DR_fcsov_tail_shut[i] = 0, 0
        B747DR_fcsov_wing_valve[i], B747DR_fcsov_tail_valve[i] = 0, 0
    end
end
-- the hydraulic model's pressures (B747.19.xt.hyd_power.lua); each move of
-- a surface takes some, and a surface stops when its systems have no more
function pressure_input()
    B747_fcsov()
    for n=1,4,1 do
        B747_pressureDRs[n]=B747_hyd_power_psi(n)
    end
    
    controlRatios[1]=B747_controls_lower_rudder--simDR_rudder[10]
    controlRatios[2]=B747_controls_upper_rudder--simDR_rudder[10]

    controlRatios[3]=B747_controls_left_inner_elevator-- -simDR_elevator[0]
    controlRatios[4]=B747_controls_right_inner_elevator-- -simDR_elevator[0]
    controlRatios[5]=B747_controls_left_outer_elevator-- -simDR_elevator[0]
    controlRatios[6]=B747_controls_right_outer_elevator-- -simDR_elevator[0]

    -- the ailerons and spoilers from the control wheel's angle (the
    -- controlObject's): the aileron programmers, the outboard ailerons
    -- through the lockout (the SRMs write left lock, right -lock), the spoiler
    -- mixers with the speedbrake program (B747.19.lateral_model.lua, 4-1
    -- step 4; before, each was in proportion to the wheel and the spoilers
    -- only rose on the wing going up)
    local wheel=B747_controls_wheel
    controlRatios[7]=B747_lateral_model.inner(wheel)
    controlRatios[8]=B747_lateral_model.inner(-wheel)
    controlRatios[9]=B747_lateral_model.outer(wheel)*B747DR_l_aileron_outer_lockout
    controlRatios[10]=B747_lateral_model.outer(-wheel)*-B747DR_r_aileron_outer_lockout

    -- the spoilers, left wing 1-6 and right wing 7-12
    B747_lateral_model.spoilers(wheel,B747DR_speedbrake_lever,spoiler_command)
    for n=1,12,1 do
        controlRatios[n+10]=spoiler_command[n]
    end

    --flaps left outer to right outer: where the flap control units have
    --them (B747.45.xt.fcu.lua; they check the systems' pressure themselves)
    controlRatios[23]=B747DR_fcu_te_deg[0]
    controlRatios[24]=B747DR_fcu_te_deg[1]
    controlRatios[25]=B747DR_fcu_te_deg[2]
    controlRatios[26]=B747DR_fcu_te_deg[3]
    
end

function pressure_output()
    -- what is left goes back to the model as the flow taken; the quantity's
    -- effect on pressure is in the model (the standpipe, HYD-21)
    for n=1,4,1 do
        B747_hyd_power_left(n,B747_pressureDRs[n])
    end
    B747DR_hyd_sys_pressure_1=B747_pressureDRs[1]
    B747DR_hyd_sys_pressure_2=B747_pressureDRs[2]
    B747DR_hyd_sys_pressure_3=B747_pressureDRs[3]
    B747DR_hyd_sys_pressure_4=B747_pressureDRs[4]

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
    -- X-Plane's spoilers (the acf's wing elements: B747.19.xt.hydraulicsmodel.lua)
    simDR_spoiler12=(B747DR_spoilers[1]+B747DR_spoilers[2])/2
    simDR_spoiler3=B747DR_spoilers[3]
    simDR_spoiler4=B747DR_spoilers[4]
    simDR_spoiler5=B747DR_spoilers[5]
    simDR_spoiler67[0]=B747DR_spoilers[6]
    simDR_spoiler67[1]=B747DR_spoilers[7]
    simDR_spoiler8=B747DR_spoilers[8]
    simDR_spoiler9=B747DR_spoilers[9]
    simDR_spoiler10=B747DR_spoilers[10]
    simDR_spoiler1112=(B747DR_spoilers[11]+B747DR_spoilers[12])/2
    --spoiler stat: the position transmitters on spoilers 4 and 12 (ATA27 p.200;
    --the in-flight speedbrake shows on the left wing only, FCOM p.939)
    B747DR_outer_spoilers[0]=B747_animate_value(B747DR_outer_spoilers[0],B747DR_spoilers[4],-100,100,10)
    B747DR_outer_spoilers[1]=B747_animate_value(B747DR_outer_spoilers[1],B747DR_spoilers[12],-100,100,10)

    --flaps: where the flap control units drive them; the outboard flaps
    --are on the acf's wings 2 and 3 (flap set 2), the inboard on wing 1
    for i=1,4,1 do
        B747DR_flaps[i]=controlRatios[22+i]
    end
    simDR_flap1=B747DR_flaps[1]
    simDR_flap2=B747DR_flaps[2]
    simDR_flap3=B747DR_flaps[3]
    simDR_flap4=B747DR_flaps[4]
    simDR_flap1_wing2=B747DR_flaps[1]
    simDR_flap4_wing2=B747DR_flaps[4]
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

-- the flaps take their share while they move (systems 4 outboard, 1
-- inboard); whether they can move is the flap control units' business
-- (1400, 1600, 2000 psi: B747.45.fcu_model.lua)
function flap_consumption(controlDiff)
    hydraulics_consumer({0,0,0,1},controlDiff[23]*10)
    hydraulics_consumer({1,0,0,0},controlDiff[24]*10)
    hydraulics_consumer({1,0,0,0},controlDiff[25]*10)
    hydraulics_consumer({0,0,0,1},controlDiff[26]*10)
end
function spoiler_consumption(controlDiff)
    --system 2, spoilers 2,3,10,11
    if hydraulics_consumer(fcsov_src.spl_2,controlDiff[12]/3)==0 then
        controlRatios[12]=B747_animate_value(lastControlValue[12],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_2,controlDiff[13]/3)==0 then
        controlRatios[13]=B747_animate_value(lastControlValue[13],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_2,controlDiff[20]/3)==0 then
        controlRatios[20]=B747_animate_value(lastControlValue[20],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_2,controlDiff[21]/3)==0 then
        controlRatios[21]=B747_animate_value(lastControlValue[21],0,-100,100,1)
    end
    --system 3, spoilers 1,4,9,12
    if hydraulics_consumer(fcsov_src.spl_3,controlDiff[11]/3)==0 then
        controlRatios[11]=B747_animate_value(lastControlValue[11],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_3,controlDiff[14]/3)==0 then
        controlRatios[14]=B747_animate_value(lastControlValue[14],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_3,controlDiff[19]/3)==0 then
        controlRatios[19]=B747_animate_value(lastControlValue[19],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_3,controlDiff[22]/3)==0 then
        controlRatios[22]=B747_animate_value(lastControlValue[22],0,-100,100,1)
    end

    --system 4, spoilers 5,6,7,8
    if hydraulics_consumer(fcsov_src.spl_4,controlDiff[15]/3)==0 then
        controlRatios[15]=B747_animate_value(lastControlValue[15],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_4,controlDiff[16]/3)==0 then
        controlRatios[16]=B747_animate_value(lastControlValue[16],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_4,controlDiff[17]/3)==0 then
        controlRatios[17]=B747_animate_value(lastControlValue[17],0,-100,100,1)
    end
    if hydraulics_consumer(fcsov_src.spl_4,controlDiff[18]/3)==0 then
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
    if hydraulics_consumer(fcsov_src.rud_lwr,controlDiff[1]*3)==0 then
        controlRatios[1]=B747_animate_value(lastControlValue[1],0,-100,100,10)
    end

    --[[if hydraulics_consumer(fcsov_src.rud_lwr,controlDiff[1]*3)==0 then
        controlRatios[1]=B747_animate_value(lastControlValue[1],0,-100,100,1)
    end]]
    -- rudder upper 1,3
    if hydraulics_consumer(fcsov_src.rud_upr,controlDiff[2]*3)==0 then
        controlRatios[2]=B747_animate_value(lastControlValue[2],0,-100,100,10)
    end
    
    --1,2 L inboard elev
    if hydraulics_consumer(fcsov_src.elev_l_in,controlDiff[3]*3)==0 then
        controlRatios[3]=B747_animate_value(lastControlValue[3],0,-100,100,20)
    end
    --3,4 R inboard elev
    if hydraulics_consumer(fcsov_src.elev_r_in,controlDiff[4]*3)==0 then
        controlRatios[4]=B747_animate_value(lastControlValue[4],0,-100,100,20)
    end
    --1 L outboard elev
    if hydraulics_consumer(fcsov_src.elev_l_out,controlDiff[5]*3)==0 then
        controlRatios[5]=B747_animate_value(lastControlValue[5],0,-100,100,20)
    end
    --4 R outboard elev
    if hydraulics_consumer(fcsov_src.elev_r_out,controlDiff[6]*3)==0 then
        controlRatios[6]=B747_animate_value(lastControlValue[6],0,-100,100,20)
    end


    --1,3 L inboard aileron
    if hydraulics_consumer(fcsov_src.ail_l_in,controlDiff[7]*3)==0 then
        controlRatios[7]=B747_animate_value(lastControlValue[7],0,-100,100,1)
    end
    --2,4 R inboard aileron
    if hydraulics_consumer(fcsov_src.ail_r_in,controlDiff[8]*3)==0 then
        controlRatios[8]=B747_animate_value(lastControlValue[8],0,-100,100,1)
    end
    --1,2 L outboard aileron
    if hydraulics_consumer(fcsov_src.ail_l_out,controlDiff[9]*3)==0 then
        controlRatios[9]=B747_animate_value(lastControlValue[9],0,-100,100,1)
    end
    --3,4 R outboard aileron
    if hydraulics_consumer(fcsov_src.ail_r_out,controlDiff[10]*3)==0 then
        controlRatios[10]=B747_animate_value(lastControlValue[10],0,-100,100,1)
    end

    spoiler_consumption(controlDiff)
    flap_consumption(controlDiff)
    for i=1,numSurfaces,1 do
        lastControlValue[i]=controlRatios[i]
    end
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
    

    --the rudder ratio changers and the outboard aileron lockout: the SRMs
    --(B747.45.xt.srm.lua). The pedals and the rudder trim (80 % of the full
    --travel) go through the ratio changers together, so the changers limit
    --their sum (ATA27 p.596, p.612-614, p.634). The pedals from the pilots'
    --input alone: X-Plane's total_heading_ratio holds some trim in the air
    local rudder_input=simDR_yoke_heading_ratio+simDR_rudder_trim_ratio*0.8
    if rudder_input>1 then rudder_input=1 elseif rudder_input<-1 then rudder_input=-1 end
    if B747DR_rudder_input~=rudder_input then B747DR_rudder_input=rudder_input end
    B747DR_elevator_ratio=1.0--(1.0-B747_rescale(150,0,350,0.84375,simDR_ias_pilot))*-1
    B747_slats()
    if simDR_autopilot_servos_on == 0 then
        -- the A/P off: its commands go back to neutral (before, the 2 s
        -- window below never ended with the A/P off, the autopilot module
        -- restarting it every frame, and the last commands stayed)
        B747DR_sim_pitch_ratio=ap_pitch_assist(doCompute)
        B747DR_sim_roll_ratio=ap_roll_assist(doCompute)
    elseif((simDRTime - B747DR_switching_servos_on)<2) then
        ap_pitch_assist(doCompute)
        ap_roll_assist(doCompute)
    else
        B747DR_sim_pitch_ratio=ap_pitch_assist(doCompute)
        B747DR_sim_roll_ratio=ap_roll_assist(doCompute)
    end
    yaw_damper_system(doCompute)

end
