--[[
*****************************************************************************************
* Program Script Name	:	B747.10.gear
* Author Name			:	Jim Gregory
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2016-04-26	0.01a				Start of Dev
*
*
*
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	        *
*****************************************************************************************
--]]


--*************************************************************************************--
--** 					              XLUA GLOBALS              				     **--
--*************************************************************************************--

--[[

SIM_PERIOD - this contains the duration of the current frame in seconds (so it is alway a
fraction).  Use this to normalize rates,  e.g. to add 3 units of fuel per second in a
per-frame callback you’d do fuel = fuel + 3 * SIM_PERIOD.

--]]


--*************************************************************************************--
--** 					               CONSTANTS                    				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 					            GLOBAL VARIABLES                				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 					            LOCAL VARIABLES                 				 **--
--*************************************************************************************--

--sim/operation/failures/rel_lbrakes  int y failure_enum  Left Brakes
--sim/operation/failures/rel_rbrakes  int y failure_enum  Right Brakes
--sim/operation/failures/rel_lagear1  int y failure_enum  Landing Gear 1 retract
--sim/operation/failures/rel_lagear2  int y failure_enum  Landing Gear 2 retract
--sim/operation/failures/rel_lagear3  int y failure_enum  Landing Gear 3 retract
--sim/operation/failures/rel_lagear4  int y failure_enum  Landing Gear 4 retract
--sim/operation/failures/rel_lagear5  int y failure_enum  Landing Gear 5 retract

function deferred_command(name,desc,realFunc)
	return replace_command(name,realFunc)
end

function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end


local B747_gear_handle_lock_override = 0
local B747_gear_handle_lock = 0




--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_startup_running       = find_dataref("sim/operation/prefs/startup_running")
simDR_aircraft_on_ground    = find_dataref("sim/flightmodel/failures/onground_any")
simDR_gear_deploy_ratio     = find_dataref("sim/flightmodel2/gear/deploy_ratio")
simDR_tire_steer_deg        = find_dataref("sim/flightmodel2/gear/tire_steer_actual_deg")
simDR_gear_claw_angle       = find_dataref("sim/flightmodel2/gear/eagle_claw_angle_deg")
simDR_gear_handle_down      = find_dataref("sim/cockpit2/controls/gear_handle_down")
simDR_autobrakes_switch     = find_dataref("sim/cockpit2/switches/auto_brake_level")
simDR_joy_axis		    = find_dataref("sim/joystick/joy_mapped_axis_value")
local seenTakeoffThrust=false
simDR_OAT_degC              = find_dataref("sim/cockpit2/temperature/outside_air_temp_degc")
simDR_tire_rot_speed        = find_dataref("sim/flightmodel2/gear/tire_rotation_speed_rad_sec")
B747DR_parking_brake_ratio  = find_dataref("laminar/B747/flt_ctrls/parking_brake_ratio")
simDR_parking_brake_ratio   = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
simDR_brake_override= find_dataref("sim/operation/override/override_toe_brakes")
simDR_brake_sweep= find_dataref("sim/cockpit2/controls/wingsweep_ratio")
simDR_left_brake_ratio      = find_dataref("sim/cockpit2/controls/left_brake_ratio")
simDR_right_brake_ratio     = find_dataref("sim/cockpit2/controls/right_brake_ratio")
simDR_inReplay              = find_dataref("sim/time/is_in_replay")
simDR_prop_mode                 = find_dataref("sim/cockpit2/engine/actuators/prop_mode")
simDR_left_brake_fail     = find_dataref("sim/operation/failures/rel_lbrakes")--6 = inoperative
simDR_right_brake_fail     = find_dataref("sim/operation/failures/rel_rbrakes")--6 = inoperative

-- air/ground sensing (PSEU): the model and its glue
dofile("B747.10.xt.pseu.lua")
-- the gear's actuation, alternate extension, monitoring and EICAS indication
dofile("B747.10.xt.gear_act.lua")
-- the wheel brakes: the brake source, the parking brake, the antiskid
dofile("B747.10.xt.brakes.lua")
B747DR_gear_lever_lock          = find_dataref("laminar/B747/gear/lever_lock")

