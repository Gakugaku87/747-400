-- The radio tuning panels and the radios in the aircraft (7-1a;
-- docs/overhaul/notes/ATA-23.md §11) on B747.15.radio_model.lua: the
-- panels' commands (the OFF, radio tuning, AM and transfer switches, the
-- frequency knobs), their lights and windows (lcd_to_display, stby_show),
-- VHF C's and the HF's frequencies; VHF L and R tuned through X-Plane's
-- COM1 and COM2 (on the 109 by 25 kHz, on the 570 by 8.33 kHz: FCOM
-- p.714). X-Plane's COM1 and COM2 powered by VHF L's and VHF R's buses
-- (before, by a panel showing them: COM-01). Before, the AM switch took
-- the panel off its radio (COM-04), VHF C and the HF had no frequencies
-- (COM-03), the right panel's inner knob held up tuned down (COM-11) and
-- some knobs tuned with the panel OFF (COM-12).
dofile("B747.15.radio_model.lua")
local RM = B747_radio_model
local rtpState = RM.new()

B747DR_rtp_L_stby_show             = find_dataref("laminar/B747/comm/rtp_L/stby_show")
B747DR_rtp_C_stby_show             = find_dataref("laminar/B747/comm/rtp_C/stby_show")
B747DR_rtp_R_stby_show             = find_dataref("laminar/B747/comm/rtp_R/stby_show")
B747DR_com_vhf_C_active_khz         = find_dataref("laminar/B747/comm/vhf_C/active_khz")
B747DR_com_vhf_C_standby_khz        = find_dataref("laminar/B747/comm/vhf_C/standby_khz")
B747DR_com_hf_L_active_khz          = find_dataref("laminar/B747/comm/hf_L/active_khz")
B747DR_com_hf_L_standby_khz         = find_dataref("laminar/B747/comm/hf_L/standby_khz")
B747DR_com_hf_L_am                  = find_dataref("laminar/B747/comm/hf_L/am")
B747DR_com_hf_R_active_khz          = find_dataref("laminar/B747/comm/hf_R/active_khz")
B747DR_com_hf_R_standby_khz         = find_dataref("laminar/B747/comm/hf_R/standby_khz")
B747DR_com_hf_R_am                  = find_dataref("laminar/B747/comm/hf_R/am")
B747DR_rtp_bus_dc                   = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_rtp_bus_bat_main             = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_rtp_engine_type              = find_dataref("laminar/B747/engines/type")
-- X-Plane's 25 kHz knob (the 109; the 8.33 kHz ones: simCMD_com*_stby_fine_*)
simCMD_com1_stby_fine_up_25         = find_command("sim/radios/stby_com1_fine_up")
simCMD_com1_stby_fine_dn_25         = find_command("sim/radios/stby_com1_fine_down")
simCMD_com2_stby_fine_up_25         = find_command("sim/radios/stby_com2_fine_up")
simCMD_com2_stby_fine_dn_25         = find_command("sim/radios/stby_com2_fine_down")

-- the panels' power: the left panel the main battery bus (FCOM p.819); the
-- center and right panels' not in the sources (estimate: DC buses 1, 2,
-- as VHF C's and VHF R's)
local function panels_powered()
    return {L = B747DR_rtp_bus_bat_main > 0.5, C = B747DR_rtp_bus_dc[0] > 0.5, R = B747DR_rtp_bus_dc[1] > 0.5}
end

-- X-Plane's commands for VHF L (COM1) and VHF R (COM2)
local function xp_knob(radio, knob, dir)
    local one = radio == "vhf_L"
    local khz833 = B747DR_rtp_engine_type == 1 -- the GE: the 570 (FCOM effectivity)
    local c
    if knob == "MHz" then
        if one then c = dir > 0 and simCMD_com1_stby_coarse_up or simCMD_com1_stby_coarse_dn
        else c = dir > 0 and simCMD_com2_stby_coarse_up or simCMD_com2_stby_coarse_dn end
    elseif khz833 then
        if one then c = dir > 0 and simCMD_com1_stby_fine_up or simCMD_com1_stby_fine_dn
        else c = dir > 0 and simCMD_com2_stby_fine_up or simCMD_com2_stby_fine_dn end
    else
        if one then c = dir > 0 and simCMD_com1_stby_fine_up_25 or simCMD_com1_stby_fine_dn_25
        else c = dir > 0 and simCMD_com2_stby_fine_up_25 or simCMD_com2_stby_fine_dn_25 end
    end
    c:once()
end

-- the handlers
local function sel(panel, radio)
    return function(phase, duration)
        if phase == 0 then RM.select(rtpState, panel, radio) end
    end
end
local function off(panel)
    return function(phase, duration)
        if phase == 0 then RM.off(rtpState, panel) end
    end
