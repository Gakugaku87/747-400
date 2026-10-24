-- The wheel brake model (B747.10.brake_model.lua) in the aircraft (4-2 step
-- 2): reads the pilots' brakes (X-Plane's brake commands, replaced here, and
-- the wing sweep axis that upstream used for a single brake axis), the
-- parking brake lever (laminar/B747/flt_ctrls/parking_brake_ratio, the 3D
-- lever), the hydraulic model's brake source and pressure
-- (laminar/B747/hydraulics/brake_source, brake_psi), the battery bus, the DC
-- buses, the PSEU's air mode, the chocks and the failures; writes X-Plane's
-- brakes (left/right_brake_ratio with override_toe_brakes always on, the
-- parking brake ratio as the trapped pressure's hold, acf_has_abs), the
-- valve (gear/brakes/park_valve), PARK BRAKE SET, ANTISKID, ANTISKID OFF and
-- BRAKE LIMITER. B747.10.xt.gear.lua loads it after the actuation's glue and
-- uses its bindings (the buses, the PSEU).
-- X-Plane's toe brake axes are not read: their index in
-- joy_mapped_axis_value is not documented here (the user's joystick has
-- none); while override_toe_brakes is on, X-Plane does not apply them.
-- The autobrakes (B747.10.autobrake_model.lua, 4-2 step 3) run here before
-- the brakes: the selector (gear/autobrakes/sel_dial_pos), the thrust levers
-- (laminar/B747/engine/throttle), the captain's IRS (status and selector) and
-- the groundspeed, the speedbrake lever, the PSEU, the brake source and the
-- normal antiskid; their pressure goes to the brakes, the selector moves
-- back to DISARM or OFF, the memo (AUTOBRAKES 1-4, MAX, RTO) and AUTOBRAKES.
-- X-Plane's own autobrakes stay OFF; its autobrake commands move the selector.
dofile("B747.10.brake_model.lua")
dofile("B747.10.autobrake_model.lua")
local B = B747_brake_model
local A = B747_autobrake_model

simDR_brk_override              = find_dataref("sim/operation/override/override_toe_brakes")
simDR_brk_left                  = find_dataref("sim/cockpit2/controls/left_brake_ratio")
simDR_brk_right                 = find_dataref("sim/cockpit2/controls/right_brake_ratio")
simDR_brk_park                  = find_dataref("sim/cockpit2/controls/parking_brake_ratio")
simDR_brk_abs                   = find_dataref("sim/aircraft/gear/acf_has_abs")
simDR_brk_sweep                 = find_dataref("sim/cockpit2/controls/wingsweep_ratio")
B747DR_brk_lever                = find_dataref("laminar/B747/flt_ctrls/parking_brake_ratio")
B747DR_brk_source               = find_dataref("laminar/B747/hydraulics/brake_source")
B747DR_brk_psi                  = find_dataref("laminar/B747/hydraulics/brake_psi")
B747DR_brk_bat_main             = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_brk_valve                = find_dataref("laminar/B747/gear/brakes/park_valve")
B747DR_brk_fail_antiskid        = find_dataref("laminar/B747/gear/fail/antiskid")
B747DR_brk_fail_limiter         = find_dataref("laminar/B747/gear/fail/brake_limiter")
B747DR_brk_fail_valve           = find_dataref("laminar/B747/gear/fail/park_valve")
B747DR_brk_memo                 = find_dataref("laminar/B747/CAS/memo_status")
simDR_brk_time                  = find_dataref("sim/time/total_running_time_sec")
simDR_brk_gs                    = find_dataref("sim/flightmodel/position/groundspeed")
B747DR_brk_throttle             = find_dataref("laminar/B747/engine/throttle")
B747DR_brk_iru_status           = find_dataref("laminar/B747/flt_mgmt/iru/status")
B747DR_brk_iru_dial             = find_dataref("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos")
B747DR_brk_speedbrake           = find_dataref("laminar/B747/flt_ctrls/speedbrake_lever")
B747DR_brk_fail_autobrake       = find_dataref("laminar/B747/gear/fail/autobrake")

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_ANTISKID, ADV_ANTISKID_OFF, ADV_BRAKE_LIMITER = 10, 11, 45
local MEMO_PARK_BRAKE_SET = 26
local ADV_AUTOBRAKES = 17
local MEMO_AUTOBRAKES = {{3, 2}, {4, 3}, {5, 4}, {6, 5}, {7, 6}, {0, 7}}    -- {selector, memo}: 1-4, MAX, RTO
local REGULAR = 0.5                 -- X-Plane's "regular" brakes on both pedals (estimate; "max" is 1)
local PEDAL_RATE = 4                -- the pedals pushed or let go in 0.25 s (estimate)
local INIT_S = 3                    -- the first reads of other modules' values are 0:
                                    -- the valve follows the lever meanwhile

local brk_state = B.new()
local brk_inputs = B.inputs()
local ab_state = A.new()
local ab_inputs = A.inputs()
local brk_t0 = nil
-- the pilots' brakes from X-Plane's commands: held regular, max, left, right;
-- the toggles
local hold = {regular = false, max = false, left = false, right = false}
local toggled = 0                   -- 0, REGULAR or 1
local pedal = {0, 0}

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

local function holder(name)
    return function(phase, duration)
        if phase == 0 or phase == 1 then hold[name] = true else hold[name] = false end
    end
end
local function toggler(level)
    return function(phase, duration)
        if phase == 0 then toggled = (toggled == level) and 0 or level end
    end
end
simCMD_brk_regular = replace_command("sim/flight_controls/brakes_regular", holder("regular"))
simCMD_brk_max = replace_command("sim/flight_controls/brakes_max", holder("max"))
simCMD_brk_left = replace_command("sim/flight_controls/left_brake", holder("left"))
simCMD_brk_right = replace_command("sim/flight_controls/right_brake", holder("right"))
simCMD_brk_toggle_regular = replace_command("sim/flight_controls/brakes_toggle_regular", toggler(REGULAR))
simCMD_brk_toggle_max = replace_command("sim/flight_controls/brakes_toggle_max", toggler(1))
-- X-Plane's parking brake commands move the 747's lever
simCMD_brk_park_set = replace_command("sim/flight_controls/park_brake_set",
    function(phase, duration) if phase == 0 then B747DR_brk_lever = 1 end end)
simCMD_brk_park_release = replace_command("sim/flight_controls/park_brake_release",
    function(phase, duration) if phase == 0 then B747DR_brk_lever = 0 end end)
simCMD_brk_park_toggle = replace_command("sim/flight_controls/park_brake_toggle",
    function(phase, duration) if phase == 0 then B747DR_brk_lever = (B747DR_brk_lever > 0.5) and 0 or 1 end end)
-- X-Plane's autobrake commands move the 747's selector (0 RTO, 1 OFF, 2
-- DISARM, 3-6 = 1-4, 7 MAX AUTO)
local function ab_select(dial)
    return function(phase, duration) if phase == 0 then B747DR_autobrakes_sel_dial_pos = dial end end
end
simCMD_brk_ab_off = replace_command("sim/flight_controls/brakes_off_auto", ab_select(1))
simCMD_brk_ab_rto = replace_command("sim/flight_controls/brakes_rto_auto", ab_select(0))
simCMD_brk_ab_1 = replace_command("sim/flight_controls/brakes_1_auto", ab_select(3))
simCMD_brk_ab_2 = replace_command("sim/flight_controls/brakes_2_auto", ab_select(4))
simCMD_brk_ab_3 = replace_command("sim/flight_controls/brakes_3_auto", ab_select(5))
simCMD_brk_ab_max = replace_command("sim/flight_controls/brakes_max_auto", ab_select(7))
simCMD_brk_ab_up = replace_command("sim/flight_controls/brakes_up_auto", function(phase, duration)
    if phase == 0 then B747DR_autobrakes_sel_dial_pos = math.min(B747DR_autobrakes_sel_dial_pos + 1, 7) end end)
simCMD_brk_ab_dn = replace_command("sim/flight_controls/brakes_dn_auto", function(phase, duration)
    if phase == 0 then B747DR_autobrakes_sel_dial_pos = math.max(B747DR_autobrakes_sel_dial_pos - 1, 0) end end)
simCMD_brk_ab_toggle = replace_command("sim/flight_controls/brakes_toggle_auto", function(phase, duration)
    if phase == 0 then B747DR_autobrakes_sel_dial_pos = (B747DR_autobrakes_sel_dial_pos == 1) and 3 or 1 end end)

function B747_brakes_flight_start()
    ab_state = A.new()
    brk_state = B.new()
    brk_t0 = nil
    hold.regular, hold.max, hold.left, hold.right = false, false, false, false
    toggled = 0
    pedal[1], pedal[2] = 0, 0
end

local function toward(x, target, step)
    if x < target then return math.min(target, x + step) end
    if x > target then return math.max(target, x - step) end
    return x
end

function B747_brakes()
    local now = simDR_brk_time
    if brk_t0 == nil then brk_t0 = now end
    local init = now - brk_t0 < INIT_S

    -- the pilots' pedals
    local both = math.max(hold.regular and REGULAR or 0, hold.max and 1 or 0, toggled, simDR_brk_sweep)
    local want_l = math.max(both, hold.left and 1 or 0)
    local want_r = math.max(both, hold.right and 1 or 0)
    pedal[1] = toward(pedal[1], want_l, PEDAL_RATE * SIM_PERIOD)
    pedal[2] = toward(pedal[2], want_r, PEDAL_RATE * SIM_PERIOD)

    -- the autobrakes (not in the first seconds: other modules' first reads are 0)
    local ab = nil
    if not init then
        local ai = ab_inputs
        ai.dial = B747DR_autobrakes_sel_dial_pos
        ai.air = B747DR_pseu_pri_air == 1 and B747DR_pseu_alt_air == 1
        ai.gnd = B747DR_pseu_pri_gnd == 1 or B747DR_pseu_alt_gnd == 1
        ai.gnd_both = B747DR_pseu_pri_gnd == 1 and B747DR_pseu_alt_gnd == 1
        for i = 1, 4 do ai.levers[i] = B747DR_brk_throttle[i - 1] end
        ai.irs = B747DR_brk_iru_status[0] == 2 and B747DR_brk_iru_dial[0] >= 2
        ai.gs_kt = simDR_brk_gs * 1.94384
        ai.pedal[1], ai.pedal[2] = pedal[1], pedal[2]
        ai.speedbrake = B747DR_brk_speedbrake
        ai.normal = B747DR_brk_source == B.NORMAL
        ai.antiskid_fault = brk_state.out.antiskid_off or B747DR_brk_fail_antiskid[0] > 0.5
        ai.fail = B747DR_brk_fail_autobrake > 0.5
        ab = A.update(ab_state, ai, SIM_PERIOD)
        if B747DR_autobrakes_sel_dial_pos ~= ab.dial then B747DR_autobrakes_sel_dial_pos = ab.dial end
    end

    local inp = brk_inputs
    inp.pedal[1], inp.pedal[2] = pedal[1], pedal[2]
    inp.auto = ab and ab.cmd or 0
    inp.lever = B747DR_brk_lever
    inp.source, inp.psi = B747DR_brk_source, B747DR_brk_psi
    inp.bat_bus = B747DR_brk_bat_main > 0.5
    for i = 1, 4 do inp.dc[i] = B747DR_gact_bus_dc[i - 1] > 0.5 end
    inp.air = B747DR_pseu_pri_air == 1
    inp.chocked = B747DR__gear_chocked == 1
    inp.fail_antiskid[1] = B747DR_brk_fail_antiskid[0] > 0.5
    inp.fail_antiskid[2] = B747DR_brk_fail_antiskid[1] > 0.5
    inp.fail_limiter = B747DR_brk_fail_limiter > 0.5
    inp.fail_valve = B747DR_brk_fail_valve > 0.5

    if init then B.set_to(brk_state, inp) end
    local out = B.update(brk_state, inp, init and 0 or SIM_PERIOD)

    -- X-Plane: the pedals with the toe brakes overridden, the parking brake as
    -- the hold, its antiskid
    if simDR_brk_override ~= 1 then simDR_brk_override = 1 end
    if simDR_brk_left ~= out.brake[1] then simDR_brk_left = out.brake[1] end
    if simDR_brk_right ~= out.brake[2] then simDR_brk_right = out.brake[2] end
    if simDR_brk_park ~= out.park then simDR_brk_park = out.park end
    local abs = flag(out.abs)
    if simDR_brk_abs ~= abs then simDR_brk_abs = abs end
    if out.release_lever and B747DR_brk_lever > 0 then B747DR_brk_lever = 0 end
    if B747DR_brk_valve ~= out.valve then B747DR_brk_valve = out.valve end

    put(B747DR_brk_memo, MEMO_PARK_BRAKE_SET, flag(out.park_brake_set))
    put(B747DR_gact_advisory, ADV_ANTISKID, flag(out.antiskid))
    put(B747DR_gact_advisory, ADV_ANTISKID_OFF, flag(out.antiskid_off))
    put(B747DR_gact_advisory, ADV_BRAKE_LIMITER, flag(out.brake_limiter))
    -- the autobrakes' memo and AUTOBRAKES; X-Plane's own autobrakes off
    for _, m in ipairs(MEMO_AUTOBRAKES) do put(B747DR_brk_memo, m[2], flag(ab ~= nil and ab.memo == m[1])) end
    put(B747DR_gact_advisory, ADV_AUTOBRAKES, flag(ab ~= nil and ab.autobrakes))
    if simDR_autobrakes_switch ~= 1 then simDR_autobrakes_switch = 1 end
end
