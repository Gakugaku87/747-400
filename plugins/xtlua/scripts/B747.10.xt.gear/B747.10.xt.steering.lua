-- The steering model (B747.10.steering_model.lua) in the aircraft (4-2 step
-- 4): reads the tillers (X-Plane's nosewheel tiller axis, or
-- laminar/B747/gear/steering/tiller with no such axis), the rudder pedals
-- with the rudder trim (laminar/B747/flt_ctrls/rudder_input), hydraulic
-- system 1 with the gear lever DN (the gear down pressure), the PSEU (nose
-- gear compressed, air/ground), the groundspeed, the option of the pedals as
-- the tiller (laminar/B747/gear/steering/pedal_tiller: not the aircraft) and
-- the failures; steers X-Plane's nose wheels and body gear
-- (override_wheel_steer always on, tire_steer_command_deg), writes the
-- trucks' locks (laminar/B747/gear/steering/body_unlocked: CONFIG GEAR CTR,
-- the gear lever's lock), >BODY GEAR STRG, BODY GR STRG SYS and PEDAL
-- STEERING. B747.10.xt.gear.lua loads it after the brakes' glue and uses its
-- bindings (the PSEU, system 1's pressure, the gear lever).
dofile("B747.10.steering_model.lua")
local S = B747_steering_model

simDR_strg_override             = find_dataref("sim/operation/override/override_wheel_steer")
simDR_strg_command              = find_dataref("sim/flightmodel2/gear/tire_steer_command_deg")
simDR_strg_axis_avail           = find_dataref("sim/joystick/joy_mapped_axis_avail")
simDR_strg_axis_value           = find_dataref("sim/joystick/joy_mapped_axis_value")
simDR_strg_gs                   = find_dataref("sim/flightmodel/position/groundspeed")
B747DR_strg_rudder_input        = find_dataref("laminar/B747/flt_ctrls/rudder_input")
B747DR_strg_tiller              = find_dataref("laminar/B747/gear/steering/tiller")
B747DR_strg_pedal_tiller        = find_dataref("laminar/B747/gear/steering/pedal_tiller")
B747DR_strg_body_unlocked       = find_dataref("laminar/B747/gear/steering/body_unlocked")
B747DR_strg_fail_pedal          = find_dataref("laminar/B747/gear/fail/pedal_steering")
B747DR_strg_fail_body           = find_dataref("laminar/B747/gear/fail/body_steering")
B747DR_strg_status              = find_dataref("laminar/B747/CAS/status_status")

-- X-Plane's joystick axis assignment "Nosewheel tiller", which
-- joy_mapped_axis_avail/value are indexed by (developer.x-plane.com,
-- "joystick datarefs"; estimate: not tried, the user's joystick has none)
local AXIS_TILLER = 37
-- EICAS slots (B747.87.xt.warning.lua)
local ADV_BODY_GEAR_STRG = 43
local STATUS_BODY_GR_STRG_SYS, STATUS_PEDAL_STEERING = 95, 96
-- X-Plane's gear: 0 nose, 1 right body, 2 left body, 3 right wing, 4 left wing
local XP_NOSE, XP_RB, XP_LB, XP_RW, XP_LW = 0, 1, 2, 3, 4

local strg_state = S.new()
local strg_inputs = S.inputs()

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_steering_aircraft_load()
    -- the pedals as the tiller for users without a tiller axis, on unless set
    -- off (not the aircraft: docs/overhaul/notes/ATA-32.md §13)
    B747DR_strg_pedal_tiller = 1
end

function B747_steering_flight_start()
    strg_state = S.new()
end

function B747_steering()
    local inp = strg_inputs
    inp.tiller_avail = simDR_strg_axis_avail[AXIS_TILLER] == 1
    if inp.tiller_avail then inp.tiller = simDR_strg_axis_value[AXIS_TILLER] else inp.tiller = B747DR_strg_tiller end
    inp.pedal = B747DR_strg_rudder_input
    inp.pedal_tiller = B747DR_strg_pedal_tiller > 0.5
    inp.down_psi = B747DR_gear_handle < 0.5 and B747DR_pseu_hyd_pressure_1 or 0
    inp.ng_compressed = B747DR_pseu_ng_compressed == 1
    inp.gnd_both = B747DR_pseu_pri_gnd == 1 and B747DR_pseu_alt_gnd == 1
    inp.air = B747DR_pseu_pri_air == 1 or B747DR_pseu_alt_air == 1
    -- the wing gear wheels' speed taken as the groundspeed (estimate)
    inp.iru_kt = simDR_strg_gs * 1.94384
    inp.wheel_kt = inp.iru_kt
    inp.fail_pedal = B747DR_strg_fail_pedal > 0.5
    inp.fail_body = B747DR_strg_fail_body > 0.5
    local out = S.update(strg_state, inp, SIM_PERIOD)

    if simDR_strg_override ~= 1 then simDR_strg_override = 1 end
    put(simDR_strg_command, XP_NOSE, out.nose)
    put(simDR_strg_command, XP_LB, out.body[1])
    put(simDR_strg_command, XP_RB, out.body[2])
    put(simDR_strg_command, XP_RW, 0)
    put(simDR_strg_command, XP_LW, 0)
    local unlocked = flag(out.unlocked)
    if B747DR_strg_body_unlocked ~= unlocked then B747DR_strg_body_unlocked = unlocked end
    put(B747DR_gact_advisory, ADV_BODY_GEAR_STRG, flag(out.body_gear_strg))
    put(B747DR_strg_status, STATUS_BODY_GR_STRG_SYS, flag(out.body_gear_strg))
    put(B747DR_strg_status, STATUS_PEDAL_STEERING, flag(out.pedal_steering))
end
