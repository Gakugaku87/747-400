-- The engine start model (B747.40.engine_start_model.lua) in the aircraft
-- (2-3, step 1): reads the START, FUEL CONTROL, fire, AUTOSTART, CON and
-- ignition selector switches, the buses, air/ground, the flaps, the
-- nacelle anti-ice, X-Plane's N2, EGT and light-off, the start valves (bleed
-- model) and the spar valves (fuel model); runs the model every frame and
-- writes the start valve commands (read by the bleed glue), X-Plane's
-- starters, igniters, auto-ignite and mixture, the engine fuel valves (read
-- by the fuel glue), releases the START switches and sets the start EICAS
-- messages (docs/overhaul/notes/ATA-70-80.md §3-4). B747.40.xt.engines.lua
-- loads it; B747_engine_start() runs in before_physics.
dofile("B747.40.engine_start_model.lua")
local S = B747_engine_start_model

simDR_engine_N2_pct             = find_dataref("sim/flightmodel/engine/ENGN_N2_")
simDR_engine_burning            = find_dataref("sim/flightmodel2/engines/engine_is_burning_fuel")
B747DR_engines_elec_bus_ac      = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_engines_elec_stby_main   = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_engines_elec_bat_main    = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_engines_elec_bat_apu     = find_dataref("laminar/B747/electrical/bus/bat_apu")
B747DR_engines_stby_ignit_sel   = find_dataref("laminar/B747/electrical/stby_ignit/sel_dial_pos")
B747DR_engines_auto_ignit_sel   = find_dataref("laminar/B747/electrical/auto_ignit/sel_dial_pos")
B747DR_engines_is_freighter     = find_dataref("laminar/B747/freighter")
B747DR_engines_spar_valve1_pos  = find_dataref("laminar/B747/fuel/spar_vlv1_pos")
B747DR_engines_spar_valve2_pos  = find_dataref("laminar/B747/fuel/spar_vlv2_pos")
B747DR_engines_spar_valve3_pos  = find_dataref("laminar/B747/fuel/spar_vlv3_pos")
B747DR_engines_spar_valve4_pos  = find_dataref("laminar/B747/fuel/spar_vlv4_pos")
B747DR_engine_start_valve_cmd   = find_dataref("laminar/B747/engines/start_valve_cmd")

