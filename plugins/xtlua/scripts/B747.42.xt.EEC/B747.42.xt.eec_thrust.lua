-- The EEC model (B747.42.eec_model.lua) in the aircraft: reads the thrust
-- levers, the air data, the packs, the anti-ice valves, air/ground, the
-- flap lever, CON and the reversers every frame, and gives each engine's
-- command (laminar/B747/engines/TRA, the target of the thrust control in
-- ecc_spd), the max line of the upper EICAS (display_N1_max for GE,
-- display_EPR_max for P&W and RR), X-Plane's idle setting and the idle
-- messages. The FMC's thrust reference and the A/T stay in
-- B747.42.xt.EEC.lua (PLAN.md 6-4). B747.42.xt.EEC.lua loads it after its
-- bindings.
dofile("B747.42.eec_model.lua")
local E = B747_eec_model

simDR_eec_pressure_alt          = find_dataref("sim/flightmodel2/position/pressure_altitude")
B747DR_eec_wing_ai_valve        = find_dataref("laminar/B747/antiice/wing/valve_pos")
B747DR_eec_pseu_pri_gnd         = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
simDR_eec_flap_handle           = find_dataref("sim/cockpit2/controls/flap_ratio")
B747DR_eec_freighter            = find_dataref("laminar/B747/freighter")
B747DR_eec_CAS_advisory         = find_dataref("laminar/B747/CAS/advisory_status")

-- the lever's idle end commands less than any idle, so that the thrust
-- control always comes back to X-Plane's idle there (the previous mapping's
-- values, estimate): N1 25 % (GE), EPR 0.95 (P&W, RR)
local IDLE_COMMAND = {GE = 25, PW = 0.95}
-- the flap lever's detents (0, 1, 5, 10, 20, 25, 30 at even steps of
-- sim/cockpit2/controls/flap_ratio) as trailing edge flap degrees
local FLAP_DETENTS = {0, 1, 5, 10, 20, 25, 30}
-- X-Plane has one idle setting for all engines (high_idle_ratio): approach
-- idle when any engine selects it, else minimum idle by the outside air
-- temperature (the previous code's values, estimate)
local APPROACH_IDLE_RATIO = 2.625
local function minimum_idle_ratio(t)
    if B747DR_engineType == 1 then
        if t < 15 then return B747_rescale(-75.0, 1.04, 14.99, 1.249, t) end
        return B747_rescale(15.0, 1.25, 75.0, 1.49, t)
    end
    if t < 15 then return B747_rescale(-75.0, 1.00, 14.99, 1.07, t) end
    return B747_rescale(15.0, 1.071, 75.0, 1.14, t)
end
-- EICAS advisory slots (laminar/B747/CAS/advisory_status)
local ADV_IDLE_DISAGREE = 223
local ADV_LOW_IDLE = 309            -- ENG 1-4 LOW IDLE: 309-312

local eec_state = E.new()
local eec_inputs = E.inputs()
local eec_out = nil
local eec_last_time = nil

local function flap_degrees(ratio)
    local x = ratio * (#FLAP_DETENTS - 1)
    local i = math.floor(x)
    if i >= #FLAP_DETENTS - 1 then return FLAP_DETENTS[#FLAP_DETENTS] end
    if i < 0 then return 0 end
    return FLAP_DETENTS[i + 1] + (FLAP_DETENTS[i + 2] - FLAP_DETENTS[i + 1]) * (x - i)
end

local function flag(v) if v then return 1 else return 0 end end

function B747_eec_flight_start()
    eec_state = E.new()
    eec_last_time = nil
end

function B747_eec_update()
    local dt = 0
    if eec_last_time ~= nil then dt = math.max(0, math.min(simDRTime - eec_last_time, 1)) end
    eec_last_time = simDRTime
    local inp = eec_inputs
    if B747DR_engineType == 1 then inp.type = "GE" else inp.type = "PW" end
    inp.alt = simDR_eec_pressure_alt
    inp.tat = simDR_TAT
    inp.kias = simDR_ias_pilot
    local packs = 0
    for i = 0, 2 do
        if B747DR_pack_ctrl_sel_pos[i] > 0 then packs = packs + 1 end
    end
    inp.packs_on = packs
    inp.wai = B747DR_eec_wing_ai_valve[0] > 0.5 or B747DR_eec_wing_ai_valve[1] > 0.5
    inp.air = B747DR_eec_pseu_pri_gnd == 0
    inp.flaps_deg = flap_degrees(simDR_eec_flap_handle)
    inp.con = B747DR_button_switch_position[44] > 0.5
    inp.freighter = B747DR_eec_freighter == 1
    for n = 1, 4 do
        inp.nai[n] = B747DR_nacelle_ai_valve_pos[n - 1] > 0.5
        inp.lever[n] = B747DR_throttle[n - 1]
        inp.idle[n] = IDLE_COMMAND[inp.type]
        inp.reverser[n] = simDR_reverser_deploy_ratio[n - 1] > 0.01
    end
    eec_out = E.update(eec_state, inp, dt)

    local approach = false
    for n = 1, 4 do
        approach = approach or eec_out.approach[n]
        B747DR_eec_CAS_advisory[ADV_LOW_IDLE + n - 1] = flag(eec_out.low_idle[n])
    end
    B747DR_eec_CAS_advisory[ADV_IDLE_DISAGREE] = flag(eec_out.idle_disagree)
    local ratio = APPROACH_IDLE_RATIO
    if not approach then ratio = minimum_idle_ratio(simDR_temperature) end
    if math.abs(simDR_engine_high_idle_ratio - ratio) > 0.0001 then simDR_engine_high_idle_ratio = ratio end
end

-- engine 0-3: the N1 (GE) or EPR (P&W, RR) the lever commands, and the
-- maximum rated one
function B747_eec_command(engine)
    if eec_out == nil then return 0 end
    return eec_out.command[engine + 1]
end

function B747_eec_max(engine)
    if eec_out == nil then return 0 end
    return eec_out.max[engine + 1]
end
