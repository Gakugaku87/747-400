-- The engines' fuel per thrust above FL370 (B747.42.sfc_corr_model.lua,
-- 補正) in the aircraft: X-Plane's four jet SFC figures, the acf's own (read
-- on the first frame they are there, before anything is written) times the
-- altitude's factor, every frame. The P&W only: the factor is the PW4056's
-- FCOM tables' (GE and RR: none yet, the acf's own). laminar/B747/debug/
-- sfc_corr_off 1 puts the acf's own back once and then leaves them alone (for
-- comparing in X-Plane, or tests/flight/measure/aero_sfc_sweep.json's
-- writes). B747.42.xt.EEC.lua loads it and calls B747_sfc_corr every frame.
dofile("B747.42.sfc_corr_model.lua")
local SC = B747_sfc_corr_model

simDR_sc_sfc_to                 = find_dataref("sim/aircraft/overflow/jet_SFC_takeoff")
simDR_sc_sfc_clb                = find_dataref("sim/aircraft/overflow/jet_SFC_climb")
simDR_sc_sfc_lo                 = find_dataref("sim/aircraft/overflow/jet_SFC_locrz")
simDR_sc_sfc_hi                 = find_dataref("sim/aircraft/overflow/jet_SFC_hicrz")
simDR_sc_press_alt              = find_dataref("sim/flightmodel2/position/pressure_altitude")
B747DR_sc_off                   = find_dataref("laminar/B747/debug/sfc_corr_off")

-- the acf's own figures (kg/(N s), as X-Plane holds them), and whether the
-- last frame wrote the corrected ones
local acf_to, acf_clb, acf_lo, acf_hi = nil, nil, nil, nil
local written = false

function B747_sfc_corr()
    if acf_hi == nil then
        if simDR_sc_sfc_hi <= 0 then return end     -- not read yet (or none)
        acf_to = simDR_sc_sfc_to
        acf_clb = simDR_sc_sfc_clb
        acf_lo = simDR_sc_sfc_lo
        acf_hi = simDR_sc_sfc_hi
    end
    if B747DR_sc_off ~= 0 then
        if written then
            simDR_sc_sfc_to = acf_to
            simDR_sc_sfc_clb = acf_clb
            simDR_sc_sfc_lo = acf_lo
            simDR_sc_sfc_hi = acf_hi
            written = false
        end
        return
    end
    local f = 1
    if B747DR_engineType == 0 then f = SC.factor(simDR_sc_press_alt) end
    simDR_sc_sfc_to = acf_to * f
    simDR_sc_sfc_clb = acf_clb * f
    simDR_sc_sfc_lo = acf_lo * f
    simDR_sc_sfc_hi = acf_hi * f
    written = true
end
