-- The engine indication model (B747.40.engine_display_model.lua) in the
-- aircraft: reads the displayed EGT, N1 and N2, X-Plane's oil pressure,
-- temperature and quantity, FUEL CONTROL, the start phases and the TO/GA
-- switch, and writes the flags the upper EICAS draws the EGT with
-- (laminar/B747/engines/EGT/white_on, amber_on, red_on, start_limit_on),
-- the red readouts, tapes and boxes of N1, EGT, N2, N3 and the P&W EPR tape
-- (N1/red_on, N1/box_red, EGT/box_red, N2/..., N3/..., EPR/red_on; the boxes
-- from the exceedance model, B747.40.exceedance_model.lua, with the EICAS
-- CANC and RCL switches), the secondary EICAS's oil and vibration
-- (oil_press_psi and EICAS2_oil_press_status, oil_temp_degC, oil_qty_liters
-- (US quarts for the CF6), vibration; the GE oil pressure amber band, the
-- oil quantity magenta and the vibration source label for the panel:
-- oil_press_amber, oil_qty_magenta, vib_source) and ENG n OIL PRESS, ENG n
-- OIL TEMP. 5-2 step 6b: the secondary engine exceedances (new
-- engines/sec_exceed[3]: N2, oil, vibration) for the EICAS formats (the
-- display glue, B747.60.xt.displays.lua).
-- B747.40.xt.engines.lua loads it after the start glue and calls
-- B747_engine_display() every frame (after_physics) and
-- B747_engine_display_toga() from its TO/GA command.
dofile("B747.40.engine_display_model.lua")
dofile("B747.40.exceedance_model.lua")
local D = B747_engine_display_model
local X = B747_exceedance_model

B747DR_engines_display_GE_EGT   = find_dataref("laminar/B747/engines/display_GE_EGT")
B747DR_engines_display_N3       = find_dataref("laminar/B747/engines/display_N3")
B747DR_engines_display_EPR      = find_dataref("laminar/B747/engines/display_EPR")
B747DR_engines_display_EPR_max  = find_dataref("laminar/B747/engines/display_EPR_max")
B747DR_engines_canc_count       = find_dataref("laminar/B747/CAS/canc_count")
B747DR_engines_rcl_count        = find_dataref("laminar/B747/CAS/rcl_count")
B747DR_EGT_red_on               = find_dataref("laminar/B747/engines/EGT/red_on")
B747DR_EGT_start_limit_on       = find_dataref("laminar/B747/engines/EGT/start_limit_on")
B747DR_EGT_box_red              = find_dataref("laminar/B747/engines/EGT/box_red")
B747DR_N1_red_on                = find_dataref("laminar/B747/engines/N1/red_on")
B747DR_N1_box_red               = find_dataref("laminar/B747/engines/N1/box_red")
B747DR_N2_red_on                = find_dataref("laminar/B747/engines/N2/red_on")
B747DR_N2_box_red               = find_dataref("laminar/B747/engines/N2/box_red")
B747DR_N3_red_on                = find_dataref("laminar/B747/engines/N3/red_on")
B747DR_N3_box_red               = find_dataref("laminar/B747/engines/N3/box_red")
B747DR_EPR_red_on               = find_dataref("laminar/B747/engines/EPR/red_on")
B747DR_oil_press_amber          = find_dataref("laminar/B747/engines/oil_press_amber")
B747DR_oil_qty_magenta          = find_dataref("laminar/B747/engines/oil_qty_magenta")
B747DR_vib_source               = find_dataref("laminar/B747/engines/vib_source")
B747DR_sec_exceed               = find_dataref("laminar/B747/engines/sec_exceed")
-- the panel's vibration source labels: 0 BB, 1 N1, 2 N2, 3 FAN, 4 LPT
local VIB_LABEL = {N1 = 1, N2 = 2, FAN = 3, LPT = 4}

local ADV_OIL_TEMP = 118            -- ENG 1-4 OIL TEMP: 118-121
local ADV_OIL_PRESS = 317           -- ENG 1-4 OIL PRESS: 317-320

local display_state = D.new()
local display_inputs = D.inputs()
local exceed_state = X.new()
local exceed_inputs = X.inputs()
local toga_pushed = false
local counts = {}                   -- the CANC and RCL push counters as last seen
local TYPES = {[0] = "PW", [1] = "GE", [2] = "RR"}

-- pushes of a counter since the last frame (none at the first look)
local function pushes(key, value)
    local last = counts[key]
    counts[key] = value
    if last == nil or value <= last then return 0 end
    return value - last
end

local function flag(v)
    if v then return 1 end
    return 0
end

