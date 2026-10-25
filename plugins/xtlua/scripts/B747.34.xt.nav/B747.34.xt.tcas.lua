-- The transponder and TCAS model (B747.34.tcas_model.lua) in the aircraft:
-- reads the 570 transponder panel (the mode selector, the XPDR switch), the
-- buses (transponder L: AC standby bus, R: AC bus 2; TCAS: AC bus 3), the
-- failures, the PSEU's air/ground, the TCAS's radio altitude (B747.34.xt.ra.lua),
-- the GPWS's warning, windshear and voice, the displays' power, the EFIS
-- panels (ND modes, ranges, TFC pushes) and X-Plane's TCAS; writes X-Plane's
-- transponder mode, the voice, each target's ND symbol, the PFDs' RA
-- guidance values, the NDs' TCAS messages and the EICAS messages.
-- B747.34.xt.nav.lua loads it after B747.34.xt.gpws.lua.

dofile("B747.34.tcas_model.lua")
local TC = B747_tcas_model

simDR_tcas_time                 = find_dataref("sim/time/total_running_time_sec")
simDR_tcas_xpdr_mode            = find_dataref("sim/cockpit2/radios/actuators/transponder_mode")
simDR_tcas_xpdr_failure         = find_dataref("sim/operation/failures/rel_xpndr")
simDR_tcas_threat               = find_dataref("sim/cockpit2/tcas/targets/threat")
simDR_tcas_ssr                  = find_dataref("sim/cockpit2/tcas/targets/ssr_mode")
simDR_tcas_dist                 = find_dataref("sim/cockpit2/tcas/indicators/relative_distance_mtrs")
simDR_tcas_rel_alt              = find_dataref("sim/cockpit2/tcas/indicators/relative_altitude_mtrs")
simDR_tcas_advisory             = find_dataref("sim/cockpit2/tcas/indicators/tcas_active_advisory")
simDR_tcas_message              = find_dataref("sim/cockpit2/tcas/indicators/tcas_message")
simDR_tcas_bands                = find_dataref("sim/cockpit2/tcas/indicators/tcas_vs_bands")
simDR_tcas_vs                   = find_dataref("sim/flightmodel/position/vh_ind_fpm")
simDR_tcas_tas                  = find_dataref("sim/flightmodel/position/true_airspeed")
B747DR_tcas_mode_sel            = find_dataref("laminar/B747/flt_mgmt/txpdr/mode_sel_pos")
B747DR_tcas_xpdr_sel            = find_dataref("laminar/B747/flt_mgmt/transponder/sel_dial_pos")
B747DR_tcas_bus_ac              = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_tcas_bus_stby            = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_tcas_pseu_air            = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_tcas_gpws_warning        = find_dataref("laminar/B747/gpws/warning")
B747DR_tcas_gpws_windshear      = find_dataref("laminar/B747/gpws/windshear")
B747DR_tcas_gpws_voice          = find_dataref("laminar/B747/gpws/voice")
B747DR_tcas_display_power       = find_dataref("laminar/B747/electrical/display_has_power")
B747DR_tcas_nd_mode_capt        = find_dataref("laminar/B747/nd/mode/capt/sel_dial_pos")
B747DR_tcas_nd_mode_fo          = find_dataref("laminar/B747/nd/mode/fo/sel_dial_pos")
B747DR_tcas_nd_center_capt      = find_dataref("laminar/B747/nd/map_center/capt")
B747DR_tcas_nd_center_fo        = find_dataref("laminar/B747/nd/map_center/fo")
B747DR_tcas_nd_range_capt       = find_dataref("laminar/B747/nd/range/capt/sel_dial_pos")
B747DR_tcas_nd_range_fo         = find_dataref("laminar/B747/nd/range/fo/sel_dial_pos")
B747DR_tcas_tfc_pushes_capt     = find_dataref("laminar/B747/nd/traffic/capt/pushes")
B747DR_tcas_tfc_pushes_fo       = find_dataref("laminar/B747/nd/traffic/fo/pushes")
B747DR_tcas_CAS_advisory        = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_tcas_xpdr_fail           = find_dataref("laminar/B747/xpdr/fail")
B747DR_tcas_fail_in             = find_dataref("laminar/B747/tcas/fail")
B747DR_tcas_voice_out           = find_dataref("laminar/B747/tcas/voice")
B747DR_tcas_last_voice_out      = find_dataref("laminar/B747/tcas/last_voice")
B747DR_tcas_sym_out             = find_dataref("laminar/B747/tcas/sym")
B747DR_tcas_operating_out       = find_dataref("laminar/B747/tcas/operating")
B747DR_tcas_failed_out          = find_dataref("laminar/B747/tcas/failed")
B747DR_tcas_ra_mode_out         = find_dataref("laminar/B747/tcas/ra_mode")
B747DR_tcas_traffic_out         = find_dataref("laminar/B747/tcas/traffic")
B747DR_tcas_pfd_ra_out          = find_dataref("laminar/B747/tcas/pfd/ra")
B747DR_tcas_pfd_lo_on_out       = find_dataref("laminar/B747/tcas/pfd/lo_on")
B747DR_tcas_pfd_hi_on_out       = find_dataref("laminar/B747/tcas/pfd/hi_on")
B747DR_tcas_pfd_vs_lo_out       = find_dataref("laminar/B747/tcas/pfd/vs_lo")
B747DR_tcas_pfd_vs_hi_out       = find_dataref("laminar/B747/tcas/pfd/vs_hi")
B747DR_tcas_pfd_pitch_lo_out    = find_dataref("laminar/B747/tcas/pfd/pitch_lo")
B747DR_tcas_pfd_pitch_hi_out    = find_dataref("laminar/B747/tcas/pfd/pitch_hi")
B747DR_tcas_pfd_vs_red_out      = find_dataref("laminar/B747/tcas/pfd/vs_red")
-- each ND (Captain, F/O): TFC and TCAS OFF are the panel's (xtlua_keysystems).
-- XTLua makes each of these tables a namespace: t[i] reads and writes the
-- dataref itself.
B747DR_tcas_nd_tfc              = {find_dataref("laminar/B747/nd/capt/tfc"), find_dataref("laminar/B747/nd/fo/tfc")}
B747DR_tcas_nd_off              = {find_dataref("laminar/B747/nd/capt/tcas_off"), find_dataref("laminar/B747/nd/fo/tcas_off")}
B747DR_tcas_nd_fail             = {find_dataref("laminar/B747/nd/capt/tcas_fail"), find_dataref("laminar/B747/nd/fo/tcas_fail")}
B747DR_tcas_nd_traffic          = {find_dataref("laminar/B747/nd/capt/traffic"), find_dataref("laminar/B747/nd/fo/traffic")}
B747DR_tcas_nd_offscale         = {find_dataref("laminar/B747/nd/capt/offscale"), find_dataref("laminar/B747/nd/fo/offscale")}
B747DR_tcas_nd_ta_only          = {find_dataref("laminar/B747/nd/capt/ta_only"), find_dataref("laminar/B747/nd/fo/ta_only")}
B747DR_tcas_nd_show             = {find_dataref("laminar/B747/nd/capt/tcas_show"), find_dataref("laminar/B747/nd/fo/tcas_show")}

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_TCAS_OFF, ADV_TCAS_RA_CAPT, ADV_TCAS_RA_FO, ADV_TCAS_SYSTEM = 279, 280, 281, 282
local ADV_XPDR_L, ADV_XPDR_R = 292, 293
-- display_has_power: 0 Captain's PFD, 1 F/O's PFD, 2 F/O's ND, 3 Captain's ND
local DSP_PFD_CAPT, DSP_PFD_FO, DSP_ND_FO, DSP_ND_CAPT = 0, 1, 2, 3
-- the ND mode selector: 0 APP, 1 VOR, 2 MAP, 3 PLN (B747.60.xt.fltInst02.lua)
local ND_MAP = 2
local RANGES_NM = {10, 20, 40, 80, 160, 320, 640}
local XP_FAILED = 6
local TARGETS = 63                              -- X-Plane's TCAS arrays: 0 is us
local M_TO_FT, M_TO_NM, MS_TO_KT = 3.28084, 1 / 1852, 1.943844
local INIT_S = 3                                -- the first reads are 0

