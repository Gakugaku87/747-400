--[[
*****************************************************************************************
* Program Script Name	:	B747.45.fltCtrls
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
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED
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
function deferred_command(name,desc,realFunc)
	return replace_command(name,realFunc)
end
--replace deferred_dataref
function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end
local B747_rudder_trim_sel_dial_position_target = 0
local B747_aileron_trim_sel_dial_position_target = 0
B747_speedbrake_stop = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_stop", "number") --0
local B747_speedbrake_lever_pos_target = 0
local B747_wheels_on_ground = 1
B747_sb_manip_changed = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever_changed", "number")
simDR_radarAlt1           	= find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
B747DR_fmc_notifications            = find_dataref("laminar/B747/fms/notification")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_button_switch_position   = find_dataref("laminar/B747/button_switch/position")

B747DR_fuel_control_toggle_switch_pos   = find_dataref("laminar/B747/fuel/fuel_control/toggle_sw_pos")

B747DR_CAS_warning_status       = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status       = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status      = find_dataref("laminar/B747/CAS/advisory_status")

B747DR_airspeed_V1              = find_dataref("laminar/B747/airspeed/V1")
B747DR_parking_brake_ratio = find_dataref("laminar/B747/flt_ctrls/parking_brake_ratio")
B747DR_autobrakes_sel_dial_pos  = deferred_dataref("laminar/B747/gear/autobrakes/sel_dial_pos", "number")
B747DR_CAS_memo_status          = find_dataref("laminar/B747/CAS/memo_status")

-- crazytimtimtim
B747DR_IRS_dial_pos             = find_dataref("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos")
B747DR_ELEC_BATT                = find_dataref("sim/cockpit/electrical/battery_array_on")
-- crazytimtimtim end
--*************************************************************************************--
--** 				               FIND CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747CMD_yaw_damper_upr = find_command("laminar/B747/button_switch/yaw_damper_upr")
B747CMD_yaw_damper_lwr = find_command("laminar/B747/button_switch/yaw_damper_lwr")




--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_startup_running           = find_dataref("sim/operation/prefs/startup_running")

simDR_innerslats_ratio  	= find_dataref("sim/flightmodel2/controls/slat1_deploy_ratio")
simDR_outerslats_ratio  	= find_dataref("sim/flightmodel2/controls/slat2_deploy_ratio")
simDR_autoslats_ratio  		= find_dataref("sim/aircraft/parts/acf_slatEQ")
simDR_prop_mode                 = find_dataref("sim/cockpit2/engine/actuators/prop_mode")
simDR_all_wheels_on_ground      = find_dataref("sim/flightmodel/failures/onground_any")
B747DR_reverser_lockout            = deferred_dataref("laminar/B747/engines/reverser_lockout", "number")
simDR_speedbrake_ratio_control  = find_dataref("sim/cockpit2/controls/speedbrake_ratio")
simDR_flap_handle_deploy_ratio  = find_dataref("sim/cockpit2/controls/flap_handle_deploy_ratio")
simDR_flap_ratio_control        = find_dataref("sim/cockpit2/controls/flap_ratio")                      -- FLAP HANDLE
B747DR_flap_ratio               = deferred_dataref("laminar/B747/cablecontrols/flap_ratio", "number") -- USED FLAP HANDLE
B747DR_flap_deployed_ratio        = find_dataref("laminar/B747/gauges/indicators/flap_deployed_ratio")
B747DR_flap_deployed_ratio1        = deferred_dataref("laminar/B747/gauges/indicators/flap_deployed_ratio1", "number")
B747DR_flap_deployed_ratio2        = deferred_dataref("laminar/B747/gauges/indicators/flap_deployed_ratio2", "number")
B747DR_flap_deployed_ratio3        = deferred_dataref("laminar/B747/gauges/indicators/flap_deployed_ratio3", "number")
B747DR_flap_deployed_ratio4        = deferred_dataref("laminar/B747/gauges/indicators/flap_deployed_ratio4", "number")
B747DR_yaw_damper_upr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_upr_on", "number")
B747DR_yaw_damper_lwr_on             = deferred_dataref("laminar/B747/flt_ctrls/yaw_damper_lwr_on", "number")
simDR_flap_deploy_ratio         = find_dataref("laminar/B747/cablecontrols/flap_ratio")
simDR_yaw_damper_on             = find_dataref("sim/cockpit2/switches/yaw_damper_on")
simDR_gear_vert_defl            = find_dataref("sim/flightmodel2/gear/tire_vertical_deflection_mtr")
simDR_gear_deploy_ratio         = find_dataref("sim/flightmodel2/gear/deploy_ratio")
simDR_wing_flap1_deg            = find_dataref("sim/flightmodel2/wing/flap1_deg")
B747DR_airspeed_flapsRef        = find_dataref("laminar/B747/airspeed/flapsRef")
simDR_ind_airspeed_kts_pilot    = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")

B747DR_display_N1				= find_dataref("laminar/B747/engines/display_N1")
B747DR_display_N2				= find_dataref("laminar/B747/engines/display_N2")
simDR_radio_alt_height_capt     = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")

-- a body gear steering actuator unlocked: its lock switches (the gear module's steering, 4-2 step 4)
B747DR_body_steering_unlocked = find_dataref("laminar/B747/gear/steering/body_unlocked")
simDR_parking_brake_ratio       = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
simDR_elevator_trim             = find_dataref("sim/flightmodel2/controls/elevator_trim")
simDR_acf_weight_total_kg       = find_dataref("sim/flightmodel/weight/m_total")
simDR_flap_control_fail         = find_dataref("sim/operation/failures/rel_flap_act")

simDR_engine_throttle_jet_all   = find_dataref("sim/cockpit2/engine/actuators/throttle_jet_rev_ratio_all")

simDR_hyd_press_1_2             = find_dataref("laminar/B747/hydraulics/indicators/hydraulic_pressure_1_2_4")

simDR_cg_adjust					= find_dataref("sim/flightmodel/misc/cgz_ref_to_default")
--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--


B747DR_alt_flaps_sel_dial_pos   = deferred_dataref("laminar/B747/flt_ctrls/alt_flaps/sel_dial_pos", "number")
B747DR_rudder_trim_sel_dial_pos = deferred_dataref("laminar/B747/flt_ctrls/rudder_trim/sel_dial_pos", "number")
B747DR_rudder_trim_switch_pos   = deferred_dataref("laminar/B747/flt_ctrls/aileron_trim/switch_pos", "number")
B747DR_speedbrake_lever_pos     = deferred_dataref("laminar/B747/flt_ctrls/speedbrake/lever_pos", "number")
B747DR_flap_trans_status        = deferred_dataref("laminar/B747/flt_ctrls/flap/transition_status", "number")
B747DR_EICAS1_flap_display_status = deferred_dataref("laminar/B747/flt_ctrls/flaps/EICAS1_display_status", "number")
B747DR_elevator_trim_mid_ind    = deferred_dataref("laminar/B747/flt_ctrls/elevator_trim/mid/indicator", "number")
B747DR__gear_chocked           = deferred_dataref("laminar/B747/gear/chocked", "number")
B747DR_init_fltctrls_CD         = deferred_dataref("laminar/B747/fltctrls/init_CD", "number")
B747DR_engines_numClimb         = deferred_dataref("laminar/B747/flt_ctrls/numClimb", "number")
B747DR_engines_numLeverClimb    = deferred_dataref("laminar/B747/flt_ctrls/numLeverClimb", "number")
--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

----- SPEEDBRAKE HANDLE -----------------------------------------------------------------
B747DR_speedbrake_lever     	= deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever", "number")--uses change handler B747_speedbrake_lever_DRhandler in xlua
B747DR_speedbrake_lever_detent  = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever_detent", "number")
B747DR_speedbrake_auto_ext      = deferred_dataref("B747DR/speedbrake/auto_extend", "number")



----- FLAP HANDLE -----------------------------------------------------------------------
B747DR_flap_lever_detent		= deferred_dataref("laminar/B747/flt_ctrls/flap_lever_detent", "number")

--STAB TRIM setting
B747DR_elevator_trim				    = deferred_dataref("laminar/B747/fmc/elevator_trim", "number")


--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--

----- SPEEDBRAKE LEVER ------------------------------------------------------------------
function B747_speedbrake_manip_timeout()
	B747_sb_manip_changed = 0 
end

function B747_speedbrake_lever_DRhandler()
    -- Done in init/scripts

end




function B747_speedbrake_lever_detent_DRhandler() end



function B747_flap_lever_detent_DRhandler() end	









--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- ALTERNATE FLAPS
function B747_alt_flaps_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_alt_flaps_sel_dial_pos = math.min(B747DR_alt_flaps_sel_dial_pos+1, 1)
    end
end
function B747_alt_flaps_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_alt_flaps_sel_dial_pos = math.max(B747DR_alt_flaps_sel_dial_pos-1,-1)
    end
end




-- STABLIZER TRIM: the control wheel switch pairs go to the SRMs
-- (B747.45.xt.srm.lua, 4-1 step 2b) while held. The captain's also hold
-- X-Plane's pitch trim command, which the sound plays its click on; that
-- command is replaced below and counts as the captain's switches (a
-- joystick's trim buttons)
function B747_stablizer_trim_up_capt_CMDhandler(phase, duration)
    B747_srm_trim_switch("capt", 1, phase)
    if phase == 0 then simCMD_stablizer_trim_up:start() elseif phase == 2 then simCMD_stablizer_trim_up:stop() end
end

function B747_stablizer_trim_dn_capt_CMDhandler(phase, duration)
    B747_srm_trim_switch("capt", -1, phase)
    if phase == 0 then simCMD_stablizer_trim_dn:start() elseif phase == 2 then simCMD_stablizer_trim_dn:stop() end
end

function B747_stablizer_trim_up_fo_CMDhandler(phase, duration)
    B747_srm_trim_switch("fo", 1, phase)
end

function B747_stablizer_trim_dn_fo_CMDhandler(phase, duration)
    B747_srm_trim_switch("fo", -1, phase)
end

function B747_pitch_trim_up_CMDhandler(phase, duration)
    B747_srm_trim_switch("xp", 1, phase)
end

function B747_pitch_trim_dn_CMDhandler(phase, duration)
    B747_srm_trim_switch("xp", -1, phase)
end




function B747_ai_fltctrls_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
	  	B747_set_fltctrls_all_modes() 
	  	B747_set_fltctrls_CD()
	  	B747_set_fltctrls_ER()
	end	
end	





--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--


-- RUDDER TRIM
function sim_rudder_trim_left_beforeCMDhandler(phase, duration) end

function sim_rudder_trim_left_afterCMDhandler(phase, duration)
    if phase == 0 then
        B747_rudder_trim_sel_dial_position_target = -1
    elseif phase == 2 then
        B747_rudder_trim_sel_dial_position_target = 0
    end
end



function sim_rudder_trim_right_beforeCMDhandler(phase, duration) end

function sim_rudder_trim_right_afterCMDhandler(phase, duration)
    if phase == 0 then
        B747_rudder_trim_sel_dial_position_target = 1
    elseif phase == 2 then
        B747_rudder_trim_sel_dial_position_target = 0
    end
end





-- AILERON TRIM
function sim_aileron_trim_left_beforeCMDhandler(phase, duration) end

function sim_aileron_trim_left_afterCMDhandler(phase, duration)
    if phase == 0 then
        B747_aileron_trim_sel_dial_position_target = -1
    elseif phase == 2 then
        B747_aileron_trim_sel_dial_position_target = 0
    end
end



function sim_aileron_trim_right_beforeCMDhandler(phase, duration) end

function sim_aileron_trim_right_afterCMDhandler(phase, duration)
    if phase == 0 then
        B747_aileron_trim_sel_dial_position_target = 1
    elseif phase == 2 then
        B747_aileron_trim_sel_dial_position_target = 0
    end
end




function sim_yaw_damper_on_beforeCMDhandler(phase, duration) end
function sim_yaw_damper_on_afterCMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_button_switch_position[82] <= 0.05 then
            B747CMD_yaw_damper_upr:once()
            B747CMD_yaw_damper_lwr:once()
        end
    end
end

function sim_yaw_damper_off_beforeCMDhandler(phase, duration) end
function sim_yaw_damper_off_afterCMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_button_switch_position[82] >= 0.95 then
            B747CMD_yaw_damper_upr:once()
            B747CMD_yaw_damper_lwr:once()
        end
    end
end






-- SPEEDBRAKE LEVER
function sim_speedbrake_lever_extend_one_CMDhandler(phase, duration)
    if phase == 0 then

	    -- MOVE FROM DOWN TO ARM
		if B747DR_speedbrake_lever < 0.10 then
	   		B747DR_speedbrake_lever = 0.125
	    
	    -- MOVE FROM ARM TO FLIGHT DETENT
	    elseif B747DR_speedbrake_lever > 0.10 and B747DR_speedbrake_lever < 0.15 then
		    B747DR_speedbrake_lever = 0.53
	    
	    -- MOVE FROM FLIGHT DETENT TO UP
	    elseif B747DR_speedbrake_lever > 0.525 and B747DR_speedbrake_lever < 1.0 then
	    	B747DR_speedbrake_lever = 1.0
	    end
	    
	    B747_speedbrake_lever_DRhandler()

    end
end

function sim_speedbrake_lever_retract_one_CMDhandler(phase, duration)
    if phase == 0 then
	    
	    -- MOVE FROM UP TO FLIGHT DETENT
		if B747DR_speedbrake_lever > 0.53 then
	   		B747DR_speedbrake_lever = 0.53
	    
	    -- MOVE FROM FLIGHT DETENT TO ARM 
	    elseif B747DR_speedbrake_lever > 0.15 and B747DR_speedbrake_lever <= 0.53 then
		    B747DR_speedbrake_lever = 0.125
	    
	    -- MOVE FROM ARM DETENT TO DOWN
	    elseif B747DR_speedbrake_lever > 0.10 and B747DR_speedbrake_lever < 0.15 then
	    	B747DR_speedbrake_lever = 0.0
	    end
	    
	    B747_speedbrake_lever_DRhandler()
	    
    end
end




function sim_speedbrake_lever_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_speedbrake_lever = 1.0
        B747_speedbrake_lever_DRhandler()
    end
end

function sim_speedbrake_lever_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_speedbrake_lever = 0.0
        B747_speedbrake_lever_DRhandler()
    end
end




function sim_toggle_speedbrakes_CMDhandler(phase, duration)
	if phase == 0 then
		if B747DR_speedbrake_lever < 0.01 then 
			B747DR_speedbrake_lever = 1.0
		else		
	    	B747DR_speedbrake_lever = 0.0
	    end	
	    B747_speedbrake_lever_DRhandler()
	end    
end








--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--

-- RUDDER TRIM
simCMD_rudder_trim_left         = wrap_command("sim/flight_controls/rudder_trim_left", sim_rudder_trim_left_beforeCMDhandler, sim_rudder_trim_left_afterCMDhandler)
simCMD_rudder_trim_right        = wrap_command("sim/flight_controls/rudder_trim_right", sim_rudder_trim_right_beforeCMDhandler, sim_rudder_trim_right_afterCMDhandler)



-- AILERON TRIM
simCMD_aileron_trim_left        = wrap_command("sim/flight_controls/aileron_trim_left", sim_aileron_trim_left_beforeCMDhandler, sim_aileron_trim_left_afterCMDhandler)
simCMD_aileron_trim_right       = wrap_command("sim/flight_controls/aileron_trim_right", sim_aileron_trim_right_beforeCMDhandler, sim_aileron_trim_right_afterCMDhandler)


-- STABILIZER TRIM
simCMD_stablizer_trim_up        = replace_command("sim/flight_controls/pitch_trim_up", B747_pitch_trim_up_CMDhandler)
simCMD_stablizer_trim_dn        = replace_command("sim/flight_controls/pitch_trim_down", B747_pitch_trim_dn_CMDhandler)



-- YAW DAMPER
--simCMD_yaw_damper_on            = wrap_command("sim/systems/yaw_damper_on", sim_yaw_damper_on_beforeCMDhandler, sim_yaw_damper_on_afterCMDhandler)
--simCMD_yaw_damper_off           = wrap_command("sim/systems/yaw_damper_off", sim_yaw_damper_off_beforeCMDhandler, sim_yaw_damper_off_afterCMDhandler)
simCMD_yaw_damper_off = find_command("sim/systems/yaw_damper_off")



-- SPEEDBRAKES
simCMD_speedbrakes_extend_one   = replace_command("sim/flight_controls/speed_brakes_down_one", sim_speedbrake_lever_extend_one_CMDhandler)
simCMD_speedbrakes_retract_one  = replace_command("sim/flight_controls/speed_brakes_up_one", sim_speedbrake_lever_retract_one_CMDhandler)
simCMD_speedbrakes_extend_full  = replace_command("sim/flight_controls/speed_brakes_down_all", sim_speedbrake_lever_up_CMDhandler)
simCMD_speedbrakes_retract_full = replace_command("sim/flight_controls/speed_brakes_up_all", sim_speedbrake_lever_dn_CMDhandler)
simCMD_speedbrakes_toggle       = replace_command("sim/flight_controls/speed_brakes_toggle", sim_toggle_speedbrakes_CMDhandler)










--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- ALTERNATE FLAPS
B747CMD_alt_flaps_sel_dial_up           = deferred_command("laminar/B747/flt_ctrls/flaps/alt_flaps/sel_dial_up", "Alternate Flaps Selector Dial Up", B747_alt_flaps_sel_dial_up_CMDhandler)
B747CMD_alt_flaps_sel_dial_dn           = deferred_command("laminar/B747/flt_ctrls/flaps/alt_flaps/sel_dial_dn", "Alternate Flaps Selector Dial Down", B747_alt_flaps_sel_dial_dn_CMDhandler)


-- STABLIZER TRIM
B747CMD_stablizer_trim_up_capt          = deferred_command("laminar/B747/flt_ctrls/stab_trim_up_capt", "Stablizer Trim Up Captain", B747_stablizer_trim_up_capt_CMDhandler)
B747CMD_stablizer_trim_dn_capt          = deferred_command("laminar/B747/flt_ctrls/stab_trim_dn_capt", "Stablizer Trim Down Captain", B747_stablizer_trim_dn_capt_CMDhandler)

B747CMD_stablizer_trim_up_fo            = deferred_command("laminar/B747/flt_ctrls/stab_trim_up_fo", "Stablizer Trim Up First Officer", B747_stablizer_trim_up_fo_CMDhandler)
B747CMD_stablizer_trim_dn_fo            = deferred_command("laminar/B747/flt_ctrls/stab_trim_dn_fo", "Stablizer Trim Down First Officer", B747_stablizer_trim_dn_fo_CMDhandler)


-- AI
B747CMD_ai_fltctrls_quick_start			= deferred_command("laminar/B747/ai/fltctrls_quick_start", "number", B747_ai_fltctrls_quick_start_CMDhandler)



function B747CMD_parking_brake_on_CMDhandler(phase, duration)
	if phase == 0 then
	  B747DR_parking_brake_ratio=1.0
	end    
end
function B747CMD_parking_brake_off_CMDhandler(phase, duration)
	if phase == 0 then
	  B747DR_parking_brake_ratio=0.0
	end    
end
function B747CMD_parking_brake_toggle_CMDhandler(phase, duration)
	if phase == 0 then
	  B747DR_parking_brake_ratio=1.0-B747DR_parking_brake_ratio
	end    
end
B747CMD_parking_brake_on            = deferred_command("laminar/B747/flt_ctrls/parking_brake_on", "Parking brake on", B747CMD_parking_brake_on_CMDhandler)
B747CMD_parking_brake_off            = deferred_command("laminar/B747/flt_ctrls/parking_brake_off", "Parking brake off", B747CMD_parking_brake_off_CMDhandler)
B747CMD_parking_brake_toggle            = deferred_command("laminar/B747/flt_ctrls/parking_brake_toggle", "Parking brake toggle", B747CMD_parking_brake_toggle_CMDhandler)


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

    local fps_factor = math.min(0.1, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end





----- RESCALE FLOAT AND CLAMP TO OUTER LIMITS -------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end





----- RUDDER TRIM DIAL POSITION ANIMATION --------------------------------------------
function B747_rudder_trim_dial_animation()

    B747DR_rudder_trim_sel_dial_pos = B747_set_animation_position(B747DR_rudder_trim_sel_dial_pos, B747_rudder_trim_sel_dial_position_target, -1.0, 1.0, 10.0)

end




----- AILERON TRIM SWITCH POSITION ANIMATION --------------------------------------------
function B747_aileron_trim_switch_animation()

    B747DR_rudder_trim_switch_pos = B747_set_animation_position(B747DR_rudder_trim_switch_pos, B747_aileron_trim_sel_dial_position_target, -1.0, 1.0, 10.0)

end




--[[
----- SPEEDBRAKE LEVER POSITION ANIMATION -----------------------------------------------
function B747_speedbrake_lever_animation()

    B747DR_speedbrake_lever_pos = B747_set_animation_position(B747DR_speedbrake_lever_pos, B747_speedbrake_lever_pos_target, 0.0, 1.0, 10.0)

end--]]





----- SPEEDBRAKE LEVER STOP -------------------------------------------------------------
function B747_speedbrake_lever_stop()

    if simDR_all_wheels_on_ground < 1 and simDR_radarAlt1>15 then
        B747_speedbrake_stop = 1
        B747DR__gear_chocked=0
    else
		B747_speedbrake_stop = 0	        
    end

end






----- SPEEDBRAKES -----------------------------------------------------------------------
-- the auto speedbrake, X-Plane's ratio and the speedbrake messages: the
-- speedbrake model (B747.45.xt.speedbrake.lua, 4-1 step 3)




----- YAW DAMPER ------------------------------------------------------------------------
-- the yaw damper modules' modes, engagement and INOP (laminar/B747/
-- flt_ctrls/yaw_damper_upr_on, lwr_on, read for >YAW DAMPER UPR, LWR
-- below): the yaw damper model in the hydraulics module
-- (B747.19.yd_model.lua, 6-3 step 6a; before, here: 4-1 step 4)
function B747_yaw_damper()
    if  simDR_yaw_damper_on == 1
    then
        simCMD_yaw_damper_off:once()                -- X-Plane's own yaw damper stays off
    end
end


function B747_flap_move_to_slot()
    
    
    if simDR_flap_ratio_control<=0.0835 then --flaps up
	    simDR_flap_ratio_control=0
    elseif simDR_flap_ratio_control<=0.25 then --flaps 1
	    simDR_flap_ratio_control= 0.167
    elseif simDR_flap_ratio_control<=0.4165 then --flaps 5
	    simDR_flap_ratio_control= 0.333
    elseif simDR_flap_ratio_control<=0.5835 then --flaps 10
	    simDR_flap_ratio_control= 0.5
    elseif simDR_flap_ratio_control<=0.7505 then --flaps 20
	    simDR_flap_ratio_control= 0.667
    elseif simDR_flap_ratio_control<=0.9165 then --flaps 25
	    simDR_flap_ratio_control= 0.833
    else --flaps 30
	    simDR_flap_ratio_control = 1.0
    end

end

function FlapinSlot()
  if simDR_flap_ratio_control<0.001 then --flaps 0

	   return true
    elseif simDR_flap_ratio_control>0.166 and simDR_flap_ratio_control<0.168 then --flaps 1 

      simDR_flap_ratio_control= 0.167
	    return true
    elseif simDR_flap_ratio_control>0.332 and simDR_flap_ratio_control<0.334 then --flaps 5
      simDR_flap_ratio_control= 0.333

	    return true
    elseif simDR_flap_ratio_control>0.499 and simDR_flap_ratio_control<0.501 then --flaps 10
      simDR_flap_ratio_control= 0.5

	    return true
    elseif simDR_flap_ratio_control>0.666 and simDR_flap_ratio_control<0.668 then --flaps 20
     simDR_flap_ratio_control= 0.667

	    return true
    elseif simDR_flap_ratio_control>0.832 and simDR_flap_ratio_control<0.834 then --flaps 25
      simDR_flap_ratio_control= 0.833

	   return true
    elseif simDR_flap_ratio_control>0.999 then --flaps 30
      simDR_flap_ratio_control = 1.0

	   return true
    end
    --print("flap not in slot")
    return false
end
local last_flap_handle=-1
----- FLAP LEVER ------------------------------------------------------------------------
-- the flaps themselves, their load relief and indication: the flap control
-- units (B747.45.xt.fcu.lua)
function B747_flap_transition_status()
    if last_flap_handle~=simDR_flap_ratio_control then
      -- the lever moved: snap it to the nearest detent 2 s after it stops
      if is_timer_scheduled(B747_flap_move_to_slot) then
	      stop_timer(B747_flap_move_to_slot)
      end
      run_after_time(B747_flap_move_to_slot, 2.0)
    end
    
    last_flap_handle=simDR_flap_ratio_control
    if FlapinSlot()==false then 
      B747DR_flap_lever_detent = 0.006 
    else
      --print("flap in slot")
       B747DR_flap_lever_detent = 0.0
    end
end


----- PRIMARY EICAS FLAP DISPLAY STATUS -------------------------------------------------
-- the flap control units' (B747.45.xt.fcu.lua)




----- ELEVATOR TRIM ---------------------------------------------------------------------
-- the takeoff greenband (B747.45.greenband_model.lua, 4-1 step 2c): the band
-- the MAWEA selects (from the FMC's takeoff trim), lit on the ground until
-- V1, otherwise the painted mid band; CONFIG STAB compares with the selected
-- band. Before, one band of FMC trim +-2.25 units slid with the trim
B747_greenband_sel = 1
function B747_elevator_trim()
    local G = B747_greenband_model
    local band = G.select(tonumber(B747DR_elevator_trim) or 0)
    B747_greenband_sel = band
    local lit = B747DR_fcu_pri_gnd == 1
        and (B747DR_airspeed_V1 <= 0 or simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1)
    local ind = G.indicator(band, lit)
    if B747DR_elevator_trim_mid_ind ~= ind then B747DR_elevator_trim_mid_ind = ind end
end






----- EICAS MESSAGES --------------------------------------------------------------------
function B747_animate_value(current_value, target, min, max, speed)

    local fps_factor = math.min(0.1, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end

function setNumClimb()
    B747DR_engines_numClimb = 0
    if B747DR_display_N1[0] > 90.0 then B747DR_engines_numClimb = B747DR_engines_numClimb + 1 end
    if B747DR_display_N1[1] > 90.0 then B747DR_engines_numClimb = B747DR_engines_numClimb + 1 end
    if B747DR_display_N1[2] > 90.0 then B747DR_engines_numClimb = B747DR_engines_numClimb + 1 end
    if B747DR_display_N1[3] > 90.0 then B747DR_engines_numClimb = B747DR_engines_numClimb + 1 end

    -- thrust levers at climb thrust or beyond: the EEC's climb rating lever
    -- angle, 35 of 50 degrees (ATA70_80 p.208; as the switch point for
    -- CONFIG SPOILERS in flight, an estimate)
    local n = 0
    for i = 0, 3 do
        if B747DR_sb_thrust_lever[i] >= 35 / 50 then n = n + 1 end
    end
    B747DR_engines_numLeverClimb = n
end




function B747_fltCtrols_EICAS_msg()
    
    -- FUEL CONTROL SWITCH STATUS
    local num_fuel_ctrl_sw_on = 0
    for i = 0, 3 do
        if B747DR_fuel_control_toggle_switch_pos[i] > 0.95 then
            num_fuel_ctrl_sw_on = num_fuel_ctrl_sw_on + 1
        end
    end

    -- THRUST LEVER CLOSED: any one (FCOM p.1603)
    local any_thrust_lever_closed = 0
    for i = 0, 3 do
        if B747DR_sb_thrust_lever[i] < 0.05 then any_thrust_lever_closed = 1 end
    end

    -- >CONFIG FLAPS
    local thRef=96
    local unmatchedConfig=false
    if B747DR_airspeed_flapsRef>0 then
        if simDR_wing_flap1_deg[0]>B747DR_airspeed_flapsRef+0.05 or simDR_wing_flap1_deg[0]<B747DR_airspeed_flapsRef-0.05 then
            unmatchedConfig=true
        end
        thRef=86
    end
    

    if (simDR_wing_flap1_deg[0] < 9.95 or simDR_wing_flap1_deg[0] > 20.05 or unmatchedConfig==true)
        and simDR_all_wheels_on_ground == 1
        and simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1
        and num_fuel_ctrl_sw_on >= 3
        and simDR_engine_throttle_jet_all >= 0
        and B747DR_display_N1[1] > thRef and B747DR_display_N1[2] > thRef
    then
        B747DR_CAS_warning_status[2] = 1
    else
	B747DR_CAS_warning_status[2] = 0
    end

    -- >CONFIG GEAR CTR: the body gear not centred (the actuators' lock
    -- switches), engine 2 or 3 in the takeoff range (FCOM p.1603)
    if B747DR_body_steering_unlocked == 1
        and simDR_all_wheels_on_ground == 1
        and simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1
        and num_fuel_ctrl_sw_on >= 3
        and simDR_engine_throttle_jet_all >= 0
        and (B747DR_display_N1[1] > thRef or B747DR_display_N1[2] > thRef)
    then
        B747DR_CAS_warning_status[4] = 1
    else
	    B747DR_CAS_warning_status[4] = 0
    end

    -- >CONFIG GEAR; the GND PROX CONFIG GR OVRD switch inhibits it (FCOM
    -- p.1538, ATA34_2 p.207)
    if B747DR_button_switch_position[5] < 0.5 and ((simDR_gear_deploy_ratio[0] < 0.99
        or simDR_gear_deploy_ratio[1] < 0.99
        or simDR_gear_deploy_ratio[2] < 0.99
        or simDR_gear_deploy_ratio[3] < 0.99
        or simDR_gear_deploy_ratio[4] < 0.99)

        and

        ((simDR_radio_alt_height_capt < 800.0 and any_thrust_lever_closed == 1)
        or
        math.min(B747DR_fcu_te_deg[0], B747DR_fcu_te_deg[1], B747DR_fcu_te_deg[2], B747DR_fcu_te_deg[3]) >= 21))   -- flaps 25 (22 degrees) or 30

    then
        B747DR_CAS_warning_status[3] = 1
    else
	B747DR_CAS_warning_status[3] = 0
    end

    -- >CONFIG PARK BRK: the parking brake lever set (the parking brake
    -- itself is the gear module's: B747.10.xt.brakes.lua) on the ground below
    -- V1 with three fuel control switches at RUN and engine 2 or 3 in the
    -- takeoff range (FCOM p.1557, p.1603; N1 above 90 % as before: estimate)
    if B747DR_parking_brake_ratio > 0.9
        and simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1
        and num_fuel_ctrl_sw_on >= 3
        and (B747DR_display_N1[1] > 90.0 or B747DR_display_N1[2] > 90.0)
        and simDR_engine_throttle_jet_all >= 0
        and simDR_all_wheels_on_ground == 1
    then
        B747DR_CAS_warning_status[5] = 1
    else
        B747DR_CAS_warning_status[5] = 0
    end

    -- >CONFIG SPOILERS: the takeoff configuration warning (the conditions as
    -- before, WARN-11); in flight on the 405 and 570 only, the lever beyond
    -- ARM with climb thrust or more on two or more thrust levers, until it is
    -- at ARM or DN or three are below climb thrust (FCOM p.1558; the 109 has
    -- >SPEEDBRAKES EXT only, B747.45.xt.speedbrake.lua)
    if (B747DR_speedbrake_lever >0.01 --< 0.99
        and simDR_all_wheels_on_ground == 1
        and simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1
        and num_fuel_ctrl_sw_on >= 3
        and B747DR_display_N1[1] > 90.0
        and B747DR_display_N1[2] > 90.0
        and simDR_engine_throttle_jet_all >= 0)
        or (B747DR_sb_freighter == 1 and B747DR_fcu_pri_gnd ~= 1
        and B747DR_speedbrake_lever > B747_speedbrake_model.ABOVE_ARM
        and B747DR_engines_numLeverClimb >= 2)
    then
        B747DR_CAS_warning_status[6] = 1
    else
        B747DR_CAS_warning_status[6] = 0
    end

    -- >CONFIG STAB: the stabilizer out of the selected greenband (ATA27
    -- p.729-730; the thrust and other conditions as before, WARN-11)
    local curTrim   = B747_rescale(-1.0, 0.0, 1.0, 15.0, simDR_elevator_trim)
    if not B747_greenband_model.within(B747_greenband_sel, curTrim)
        and simDR_all_wheels_on_ground == 1
        and simDR_ind_airspeed_kts_pilot < B747DR_airspeed_V1
        and num_fuel_ctrl_sw_on >= 3
        and B747DR_display_N1[1] > 90.0
        and B747DR_display_N1[2] > 90.0
        and simDR_engine_throttle_jet_all >= 0
    then
        B747DR_CAS_warning_status[7] = 1
    else
       B747DR_CAS_warning_status[7] = 0
    end

    -- FLAPS CONTROL, FLAPS DRIVE, FLAPS PRIMARY, >FLAP RELIEF: the flap
    -- control units (B747.45.xt.fcu.lua)

    -- >SPEEDBRAKES EXT: the speedbrake model (B747.45.xt.speedbrake.lua)

    -- >YAW DAMPER LWR
    
    if B747DR_yaw_damper_lwr_on==0 then 
      B747DR_CAS_advisory_status[300] = 1
    else
      B747DR_CAS_advisory_status[300] = 0
    end

    -- >YAW DAMPER UPR

    if B747DR_yaw_damper_upr_on==0 then
      B747DR_CAS_advisory_status[301] = 1
    else
      B747DR_CAS_advisory_status[301] = 0
    end
end









----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_fltctrls_monitor_AI()

    if B747DR_init_fltctrls_CD == 1 then
        B747_set_fltctrls_all_modes()
        B747_set_fltctrls_CD()
        B747DR_init_fltctrls_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_fltctrls_all_modes()
	
	B747DR_init_fltctrls_CD = 0
	run_after_time(B747_flight_start_deferred, 2.0)
	

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_fltctrls_CD()

    --B747DR_speedbrake_lever = 1.0
    --B747_speedbrake_lever_DRhandler()


    simDR_elevator_trim = 0

end




----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_fltctrls_ER()
  if simDR_all_wheels_on_ground == 1 then
	B747DR_parking_brake_ratio=1
  end
	
end







----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_fltCtrls()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_fltctrls_all_modes()
	

    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_fltctrls_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then
	    
		B747_set_fltctrls_ER()

    end

end





----- DEFERRED INIT ---------------------------------------------------------------------
function B747_flight_start_deferred()

    --B747_init_gear_check_flag()                                                             -- REQUIRED BECAUSE "sim/flightmodel/failures/onground_all" IS NOT VALID AT LOAD
    --B747_elevator_trim()  --moved to after_physics loop
    
end





-- the flap control units, the SRMs, the takeoff greenband and the speedbrakes (4-1)
dofile("B747.45.xt.fcu.lua")
dofile("B747.45.xt.srm.lua")
dofile("B747.45.greenband_model.lua")
dofile("B747.45.xt.speedbrake.lua")

--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end

local flightInit=false
function flight_start()
    flightInit=false
    B747_fcu_flight_start()
    B747_srm_flight_start()
    B747_speedbrake_flight_start()
end
function do_flight_start()

    B747_flight_start_fltCtrls()

end

--function flight_crash() end

--function before_physics() end
debug_fltctrls     = deferred_dataref("laminar/B747/debug/fltctrls", "number")
function after_physics()
    if debug_fltctrls>0 then return end
    if flightInit==false then
        do_flight_start()
    end
    flightInit=true
    B747_rudder_trim_dial_animation()
    B747_aileron_trim_switch_animation()

    B747_speedbrake_lever_stop()
    B747_speedbrake()
    --B747_speedbrake_lever_animation()
    --B747_speedbrake()

    B747_yaw_damper()

    B747_flap_transition_status()
    B747_fcu()
    B747_srm()

    B747_fltCtrols_EICAS_msg()

    B747_fltctrls_monitor_AI()

    --print(collectgarbage("count")*1024)
	
    --Marauder28
    B747_elevator_trim()  --constantly update the safe stab trim position based on CG   
	
    -- the autobrakes, DISARM on the ground included, are the gear module's (B747.10.xt.brakes.lua)
	
    setNumClimb()
	
end

--function after_replay() end



