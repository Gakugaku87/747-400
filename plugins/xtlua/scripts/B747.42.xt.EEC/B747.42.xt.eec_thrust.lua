-- The EEC model (B747.42.eec_model.lua) in the aircraft: reads the thrust
-- levers, the air data, the packs, the anti-ice valves, air/ground, the
-- flap lever, CON, the reversers and the rotor speeds every frame, and
-- gives each engine's command (laminar/B747/engines/TRA), the target of the
-- thrust control in ecc_spd (the command held back by the overspeed
-- protection), the max line of the upper EICAS (display_N1_max for GE,
-- display_EPR_max for P&W and RR), X-Plane's idle setting and the EEC
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
B747DR_eec_CAS_caution          = find_dataref("laminar/B747/CAS/caution_status")

-- the lever's idle end commands less than any idle, so that the thrust
-- control always comes back to X-Plane's idle there (the previous mapping's
-- values, estimate): N1 25 % (GE), EPR 0.95 (P&W, RR)
local IDLE_COMMAND = {GE = 25, PW = 0.95}
-- the flap lever's detents (0, 1, 5, 10, 20, 25, 30 at even steps of
-- sim/cockpit2/controls/flap_ratio) as trailing edge flap degrees
local FLAP_DETENTS = {0, 1, 5, 10, 20, 25, 30}
-- EICAS slots (laminar/B747/CAS/advisory_status, caution_status)
local ADV_IDLE_DISAGREE = 223
local ADV_LOW_IDLE = 309            -- ENG 1-4 LOW IDLE: 309-312
local ADV_EEC_MODE = 313            -- ENG 1-4 EEC MODE: 313-316
local ADV_RPM_LIM = 134             -- >ENG 1-4 RPM LIM: 134-137
local CAUTION_LIM_PROT = 75         -- >ENG 1-4 LIM PROT: 75-78

local eec_state = E.new()
local eec_inputs = E.inputs()
local eec_out = nil
local eec_last_time = nil
-- N2 for the overspeed protection, before the display rounds it (the P&W
-- display shows whole percent); B747_eec_set_n2 in the GE and P&W files
local rotor_n2 = {0, 0, 0, 0}

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
    inp.packs_on = B747DR_packs_operating     -- the packs with their valves open (the pack model)
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
        inp.altn[n] = B747DR_button_switch_position[6 + n] < 0.5    -- EEC MODE switches: [7]-[10]
        inp.n1[n] = B747DR_display_N1[n - 1]
        inp.n2[n] = rotor_n2[n]
        if inp.type == "GE" then inp.actual[n] = B747DR_display_N1[n - 1]
        else inp.actual[n] = B747DR_display_EPR[n - 1] end
    end
    eec_out = E.update(eec_state, inp, dt)

    local approach = false
    for n = 1, 4 do
        approach = approach or eec_out.approach[n]
        B747DR_eec_CAS_advisory[ADV_LOW_IDLE + n - 1] = flag(eec_out.low_idle[n])
        B747DR_eec_CAS_advisory[ADV_EEC_MODE + n - 1] = flag(eec_out.altn[n])
        B747DR_eec_CAS_caution[CAUTION_LIM_PROT + n - 1] = flag(eec_out.lim_prot[n])
        -- RR keeps its own (B747.40.xt.engines.lua)
        if B747DR_engineType ~= 2 then B747DR_eec_CAS_advisory[ADV_RPM_LIM + n - 1] = flag(eec_out.rpm_lim[n]) end
    end
    B747DR_eec_CAS_advisory[ADV_IDLE_DISAGREE] = flag(eec_out.idle_disagree)
    -- the A/T: off when an EEC goes to the alternate mode and while it may
    -- not be used; EEC_status gates the A/T modes in throttle_management
    if eec_out.at_disconnect or eec_out.at_inhibit then
        if B747DR_autothrottle_fail == 0 then B747DR_autothrottle_fail = 1 end
        if B747DR_autothrottle_active == 1 then B747DR_autothrottle_active = 0 end
    end
    if eec_out.at_inhibit then EEC_status = 1 else EEC_status = 0 end
    -- X-Plane's one idle setting: approach idle when any engine selects it
    local ratio = E.idle_ratio(inp.air, inp.alt, approach)
    if math.abs(simDR_engine_high_idle_ratio - ratio) > 0.0001 then simDR_engine_high_idle_ratio = ratio end
end

-- engine 0-3: the N1 (GE) or EPR (P&W, RR) the lever commands, the one the
-- thrust control aims at, and the maximum rated one
function B747_eec_command(engine)
    if eec_out == nil then return 0 end
    return eec_out.command[engine + 1]
end

function B747_eec_target(engine)
    if eec_out == nil then return 0 end
    return eec_out.target[engine + 1]
end

function B747_eec_set_n2(engine, n2)
    rotor_n2[engine + 1] = n2
end

function B747_eec_max(engine)
    if eec_out == nil then return 0 end
    return eec_out.max[engine + 1]
end

-- engine 0-3: X-Plane's throttle from the EEC's thrust control (GE and P&W,
-- forward thrust, engine running); ecc_spd in B747.42.xt.EEC.lua sets it
-- after the displays are worked out, and resets it otherwise
function B747_eec_throttle(engine)
    if eec_out == nil then return 0 end
    local key = eec_inputs.type
    local actual = B747DR_display_EPR[engine]
    if key == "GE" then actual = B747DR_display_N1[engine] end
    local n = engine + 1
    return E.thrust_control(eec_state, key, n, eec_out.target[n], actual, simDR_engn_thro_use[engine], IDLE_COMMAND[key], SIM_PERIOD)
end

function B747_eec_reset_throttle(engine)
    E.reset_thrust_control(eec_state, engine + 1)
end

-- an engine at full throttle still short of its target by more than this
-- (N1 % or EPR): X-Plane's engine cannot give the thrust, and the GE and P&W
-- files raise X-Plane's maximum thrust a little each frame (the previous
-- code's remedy, estimate)
local THRUST_SHORT = {GE = 0.2, PW = 0.005}
function B747_eec_thrust_short()
    if eec_out == nil then return false end
    local key = eec_inputs.type
    for engine = 0, 3 do
        local actual = B747DR_display_EPR[engine]
        if key == "GE" then actual = B747DR_display_N1[engine] end
        if simDR_engn_thro_use[engine] >= 0.999 and actual < eec_out.target[engine + 1] - THRUST_SHORT[key] then
            return true
        end
    end
    return false
end
