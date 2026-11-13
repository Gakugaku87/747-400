--[[
*****************************************************************************************
* Program Script Name	:	B747.03.electrical
* Author Name			:	Jim Gregory
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2016-05-03	0.01a				Start of Dev
*
*
*
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	    *
*****************************************************************************************
--]]

--[[

ELECTRICAL SYSTEM LOGIC DESCRIPTION:

In planemaker we set up 5 busses.  The battery is assigned to bus 5 making it essentially
the "Battery Bus".  The fifth bus will have power when the battery switch is on.
The 747 has 4 "bus-tie" switches, which can isolate each of the 4 main busses.  This cannot
be done in X-Plane so we require ALL (747) bus-tie switches to be closed in order to close the
X-Plane cross-tie (handled in the code below).  So, in X-Plane we assign the battery and
generators to bus 5.  Therefore, all of these 4 busses will have zero voltage until the
cross-tie is closed.

Since this logic means that all 4 busses either have power or they don't, the assignment of
components to busses in Planemaker is made for amp load distribution, not for power
source.  There should be no assignments made to the fifth bus.

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

function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end



--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--
simDR_version=find_dataref("sim/version/xplane_internal_version")
simDR_gpuvolts=find_dataref("sim/cockpit2/electrical/GPU_generator_volts")
simDR_startup_running           = find_dataref("sim/operation/prefs/startup_running")

simDR_engine_running            = find_dataref("sim/flightmodel/engine/ENGN_running")

simDR_aircraft_groundspeed      = find_dataref("sim/flightmodel/position/groundspeed")

simDR_battery_on                = find_dataref("sim/cockpit2/electrical/battery_on")
simDR_gpu_on                    = find_dataref("sim/cockpit/electrical/gpu_on")
simDR_cross_tie                 = find_dataref("sim/cockpit2/electrical/cross_tie")

simDR_apu_gen_on                = find_dataref("sim/cockpit2/electrical/APU_generator_on")
--simDR_apu_gen_amps              = find_dataref("sim/cockpit2/electrical/APU_generator_amps")
simDR_apu_start_switch_mode     = find_dataref("sim/cockpit2/electrical/APU_starter_switch")
simDR_apu_N1_pct                = find_dataref("sim/cockpit2/electrical/APU_N1_percent")
simDR_apu_running               = find_dataref("sim/cockpit2/electrical/APU_running")
B747DR_elec_apu_oil      	= deferred_dataref("laminar/B747/electrical/oil", "number")


simDR_generator_on              = find_dataref("sim/cockpit2/electrical/generator_on")
simDR_generator_off              = find_dataref("sim/cockpit2/annunciators/generator_off")
simDR_esys0              = find_dataref("sim/operation/failures/rel_esys")
simDR_esys1              = find_dataref("sim/operation/failures/rel_esys2")
simDR_esys2              = find_dataref("sim/operation/failures/rel_esys3")
simDR_esys3              = find_dataref("sim/operation/failures/rel_esys4")




--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--
B747DR_elec_display_power   = find_dataref("laminar/B747/electrical/display_has_power")
-- Captain PFD
-- First Officer PFD
-- First Officer ND
-- Captain ND
-- Upper EIACAS
-- Lower EICAS
-- FMS L
-- FMS R
-- FMS C
B747DR_button_switch_position       = find_dataref("laminar/B747/button_switch/position")
B747DR_elec_ext_pwr_1_switch_mode   = find_dataref("laminar/B747/elec_ext_pwr_1/switch_mode")
B747DR_elec_ext_pwr_2_switch_mode   = find_dataref("laminar/B747/elec_ext_pwr_2/switch_mode")
B747DR_elec_apu_pwr_1_switch_mode   = find_dataref("laminar/B747/apu_pwr_1/switch_mode")
B747DR_elec_apu_pwr_2_switch_mode   = find_dataref("laminar/B747/apu_pwr_2/switch_mode")

B747DR_gen_drive_disc_status        = find_dataref("laminar/B747/electrical/generator/drive_disc_status")

B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_caution_status       = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_memo_status              = find_dataref("laminar/B747/CAS/memo_status")
B747DR_simDR_esys0              = find_dataref("laminar/B747/rel_esys")
B747DR_simDR_esys1              = find_dataref("laminar/B747/rel_esys2")
B747DR_simDR_esys2              = find_dataref("laminar/B747/rel_esys3")
B747DR_simDR_esys3              = find_dataref("laminar/B747/rel_esys4")
B747DR_simDR_captain_display              = find_dataref("laminar/B747/electrical/capt_display_power")
B747DR_simDR_fo_display             = find_dataref("laminar/B747/electrical/fo_display_power")

--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_elec_standby_power_sel_pos   = deferred_dataref("laminar/B747/electrical/standby_power/sel_dial_pos", "number")
B747DR_elec_apu_sel_pos             = deferred_dataref("laminar/B747/electrical/apu/sel_dial_pos", "number")
B747DR_elec_stby_ignit_sel_pos      = deferred_dataref("laminar/B747/electrical/stby_ignit/sel_dial_pos", "number")
B747DR_elec_auto_ignit_sel_pos      = deferred_dataref("laminar/B747/electrical/auto_ignit/sel_dial_pos", "number")

B747DR_elec_apu_inlet_door_pos      = deferred_dataref("laminar/B747/electrical/apu_inlet_door", "number")
B747DR_elec_apu_volts      = deferred_dataref("laminar/B747/electrical/apu_volts", "number")
B747DR_elec_ext_pwr1_available      = deferred_dataref("laminar/B747/electrical/ext_pwr1_avail", "number")
B747DR_elec_ext_pwr2_available      = deferred_dataref("laminar/B747/electrical/ext_pwr2_avail", "number")
B747DR_elec_apu_pwr1_available      = deferred_dataref("laminar/B747/electrical/apu_pwr1_avail", "number")
B747DR_elec_apu_pwr2_available      = deferred_dataref("laminar/B747/electrical/apu_pwr2_avail", "number")
B747DR_init_elec_CD                 = deferred_dataref("laminar/B747/elec/init_CD", "number")
B747DR_elec_ext_pwr1_on      	= deferred_dataref("laminar/B747/electrical/ext_pwr1_on", "number")
B747DR_elec_ext_pwr2_on      	= deferred_dataref("laminar/B747/electrical/ext_pwr2_on", "number")
B747DR_elec_apu_pwr1_on      	= deferred_dataref("laminar/B747/electrical/apu_pwr1_on", "number")
B747DR_elec_apu_pwr2_on      	= deferred_dataref("laminar/B747/electrical/apu_pwr2_on", "number")
B747DR_elec_ssb      		= deferred_dataref("laminar/B747/electrical/ssb", "number")
B747DR_elec_topleftbus      	= deferred_dataref("laminar/B747/electrical/topleftbus", "number")
B747DR_elec_toprightbus      	= deferred_dataref("laminar/B747/electrical/toprightbus", "number")
B747DR_elec_bus1hot      	= deferred_dataref("laminar/B747/electrical/bus1hot", "number")
B747DR_elec_bus2hot      	= deferred_dataref("laminar/B747/electrical/bus2hot", "number")
B747DR_elec_bus3hot      	= deferred_dataref("laminar/B747/electrical/bus3hot", "number")
B747DR_elec_bus4hot      	= deferred_dataref("laminar/B747/electrical/bus4hot", "number")
B747DR_elec_utilityleft1      	= deferred_dataref("laminar/B747/electrical/utilityleft1", "number")
B747DR_elec_utilityright1      	= deferred_dataref("laminar/B747/electrical/utilityright1", "number")
B747DR_elec_utilityleft2      	= deferred_dataref("laminar/B747/electrical/utilityleft2", "number")
B747DR_elec_utilityright2      	= deferred_dataref("laminar/B747/electrical/utilityright2", "number")
simDR_override_gpu               = find_dataref("sim/operation/override/override_GPU_volts")
B747DR__gear_chocked           = deferred_dataref("laminar/B747/gear/chocked", "number")

-- buses, breakers, lights, EICAS: the electrical model and its glue
dofile("B747.03.xt.elec_buses.lua")
-- the APU sequence, its shutdowns and messages: the APU model and its glue
dofile("B747.03.xt.apu.lua")
--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	         	     **--
--*************************************************************************************--





--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--





--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--

-- APU
-- (2026-11-13; finding 3 of the 2026-11-12 review) the selector to START
-- and back to ON at once: ON, and START's latch of the automatic start
-- (B747_apu_start_pushed, as the selector's own command: FCOM p.867,
-- p.896). Before, the selector's command twice from here: in X-Plane the
-- two onces of one frame came out as one push, the selector stopped at
-- ON and the APU did not start (X-Plane's auto start: auto board's step
-- 8 timed out after 120 s, s305)
function sim_apu_start_CMDhandler(phase, duration)
    if phase == 0 then
        if simDR_apu_running == 0 then
            if B747DR_elec_apu_sel_pos < 1 then B747DR_elec_apu_sel_pos = 1 end
            B747_apu_start_pushed = true
        end
    end
end

function sim_apu_on_CMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_elec_apu_sel_pos == 0 then
            B747CMD_elec_apu_sel_up:once()
        end
    end
end

function sim_apu_off_CMDhandler(phase, duration)
    if phase == 0 then
        if B747DR_elec_apu_sel_pos == 1 then
            B747CMD_elec_apu_sel_dn:once()
        end
    end
end





--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--

simCMD_apu_start                = replace_command("sim/electrical/APU_start", sim_apu_start_CMDhandler)
simCMD_apu_on                   = replace_command("sim/electrical/APU_on", sim_apu_on_CMDhandler)
simCMD_apu_off                  = replace_command("sim/electrical/APU_off", sim_apu_off_CMDhandler)

--simCMD_apu_gen_on               = find_command("sim/electrical/APU_generator_on")
--simCMD_apu_gen_off              = find_command("sim/electrical/APU_generator_off")






--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- STANDBY POWER
function B747_elec_standby_power_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_standby_power_sel_pos = math.min(B747DR_elec_standby_power_sel_pos+1, 2)
    end
end
function B747_elec_standby_power_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_standby_power_sel_pos = math.max(B747DR_elec_standby_power_sel_pos-1, 0)
    end
end




-- APU SELECTOR
function B747_elec_apu_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_apu_sel_pos = math.min(B747DR_elec_apu_sel_pos+1, 2)
        -- START latches the automatic start; it may go back to ON at once (FCOM p.867, p.896)
        if B747DR_elec_apu_sel_pos == 2 then B747_apu_start_pushed = true end
    end

    if phase == 2 then
        if B747DR_elec_apu_sel_pos == 2 then
            B747DR_elec_apu_sel_pos = 1
        end
    end
end
function B747_elec_apu_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_apu_sel_pos = math.max(B747DR_elec_apu_sel_pos-1, 0)
    end
end




-- STANDBY IGNITION
function B747_stby_ign_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_stby_ignit_sel_pos = math.min(B747DR_elec_stby_ignit_sel_pos+1, 2)
    end
end
function B747_stby_ign_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_stby_ignit_sel_pos = math.max(B747DR_elec_stby_ignit_sel_pos-1, 0)
    end
end




-- AUTO IGNITION
function B747_auto_ign_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_auto_ignit_sel_pos = math.min(B747DR_elec_auto_ignit_sel_pos+1, 2)
    end
end
function B747_auto_ign_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_elec_auto_ignit_sel_pos = math.max(B747DR_elec_auto_ignit_sel_pos-1, 0)
    end
end





function B747_ai_elec_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
	  	B747_set_elec_all_modes()
	  	B747_set_elec_CD()
	  	B747_set_elec_ER()
	end
end



--*************************************************************************************--
--** 				                 CUSTOM COMMANDS                			     **--
--*************************************************************************************--
-- (2026-11-04) the ground power cart from the FMC's GROUND SERVICES page
-- (L2) or this command, without add-ons. X-Plane 12: X-Plane's own ground
-- power truck where it can be called for (sim/ground_ops/toggle_gpu_request:
-- its voltage then makes EXT PWR available, B747_external_power), else a
-- cart without the truck (X-Plane's GPU voltage overridden). Connecting
-- needs the airplane standing on the ground; the ground crew chocks the
-- wheels first (EXT PWR needs the chocks: B747_external_power). Before, on
-- X-Plane 12 only X-Plane's menu or an add-on could bring the voltage, and
-- the handler toggled on each phase of the command
simDR_elec_gpu_can_call         = find_dataref("sim/cockpit2/electrical/GPU_can_be_called_for")
simDR_elec_gpu_generator_on     = find_dataref("sim/cockpit2/electrical/GPU_generator_on")
simCMD_elec_gpu_request         = find_command("sim/ground_ops/toggle_gpu_request")
B747DR_elec_ext_pwr_requested   = find_dataref("laminar/B747/electrical/ext_pwr_requested")
local ELEC_GPU_STANDING_MS = 1          -- standing: below 1 m/s (estimate)
local elec_gpu_truck = false            -- X-Plane's truck asked for
function B747_connect_power_CMDhandler(phase, duration)
    if phase ~= nil and phase ~= 0 then return end      -- once per push
    local connected = B747DR_elec_ext_pwr1_available == 1
    if connected or elec_gpu_truck then
        -- removed: the truck sent away, the cart's power off
        if simDR_version >= 120012 then
            if elec_gpu_truck or simDR_elec_gpu_generator_on == 1 then simCMD_elec_gpu_request:once() end
            simDR_override_gpu = 0
            simDR_gpuvolts = 0
        end
        elec_gpu_truck = false
        B747DR_elec_ext_pwr1_available = 0
        B747DR_elec_ext_pwr2_available = 0
        B747DR_elec_ext_pwr_requested = 0
        return
    end
    if B747DR_elec_pseu_air == 1 or simDR_aircraft_groundspeed > ELEC_GPU_STANDING_MS then return end
    if B747DR__gear_chocked == 0 then B747DR__gear_chocked = 1 end
    if simDR_version < 120012 then
        B747DR_elec_ext_pwr1_available = 1
        B747DR_elec_ext_pwr2_available = 1
    elseif simDR_elec_gpu_can_call == 1 then
        simCMD_elec_gpu_request:once()      -- X-Plane's truck: EXT PWR once it is connected
        elec_gpu_truck = true
        B747DR_elec_ext_pwr_requested = 1
    else
        simDR_override_gpu = 1              -- no X-Plane ground service here: the cart alone
        simDR_gpuvolts = 28
    end
end
B747CMD_connect_power          = deferred_command("laminar/B747/electrical/connect_power", "Connect external power", B747_connect_power_CMDhandler)
-- STANDBY POWER
B747CMD_elec_standby_power_sel_up = deferred_command("laminar/B747/electrical/standby_power/sel_dial_up", "Electrical Standby Power Selector Up", B747_elec_standby_power_sel_up_CMDhandler)
B747CMD_elec_standby_power_sel_dn = deferred_command("laminar/B747/electrical/standby_power/sel_dial_dn", "Electrical Standby Power Selector Down", B747_elec_standby_power_sel_dn_CMDhandler)



-- APU SELECTOR
B747CMD_elec_apu_sel_up = deferred_command("laminar/B747/electrical/apu/sel_dial_up", "Electrical APU Selector Dial Up", B747_elec_apu_sel_up_CMDhandler)
B747CMD_elec_apu_sel_dn = deferred_command("laminar/B747/electrical/apu/sel_dial_dn", "Electrical APU Selector Dial Down", B747_elec_apu_sel_dn_CMDhandler)



-- STANDBY IGNITION
B747CMD_stby_ign_sel_up = deferred_command("laminar/B747/electrical/stby_ignit/sel_dial_up", "Electrical Standby Ignition Selector Dial Up", B747_stby_ign_sel_up_CMDhandler)
B747CMD_stby_ign_sel_dn = deferred_command("laminar/B747/electrical/stby_ignit/sel_dial_dn", "Electrical Standby Ignition Selector Dial Down", B747_stby_ign_sel_dn_CMDhandler)



-- AUTO IGNITION
B747CMD_auto_ign_sel_up = deferred_command("laminar/B747/electrical/auto_ignit/sel_dial_up", "Electrical Auto Ignition Selector Dial Up", B747_auto_ign_sel_up_CMDhandler)
B747CMD_auto_ign_sel_dn = deferred_command("laminar/B747/electrical/auto_ignit/sel_dial_dn", "Electrical Auto Ignition Selector Dial Down", B747_auto_ign_sel_dn_CMDhandler)


-- AI
B747CMD_ai_elec_quick_start			= deferred_command("laminar/B747/ai/elec_quick_start", "number", B747_ai_elec_quick_start_CMDhandler)



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





----- EXTERNAL POWER --------------------------------------------------------------------
function B747_external_power()

    -- EXT POWER 1 AVAILABLE
--     if simDR_aircraft_on_ground == 1
--         and simDR_aircraft_groundspeed < 0.05
--         and simDR_engine_running[0] == 0
--         and simDR_engine_running[1] == 0
--         and simDR_engine_running[2] == 0
--         and simDR_engine_running[3] == 0
--     then
--         B747DR_elec_ext_pwr1_available = 1
-- 	B747DR_elec_ext_pwr2_available = 1
--     else
--         B747DR_elec_ext_pwr1_available = 0
-- 	B747DR_elec_ext_pwr2_available = 0
--     end

    if B747DR__gear_chocked == 0
    then
        --print("disabled ground power at ".. simDR_aircraft_groundspeed .. " "..simDR_aircraft_on_ground)
      B747DR_elec_ext_pwr1_available = 0
	    B747DR_elec_ext_pwr2_available = 0
			simDR_override_gpu = 0
			simDR_gpuvolts = 0
    end
    if simDR_version>=120012 and (simDR_gpuvolts<24) then
			B747DR_elec_ext_pwr1_available = 0
	    B747DR_elec_ext_pwr2_available =0
		end
		if simDR_version>=120012 and (simDR_gpuvolts>=24) then
			simDR_override_gpu = 1

		end
		if simDR_version>=120012 and simDR_override_gpu ==1 then
			simDR_gpuvolts = 28
			B747DR_elec_ext_pwr1_available = 1
	    B747DR_elec_ext_pwr2_available = 1
		end
    -- (2026-11-04) the truck asked for: done once it gives power, or given
    -- up without the chocks
    if B747DR_elec_ext_pwr_requested == 1 and (B747DR_elec_ext_pwr1_available == 1 or B747DR__gear_chocked == 0) then
        B747DR_elec_ext_pwr_requested = 0
    end
    -- connecting it (X-Plane's GPU on) is the electrical model's XPC
end





----- UTILITY ---------------------------------------------------------------------------
function B747_ternary(condition, ifTrue, ifFalse)
    if condition then return ifTrue else return ifFalse end
end





----- APU: the APU model and its glue (B747.03.xt.apu.lua) ----------------------------






----- ELECTRICAL EICAS MESSAGES ---------------------------------------------------------
function B747_electrical_EICAS_msg()

    -- APU, APU DOOR, APU RUNNING: B747.03.xt.apu.lua

    -- STBY IGNITION ON

    if B747DR_elec_stby_ignit_sel_pos == 0
        or B747DR_elec_stby_ignit_sel_pos == 2
    then
        B747DR_CAS_memo_status[34] = 1
    else
        B747DR_CAS_memo_status[34] = 0
    end

end






----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_elec_monitor_AI()

    if B747DR_init_elec_CD == 1 then
        B747_set_elec_all_modes()
        B747_set_elec_CD()
        B747DR_init_elec_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_elec_all_modes()

	B747DR_init_elec_CD = 0
    B747DR_elec_stby_ignit_sel_pos = 1
    B747DR_elec_auto_ignit_sel_pos = 1

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_elec_CD()

    B747DR_elec_standby_power_sel_pos = 0
    B747DR_elec_apu_sel_pos = 0
    simDR_apu_start_switch_mode = 0

end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_elec_ER()
  B747DR_elec_standby_power_sel_pos = 1


end






----- FLIGHT START ---------------------------------------------------------------------
function B747_flight_start_electric()

    -- ALL MODES ------------------------------------------------------------------------
    B747_elec_reset()
    B747_set_elec_all_modes()
    B747_apu_flight_start()


    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_elec_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_elec_ER()

    end

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

    B747_flight_start_electric()

end

--function flight_crash() end

--function before_physics() end
debug_electrical     = deferred_dataref("laminar/B747/debug/electrical", "number")
function after_physics()
    if debug_electrical>0 then return end
    if flightInit==false then
        do_flight_start()
    end
    flightInit=true
    B747_external_power()
    B747_apu()
    B747_elec_buses()
    B747_electrical_EICAS_msg()
    B747_elec_monitor_AI()

end

--function after_replay() end