-- write a flag only when it changes
local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_engine_display_flight_start()
    display_state = D.new()
    exceed_state = X.new()          -- a new flight: no stored exceedances
    toga_pushed = false
end

-- the TO/GA switch was pushed (FCOM p.872: the EGT amber inhibit starts)
function B747_engine_display_toga()
    toga_pushed = true
end

function B747_engine_display()
    local inp = display_inputs
    inp.type = TYPES[B747DR_engineType] or "PW"
    for n = 1, 4 do
        local i = n - 1
        if inp.type == "GE" then inp.egt[n] = B747DR_engines_display_GE_EGT[i]
        else inp.egt[n] = B747DR_display_EGT[i] end
        inp.cutoff[n] = B747DR_fuel_control_toggle_switch_pos[i] <= 0.95
        inp.starting[n] = B747_engine_start_phase(i) ~= "off"
        inp.running[n] = simDR_engine_running[i] == 1
        inp.n1[n] = B747DR_display_N1[i]
        inp.n2[n] = B747DR_display_N2[i]
        inp.n3[n] = B747DR_engines_display_N3[i]
        inp.epr[n] = B747DR_engines_display_EPR[i]
        inp.epr_max[n] = B747DR_engines_display_EPR_max[i]
        inp.oil_psi[n] = simDR_engine_oil_pressure[i]
        inp.oil_degc[n] = simDR_engine_oil_temp[i]
        inp.oil_ratio[n] = simDR_engine_oil_qty_ratio[i]
    end
    inp.cruise = B747DR_engines_pseu_pri_gnd == 0 and simDR_flap_deploy_ratio < 0.01
    inp.toga = toga_pushed
    toga_pushed = false
    local out = D.update(display_state, inp, SIM_PERIOD)
    local x = exceed_inputs
    x.type = inp.type
    x.cancel = pushes("cancel", B747DR_engines_canc_count)
    x.recall = pushes("recall", B747DR_engines_rcl_count)
    for n = 1, 4 do
        x.red.n1[n], x.red.egt[n], x.red.n2[n], x.red.n3[n] = out.n1_red[n], out.red[n], out.n2_red[n], out.n3_red[n]
    end
    local xo = X.update(exceed_state, x, SIM_PERIOD)
    for n = 1, 4 do
        local i = n - 1
        put(B747DR_EGT_white_on, i, flag(out.white[n]))
        put(B747DR_EGT_amber_on, i, flag(out.amber[n]))
        put(B747DR_EGT_red_on, i, flag(out.red[n]))
        put(B747DR_EGT_start_limit_on, i, flag(out.start_limit[n]))
        put(B747DR_EGT_box_red, i, flag(xo.box_red.egt[n]))
        put(B747DR_N1_red_on, i, flag(xo.red.n1[n]))
        put(B747DR_N1_box_red, i, flag(xo.box_red.n1[n]))
        put(B747DR_N2_red_on, i, flag(xo.red.n2[n]))       -- with the CF6's 20 s hold
        put(B747DR_N2_box_red, i, flag(xo.box_red.n2[n]))
        put(B747DR_N3_red_on, i, flag(xo.red.n3[n]))
        put(B747DR_N3_box_red, i, flag(xo.box_red.n3[n]))
        put(B747DR_EPR_red_on, i, flag(out.epr_red[n]))
        -- the amber band (the continuous limit) is always shown (FCOM p.838)
        put(B747DR_EGT_amber_inhibit, i, 0)
        B747DR_engine_oil_press_psi[i] = out.oil_psi[n]
        put(B747DR_EICAS2_oil_press_status, i, flag(out.oil_red[n]))
        B747DR_engine_oil_temp_degC[i] = out.oil_degc[n]
        B747DR_engine_oil_qty_liters[i] = out.oil_qty[n]
        put(B747DR_oil_press_amber, i, flag(out.oil_amber[n]))
        put(B747DR_oil_qty_magenta, i, flag(out.oil_qty_magenta[n]))
        B747DR_EICAS2_engine_vibration[i] = out.vib[n]
        local sources = D.VIB_SOURCES[inp.type] or D.VIB_SOURCES.PW
        local label = 0
        if out.vib_source[n] > 0 then label = VIB_LABEL[sources[out.vib_source[n]]] end
        put(B747DR_vib_source, i, label)
        put(B747DR_CAS_advisory_status, ADV_OIL_TEMP + i, flag(out.oil_temp_msg[n]))
        put(B747DR_CAS_advisory_status, ADV_OIL_PRESS + i, flag(out.oil_press_msg[n]))
    end
    put(B747DR_sec_exceed, 0, flag(out.exceed_n2))
    put(B747DR_sec_exceed, 1, flag(out.exceed_oil))
    put(B747DR_sec_exceed, 2, flag(out.exceed_vib))
end
