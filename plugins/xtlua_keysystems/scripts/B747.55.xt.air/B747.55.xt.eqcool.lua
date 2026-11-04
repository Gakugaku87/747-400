-- The equipment cooling model (B747.55.eqcool_model.lua) in the aircraft:
-- reads the EQUIP COOLING selector, the air/ground relays, the engines
-- running, the outside air (the skin temperature), cargo fire ARM, the
-- cabin's differential pressure (the pressurization model) and the buses;
-- writes laminar/B747/air/equip_cooling/state (1 with the fans running),
-- EQUIP COOLING, the air OVRD takes overboard for the pressurization model,
-- and the exhaust into the forward cargo for the temperature glue
-- (B747_eqcool_out). B747.55.xt.air.lua loads it after the pressurization
-- glue.
dofile("B747.55.eqcool_model.lua")
local Q = B747_eqcool_model

simDR_eqcool_oat                = find_dataref("sim/weather/aircraft/temperature_ambient_deg_c")

-- (2026-11-04) the failures (notes/ATA-21.md §10) and the STATUS messages
B747DR_air_fail_eq_fan          = find_dataref("laminar/B747/air/fail/eq_fan")
B747DR_air_fail_eq_ovht         = find_dataref("laminar/B747/air/fail/eq_ovht")
B747DR_air_fail_eq_low_flow     = find_dataref("laminar/B747/air/fail/eq_low_flow")
B747DR_air_fail_fd_low_flow     = find_dataref("laminar/B747/air/fail/fd_low_flow")
B747DR_air_fail_eq_smoke        = find_dataref("laminar/B747/air/fail/eq_smoke")
B747DR_air_fail_eq_card         = find_dataref("laminar/B747/air/fail/eq_card")
B747DR_eqcool_status            = find_dataref("laminar/B747/CAS/status_status")

local SW_CARGO_ARM_FWD, SW_CARGO_ARM_AFT = 84, 85
local CAUT_EQUIP_COOLING = 27       -- B747.87.xt.warning.lua
local ADV_EE_CLNG_CARD = 87         -- >E/E CLNG CARD
-- STATUS (2026-11-04): EE CLNG SUP FAN, EXH FAN, EQUIPMENT TEMP, EQUIP LOW
-- FLOW, FLT DK LOW FLOW, EQUIPMENT SMOKE, E/E CLNG CARD: 132-138
local STATUS_EQ = 132
local EQ_STATUS = {"st_sup_fan", "st_exh_fan", "st_temp", "st_low_flow", "st_fd_low_flow", "st_smoke", "st_card"}

local eqcool_state = Q.new()
local eqcool_inputs = Q.inputs()
B747_eqcool_overboard_kg_s = 0      -- for the pressurization glue (next frame)
B747_eqcool_out = setmetatable(eqcool_state.out, {})  -- for the temperature glue (B747.55.xt.packs.lua)

local function flag(v)
    if v then return 1 end
    return 0
end

function B747_eqcool_flight_start()
    eqcool_state = Q.new()
    B747_eqcool_overboard_kg_s = 0
    B747_eqcool_out = setmetatable(eqcool_state.out, {})
end

function B747_eqcool()
    local inp = eqcool_inputs
    inp.selector = math.floor(B747DR_equip_cooling_sel_pos + 0.5)
    inp.on_ground = B747DR_pack_pseu_pri_gnd == 1
    inp.engine_left = simDR_engine_running[0] == 1 or simDR_engine_running[1] == 1
    inp.engine_right = simDR_engine_running[2] == 1 or simDR_engine_running[3] == 1
    inp.skin_c = simDR_eqcool_oat
    inp.cargo_fire_arm = B747DR_button_switch_position[SW_CARGO_ARM_FWD] > 0.5
        or B747DR_button_switch_position[SW_CARGO_ARM_AFT] > 0.5
    inp.dp = B747_press_out.dp
    inp.ac = B747DR_pack_elec_any_ac > 0.5
    inp.bat = B747DR_press_bat_main > 0.5
    inp.fan_failed[1] = B747DR_air_fail_eq_fan[0] > 0.5
    inp.fan_failed[2] = B747DR_air_fail_eq_fan[1] > 0.5
    inp.overheat = B747DR_air_fail_eq_ovht > 0.5
    inp.low_flow = B747DR_air_fail_eq_low_flow > 0.5
    inp.fd_low_flow = B747DR_air_fail_fd_low_flow > 0.5
    inp.smoke = B747DR_air_fail_eq_smoke > 0.5
    inp.card_failed = B747DR_air_fail_eq_card > 0.5
    local out = Q.update(eqcool_state, inp, SIM_PERIOD)
    B747_eqcool_overboard_kg_s = out.overboard_kg_s
    local state = out.state
    if B747DR_equip_cooling_state ~= state then B747DR_equip_cooling_state = state end
    local alert = flag(out.alert)
    if B747DR_CAS_caution_status[CAUT_EQUIP_COOLING] ~= alert then B747DR_CAS_caution_status[CAUT_EQUIP_COOLING] = alert end
    local card = flag(out.card_alert)
    if B747DR_CAS_advisory_status[ADV_EE_CLNG_CARD] ~= card then B747DR_CAS_advisory_status[ADV_EE_CLNG_CARD] = card end
    for i = 1, #EQ_STATUS do
        local v = flag(out[EQ_STATUS[i]])
        if B747DR_eqcool_status[STATUS_EQ + i - 1] ~= v then B747DR_eqcool_status[STATUS_EQ + i - 1] = v end
    end
end
