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
function null_command(phase, duration)
end
--replace create command
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

B747DR_sfty_no_smoke_sel_dial_pos   = deferred_dataref("laminar/B747/safety/no_smoking/sel_dial_pos", "number")
B747DR_sfty_seat_belts_sel_dial_pos = deferred_dataref("laminar/B747/safety/seat_belts/sel_dial_pos", "number")

B747DR_init_safety_CD               = deferred_dataref("laminar/B747/safety/init_CD", "number")
-- (7-3) the entry doors L1-L5, R1-R5 and the upper deck doors L, R: 1
-- AUTOMATIC (armed), 0 MANUAL; all at once by commands (no 3D levers)
B747DR_door_mode                    = deferred_dataref("laminar/B747/door/mode", "array[12]")
B747CMD_door_mode_auto_all          = deferred_command("laminar/B747/door/mode_auto_all", "Entry and upper deck doors to AUTOMATIC (armed)", B747_door_mode_auto_all_CMDhandler)
B747CMD_door_mode_manual_all        = deferred_command("laminar/B747/door/mode_manual_all", "Entry and upper deck doors to MANUAL (disarmed)", B747_door_mode_manual_all_CMDhandler)



--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--

B747DR_checklist_marker_capt        = deferred_dataref("laminar/B747/safety/checklist_marker_capt", "number", B747_checklist_marker_capt_DRhandler)
B747DR_checklist_marker_fo          = deferred_dataref("laminar/B747/safety/checklist_marker_fo", "number", B747_checklist_marker_fo_DRhandler)



-- NO SMOKING DIAL
B747CMD_sfty_no_smoke_sel_dial_up   = deferred_command("laminar/B747/safety/no_smoking/sel_dial_up", "No Smoking Selector Dial Up", B747_sfty_no_smoke_sel_dial_up_CMDhandler)
B747CMD_sfty_no_smoke_sel_dial_dn   = deferred_command("laminar/B747/safety/no_smoking/sel_dial_dn", "No Smoking Selector Dial Down", B747_sfty_no_smoke_sel_dial_dn_CMDhandler)


-- SEAT BELTS DIAL
B747CMD_sfty_seat_belts_sel_dial_up = deferred_command("laminar/B747/safety/seat_belts/sel_dial_up", "Seat Belts Selector Dial Up", B747_sfty_seat_belts_sel_dial_up_CMDhandler)
B747CMD_sfty_seat_belts_sel_dial_dn = deferred_command("laminar/B747/safety/seat_belts/sel_dial_dn", "Seat Belts Selector Dial_Down", B747_sfty_seat_belts_sel_dial_dn_CMDhandler)



-- AI
B747CMD_ai_safety_quick_start			= deferred_command("laminar/B747/ai/safety_quick_start", "number", B747_ai_safety_quick_start_CMDhandler)