end
local function am(panel)
    return function(phase, duration)
        if phase == 0 then RM.am(rtpState, panel) end
    end
end
local function transfer(panel)
    return function(phase, duration)
        if phase ~= 0 then return end
        local what, radio = RM.transfer(rtpState, panel)
        if what == "xp" then
            if radio == "vhf_L" then simCMD_com1_stby_flip:once() else simCMD_com2_stby_flip:once() end
        end
    end
end
-- a knob: a step at the push, then repeating after 0.5 s held (as before);
-- the 3D knob's position turns with it (dial(): read, set)
local function knob(panel, which, dir, dial)
    return function(phase, duration)
        if phase == 0 or (phase == 1 and duration > 0.5) then
            local what, radio = RM.knob(rtpState, panel, which, dir)
            if what == "xp" then xp_knob(radio, which, dir) end
            dial(dir)
        end
    end
end

B747_rtp_L_off_switch_CMDhandler = off("L")
B747_rtp_L_vhf_L_sel_switch_CMDhandler = sel("L", "vhf_L")
B747_rtp_L_vhf_C_sel_switch_CMDhandler = sel("L", "vhf_C")
B747_rtp_L_vhf_R_sel_switch_CMDhandler = sel("L", "vhf_R")
B747_rtp_L_hf_L_sel_switch_CMDhandler = sel("L", "hf_L")
B747_rtp_L_hf_R_sel_switch_CMDhandler = sel("L", "hf_R")
B747_rtp_L_am_sel_switch_CMDhandler = am("L")
B747_rtp_L_freq_txfr_switch_CMDhandler = transfer("L")
B747_rtp_L_freq_MHz_sel_dial_up_CMDhandler = knob("L", "MHz", 1, function(d) B747DR_rtp_L_freq_MHz_sel_dial_pos = B747DR_rtp_L_freq_MHz_sel_dial_pos + d end)
B747_rtp_L_freq_MHz_sel_dial_dn_CMDhandler = knob("L", "MHz", -1, function(d) B747DR_rtp_L_freq_MHz_sel_dial_pos = B747DR_rtp_L_freq_MHz_sel_dial_pos + d end)
B747_rtp_L_freq_khz_sel_dial_up_CMDhandler = knob("L", "kHz", 1, function(d) B747DR_rtp_L_freq_khz_sel_dial_pos = B747DR_rtp_L_freq_khz_sel_dial_pos + d end)
B747_rtp_L_freq_khz_sel_dial_dn_CMDhandler = knob("L", "kHz", -1, function(d) B747DR_rtp_L_freq_khz_sel_dial_pos = B747DR_rtp_L_freq_khz_sel_dial_pos + d end)

B747_rtp_C_off_switch_CMDhandler = off("C")
B747_rtp_C_vhf_L_sel_switch_CMDhandler = sel("C", "vhf_L")
B747_rtp_C_vhf_C_sel_switch_CMDhandler = sel("C", "vhf_C")
B747_rtp_C_vhf_R_sel_switch_CMDhandler = sel("C", "vhf_R")
B747_rtp_C_hf_L_sel_switch_CMDhandler = sel("C", "hf_L")
B747_rtp_C_hf_R_sel_switch_CMDhandler = sel("C", "hf_R")
B747_rtp_C_am_sel_switch_CMDhandler = am("C")
B747_rtp_C_freq_txfr_switch_CMDhandler = transfer("C")
B747_rtp_C_freq_MHz_sel_dial_up_CMDhandler = knob("C", "MHz", 1, function(d) B747DR_rtp_C_freq_MHz_sel_dial_pos = B747DR_rtp_C_freq_MHz_sel_dial_pos + d end)
B747_rtp_C_freq_MHz_sel_dial_dn_CMDhandler = knob("C", "MHz", -1, function(d) B747DR_rtp_C_freq_MHz_sel_dial_pos = B747DR_rtp_C_freq_MHz_sel_dial_pos + d end)
B747_rtp_C_freq_khz_sel_dial_up_CMDhandler = knob("C", "kHz", 1, function(d) B747DR_rtp_C_freq_khz_sel_dial_pos = B747DR_rtp_C_freq_khz_sel_dial_pos + d end)
B747_rtp_C_freq_khz_sel_dial_dn_CMDhandler = knob("C", "kHz", -1, function(d) B747DR_rtp_C_freq_khz_sel_dial_pos = B747DR_rtp_C_freq_khz_sel_dial_pos + d end)

