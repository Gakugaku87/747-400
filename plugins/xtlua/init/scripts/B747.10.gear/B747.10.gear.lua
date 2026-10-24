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
function null_command(phase, duration)
end
--replace create_command
--[[function deferred_command(name,desc,nilFunc)
	c = XLuaCreateCommand(name,desc)
	print("Deffereed command: "..name)
	XLuaReplaceCommand(c,null_command)
	return make_command_obj(c)
end
--replace create_dataref
function deferred_dataref(name,type,notifier)
	print("Deffereed dataref: "..name)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type) 
end]]
function deferred_command(name,desc,nilFunc)
	c = XLuaCreateCommand(name,desc)
	--print("Deferred command: "..name)
	--XLuaReplaceCommand(c,null_command)
	return nil --make_command_obj(c)
end
--replace create_dataref
function deferred_dataref(name,type,notifier)
	--print("Deffereed dataref: "..name)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type) 
end

B747DR_gear_lock_override_pos   = deferred_dataref("laminar/B747/gear_lock_ovrd/position", "number")
B747DR_autobrakes_sel_dial_pos  = deferred_dataref("laminar/B747/gear/autobrakes/sel_dial_pos", "number")

B747DR_gear_annun_status        = deferred_dataref("laminar/B747/gear/gear_position/annun_status", "number")
B747DR_EICAS1_gear_display_status = deferred_dataref("laminar/B747/gear/EICAS1_display_status", "number")

B747DR_tire_pressure            = deferred_dataref("laminar/B747/gear/tire_pressure", "array[18]")
B747DR_brake_temp               = deferred_dataref("laminar/B747/gear/brake_temp", "array[18]")
B747DR_brake_temp_ind               = deferred_dataref("laminar/B747/gear/brake_temp_ind", "array[18]")
B747DR_init_gear_CD             = deferred_dataref("laminar/B747/gear/init_CD", "number")
B747DR__gear_chocked           = deferred_dataref("laminar/B747/gear/chocked", "number")

-- Air/ground sensing (PSEU), 1 true, from B747.10.pseu_model.lua
-- (docs/overhaul/ARCHITECTURE.md §4.2). Other systems read these instead of
-- sim/flightmodel/failures/onground_any (any one wheel on the ground).
B747DR_pseu_pri_air            = deferred_dataref("laminar/B747/gear/air_ground/pri_air", "number")
B747DR_pseu_pri_gnd            = deferred_dataref("laminar/B747/gear/air_ground/pri_gnd", "number")
B747DR_pseu_alt_air            = deferred_dataref("laminar/B747/gear/air_ground/alt_air", "number")
B747DR_pseu_alt_gnd            = deferred_dataref("laminar/B747/gear/air_ground/alt_gnd", "number")
B747DR_pseu_ng_compressed      = deferred_dataref("laminar/B747/gear/air_ground/ng_compressed", "number")
B747DR_pseu_all_gear_down      = deferred_dataref("laminar/B747/gear/air_ground/all_gear_down", "number")
B747DR_pseu_nose_not_down      = deferred_dataref("laminar/B747/gear/air_ground/nose_not_down", "number")
B747DR_pseu_lever_unlock       = deferred_dataref("laminar/B747/gear/air_ground/lever_unlock", "number")