--Marauder28
--Autobrake OFF/DISARM logic
simDR_speedbrake_lever	 		= find_dataref("laminar/B747/flt_ctrls/speedbrake_lever")
simDR_reverser_deployed			= find_dataref("sim/cockpit2/annunciators/reverser_deployed")
simDR_throttle_ratio_all		= find_dataref("sim/cockpit2/engine/actuators/throttle_ratio_all")
simDR_left_brake_add			= find_dataref("sim/flightmodel/controls/l_brake_add")
simDR_right_brake_add			= find_dataref("sim/flightmodel/controls/r_brake_add")
simDR_speedbrake_ratio			= find_dataref("sim/flightmodel2/controls/speedbrake_ratio")
B747DR_speedbrake_lever_changed	= find_dataref("laminar/B747/flt_ctrls/speedbrake_lever_changed", "number")
--Marauder28

--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_CAS_memo_status          = find_dataref("laminar/B747/CAS/memo_status")
B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")


--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_gear_lock_override_pos   = deferred_dataref("laminar/B747/gear_lock_ovrd/position", "number")
B747DR_autobrakes_sel_dial_pos  = deferred_dataref("laminar/B747/gear/autobrakes/sel_dial_pos", "number")

B747DR_gear_annun_status        = deferred_dataref("laminar/B747/gear/gear_position/annun_status", "number")
B747DR_EICAS1_gear_display_status = deferred_dataref("laminar/B747/gear/EICAS1_display_status", "number")


B747DR_tire_pressure            = deferred_dataref("laminar/B747/gear/tire_pressure", "array[18]")
B747DR_brake_temp               = deferred_dataref("laminar/B747/gear/brake_temp", "array[18]")
simDR_tire1_fail               = find_dataref("sim/operation/failures/rel_tire1")
simDR_tire2_fail               = find_dataref("sim/operation/failures/rel_tire2")
simDR_tire3_fail               = find_dataref("sim/operation/failures/rel_tire3")
simDR_tire4_fail               = find_dataref("sim/operation/failures/rel_tire4")
simDR_tire5_fail               = find_dataref("sim/operation/failures/rel_tire5")
B747DR_brake_temp_ind               = deferred_dataref("laminar/B747/gear/brake_temp_ind", "array[18]")
B747DR_init_gear_CD             = deferred_dataref("laminar/B747/gear/init_CD", "number")
B747DR__gear_chocked           = deferred_dataref("laminar/B747/gear/chocked", "number")

--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--

----- GEAR HANDLE DATAREF HANDLER -------------------------------------------------------
-- in the init script (B747.10.gear.lua): the detents and the lever lock





--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

----- LANDING GEAR HANDLE ---------------------------------------------------------------
B747DR_gear_handle 			= deferred_dataref("laminar/B747/actuator/gear_handle", "number")
B747DR_gear_handle_detent 	= deferred_dataref("laminar/B747/actuator/gear_handle_detent", "number")


local runningGear=0
function B747CMD_gear_up_full_CMDhandler(phase, duration)
    if B747DR_gear_handle~=2 then
        runningGear=1 --up
    end
end
function B747CMD_gear_down_full_CMDhandler(phase, duration)
    if B747DR_gear_handle~=0 then
        runningGear=-1 --down
    end
end
function B747CMD_gear_off_CMDhandler(phase, duration)
    if B747DR_gear_handle~=1 then
        runningGear=2 --off
    end
