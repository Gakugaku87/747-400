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
-- (2026-11-04) the failures and the ALTN lights (notes/ATA-70-80.md §10)
B747DR_eec_fail_altn_in         = find_dataref("laminar/B747/engines/fail/eec_altn")
B747DR_eec_fail_fault_in        = find_dataref("laminar/B747/engines/fail/eec_fault")
B747DR_eec_fail_idle_min_in     = find_dataref("laminar/B747/engines/fail/idle_min")
B747DR_eec_fail_idle_app_in     = find_dataref("laminar/B747/engines/fail/idle_approach")
B747DR_eec_altn_light_out       = find_dataref("laminar/B747/engines/eec/altn_light")

-- the lever's idle end commands less than any idle, so that the thrust
-- control always comes back to X-Plane's idle there (the previous mapping's
-- values, estimate): N1 25 % (GE), EPR 0.95 (RR). P&W: the EPR model's idle
-- command (B747_epr_model.idle_command: under X-Plane's idle at every Mach,
-- the lever's travel spanning the EPRs from X-Plane's idle up; FCOM p.876:
-- the EEC calculates an EPR between idle and the maximum). Before
-- (2026-10-31), 0.95 at any Mach with the shown EPR held at 0.97: at FL300,
-- M.78 no thrust between X-Plane's idle (2 kN an engine) and 34 kN. Then
-- (to 2026-11-05) the EPR of no net thrust: over X-Plane's idle in a fast
-- descent, where the A/T's HOLD at 0.0013 had the EEC add about 2 kN an
-- engine (s148)
local IDLE_COMMAND = {GE = 25, PW = 0.95}
local function idle_command(key)
    if key == "PW" and B747DR_engineType == 0 then return B747_epr_model.idle_command(simDR_epr_mach) end
    return IDLE_COMMAND[key]
