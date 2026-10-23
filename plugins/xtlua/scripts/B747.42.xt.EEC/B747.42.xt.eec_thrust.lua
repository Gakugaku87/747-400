-- The EEC model (B747.42.eec_model.lua) in the aircraft: reads the thrust
-- levers, the air data, the packs and the anti-ice valves every frame, and
-- gives each engine's command (laminar/B747/engines/TRA, the target of the
-- thrust control in ecc_spd) and the max line of the upper EICAS
-- (display_N1_max for GE, display_EPR_max for P&W and RR). The FMC's thrust
-- reference and the A/T stay in B747.42.xt.EEC.lua (PLAN.md 6-4).
-- B747.42.xt.EEC.lua loads it after its bindings.
dofile("B747.42.eec_model.lua")
local E = B747_eec_model

simDR_eec_pressure_alt          = find_dataref("sim/flightmodel2/position/pressure_altitude")
B747DR_eec_wing_ai_valve        = find_dataref("laminar/B747/antiice/wing/valve_pos")

-- the lever's idle end commands less than any idle, so that the thrust
-- control always comes back to X-Plane's idle there (the previous mapping's
-- values, estimate): N1 25 % (GE), EPR 0.95 (P&W, RR)
local IDLE_COMMAND = {GE = 25, PW = 0.95}

local eec_inputs = E.inputs()
local eec_out = nil

function B747_eec_update()
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
    for n = 1, 4 do
        inp.nai[n] = B747DR_nacelle_ai_valve_pos[n - 1] > 0.5
        inp.lever[n] = B747DR_throttle[n - 1]
        inp.idle[n] = IDLE_COMMAND[inp.type]
    end
    eec_out = E.update(inp)
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
