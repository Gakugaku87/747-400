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

B747DR_init_fltctrls_CD         = deferred_dataref("laminar/B747/fltctrls/init_CD", "number")
B747DR_parking_brake_ratio      = deferred_dataref("laminar/B747/flt_ctrls/parking_brake_ratio", "number")
B747DR_CAS_memo_status          = find_dataref("laminar/B747/CAS/memo_status")

B747DR_engines_numClimb         = deferred_dataref("laminar/B747/flt_ctrls/numClimb", "number")
B747DR_engines_numLeverClimb    = deferred_dataref("laminar/B747/flt_ctrls/numLeverClimb", "number")

--*************************************************************************************--
--** 				       READ-WRITE CUSTOM DATAREF HANDLERS     	        	     **--
--*************************************************************************************--
----- SPEEDBRAKE LEVER ------------------------------------------------------------------
--local B747_sb_manip_changed = 0
B747_sb_manip_changed = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever_changed", "number")
B747DR_speedbrake_auto_ext      = deferred_dataref("B747DR/speedbrake/auto_extend", "number")

--local B747_speedbrake_stop = 0
B747_speedbrake_stop = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_stop", "number")
simDR_speedbrake_ratio_control  = find_dataref("sim/cockpit2/controls/speedbrake_ratio")

