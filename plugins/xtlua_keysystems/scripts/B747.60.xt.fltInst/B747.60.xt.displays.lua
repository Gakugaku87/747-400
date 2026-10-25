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
-- dofile'd from B747.60.xt.fltInst.lua after B747.60.xt.fltInst02.lua.

dofile("B747.60.display_model.lua")
dofile("B747.60.pfd_model.lua")
local DM = B747_display_model
local PM = B747_pfd_model

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

-- the EIU selectors' positions: Captain and centre L, AUTO, C, R; F/O L, C, AUTO, R
local EIU_CAPT = {[0] = DM.EIU_L, DM.SEL_AUTO, DM.EIU_C, DM.EIU_R}
local EIU_FO = {[0] = DM.EIU_L, DM.EIU_C, DM.SEL_AUTO, DM.EIU_R}
local ADV_EIU_LEFT = 91
local ADV_EFIS_CONTROL, ADV_EFIS_EICAS_CP = {88, 89}, 90
local ADV_SOURCE_SEL_EIU, ADV_SOURCE_SEL_FD, ADV_SOURCE_SEL_NAV = 268, 269, 271
-- the NAV source selectors' positions (FCOM p.1043; the F/O's knob mirrored):
-- Captain FMC L, FMC R, CDU L, CDU C; F/O CDU C, CDU R, FMC L, FMC R (0 a CDU)
local NAV_CAPT = {[0] = 1, 2, 0, 0}
local NAV_FO = {[0] = 0, 0, 1, 2}

local dsp_state = DM.new()
local dsp_inputs = DM.inputs()
local pfd_state = PM.new()
local pfd_inputs = PM.inputs()

local function msg(i, on)
    local v = on and 1 or 0
    if B747DR_CAS_advisory_status[i] ~= v then B747DR_CAS_advisory_status[i] = v end
end

local function knob(v, map)
    return map[math.max(0, math.min(3, math.floor(v + 0.5)))]
end

-- an IRS source selector (0 L, 1 C, 2 R) as the IRU
local function iru(v)
    return math.max(1, math.min(3, math.floor(v + 0.5) + 1))
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
