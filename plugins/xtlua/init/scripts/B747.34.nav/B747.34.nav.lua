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

-- The transponders and the TCAS (B747.34.tcas_model.lua): failures for the
-- tests (L, R; the TCAS computer); the voice the .snd plays (0 none, 1
-- TRAFFIC TRAFFIC, 2 CLIMB CLIMB, 3 CLIMB CROSSING CLIMB, 4 INCREASE CLIMB,
-- 5 CLIMB CLIMB NOW, 6 DESCEND DESCEND, 7 DESCEND CROSSING DESCEND, 8
-- INCREASE DESCENT, 9 DESCEND DESCEND NOW, 10 MONITOR VERTICAL SPEED, 11
-- MAINTAIN VERTICAL SPEED MAINTAIN, 12 MAINTAIN VERTICAL SPEED CROSSING
-- MAINTAIN, 13 ADJUST VERTICAL SPEED ADJUST, 14 CLEAR OF CONFLICT; held 0.5 s)
-- and the last one (held until the next, for the tests); each X-Plane TCAS
-- target's ND symbol (0 none, 1 other, 2 proximate, 3 TA, 4 RA); the TCAS's
-- state (working, failed, RAs available, TRAFFIC 0/1 amber/2 red); the PFDs'
-- RA guidance (shown; the red vertical speed regions below vs_lo and above
-- vs_hi, fpm, and the RA pitch regions' edges, deg, each with an on flag);
-- each ND's TCAS messages (TCAS FAIL, TRAFFIC and OFFSCALE 0/1 amber/2 red,
-- TA ONLY) and whether it draws traffic; the TFC switches' pushes (the
-- switches add one for each). laminar/B747/nd/capt|fo/tfc and tcas_off are
-- the panel's, created by xtlua_keysystems.
B747DR_xpdr_fail                = deferred_dataref("laminar/B747/xpdr/fail", "array[2]")
B747DR_xpdr_panel_on            = deferred_dataref("laminar/B747/xpdr/panel_on", "number")
B747DR_tcas_fail                = deferred_dataref("laminar/B747/tcas/fail", "number")
B747DR_tcas_voice               = deferred_dataref("laminar/B747/tcas/voice", "number")
B747DR_tcas_last_voice          = deferred_dataref("laminar/B747/tcas/last_voice", "number")
B747DR_tcas_sym                 = deferred_dataref("laminar/B747/tcas/sym", "array[64]")
B747DR_tcas_operating           = deferred_dataref("laminar/B747/tcas/operating", "number")
B747DR_tcas_failed              = deferred_dataref("laminar/B747/tcas/failed", "number")
B747DR_tcas_ra_mode             = deferred_dataref("laminar/B747/tcas/ra_mode", "number")
B747DR_tcas_traffic             = deferred_dataref("laminar/B747/tcas/traffic", "number")
B747DR_tcas_pfd_ra              = deferred_dataref("laminar/B747/tcas/pfd/ra", "number")
B747DR_tcas_pfd_lo_on           = deferred_dataref("laminar/B747/tcas/pfd/lo_on", "number")
B747DR_tcas_pfd_hi_on           = deferred_dataref("laminar/B747/tcas/pfd/hi_on", "number")
B747DR_tcas_pfd_vs_lo           = deferred_dataref("laminar/B747/tcas/pfd/vs_lo", "number")
B747DR_tcas_pfd_vs_hi           = deferred_dataref("laminar/B747/tcas/pfd/vs_hi", "number")
B747DR_tcas_pfd_pitch_lo        = deferred_dataref("laminar/B747/tcas/pfd/pitch_lo", "number")
B747DR_tcas_pfd_pitch_hi        = deferred_dataref("laminar/B747/tcas/pfd/pitch_hi", "number")
B747DR_tcas_pfd_vs_red          = deferred_dataref("laminar/B747/tcas/pfd/vs_red", "number")
B747DR_nd_capt_tcas_fail        = deferred_dataref("laminar/B747/nd/capt/tcas_fail", "number")
B747DR_nd_fo_tcas_fail          = deferred_dataref("laminar/B747/nd/fo/tcas_fail", "number")
B747DR_nd_capt_traffic          = deferred_dataref("laminar/B747/nd/capt/traffic", "number")
B747DR_nd_fo_traffic            = deferred_dataref("laminar/B747/nd/fo/traffic", "number")
B747DR_nd_capt_offscale         = deferred_dataref("laminar/B747/nd/capt/offscale", "number")
B747DR_nd_fo_offscale           = deferred_dataref("laminar/B747/nd/fo/offscale", "number")
B747DR_nd_capt_ta_only          = deferred_dataref("laminar/B747/nd/capt/ta_only", "number")
B747DR_nd_fo_ta_only            = deferred_dataref("laminar/B747/nd/fo/ta_only", "number")
B747DR_nd_capt_tcas_show        = deferred_dataref("laminar/B747/nd/capt/tcas_show", "number")
B747DR_nd_fo_tcas_show          = deferred_dataref("laminar/B747/nd/fo/tcas_show", "number")
B747DR_nd_capt_tfc_pushes       = deferred_dataref("laminar/B747/nd/traffic/capt/pushes", "number")
B747DR_nd_fo_tfc_pushes         = deferred_dataref("laminar/B747/nd/traffic/fo/pushes", "number")

-- The weather radar control (B747.34.wxr_model.lua, 5-1 step 5c): the 570
-- panel's TFR, TEST, LR/T and RR/T switches (TILT, MAP GAIN, WX, WX+T, MAP and
-- GCS are X-Plane's commands, replaced in B747.34.xt.wxr.lua); the panel's
-- lamps for the lighting module: each side's lit mode switch (1 WX, 2 WX+T,
-- 3 MAP, 4 TFR, 0 none) and GCS, TEST, the lit R/T switch (1 L, 2 R, 0 none).
B747CMD_wxr_test                = deferred_command("laminar/B747/wxr/buttons/test", "WXR Test", null_command)
B747CMD_wxr_rr                  = deferred_command("laminar/B747/wxr/buttons/rr", "WXR RR", null_command)
B747CMD_wxr_lr                  = deferred_command("laminar/B747/wxr/buttons/lr", "WXR LR", null_command)
B747CMD_wxr_cpt_tfr             = deferred_command("laminar/B747/wxr/buttons/cpt_ftr", "WXR CPT TFR", null_command)
B747CMD_wxr_fo_tfr              = deferred_command("laminar/B747/wxr/buttons/fo_ftr", "WXR FO TFR", null_command)
B747DR_wxr_lamp_sel             = deferred_dataref("laminar/B747/wxr/lamp/sel", "array[2]")
B747DR_wxr_lamp_gcs             = deferred_dataref("laminar/B747/wxr/lamp/gcs", "array[2]")
B747DR_wxr_lamp_test            = deferred_dataref("laminar/B747/wxr/lamp/test", "number")
B747DR_wxr_lamp_rt              = deferred_dataref("laminar/B747/wxr/lamp/rt", "number")
