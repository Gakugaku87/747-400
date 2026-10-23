--[[
*****************************************************************************************
* Program Script Name	:	B747.55.air
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
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	    *
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
B747bleedAir            = {}

B747bleedAir.engine1    = {}
B747bleedAir.engine2    = {}
B747bleedAir.engine3    = {}
B747bleedAir.engine4    = {}
B747bleedAir.apu        = {}
B747bleedAir.grnd_cart  = {}

B747bleedAir.engine1.psi    = deferred_dataref("laminar/B747/air/engine1/bleed_air_psi", "number")
B747bleedAir.engine2.psi    = deferred_dataref("laminar/B747/air/engine2/bleed_air_psi", "number")
B747bleedAir.engine3.psi    = deferred_dataref("laminar/B747/air/engine3/bleed_air_psi", "number")
B747bleedAir.engine4.psi    = deferred_dataref("laminar/B747/air/engine4/bleed_air_psi", "number")
B747bleedAir.apu.psi        = 0
B747bleedAir.grnd_cart.psi  =   0

B747bleedAir.engine1.bleed_air_valve        = {}
B747bleedAir.engine2.bleed_air_valve        = {}
B747bleedAir.engine3.bleed_air_valve        = {}
B747bleedAir.engine4.bleed_air_valve        = {}
B747bleedAir.engine1.bleed_air_start_valve  = {}
B747bleedAir.engine2.bleed_air_start_valve  = {}
B747bleedAir.engine3.bleed_air_start_valve  = {}
B747bleedAir.engine4.bleed_air_start_valve  = {}
B747bleedAir.apu.bleed_air_valve            = {}
B747bleedAir.isolation_valve_L              = {}
B747bleedAir.isolation_valve_R              = {}

B747bleedAir.engine1.bleed_air_valve.target_pos = 0.0
B747bleedAir.engine2.bleed_air_valve.target_pos = 0.0
B747bleedAir.engine3.bleed_air_valve.target_pos = 0.0
B747bleedAir.engine4.bleed_air_valve.target_pos = 0.0
B747bleedAir.engine1.bleed_air_start_valve.target_pos = 0.0
B747bleedAir.engine2.bleed_air_start_valve.target_pos = 0.0
B747bleedAir.engine3.bleed_air_start_valve.target_pos = 0.0
B747bleedAir.engine4.bleed_air_start_valve.target_pos = 0.0
B747bleedAir.apu.bleed_air_valve.target_pos     = 0.0
B747bleedAir.isolation_valve_L.target_pos       = 0.0
B747bleedAir.isolation_valve_R.target_pos       = 0.0

B747bleedAir.engine1.bleed_air_valve.pos        = deferred_dataref("laminar/B747/air/engine1/bleed_valve_pos", "number")
B747bleedAir.engine2.bleed_air_valve.pos        = deferred_dataref("laminar/B747/air/engine2/bleed_valve_pos", "number")
B747bleedAir.engine3.bleed_air_valve.pos        = deferred_dataref("laminar/B747/air/engine3/bleed_valve_pos", "number")
B747bleedAir.engine4.bleed_air_valve.pos        = deferred_dataref("laminar/B747/air/engine4/bleed_valve_pos", "number")
B747bleedAir.engine1.bleed_air_start_valve.pos  = deferred_dataref("laminar/B747/air/engine1/bleed_start_valve_pos", "number")
B747bleedAir.engine2.bleed_air_start_valve.pos  = deferred_dataref("laminar/B747/air/engine2/bleed_start_valve_pos", "number")
B747bleedAir.engine3.bleed_air_start_valve.pos  = deferred_dataref("laminar/B747/air/engine3/bleed_start_valve_pos", "number")
B747bleedAir.engine4.bleed_air_start_valve.pos  = deferred_dataref("laminar/B747/air/engine4/bleed_start_valve_pos", "number")
B747bleedAir.apu.bleed_air_valve.pos            = deferred_dataref("laminar/B747/air/apu/bleed_valve_pos", "number")
B747bleedAir.isolation_valve_L.pos              = deferred_dataref("laminar/B747/air/isolation_valve_L_pos", "number")
B747bleedAir.isolation_valve_R.pos              = deferred_dataref("laminar/B747/air/isolation_valve_R_pos", "number")
simDR_isolation_valve_L            = deferred_dataref("sim/cockpit2/bleedair/actuators/isol_valve_left", "number")
simDR_isolation_valve_R              = deferred_dataref("sim/cockpit2/bleedair/actuators/isol_valve_right", "number")




--*************************************************************************************--
--** 					            LOCAL VARIABLES                 				 **--
--*************************************************************************************--





--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")

simDR_bleed_air_mode                = find_dataref("sim/cockpit2/pressurization/actuators/bleed_air_mode")

simDR_elec_bus_volts                = find_dataref("sim/cockpit2/electrical/bus_volts")

simDR_indicated_altitude_pilot      = find_dataref("sim/cockpit2/gauges/indicators/altitude_ft_pilot")
simDR_indicated_vvi_fpm_pilot       = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")

--simDR_apu_running                   = find_dataref("sim/cockpit2/electrical/APU_running")
simDR_apu_N1_pct                    = find_dataref("sim/cockpit2/electrical/APU_N1_percent")
simDR_engine_running                = find_dataref("sim/flightmodel/engine/ENGN_running")
B747DR_display_N1				= find_dataref("laminar/B747/engines/display_N1")
B747DR_display_N2				= find_dataref("laminar/B747/engines/display_N2")






--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_button_switch_position           = find_dataref("laminar/B747/button_switch/position")
B747DR_toggle_switch_position           = find_dataref("laminar/B747/toggle_switch/position")
B747DR_fuel_control_toggle_switch_pos   = find_dataref("laminar/B747/fuel/fuel_control/toggle_sw_pos")
B747DR_dsp_synoptic_display             = find_dataref("laminar/B747/dsp/synoptic_display")

B747DR_CAS_warning_status               = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status               = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status              = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_memo_status                  = find_dataref("laminar/B747/CAS/memo_status")



--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_cabin_alt_auto_sel_pos       = deferred_dataref("laminar/B747/air/cabin_alt_auto/sel_dial_pos", "number")
B747DR_equip_cooling_sel_pos        = deferred_dataref("laminar/B747/air/equip_cooling/sel_dial_pos", "number")
B747DR_equip_cooling_state        = deferred_dataref("laminar/B747/air/equip_cooling/state", "number")
B747DR_pack_ctrl_sel_pos            = deferred_dataref("laminar/B747/air/pack_ctrl/sel_dial_pos", "array[3]")
B747DR_landing_alt_button_pos       = deferred_dataref("laminar/B747/air/landing_alt/button_pos", "number")

B747DR_outflow_valve_pos_L          = deferred_dataref("laminar/B747/air/outflow_valve_left/pos", "number")
B747DR_outflow_valve_pos_R          = deferred_dataref("laminar/B747/air/outflow_valve_right/pos", "number")

B747DR_landing_altitude             = deferred_dataref("laminar/B747/air/landing_altitude", "number")

B747_duct_pressure_L                = find_dataref("laminar/B747/air/duct_pressure_L")
B747_duct_pressure_C                = find_dataref("laminar/B747/air/duct_pressure_C")
B747_duct_pressure_R                = find_dataref("laminar/B747/air/duct_pressure_R")

B747DR_pressure_EICAS1_display_status = deferred_dataref("laminar/B747/air/pressurization/EICAS1_display_status", "number")

B747DR_init_air_CD                  = deferred_dataref("laminar/B747/air/init_CD", "number")



--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--






--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

-- LANDING ALTITUDE SELECTOR
B747DR_landing_alt_sel_rheo     = deferred_dataref("laminar/B747/air/land_alt_sel/rheostat", "number")


-- PASSENGER TEMP CONTROL
B747DR_pass_temp_ctrl__rheo     = deferred_dataref("laminar/B747/air/pass_temp_ctrl/rheostat", "number")


-- FLIGHT DECK TEMP CONTROL
B747DR_flt_deck_temp_ctrl_rheo  = deferred_dataref("laminar/B747/air/flt_deck_temp_ctrl/rheostat", "number")


-- CARGO TEMP CONTROL
B747DR_cargo_temp_ctrl_rheo     = deferred_dataref("laminar/B747/air/cargo_temp_ctrl/rheostat", "number")





--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- CABIN ALTITUDE AUTO SELECTOR
function B747_cabin_alt_auto_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_cabin_alt_auto_sel_pos = math.min(B747DR_cabin_alt_auto_sel_pos+1, 2)
    end
end
function B747_cabin_alt_auto_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_cabin_alt_auto_sel_pos = math.max(B747DR_cabin_alt_auto_sel_pos-1, 0)
    end
end




-- EQUIPMENT COOLING SELECTOR
function B747_equip_cooling_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_equip_cooling_sel_pos = math.min(B747DR_equip_cooling_sel_pos+1, 2)
    end
end
function B747_equip_cooling_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_equip_cooling_sel_pos = math.max(B747DR_equip_cooling_sel_pos-1, 0)
    end
end




-- PACK CONTROL SELECTOR 01
function B747_pack_ctrl_sel_01_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[0] = math.min(B747DR_pack_ctrl_sel_pos[0]+1, 3)
    end
end
function B747_pack_ctrl_sel_01_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[0] = math.max(B747DR_pack_ctrl_sel_pos[0]-1, 0)
    end
end



-- PACK CONTROL SELECTOR 02
function B747_pack_ctrl_sel_02_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[1] = math.min(B747DR_pack_ctrl_sel_pos[1]+1, 3)
    end
end
function B747_pack_ctrl_sel_02_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[1] = math.max(B747DR_pack_ctrl_sel_pos[1]-1, 0)
    end
end



-- PACK CONTROL SELECTOR 03
function B747_pack_ctrl_sel_03_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[2] = math.min(B747DR_pack_ctrl_sel_pos[2]+1, 3)
    end
end
function B747_pack_ctrl_sel_03_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_pack_ctrl_sel_pos[2] = math.max(B747DR_pack_ctrl_sel_pos[2]-1, 0)
    end
end




-- LANDING ALTITUDE BUTTON
function B747_landing_alt_button_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_landing_alt_button_pos = 1.0 - B747DR_landing_alt_button_pos
    end
end




function B747_ai_air_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
		B747_set_air_all_modes()
		B747_set_air_CD()
		B747_set_air_ER()	        
    end	
end	




--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- CABIN ALTITUDE AUTO SELECTOR
B747CMD_cabin_alt_auto_sel_up = deferred_command("laminar/B747/air/cabin_alt_auto/sel_dial_up", "Cabin Altitude Selector Dial Up", B747_cabin_alt_auto_sel_up_CMDhandler)
B747CMD_cabin_alt_auto_sel_dn = deferred_command("laminar/B747/air/cabin_alt_auto/sel_dial_dn", "Cabin Altitude Selector Dial Down", B747_cabin_alt_auto_sel_dn_CMDhandler)



-- EQUIPMENT COOLING SELECTOR
B747CMD_equip_cooling_sel_up = deferred_command("laminar/B747/air/equip_cooling/sel_dial_up", "Equipment Coooling Selector Dial Up", B747_equip_cooling_sel_up_CMDhandler)
B747CMD_equip_cooling_sel_dn = deferred_command("laminar/B747/air/equip_cooling/sel_dial_dn", "Equipment Coooling Selector Dial Down", B747_equip_cooling_sel_dn_CMDhandler)



-- PACK CONTROL SELECTOR
B747CMD_pack_ctrl_sel_01_up = deferred_command("laminar/B747/air/pack_ctrl_01/sel_dial_up", "Equipment Coooling Selector 1 Dial Up", B747_pack_ctrl_sel_01_up_CMDhandler)
B747CMD_pack_ctrl_sel_01_dn = deferred_command("laminar/B747/air/pack_ctrl_01/sel_dial_dn", "Equipment Coooling Selector 1 Dial Down", B747_pack_ctrl_sel_01_dn_CMDhandler)

B747CMD_pack_ctrl_sel_02_up = deferred_command("laminar/B747/air/pack_ctrl_02/sel_dial_up", "Equipment Coooling Selector 2 Dial Up", B747_pack_ctrl_sel_02_up_CMDhandler)
B747CMD_pack_ctrl_sel_02_dn = deferred_command("laminar/B747/air/pack_ctrl_02/sel_dial_dn", "Equipment Coooling Selector 2 Dial Down", B747_pack_ctrl_sel_02_dn_CMDhandler)

B747CMD_pack_ctrl_sel_03_up = deferred_command("laminar/B747/air/pack_ctrl_03/sel_dial_up", "Equipment Coooling Selector 3 Dial Up", B747_pack_ctrl_sel_03_up_CMDhandler)
B747CMD_pack_ctrl_sel_03_dn = deferred_command("laminar/B747/air/pack_ctrl_03/sel_dial_dn", "Equipment Coooling Selector 3 Dial Down", B747_pack_ctrl_sel_03_dn_CMDhandler)


-- LANDING ALTITUDE SWITCH
B747CMD_landing_alt_button = deferred_command("laminar/B747/air/landing_alt/button", "Landing Altitude Button", B747_landing_alt_button_CMDhandler)


-- AI
B747CMD_ai_air_quick_start = deferred_command("laminar/B747/ai/air_quick_start", "number", B747_ai_air_quick_start_CMDhandler)




--*************************************************************************************--
--** 					            OBJECT CONSTRUCTORS         		    		 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				               CREATE SYSTEM OBJECTS            				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

----- TERNARY CONDITIONAL ---------------------------------------------------------------
function B747_ternary(condition, ifTrue, ifFalse)
    if condition then return ifTrue else return ifFalse end
end



----- RESCALE ---------------------------------------------------------------------------
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end



----- ANIMATION UTILITY -----------------------------------------------------------------
function B747_set_anim_value(current_value, target, min, max, speed)

    local fps_factor = math.min(1.0, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end





B747DR_engine01_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine01/ext_switch/pos_arm", "number")
B747DR_engine02_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine02/ext_switch/pos_arm", "number")
B747DR_engine03_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine03/ext_switch/pos_arm", "number")
B747DR_engine04_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine04/ext_switch/pos_arm", "number") 


-- the bleed air: the model and its glue (notes/ATA-36.md), after the bindings
dofile("B747.55.xt.bleed.lua")
-- the packs and the pressurization: the models and their glue
-- (notes/ATA-21.md), after the bleed glue
dofile("B747.55.xt.packs.lua")
dofile("B747.55.xt.press.lua")





function equipment_cooling()
    if (simDR_elec_bus_volts[0] > 0.0) and B747DR_equip_cooling_sel_pos==1 then
        B747DR_equip_cooling_state =1
    else
        B747DR_equip_cooling_state =0
    end    
end











----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_air_monitor_AI()

    if B747DR_init_air_CD == 1 then
        B747_set_air_all_modes()
        B747_set_air_CD()
        B747DR_init_air_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_air_all_modes()

	B747DR_init_air_CD = 0
    B747DR_pass_temp_ctrl__rheo = 0.5
    B747DR_flt_deck_temp_ctrl_rheo = 0.5
    B747DR_cargo_temp_ctrl_rheo = 0.5
    B747DR_landing_alt_button_pos = 1.0
    B747DR_pressure_EICAS1_display_status = 0

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_air_CD()

    B747DR_pack_ctrl_sel_pos[0] = 0
    B747DR_pack_ctrl_sel_pos[1] = 0
    B747DR_pack_ctrl_sel_pos[2] = 0

    B747DR_equip_cooling_sel_pos = 0
    B747DR_cabin_alt_auto_sel_pos = 0

end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_air_ER()
	
    B747DR_pack_ctrl_sel_pos[0] = 1
    B747DR_pack_ctrl_sel_pos[1] = 1
    B747DR_pack_ctrl_sel_pos[2] = 1
	
end








----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_air()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_air_all_modes()


    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_air_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_air_ER()

    end

end







--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end

function flight_start() 

    B747_flight_start_air()
    B747_bleed_flight_start()
    B747_packs_flight_start()
    B747_press_flight_start()

end

--function flight_crash() end

--function before_physics() end
debug_air     = deferred_dataref("laminar/B747/debug/air", "number")
function after_physics()
  if debug_air>0 then return end

    B747_bleed()        -- with the packs' flow of the last frame
    B747_packs()
    B747_press()
    equipment_cooling()

    B747_air_monitor_AI()

end

--function after_replay() end



