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

local SW_CARGO_ARM_FWD, SW_CARGO_ARM_AFT = 84, 85
local CAUT_EQUIP_COOLING = 27       -- B747.87.xt.warning.lua

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
    local out = Q.update(eqcool_state, inp, SIM_PERIOD)
    B747_eqcool_overboard_kg_s = out.overboard_kg_s
    local state = out.state
    if B747DR_equip_cooling_state ~= state then B747DR_equip_cooling_state = state end
    local alert = flag(out.alert)
    if B747DR_CAS_caution_status[CAUT_EQUIP_COOLING] ~= alert then B747DR_CAS_caution_status[CAUT_EQUIP_COOLING] = alert end
end