local tcas_state = TC.new()
local tcas_inputs = TC.inputs()
local tcas_t0 = nil
tcas_inputs.n = TARGETS

-- MAP and MAP CTR, VOR and APP not centred (FCOM p.1560)
local function traffic_mode(mode, center)
    return mode == ND_MAP or (mode < ND_MAP and center < 0.5)
end

-- the range the ND shows: in the centred modes the compass rose is half the
-- selected range (seen in X-Plane, 2026-10-25)
local function range_nm(pos, center)
    local r = RANGES_NM[math.floor(pos + 0.5) + 1] or 640
    if center > 0.5 then r = r / 2 end
    return r
end

function B747_tcas()
    local now = simDR_tcas_time
    if tcas_t0 == nil then tcas_t0 = now end
    if now - tcas_t0 < INIT_S then return end

    local inp = tcas_inputs
    inp.sel = math.floor(B747DR_tcas_mode_sel + 0.5)
    inp.xpdr_r = B747DR_tcas_xpdr_sel > 0.5
    inp.xpdr_power[1] = B747DR_tcas_bus_stby > 0.5
    inp.xpdr_power[2] = B747DR_tcas_bus_ac[1] > 0.5
    inp.xpdr_fail[1] = B747DR_tcas_xpdr_fail[0] > 0.5 or simDR_tcas_xpdr_failure == XP_FAILED
    inp.xpdr_fail[2] = B747DR_tcas_xpdr_fail[1] > 0.5
    inp.power = B747DR_tcas_bus_ac[2] > 0.5
    inp.fail = B747DR_tcas_fail_in > 0.5
    inp.on_ground = B747DR_tcas_pseu_air < 0.5
    inp.ra, inp.ra_valid, inp.ra_ncd = B747_ra_tcas()
    inp.gpws_warning = B747DR_tcas_gpws_warning > 0.5
    inp.windshear = B747DR_tcas_gpws_windshear > 0.5
    inp.gpws_voice = B747DR_tcas_gpws_voice > 0.5
    local dp = B747DR_tcas_display_power
    inp.pfd_ok[1], inp.pfd_ok[2] = dp[DSP_PFD_CAPT] > 0.1, dp[DSP_PFD_FO] > 0.1
    inp.nd_ok[1], inp.nd_ok[2] = dp[DSP_ND_CAPT] > 0.1, dp[DSP_ND_FO] > 0.1
    inp.nd_traffic_mode[1] = traffic_mode(B747DR_tcas_nd_mode_capt, B747DR_tcas_nd_center_capt)
    inp.nd_traffic_mode[2] = traffic_mode(B747DR_tcas_nd_mode_fo, B747DR_tcas_nd_center_fo)
    inp.nd_range_nm[1] = range_nm(B747DR_tcas_nd_range_capt, B747DR_tcas_nd_center_capt)
    inp.nd_range_nm[2] = range_nm(B747DR_tcas_nd_range_fo, B747DR_tcas_nd_center_fo)
    inp.tfc_pushes[1] = B747DR_tcas_tfc_pushes_capt
    inp.tfc_pushes[2] = B747DR_tcas_tfc_pushes_fo
    inp.own_vs = simDR_tcas_vs
    inp.tas_kt = simDR_tcas_tas * MS_TO_KT
    for j = 1, TARGETS do
        inp.threat[j] = simDR_tcas_threat[j]
        inp.ssr[j] = simDR_tcas_ssr[j]
        inp.dist_nm[j] = simDR_tcas_dist[j] * M_TO_NM
        inp.rel_alt_ft[j] = simDR_tcas_rel_alt[j] * M_TO_FT
    end
    inp.adv = simDR_tcas_advisory
    inp.msg = simDR_tcas_message
    for k = 1, 6 do inp.bands[k] = simDR_tcas_bands[k - 1] end

    local out = TC.update(tcas_state, inp, SIM_PERIOD)
    if simDR_tcas_xpdr_mode ~= out.xp_mode then simDR_tcas_xpdr_mode = out.xp_mode end
    if B747DR_tcas_voice_out ~= out.voice then
        B747DR_tcas_voice_out = out.voice
        if out.voice ~= TC.V_NONE then B747DR_tcas_last_voice_out = out.voice end
    end
    for j = 1, TARGETS do B747_nav_put(B747DR_tcas_sym_out, j, out.sym[j] or TC.SYM_NONE) end
    local v = B747_nav_flag(out.operating)
    if B747DR_tcas_operating_out ~= v then B747DR_tcas_operating_out = v end
    v = B747_nav_flag(out.failed)
    if B747DR_tcas_failed_out ~= v then B747DR_tcas_failed_out = v end
    v = B747_nav_flag(out.ra_mode)
    if B747DR_tcas_ra_mode_out ~= v then B747DR_tcas_ra_mode_out = v end
    v = out.ra and 2 or (out.ta and 1 or 0)
    if B747DR_tcas_traffic_out ~= v then B747DR_tcas_traffic_out = v end
    -- the PFDs' RA guidance: the panel's red pitch regions, VSI regions and
    -- vertical speed pointer
    v = B747_nav_flag(out.pfd_ra)
    if B747DR_tcas_pfd_ra_out ~= v then B747DR_tcas_pfd_ra_out = v end
    v = B747_nav_flag(out.vs_lo ~= nil)
    if B747DR_tcas_pfd_lo_on_out ~= v then B747DR_tcas_pfd_lo_on_out = v end
    v = B747_nav_flag(out.vs_hi ~= nil)
    if B747DR_tcas_pfd_hi_on_out ~= v then B747DR_tcas_pfd_hi_on_out = v end
    if out.vs_lo and B747DR_tcas_pfd_vs_lo_out ~= out.vs_lo then B747DR_tcas_pfd_vs_lo_out = out.vs_lo end
    if out.vs_hi and B747DR_tcas_pfd_vs_hi_out ~= out.vs_hi then B747DR_tcas_pfd_vs_hi_out = out.vs_hi end
    if out.pitch_lo and B747DR_tcas_pfd_pitch_lo_out ~= out.pitch_lo then B747DR_tcas_pfd_pitch_lo_out = out.pitch_lo end
    if out.pitch_hi and B747DR_tcas_pfd_pitch_hi_out ~= out.pitch_hi then B747DR_tcas_pfd_pitch_hi_out = out.pitch_hi end
    v = B747_nav_flag(out.vs_red)
    if B747DR_tcas_pfd_vs_red_out ~= v then B747DR_tcas_pfd_vs_red_out = v end
    -- the NDs
    for i = 1, 2 do
        local nd = out.nd[i]
        v = B747_nav_flag(nd.tfc)
        if B747DR_tcas_nd_tfc[i] ~= v then B747DR_tcas_nd_tfc[i] = v end
        v = B747_nav_flag(nd.off)
        if B747DR_tcas_nd_off[i] ~= v then B747DR_tcas_nd_off[i] = v end
        v = B747_nav_flag(nd.fail)
        if B747DR_tcas_nd_fail[i] ~= v then B747DR_tcas_nd_fail[i] = v end
        if B747DR_tcas_nd_traffic[i] ~= nd.traffic then B747DR_tcas_nd_traffic[i] = nd.traffic end
        if B747DR_tcas_nd_offscale[i] ~= nd.offscale then B747DR_tcas_nd_offscale[i] = nd.offscale end
        v = B747_nav_flag(nd.ta_only)
        if B747DR_tcas_nd_ta_only[i] ~= v then B747DR_tcas_nd_ta_only[i] = v end
        v = B747_nav_flag(nd.show)
        if B747DR_tcas_nd_show[i] ~= v then B747DR_tcas_nd_show[i] = v end
    end
    -- EICAS
    local adv = B747DR_tcas_CAS_advisory
    B747_nav_put(adv, ADV_TCAS_OFF, B747_nav_flag(out.msg_tcas_off))
    B747_nav_put(adv, ADV_TCAS_SYSTEM, B747_nav_flag(out.msg_tcas_system))
    B747_nav_put(adv, ADV_TCAS_RA_CAPT, B747_nav_flag(out.msg_ra[1]))
    B747_nav_put(adv, ADV_TCAS_RA_FO, B747_nav_flag(out.msg_ra[2]))
    B747_nav_put(adv, ADV_XPDR_L, B747_nav_flag(out.xpdr_msg[1]))
    B747_nav_put(adv, ADV_XPDR_R, B747_nav_flag(out.xpdr_msg[2]))
end

function B747_tcas_flight_start()
    tcas_state = TC.new()
    tcas_t0 = nil
end
