--[[
*****************************************************************************************
* Program Script Name	:	B747.34.nav
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2026-10-25						The navigation sensors (notes/ATA-34.md, 5-1)
*
*****************************************************************************************
--]]

--replace create command
function deferred_command(name,desc,nilFunc)
	c = XLuaCreateCommand(name,desc)
	return nil
end
--replace create_dataref
function deferred_dataref(name,type,notifier)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type)
end

-- The air data (B747.34.airdata_model.lua, ARCHITECTURE.md): the ADC on each
-- pilot's displays (1 L, 2 C, 3 R), each ADC valid (power, not failed) and
-- each pilot's air data valid (for the PFD's SPD, ALT and MACH flags), the
-- altitude alert's white box (approaching) and amber box (departing), each
-- PFD's altitude (ft, that pilot's baro setting) and Mach from the selected
-- ADC; failures (L and R also from X-Plane's ADC failures): each ADC.
B747DR_airdata_src_capt         = deferred_dataref("laminar/B747/airdata/src_capt", "number")
B747DR_airdata_src_fo           = deferred_dataref("laminar/B747/airdata/src_fo", "number")
B747DR_airdata_valid            = deferred_dataref("laminar/B747/airdata/valid", "array[3]")
B747DR_airdata_valid_capt       = deferred_dataref("laminar/B747/airdata/valid_capt", "number")
B747DR_airdata_valid_fo         = deferred_dataref("laminar/B747/airdata/valid_fo", "number")
B747DR_airdata_alt_advise       = deferred_dataref("laminar/B747/airdata/alt_advise", "number")
B747DR_airdata_alt_alert        = deferred_dataref("laminar/B747/airdata/alt_alert", "number")
B747DR_airdata_alt_capt         = deferred_dataref("laminar/B747/airdata/alt_capt", "number")
B747DR_airdata_alt_fo           = deferred_dataref("laminar/B747/airdata/alt_fo", "number")
B747DR_airdata_mach_capt        = deferred_dataref("laminar/B747/airdata/mach_capt", "number")
B747DR_airdata_mach_fo          = deferred_dataref("laminar/B747/airdata/mach_fo", "number")
B747DR_airdata_fail             = deferred_dataref("laminar/B747/airdata/fail/adc", "array[3]")

-- The IRS (B747.34.irs_model.lua, ARCHITECTURE.md), each IRU L, C, R: its
-- mode (0 off, 1 aligning or aligned at ALIGN, 2 NAV, 3 ATT, 4 failed), the
-- seconds left of its alignment, attitude, heading and navigation valid, its
-- position (degrees), ground speed (kt) and heading (magnetic; the entered
-- one in ATT); excessive motion, the FMC's SET IRS POS boxes (an IRU wants a
-- position), an IRU aligning, the SET HDG dashes (an IRU in ATT), the ON BAT
-- light. The FMC's entries (each new entry adds one to its seq): the present
-- position and SET HDG. Failures: each IRU (L and R also from X-Plane's
-- long-range navigation failures).
B747DR_irs_mode                 = deferred_dataref("laminar/B747/irs/mode", "array[3]")
B747DR_irs_time_left            = deferred_dataref("laminar/B747/irs/time_left", "array[3]")
B747DR_irs_att_valid            = deferred_dataref("laminar/B747/irs/att_valid", "array[3]")
B747DR_irs_hdg_valid            = deferred_dataref("laminar/B747/irs/hdg_valid", "array[3]")
B747DR_irs_nav_valid            = deferred_dataref("laminar/B747/irs/nav_valid", "array[3]")
B747DR_irs_lat                  = deferred_dataref("laminar/B747/irs/lat", "array[3]")
B747DR_irs_lon                  = deferred_dataref("laminar/B747/irs/lon", "array[3]")
B747DR_irs_gs                   = deferred_dataref("laminar/B747/irs/gs", "array[3]")
B747DR_irs_hdg                  = deferred_dataref("laminar/B747/irs/hdg", "array[3]")
B747DR_irs_motion               = deferred_dataref("laminar/B747/irs/motion", "number")
B747DR_irs_set_pos              = deferred_dataref("laminar/B747/irs/set_pos", "number")
B747DR_irs_aligning             = deferred_dataref("laminar/B747/irs/aligning", "number")
B747DR_irs_set_hdg_shown        = deferred_dataref("laminar/B747/irs/set_hdg_shown", "number")
B747DR_irs_on_bat               = deferred_dataref("laminar/B747/irs/on_bat", "number")
B747DR_irs_pos_entry_seq        = deferred_dataref("laminar/B747/irs/pos_entry_seq", "number")
B747DR_irs_pos_entry_lat        = deferred_dataref("laminar/B747/irs/pos_entry_lat", "number")
B747DR_irs_pos_entry_lon        = deferred_dataref("laminar/B747/irs/pos_entry_lon", "number")
B747DR_irs_set_hdg_seq          = deferred_dataref("laminar/B747/irs/set_hdg_seq", "number")
B747DR_irs_set_hdg              = deferred_dataref("laminar/B747/irs/set_hdg", "number")
B747DR_irs_fail                 = deferred_dataref("laminar/B747/irs/fail/iru", "array[3]")
-- a quick start: every IRU at NAV aligned at once
B747CMD_irs_align_now           = deferred_command("laminar/B747/irs/align_now", "IRS: IRUs at NAV aligned at once (quick start)", null_command)

