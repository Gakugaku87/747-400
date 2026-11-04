-- The ILS antenna switching model (B747.34.ils_ant_model.lua; 2026-11-04,
-- for the failure window) in the aircraft: reads the PSEU's air/ground and
-- nose gear down, the FCC's approach or localizer mode (the FMA: LOC armed
-- or engaged, ROLLOUT) and the failures laminar/B747/ils/fail/loc_antenna[3]
-- and gs_antenna[3]; writes STATUS G/S ANTENNA L, C, R and LOC ANTENNA L,
-- C, R and the caution ILS ANTENNA (docs/overhaul/notes/ATA-34.md §22).
-- B747.34.xt.nav.lua loads it.

dofile("B747.34.ils_ant_model.lua")
local IA = B747_ils_ant_model

B747DR_ils_pri_gnd              = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_ils_nose_not_down        = find_dataref("laminar/B747/gear/air_ground/nose_not_down")
B747DR_ils_armed_roll           = find_dataref("laminar/B747/autopilot/FMA/armed_roll_mode")
B747DR_ils_active_roll          = find_dataref("laminar/B747/autopilot/FMA/active_roll_mode")
B747DR_ils_fail_loc             = find_dataref("laminar/B747/ils/fail/loc_antenna")
B747DR_ils_fail_gs              = find_dataref("laminar/B747/ils/fail/gs_antenna")
B747DR_ils_CAS_caution          = find_dataref("laminar/B747/CAS/caution_status")
B747DR_ils_CAS_status           = find_dataref("laminar/B747/CAS/status_status")
local CAUT_ILS_ANTENNA = 47
local STATUS_GS_ANTENNA, STATUS_LOC_ANTENNA = 148, 151      -- L, C, R: 148-150 and 151-153
local ROLL_LOC, ROLL_ROLLOUT = 3, 4                         -- the FMA's roll modes

local ils_state = IA.new()
local ils_inputs = IA.inputs()

function B747_ils_flight_start()
    ils_state = IA.new()
end

function B747_ils()
    local inp = ils_inputs
    inp.on_ground = B747DR_ils_pri_gnd == 1
    inp.nose_down = B747DR_ils_nose_not_down < 0.5
    inp.fcc_app_loc = B747DR_ils_armed_roll == ROLL_LOC or B747DR_ils_active_roll == ROLL_LOC
        or B747DR_ils_active_roll == ROLL_ROLLOUT
    for n = 1, 3 do
        inp.loc_stuck[n] = B747DR_ils_fail_loc[n - 1] > 0.5
        inp.gs_stuck[n] = B747DR_ils_fail_gs[n - 1] > 0.5
    end
    local out = IA.update(ils_state, inp, SIM_PERIOD)
    for n = 1, 3 do
        B747_nav_put(B747DR_ils_CAS_status, STATUS_GS_ANTENNA + n - 1, B747_nav_flag(out.gs_status[n]))
        B747_nav_put(B747DR_ils_CAS_status, STATUS_LOC_ANTENNA + n - 1, B747_nav_flag(out.loc_status[n]))
    end
    B747_nav_put(B747DR_ils_CAS_caution, CAUT_ILS_ANTENNA, B747_nav_flag(out.ils_antenna))
end