end
-- the flap lever's detents (0, 1, 5, 10, 20, 25, 30 at even steps of
-- sim/cockpit2/controls/flap_ratio) as trailing edge flap degrees
local FLAP_DETENTS = {0, 1, 5, 10, 20, 25, 30}
-- EICAS slots (laminar/B747/CAS/advisory_status, caution_status)
local ADV_IDLE_DISAGREE = 223
local ADV_LOW_IDLE = 309            -- ENG 1-4 LOW IDLE: 309-312
local ADV_EEC_MODE = 313            -- ENG 1-4 EEC MODE: 313-316
local ADV_ENG_CONTROL = 110         -- (2026-11-04) >ENG 1-4 CONTROL: 110-113
local ADV_ENG_CONTROLS = 323        -- (2026-11-04) >ENG CONTROLS
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
        inp.idle[n] = idle_command(inp.type)
        inp.reverser[n] = simDR_reverser_deploy_ratio[n - 1] > 0.01
        inp.altn[n] = B747DR_button_switch_position[6 + n] < 0.5    -- EEC MODE switches: [7]-[10]
        inp.fail_altn[n] = B747DR_eec_fail_altn_in[n - 1] > 0.5
        inp.fault[n] = B747DR_eec_fail_fault_in[n - 1] > 0.5
        inp.idle_min[n] = B747DR_eec_fail_idle_min_in[n - 1] > 0.5
        inp.idle_approach[n] = B747DR_eec_fail_idle_app_in[n - 1] > 0.5
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
        B747DR_eec_CAS_advisory[ADV_ENG_CONTROL + n - 1] = flag(eec_out.control_alert[n])
        B747DR_eec_altn_light_out[n - 1] = flag(eec_out.altn_light[n])
        B747DR_eec_CAS_caution[CAUTION_LIM_PROT + n - 1] = flag(eec_out.lim_prot[n])
        -- RR keeps its own (B747.40.xt.engines.lua)
        if B747DR_engineType ~= 2 then B747DR_eec_CAS_advisory[ADV_RPM_LIM + n - 1] = flag(eec_out.rpm_lim[n]) end
    end
    B747DR_eec_CAS_advisory[ADV_IDLE_DISAGREE] = flag(eec_out.idle_disagree)
    B747DR_eec_CAS_advisory[ADV_ENG_CONTROLS] = flag(eec_out.controls_alert)
    -- the A/T: off when an EEC goes to the alternate mode and while it may
    -- not be used; EEC_status gates the A/T modes in throttle_management
    -- (the A/T model disengages the A/T on the fail: the FMC's step 9f1)
    if eec_out.at_disconnect or eec_out.at_inhibit then
        if B747DR_autothrottle_fail == 0 then B747DR_autothrottle_fail = 1 end
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

-- (the FMC's step 9g3; notes/ATA-34-61-FMC.md §75) engine 0-3: the
-- reference thrust limit for the FMC's mode (B747.42.ref_thrust_model.lua)
-- with the FMS's takeoff derate (%) and assumed temperature (°C, -99 none);
-- the takeoff's thrust reduction (%) back for the FMC's climb derate
dofile("B747.42.ref_thrust_model.lua")
B747DR_eec_thrlim_sel = find_dataref("laminar/B747/fms/thrlim/sel")
B747DR_eec_thrlim_to_pct = find_dataref("laminar/B747/fms/thrlim/to_pct")
B747DR_eec_to_reduction = find_dataref("laminar/B747/engines/to_reduction")
-- the FMS's mode as a number (this plugin does not see the other's string
-- writes: s152's D-TO and s141's CLB came to the EEC as TO): 10 x TO 1,
-- CLB 2, CRZ 3, CON 4, GA 5, plus the rating, plus 100 with D-; the mode's
-- text back, into this plugin's ref_thr_limit_mode too (RR's branches read
-- it)
B747DR_eec_thrlim_code = find_dataref("laminar/B747/fms/thrlim/code")
local THRLIM_BASE = {"TO", "CLB", "CRZ", "CON", "GA"}
local function thrlim_mode()
    local c = math.floor(B747DR_eec_thrlim_code + 0.5)
    local d = c >= 100
    c = c % 100
    local base, n = THRLIM_BASE[math.floor(c / 10)], c % 10
    if not base then return nil end
    return (d and "D-" or "") .. base .. (n > 0 and (" " .. n) or "")
end
function B747_eec_thrlim_mode()
    local m = thrlim_mode()
    if m and B747DR_ref_thr_limit_mode ~= m then B747DR_ref_thr_limit_mode = m end
    return m or B747DR_ref_thr_limit_mode
end
local refIn = {}
function B747_eec_reference(engine)
    local inp = eec_inputs
    refIn.type, refIn.alt, refIn.tat = inp.type, inp.alt, inp.tat
    refIn.packs_on, refIn.wai, refIn.nai = inp.packs_on, inp.wai, inp.nai[engine + 1]
    refIn.mach = simDR_epr_mach
    refIn.kias = inp.kias
    refIn.mode = B747_eec_thrlim_mode()
    refIn.to_pct = B747DR_eec_thrlim_to_pct
    local sel = B747DR_eec_thrlim_sel
    refIn.sel = sel > -90 and sel or nil
    local v, red = B747_ref_thrust_model.reference(refIn)
    if engine == 0 and B747DR_eec_to_reduction ~= red then B747DR_eec_to_reduction = red end
    return v
end

