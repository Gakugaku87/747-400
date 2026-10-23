-- The temperature model (B747.55.temp_model.lua) in the aircraft: reads
-- the PASS TEMP and FLT DECK TEMP knobs, TRIM AIR, ZONE RST, AFT CARGO HT,
-- AFT cargo fire ARM, the packs' air and the recirculation fans (the pack
-- model), the centre duct, the altitudes, the air/ground relay, the
-- pressurization model's cruise clamp and descent detect, the outside air,
-- the engines, the equipment cooling exhaust (the equipment cooling model)
-- and the buses; writes the zone, cargo and pack outlet temperatures (°C),
-- the master trim air valve, the ZONE SYS FAULT and aft cargo TEMP lights,
-- TEMP ZONE, >TRIM AIR OFF, TEMP CARGO HEAT, the STATUS ZONE TEMP and, for
-- the pack glue, whether the cabin is at its target. B747.55.xt.air.lua
-- loads it after the equipment cooling glue.
dofile("B747.55.temp_model.lua")
local T = B747_temp_model

simDR_temp_tat                  = find_dataref("sim/weather/aircraft/temperature_leadingedge_deg_c")
B747DR_temp_zone_actual         = find_dataref("laminar/B747/air/temp/zone_actual")
B747DR_temp_zone_target         = find_dataref("laminar/B747/air/temp/zone_target")
B747DR_temp_target_shown        = find_dataref("laminar/B747/air/temp/target_shown")
B747DR_temp_master              = find_dataref("laminar/B747/air/temp/master")
B747DR_temp_cargo               = find_dataref("laminar/B747/air/temp/cargo")
B747DR_temp_pack_outlet         = find_dataref("laminar/B747/air/temp/pack_outlet")
B747DR_temp_trim_air_valve      = find_dataref("laminar/B747/air/temp/trim_air_valve")
B747DR_temp_light_zone_fault    = find_dataref("laminar/B747/air/light/zone_sys_fault")
B747DR_temp_light_aft_cargo     = find_dataref("laminar/B747/air/light/aft_cargo_temp")

local SW_ZONE_RST, SW_TRIM_AIR, SW_AFT_CARGO_HT, SW_CARGO_ARM_AFT = 36, 37, 40, 85
-- EICAS slots (B747.87.xt.warning.lua)
local ADV_TEMP_CARGO_HEAT, ADV_TEMP_ZONE, ADV_TRIM_AIR_OFF = 284, 287, 294
local STATUS_ZONE_TEMP = 36

local temp_state = T.new()
local temp_inputs = T.inputs()
local zone_rst_last = false
B747_temp_settled = true            -- for the pack glue (next frame)

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_temp_flight_start()
    temp_state = T.new()
    zone_rst_last = false
    B747_temp_settled = true
end

function B747_temp()
    local inp = temp_inputs
    local pack = B747_pack_out
    inp.pass_sel = B747DR_pass_temp_ctrl__rheo
    inp.fd_sel = B747DR_flt_deck_temp_ctrl_rheo
    inp.trim_air = B747DR_button_switch_position[SW_TRIM_AIR] > 0.5
    local rst = B747DR_button_switch_position[SW_ZONE_RST] > 0.5    -- momentary: the push
    inp.zone_rst = rst and not zone_rst_last
    zone_rst_last = rst
    inp.aft_heat = B747DR_button_switch_position[SW_AFT_CARGO_HT] > 0.5
    inp.aft_fire_arm = B747DR_button_switch_position[SW_CARGO_ARM_AFT] > 0.5
    local flow, ptc, fans = 0, false, 0
    for p = 1, 3 do
        flow = flow + pack.flow[p]
        if pack.operating[p] and pack.ptc[p] > 0 then ptc = true end
    end
    for f = 1, 4 do if pack.fan[f] then fans = fans + 1 end end
    inp.pack_kg_s = flow * B747_press_model.PACK_KG_S
    inp.packs_operating = pack.packs_operating
    inp.ptc = ptc
    inp.fans = fans
    inp.centre_psi = B747_duct_pressure_C
    inp.alt_ft = simDR_press_pressure_alt
    inp.agl_ft = simDR_press_agl * 3.28084
    inp.on_ground = B747DR_pack_pseu_pri_gnd == 1
    inp.cruise_clamp = B747_press_out.cruise_clamp
    inp.descent = B747_press_out.mode == B747_press_model.DESCENT
    inp.skin_c = simDR_temp_tat
    local engines, n2 = 0, 0
    for e = 0, 3 do
        if simDR_engine_running[e] == 1 then engines = engines + 1 end
        if B747DR_display_N2[e] > T.FWD_N2 then n2 = n2 + 1 end
    end
    inp.engines, inp.engines_n2 = engines, n2
    inp.ee_exhaust = B747_eqcool_out.cargo_warm
    inp.ac = B747DR_pack_elec_any_ac > 0.5
    inp.dc = B747DR_bleed_elec_dc[0] > 0.5 or B747DR_bleed_elec_dc[1] > 0.5
        or B747DR_bleed_elec_dc[2] > 0.5 or B747DR_bleed_elec_dc[3] > 0.5
    local out = T.update(temp_state, inp, SIM_PERIOD)
    B747_temp_settled = out.settled

    for z = 1, T.NZ do
        put(B747DR_temp_zone_actual, z - 1, out.zone_c[z])
        put(B747DR_temp_zone_target, z - 1, out.target_c[z])
    end
    put(B747DR_temp_cargo, 0, out.cargo_c[1])
    put(B747DR_temp_cargo, 1, out.cargo_c[2])
    local shown, valve = flag(out.target_shown), flag(out.trim_valve)
    if B747DR_temp_target_shown ~= shown then B747DR_temp_target_shown = shown end
    if B747DR_temp_master ~= out.master_c then B747DR_temp_master = out.master_c end
    if B747DR_temp_pack_outlet ~= out.pack_c then B747DR_temp_pack_outlet = out.pack_c end
    if B747DR_temp_trim_air_valve ~= valve then B747DR_temp_trim_air_valve = valve end
    local zone_fault, aft_light = flag(out.sys_fault), flag(out.aft_temp_light)
    if B747DR_temp_light_zone_fault ~= zone_fault then B747DR_temp_light_zone_fault = zone_fault end
    if B747DR_temp_light_aft_cargo ~= aft_light then B747DR_temp_light_aft_cargo = aft_light end
    put(B747DR_CAS_advisory_status, ADV_TEMP_CARGO_HEAT, flag(out.cargo_heat_alert))
    put(B747DR_CAS_advisory_status, ADV_TEMP_ZONE, flag(out.temp_zone))
    put(B747DR_CAS_advisory_status, ADV_TRIM_AIR_OFF, flag(out.trim_air_off))
    put(B747DR_press_status, STATUS_ZONE_TEMP, flag(out.zone_temp))
end
