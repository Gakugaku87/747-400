-- The display units and EIUs (5-2 step 1; notes/ATA-31.md §10): the INBD and
-- LWR display selectors, the buses, the unit and EIU failures and the EIU
-- selectors go to the model (B747.60.display_model.lua); each display's
-- position (flt_inst/display/*_pos) and power (electrical/display_has_power
-- [0..5]) come back for the panel, the unit showing each display for the
-- lighting module's brightness, the EIU in use and >EIU LEFT. Replaces the
-- old table of selector combinations (fltInstsetCRTs). dofile'd from
-- B747.60.xt.fltInst.lua after B747.60.xt.fltInst02.lua.

dofile("B747.60.display_model.lua")
local DM = B747_display_model

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

-- the EIU selectors' positions: Captain and centre L, AUTO, C, R; F/O L, C, AUTO, R
local EIU_CAPT = {[0] = DM.EIU_L, DM.SEL_AUTO, DM.EIU_C, DM.EIU_R}
local EIU_FO = {[0] = DM.EIU_L, DM.EIU_C, DM.SEL_AUTO, DM.EIU_R}
local ADV_EIU_LEFT = 91

local dsp_state = DM.new()
local dsp_inputs = DM.inputs()

local function knob(v, map)
    return map[math.max(0, math.min(3, math.floor(v + 0.5)))]
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
    local v = out.msg_eiu_left and 1 or 0
    if B747DR_CAS_advisory_status[ADV_EIU_LEFT] ~= v then B747DR_CAS_advisory_status[ADV_EIU_LEFT] = v end
end