B747_rtp_R_off_switch_CMDhandler = off("R")
B747_rtp_R_vhf_L_sel_switch_CMDhandler = sel("R", "vhf_L")
B747_rtp_R_vhf_C_sel_switch_CMDhandler = sel("R", "vhf_C")
B747_rtp_R_vhf_R_sel_switch_CMDhandler = sel("R", "vhf_R")
B747_rtp_R_hf_L_sel_switch_CMDhandler = sel("R", "hf_L")
B747_rtp_R_hf_R_sel_switch_CMDhandler = sel("R", "hf_R")
B747_rtp_R_am_sel_switch_CMDhandler = am("R")
B747_rtp_R_freq_txfr_switch_CMDhandler = transfer("R")
B747_rtp_R_freq_MHz_sel_dial_up_CMDhandler = knob("R", "MHz", 1, function(d) B747DR_rtp_R_freq_MHz_sel_dial_pos = B747DR_rtp_R_freq_MHz_sel_dial_pos + d end)
B747_rtp_R_freq_MHz_sel_dial_dn_CMDhandler = knob("R", "MHz", -1, function(d) B747DR_rtp_R_freq_MHz_sel_dial_pos = B747DR_rtp_R_freq_MHz_sel_dial_pos + d end)
B747_rtp_R_freq_khz_sel_dial_up_CMDhandler = knob("R", "kHz", 1, function(d) B747DR_rtp_R_freq_khz_sel_dial_pos = B747DR_rtp_R_freq_khz_sel_dial_pos + d end)
B747_rtp_R_freq_khz_sel_dial_dn_CMDhandler = knob("R", "kHz", -1, function(d) B747DR_rtp_R_freq_khz_sel_dial_pos = B747DR_rtp_R_freq_khz_sel_dial_pos + d end)

-- a new flight: the panels on their own radios, VHF C in data mode
function B747_rtp_reset()
    rtpState = RM.new()
end

-- every frame: the panels' lights and windows, the model radios' datarefs,
-- X-Plane's COM1 and COM2 power
local function flag(v) return v and 1 or 0 end
function B747_rtp_update()
    local powered = panels_powered()
    local out = RM.panels(rtpState, powered)
    local s = rtpState
    local function lights(p, o)
        local q = s.rtp[p]
        local on = not q.off and powered[p]
        local function is(r) return flag(on and q.sel == r) end
        local hf = (q.sel == "hf_L" or q.sel == "hf_R") and s.radio[q.sel] or nil
        return flag(q.off), flag(o.offside), is("vhf_L"), is("vhf_C"), is("vhf_R"), is("hf_L"), is("hf_R"),
            flag(on and hf and hf.am), o.show, o.stby
    end
    B747DR_rtp_L_off_status, B747DR_rtp_L_offside_tuning_status, B747DR_rtp_L_vhf_L_status, B747DR_rtp_L_vhf_C_status,
        B747DR_rtp_L_vhf_R_status, B747DR_rtp_L_hf_L_status, B747DR_rtp_L_hf_R_status, B747DR_rtp_L_am_status,
        B747DR_rtp_L_lcd_to_display, B747DR_rtp_L_stby_show = lights("L", out.L)
    B747DR_rtp_C_off_status, B747DR_rtp_C_offside_tuning_status, B747DR_rtp_C_vhf_L_status, B747DR_rtp_C_vhf_C_status,
        B747DR_rtp_C_vhf_R_status, B747DR_rtp_C_hf_L_status, B747DR_rtp_C_hf_R_status, B747DR_rtp_C_am_status,
        B747DR_rtp_C_lcd_to_display, B747DR_rtp_C_stby_show = lights("C", out.C)
    B747DR_rtp_R_off_status, B747DR_rtp_R_offside_tuning_status, B747DR_rtp_R_vhf_L_status, B747DR_rtp_R_vhf_C_status,
        B747DR_rtp_R_vhf_R_status, B747DR_rtp_R_hf_L_status, B747DR_rtp_R_hf_R_status, B747DR_rtp_R_am_status,
        B747DR_rtp_R_lcd_to_display, B747DR_rtp_R_stby_show = lights("R", out.R)
    local r = s.radio
    B747DR_com_vhf_C_active_khz, B747DR_com_vhf_C_standby_khz = r.vhf_C.active, r.vhf_C.standby
    B747DR_com_hf_L_active_khz, B747DR_com_hf_L_standby_khz, B747DR_com_hf_L_am = r.hf_L.active, r.hf_L.standby, flag(r.hf_L.am)
    B747DR_com_hf_R_active_khz, B747DR_com_hf_R_standby_khz, B747DR_com_hf_R_am = r.hf_R.active, r.hf_R.standby, flag(r.hf_R.am)
    -- VHF L on the main battery bus (FCOM p.819); VHF R's bus not in the
    -- sources (estimate: DC bus 2)
    simDR_audio_com1_power = flag(B747DR_rtp_bus_bat_main > 0.5)
    simDR_audio_com2_power = flag(B747DR_rtp_bus_dc[1] > 0.5)
end