-- The gear's actuation (4-2 step 1, B747.10.gear_model.lua; ARCHITECTURE.md):
-- each gear's position (0 up and locked .. 1 down and locked) and its door
-- (0 closed .. 1 open), each gear's box of the expanded EICAS indication
-- (0 UP, 1 DN, 2 in transit, 3 amber X), all in the order nose, left body,
-- right body, left wing, right wing; the lever lock (1 locked: the lever
-- stops at OFF); failures (no X-Plane equivalents): the gear does not move,
-- its door does not move, its position indication lost, its truck not tilted.
B747DR_gear_lever_lock         = deferred_dataref("laminar/B747/gear/lever_lock", "number")
B747DR_gear_position           = deferred_dataref("laminar/B747/gear/position", "array[5]")
B747DR_gear_door               = deferred_dataref("laminar/B747/gear/door", "array[5]")
B747DR_gear_annun_gear         = deferred_dataref("laminar/B747/gear/gear_position/annun_gear", "array[5]")
B747DR_gear_fail_actuator      = deferred_dataref("laminar/B747/gear/fail/actuator", "array[5]")
B747DR_gear_fail_door          = deferred_dataref("laminar/B747/gear/fail/door", "array[5]")
B747DR_gear_fail_indication    = deferred_dataref("laminar/B747/gear/fail/indication", "array[5]")
B747DR_gear_fail_truck_tilt    = deferred_dataref("laminar/B747/gear/fail/truck_tilt", "array[5]")
-- The wheel brakes (4-2 step 2, B747.10.brake_model.lua): the parking brake
-- valve (0 open .. 1 closed); failures (no X-Plane equivalents): the normal
-- and the alternate antiskid, the torque limiters, the parking brake valve
-- stuck.
B747DR_gear_park_valve         = deferred_dataref("laminar/B747/gear/brakes/park_valve", "number")
B747DR_gear_fail_antiskid      = deferred_dataref("laminar/B747/gear/fail/antiskid", "array[2]")
B747DR_gear_fail_limiter       = deferred_dataref("laminar/B747/gear/fail/brake_limiter", "number")
B747DR_gear_fail_park_valve    = deferred_dataref("laminar/B747/gear/fail/park_valve", "number")
-- the autobrakes (4-2 step 3, B747.10.autobrake_model.lua): failed
B747DR_gear_fail_autobrake     = deferred_dataref("laminar/B747/gear/fail/autobrake", "number")
-- the steering (4-2 step 4, B747.10.steering_model.lua): the tillers (-1 .. 1,
-- + right) for users and tools without X-Plane's tiller axis; the pedals as
-- the tiller without a tiller axis (1 on: not the aircraft, on at the
-- aircraft's load); a body gear truck unlocked (1); failures (no X-Plane
-- equivalents): a pedal steering interconnect actuator, a body gear
-- steering actuator unlocked.
B747DR_gear_steering_tiller    = deferred_dataref("laminar/B747/gear/steering/tiller", "number")
B747DR_gear_pedal_tiller       = deferred_dataref("laminar/B747/gear/steering/pedal_tiller", "number")
B747DR_gear_body_unlocked      = deferred_dataref("laminar/B747/gear/steering/body_unlocked", "number")
B747DR_gear_fail_pedal_strg    = deferred_dataref("laminar/B747/gear/fail/pedal_steering", "number")
B747DR_gear_fail_body_strg     = deferred_dataref("laminar/B747/gear/fail/body_steering", "number")
B747DR_parking_brake_ratio = find_dataref("laminar/B747/flt_ctrls/parking_brake_ratio")
simDR_parking_brake_ratio       = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
----- GEAR HANDLE DATAREF HANDLER -------------------------------------------------------

-- the detents; the lever lock (laminar/B747/gear/lever_lock, from the gear
-- module: the PSEU, LOCK OVRD, DC bus 2) stops the lever at OFF on its way to
-- UP (FCOM p.1512). X-Plane's handle follows the gear model
-- (B747.10.xt.gear_act.lua).
function B747DR_gear_handle_DRhandler()

    -- GEAR HANDLE LOCK IS DISENGAGED
    if B747DR_gear_lever_lock == 0 then

        if B747DR_gear_handle <= 0.1 then
            B747DR_gear_handle = 0.0   -- DETENT (GEAR HANDLE "DOWN")
        elseif B747DR_gear_handle >= 0.9 and B747DR_gear_handle <= 1.1 then
            B747DR_gear_handle = 1.0   -- DETENT (GEAR HANDLE "OFF")
        elseif B747DR_gear_handle >= 1.9 then
            B747DR_gear_handle = 2.0   -- DETENT (GEAR HANDLE "UP")
        end


    -- GEAR HANDLE LOCK IS ENGAGED
    else

        if B747DR_gear_handle <= 0.1 then
            B747DR_gear_handle = 0.0   -- DETENT (GEAR HANDLE "DOWN")
        elseif B747DR_gear_handle >= 0.9 then
            B747DR_gear_handle = 1.0
        end

    end
end



function B747DR_gear_handle_detent_DRhandler() end

B747DR_gear_handle 			= deferred_dataref("laminar/B747/actuator/gear_handle", "number", B747DR_gear_handle_DRhandler)
B747DR_gear_handle_detent 	= deferred_dataref("laminar/B747/actuator/gear_handle_detent", "number", B747DR_gear_handle_detent_DRhandler)





-- GEAR LOCK OVERRIDE
B747CMD_gear_lock_override      = deferred_command("laminar/B747/gear_lock/override", "Gear Lock Override", B747_gear_lock_override_CMDhandler)

B747CMD_gear_up_full      = deferred_command("laminar/B747/gear/overrideUp", "Gear Full Up", B747_gear_lock_override_CMDhandler)
B747CMD_gear_down_full      = deferred_command("laminar/B747/gear/overrideDown", "Gear Full Down", B747_gear_lock_override_CMDhandler)
B747CMD_gear_off      = deferred_command("laminar/B747/gear/overrideOff", "Gear Off", B747_gear_lock_override_CMDhandler)

-- AUTOBRAKES SELECTOR DIAL
B747CMD_autobrakes_sel_dial_up  = deferred_command("laminar/B747/gear/autobrakes/sel_dial_up", "Autobrakes Sel Dial Up", B747_autobrakes_sel_dial_up_CMDhandler)
B747CMD_autobrakes_sel_dial_dn  = deferred_command("laminar/B747/gear/autobrakes/sel_dial_dn", "Autobrakes Sel Dial Down", B747_autobrakes_sel_dial_dn_CMDhandler)


-- AI
B747CMD_ai_gear_quick_start			= deferred_command("laminar/B747/ai/gear_quick_start", "number", B747_ai_gear_quick_start_CMDhandler)


simDR_aircraft_on_ground    = find_dataref("sim/flightmodel/failures/onground_any")



