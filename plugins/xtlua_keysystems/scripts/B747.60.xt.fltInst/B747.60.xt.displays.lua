-- The display units and EIUs (5-2 step 1; notes/ATA-31.md §10): the INBD and
-- LWR display selectors, the buses, the unit and EIU failures and the EIU
-- selectors go to the model (B747.60.display_model.lua); each display's
-- position (flt_inst/display/*_pos) and power (electrical/display_has_power
-- [0..5]) come back for the panel, the unit showing each display for the
-- lighting module's brightness, the EIU in use and >EIU LEFT. Replaces the
-- old table of selector combinations (fltInstsetCRTs). Step 2: the FLT DIR
-- and NAV source selectors and the EFIS and EICAS control panels in, the
-- messages >SOURCE SEL EIU, F/D, NAV, >EFIS CONTROL L, R, >EFIS/EICAS C/P out.
-- Step 4a: the PFD sources model (B747.60.pfd_model.lua) with the IRUs, the
-- IRS selectors, the NAV source and each pilot's air data in; each PFD's
-- attitude, heading scale, track and vertical speed shown and the VERT flag
-- (laminar/B747/pfd/capt/*, fo/*) out for the panel. Step 4b: each side's
-- barometric setting, altitude and the MCP altitude, and the FMC's
-- transition altitude in; the amber box (pfd/capt|fo/baro_alert) out.
-- Step 4d: the FPV switches' selection, X-Plane's flight path, track and
-- each side's attitude in; the flight path vector (pfd/capt|fo/fpv_show,
-- fpv_flag, fpv_x, fpv_y) and the PITCH and ROLL flags (pfd/pitch_flag,
-- roll_flag) out.
-- Step 4e: the PFD ILS model (B747.60.pfd_ils_model.lua) with each side's
-- ILS receiver (X-Plane's NAV1 and NAV2 through the pilot's and copilot's
-- HSI, their failures and buses), roll, track, radio altitude and flight
-- director, and the AFDS modes in; each PFD's approach reference, localizer
-- and glideslope scales, pointers and flags and the rising runway
-- (pfd/capt|fo/ils_show, loc_scale, loc_ptr, loc_flag, gs_scale, gs_ptr,
-- gs_flag, rwy_show) out.
-- Step 5a: the ND model (B747.60.nd_model.lua) with each ND's mode, that
-- side's heading, track and airspeed, the PFD model's heading and track,
-- the IRUs in NAV, the wind, the MCP heading and the AFDS roll mode in;
-- X-Plane's map mode for each side and each ND's rose, flags, heading
-- pointer, selected heading bug and line and wind arrow (nd/capt|fo/*) out.
-- Step 5b: each PFD's ILS from the receiver of the EIU in use (X-Plane's
-- NAV1 and NAV2 directly), its deviations (pfd/capt|fo/ils_rx, loc_dots,
-- gs_dots), the approach reference's identifier or frequency (pfd/capt|fo/
-- ils_ref) and >SNGL SOURCE ILS out; each ND's APP mode on the same
-- receiver (nd/capt|fo/loc_scale, loc_ptr, loc_flag, gs_scale, gs_ptr,
-- gs_flag, crs, crs_deg, dme, dme_nm, ils_ref; nd/dashes) out; the VOR
-- mode's reference VOR (nd/capt|fo/vor_rx, vor_flag, vor_dev, vor_crs,
-- vor_crs_deg, to_from, vor_dme, vor_dme_nm, vor_ref) out; the VOR and
-- ADF bearing pointers and the lower corner blocks (nd/capt|fo/ptr_l,
-- ptr_r, brg_l, brg_r, rad_l, rad_r, rad_l_flag, rad_r_flag, rad_l_dme,
-- rad_r_dme; nd/vor_l_ref, vor_r_ref, adf_l_ref, adf_r_ref) out.
-- dofile'd from B747.60.xt.fltInst.lua after B747.60.xt.fltInst02.lua.

dofile("B747.60.display_model.lua")
dofile("B747.60.pfd_model.lua")
dofile("B747.60.pfd_ils_model.lua")
dofile("B747.60.nd_model.lua")
local DM = B747_display_model
local PM = B747_pfd_model
local IM = B747_pfd_ils_model
local NM = B747_nd_model

B747DR_dsp_bus_stby_apu         = find_dataref("laminar/B747/electrical/bus/stby_apu")
B747DR_dsp_bus_stby_main        = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_dsp_bus_xfr_capt         = find_dataref("laminar/B747/electrical/bus/xfr_capt")
B747DR_dsp_bus_xfr_fo           = find_dataref("laminar/B747/electrical/bus/xfr_fo")
B747DR_dsp_bus_any_ac           = find_dataref("laminar/B747/electrical/bus/any_ac")
B747DR_dsp_pri_air              = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_dsp_unit_fail            = find_dataref("laminar/B747/displays/fail")
B747DR_dsp_eiu_fail             = find_dataref("laminar/B747/eiu/fail")
B747DR_dsp_eiu_used             = find_dataref("laminar/B747/eiu/used")
B747DR_dsp_content_unit         = find_dataref("laminar/B747/displays/content_unit")
B747DR_dsp_display_power        = find_dataref("laminar/B747/electrical/display_has_power")
B747DR_dsp_efis_fail            = find_dataref("laminar/B747/efis/fail")
B747DR_dsp_dsp_fail             = find_dataref("laminar/B747/dsp/fail")
B747DR_dsp_irs_att_valid        = find_dataref("laminar/B747/irs/att_valid")
B747DR_dsp_irs_hdg_valid        = find_dataref("laminar/B747/irs/hdg_valid")
B747DR_dsp_irs_nav_valid        = find_dataref("laminar/B747/irs/nav_valid")
B747DR_dsp_irs_src_capt         = find_dataref("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos")
B747DR_dsp_irs_src_fo           = find_dataref("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos")
B747DR_dsp_air_valid_capt       = find_dataref("laminar/B747/airdata/valid_capt")
B747DR_dsp_air_valid_fo         = find_dataref("laminar/B747/airdata/valid_fo")
B747DR_dsp_pfd_att_capt         = find_dataref("laminar/B747/pfd/capt/att")
B747DR_dsp_pfd_hdg_capt         = find_dataref("laminar/B747/pfd/capt/hdg")
B747DR_dsp_pfd_trk_capt         = find_dataref("laminar/B747/pfd/capt/trk")
B747DR_dsp_pfd_vsi_capt         = find_dataref("laminar/B747/pfd/capt/vsi")
B747DR_dsp_pfd_vert_capt        = find_dataref("laminar/B747/pfd/capt/vert")
B747DR_dsp_pfd_att_fo           = find_dataref("laminar/B747/pfd/fo/att")
B747DR_dsp_pfd_hdg_fo           = find_dataref("laminar/B747/pfd/fo/hdg")
B747DR_dsp_pfd_trk_fo           = find_dataref("laminar/B747/pfd/fo/trk")
B747DR_dsp_pfd_vsi_fo           = find_dataref("laminar/B747/pfd/fo/vsi")
B747DR_dsp_pfd_vert_fo          = find_dataref("laminar/B747/pfd/fo/vert")
B747DR_dsp_alt_capt             = find_dataref("laminar/B747/airdata/alt_capt")
B747DR_dsp_alt_fo               = find_dataref("laminar/B747/airdata/alt_fo")
B747DR_dsp_mcp_alt              = find_dataref("laminar/B747/autopilot/heading/altitude_dial_ft")
B747DR_dsp_fms_data             = find_dataref("laminar/B747/fms/data")
B747DR_dsp_pfd_baro_alert_capt  = find_dataref("laminar/B747/pfd/capt/baro_alert")
B747DR_dsp_pfd_baro_alert_fo    = find_dataref("laminar/B747/pfd/fo/baro_alert")
simDR_dsp_vpath                 = find_dataref("sim/flightmodel/position/vpath")
simDR_dsp_hpath                 = find_dataref("sim/flightmodel/position/hpath")
simDR_dsp_psi                   = find_dataref("sim/flightmodel/position/psi")
simDR_dsp_pitch_pilot           = find_dataref("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot")
simDR_dsp_pitch_copilot         = find_dataref("sim/cockpit2/gauges/indicators/pitch_AHARS_deg_copilot")
simDR_dsp_roll_pilot            = find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot")
simDR_dsp_roll_copilot          = find_dataref("sim/cockpit2/gauges/indicators/roll_AHARS_deg_copilot")
B747DR_dsp_fpv_sel_capt         = find_dataref("laminar/B747/efis/fpv/capt/selected")
B747DR_dsp_fpv_sel_fo           = find_dataref("laminar/B747/efis/fpv/fo/selected")
B747DR_dsp_fpv_show_capt        = find_dataref("laminar/B747/pfd/capt/fpv_show")
B747DR_dsp_fpv_flag_capt        = find_dataref("laminar/B747/pfd/capt/fpv_flag")
B747DR_dsp_fpv_x_capt           = find_dataref("laminar/B747/pfd/capt/fpv_x")
B747DR_dsp_fpv_y_capt           = find_dataref("laminar/B747/pfd/capt/fpv_y")
B747DR_dsp_fpv_show_fo          = find_dataref("laminar/B747/pfd/fo/fpv_show")
B747DR_dsp_fpv_flag_fo          = find_dataref("laminar/B747/pfd/fo/fpv_flag")
B747DR_dsp_fpv_x_fo             = find_dataref("laminar/B747/pfd/fo/fpv_x")
B747DR_dsp_fpv_y_fo             = find_dataref("laminar/B747/pfd/fo/fpv_y")
B747DR_dsp_pitch_flag           = find_dataref("laminar/B747/pfd/pitch_flag")
B747DR_dsp_roll_flag            = find_dataref("laminar/B747/pfd/roll_flag")
B747DR_dsp_bus_ac               = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_dsp_ils_dots             = find_dataref("laminar/B747/autopilot/ils_dots")
simDR_dsp_nav1_fail             = find_dataref("sim/operation/failures/rel_nav1")
simDR_dsp_nav2_fail             = find_dataref("sim/operation/failures/rel_nav2")
simDR_dsp_loc_fail              = find_dataref("sim/operation/failures/rel_loc")
simDR_dsp_gs_fail               = find_dataref("sim/operation/failures/rel_gls")
simDR_dsp_nav1_hdef             = find_dataref("sim/cockpit2/radios/indicators/nav1_hdef_dots_pilot")
simDR_dsp_nav2_hdef             = find_dataref("sim/cockpit2/radios/indicators/nav2_hdef_dots_pilot")
simDR_dsp_nav1_vdef             = find_dataref("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot")
simDR_dsp_nav2_vdef             = find_dataref("sim/cockpit2/radios/indicators/nav2_vdef_dots_pilot")
simDR_dsp_nav1_loc_rx           = find_dataref("sim/cockpit2/radios/indicators/nav1_display_horizontal")
simDR_dsp_nav2_loc_rx           = find_dataref("sim/cockpit2/radios/indicators/nav2_display_horizontal")
simDR_dsp_nav1_gs_rx            = find_dataref("sim/cockpit2/radios/indicators/nav1_display_vertical")
simDR_dsp_nav2_gs_rx            = find_dataref("sim/cockpit2/radios/indicators/nav2_display_vertical")
simDR_dsp_nav1_gs_flag          = find_dataref("sim/cockpit2/radios/indicators/nav1_flag_glideslope")
simDR_dsp_nav2_gs_flag          = find_dataref("sim/cockpit2/radios/indicators/nav2_flag_glideslope")
simDR_dsp_nav1_id               = find_dataref("sim/cockpit2/radios/indicators/nav1_nav_id")
simDR_dsp_nav2_id               = find_dataref("sim/cockpit2/radios/indicators/nav2_nav_id")
simDR_dsp_nav1_freq             = find_dataref("sim/cockpit2/radios/actuators/nav1_frequency_hz")
simDR_dsp_nav2_freq             = find_dataref("sim/cockpit2/radios/actuators/nav2_frequency_hz")
B747DR_dsp_ils_ref_capt         = find_dataref("laminar/B747/pfd/capt/ils_ref")
B747DR_dsp_ils_ref_fo           = find_dataref("laminar/B747/pfd/fo/ils_ref")
simDR_dsp_nav1_has_dme          = find_dataref("sim/cockpit2/radios/indicators/nav1_has_dme")
simDR_dsp_nav2_has_dme          = find_dataref("sim/cockpit2/radios/indicators/nav2_has_dme")
simDR_dsp_nav1_dme_nm           = find_dataref("sim/cockpit2/radios/indicators/nav1_dme_distance_nm")
simDR_dsp_nav2_dme_nm           = find_dataref("sim/cockpit2/radios/indicators/nav2_dme_distance_nm")
simDR_dsp_dme_fail              = find_dataref("sim/operation/failures/rel_dme")
simDR_dsp_nav_obs               = find_dataref("sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot")
B747DR_dsp_nd_loc_scale_capt    = find_dataref("laminar/B747/nd/capt/loc_scale")
B747DR_dsp_nd_loc_ptr_capt      = find_dataref("laminar/B747/nd/capt/loc_ptr")
B747DR_dsp_nd_loc_flag_capt     = find_dataref("laminar/B747/nd/capt/loc_flag")
B747DR_dsp_nd_gs_scale_capt     = find_dataref("laminar/B747/nd/capt/gs_scale")
B747DR_dsp_nd_gs_ptr_capt       = find_dataref("laminar/B747/nd/capt/gs_ptr")
B747DR_dsp_nd_gs_flag_capt      = find_dataref("laminar/B747/nd/capt/gs_flag")
B747DR_dsp_nd_crs_capt          = find_dataref("laminar/B747/nd/capt/crs")
B747DR_dsp_nd_crs_deg_capt      = find_dataref("laminar/B747/nd/capt/crs_deg")
B747DR_dsp_nd_dme_capt          = find_dataref("laminar/B747/nd/capt/dme")
B747DR_dsp_nd_dme_nm_capt       = find_dataref("laminar/B747/nd/capt/dme_nm")
B747DR_dsp_nd_ils_ref_capt      = find_dataref("laminar/B747/nd/capt/ils_ref")
B747DR_dsp_nd_loc_scale_fo      = find_dataref("laminar/B747/nd/fo/loc_scale")
B747DR_dsp_nd_loc_ptr_fo        = find_dataref("laminar/B747/nd/fo/loc_ptr")
B747DR_dsp_nd_loc_flag_fo       = find_dataref("laminar/B747/nd/fo/loc_flag")
B747DR_dsp_nd_gs_scale_fo       = find_dataref("laminar/B747/nd/fo/gs_scale")
B747DR_dsp_nd_gs_ptr_fo         = find_dataref("laminar/B747/nd/fo/gs_ptr")
B747DR_dsp_nd_gs_flag_fo        = find_dataref("laminar/B747/nd/fo/gs_flag")
B747DR_dsp_nd_crs_fo            = find_dataref("laminar/B747/nd/fo/crs")
B747DR_dsp_nd_crs_deg_fo        = find_dataref("laminar/B747/nd/fo/crs_deg")
B747DR_dsp_nd_dme_fo            = find_dataref("laminar/B747/nd/fo/dme")
B747DR_dsp_nd_dme_nm_fo         = find_dataref("laminar/B747/nd/fo/dme_nm")
B747DR_dsp_nd_ils_ref_fo        = find_dataref("laminar/B747/nd/fo/ils_ref")
B747DR_dsp_nd_dashes            = find_dataref("laminar/B747/nd/dashes")
simDR_dsp_nav_rx                = find_dataref("sim/cockpit2/radios/indicators/nav_display_horizontal")
simDR_dsp_nav_freq              = find_dataref("sim/cockpit2/radios/actuators/nav_frequency_hz")
simDR_dsp_nav_to_from           = find_dataref("sim/cockpit2/radios/indicators/nav_flag_from_to_pilot")
simDR_dsp_nav_has_dme           = find_dataref("sim/cockpit2/radios/indicators/nav_has_dme")
simDR_dsp_nav_dme_nm            = find_dataref("sim/cockpit2/radios/indicators/nav_dme_distance_nm")
simDR_dsp_nav3_id               = find_dataref("sim/cockpit2/radios/indicators/nav3_nav_id")
simDR_dsp_nav4_id               = find_dataref("sim/cockpit2/radios/indicators/nav4_nav_id")
B747DR_dsp_radio_modes          = find_dataref("laminar/B747/radio/tuningmodes")
simDR_dsp_efis_sw_l_capt        = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_pilot")
simDR_dsp_efis_sw_r_capt        = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_pilot")
simDR_dsp_efis_sw_l_fo          = find_dataref("sim/cockpit2/EFIS/EFIS_1_selection_copilot")
simDR_dsp_efis_sw_r_fo          = find_dataref("sim/cockpit2/EFIS/EFIS_2_selection_copilot")
simDR_dsp_nav_rel               = find_dataref("sim/cockpit2/radios/indicators/nav_relative_bearing_deg")
simDR_dsp_adf1_rel              = find_dataref("sim/cockpit2/radios/indicators/adf1_relative_bearing_deg")
simDR_dsp_adf2_rel              = find_dataref("sim/cockpit2/radios/indicators/adf2_relative_bearing_deg")
simDR_dsp_adf1_id               = find_dataref("sim/cockpit2/radios/indicators/adf1_nav_id")
simDR_dsp_adf2_id               = find_dataref("sim/cockpit2/radios/indicators/adf2_nav_id")
simDR_dsp_adf1_freq             = find_dataref("sim/cockpit2/radios/actuators/adf1_frequency_hz")
simDR_dsp_adf2_freq             = find_dataref("sim/cockpit2/radios/actuators/adf2_frequency_hz")
simDR_dsp_adf1_fail             = find_dataref("sim/operation/failures/rel_adf1")
simDR_dsp_adf2_fail             = find_dataref("sim/operation/failures/rel_adf2")
B747DR_dsp_nd_ptr_l_capt        = find_dataref("laminar/B747/nd/capt/ptr_l")
B747DR_dsp_nd_ptr_r_capt        = find_dataref("laminar/B747/nd/capt/ptr_r")
B747DR_dsp_nd_brg_l_capt        = find_dataref("laminar/B747/nd/capt/brg_l")
B747DR_dsp_nd_brg_r_capt        = find_dataref("laminar/B747/nd/capt/brg_r")
B747DR_dsp_nd_rad_l_capt        = find_dataref("laminar/B747/nd/capt/rad_l")
B747DR_dsp_nd_rad_r_capt        = find_dataref("laminar/B747/nd/capt/rad_r")
B747DR_dsp_nd_rad_l_flag_capt   = find_dataref("laminar/B747/nd/capt/rad_l_flag")
B747DR_dsp_nd_rad_r_flag_capt   = find_dataref("laminar/B747/nd/capt/rad_r_flag")
B747DR_dsp_nd_rad_l_dme_capt    = find_dataref("laminar/B747/nd/capt/rad_l_dme")
B747DR_dsp_nd_rad_r_dme_capt    = find_dataref("laminar/B747/nd/capt/rad_r_dme")
B747DR_dsp_nd_ptr_l_fo          = find_dataref("laminar/B747/nd/fo/ptr_l")
B747DR_dsp_nd_ptr_r_fo          = find_dataref("laminar/B747/nd/fo/ptr_r")
B747DR_dsp_nd_brg_l_fo          = find_dataref("laminar/B747/nd/fo/brg_l")
B747DR_dsp_nd_brg_r_fo          = find_dataref("laminar/B747/nd/fo/brg_r")
B747DR_dsp_nd_rad_l_fo          = find_dataref("laminar/B747/nd/fo/rad_l")
B747DR_dsp_nd_rad_r_fo          = find_dataref("laminar/B747/nd/fo/rad_r")
B747DR_dsp_nd_rad_l_flag_fo     = find_dataref("laminar/B747/nd/fo/rad_l_flag")
B747DR_dsp_nd_rad_r_flag_fo     = find_dataref("laminar/B747/nd/fo/rad_r_flag")
B747DR_dsp_nd_rad_l_dme_fo      = find_dataref("laminar/B747/nd/fo/rad_l_dme")
B747DR_dsp_nd_rad_r_dme_fo      = find_dataref("laminar/B747/nd/fo/rad_r_dme")
B747DR_dsp_nd_vor_l_ref         = find_dataref("laminar/B747/nd/vor_l_ref")
B747DR_dsp_nd_vor_r_ref         = find_dataref("laminar/B747/nd/vor_r_ref")
B747DR_dsp_nd_adf_l_ref         = find_dataref("laminar/B747/nd/adf_l_ref")
B747DR_dsp_nd_adf_r_ref         = find_dataref("laminar/B747/nd/adf_r_ref")
-- the POS switch (step 5c): each side's POS and range, the GPS positions;
-- the symbols out
B747DR_dsp_nd_pos_sel_capt      = find_dataref("laminar/B747/nd/data/capt/pos")
B747DR_dsp_nd_pos_sel_fo        = find_dataref("laminar/B747/nd/data/fo/pos")
B747DR_dsp_nd_range_capt        = find_dataref("laminar/B747/nd/range/capt/sel_dial_pos")
B747DR_dsp_nd_range_fo          = find_dataref("laminar/B747/nd/range/fo/sel_dial_pos")
B747DR_dsp_gps_valid            = find_dataref("laminar/B747/gps/valid")
B747DR_dsp_nd_pos_iru_capt      = find_dataref("laminar/B747/nd/capt/pos_iru")
B747DR_dsp_nd_pos_gps_capt      = find_dataref("laminar/B747/nd/capt/pos_gps")
B747DR_dsp_nd_pos_rad_l_capt    = find_dataref("laminar/B747/nd/capt/pos_rad_l")
B747DR_dsp_nd_pos_rad_l_brg_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_brg")
B747DR_dsp_nd_pos_rad_l_len_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_len")
B747DR_dsp_nd_pos_rad_l_end_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_end")
B747DR_dsp_nd_pos_rad_l_tick_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_tick")
B747DR_dsp_nd_pos_rad_l_tbrg_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_tbrg")
B747DR_dsp_nd_pos_rad_l_tside_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_tside")
B747DR_dsp_nd_pos_rad_l_text_capt = find_dataref("laminar/B747/nd/capt/pos_rad_l_text")
B747DR_dsp_nd_pos_rad_r_capt    = find_dataref("laminar/B747/nd/capt/pos_rad_r")
B747DR_dsp_nd_pos_rad_r_brg_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_brg")
B747DR_dsp_nd_pos_rad_r_len_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_len")
B747DR_dsp_nd_pos_rad_r_end_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_end")
B747DR_dsp_nd_pos_rad_r_tick_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_tick")
B747DR_dsp_nd_pos_rad_r_tbrg_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_tbrg")
B747DR_dsp_nd_pos_rad_r_tside_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_tside")
B747DR_dsp_nd_pos_rad_r_text_capt = find_dataref("laminar/B747/nd/capt/pos_rad_r_text")
B747DR_dsp_nd_pos_iru_fo        = find_dataref("laminar/B747/nd/fo/pos_iru")
B747DR_dsp_nd_pos_gps_fo        = find_dataref("laminar/B747/nd/fo/pos_gps")
B747DR_dsp_nd_pos_rad_l_fo      = find_dataref("laminar/B747/nd/fo/pos_rad_l")
B747DR_dsp_nd_pos_rad_l_brg_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_l_brg")
B747DR_dsp_nd_pos_rad_l_len_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_l_len")
B747DR_dsp_nd_pos_rad_l_end_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_l_end")
B747DR_dsp_nd_pos_rad_l_tick_fo = find_dataref("laminar/B747/nd/fo/pos_rad_l_tick")
B747DR_dsp_nd_pos_rad_l_tbrg_fo = find_dataref("laminar/B747/nd/fo/pos_rad_l_tbrg")
B747DR_dsp_nd_pos_rad_l_tside_fo = find_dataref("laminar/B747/nd/fo/pos_rad_l_tside")
B747DR_dsp_nd_pos_rad_l_text_fo = find_dataref("laminar/B747/nd/fo/pos_rad_l_text")
B747DR_dsp_nd_pos_rad_r_fo      = find_dataref("laminar/B747/nd/fo/pos_rad_r")
B747DR_dsp_nd_pos_rad_r_brg_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_r_brg")
B747DR_dsp_nd_pos_rad_r_len_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_r_len")
B747DR_dsp_nd_pos_rad_r_end_fo  = find_dataref("laminar/B747/nd/fo/pos_rad_r_end")
B747DR_dsp_nd_pos_rad_r_tick_fo = find_dataref("laminar/B747/nd/fo/pos_rad_r_tick")
B747DR_dsp_nd_pos_rad_r_tbrg_fo = find_dataref("laminar/B747/nd/fo/pos_rad_r_tbrg")
B747DR_dsp_nd_pos_rad_r_tside_fo = find_dataref("laminar/B747/nd/fo/pos_rad_r_tside")
B747DR_dsp_nd_pos_rad_r_text_fo = find_dataref("laminar/B747/nd/fo/pos_rad_r_text")
B747DR_dsp_nd_vor_rx_capt       = find_dataref("laminar/B747/nd/capt/vor_rx")
B747DR_dsp_nd_vor_flag_capt     = find_dataref("laminar/B747/nd/capt/vor_flag")
B747DR_dsp_nd_vor_dev_capt      = find_dataref("laminar/B747/nd/capt/vor_dev")
B747DR_dsp_nd_vor_crs_capt      = find_dataref("laminar/B747/nd/capt/vor_crs")
B747DR_dsp_nd_vor_crs_deg_capt  = find_dataref("laminar/B747/nd/capt/vor_crs_deg")
B747DR_dsp_nd_to_from_capt      = find_dataref("laminar/B747/nd/capt/to_from")
B747DR_dsp_nd_vor_dme_capt      = find_dataref("laminar/B747/nd/capt/vor_dme")
B747DR_dsp_nd_vor_dme_nm_capt   = find_dataref("laminar/B747/nd/capt/vor_dme_nm")
B747DR_dsp_nd_vor_ref_capt      = find_dataref("laminar/B747/nd/capt/vor_ref")
B747DR_dsp_nd_vor_rx_fo         = find_dataref("laminar/B747/nd/fo/vor_rx")
B747DR_dsp_nd_vor_flag_fo       = find_dataref("laminar/B747/nd/fo/vor_flag")
B747DR_dsp_nd_vor_dev_fo        = find_dataref("laminar/B747/nd/fo/vor_dev")
B747DR_dsp_nd_vor_crs_fo        = find_dataref("laminar/B747/nd/fo/vor_crs")
B747DR_dsp_nd_vor_crs_deg_fo    = find_dataref("laminar/B747/nd/fo/vor_crs_deg")
B747DR_dsp_nd_to_from_fo        = find_dataref("laminar/B747/nd/fo/to_from")
B747DR_dsp_nd_vor_dme_fo        = find_dataref("laminar/B747/nd/fo/vor_dme")
B747DR_dsp_nd_vor_dme_nm_fo     = find_dataref("laminar/B747/nd/fo/vor_dme_nm")
B747DR_dsp_nd_vor_ref_fo        = find_dataref("laminar/B747/nd/fo/vor_ref")
B747DR_dsp_ils_rx_capt          = find_dataref("laminar/B747/pfd/capt/ils_rx")
B747DR_dsp_ils_rx_fo            = find_dataref("laminar/B747/pfd/fo/ils_rx")
B747DR_dsp_loc_dots_capt        = find_dataref("laminar/B747/pfd/capt/loc_dots")
B747DR_dsp_loc_dots_fo          = find_dataref("laminar/B747/pfd/fo/loc_dots")
B747DR_dsp_gs_dots_capt         = find_dataref("laminar/B747/pfd/capt/gs_dots")
B747DR_dsp_gs_dots_fo           = find_dataref("laminar/B747/pfd/fo/gs_dots")
B747DR_dsp_ra_capt_value        = find_dataref("laminar/B747/ra/capt/value")
B747DR_dsp_ra_capt_flag         = find_dataref("laminar/B747/ra/capt/flag")
B747DR_dsp_ra_capt_show         = find_dataref("laminar/B747/ra/capt/show")
B747DR_dsp_ra_fo_value          = find_dataref("laminar/B747/ra/fo/value")
B747DR_dsp_ra_fo_flag           = find_dataref("laminar/B747/ra/fo/flag")
B747DR_dsp_ra_fo_show           = find_dataref("laminar/B747/ra/fo/show")
B747DR_dsp_toggle_switch        = find_dataref("laminar/B747/toggle_switch/position")
B747DR_dsp_ap_cmd_L             = find_dataref("laminar/B747/autopilot/cmd_L_mode/status")
B747DR_dsp_ap_cmd_C             = find_dataref("laminar/B747/autopilot/cmd_C_mode/status")
B747DR_dsp_ap_cmd_R             = find_dataref("laminar/B747/autopilot/cmd_R_mode/status")
B747DR_dsp_fma_roll             = find_dataref("laminar/B747/autopilot/FMA/active_roll_mode")
B747DR_dsp_fma_roll_armed       = find_dataref("laminar/B747/autopilot/FMA/armed_roll_mode")
B747DR_dsp_fma_pitch            = find_dataref("laminar/B747/autopilot/FMA/active_pitch_mode")
B747DR_dsp_ils_show_capt        = find_dataref("laminar/B747/pfd/capt/ils_show")
B747DR_dsp_loc_scale_capt       = find_dataref("laminar/B747/pfd/capt/loc_scale")
B747DR_dsp_loc_ptr_capt         = find_dataref("laminar/B747/pfd/capt/loc_ptr")
B747DR_dsp_loc_flag_capt        = find_dataref("laminar/B747/pfd/capt/loc_flag")
B747DR_dsp_gs_scale_capt        = find_dataref("laminar/B747/pfd/capt/gs_scale")
B747DR_dsp_gs_ptr_capt          = find_dataref("laminar/B747/pfd/capt/gs_ptr")
B747DR_dsp_gs_flag_capt         = find_dataref("laminar/B747/pfd/capt/gs_flag")
B747DR_dsp_rwy_show_capt        = find_dataref("laminar/B747/pfd/capt/rwy_show")
B747DR_dsp_ils_show_fo          = find_dataref("laminar/B747/pfd/fo/ils_show")
B747DR_dsp_loc_scale_fo         = find_dataref("laminar/B747/pfd/fo/loc_scale")
B747DR_dsp_loc_ptr_fo           = find_dataref("laminar/B747/pfd/fo/loc_ptr")
B747DR_dsp_loc_flag_fo          = find_dataref("laminar/B747/pfd/fo/loc_flag")
B747DR_dsp_gs_scale_fo          = find_dataref("laminar/B747/pfd/fo/gs_scale")
B747DR_dsp_gs_ptr_fo            = find_dataref("laminar/B747/pfd/fo/gs_ptr")
B747DR_dsp_gs_flag_fo           = find_dataref("laminar/B747/pfd/fo/gs_flag")
B747DR_dsp_rwy_show_fo          = find_dataref("laminar/B747/pfd/fo/rwy_show")
B747DR_dsp_nd_mode_capt         = find_dataref("laminar/B747/nd/mode/capt/sel_dial_pos")
B747DR_dsp_nd_mode_fo           = find_dataref("laminar/B747/nd/mode/fo/sel_dial_pos")
simDR_dsp_hdg_pilot             = find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot")
simDR_dsp_hdg_copilot           = find_dataref("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_copilot")
simDR_dsp_trk_pilot             = find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
simDR_dsp_trk_copilot           = find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_copilot")
simDR_dsp_wind_from             = find_dataref("sim/cockpit2/gauges/indicators/wind_heading_deg_mag")
simDR_dsp_map_mode              = find_dataref("sim/cockpit2/EFIS/map_mode")
simDR_dsp_map_mode_copilot      = find_dataref("sim/cockpit2/EFIS/map_mode_copilot")
B747DR_dsp_ias_capt             = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_pilot")
B747DR_dsp_ias_fo               = find_dataref("laminar/B747/gauges/indicators/airspeed_kts_copilot")
B747DR_dsp_hdg_sel              = find_dataref("laminar/B747/autopilot/heading/degrees")
B747DR_dsp_nd_rose_capt         = find_dataref("laminar/B747/nd/capt/rose")
B747DR_dsp_nd_trk_flag_capt     = find_dataref("laminar/B747/nd/capt/trk_flag")
B747DR_dsp_nd_hdg_flag_capt     = find_dataref("laminar/B747/nd/capt/hdg_flag")
B747DR_dsp_nd_map_flag_capt     = find_dataref("laminar/B747/nd/capt/map_flag")
B747DR_dsp_nd_vtk_flag_capt     = find_dataref("laminar/B747/nd/capt/vtk_flag")
B747DR_dsp_nd_hdg_ptr_capt      = find_dataref("laminar/B747/nd/capt/hdg_ptr")
B747DR_dsp_nd_hdg_ptr_pln_capt  = find_dataref("laminar/B747/nd/capt/hdg_ptr_pln")
B747DR_dsp_nd_hdg_bug_capt      = find_dataref("laminar/B747/nd/capt/hdg_bug")
B747DR_dsp_nd_hdg_line_capt     = find_dataref("laminar/B747/nd/capt/hdg_line")
B747DR_dsp_nd_wind_capt         = find_dataref("laminar/B747/nd/capt/wind")
B747DR_dsp_nd_wind_deg_capt     = find_dataref("laminar/B747/nd/capt/wind_deg")
B747DR_dsp_nd_rose_fo           = find_dataref("laminar/B747/nd/fo/rose")
B747DR_dsp_nd_trk_flag_fo       = find_dataref("laminar/B747/nd/fo/trk_flag")
B747DR_dsp_nd_hdg_flag_fo       = find_dataref("laminar/B747/nd/fo/hdg_flag")
B747DR_dsp_nd_map_flag_fo       = find_dataref("laminar/B747/nd/fo/map_flag")
B747DR_dsp_nd_vtk_flag_fo       = find_dataref("laminar/B747/nd/fo/vtk_flag")
B747DR_dsp_nd_hdg_ptr_fo        = find_dataref("laminar/B747/nd/fo/hdg_ptr")
B747DR_dsp_nd_hdg_ptr_pln_fo    = find_dataref("laminar/B747/nd/fo/hdg_ptr_pln")
B747DR_dsp_nd_hdg_bug_fo        = find_dataref("laminar/B747/nd/fo/hdg_bug")
B747DR_dsp_nd_hdg_line_fo       = find_dataref("laminar/B747/nd/fo/hdg_line")
B747DR_dsp_nd_wind_fo           = find_dataref("laminar/B747/nd/fo/wind")
B747DR_dsp_nd_wind_deg_fo       = find_dataref("laminar/B747/nd/fo/wind_deg")
B747DR_dsp_nd_trk_line_capt     = find_dataref("laminar/B747/nd/capt/trk_line")
B747DR_dsp_nd_trk_line_fo       = find_dataref("laminar/B747/nd/fo/trk_line")
B747DR_dsp_nd_center_capt       = find_dataref("laminar/B747/nd/map_center/capt")
B747DR_dsp_nd_center_fo         = find_dataref("laminar/B747/nd/map_center/fo")
simDR_dsp_wxr_on                = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on")
simDR_dsp_wxr_on_copilot        = find_dataref("sim/cockpit2/EFIS/EFIS_weather_on_copilot")
B747DR_dsp_nd_tfc_capt          = find_dataref("laminar/B747/nd/capt/tfc")
B747DR_dsp_nd_tfc_fo            = find_dataref("laminar/B747/nd/fo/tfc")

-- the EIU selectors' positions: Captain and centre L, AUTO, C, R; F/O L, C, AUTO, R
local EIU_CAPT = {[0] = DM.EIU_L, DM.SEL_AUTO, DM.EIU_C, DM.EIU_R}
local EIU_FO = {[0] = DM.EIU_L, DM.EIU_C, DM.SEL_AUTO, DM.EIU_R}
local ADV_EIU_LEFT = 91
local ADV_EFIS_CONTROL, ADV_EFIS_EICAS_CP = {88, 89}, 90
local ADV_SOURCE_SEL_EIU, ADV_SOURCE_SEL_FD, ADV_SOURCE_SEL_NAV = 268, 269, 271
local CAU_SNGL_SOURCE_ILS = 57
-- the NAV source selectors' positions (FCOM p.1043; the F/O's knob mirrored):
-- Captain FMC L, FMC R, CDU L, CDU C; F/O CDU C, CDU R, FMC L, FMC R (0 a CDU)
local NAV_CAPT = {[0] = 1, 2, 0, 0}
local NAV_FO = {[0] = 0, 0, 1, 2}

local dsp_state = DM.new()
local dsp_inputs = DM.inputs()
local pfd_state = PM.new()
local pfd_inputs = PM.inputs()
local ils_state = IM.new()
local ils_inputs = IM.inputs()
local nd_state = NM.new()
local nd_inputs = NM.inputs()

local function msg(i, on)
    local v = on and 1 or 0
    if B747DR_CAS_advisory_status[i] ~= v then B747DR_CAS_advisory_status[i] = v end
end

local function caution(i, on)
    local v = on and 1 or 0
    if B747DR_CAS_caution_status[i] ~= v then B747DR_CAS_caution_status[i] = v end
end

local function knob(v, map)
    return map[math.max(0, math.min(3, math.floor(v + 0.5)))]
end

-- an IRS source selector (0 L, 1 C, 2 R) as the IRU
local function iru(v)
    return math.max(1, math.min(3, math.floor(v + 0.5) + 1))
end

-- each PFD's ILS (step 4e): the receiver of the EIU in use (step 5b: FCOM
-- p.1044, the EIU source selector determines each PFD's and ND's localizer
-- and glideslope receivers), EIU L ILS L, C ILS C, R ILS R. X-Plane has
-- NAV1 for ILS L (the AC standby bus) and NAV2 for ILS R (AC bus 2:
-- notes/ATA-34.md §2.1); ILS C (AC bus 1) reads NAV1, tuned alike, and has
-- no X-Plane failure (estimate). The tuning is still the stock one
-- (autopilot/ils_dots: 5-1 step 3)
local function ils_rx(eiu, default)
    local e = math.floor(eiu + 0.5)
    return (e >= 1 and e <= 3) and e or default
end

-- the approach reference's identifier, or the frequency until the
-- receiver has the station's identification (ATA34_1 p.466; X-Plane's
-- nav_id stays empty until the station is received)
local ref_freq, ref_text, ref_shown, nd_ref_shown = {}, {}, {}, {}
local dashes_written = false
local function id_or_freq(k, id, hz)
    local b = string.byte(id)
    if b and b > 32 then return id end
    if ref_freq[k] ~= hz then ref_freq[k], ref_text[k] = hz, string.format("%.2f", hz / 100) end
    return ref_text[k]
end
local function adf_ref(k, id, khz)
    local b = string.byte(id)
    if b and b > 32 then return id end
    if ref_freq[k] ~= khz then ref_freq[k], ref_text[k] = khz, string.format("%d", khz) end
    return ref_text[k]
end
local function ils_ref(k, nav2)
    if nav2 then return id_or_freq(k, simDR_dsp_nav2_id, simDR_dsp_nav2_freq) end
    return id_or_freq(k, simDR_dsp_nav1_id, simDR_dsp_nav1_freq)
end

local function ils_side(i, rx, tuned, roll, trk, ra, ra_flag, ra_show, fd)
    local nav2 = rx == 3
    i.tuned = tuned
    if rx == 1 then i.rx_fail = simDR_dsp_nav1_fail == 6 or B747DR_dsp_bus_stby_main < 0.5
    elseif nav2 then i.rx_fail = simDR_dsp_nav2_fail == 6 or B747DR_dsp_bus_ac[1] < 0.5
    else i.rx_fail = B747DR_dsp_bus_ac[0] < 0.5 end
    i.loc_fail, i.gs_fail = simDR_dsp_loc_fail == 6, simDR_dsp_gs_fail == 6
    i.loc_rx = (nav2 and simDR_dsp_nav2_loc_rx or simDR_dsp_nav1_loc_rx) > 0.5
    -- X-Plane's display_vertical stays 1 on an ILS frequency without the
    -- station; its EFIS glideslope flag marks "expected but not received"
    i.gs_rx = (nav2 and simDR_dsp_nav2_gs_rx or simDR_dsp_nav1_gs_rx) > 0.5
        and (nav2 and simDR_dsp_nav2_gs_flag or simDR_dsp_nav1_gs_flag) < 0.5
    i.loc_dots = nav2 and simDR_dsp_nav2_hdef or simDR_dsp_nav1_hdef
    i.gs_dots = nav2 and simDR_dsp_nav2_vdef or simDR_dsp_nav1_vdef
    i.roll, i.trk = roll, trk
    i.ra, i.ra_valid, i.ra_show = ra, ra_flag < 0.5, ra_show > 0.5
    i.dme_rx = (nav2 and simDR_dsp_nav2_has_dme or simDR_dsp_nav1_has_dme) > 0.5
    i.dme_fail = simDR_dsp_dme_fail == 6
    i.guidance = B747DR_dsp_ap_cmd_L + B747DR_dsp_ap_cmd_C + B747DR_dsp_ap_cmd_R > 0.5 or fd > 0.5
end

local function pfd_ils(trk_capt, trk_fo)
    local inp = ils_inputs
    local tuned = B747DR_dsp_ils_dots > 0.1
    local rx_c, rx_f = ils_rx(B747DR_dsp_eiu_used[0], 1), ils_rx(B747DR_dsp_eiu_used[1], 3)
    local ci, fi = inp.side[IM.CAPT], inp.side[IM.FO]
    ils_side(ci, rx_c, tuned, simDR_dsp_roll_pilot, trk_capt, B747DR_dsp_ra_capt_value, B747DR_dsp_ra_capt_flag,
        B747DR_dsp_ra_capt_show, B747DR_dsp_toggle_switch[23])
    ils_side(fi, rx_f, tuned, simDR_dsp_roll_copilot, trk_fo, B747DR_dsp_ra_fo_value, B747DR_dsp_ra_fo_flag,
        B747DR_dsp_ra_fo_show, B747DR_dsp_toggle_switch[24])
    if B747DR_dsp_ils_rx_capt ~= rx_c then B747DR_dsp_ils_rx_capt = rx_c end
    if B747DR_dsp_ils_rx_fo ~= rx_f then B747DR_dsp_ils_rx_fo = rx_f end
    if B747DR_dsp_loc_dots_capt ~= ci.loc_dots then B747DR_dsp_loc_dots_capt = ci.loc_dots end
    if B747DR_dsp_loc_dots_fo ~= fi.loc_dots then B747DR_dsp_loc_dots_fo = fi.loc_dots end
    if B747DR_dsp_gs_dots_capt ~= ci.gs_dots then B747DR_dsp_gs_dots_capt = ci.gs_dots end
    if B747DR_dsp_gs_dots_fo ~= fi.gs_dots then B747DR_dsp_gs_dots_fo = fi.gs_dots end
    local ref_c, ref_f = ils_ref(1, rx_c == 3), ils_ref(2, rx_f == 3)
    if ref_shown[1] ~= ref_c then ref_shown[1] = ref_c; B747DR_dsp_ils_ref_capt = ref_c end
    if ref_shown[2] ~= ref_f then ref_shown[2] = ref_f; B747DR_dsp_ils_ref_fo = ref_f end
    -- >SNGL SOURCE ILS: both pilots' displays on one localizer and
    -- glideslope receiver (FCOM p.1430, ATA34_1 p.478), here both on one EIU
    local e = B747DR_dsp_eiu_used[0]
    caution(CAU_SNGL_SOURCE_ILS, e >= 0.5 and e == B747DR_dsp_eiu_used[1])
    -- the AFDS modes (FMA: roll 2 LNAV, 3 LOC, 4 ROLLOUT; pitch 2 G/S)
    local roll = B747DR_dsp_fma_roll
    inp.loc_active = roll == 3 or roll == 4
    inp.lnav_active = roll == 2
    inp.loc_armed = B747DR_dsp_fma_roll_armed == 3
    inp.gs_active = B747DR_dsp_fma_pitch == 2
    local out = IM.update(ils_state, inp, SIM_PERIOD)
    local c, f = out[IM.CAPT], out[IM.FO]
    local v = c.ils and 1 or 0
    if B747DR_dsp_ils_show_capt ~= v then B747DR_dsp_ils_show_capt = v end
    if B747DR_dsp_loc_scale_capt ~= c.loc_scale then B747DR_dsp_loc_scale_capt = c.loc_scale end
    if B747DR_dsp_loc_ptr_capt ~= c.loc_ptr then B747DR_dsp_loc_ptr_capt = c.loc_ptr end
    v = c.loc_flag and 1 or 0
    if B747DR_dsp_loc_flag_capt ~= v then B747DR_dsp_loc_flag_capt = v end
    if B747DR_dsp_gs_scale_capt ~= c.gs_scale then B747DR_dsp_gs_scale_capt = c.gs_scale end
    if B747DR_dsp_gs_ptr_capt ~= c.gs_ptr then B747DR_dsp_gs_ptr_capt = c.gs_ptr end
    v = c.gs_flag and 1 or 0
    if B747DR_dsp_gs_flag_capt ~= v then B747DR_dsp_gs_flag_capt = v end
    v = c.rwy and 1 or 0
    if B747DR_dsp_rwy_show_capt ~= v then B747DR_dsp_rwy_show_capt = v end
    v = f.ils and 1 or 0
    if B747DR_dsp_ils_show_fo ~= v then B747DR_dsp_ils_show_fo = v end
    if B747DR_dsp_loc_scale_fo ~= f.loc_scale then B747DR_dsp_loc_scale_fo = f.loc_scale end
    if B747DR_dsp_loc_ptr_fo ~= f.loc_ptr then B747DR_dsp_loc_ptr_fo = f.loc_ptr end
    v = f.loc_flag and 1 or 0
    if B747DR_dsp_loc_flag_fo ~= v then B747DR_dsp_loc_flag_fo = v end
    if B747DR_dsp_gs_scale_fo ~= f.gs_scale then B747DR_dsp_gs_scale_fo = f.gs_scale end
    if B747DR_dsp_gs_ptr_fo ~= f.gs_ptr then B747DR_dsp_gs_ptr_fo = f.gs_ptr end
    v = f.gs_flag and 1 or 0
    if B747DR_dsp_gs_flag_fo ~= v then B747DR_dsp_gs_flag_fo = v end
    v = f.rwy and 1 or 0
    if B747DR_dsp_rwy_show_fo ~= v then B747DR_dsp_rwy_show_fo = v end

    -- each ND in APP mode (step 5b), on the same receiver: the deviation
    -- bars and scales, the flags, the course (the CDU's: FCOM p.1146), the
    -- DME, the frequency or identifier ("---" without a runway course)
    if not dashes_written then B747DR_dsp_nd_dashes = "---"; dashes_written = true end
    v = c.nd_loc_scale and 1 or 0
    if B747DR_dsp_nd_loc_scale_capt ~= v then B747DR_dsp_nd_loc_scale_capt = v end
    if B747DR_dsp_nd_loc_ptr_capt ~= c.nd_loc_ptr then B747DR_dsp_nd_loc_ptr_capt = c.nd_loc_ptr end
    v = c.nd_loc_flag and 1 or 0
    if B747DR_dsp_nd_loc_flag_capt ~= v then B747DR_dsp_nd_loc_flag_capt = v end
    v = c.nd_gs_scale and 1 or 0
    if B747DR_dsp_nd_gs_scale_capt ~= v then B747DR_dsp_nd_gs_scale_capt = v end
    if B747DR_dsp_nd_gs_ptr_capt ~= c.nd_gs_ptr then B747DR_dsp_nd_gs_ptr_capt = c.nd_gs_ptr end
    v = c.nd_gs_flag and 1 or 0
    if B747DR_dsp_nd_gs_flag_capt ~= v then B747DR_dsp_nd_gs_flag_capt = v end
    if B747DR_dsp_nd_crs_capt ~= c.nd_crs then B747DR_dsp_nd_crs_capt = c.nd_crs end
    v = simDR_dsp_nav_obs[rx_c == 3 and 1 or 0]
    if B747DR_dsp_nd_crs_deg_capt ~= v then B747DR_dsp_nd_crs_deg_capt = v end
    if B747DR_dsp_nd_dme_capt ~= c.nd_dme then B747DR_dsp_nd_dme_capt = c.nd_dme end
    v = rx_c == 3 and simDR_dsp_nav2_dme_nm or simDR_dsp_nav1_dme_nm
    if B747DR_dsp_nd_dme_nm_capt ~= v then B747DR_dsp_nd_dme_nm_capt = v end
    local s = c.nd_ref == 2 and ref_c or (c.nd_ref == 1 and "---" or "")
    if nd_ref_shown[1] ~= s then nd_ref_shown[1] = s; B747DR_dsp_nd_ils_ref_capt = s end
    v = f.nd_loc_scale and 1 or 0
    if B747DR_dsp_nd_loc_scale_fo ~= v then B747DR_dsp_nd_loc_scale_fo = v end
    if B747DR_dsp_nd_loc_ptr_fo ~= f.nd_loc_ptr then B747DR_dsp_nd_loc_ptr_fo = f.nd_loc_ptr end
    v = f.nd_loc_flag and 1 or 0
    if B747DR_dsp_nd_loc_flag_fo ~= v then B747DR_dsp_nd_loc_flag_fo = v end
    v = f.nd_gs_scale and 1 or 0
    if B747DR_dsp_nd_gs_scale_fo ~= v then B747DR_dsp_nd_gs_scale_fo = v end
    if B747DR_dsp_nd_gs_ptr_fo ~= f.nd_gs_ptr then B747DR_dsp_nd_gs_ptr_fo = f.nd_gs_ptr end
    v = f.nd_gs_flag and 1 or 0
    if B747DR_dsp_nd_gs_flag_fo ~= v then B747DR_dsp_nd_gs_flag_fo = v end
    if B747DR_dsp_nd_crs_fo ~= f.nd_crs then B747DR_dsp_nd_crs_fo = f.nd_crs end
    v = simDR_dsp_nav_obs[rx_f == 3 and 1 or 0]
    if B747DR_dsp_nd_crs_deg_fo ~= v then B747DR_dsp_nd_crs_deg_fo = v end
    if B747DR_dsp_nd_dme_fo ~= f.nd_dme then B747DR_dsp_nd_dme_fo = f.nd_dme end
    v = rx_f == 3 and simDR_dsp_nav2_dme_nm or simDR_dsp_nav1_dme_nm
    if B747DR_dsp_nd_dme_nm_fo ~= v then B747DR_dsp_nd_dme_nm_fo = v end
    s = f.nd_ref == 2 and ref_f or (f.nd_ref == 1 and "---" or "")
    if nd_ref_shown[2] ~= s then nd_ref_shown[2] = s; B747DR_dsp_nd_ils_ref_fo = s end
end

-- each ND's orientation, flags and pointers (step 5a): from its own side
-- (the Captain's pilot AHRS, the F/O's copilot one) and the PFD model's
-- heading and track; the FMC's position as an IRU in NAV (estimate)
-- each ND's reference VOR in VOR mode (step 5b): that side's, the
-- Captain's VOR L (X-Plane's NAV3, the AC standby bus), the F/O's VOR R
-- (NAV4, AC bus 2: notes/ATA-34.md §2.1) (estimate: FCOM p.1144 says "the
-- selected receiver"); autotuned unless the CDU's NAV RADIO tuned it
-- (laminar/B747/radio/tuningmodes, its 2nd and 3rd letters)
local VOR_IDX = {2, 3}
local EFIS_SW = {[0] = NM.SW_ADF, NM.SW_OFF, NM.SW_VOR}
local function efis_sw(v)
    return EFIS_SW[math.max(0, math.min(2, math.floor(v + 0.5)))]
end
-- the POS switch's radials (step 5c): the range selector's ranges; a
-- radial's label along its line and readable, turned to the line's right
-- (side 1) for directions 0 to 180, else to its left (side 2); its last
-- segment (the panel's 24-pixel segments) ending at the line's end
local ND_RANGES = {10, 20, 40, 80, 160, 320, 640}
local ND_RAD_SEG_PX = 24
local function nd_range(dial)
    return ND_RANGES[math.max(0, math.min(6, math.floor(dial + 0.5))) + 1]
end
local function rad_label(brg)
    if brg >= 0 then return brg - 90, 1 end
    return brg + 90, 2
end
local pos_text = {}
local function nd_side(i, mode, hdg, trk, hdg_valid, trk_valid, ias, center, wxr, tfc, vor, modes)
    i.mode = math.floor(mode + 0.5)
    i.hdg, i.trk, i.hdg_valid, i.trk_valid, i.ias = hdg, trk, hdg_valid, trk_valid, ias
    i.center, i.wxr, i.tfc = center > 0.5, wxr > 0.5, tfc > 0.5
    local x = VOR_IDX[vor]
    i.vor_fail = (vor == 1 and B747DR_dsp_bus_stby_main or B747DR_dsp_bus_ac[1]) < 0.5
    i.vor_auto = modes:sub(vor + 1, vor + 1) ~= "M"
    i.vor_rx = simDR_dsp_nav_rx[x] > 0.5
    i.vor_to_from = math.floor(simDR_dsp_nav_to_from[x] + 0.5)
    i.vor_dme_rx = simDR_dsp_nav_has_dme[x] > 0.5
    i.dme_fail = simDR_dsp_dme_fail == 6
end

local function nd_sources(c, f, nav_valid)
    local inp = nd_inputs
    local modes = B747DR_dsp_radio_modes
    nd_side(inp.side[NM.CAPT], B747DR_dsp_nd_mode_capt, simDR_dsp_hdg_pilot, simDR_dsp_trk_pilot, c.hdg, c.trk,
        B747DR_dsp_ias_capt, B747DR_dsp_nd_center_capt, simDR_dsp_wxr_on, B747DR_dsp_nd_tfc_capt, 1, modes)
    nd_side(inp.side[NM.FO], B747DR_dsp_nd_mode_fo, simDR_dsp_hdg_copilot, simDR_dsp_trk_copilot, f.hdg, f.trk,
        B747DR_dsp_ias_fo, B747DR_dsp_nd_center_fo, simDR_dsp_wxr_on_copilot, B747DR_dsp_nd_tfc_fo, 2, modes)
    -- the bearing pointers (step 5b): each side's VOR/ADF switches; VOR L
    -- and R (NAV3 and NAV4: the AC standby bus, AC bus 2), ADF L and R (the
    -- ADFs 1 and 2: AC bus 3, AC bus 2, notes/ATA-34.md §2.1); an ADF's
    -- station counts as received with its identifier (X-Plane has no ADF
    -- signal flag)
    local sc, sf = inp.side[NM.CAPT].sw, inp.side[NM.FO].sw
    sc[1], sc[2] = efis_sw(simDR_dsp_efis_sw_l_capt), efis_sw(simDR_dsp_efis_sw_r_capt)
    sf[1], sf[2] = efis_sw(simDR_dsp_efis_sw_l_fo), efis_sw(simDR_dsp_efis_sw_r_fo)
    inp.vor_ok[1], inp.vor_ok[2] = B747DR_dsp_bus_stby_main > 0.5, B747DR_dsp_bus_ac[1] > 0.5
    inp.adf_ok[1] = B747DR_dsp_bus_ac[2] > 0.5 and simDR_dsp_adf1_fail ~= 6
    inp.adf_ok[2] = B747DR_dsp_bus_ac[1] > 0.5 and simDR_dsp_adf2_fail ~= 6
    local id1, id2 = simDR_dsp_adf1_id, simDR_dsp_adf2_id
    local b1, b2 = string.byte(id1), string.byte(id2)
    inp.adf_brg_rx[1], inp.adf_brg_rx[2] = (b1 and b1 > 32) and true or false, (b2 and b2 > 32) and true or false
    for k = 1, 2 do
        local x = VOR_IDX[k]
        inp.vor_brg_rx[k] = simDR_dsp_nav_rx[x] > 0.5
        inp.vor_rel[k] = simDR_dsp_nav_rel[x]
        inp.vor_dme_rx[k] = simDR_dsp_nav_has_dme[x] > 0.5
    end
    inp.adf_rel[1], inp.adf_rel[2] = simDR_dsp_adf1_rel, simDR_dsp_adf2_rel
    -- the POS switch (step 5c): each side's POS and range; the IRUs in NAV,
    -- a GPS position (either GPS), the VORs' DME distances
    local pc, pf = inp.side[NM.CAPT], inp.side[NM.FO]
    pc.pos, pf.pos = B747DR_dsp_nd_pos_sel_capt > 0.5, B747DR_dsp_nd_pos_sel_fo > 0.5
    pc.range_nm, pf.range_nm = nd_range(B747DR_dsp_nd_range_capt), nd_range(B747DR_dsp_nd_range_fo)
    for k = 1, 3 do inp.iru_nav[k] = nav_valid[k] end
    inp.gps_ok = B747DR_dsp_gps_valid[0] > 0.5 or B747DR_dsp_gps_valid[1] > 0.5
    inp.vor_dme_nm[1], inp.vor_dme_nm[2] = simDR_dsp_nav_dme_nm[VOR_IDX[1]], simDR_dsp_nav_dme_nm[VOR_IDX[2]]
    inp.map_valid = nav_valid[1] or nav_valid[2] or nav_valid[3]
    inp.wind_from = simDR_dsp_wind_from
    inp.hdg_sel = B747DR_dsp_hdg_sel
    inp.roll_mode = B747DR_dsp_fma_roll
    local out = NM.update(nd_state, inp, SIM_PERIOD)
    local oc, of = out[NM.CAPT], out[NM.FO]
    -- X-Plane's own map layer turns with its map mode: read it, write when
    -- it differs (TESTING.md §1.2)
    if simDR_dsp_map_mode ~= oc.xp_mode then simDR_dsp_map_mode = oc.xp_mode end
    if simDR_dsp_map_mode_copilot ~= of.xp_mode then simDR_dsp_map_mode_copilot = of.xp_mode end
    local v = oc.rose and 1 or 0
    if B747DR_dsp_nd_rose_capt ~= v then B747DR_dsp_nd_rose_capt = v end
    v = oc.trk_flag and 1 or 0
    if B747DR_dsp_nd_trk_flag_capt ~= v then B747DR_dsp_nd_trk_flag_capt = v end
    v = oc.hdg_flag and 1 or 0
    if B747DR_dsp_nd_hdg_flag_capt ~= v then B747DR_dsp_nd_hdg_flag_capt = v end
    v = oc.map_flag and 1 or 0
    if B747DR_dsp_nd_map_flag_capt ~= v then B747DR_dsp_nd_map_flag_capt = v end
    v = oc.vtk_flag and 1 or 0
    if B747DR_dsp_nd_vtk_flag_capt ~= v then B747DR_dsp_nd_vtk_flag_capt = v end
    v = oc.hdg_ptr and 1 or 0
    if B747DR_dsp_nd_hdg_ptr_capt ~= v then B747DR_dsp_nd_hdg_ptr_capt = v end
    v = oc.hdg_ptr_pln and 1 or 0
    if B747DR_dsp_nd_hdg_ptr_pln_capt ~= v then B747DR_dsp_nd_hdg_ptr_pln_capt = v end
    v = oc.hdg_bug and 1 or 0
    if B747DR_dsp_nd_hdg_bug_capt ~= v then B747DR_dsp_nd_hdg_bug_capt = v end
    v = oc.hdg_line and 1 or 0
    if B747DR_dsp_nd_hdg_line_capt ~= v then B747DR_dsp_nd_hdg_line_capt = v end
    v = oc.wind and 1 or 0
    if B747DR_dsp_nd_wind_capt ~= v then B747DR_dsp_nd_wind_capt = v end
    if B747DR_dsp_nd_wind_deg_capt ~= oc.wind_deg then B747DR_dsp_nd_wind_deg_capt = oc.wind_deg end
    v = of.rose and 1 or 0
    if B747DR_dsp_nd_rose_fo ~= v then B747DR_dsp_nd_rose_fo = v end
    v = of.trk_flag and 1 or 0
    if B747DR_dsp_nd_trk_flag_fo ~= v then B747DR_dsp_nd_trk_flag_fo = v end
    v = of.hdg_flag and 1 or 0
    if B747DR_dsp_nd_hdg_flag_fo ~= v then B747DR_dsp_nd_hdg_flag_fo = v end
    v = of.map_flag and 1 or 0
    if B747DR_dsp_nd_map_flag_fo ~= v then B747DR_dsp_nd_map_flag_fo = v end
    v = of.vtk_flag and 1 or 0
    if B747DR_dsp_nd_vtk_flag_fo ~= v then B747DR_dsp_nd_vtk_flag_fo = v end
    v = of.hdg_ptr and 1 or 0
    if B747DR_dsp_nd_hdg_ptr_fo ~= v then B747DR_dsp_nd_hdg_ptr_fo = v end
    v = of.hdg_ptr_pln and 1 or 0
    if B747DR_dsp_nd_hdg_ptr_pln_fo ~= v then B747DR_dsp_nd_hdg_ptr_pln_fo = v end
    v = of.hdg_bug and 1 or 0
    if B747DR_dsp_nd_hdg_bug_fo ~= v then B747DR_dsp_nd_hdg_bug_fo = v end
    v = of.hdg_line and 1 or 0
    if B747DR_dsp_nd_hdg_line_fo ~= v then B747DR_dsp_nd_hdg_line_fo = v end
    v = of.wind and 1 or 0
    if B747DR_dsp_nd_wind_fo ~= v then B747DR_dsp_nd_wind_fo = v end
    if B747DR_dsp_nd_wind_deg_fo ~= of.wind_deg then B747DR_dsp_nd_wind_deg_fo = of.wind_deg end
    v = oc.trk_line and 1 or 0
    if B747DR_dsp_nd_trk_line_capt ~= v then B747DR_dsp_nd_trk_line_capt = v end
    v = of.trk_line and 1 or 0
    if B747DR_dsp_nd_trk_line_fo ~= v then B747DR_dsp_nd_trk_line_fo = v end

    -- the VOR mode: the Captain's VOR L, the F/O's VOR R (the flag 1 VOR L,
    -- 2 VOR R)
    if B747DR_dsp_nd_vor_rx_capt ~= 1 then B747DR_dsp_nd_vor_rx_capt = 1 end
    v = oc.vor_flag and 1 or 0
    if B747DR_dsp_nd_vor_flag_capt ~= v then B747DR_dsp_nd_vor_flag_capt = v end
    v = oc.vor_dev and 1 or 0
    if B747DR_dsp_nd_vor_dev_capt ~= v then B747DR_dsp_nd_vor_dev_capt = v end
    if B747DR_dsp_nd_vor_crs_capt ~= oc.vor_crs then B747DR_dsp_nd_vor_crs_capt = oc.vor_crs end
    v = simDR_dsp_nav_obs[2]
    if B747DR_dsp_nd_vor_crs_deg_capt ~= v then B747DR_dsp_nd_vor_crs_deg_capt = v end
    if B747DR_dsp_nd_to_from_capt ~= oc.to_from then B747DR_dsp_nd_to_from_capt = oc.to_from end
    if B747DR_dsp_nd_vor_dme_capt ~= oc.vor_dme then B747DR_dsp_nd_vor_dme_capt = oc.vor_dme end
    v = simDR_dsp_nav_dme_nm[2]
    if B747DR_dsp_nd_vor_dme_nm_capt ~= v then B747DR_dsp_nd_vor_dme_nm_capt = v end
    local s = oc.vor_ref == 2 and id_or_freq(3, simDR_dsp_nav3_id, simDR_dsp_nav_freq[2]) or ""
    if nd_ref_shown[3] ~= s then nd_ref_shown[3] = s; B747DR_dsp_nd_vor_ref_capt = s end
    if B747DR_dsp_nd_vor_rx_fo ~= 2 then B747DR_dsp_nd_vor_rx_fo = 2 end
    v = of.vor_flag and 2 or 0
    if B747DR_dsp_nd_vor_flag_fo ~= v then B747DR_dsp_nd_vor_flag_fo = v end
    v = of.vor_dev and 1 or 0
    if B747DR_dsp_nd_vor_dev_fo ~= v then B747DR_dsp_nd_vor_dev_fo = v end
    if B747DR_dsp_nd_vor_crs_fo ~= of.vor_crs then B747DR_dsp_nd_vor_crs_fo = of.vor_crs end
    v = simDR_dsp_nav_obs[3]
    if B747DR_dsp_nd_vor_crs_deg_fo ~= v then B747DR_dsp_nd_vor_crs_deg_fo = v end
    if B747DR_dsp_nd_to_from_fo ~= of.to_from then B747DR_dsp_nd_to_from_fo = of.to_from end
    if B747DR_dsp_nd_vor_dme_fo ~= of.vor_dme then B747DR_dsp_nd_vor_dme_fo = of.vor_dme end
    v = simDR_dsp_nav_dme_nm[3]
    if B747DR_dsp_nd_vor_dme_nm_fo ~= v then B747DR_dsp_nd_vor_dme_nm_fo = v end
    s = of.vor_ref == 2 and id_or_freq(4, simDR_dsp_nav4_id, simDR_dsp_nav_freq[3]) or ""
    if nd_ref_shown[4] ~= s then nd_ref_shown[4] = s; B747DR_dsp_nd_vor_ref_fo = s end

    -- the bearing pointers and the lower corner blocks
    if B747DR_dsp_nd_ptr_l_capt ~= oc.ptr[1] then B747DR_dsp_nd_ptr_l_capt = oc.ptr[1] end
    if B747DR_dsp_nd_ptr_r_capt ~= oc.ptr[2] then B747DR_dsp_nd_ptr_r_capt = oc.ptr[2] end
    if B747DR_dsp_nd_brg_l_capt ~= oc.brg[1] then B747DR_dsp_nd_brg_l_capt = oc.brg[1] end
    if B747DR_dsp_nd_brg_r_capt ~= oc.brg[2] then B747DR_dsp_nd_brg_r_capt = oc.brg[2] end
    if B747DR_dsp_nd_rad_l_capt ~= oc.rad[1] then B747DR_dsp_nd_rad_l_capt = oc.rad[1] end
    if B747DR_dsp_nd_rad_r_capt ~= oc.rad[2] then B747DR_dsp_nd_rad_r_capt = oc.rad[2] end
    v = oc.rad_flag[1] and 1 or 0
    if B747DR_dsp_nd_rad_l_flag_capt ~= v then B747DR_dsp_nd_rad_l_flag_capt = v end
    v = oc.rad_flag[2] and 1 or 0
    if B747DR_dsp_nd_rad_r_flag_capt ~= v then B747DR_dsp_nd_rad_r_flag_capt = v end
    if B747DR_dsp_nd_rad_l_dme_capt ~= oc.rad_dme[1] then B747DR_dsp_nd_rad_l_dme_capt = oc.rad_dme[1] end
    if B747DR_dsp_nd_rad_r_dme_capt ~= oc.rad_dme[2] then B747DR_dsp_nd_rad_r_dme_capt = oc.rad_dme[2] end
    if B747DR_dsp_nd_ptr_l_fo ~= of.ptr[1] then B747DR_dsp_nd_ptr_l_fo = of.ptr[1] end
    if B747DR_dsp_nd_ptr_r_fo ~= of.ptr[2] then B747DR_dsp_nd_ptr_r_fo = of.ptr[2] end
    if B747DR_dsp_nd_brg_l_fo ~= of.brg[1] then B747DR_dsp_nd_brg_l_fo = of.brg[1] end
    if B747DR_dsp_nd_brg_r_fo ~= of.brg[2] then B747DR_dsp_nd_brg_r_fo = of.brg[2] end
    if B747DR_dsp_nd_rad_l_fo ~= of.rad[1] then B747DR_dsp_nd_rad_l_fo = of.rad[1] end
    if B747DR_dsp_nd_rad_r_fo ~= of.rad[2] then B747DR_dsp_nd_rad_r_fo = of.rad[2] end
    v = of.rad_flag[1] and 1 or 0
    if B747DR_dsp_nd_rad_l_flag_fo ~= v then B747DR_dsp_nd_rad_l_flag_fo = v end
    v = of.rad_flag[2] and 1 or 0
    if B747DR_dsp_nd_rad_r_flag_fo ~= v then B747DR_dsp_nd_rad_r_flag_fo = v end
    if B747DR_dsp_nd_rad_l_dme_fo ~= of.rad_dme[1] then B747DR_dsp_nd_rad_l_dme_fo = of.rad_dme[1] end
    if B747DR_dsp_nd_rad_r_dme_fo ~= of.rad_dme[2] then B747DR_dsp_nd_rad_r_dme_fo = of.rad_dme[2] end
    -- the receivers' frequency or identifier, both sides' blocks (removed
    -- when the receiver failed: its flag shows)
    s = inp.vor_ok[1] and id_or_freq(5, simDR_dsp_nav3_id, simDR_dsp_nav_freq[2]) or ""
    if nd_ref_shown[5] ~= s then nd_ref_shown[5] = s; B747DR_dsp_nd_vor_l_ref = s end
    s = inp.vor_ok[2] and id_or_freq(6, simDR_dsp_nav4_id, simDR_dsp_nav_freq[3]) or ""
    if nd_ref_shown[6] ~= s then nd_ref_shown[6] = s; B747DR_dsp_nd_vor_r_ref = s end
    s = inp.adf_ok[1] and adf_ref(7, id1, simDR_dsp_adf1_freq) or ""
    if nd_ref_shown[7] ~= s then nd_ref_shown[7] = s; B747DR_dsp_nd_adf_l_ref = s end
    s = inp.adf_ok[2] and adf_ref(8, id2, simDR_dsp_adf2_freq) or ""
    if nd_ref_shown[8] ~= s then nd_ref_shown[8] = s; B747DR_dsp_nd_adf_r_ref = s end

    -- the POS switch's symbols (step 5c)
    for k = 1, 3 do
        v = oc.pos_iru[k] and 1 or 0
        if B747DR_dsp_nd_pos_iru_capt[k - 1] ~= v then B747DR_dsp_nd_pos_iru_capt[k - 1] = v end
    end
    v = oc.pos_gps and 1 or 0
    if B747DR_dsp_nd_pos_gps_capt ~= v then B747DR_dsp_nd_pos_gps_capt = v end
    v = oc.pos_rad[1] and 1 or 0
    if B747DR_dsp_nd_pos_rad_l_capt ~= v then B747DR_dsp_nd_pos_rad_l_capt = v end
    v = oc.pos_rad_brg[1]
    if B747DR_dsp_nd_pos_rad_l_brg_capt ~= v then B747DR_dsp_nd_pos_rad_l_brg_capt = v end
    v = oc.pos_rad_len[1]
    if B747DR_dsp_nd_pos_rad_l_len_capt ~= v then B747DR_dsp_nd_pos_rad_l_len_capt = v end
    v = math.max(0, oc.pos_rad_len[1] - ND_RAD_SEG_PX)
    if B747DR_dsp_nd_pos_rad_l_end_capt ~= v then B747DR_dsp_nd_pos_rad_l_end_capt = v end
    v = oc.pos_rad_tick[1] and 1 or 0
    if B747DR_dsp_nd_pos_rad_l_tick_capt ~= v then B747DR_dsp_nd_pos_rad_l_tick_capt = v end
    local turn, side = rad_label(oc.pos_rad_brg[1])
    v = turn
    if B747DR_dsp_nd_pos_rad_l_tbrg_capt ~= v then B747DR_dsp_nd_pos_rad_l_tbrg_capt = v end
    v = side
    if B747DR_dsp_nd_pos_rad_l_tside_capt ~= v then B747DR_dsp_nd_pos_rad_l_tside_capt = v end
    s = string.format("R-%03d", oc.pos_rad_radial[1])
    if pos_text[1] ~= s then pos_text[1] = s; B747DR_dsp_nd_pos_rad_l_text_capt = s end
    v = oc.pos_rad[2] and 1 or 0
    if B747DR_dsp_nd_pos_rad_r_capt ~= v then B747DR_dsp_nd_pos_rad_r_capt = v end
    v = oc.pos_rad_brg[2]
    if B747DR_dsp_nd_pos_rad_r_brg_capt ~= v then B747DR_dsp_nd_pos_rad_r_brg_capt = v end
    v = oc.pos_rad_len[2]
    if B747DR_dsp_nd_pos_rad_r_len_capt ~= v then B747DR_dsp_nd_pos_rad_r_len_capt = v end
    v = math.max(0, oc.pos_rad_len[2] - ND_RAD_SEG_PX)
    if B747DR_dsp_nd_pos_rad_r_end_capt ~= v then B747DR_dsp_nd_pos_rad_r_end_capt = v end
    v = oc.pos_rad_tick[2] and 1 or 0
    if B747DR_dsp_nd_pos_rad_r_tick_capt ~= v then B747DR_dsp_nd_pos_rad_r_tick_capt = v end
    local turn, side = rad_label(oc.pos_rad_brg[2])
    v = turn
    if B747DR_dsp_nd_pos_rad_r_tbrg_capt ~= v then B747DR_dsp_nd_pos_rad_r_tbrg_capt = v end
    v = side
    if B747DR_dsp_nd_pos_rad_r_tside_capt ~= v then B747DR_dsp_nd_pos_rad_r_tside_capt = v end
    s = string.format("R-%03d", oc.pos_rad_radial[2])
    if pos_text[2] ~= s then pos_text[2] = s; B747DR_dsp_nd_pos_rad_r_text_capt = s end
    for k = 1, 3 do
        v = of.pos_iru[k] and 1 or 0
        if B747DR_dsp_nd_pos_iru_fo[k - 1] ~= v then B747DR_dsp_nd_pos_iru_fo[k - 1] = v end
    end
    v = of.pos_gps and 1 or 0
    if B747DR_dsp_nd_pos_gps_fo ~= v then B747DR_dsp_nd_pos_gps_fo = v end
    v = of.pos_rad[1] and 1 or 0
    if B747DR_dsp_nd_pos_rad_l_fo ~= v then B747DR_dsp_nd_pos_rad_l_fo = v end
    v = of.pos_rad_brg[1]
    if B747DR_dsp_nd_pos_rad_l_brg_fo ~= v then B747DR_dsp_nd_pos_rad_l_brg_fo = v end
    v = of.pos_rad_len[1]
    if B747DR_dsp_nd_pos_rad_l_len_fo ~= v then B747DR_dsp_nd_pos_rad_l_len_fo = v end
    v = math.max(0, of.pos_rad_len[1] - ND_RAD_SEG_PX)
    if B747DR_dsp_nd_pos_rad_l_end_fo ~= v then B747DR_dsp_nd_pos_rad_l_end_fo = v end
    v = of.pos_rad_tick[1] and 1 or 0
    if B747DR_dsp_nd_pos_rad_l_tick_fo ~= v then B747DR_dsp_nd_pos_rad_l_tick_fo = v end
    local turn, side = rad_label(of.pos_rad_brg[1])
    v = turn
    if B747DR_dsp_nd_pos_rad_l_tbrg_fo ~= v then B747DR_dsp_nd_pos_rad_l_tbrg_fo = v end
    v = side
    if B747DR_dsp_nd_pos_rad_l_tside_fo ~= v then B747DR_dsp_nd_pos_rad_l_tside_fo = v end
    s = string.format("R-%03d", of.pos_rad_radial[1])
    if pos_text[3] ~= s then pos_text[3] = s; B747DR_dsp_nd_pos_rad_l_text_fo = s end
    v = of.pos_rad[2] and 1 or 0
    if B747DR_dsp_nd_pos_rad_r_fo ~= v then B747DR_dsp_nd_pos_rad_r_fo = v end
    v = of.pos_rad_brg[2]
    if B747DR_dsp_nd_pos_rad_r_brg_fo ~= v then B747DR_dsp_nd_pos_rad_r_brg_fo = v end
    v = of.pos_rad_len[2]
    if B747DR_dsp_nd_pos_rad_r_len_fo ~= v then B747DR_dsp_nd_pos_rad_r_len_fo = v end
    v = math.max(0, of.pos_rad_len[2] - ND_RAD_SEG_PX)
    if B747DR_dsp_nd_pos_rad_r_end_fo ~= v then B747DR_dsp_nd_pos_rad_r_end_fo = v end
    v = of.pos_rad_tick[2] and 1 or 0
    if B747DR_dsp_nd_pos_rad_r_tick_fo ~= v then B747DR_dsp_nd_pos_rad_r_tick_fo = v end
    local turn, side = rad_label(of.pos_rad_brg[2])
    v = turn
    if B747DR_dsp_nd_pos_rad_r_tbrg_fo ~= v then B747DR_dsp_nd_pos_rad_r_tbrg_fo = v end
    v = side
    if B747DR_dsp_nd_pos_rad_r_tside_fo ~= v then B747DR_dsp_nd_pos_rad_r_tside_fo = v end
    s = string.format("R-%03d", of.pos_rad_radial[2])
    if pos_text[4] ~= s then pos_text[4] = s; B747DR_dsp_nd_pos_rad_r_text_fo = s end
end

-- each PFD's sources (step 4a)
local function pfd_sources(fmc)
    local pin = pfd_inputs
    for i = 1, 3 do
        pin.att_valid[i] = B747DR_dsp_irs_att_valid[i - 1] > 0.5
        pin.hdg_valid[i] = B747DR_dsp_irs_hdg_valid[i - 1] > 0.5
        pin.nav_valid[i] = B747DR_dsp_irs_nav_valid[i - 1] > 0.5
    end
    pin.irs[1], pin.irs[2] = iru(B747DR_dsp_irs_src_capt), iru(B747DR_dsp_irs_src_fo)
    pin.fmc[1], pin.fmc[2] = fmc[1], fmc[2]
    pin.air_data[1] = B747DR_dsp_air_valid_capt > 0.5
    pin.air_data[2] = B747DR_dsp_air_valid_fo > 0.5
    local po = PM.update(pfd_state, pin)
    local c, f = po[PM.CAPT], po[PM.FO]
    local v = c.att and 1 or 0
    if B747DR_dsp_pfd_att_capt ~= v then B747DR_dsp_pfd_att_capt = v end
    v = c.hdg and 1 or 0
    if B747DR_dsp_pfd_hdg_capt ~= v then B747DR_dsp_pfd_hdg_capt = v end
    v = c.trk and 1 or 0
    if B747DR_dsp_pfd_trk_capt ~= v then B747DR_dsp_pfd_trk_capt = v end
    v = c.vsi and 1 or 0
    if B747DR_dsp_pfd_vsi_capt ~= v then B747DR_dsp_pfd_vsi_capt = v end
    v = c.vert and 1 or 0
    if B747DR_dsp_pfd_vert_capt ~= v then B747DR_dsp_pfd_vert_capt = v end
    v = f.att and 1 or 0
    if B747DR_dsp_pfd_att_fo ~= v then B747DR_dsp_pfd_att_fo = v end
    v = f.hdg and 1 or 0
    if B747DR_dsp_pfd_hdg_fo ~= v then B747DR_dsp_pfd_hdg_fo = v end
    v = f.trk and 1 or 0
    if B747DR_dsp_pfd_trk_fo ~= v then B747DR_dsp_pfd_trk_fo = v end
    v = f.vsi and 1 or 0
    if B747DR_dsp_pfd_vsi_fo ~= v then B747DR_dsp_pfd_vsi_fo = v end
    v = f.vert and 1 or 0
    if B747DR_dsp_pfd_vert_fo ~= v then B747DR_dsp_pfd_vert_fo = v end

    -- the flight path vector (step 4d): selected with the FPV switch; from
    -- the selected IRU's inertial data (NAV), else the FPV flag. X-Plane's
    -- flight path and track stand for the IRU's, each PFD's attitude for
    -- the frame
    local drift = (simDR_dsp_hpath - simDR_dsp_psi + 180) % 360 - 180
    local sel = B747DR_dsp_fpv_sel_capt > 0.5
    local ok = pin.nav_valid[pin.irs[1]]
    v = (sel and ok) and 1 or 0
    if B747DR_dsp_fpv_show_capt ~= v then B747DR_dsp_fpv_show_capt = v end
    v = (sel and not ok) and 1 or 0
    if B747DR_dsp_fpv_flag_capt ~= v then B747DR_dsp_fpv_flag_capt = v end
    local x, y = PM.fpv_place(simDR_dsp_pitch_pilot, simDR_dsp_roll_pilot, simDR_dsp_vpath, drift)
    if B747DR_dsp_fpv_x_capt ~= x then B747DR_dsp_fpv_x_capt = x end
    if B747DR_dsp_fpv_y_capt ~= y then B747DR_dsp_fpv_y_capt = y end
    sel = B747DR_dsp_fpv_sel_fo > 0.5
    ok = pin.nav_valid[pin.irs[2]]
    v = (sel and ok) and 1 or 0
    if B747DR_dsp_fpv_show_fo ~= v then B747DR_dsp_fpv_show_fo = v end
    v = (sel and not ok) and 1 or 0
    if B747DR_dsp_fpv_flag_fo ~= v then B747DR_dsp_fpv_flag_fo = v end
    x, y = PM.fpv_place(simDR_dsp_pitch_copilot, simDR_dsp_roll_copilot, simDR_dsp_vpath, drift)
    if B747DR_dsp_fpv_x_fo ~= x then B747DR_dsp_fpv_x_fo = x end
    if B747DR_dsp_fpv_y_fo ~= y then B747DR_dsp_fpv_y_fo = y end

    -- the PITCH and ROLL flags (step 4d): both attitudes shown and apart
    local dp, dr = false, false
    if c.att and f.att then
        dp, dr = PM.attitude_disagree(simDR_dsp_pitch_pilot, simDR_dsp_roll_pilot,
            simDR_dsp_pitch_copilot, simDR_dsp_roll_copilot)
    end
    v = dp and 1 or 0
    if B747DR_dsp_pitch_flag ~= v then B747DR_dsp_pitch_flag = v end
    v = dr and 1 or 0
    if B747DR_dsp_roll_flag ~= v then B747DR_dsp_roll_flag = v end

    pfd_ils(c.trk, f.trk)
    nd_sources(c, f, pin.nav_valid)
end

-- the barometric setting's amber box at the transition (step 4b): the FMC's
-- transition altitude read from its data every 2 s (TRANS ALT on the CLB
-- page; the FMC has no TRANS LVL yet: its default FL180)
local trans_alt_ft, trans_t = PM.TRANS_ALT_FT, nil
local function pfd_baro()
    trans_t = (trans_t or 2) + SIM_PERIOD
    if trans_t >= 2 then
        trans_t = 0
        local d = B747DR_dsp_fms_data
        local v = type(d) == "string" and tonumber(d:match('"transalt"%s*:%s*"?(%d+)'))
        trans_alt_ft = v or PM.TRANS_ALT_FT
    end
    local mcp = B747DR_dsp_mcp_alt
    local v = PM.baro_alert(B747DR_efis_baro_std_capt_switch_pos > 0.5, B747DR_dsp_alt_capt, mcp,
        trans_alt_ft, PM.TRANS_LVL_FT) and 1 or 0
    if B747DR_dsp_pfd_baro_alert_capt ~= v then B747DR_dsp_pfd_baro_alert_capt = v end
    v = PM.baro_alert(B747DR_efis_baro_std_fo_switch_pos > 0.5, B747DR_dsp_alt_fo, mcp,
        trans_alt_ft, PM.TRANS_LVL_FT) and 1 or 0
    if B747DR_dsp_pfd_baro_alert_fo ~= v then B747DR_dsp_pfd_baro_alert_fo = v end
end

function B747_displays()
    local inp = dsp_inputs
    -- the Captain's knobs as the model's positions; the F/O's are mirrored
    -- (INBD PFD NORM EICAS, LWR ND NORM EICAS PRI)
    inp.inbd[1] = math.floor(B747DR_flt_inst_inbd_disp_capt_sel_dial_pos + 0.5)
    inp.lwr[1] = math.floor(B747DR_flt_inst_lwr_disp_capt_sel_dial_pos + 0.5)
    inp.inbd[2] = 2 - math.floor(B747DR_flt_inst_inbd_disp_fo_sel_dial_pos + 0.5)
    inp.lwr[2] = 2 - math.floor(B747DR_flt_inst_lwr_disp_fo_sel_dial_pos + 0.5)
    -- the units' buses (FCOM p.800, p.804)
    local apu, main, fo = B747DR_dsp_bus_stby_apu > 0.5, B747DR_dsp_bus_stby_main > 0.5, B747DR_dsp_bus_xfr_fo > 0.5
    inp.unit_power[DM.U_CAPT_OUT], inp.unit_power[DM.U_CAPT_IN] = apu, apu
    inp.unit_power[DM.U_UPPER] = main
    inp.unit_power[DM.U_LOWER], inp.unit_power[DM.U_FO_IN], inp.unit_power[DM.U_FO_OUT] = fo, fo, fo
    for u = 1, 6 do inp.unit_fail[u] = B747DR_dsp_unit_fail[u - 1] > 0.5 end
    inp.eiu_power[DM.EIU_L] = main
    inp.eiu_power[DM.EIU_C] = B747DR_dsp_bus_xfr_capt > 0.5
    inp.eiu_power[DM.EIU_R] = fo
    for e = 1, 3 do inp.eiu_fail[e] = B747DR_dsp_eiu_fail[e - 1] > 0.5 end
    inp.eiu_sel[1] = knob(B747DR_flt_inst_eiu_src_capt_dial_pos, EIU_CAPT)
    inp.eiu_sel[2] = knob(B747DR_flt_inst_eiu_src_fo_dial_pos, EIU_FO)
    inp.eiu_sel[3] = knob(B747DR_flt_inst_eiu_src_ctr_pnl_dial_pos, EIU_CAPT)
    inp.standby_power = B747DR_dsp_bus_any_ac < 0.5
    inp.on_ground = B747DR_dsp_pri_air < 0.5
    -- the FLT DIR selectors: L, C, R on both panels
    inp.fd[1] = math.floor(B747DR_flt_inst_fd_src_capt_dial_pos + 0.5) + 1
    inp.fd[2] = math.floor(B747DR_flt_inst_fd_src_fo_dial_pos + 0.5) + 1
    inp.fmc[1] = knob(B747DR_flt_inst_nav_src_capt_dial_pos, NAV_CAPT)
    inp.fmc[2] = knob(B747DR_flt_inst_nav_src_fo_dial_pos, NAV_FO)
    inp.efis_power[1], inp.efis_power[2] = main, fo
    inp.efis_fail[1] = B747DR_dsp_efis_fail[0] > 0.5
    inp.efis_fail[2] = B747DR_dsp_efis_fail[1] > 0.5
    inp.dsp_fail = B747DR_dsp_dsp_fail > 0.5

    local out = DM.update(dsp_state, inp)
    local pos = out.pos
    if B747DR_flt_inst_capt_pfd_pos ~= pos[DM.C_PFD_CAPT] then B747DR_flt_inst_capt_pfd_pos = pos[DM.C_PFD_CAPT] end
    if B747DR_flt_inst_fo_pfd_pos ~= pos[DM.C_PFD_FO] then B747DR_flt_inst_fo_pfd_pos = pos[DM.C_PFD_FO] end
    if B747DR_flt_inst_capt_nd_pos ~= pos[DM.C_ND_CAPT] then B747DR_flt_inst_capt_nd_pos = pos[DM.C_ND_CAPT] end
    if B747DR_flt_inst_fo_nd_pos ~= pos[DM.C_ND_FO] then B747DR_flt_inst_fo_nd_pos = pos[DM.C_ND_FO] end
    if B747DR_flt_inst_eicas_pos ~= pos[DM.C_SEC] then B747DR_flt_inst_eicas_pos = pos[DM.C_SEC] end
    if B747DR_flt_inst_pri_eicas_pos ~= pos[DM.C_PRI] then B747DR_flt_inst_pri_eicas_pos = pos[DM.C_PRI] end
    for c = 1, 6 do
        if B747DR_dsp_display_power[c - 1] ~= out.power[c] then B747DR_dsp_display_power[c - 1] = out.power[c] end
        if B747DR_dsp_content_unit[c - 1] ~= out.shown_on[c] then B747DR_dsp_content_unit[c - 1] = out.shown_on[c] end
    end
    for k = 1, 3 do
        if B747DR_dsp_eiu_used[k - 1] ~= out.eiu[k] then B747DR_dsp_eiu_used[k - 1] = out.eiu[k] end
    end
    msg(ADV_EIU_LEFT, out.msg_eiu_left)
    msg(ADV_SOURCE_SEL_EIU, out.msg_source_sel_eiu)
    msg(ADV_SOURCE_SEL_FD, out.msg_source_sel_fd)
    msg(ADV_SOURCE_SEL_NAV, out.msg_source_sel_nav)
    msg(ADV_EFIS_CONTROL[1], out.msg_efis_control[1])
    msg(ADV_EFIS_CONTROL[2], out.msg_efis_control[2])
    msg(ADV_EFIS_EICAS_CP, out.msg_efis_eicas_cp)
    pfd_sources(inp.fmc)
    pfd_baro()
end