local START_SWITCH = 16                     -- toggle_switch/position[16-19]
local CON_SWITCH, AUTOSTART_SWITCH = 44, 45 -- button_switch/position
local NAI_SWITCH = 68                       -- button_switch/position[68-71]: NACELLE ANTI-ICE 1-4
-- EICAS slots (laminar/B747/CAS/*_status, B747.87.xt.warning.lua). ENG FAIL
-- is in the warning list with the caution level (FCOM p.899).
local WARN_ENG_FAIL = 28
local CAUT_AUTOSTART, CAUT_SHUTDOWN, CAUT_STARTER_CUTOUT = 19, 23, 61
local ADV_ENG_IGNITION, ADV_START_VLV, ADV_AUTOSTART_OFF, ADV_FUEL_VLV = 109, 138, 304, 305
local MEMO_CON_IGNITION = 8
local SETTLE_S = 2                          -- after a flight start (as the fuel glue)

local start_state = S.new()
local start_inputs = S.inputs()
local start_settle_left = SETTLE_S
local starter_held = {false, false, false, false}
local starter_cmd = {simCMD_starter_on_1, simCMD_starter_on_2, simCMD_starter_on_3, simCMD_starter_on_4}
local start_off_cmd = {B747CMD_engine_start_switch1_off, B747CMD_engine_start_switch2_off,
    B747CMD_engine_start_switch3_off, B747CMD_engine_start_switch4_off}
local fire_arm = {}

local function flag(v)
    if v then return 1 end
    return 0
end

-- a new flight: the model starts again; the engines running keep their fuel
function B747_engine_start_flight_start()
    start_state = S.new()
    start_settle_left = SETTLE_S
end

-- engine 0-3: the start phase (the model's: off, motor, light, accel, dry,
-- aborted), for the EGT start limit line (B747.40.xt.engine_display.lua)
function B747_engine_start_phase(engine)
    return start_state.eng[engine + 1].phase
end

local function read_inputs(inp)
    local t = B747DR_engineType
    inp.type = (t == 1) and "GE" or "PW"            -- RR as PW (PLAN.md §5)
    inp.autostart_installed = not (inp.type == "PW" and B747DR_engines_is_freighter == 1)   -- not 405 (FCOM p.861)
    inp.autostart = B747DR_button_switch_position[AUTOSTART_SWITCH] > 0.95
    inp.con = B747DR_button_switch_position[CON_SWITCH] > 0.95
    inp.auto_sel = B747DR_engines_auto_ignit_sel
    inp.stby_sel = B747DR_engines_stby_ignit_sel
    inp.flaps_out = simDR_flap_deploy_ratio > 0.0
    inp.on_ground = B747DR_engines_pseu_pri_gnd == 1
    inp.ac1 = B747DR_engines_elec_bus_ac[0] > 0.5
    inp.ac3 = B747DR_engines_elec_bus_ac[2] > 0.5
    inp.ac_stby = B747DR_engines_elec_stby_main > 0.5
    inp.main_bat = B747DR_engines_elec_bat_main > 0.5
    inp.apu_bat = B747DR_engines_elec_bat_apu > 0.5
    fire_arm[1], fire_arm[2] = B747DR_engine01_fire_ext_switch_pos_arm, B747DR_engine02_fire_ext_switch_pos_arm
    fire_arm[3], fire_arm[4] = B747DR_engine03_fire_ext_switch_pos_arm, B747DR_engine04_fire_ext_switch_pos_arm
    local start_valve = {B747DR_bleedAir_engine1_start_valve_pos, B747DR_bleedAir_engine2_start_valve_pos,
        B747DR_bleedAir_engine3_start_valve_pos, B747DR_bleedAir_engine4_start_valve_pos}
    local spar = {B747DR_engines_spar_valve1_pos, B747DR_engines_spar_valve2_pos,
        B747DR_engines_spar_valve3_pos, B747DR_engines_spar_valve4_pos}
    for n = 1, 4 do
        inp.start_sw[n] = B747DR_toggle_switch_position[START_SWITCH + n - 1] > 0.95
        inp.fuel_control[n] = B747DR_fuel_control_toggle_switch_pos[n - 1] > 0.95
        inp.fire_out[n] = fire_arm[n] > 0.5
        inp.n2[n] = simDR_engine_N2_pct[n - 1]
        inp.egt[n] = B747DR_display_EGT[n - 1]
        inp.burning[n] = simDR_engine_burning[n - 1] == 1
        inp.start_valve[n] = start_valve[n] > 0.5
        inp.spar_valve[n] = spar[n]
        -- the NACELLE ANTI-ICE switch selects the igniters (FCOM p.625, p.631)
        inp.nai[n] = B747DR_button_switch_position[NAI_SWITCH + n - 1] > 0.95
    end
end

-- every frame (before_physics)
function B747_engine_start()
    local inp = start_inputs
    local dt = math.max(0, math.min(1, SIM_PERIOD))
    read_inputs(inp)
    local settling = start_settle_left > 0
    if settling then
        start_settle_left = start_settle_left - dt
        S.settle(start_state, inp)
    end
    local out = S.update(start_state, inp, dt)
    for n = 1, 4 do
        local o, i = out.eng[n], n - 1
        B747DR_engine_start_valve_cmd[i] = flag(o.start_cmd)
        -- X-Plane's starter: held while the start valve gives air (a command
        -- held, not shut_down_n, which also cuts the fuel: ENG-11)
        if o.starter and not starter_held[n] then starter_cmd[n]:start() starter_held[n] = true
        elseif not o.starter and starter_held[n] then starter_cmd[n]:stop() starter_held[n] = false end
        if o.release_start_sw and B747DR_toggle_switch_position[START_SWITCH + i] > 0 then start_off_cmd[n]:once() end
        -- X-Plane's igniters and fuel (read every frame, written only when
        -- different: ARCHITECTURE.md §9a). X-Plane's auto-ignite stays off:
        -- the model decides the ignition. While settling, a running engine
        -- keeps its fuel.
        local ign, fuel = flag(o.ignition), flag(o.fuel)
        if settling and inp.burning[n] then fuel = 1 end
        if simDR_engine_igniter_on[i] ~= ign then simDR_engine_igniter_on[i] = ign end
        if simDR_engine_auto_ignite_on[i] ~= 0 then simDR_engine_auto_ignite_on[i] = 0 end
        if simDR_engine_fuel_mix_ratio[i] ~= fuel then simDR_engine_fuel_mix_ratio[i] = fuel end
        B747DR_engine_fuel_valve_pos[i] = fuel
        local m = out.msg
        local quiet = settling
        B747DR_CAS_warning_status[WARN_ENG_FAIL + i] = flag(m.fail[n] and not quiet)
        B747DR_CAS_caution_status[CAUT_AUTOSTART + i] = flag(m.autostart[n] and not quiet)
        B747DR_CAS_caution_status[CAUT_SHUTDOWN + i] = flag(m.shutdown[n] and not quiet)
        B747DR_CAS_caution_status[CAUT_STARTER_CUTOUT + i] = flag(m.starter_cutout[n] and not quiet)
        B747DR_CAS_advisory_status[ADV_START_VLV + i] = flag(m.start_vlv[n] and not quiet)
        B747DR_CAS_advisory_status[ADV_FUEL_VLV + i] = flag(m.fuel_vlv[n] and not quiet)
    end
    B747DR_CAS_advisory_status[ADV_ENG_IGNITION] = flag(out.msg.eng_ignition and not settling)
    B747DR_CAS_advisory_status[ADV_AUTOSTART_OFF] = flag(out.msg.autostart_off)
    B747DR_CAS_memo_status[MEMO_CON_IGNITION] = flag(out.msg.con_memo)
end