end
function B747_animate_value(current_value, target, min, max, speed)

   --[[ local fps_factor = math.min(0.1, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end]]--
    local fps_factor = math.min(0.1, speed * SIM_PERIOD)
	local nextValue=current_value + ((target - current_value) * fps_factor)
    if nextValue >= (max - 0.001) then
        return max
    elseif nextValue <= (min + 0.001) then
       return min
    else
        return nextValue
    end

end
function runGear()
  --print("simDR_gear_handle_down "..simDR_gear_handle_down)
  if runningGear ==0 then return end
  if B747DR_gear_handle_detent < 0.037 then B747DR_gear_handle_detent=B747_animate_value(B747DR_gear_handle_detent,0.037,0,0.037,10) return end
  if runningGear ==2 and (B747DR_gear_handle<1 or B747DR_gear_handle>1) then B747DR_gear_handle=B747_animate_value(B747DR_gear_handle,1,0,2,10) return end
  -- the lever lock stops the lever at OFF on its way to UP (FCOM p.1512)
  if runningGear ==1 and B747_gear_handle_lock == 1 and (B747DR_gear_handle<1 or B747DR_gear_handle>1) then B747DR_gear_handle=B747_animate_value(B747DR_gear_handle,1,0,2,10) return end
  if runningGear ==1 and B747_gear_handle_lock == 0 and B747DR_gear_handle<2 then B747DR_gear_handle=B747_animate_value(B747DR_gear_handle,2,0,2,10) return end
  if runningGear ==-1 and B747DR_gear_handle>0 then B747DR_gear_handle=B747_animate_value(B747DR_gear_handle,0,0,2,10) return end

  B747DR_gear_handle_detent=0
  runningGear=0


end
--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--
B747CMD_gear_up_full      = deferred_command("laminar/B747/gear/overrideUp", "Gear Full Up", B747CMD_gear_up_full_CMDhandler)
B747CMD_gear_down_full    = deferred_command("laminar/B747/gear/overrideDown", "Gear Full Down", B747CMD_gear_down_full_CMDhandler)
B747CMD_gear_off      = deferred_command("laminar/B747/gear/overrideOff", "Gear Off", B747CMD_gear_off_CMDhandler)




function sim_landing_gear_toggle_CMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_gear_handle<1.5 and B747DR_gear_handle>0.5 then
            runningGear=-1
        end
        if B747DR_gear_handle<0.5 then
            runningGear=1
        end
        if B747DR_gear_handle>1.5 then
            runningGear=2
        end
    end
end

--[[function sim_landing_gear_toggle_CMDhandler(phase, duration)
    if phase == 0 then
        -- GEAR HANDLE LOCK IS DISENGAGED
        if B747_gear_handle_lock == 0 then

            if simDR_gear_deploy_ratio[0] >= 0.5
                    and simDR_gear_deploy_ratio[1] >= 0.5
                    and simDR_gear_deploy_ratio[2] >= 0.5
                    and B747DR_gear_handle <= 1.0
            then
                B747DR_gear_handle = 2.0
                simDR_gear_handle_down = 0
            else
                B747DR_gear_handle = 0.0
                simDR_gear_handle_down = 1
            end

        -- GEAR HANDLE LOCK IS ENGAGED
        else

            if simDR_gear_deploy_ratio[0] >= 0.5
                    and simDR_gear_deploy_ratio[1] >= 0.5
                    and simDR_gear_deploy_ratio[2] >= 0.5
                    and B747DR_gear_handle < 1.0
            then
                B747DR_gear_handle = 1.0        -- PREVENT MOVEMENT OF GEAR HANDLE TO 'UP' POSITION
            else
                B747DR_gear_handle = 0.0
                simDR_gear_handle_down = 1
            end

        end
    end
end]]






--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--

simCMD_landing_gear_up = replace_command("sim/flight_controls/landing_gear_up", B747CMD_gear_up_full_CMDhandler)
simCMD_landing_gear_down = replace_command("sim/flight_controls/landing_gear_down", B747CMD_gear_down_full_CMDhandler)
simCMD_landing_gear_down = replace_command("sim/flight_controls/landing_gear_off", B747CMD_gear_off_CMDhandler)
simCMD_landing_gear_toggle = replace_command("sim/flight_controls/landing_gear_toggle", sim_landing_gear_toggle_CMDhandler)

-- X-Plane's emergency gear extension: both ALTN GEAR EXTEND switches (the
-- manipulators' commands toggle them, so only those not pushed yet)
B747CMD_altn_nose_gear_extend = find_command("laminar/B747/button_switch/altn_nose_gear_extend")
B747CMD_altn_wing_gear_extend = find_command("laminar/B747/button_switch/altn_wing_gear_extend")
function sim_landing_gear_emer_on_CMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_gact_button[1] < 0.5 then B747CMD_altn_nose_gear_extend:once() end
        if B747DR_gact_button[2] < 0.5 then B747CMD_altn_wing_gear_extend:once() end
    end
end
simCMD_landing_gear_emer_on = replace_command("sim/flight_controls/landing_gear_emer_on", sim_landing_gear_emer_on_CMDhandler)

--B747CMD_gear_up_full      = deferred_command("laminar/B747/gear/overrideUp", "Gear Full Up", B747CMD_gear_up_full_CMDhandler)
--B747CMD_gear_down_full    = deferred_command("laminar/B747/gear/overrideDown", "Gear Full Down", B747CMD_gear_down_full_CMDhandler)
--B747CMD_gear_off      = deferred_command("laminar/B747/gear/overrideOff", "Gear Off", B747CMD_gear_off_CMDhandler)


--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

function B747_gear_lock_override_CMDhandler(phase, duration)

    if phase == 0 then
        B747_gear_handle_lock_override = 1
        B747DR_gear_lock_override_pos = 1
    elseif phase == 1 then
        B747_gear_handle_lock_override = 1
        B747DR_gear_lock_override_pos = 1
    elseif phase == 2 then
        B747_gear_handle_lock_override = 0
        B747DR_gear_lock_override_pos = 0
    end
end



-- AUTOBRAKES SELECTOR DIAL: the knob only; the autobrakes are the brakes'
-- glue (B747.10.xt.brakes.lua: the latch may move it back to DISARM or OFF)
function B747_autobrakes_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_autobrakes_sel_dial_pos = math.min(B747DR_autobrakes_sel_dial_pos+1, 7)
    end
end
function B747_autobrakes_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_autobrakes_sel_dial_pos = math.max(B747DR_autobrakes_sel_dial_pos-1, 0)
    end
end

-- AI
function B747_ai_gear_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
		B747_set_gear_all_modes()
		B747_set_gear_CD()
		B747_set_gear_ER()
	end
end







--*************************************************************************************--
--** 				                 CUSTOM COMMANDS                			     **--
--*************************************************************************************--

-- GEAR LOCK OVERRIDE
B747CMD_gear_lock_override      = deferred_command("laminar/B747/gear_lock/override", "Gear Lock Override", B747_gear_lock_override_CMDhandler)



-- AUTOBRAKES SELECTOR DIAL
B747CMD_autobrakes_sel_dial_up  = deferred_command("laminar/B747/gear/autobrakes/sel_dial_up", "Autobrakes Sel Dial Up", B747_autobrakes_sel_dial_up_CMDhandler)
B747CMD_autobrakes_sel_dial_dn  = deferred_command("laminar/B747/gear/autobrakes/sel_dial_dn", "Autobrakes Sel Dial Down", B747_autobrakes_sel_dial_dn_CMDhandler)


-- AI
B747CMD_ai_gear_quick_start			= deferred_command("laminar/B747/ai/gear_quick_start", "number", B747_ai_gear_quick_start_CMDhandler)



--*************************************************************************************--
--** 					            OBJECT CONSTRUCTORS         		    		 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				               CREATE SYSTEM OBJECTS            				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

----- ANIMATION UTILITY -----------------------------------------------------------------
function B747_set_animation_position(current_value, target, min, max, speed)

    local fps_factor = math.min(1.0, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end




----- RESCALE ---------------------------------------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end






----- SET GEAR HANDLE LOCK VALUE --------------------------------------------------------
-- The lock solenoid (28V DC bus 2) releases the lever when the PSEU's LG LVR
-- UNLK energises it (all four trucks tilted and the body gear steering
-- locked); LOCK OVRD releases it by hand (FCOM p.1512; ATA29_32 p.224-225;
-- locked without power: estimate). Published for the lever's handler in the
-- init script, which stops the lever at OFF.
function B747_set_gear_handle_lock()

    -- OVERRIDE LOCK BUTTON IS PRESSED
    if B747_gear_handle_lock_override == 1 then
        B747_gear_handle_lock = 0
    elseif B747DR_pseu_lever_unlock == 1 and B747DR_gact_bus_dc[1] > 0.5 then
        B747_gear_handle_lock = 0
    else
        B747_gear_handle_lock = 1
    end
    if B747DR_gear_lever_lock ~= B747_gear_handle_lock then B747DR_gear_lever_lock = B747_gear_handle_lock end

end











----- TIRE PRESSURE ---------------------------------------------------------------------
local initial_tire_Pressures={}
function B747_tire_pressure()

    math.randomseed(os.time())
    for i = 0, 17 do
        initial_tire_Pressures[i] = math.random(198, 210)
    end

    --[[

        B747-400 TPIS (TIRE PRESSURE INDICATING SYSTEM) CHANNEL ASSIGNMENT:

        -- WING LEFT
        1 = OUTBOARD/FRONT (DR INDEX = 0)
        2 = INBOARD/FRONT (DR INDEX = 1)
        3 = OUTBOARD/REAR (DR INDEX = 2)
        4 = INBOARD/REAR (DR INDEX = 3)

        -- BODY LEFT
        5 = OUTBOARD/FRONT (DR INDEX = 4)
        6 = INBOARD/FRONT (DR INDEX = 5)
        7 = OUTBOARD/REAR (DR INDEX = 6)
        8 = INBOARD/REAR (DR INDEX = 7)

        -- BODY RIGHT
        9 = INBOARD/FRONT (DR INDEX = 8)
        10 = OUTBOARD/FRONT (DR INDEX = 9)
        11 = INBOARD/REAR (DR INDEX = 10)
        12 = OUTBOARD/REAR (DR INDEX = 11)

        -- WING RIGHT
        13 = INBOARD/FRONT (DR INDEX = 12)
        14 = OUTBOARD/FRONT (DR INDEX = 13)
        15 = INBOARD/REAR (DR INDEX = 14)
        16 = OUTBOARD/REAR (DR INDEX = 15)

        -- NOSE
        17 = LEFT (DR INDEX = 16)
        18 = RIGHT (DR INDEX = 17)

    --]]
end

function B747_tire_pressures()

    for i = 0, 3 do
        target=initial_tire_Pressures[i]+simDR_aircraft_on_ground*10
        if simDR_tire5_fail==6 then
            target=5
        end
        B747DR_tire_pressure[i]=B747_animate_value(B747DR_tire_pressure[i],target,10,400,1)
    end
    for i = 4, 7 do
        target=initial_tire_Pressures[i]+simDR_aircraft_on_ground*10
        if simDR_tire3_fail==6 then
            target=5
        end
        B747DR_tire_pressure[i]=B747_animate_value(B747DR_tire_pressure[i],target,10,400,1)
    end
    for i = 8, 11 do
        target=initial_tire_Pressures[i]+simDR_aircraft_on_ground*10
        if simDR_tire2_fail==6 then
            target=5
        end
        B747DR_tire_pressure[i]=B747_animate_value(B747DR_tire_pressure[i],target,10,400,1)
    end
    for i = 12, 15 do
        target=initial_tire_Pressures[i]+simDR_aircraft_on_ground*10
        if simDR_tire4_fail==6 then
            target=5
        end
        B747DR_tire_pressure[i]=B747_animate_value(B747DR_tire_pressure[i],target,10,400,1)
    end
    for i = 16, 17 do
        target=initial_tire_Pressures[i]+simDR_aircraft_on_ground*10
        if simDR_tire1_fail==6 then
            target=5
        end
        B747DR_tire_pressure[i]=B747_animate_value(B747DR_tire_pressure[i],target,10,400,1)
    end
end



----- BRAKE TEMPERATURE -----------------------------------------------------------------
function B747_brake_temp_init()

    for i = 0, 17 do
        B747DR_brake_temp[i] = simDR_OAT_degC
    end

end

function fail_tire2()
    simDR_tire2_fail=6
end
function fail_tire3()
    simDR_tire3_fail=6

end
function fail_tire4()
    simDR_tire4_fail=6
end
function fail_tire5()
    simDR_tire5_fail=6
end

local excessiveBrakeTemp=0


function B747_brake_temp()

    -- DATAREF INDEXES SAME AS TIRE PRESSURE
    local brakingRatio_N = math.max(simDR_left_brake_ratio, simDR_right_brake_ratio, simDR_parking_brake_ratio)
    local brakingRatio_L = math.max(simDR_left_brake_ratio, simDR_parking_brake_ratio)
    local brakingRatio_R = math.max(simDR_right_brake_ratio, simDR_parking_brake_ratio)
    local tireSpeed = {}
    for i = 1, 5 do
        tireSpeed[i] = B747_rescale(0.0, 0.0, 200.0, 1.0, simDR_tire_rot_speed[i-1])
    end


    -- anot on the ground and back in time, quickly cool off the brakes to oat in a replay
    if simDR_inReplay==1 and simDR_aircraft_on_ground==0 then
        for i = 0, 17 do
            B747DR_brake_temp[i]=simDR_OAT_degC
        end
        return
    end
    -- BODY RIGHT GEAR
    if tireSpeed[2] > 0 and brakingRatio_R > 0 then
        local rate = brakingRatio_R * tireSpeed[2] * SIM_PERIOD * 130.0
        --print("rate=",rate)
        B747DR_brake_temp[8] = B747DR_brake_temp[8] + rate
        B747DR_brake_temp[9] = B747DR_brake_temp[8]
        B747DR_brake_temp[10] = B747DR_brake_temp[8]
        B747DR_brake_temp[11] = B747DR_brake_temp[8]
    else
        local rate = 1.8 * SIM_PERIOD
        B747DR_brake_temp[8] = math.max(B747DR_brake_temp[8] - rate, simDR_OAT_degC)
        B747DR_brake_temp[9] = B747DR_brake_temp[8]
        B747DR_brake_temp[10] = B747DR_brake_temp[8]
        B747DR_brake_temp[11] = B747DR_brake_temp[8]
    end

    -- BODY LEFT GEAR
    if tireSpeed[3] > 0 and brakingRatio_L > 0 then
        local rate = brakingRatio_L * tireSpeed[3] * SIM_PERIOD * 130.0
        B747DR_brake_temp[4] = B747DR_brake_temp[4] + rate
        --print("rate=",rate)
        B747DR_brake_temp[5] = B747DR_brake_temp[4]
        B747DR_brake_temp[6] = B747DR_brake_temp[4]
        B747DR_brake_temp[7] = B747DR_brake_temp[4]
    else
        local rate = 1.8 * SIM_PERIOD
        B747DR_brake_temp[4] = math.max(B747DR_brake_temp[4] - rate, simDR_OAT_degC)
        B747DR_brake_temp[5] = B747DR_brake_temp[4]
        B747DR_brake_temp[6] = B747DR_brake_temp[4]
        B747DR_brake_temp[7] = B747DR_brake_temp[4]
    end

    -- WING RIGHT GEAR
    if tireSpeed[4] > 0 and brakingRatio_R > 0 then
        local rate = brakingRatio_R * tireSpeed[4] * SIM_PERIOD * 130.0
        B747DR_brake_temp[12] = B747DR_brake_temp[12] + rate
        B747DR_brake_temp[13] = B747DR_brake_temp[12]
        B747DR_brake_temp[14] = B747DR_brake_temp[12]
        B747DR_brake_temp[15] = B747DR_brake_temp[12]
    else
        local rate = 1.8 * SIM_PERIOD
        B747DR_brake_temp[12] = math.max(B747DR_brake_temp[12] - rate, simDR_OAT_degC)
        B747DR_brake_temp[13] = B747DR_brake_temp[12]
        B747DR_brake_temp[14] = B747DR_brake_temp[12]
        B747DR_brake_temp[15] = B747DR_brake_temp[12]
    end

    -- WING LEFT GEAR

    if brakingRatio_L > 0 and tireSpeed[5] > 0 then
        local rate = brakingRatio_L * tireSpeed[5] * SIM_PERIOD * 130.0
        B747DR_brake_temp[0] = B747DR_brake_temp[0] + rate
        B747DR_brake_temp[1] = B747DR_brake_temp[0]
        B747DR_brake_temp[2] = B747DR_brake_temp[0]
        B747DR_brake_temp[3] = B747DR_brake_temp[0]

    else
        local rate = 1.8 * SIM_PERIOD
        B747DR_brake_temp[0] = math.max(B747DR_brake_temp[0] - rate, simDR_OAT_degC)
        B747DR_brake_temp[1] = B747DR_brake_temp[0]
        B747DR_brake_temp[2] = B747DR_brake_temp[0]
        B747DR_brake_temp[3] = B747DR_brake_temp[0]
    end
    if B747DR_brake_temp[0]>500 and is_timer_scheduled(fail_tire5) == false then
        run_after_time(fail_tire5, math.random(25, 45))
    end
    if B747DR_brake_temp[4]>500 and is_timer_scheduled(fail_tire3) == false then
        run_after_time(fail_tire3, math.random(25, 45))
    end
    if B747DR_brake_temp[8]>500 and is_timer_scheduled(fail_tire2) == false then
        run_after_time(fail_tire2, math.random(25, 45))
    end
    if B747DR_brake_temp[12]>500 and is_timer_scheduled(fail_tire4) == false then
        run_after_time(fail_tire4, math.random(25, 45))
    end
    --
    -- level 0 = to 100c
    -- level 5 = 482c
    -- level 9 = 864c
    excessiveBrakeTemp=0
  for i = 0, 17 do
    B747DR_brake_temp_ind[i]=math.floor(B747DR_brake_temp[i]/100)
    if B747DR_brake_temp[i]>482 then
        excessiveBrakeTemp=1
    end
  end



end








----- EICAS MESSAGES --------------------------------------------------------------------
-- BRAKE TEMP (the autobrakes' memo and AUTOBRAKES are the brakes' glue,
-- B747.10.xt.brakes.lua)
function B747_gear_EICAS_msg()
    if excessiveBrakeTemp == 1 then
        B747DR_CAS_advisory_status[46] = 1
    else
        B747DR_CAS_advisory_status[46] = 0
    end
end






----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_gear_monitor_AI()
    if B747DR_init_gear_CD == 1 then
        B747_set_gear_all_modes()
        B747_set_gear_CD()
        B747DR_init_gear_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_gear_all_modes()

	B747DR_init_gear_CD = 0
    B747DR_autobrakes_sel_dial_pos = 1                                                   -- INIT AUTOBRAKES TO "OFF
    simDR_autobrakes_switch = 1
    B747_tire_pressure()
    B747_brake_temp_init()

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_gear_CD()

  B747DR__gear_chocked=1.0

end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_gear_ER()

	--B747DR__gear_chocked=0.0

end





----- FLIGHT START ---------------------------------------------------------------------
function B747_flight_start_gear()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_gear_all_modes()


    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_gear_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_gear_ER()


    end

    -- the lever and the gear: the actuation's glue puts the lever where X-Plane
    -- has put the gear once its first 3 s are over (it raised an air start's gear before)
    runningGear = 0
    B747_gear_act_flight_start()
    B747_brakes_flight_start()

end







--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end

local flightInit=false
function flight_start()
    flightInit=false
end
function do_flight_start()

    B747_flight_start_gear()

end

--function flight_crash() end

--function before_physics() end
debug_gear     = deferred_dataref("laminar/B747/debug/gear", "number")
function after_physics()
     if debug_gear>0 then return end
     if flightInit==false then
        do_flight_start()
    end
    flightInit=true
    B747_pseu()
    B747_set_gear_handle_lock()
    B747_gear_act()
    B747_brakes()

    B747_gear_EICAS_msg()

    B747_brake_temp()
    B747_tire_pressures()
    runGear()
    B747_gear_monitor_AI()


end

--function after_replay() end