-- (the FMC's step 9g4) the EICAS's target thrust cursor (ATA34_2 p.652):
-- magenta in the climb with VNAV engaged, in the descent with VNAV at idle
-- and anti-ice on, and with the A/T arm switch off (the pilots' manual
-- thrust); green else, at the reference. The second: the cursor at idle
-- (the descent's target: estimate; the others' targets the reference)
B747DR_eec_vnav_state = find_dataref("laminar/B747/autopilot/vnav_state")
B747DR_eec_fvn_phase = find_dataref("laminar/B747/fms/vnav/phase")
B747DR_eec_fvn_at = find_dataref("laminar/B747/fms/vnav/at")
B747DR_eec_at_armed = find_dataref("laminar/B747/autothrottle/armed")
function B747_eec_cursor()
    local inp = eec_inputs
    local ai = inp.wai
    for n = 1, 4 do ai = ai or inp.nai[n] end
    local vnav = B747DR_eec_vnav_state == 2
    local idle = vnav and B747DR_eec_fvn_phase == 3 and B747DR_eec_fvn_at == 2 and ai
    local magenta = (vnav and B747DR_eec_fvn_phase == 1) or idle or B747DR_eec_at_armed == 0
    return magenta, idle
end
-- engine 0-3: its idle command (the lever's idle end)
function B747_eec_idle(engine) return eec_inputs.idle[engine + 1] end

-- engine 0-3: X-Plane's throttle from the EEC's thrust control (GE and P&W,
-- forward thrust, engine running); ecc_spd in B747.42.xt.EEC.lua sets it
-- after the displays are worked out, and resets it otherwise. Its time step
-- at most X-Plane's 0.05 s a frame (2026-10-31: below 20 fps X-Plane's time
-- runs slower while SIM_PERIOD stays real time)
local EEC_DT_MAX = 0.05
-- (2026-11-10) the open-loop test (the EEC's init script; tests/flight/
-- measure/eec_steps_*.json): while test_open is 1 each engine's throttle is
-- the one it had when the test began plus test_step_pm per mille, and the
-- control starts again from X-Plane's throttle after it
B747DR_eec_test_open_in         = find_dataref("laminar/B747/engines/eec/test_open")
B747DR_eec_test_step_pm_in      = find_dataref("laminar/B747/engines/eec/test_step_pm")
local test_base = {}
local function test_throttle(engine)
    local n = engine + 1
    if B747DR_eec_test_open_in < 0.5 then
        test_base[n] = nil
        return nil
    end
    if test_base[n] == nil then test_base[n] = simDR_engn_thro_use[engine] end
    E.reset_thrust_control(eec_state, n)
    return math.max(0, math.min(1, test_base[n] + B747DR_eec_test_step_pm_in / 1000))
end
-- (2026-11-10) the slope of the value the thrust control follows against
-- X-Plane's throttle (B747.42.eec_model.lua, M.KP): the display formula's
-- slope against the thrust (P&W: the EPR model, B747_epr_model.epr; GE in
-- the air: its N1 polynomial, B747_ge_n1_of_thrust) times X-Plane's thrust
-- for each unit of throttle; nil where the GE's display is X-Plane's N1
-- (the takeoff: the model's tables). X-Plane's thrust for each unit of
-- throttle (kN, alike for both types): X-Plane's thrust goes about as the
-- throttle to the n-th power, so n x the thrust over the throttle, n =
-- N_A - N_B x delta (the open-loop test, 2026-11-10, tests/flight/measure/
-- eec_steps_*.json, and the takeoff roll of s11: n x thrust / throttle =
-- the measured slope with n 1.9 on the takeoff roll, 2.2 at 6,000 ft, 2.7
-- at 11,000 ft, 3.0 at FL250, 3.2 at FL390; the formula within -9 to +2 %
-- of the measured 470, 241, 187, 177, 142 kN). The present thrust and
-- throttle, the throttle at least THR_MIN, the result within C_RANGE
-- (estimates). Near idle X-Plane's thrust hardly moves with the throttle
-- (C_RANGE's low end; the slope's at SLOPE_MIN).
-- The first version (THRUST_C x delta^THRUST_P, from the cruise points
-- alone) gave 246 on the takeoff roll and the takeoff EPR 0.005 short at
-- 59 kt (s11 2026-11-10: too strong a proportional part held the throttle
-- back). The second took the larger of the present thrust and the
-- target's (for a spool-up, whose thrust lags its throttle): from idle
-- that made the slope about ten times X-Plane's, the throttle opened
-- slowly and the A/T overshot 250 kt by 6 kt at 10,000 ft (s220
-- 2026-11-10; offline from idle to EPR 1.01: 16 s, now 4 s, the previous
-- law 2.9 s with 0.03 over); the takeoff alike either way (10 to 11 s)
local N_A, N_B = 3.5, 1.6
local THR_MIN = 0.2
local C_RANGE = {50, 600}
local SLOPE_MIN = {PW = 0.2, GE = 15}       -- EPR, N1 % for each unit of throttle
local function thrust_per_throttle(f, thr, delta)
    local c = (N_A - N_B * delta) * f / math.max(THR_MIN, thr)
    return math.max(C_RANGE[1], math.min(C_RANGE[2], c))
end
local function plant_slope(key, engine, delta)
    local f = simDR_thrust_n[engine] / 1000
    local dydf
    if key == "GE" then
        if B747_ge_n1_from_xp(engine) then return nil end
        dydf = (B747_ge_n1_of_thrust((f + 0.5) * 1000) - B747_ge_n1_of_thrust(math.max(0, f - 0.5) * 1000)) / (f + 0.5 - math.max(0, f - 0.5))
    else
        local M = simDR_epr_mach
        dydf = (B747_epr_model.epr(f + 0.5, delta, M) - B747_epr_model.epr(f - 0.5, delta, M)) / 1.0
    end
    -- NaN or infinite: no air data yet (the GE's pressure ratio 0)
    if dydf ~= dydf or dydf == math.huge or dydf == -math.huge then return nil end
    local c = thrust_per_throttle(f, simDR_engn_thro_use[engine], delta)
    return math.max(SLOPE_MIN[key], dydf * c)
end
function B747_eec_throttle(engine)
    if eec_out == nil then return 0 end
    local test = test_throttle(engine)
    if test ~= nil then return test end
    local key = eec_inputs.type
    local actual = B747DR_display_EPR[engine]
    if key == "GE" then actual = B747DR_display_N1[engine] end
    local n = engine + 1
    local delta = math.max(0.1, simDR_epr_ambient_pa / 101325)
    return E.thrust_control(eec_state, key, n, eec_out.target[n], actual, simDR_engn_thro_use[engine], idle_command(key),
        math.min(SIM_PERIOD, EEC_DT_MAX), plant_slope(key, engine, delta), delta)
end

function B747_eec_reset_throttle(engine)
    E.reset_thrust_control(eec_state, engine + 1)
end

-- (ENG-31) GE in reverse with both cowls deployed: X-Plane's reverse
-- throttle the ECU's (B747_eec_model.reverse_throttle: 90 % of the maximum
-- rated thrust at full reverse), the share as the source gives it (in
-- thrust), not a control on the N1
function B747_eec_reverse_throttle(engine)
    return E.reverse_throttle(-B747DR_throttle_reversor[engine])
end
-- X-Plane's maximum reverse throttle (sim/aircraft/engine/acf_throtmax_REV):
-- GE 1, the ECU's share above giving the thrust; P&W the custom acf's 0.8
-- as before (no sources for the PW4000's reverse); RR its own
-- (B747.42.xt.EEC.RR.lua)
local REV_MAX = {[0] = 0.8, [1] = 1.0}
function B747_eec_reverse_max()
    local want = REV_MAX[B747DR_engineType]
    if want and math.abs(simDR_reverser_max - want) > 1e-6 then simDR_reverser_max = want end
end

-- an engine at full throttle still short of its target by more than this
-- (N1 % or EPR): X-Plane's engine cannot give the thrust, and the GE and P&W
-- files raise X-Plane's maximum thrust a little each frame (the previous
-- code's remedy, estimate)
local THRUST_SHORT = {GE = 0.2, PW = 0.005}
function B747_eec_thrust_short()
    if eec_out == nil or B747DR_eec_test_open_in > 0.5 then return false end
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
