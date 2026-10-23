-- The engine indication model (B747.40.engine_display_model.lua) in the
-- aircraft: reads the displayed EGT, FUEL CONTROL, the start phases and the
-- TO/GA switch, and writes the flags the upper EICAS draws the EGT with
-- (laminar/B747/engines/EGT/white_on, amber_on, red_on, start_limit_on).
-- B747.40.xt.engines.lua loads it after the start glue and calls
-- B747_engine_display() every frame (after_physics) and
-- B747_engine_display_toga() from its TO/GA command.
dofile("B747.40.engine_display_model.lua")
local D = B747_engine_display_model

B747DR_engines_display_GE_EGT   = find_dataref("laminar/B747/engines/display_GE_EGT")
B747DR_EGT_red_on               = find_dataref("laminar/B747/engines/EGT/red_on")
B747DR_EGT_start_limit_on       = find_dataref("laminar/B747/engines/EGT/start_limit_on")

local display_state = D.new()
local display_inputs = D.inputs()
local toga_pushed = false
local TYPES = {[0] = "PW", [1] = "GE", [2] = "RR"}

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
    end
    inp.toga = toga_pushed
    toga_pushed = false
    local out = D.update(display_state, inp, SIM_PERIOD)
    for n = 1, 4 do
        local i = n - 1
        put(B747DR_EGT_white_on, i, flag(out.white[n]))
        put(B747DR_EGT_amber_on, i, flag(out.amber[n]))
        put(B747DR_EGT_red_on, i, flag(out.red[n]))
        put(B747DR_EGT_start_limit_on, i, flag(out.start_limit[n]))
        -- the amber band (the continuous limit) is always shown (FCOM p.838)
        put(B747DR_EGT_amber_inhibit, i, 0)
    end
end
