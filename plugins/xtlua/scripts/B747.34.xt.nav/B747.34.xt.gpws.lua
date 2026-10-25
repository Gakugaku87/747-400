-- The GPWS model (B747.34.gpws_model.lua) in the aircraft: reads the GPWC's
-- inputs (its radio altitude from B747.34.xt.ra.lua; the L IRU's vertical
-- speed and roll, else the L ADC's rate; the ADCs' CAS; the L ILS (X-Plane's
-- NAV 1); the gear lever, the FCU's flaps, the PSEU's air/ground; the GND
-- PROX panel; X-Plane's reactive windshear; the Captain's minimums; the
-- CDU's GPWS sound options) and writes laminar/B747/gpws/*: the voice and
-- the callout the .snd plays, the GND PROX light, PULL UP and WINDSHEAR on
-- the PFDs, the warning for master WARNING, and the EICAS advisories.
-- B747.34.xt.nav.lua loads it after B747.34.xt.ra.lua.

dofile("B747.34.gpws_model.lua")
local GP = B747_gpws_model

simDR_gpws_time                 = find_dataref("sim/time/total_running_time_sec")
simDR_gpws_vs_inertial          = find_dataref("sim/flightmodel/position/vh_ind_fpm")
simDR_gpws_vs_baro              = find_dataref("sim/cockpit2/gauges/indicators/vvi_fpm_pilot")
simDR_gpws_elevation            = find_dataref("sim/flightmodel/position/elevation")
simDR_gpws_cas                  = find_dataref("sim/flightmodel/position/indicated_airspeed")
simDR_gpws_roll                 = find_dataref("sim/flightmodel/position/phi")
simDR_gpws_gs_dots              = find_dataref("sim/cockpit2/radios/indicators/nav1_vdef_dots_pilot")
simDR_gpws_loc_dots             = find_dataref("sim/cockpit2/radios/indicators/nav1_hdef_dots_pilot")
simDR_gpws_gs_shown             = find_dataref("sim/cockpit2/radios/indicators/nav1_display_vertical")
simDR_gpws_loc_shown            = find_dataref("sim/cockpit2/radios/indicators/nav1_display_horizontal")
simDR_gpws_course               = find_dataref("sim/cockpit2/radios/actuators/nav1_course_deg_mag_pilot")
simDR_gpws_track                = find_dataref("sim/cockpit2/gauges/indicators/ground_track_mag_pilot")
simDR_gpws_gear_handle          = find_dataref("sim/cockpit2/controls/gear_handle_down")
simDR_gpws_windshear            = find_dataref("sim/cockpit2/annunciators/windshear_warning_systems")
simDR_gpws_dh_capt              = find_dataref("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot")
B747DR_gpws_bus_ac              = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_gpws_bus_stby            = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_gpws_irs_nav_valid       = find_dataref("laminar/B747/irs/nav_valid")
B747DR_gpws_irs_att_valid       = find_dataref("laminar/B747/irs/att_valid")
B747DR_gpws_adc_valid           = find_dataref("laminar/B747/airdata/valid")
B747DR_gpws_alt_capt            = find_dataref("laminar/B747/airdata/alt_capt")
B747DR_gpws_gps_valid           = find_dataref("laminar/B747/gps/valid")
B747DR_gpws_fcu_te_deg          = find_dataref("laminar/B747/flt_ctrls/fcu/te_deg")
B747DR_gpws_pseu_air            = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_gpws_button              = find_dataref("laminar/B747/button_switch/position")
B747DR_gpws_mins_sel_capt       = find_dataref("laminar/B747/efis/min_ref_alt/capt/sel_dial_pos")
B747DR_gpws_baro_mins_capt      = find_dataref("laminar/B747/efis/baro_ref/capt")
B747DR_gpws_snd_options         = find_dataref("laminar/B747/fmod/options/gpws")
B747DR_gpws_CAS_advisory        = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_gpws_gs_inhb_pushes      = find_dataref("laminar/B747/gpws/gs_inhb_pushes")
B747DR_gpws_fail                = find_dataref("laminar/B747/gpws/fail")
B747DR_gpws_voice               = find_dataref("laminar/B747/gpws/voice")
B747DR_gpws_callout             = find_dataref("laminar/B747/gpws/callout")
B747DR_gpws_last_callout        = find_dataref("laminar/B747/gpws/last_callout")
B747DR_gpws_gnd_prox_light      = find_dataref("laminar/B747/gpws/gnd_prox_light")
B747DR_gpws_pull_up             = find_dataref("laminar/B747/gpws/pull_up")
B747DR_gpws_windshear           = find_dataref("laminar/B747/gpws/windshear")
B747DR_gpws_warning             = find_dataref("laminar/B747/gpws/warning")
B747DR_gpws_alert               = find_dataref("laminar/B747/gpws/alert")
B747DR_gpws_gs_inhibited        = find_dataref("laminar/B747/gpws/gs_inhibited")

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_ALT_CALLOUTS, ADV_GND_PROX_SYS, ADV_TERR_POS, ADV_TERR_OVRD, ADV_WINDSHEAR_SYS = 6, 181, 288, 289, 298
-- button_switch/position: the GND PROX panel
local BTN_FLAP_OVRD, BTN_GEAR_OVRD, BTN_TERR_OVRD = 4, 5, 6
local FLAPS_25_DEG = 21                         -- the FCU's flaps 25 (22 deg) or 30, as CONFIG GEAR
local XP_REACTIVE_WINDSHEAR = 5
local M_TO_FT = 3.28084
-- X-Plane's glide slope deflection is negative with the airplane below it
-- (-2.5 dots far below the glide slope: s43_gpws, 2026-10-25; the PFD's
-- pointer moves up for it); the model takes + as below
local GS_SIGN = -1
-- the CDU's GPWS sound options (laminar/B747/fmod/options/gpws[n], 1 = off)
-- in the sound bank's order (fmod/warnings.bank)
local OPTION = {[2500] = 1, [1000] = 2, [500] = 3, [100] = 7, [50] = 8, [40] = 9, [30] = 10,
    [20] = 11, [10] = 12, [GP.C_MINIMUMS] = 14, [GP.C_APPROACHING_MINIMUMS] = 15}
local INIT_S = 3                                -- the first reads are 0

local gpws_state = GP.new()
local gpws_inputs = GP.inputs()
local gpws_t0 = nil
local gpws_pushes = nil

function B747_gpws()
    local now = simDR_gpws_time
    if gpws_t0 == nil then gpws_t0 = now end
    if now - gpws_t0 < INIT_S then return end

    local inp = gpws_inputs
    local ra, ra_valid = B747_ra_gpwc()
    inp.power = B747DR_gpws_bus_ac[2] > 0.5 and B747DR_gpws_fail < 0.5
    inp.ra, inp.ra_valid = ra, ra_valid
    -- the L IRU's inertial vertical speed and altitude (NAV), else the L ADC
    if B747DR_gpws_irs_nav_valid[0] > 0.5 then
        inp.vs, inp.vs_valid = simDR_gpws_vs_inertial, true
    elseif B747DR_gpws_adc_valid[0] > 0.5 then
        inp.vs, inp.vs_valid = simDR_gpws_vs_baro, true
    else
        inp.vs_valid = false
    end
    inp.alt = simDR_gpws_elevation * M_TO_FT
    inp.alt_valid = B747DR_gpws_irs_nav_valid[0] > 0.5 or B747DR_gpws_adc_valid[0] > 0.5
    inp.cas = simDR_gpws_cas
    inp.cas_valid = B747DR_gpws_adc_valid[0] > 0.5 or B747DR_gpws_adc_valid[2] > 0.5
    -- the L ILS: the AC standby bus (notes/ATA-34.md §2.1)
    local ils = B747DR_gpws_bus_stby > 0.5
    inp.gs_dev = GS_SIGN * simDR_gpws_gs_dots
    inp.gs_valid = ils and simDR_gpws_gs_shown == 1
    inp.loc_dev = simDR_gpws_loc_dots
    inp.loc_valid = ils and simDR_gpws_loc_shown == 1
    local d = math.abs((simDR_gpws_course - simDR_gpws_track + 540) % 360 - 180)
    inp.back_course = d > 90
    inp.roll = simDR_gpws_roll
    inp.roll_valid = B747DR_gpws_irs_att_valid[0] > 0.5
    inp.gear_down = simDR_gpws_gear_handle == 1
    local te = B747DR_gpws_fcu_te_deg
    inp.flaps_landing = math.min(te[0], te[1], te[2], te[3]) >= FLAPS_25_DEG
    inp.relay_air = B747DR_gpws_pseu_air == 1
    local pushes = B747DR_gpws_gs_inhb_pushes
    inp.gs_inhb_push = gpws_pushes ~= nil and pushes ~= gpws_pushes
    gpws_pushes = pushes
    inp.flap_ovrd = B747DR_gpws_button[BTN_FLAP_OVRD] > 0.5
    inp.gear_ovrd = B747DR_gpws_button[BTN_GEAR_OVRD] > 0.5
    inp.terr_ovrd = B747DR_gpws_button[BTN_TERR_OVRD] > 0.5
    inp.windshear = simDR_gpws_windshear == XP_REACTIVE_WINDSHEAR
    -- the Captain's minimums: RADIO (the GPWC's radio altitude) or BARO
    if B747DR_gpws_mins_sel_capt < 0.5 then
        inp.mins_ref, inp.mins = ra, simDR_gpws_dh_capt
    else
        inp.mins_ref, inp.mins = B747DR_gpws_alt_capt, B747DR_gpws_baro_mins_capt
    end
    for code, n in pairs(OPTION) do inp.callout_off[code] = B747DR_gpws_snd_options[n] > 0.5 end
    inp.gps_valid = B747DR_gpws_gps_valid[0] > 0.5 or B747DR_gpws_gps_valid[1] > 0.5

    local out = GP.update(gpws_state, inp, SIM_PERIOD)
    if B747DR_gpws_voice ~= out.voice then B747DR_gpws_voice = out.voice end
    if B747DR_gpws_callout ~= out.callout then B747DR_gpws_callout = out.callout end
    if B747DR_gpws_last_callout ~= out.last_callout then B747DR_gpws_last_callout = out.last_callout end
    local v = B747_nav_flag(out.gnd_prox_light)
    if B747DR_gpws_gnd_prox_light ~= v then B747DR_gpws_gnd_prox_light = v end
    v = B747_nav_flag(out.pull_up)
    if B747DR_gpws_pull_up ~= v then B747DR_gpws_pull_up = v end
    v = B747_nav_flag(out.windshear)
    if B747DR_gpws_windshear ~= v then B747DR_gpws_windshear = v end
    v = B747_nav_flag(out.warning)
    if B747DR_gpws_warning ~= v then B747DR_gpws_warning = v end
    v = B747_nav_flag(out.alert)
    if B747DR_gpws_alert ~= v then B747DR_gpws_alert = v end
    v = B747_nav_flag(out.gs_inhibited)
    if B747DR_gpws_gs_inhibited ~= v then B747DR_gpws_gs_inhibited = v end
    B747_nav_put(B747DR_gpws_CAS_advisory, ADV_ALT_CALLOUTS, B747_nav_flag(out.msg_alt_callouts))
    B747_nav_put(B747DR_gpws_CAS_advisory, ADV_GND_PROX_SYS, B747_nav_flag(out.msg_gnd_prox_sys))
    B747_nav_put(B747DR_gpws_CAS_advisory, ADV_TERR_POS, B747_nav_flag(out.msg_terr_pos))
    B747_nav_put(B747DR_gpws_CAS_advisory, ADV_TERR_OVRD, B747_nav_flag(out.msg_terr_ovrd))
    B747_nav_put(B747DR_gpws_CAS_advisory, ADV_WINDSHEAR_SYS, B747_nav_flag(out.msg_windshear_sys))
end

function B747_gpws_flight_start()
    gpws_state = GP.new()
    gpws_t0 = nil
    gpws_pushes = nil
end
