-- The weather radar control (5-1 step 5c; notes/ATA-34.md §17): the 570
-- panel's switches go to the model (B747.34.wxr_model.lua); X-Plane's own
-- weather radar commands, which the 3D panel's knobs and mode switches use,
-- are replaced so that they move the model's panel, and the model's mode,
-- tilt, gain, GCS and stabilization for each ND are written to X-Plane's
-- radar, which draws the returns. dofile'd from B747.34.xt.nav.lua.

dofile("B747.34.wxr_model.lua")
local WX = B747_wxr_model

simDR_wxr_mode                  = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_mode"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_mode_copilot")}
simDR_wxr_tilt                  = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_tilt"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_tilt_copilot")}
simDR_wxr_gain                  = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_gain"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_gain_copilot")}
simDR_wxr_gcs                   = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_gcs"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_gcs_copilot")}
simDR_wxr_stab                  = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_stab"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_stab_copilot")}
simDR_wxr_on                    = {find_dataref("sim/cockpit2/EFIS/EFIS_weather_on"), find_dataref("sim/cockpit2/EFIS/EFIS_weather_on_copilot")}
simDR_wxr_sector                = find_dataref("sim/cockpit2/EFIS/EFIS_weather_sector_width")
simDR_wxr_antenna_limit         = find_dataref("sim/cockpit2/EFIS/EFIS_weather_antenna_limit")
simDR_wxr_failure               = find_dataref("sim/operation/failures/rel_wxr_radar")
simDR_wxr_time                  = find_dataref("sim/time/total_running_time_sec")
B747DR_wxr_nd_range             = {find_dataref("laminar/B747/nd/range/capt/sel_dial_pos"), find_dataref("laminar/B747/nd/range/fo/sel_dial_pos")}
B747DR_wxr_bus_ac               = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_wxr_att_valid            = find_dataref("laminar/B747/irs/att_valid")
B747DR_wxr_irs_src              = {find_dataref("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos"), find_dataref("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos")}
-- the new failures: [0] the antenna, [1] the control panel, [2] the
-- receiver's calibration (AGC)
B747DR_wxr_fail                 = find_dataref("laminar/B747/wxr/fail")
-- each ND's annunciations for the ND module (B747.61.xt.nd.lua): WXR FAIL,
-- the fault source in TEST, WEAK or ATT, CAL or VAR (wxr_model's codes)
B747DR_wxr_nd_fail              = find_dataref("laminar/B747/wxr/nd_fail")
B747DR_wxr_nd_fault             = find_dataref("laminar/B747/wxr/nd_fault")
B747DR_wxr_nd_msg               = find_dataref("laminar/B747/wxr/nd_msg")
B747DR_wxr_nd_gain              = find_dataref("laminar/B747/wxr/nd_gain")
-- the panel's lamps for the lighting module (B747.90.xt.lighting.lua)
B747DR_wxr_lamp_sel             = find_dataref("laminar/B747/wxr/lamp/sel")
B747DR_wxr_lamp_gcs             = find_dataref("laminar/B747/wxr/lamp/gcs")
B747DR_wxr_lamp_test            = find_dataref("laminar/B747/wxr/lamp/test")
B747DR_wxr_lamp_rt              = find_dataref("laminar/B747/wxr/lamp/rt")

local RANGES_NM = {10, 20, 40, 80, 160, 320, 640}
local XP_FAILED = 6
local INIT_S = 3                                -- the first reads are 0
-- the antenna scans 90 deg each side (ATA34_1 p.231; X-Plane's default is 50)
local SCAN_DEG = 90
local SEL_OF_XP = {[WX.XP_WX] = WX.SEL_WX, [WX.XP_WXT] = WX.SEL_WXT, [WX.XP_MAP] = WX.SEL_MAP}

local wxr_state = WX.new()
local wxr_inputs = WX.inputs()
local wxr_t0 = nil
local wxr_taken = false                         -- the panel taken from X-Plane's radar

-- the panel starts as X-Plane's radar was left
local function take_panel()
    local s = wxr_state
    for i = 1, 2 do
        s.sel[i] = SEL_OF_XP[simDR_wxr_mode[i]] or WX.SEL_WX
        s.tilt[i] = math.max(-WX.TILT_MAX, math.min(WX.TILT_MAX, simDR_wxr_tilt[i]))
        s.gain[i] = math.max(0, math.min(WX.GAIN_CAL, simDR_wxr_gain[i]))
        s.gcs[i] = simDR_wxr_gcs[i] > 0.5
    end
end

-- the panel's switches (FCOM p.1223-1224)
local function on_push(phase, f)
    if phase == 0 then f() end
end
function B747_wxr_test_CMDhandler(phase, duration) on_push(phase, function() WX.test(wxr_state) end) end
function B747_wxr_lr_CMDhandler(phase, duration) on_push(phase, function() WX.select_rt(wxr_state, WX.RT_L) end) end
function B747_wxr_rr_CMDhandler(phase, duration) on_push(phase, function() WX.select_rt(wxr_state, WX.RT_R) end) end
function B747_wxr_cpt_tfr_CMDhandler(phase, duration) on_push(phase, function() WX.mode(wxr_state, 1, WX.SEL_TFR) end) end
function B747_wxr_fo_tfr_CMDhandler(phase, duration) on_push(phase, function() WX.mode(wxr_state, 2, WX.SEL_TFR) end) end
B747CMD_wxr_test                = deferred_command("laminar/B747/wxr/buttons/test", "WXR Test", B747_wxr_test_CMDhandler)
B747CMD_wxr_rr                  = deferred_command("laminar/B747/wxr/buttons/rr", "WXR RR", B747_wxr_rr_CMDhandler)
B747CMD_wxr_lr                  = deferred_command("laminar/B747/wxr/buttons/lr", "WXR LR", B747_wxr_lr_CMDhandler)
B747CMD_wxr_cpt_tfr             = deferred_command("laminar/B747/wxr/buttons/cpt_ftr", "WXR CPT TFR", B747_wxr_cpt_tfr_CMDhandler)
B747CMD_wxr_fo_tfr              = deferred_command("laminar/B747/wxr/buttons/fo_ftr", "WXR FO TFR", B747_wxr_fo_tfr_CMDhandler)

-- X-Plane's radar commands (the 3D panel's knobs and WX, WX+T, MAP, GCS)
-- move the model's panel instead of X-Plane's radar
local function replace_side(suffix, side)
    local function rep(name, f)
        return replace_command("sim/instruments/EFIS_wxr_" .. name .. suffix, function(phase, duration) on_push(phase, f) end)
    end
    return {
        rep("radar_wx", function() WX.mode(wxr_state, side, WX.SEL_WX) end),
        rep("radar_wxt", function() WX.mode(wxr_state, side, WX.SEL_WXT) end),
        rep("radar_map", function() WX.mode(wxr_state, side, WX.SEL_MAP) end),
        rep("radar_test", function() WX.test(wxr_state) end),
        rep("tilt_up", function() WX.tilt(wxr_state, side, 1) end),
        rep("tilt_down", function() WX.tilt(wxr_state, side, -1) end),
        rep("gain_up", function() WX.gain(wxr_state, side, 1) end),
        rep("gain_down", function() WX.gain(wxr_state, side, -1) end),
        rep("gain_cal", function() wxr_state.gain[side] = WX.GAIN_CAL end),
        rep("gcs_tog", function() WX.toggle_gcs(wxr_state, side) end),
        rep("gcs_on", function() wxr_state.gcs[side] = true end),
        rep("gcs_off", function() wxr_state.gcs[side] = false end),
    }
end
simCMD_wxr_capt = replace_side("", 1)
simCMD_wxr_fo = replace_side("_copilot", 2)

-- X-Plane keeps floats: written again only when it differs by more than this
local function differs(a, b) return math.abs(a - b) > 1e-4 end

function B747_wxr()
    local now = simDR_wxr_time
    if wxr_t0 == nil then wxr_t0 = now end
    if now - wxr_t0 < INIT_S then return end
    if not wxr_taken then
        take_panel()
        wxr_taken = true
    end

    local inp = wxr_inputs
    for i = 1, 2 do
        inp.on[i] = simDR_wxr_on[i] > 0.5
        inp.range_nm[i] = RANGES_NM[math.floor(B747DR_wxr_nd_range[i] + 0.5) + 1] or 640
        inp.irs_src[i] = math.floor(B747DR_wxr_irs_src[i] + 0.5)
    end
    -- the R/Ts' 115 V AC: L on AC bus 1, R on AC bus 2 (estimate: the manual
    -- names only their own circuit breakers, ATA34_1 p.210)
    inp.power[1] = B747DR_wxr_bus_ac[0] > 0.5
    inp.power[2] = B747DR_wxr_bus_ac[1] > 0.5
    inp.failed = simDR_wxr_failure == XP_FAILED
    inp.fail_ant = B747DR_wxr_fail[0] > 0.5
    inp.fail_cont = B747DR_wxr_fail[1] > 0.5
    inp.fail_weak = B747DR_wxr_fail[2] > 0.5
    for k = 1, 3 do inp.att_valid[k] = B747DR_wxr_att_valid[k - 1] > 0.5 end

    local out = WX.update(wxr_state, inp)
    local stab = B747_nav_flag(out.stab)
    for i = 1, 2 do
        if simDR_wxr_mode[i] ~= out.xp_mode[i] then simDR_wxr_mode[i] = out.xp_mode[i] end
        if differs(simDR_wxr_tilt[i], out.tilt[i]) then simDR_wxr_tilt[i] = out.tilt[i] end
        if differs(simDR_wxr_gain[i], out.gain[i]) then simDR_wxr_gain[i] = out.gain[i] end
        local gcs = B747_nav_flag(out.gcs[i])
        if simDR_wxr_gcs[i] ~= gcs then simDR_wxr_gcs[i] = gcs end
        if simDR_wxr_stab[i] ~= stab then simDR_wxr_stab[i] = stab end
        B747_nav_put(B747DR_wxr_lamp_sel, i - 1, out.lamp_sel[i])
        B747_nav_put(B747DR_wxr_lamp_gcs, i - 1, B747_nav_flag(out.lamp_gcs[i]))
        B747_nav_put(B747DR_wxr_nd_fail, i - 1, B747_nav_flag(out.nd_fail[i]))
        B747_nav_put(B747DR_wxr_nd_fault, i - 1, out.nd_fault[i])
        B747_nav_put(B747DR_wxr_nd_msg, i - 1, out.nd_msg[i])
        B747_nav_put(B747DR_wxr_nd_gain, i - 1, out.nd_gain[i])
    end
    if simDR_wxr_sector ~= SCAN_DEG then simDR_wxr_sector = SCAN_DEG end
    if simDR_wxr_antenna_limit ~= SCAN_DEG then simDR_wxr_antenna_limit = SCAN_DEG end
    local v = B747_nav_flag(out.lamp_test)
    if B747DR_wxr_lamp_test ~= v then B747DR_wxr_lamp_test = v end
    if B747DR_wxr_lamp_rt ~= out.lamp_rt then B747DR_wxr_lamp_rt = out.lamp_rt end
end

function B747_wxr_flight_start()
    wxr_state = WX.new()
    wxr_t0 = nil
    wxr_taken = false
end
