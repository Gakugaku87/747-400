--[[
*****************************************************************************************
* Program Script Name	:	B747.85.safety
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



--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
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
simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")
simDR_door_open_ratio               = find_dataref("sim/flightmodel2/misc/door_open_ratio")
simDR_sfty_throttle_ratio           = find_dataref("sim/cockpit2/engine/actuators/throttle_ratio")
simDR_sfty_time                     = find_dataref("sim/time/total_running_time_sec")
simDR_cockpit2_no_smoking_switch    = find_dataref("sim/cockpit2/switches/no_smoking")
simDR_cockpit2_seat_belt_switch     = find_dataref("sim/cockpit2/switches/fasten_seat_belts")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--


B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_memo_status              = find_dataref("laminar/B747/CAS/memo_status")



--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_sfty_no_smoke_sel_dial_pos   = deferred_dataref("laminar/B747/safety/no_smoking/sel_dial_pos", "number")
B747DR_sfty_seat_belts_sel_dial_pos = deferred_dataref("laminar/B747/safety/seat_belts/sel_dial_pos", "number")

B747DR_init_safety_CD               = deferred_dataref("laminar/B747/safety/init_CD", "number")
B747DR_door_mode                    = deferred_dataref("laminar/B747/door/mode", "array[12]")
B747DR_sfty_pseu_gnd                = find_dataref("laminar/B747/gear/air_ground/pri_gnd")



--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--

function B747_checklist_marker_capt_DRhandler() end
function B747_checklist_marker_fo_DRhandler() end



--*************************************************************************************--
--** 				       CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

B747DR_checklist_marker_capt        = deferred_dataref("laminar/B747/safety/checklist_marker_capt", "number", B747_checklist_marker_capt_DRhandler)
B747DR_checklist_marker_fo          = deferred_dataref("laminar/B747/safety/checklist_marker_fo", "number", B747_checklist_marker_fo_DRhandler)




--*************************************************************************************--
--** 				             X-PLANE COMMAND HANDLERS               	    	 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                 X-PLANE COMMANDS                   	    	 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--



--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- NO SMOKING DIAL
function B747_sfty_no_smoke_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_sfty_no_smoke_sel_dial_pos = math.min(B747DR_sfty_no_smoke_sel_dial_pos+1, 2)
    end
end
function B747_sfty_no_smoke_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_sfty_no_smoke_sel_dial_pos = math.max(B747DR_sfty_no_smoke_sel_dial_pos-1, 0)
    end
end




-- SEAT BELTS DIAL
function B747_sfty_seat_belts_sel_dial_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_sfty_seat_belts_sel_dial_pos = math.min(B747DR_sfty_seat_belts_sel_dial_pos+1, 2)
    end
end
function B747_sfty_seat_belts_sel_dial_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_sfty_seat_belts_sel_dial_pos = math.max(B747DR_sfty_seat_belts_sel_dial_pos-1, 0)
    end
end





function B747_ai_safety_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
      	B747_set_safety_all_modes()
      	B747_set_safety_CD()
      	B747_set_safety_ER() 
    end
end






--*************************************************************************************--
--** 					            OBJECT CONSTRUCTORS         		    		 **--
--*************************************************************************************--

-- NO SMOKING DIAL
B747CMD_sfty_no_smoke_sel_dial_up   = deferred_command("laminar/B747/safety/no_smoking/sel_dial_up", "No Smoking Selector Dial Up", B747_sfty_no_smoke_sel_dial_up_CMDhandler)
B747CMD_sfty_no_smoke_sel_dial_dn   = deferred_command("laminar/B747/safety/no_smoking/sel_dial_dn", "No Smoking Selector Dial Down", B747_sfty_no_smoke_sel_dial_dn_CMDhandler)


-- SEAT BELTS DIAL
B747CMD_sfty_seat_belts_sel_dial_up = deferred_command("laminar/B747/safety/seat_belts/sel_dial_up", "Seat Belts Selector Dial Up", B747_sfty_seat_belts_sel_dial_up_CMDhandler)
B747CMD_sfty_seat_belts_sel_dial_dn = deferred_command("laminar/B747/safety/seat_belts/sel_dial_dn", "Seat Belts Selector Dial_Down", B747_sfty_seat_belts_sel_dial_dn_CMDhandler)



-- AI
B747CMD_ai_safety_quick_start			= deferred_command("laminar/B747/ai/safety_quick_start", "number", B747_ai_safety_quick_start_CMDhandler)

-- (7-3) the doors' modes, all at once (the 3D has no doors' levers)
local NUM_DOOR_MODES = 12
local function B747_door_mode_all(mode)
    for i = 0, NUM_DOOR_MODES - 1 do B747DR_door_mode[i] = mode end
end
function B747_door_mode_auto_all_CMDhandler(phase, duration)
    if phase == 0 then B747_door_mode_all(1) end
end
function B747_door_mode_manual_all_CMDhandler(phase, duration)
    if phase == 0 then B747_door_mode_all(0) end
end
B747CMD_door_mode_auto_all          = deferred_command("laminar/B747/door/mode_auto_all", "Entry and upper deck doors to AUTOMATIC (armed)", B747_door_mode_auto_all_CMDhandler)
B747CMD_door_mode_manual_all        = deferred_command("laminar/B747/door/mode_manual_all", "Entry and upper deck doors to MANUAL (disarmed)", B747_door_mode_manual_all_CMDhandler)

-- (7-3; notes/ATA-52.md §11) the doors' mode memos of the E&M's
-- configuration (ATA38_51_52_56 p.304; FCOM 109 has none, put in at the
-- user's wish, 2026-11-01):
--  - DOORS AUTO: every entry and upper deck door AUTOMATIC; inhibited from
--    takeoff power until 1 minute after landing
--  - DOORS MANUAL: every one MANUAL, on the ground only
--  - DOORS AUTO/MAN: mixed
-- Takeoff power: a thrust lever at 0.6 or more on the ground (estimate),
-- or 10 s in the air (an air start); the inhibit ends after 60 s on the
-- ground with the levers below it (after a landing or a rejected takeoff;
-- reverse thrust counts as power: estimate). A new flight starts without
-- it
local DOORS_TO_POWER = 0.6
local DOORS_AIR_S = 10
local DOORS_AFTER_LANDING_S = 60
local doorsInhibit = {on = false, since = nil, air = nil}
function B747_doors_mode_memo_reset()
    doorsInhibit.on, doorsInhibit.since, doorsInhibit.air = false, nil, nil
end
function B747_doors_mode_memo()
    local n = 0
    for i = 0, NUM_DOOR_MODES - 1 do
        if B747DR_door_mode[i] > 0.5 then n = n + 1 end
    end
    local ground = B747DR_sfty_pseu_gnd > 0.5
    local power = false
    for i = 0, 3 do
        if simDR_sfty_throttle_ratio[i] >= DOORS_TO_POWER then power = true end
    end
    local inh = doorsInhibit
    local now = simDR_sfty_time
    if ground then inh.air = nil else inh.air = inh.air or now end
    if (ground and power) or (inh.air and now - inh.air >= DOORS_AIR_S) then
        inh.on, inh.since = true, nil
    elseif inh.on and ground then
        inh.since = inh.since or now
        if now - inh.since >= DOORS_AFTER_LANDING_S then inh.on = false end
    end
    B747DR_CAS_memo_status[9] = (n == NUM_DOOR_MODES and not inh.on) and 1 or 0
    B747DR_CAS_memo_status[10] = (n > 0 and n < NUM_DOOR_MODES) and 1 or 0
    B747DR_CAS_memo_status[11] = (n == 0 and ground) and 1 or 0
end



--*************************************************************************************--
--** 				               CREATE SYSTEM OBJECTS            				 **--
--*************************************************************************************--



--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--










----- SAFETY EICAS MESSAGES -------------------------------------------------------------
function B747_safety_EICAS_msg()

    -- DOOR ENTRY L1
    
    if simDR_door_open_ratio[1] > 0.01 then 
        B747DR_CAS_advisory_status[66] = 1
    else
        B747DR_CAS_advisory_status[66] = 0     
    end

    -- DOOR L UPPER DK
    
    if simDR_door_open_ratio[0] > 0.01 then 
        B747DR_CAS_advisory_status[76] = 1 
    else
        B747DR_CAS_advisory_status[76] = 0
    end

    -- THE SIGN MEMOS: THE SELECTORS MANUALLY ON, NOT THE SIGNS (AUTO, OXYGEN)
    -- (FCOM p.502, p.547; ATA33 p.211)
    local no_smoking_on = B747DR_sfty_no_smoke_sel_dial_pos == 2
    local seat_belts_on = B747DR_sfty_seat_belts_sel_dial_pos == 2

    -- NO SMOKING ON

    if no_smoking_on and not seat_belts_on then
        B747DR_CAS_memo_status[17] = 1
    else
        B747DR_CAS_memo_status[17] = 0
    end

    -- PASS SIGNS ON

    if no_smoking_on and seat_belts_on then
        B747DR_CAS_memo_status[27] = 1
    else
        B747DR_CAS_memo_status[27] = 0
    end

    -- SEATBELTS ON

    if seat_belts_on and not no_smoking_on then
        B747DR_CAS_memo_status[33] = 1
    else
        B747DR_CAS_memo_status[33] = 0
    end


end






----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_safety_monitor_AI()

    if B747DR_init_safety_CD == 1 then
        B747_set_safety_all_modes()
        B747_set_safety_CD()
        B747DR_init_safety_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_safety_all_modes()

	B747DR_init_safety_CD = 0

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_safety_CD()

    B747DR_sfty_no_smoke_sel_dial_pos = 0
    B747DR_sfty_seat_belts_sel_dial_pos = 0
    B747_door_mode_all(0)       -- (7-3) the doors MANUAL at the gate

end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_safety_ER()
	
    B747DR_sfty_no_smoke_sel_dial_pos = 1
    B747DR_sfty_seat_belts_sel_dial_pos = 1
    B747_door_mode_all(1)       -- (7-3) the doors AUTOMATIC (armed)
	
end







----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_safety()

    -- ALL MODES ------------------------------------------------------------------------
    B747_doors_mode_memo_reset()



    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_safety_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_safety_ER()

    end

end







--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

--function aircraft_load() end

--function aircraft_unload() end

function flight_start() 

    B747_flight_start_safety()

end

--function flight_crash() end

--function before_physics() end
debug_safety     = deferred_dataref("laminar/B747/debug/safety", "number")
function after_physics()
    if debug_safety>0 then return end
    B747_safety_EICAS_msg()
    B747_doors_mode_memo()

    B747_safety_monitor_AI()

end

--function after_replay() end



