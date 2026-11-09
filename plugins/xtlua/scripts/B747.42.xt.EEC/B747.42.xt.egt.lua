-- The EGT model (B747.42.egt_model.lua, ENG-33) in the aircraft: for the
-- P&W (display_EGT) and the GE (display_GE_EGT), each engine's EGT from
-- X-Plane's burning flag and N2, the EPR (P&W) or N1 (GE) the display shows
-- this frame (and the N1 for the EGT OVERTEMP's share, both types), the TAT
-- and air/ground, every frame with the frame's time
-- (SIM_PERIOD). The RB211 keeps X-Plane's EGT scaled (egt_thermal_profile,
-- B747.42.xt.EEC.lua). B747.42.xt.EEC.lua loads it; the PW and GE files call
-- B747_egt for each engine after its EPR and N1, flight_start calls
-- B747_egt_flight_start.
-- The datarefs are bound in this module before this file loads and are read
-- here, not bound again (a global bound twice writes to the first):
-- simDR_heating, simDR_N2, simDR_TAT, simDR_temperature, simDR_onGround,
-- B747DR_display_EPR and B747DR_display_N1 (B747.42.xt.EEC.lua)
dofile("B747.42.egt_model.lua")
local G = B747_egt_model

-- (2026-11-10) the failure window's HOT START and EGT OVERTEMP (1 failed;
-- created in the EEC's init script, B747.42.EEC.lua): the model's inputs
-- (B747.42.egt_model.lua: HOT_START_C, EGT_HIGH_*). New names: the module
-- binds no others to them
B747DR_egt_fail_hot_start_in    = find_dataref("laminar/B747/engines/fail/hot_start")
B747DR_egt_fail_egt_high_in     = find_dataref("laminar/B747/engines/fail/egt_high")

-- a new flight: the EGT is its target at once for this long (the first
-- frames' reads may still be 0; no lag from the last flight's EGT)
local SETTLE_S = 2

local egt_state = {G.new(), G.new(), G.new(), G.new()}
local egt_inputs = G.inputs()

function B747_egt_flight_start()
    for n = 1, 4 do G.settle(egt_state[n], SETTLE_S) end
end

-- engine 0-3, kind "PW" or "GE": the EGT the EICAS shows this frame (°C);
-- the floor the outside air temperature, as the previous code's
function B747_egt(engine, kind)
    local inp = egt_inputs
    inp.kind = kind
    inp.burning = simDR_heating[engine] > 0.5
    inp.n2 = simDR_N2[engine]
    inp.n1 = B747DR_display_N1[engine]
    if kind == "GE" then inp.x = inp.n1
    else inp.x = B747DR_display_EPR[engine] end
    inp.tat = simDR_TAT
    inp.air = simDR_onGround == 0
    inp.floor = simDR_temperature
    inp.hot_start = B747DR_egt_fail_hot_start_in[engine] > 0.5
    inp.egt_high = B747DR_egt_fail_egt_high_in[engine] > 0.5
    return G.update(egt_state[engine + 1], inp, math.max(0, math.min(1, SIM_PERIOD)))
end