-- The GPS (B747.34.gps_model.lua), L and R: navigating (its position valid);
-- failures (also from X-Plane's GPS failures).
B747DR_gps_valid                = deferred_dataref("laminar/B747/gps/valid", "array[2]")
B747DR_gps_fail                 = deferred_dataref("laminar/B747/gps/fail", "array[2]")

-- The radio altimeters (B747.34.ra_model.lua): each one working (L, C, R);
-- each PFD's radio altitude: digits shown (working, below 2,500 ft), the RA
-- flag (none working), the radio altitude (ft, not rounded; the rounded
-- Captain's is laminar/B747/efis/radio_altitude, fltInst's) and the F/O's
-- rounded one; the GPWC's radio altitude and its validity. Failures: each
-- radio altimeter (L and R also from X-Plane's).
B747DR_ra_valid                 = deferred_dataref("laminar/B747/ra/valid", "array[3]")
B747DR_ra_capt_show             = deferred_dataref("laminar/B747/ra/capt/show", "number")
B747DR_ra_capt_flag             = deferred_dataref("laminar/B747/ra/capt/flag", "number")
B747DR_ra_capt_value            = deferred_dataref("laminar/B747/ra/capt/value", "number")
B747DR_ra_fo_show               = deferred_dataref("laminar/B747/ra/fo/show", "number")
B747DR_ra_fo_flag               = deferred_dataref("laminar/B747/ra/fo/flag", "number")
B747DR_ra_fo_value              = deferred_dataref("laminar/B747/ra/fo/value", "number")
B747DR_ra_efis_fo               = deferred_dataref("laminar/B747/efis/radio_altitude_fo", "number")
B747DR_ra_gpwc                  = deferred_dataref("laminar/B747/ra/gpwc", "number")
B747DR_ra_gpwc_valid            = deferred_dataref("laminar/B747/ra/gpwc_valid", "number")
B747DR_ra_fail                  = deferred_dataref("laminar/B747/ra/fail", "array[3]")

-- The GPWS (B747.34.gpws_model.lua): the voice (0 none, 1 SINK RATE, 2 PULL
-- UP, 3 TERRAIN, 4 DON'T SINK, 5 TOO LOW GEAR, 6 TOO LOW FLAPS, 7 TOO LOW
-- TERRAIN, 8 GLIDE SLOPE, 9 BANK ANGLE, 10 WINDSHEAR) and the callout (the
-- radio altitude called, 1 APPROACHING MINIMUMS, 2 MINIMUMS; 0 between) the
-- .snd plays; the GND PROX light, PULL UP and WINDSHEAR on the PFDs, the
-- warning (PULL UP or WINDSHEAR: master WARNING), any alert (to TCAS), the
-- glide slope alert inhibited; the G/S INHB pushes (the manipulators add one
-- for each); a GPWC failure.
B747DR_gpws_voice               = deferred_dataref("laminar/B747/gpws/voice", "number")
B747DR_gpws_callout             = deferred_dataref("laminar/B747/gpws/callout", "number")
-- the last callout, held until the next (for the tests: the callout itself lasts 0.3 s)
B747DR_gpws_last_callout        = deferred_dataref("laminar/B747/gpws/last_callout", "number")
B747DR_gpws_gnd_prox_light      = deferred_dataref("laminar/B747/gpws/gnd_prox_light", "number")
B747DR_gpws_pull_up             = deferred_dataref("laminar/B747/gpws/pull_up", "number")
B747DR_gpws_windshear           = deferred_dataref("laminar/B747/gpws/windshear", "number")
B747DR_gpws_warning             = deferred_dataref("laminar/B747/gpws/warning", "number")
B747DR_gpws_alert               = deferred_dataref("laminar/B747/gpws/alert", "number")
B747DR_gpws_gs_inhibited        = deferred_dataref("laminar/B747/gpws/gs_inhibited", "number")
B747DR_gpws_gs_inhb_pushes      = deferred_dataref("laminar/B747/gpws/gs_inhb_pushes", "number")
B747DR_gpws_fail                = deferred_dataref("laminar/B747/gpws/fail", "number")