-- the pilot's moves of the speedbrake lever snap into the DN and ARM
-- detents and stop at the flight detent in the air; X-Plane's speedbrake
-- ratio and SPEEDBRAKE ARMED: the speedbrake model (B747.45.xt.speedbrake.lua,
-- 4-1 step 3; before, ARM wrote X-Plane's -0.5, its own auto speedbrake)
function B747_speedbrake_manip_timeout()
	if B747DR_speedbrake_lever < 0.01 then
		B747DR_speedbrake_lever = 0.0
	-- ARMED DETENT
	elseif B747DR_speedbrake_lever < 0.30 and
		B747DR_speedbrake_lever > 0.07
	then

		B747DR_speedbrake_lever = 0.125 
	-- ALL OTHER POSITIONS    
	else
		B747DR_speedbrake_lever = math.min(1.0 - (B747_speedbrake_stop * 0.47), B747DR_speedbrake_lever)
	end	
	B747_sb_manip_changed = 0 
end
function B747_rescale(in1, out1, in2, out2, x)

    if x < in1 then return out1 end
    if x > in2 then return out2 end
    return out1 + (out2 - out1) * (x - in1) / (in2 - in1)

end
function B747_speedbrake_lever_DRhandler()
	if  B747DR_speedbrake_auto_ext==0 then
		B747_sb_manip_changed = 1 
		-- DOWN DETENT
		if B747DR_speedbrake_lever < 0.01 then
			B747DR_speedbrake_lever = 0.0
		-- ARMED DETENT
		elseif B747DR_speedbrake_lever < 0.30 and
			B747DR_speedbrake_lever > 0.07
		then

			B747DR_speedbrake_lever = 0.125 
		-- ALL OTHER POSITIONS    
		else
			B747DR_speedbrake_lever = math.min(1.0 - (B747_speedbrake_stop * 0.47), B747DR_speedbrake_lever)
		end	   
		
		
		if is_timer_scheduled(B747_speedbrake_manip_timeout) then
			stop_timer(B747_speedbrake_manip_timeout)    
		end	
		run_after_time(B747_speedbrake_manip_timeout, 1.0)
	end

end

	

----- SPEEDBRAKE HANDLE -----------------------------------------------------------------
B747DR_speedbrake_lever     	= deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever", "number", B747_speedbrake_lever_DRhandler)
function B747_speedbrake_lever_detent_DRhandler() end
B747DR_speedbrake_lever_detent  = deferred_dataref("laminar/B747/flt_ctrls/speedbrake_lever_detent", "number", B747_speedbrake_lever_detent_DRhandler)

----- FLAP HANDLE -----------------------------------------------------------------------
function B747_flap_lever_detent_DRhandler() end
B747DR_flap_lever_detent		= deferred_dataref("laminar/B747/flt_ctrls/flap_lever_detent", "number", B747_flap_lever_detent_DRhandler)

-- the flap control units (B747.45.xt.fcu.lua; 4-1): the trailing edge
-- panels L OB, L IB, R IB, R OB in degrees and the leading edge groups A
-- (inboard and midspan) and B (outboard) as X-Plane's slat ratios, which
-- the hydraulics module puts on the surfaces; each LE group on each wing
-- (inboard L, R, midspan L, R, outboard L, R); the drives' modes (0
-- primary, 1 secondary, 2 stopped) of the TE groups IB, OB and the LE
-- groups; the TE moving and out (to the demand pumps)
B747DR_fcu_te_deg               = deferred_dataref("laminar/B747/flt_ctrls/fcu/te_deg", "array[4]")
B747DR_fcu_slat                 = deferred_dataref("laminar/B747/flt_ctrls/fcu/slat", "array[2]")
B747DR_fcu_le                   = deferred_dataref("laminar/B747/flt_ctrls/fcu/le", "array[6]")
B747DR_fcu_te_mode              = deferred_dataref("laminar/B747/flt_ctrls/fcu/te_mode", "array[2]")
B747DR_fcu_le_mode              = deferred_dataref("laminar/B747/flt_ctrls/fcu/le_mode", "array[3]")
B747DR_fcu_te_moving            = deferred_dataref("laminar/B747/flt_ctrls/fcu/te_moving", "number")
B747DR_fcu_te_down              = deferred_dataref("laminar/B747/flt_ctrls/fcu/te_down", "number")
-- failures X-Plane does not have (1 failed): the FCUs L, C, R; the TE
-- groups' (IB, OB) hydraulic and electric drives and a broken drive shaft
-- (the left side stuck: asymmetry); the LE groups' (inboard, midspan,
-- outboard) pneumatic and electric drives
B747DR_fcu_fail_fcu             = deferred_dataref("laminar/B747/flt_ctrls/fail/fcu", "array[3]")
B747DR_fcu_fail_te_primary      = deferred_dataref("laminar/B747/flt_ctrls/fail/te_primary", "array[2]")
B747DR_fcu_fail_te_secondary    = deferred_dataref("laminar/B747/flt_ctrls/fail/te_secondary", "array[2]")
B747DR_fcu_fail_te_stuck        = deferred_dataref("laminar/B747/flt_ctrls/fail/te_stuck", "array[2]")
B747DR_fcu_fail_le_primary      = deferred_dataref("laminar/B747/flt_ctrls/fail/le_primary", "array[3]")
B747DR_fcu_fail_le_secondary    = deferred_dataref("laminar/B747/flt_ctrls/fail/le_secondary", "array[3]")
-- the SRMs (B747.45.xt.srm.lua; 4-1 step 2a): failures X-Plane does not
-- have (1 failed): SRM L, R; the outboard aileron lockout actuator stuck;
-- the upper, lower rudder ratio changer actuators stuck
B747DR_srm_fail_srm             = deferred_dataref("laminar/B747/flt_ctrls/fail/srm", "array[2]")
B747DR_srm_fail_lockout         = deferred_dataref("laminar/B747/flt_ctrls/fail/lockout_actuator", "number")
B747DR_srm_fail_rrc             = deferred_dataref("laminar/B747/flt_ctrls/fail/rrc", "array[2]")
-- the stabilizer trim (B747.45.xt.srm.lua; step 2b): the position in trim
-- units (0-15); the cutout switches 2, 3 (-1 CUTOUT, 0 AUTO, 1 ON) and the
-- alternate switches (-1 nose down, 0, 1 nose up), which the 3D does not
-- have; failures X-Plane does not have: the trim control module of
-- hydraulic system 2, 3 does not drive (1), or drives by itself (-1 nose
-- down, 1 nose up)
B747DR_srm_stab_units           = deferred_dataref("laminar/B747/flt_ctrls/stab_trim/units", "number")
B747DR_srm_speed_trim           = deferred_dataref("laminar/B747/flt_ctrls/stab_trim/speed_trim", "number")    -- 1: speed trim engaged (step 2c)
B747DR_srm_cutout_sw            = deferred_dataref("laminar/B747/flt_ctrls/stab_trim/cutout_sw", "array[2]")
B747DR_srm_altn_sw              = deferred_dataref("laminar/B747/flt_ctrls/stab_trim/altn_sw", "number")
B747DR_srm_fail_stab_actuator   = deferred_dataref("laminar/B747/flt_ctrls/fail/stab_actuator", "array[2]")
B747DR_srm_fail_stab_runaway    = deferred_dataref("laminar/B747/flt_ctrls/fail/stab_runaway", "array[2]")
-- the speedbrakes (B747.45.xt.speedbrake.lua; step 3): the auto speedbrake
-- actuator does not move (1)
B747DR_sb_fail                  = deferred_dataref("laminar/B747/flt_ctrls/fail/auto_speedbrake", "number")
B747CMD_altn_stab_trim_up       = deferred_command("laminar/B747/flt_ctrls/altn_stab_trim_up", "Alternate Stabilizer Trim Nose Up", B747_altn_stab_trim_up_CMDhandler)
B747CMD_altn_stab_trim_dn       = deferred_command("laminar/B747/flt_ctrls/altn_stab_trim_dn", "Alternate Stabilizer Trim Nose Down", B747_altn_stab_trim_dn_CMDhandler)
B747CMD_stab_cutout_2_up        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_2_up", "Stab Trim Cutout 2 toward ON", B747_stab_cutout_2_up_CMDhandler)
B747CMD_stab_cutout_2_dn        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_2_dn", "Stab Trim Cutout 2 toward CUTOUT", B747_stab_cutout_2_dn_CMDhandler)
B747CMD_stab_cutout_3_up        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_3_up", "Stab Trim Cutout 3 toward ON", B747_stab_cutout_3_up_CMDhandler)
B747CMD_stab_cutout_3_dn        = deferred_command("laminar/B747/flt_ctrls/stab_trim/cutout_3_dn", "Stab Trim Cutout 3 toward CUTOUT", B747_stab_cutout_3_dn_CMDhandler)

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


B747CMD_parking_brake_on            = deferred_command("laminar/B747/flt_ctrls/parking_brake_on", "Parking brake on", B747CMD_parking_brake_on_CMDhandler)
B747CMD_parking_brake_off            = deferred_command("laminar/B747/flt_ctrls/parking_brake_off", "Parking brake off", B747CMD_parking_brake_off_CMDhandler)
B747CMD_parking_brake_toggle            = deferred_command("laminar/B747/flt_ctrls/parking_brake_toggle", "Parking brake toggle", B747CMD_parking_brake_toggle_CMDhandler)
