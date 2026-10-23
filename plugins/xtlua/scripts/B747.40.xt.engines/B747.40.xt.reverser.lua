-- The thrust reverser model (B747.40.reverser_model.lua) in the aircraft:
-- after the reverse lever logic (B747_prop_mode) has set X-Plane's prop
-- mode from the levers and commands, it keeps a reverser stowed, or
-- deployed, while it has no power or no ground, and writes ENG n REVERSER
-- (advisories 126-129). B747.40.xt.engines.lua loads it and calls
-- B747_reverser() every frame after B747_prop_mode().
dofile("B747.40.reverser_model.lua")
local R = B747_reverser_model

-- scalar datarefs read through their globals
B747DR_reverser_hyd_psi_1       = find_dataref("laminar/B747/hydraulics/pressure_1")
B747DR_reverser_hyd_psi_2       = find_dataref("laminar/B747/hydraulics/pressure_2")
B747DR_reverser_hyd_psi_3       = find_dataref("laminar/B747/hydraulics/pressure_3")
B747DR_reverser_hyd_psi_4       = find_dataref("laminar/B747/hydraulics/pressure_4")
local ADV_REVERSER = 126            -- ENG 1-4 REVERSER: 126-129
local TYPES = {[0] = "PW", [1] = "GE", [2] = "RR"}

local reverser_state = R.new()
local reverser_inputs = R.inputs()

function B747_reverser_flight_start()
    reverser_state = R.new()
end

-- engine 0-3: the reverser may deploy (power and ground, as of the last
-- frame); the reverse commands ask X-Plane for reverse only then, so that
-- X-Plane does not start an unpowered reverser between frames
function B747_reverser_can_deploy(engine)
    return reverser_state.out.can_deploy[engine + 1]
end

function B747_reverser()
    local inp = reverser_inputs
    inp.type = TYPES[B747DR_engineType] or "PW"
    inp.pri_gnd = B747DR_engines_pseu_pri_gnd == 1
    inp.alt_gnd = B747DR_engines_pseu_alt_gnd == 1
    inp.hyd_psi[1], inp.hyd_psi[2] = B747DR_reverser_hyd_psi_1, B747DR_reverser_hyd_psi_2
    inp.hyd_psi[3], inp.hyd_psi[4] = B747DR_reverser_hyd_psi_3, B747DR_reverser_hyd_psi_4
    inp.xp_fail[1], inp.xp_fail[2] = simDR_thrust_rev_fail_01 == 6, simDR_thrust_rev_fail_02 == 6
    inp.xp_fail[3], inp.xp_fail[4] = simDR_thrust_rev_fail_03 == 6, simDR_thrust_rev_fail_04 == 6
    for n = 1, 4 do
        local i = n - 1
        inp.want[n] = simDR_prop_mode[i] == 3
        inp.asked[n] = B747_reverse_asked(i)
        inp.position[n] = simDR_thrust_rev_deploy_ratio[i]
        inp.running[n] = simDR_engine_running[i] == 1
    end
    local out = R.update(reverser_state, inp, SIM_PERIOD)
    for n = 1, 4 do
        local i = n - 1
        local mode = 1
        if out.reverse[n] then mode = 3 end
        if simDR_prop_mode[i] ~= mode then simDR_prop_mode[i] = mode end
        -- no reverse throttle for a reverser kept in: X-Plane would start moving it
        if mode == 1 and simDR_engine_throttle_jet[i] < 0 then simDR_engine_throttle_jet[i] = 0 end
        local msg = 0
        if out.message[n] then msg = 1 end
        if B747DR_CAS_advisory_status[ADV_REVERSER + i] ~= msg then B747DR_CAS_advisory_status[ADV_REVERSER + i] = msg end
    end
end
