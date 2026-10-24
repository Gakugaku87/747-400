-- The landing gear actuation model (B747.10.gear_model.lua) in the aircraft
-- (4-2 step 1): reads the gear lever, hydraulic systems 1 and 4, the AC and
-- DC buses, the ALTN GEAR EXTEND switches (button_switch/position [1] and
-- [2]), the PSEU's air mode, each gear's weight on the wheels and truck
-- tilt, and the failures (laminar/B747/gear/fail/..., X-Plane's rel_lagear1-5,
-- rel_gear_act and rel_gear_ind); moves each gear in X-Plane
-- (acf_gear_deploy, written every frame: X-Plane moves all its gear towards
-- its one handle, which follows the lever); writes the gear and door
-- positions (laminar/B747/gear/position, door), the EICAS gear indication
-- (annun_status, annun_gear, EICAS1_display_status), GEAR DISAGREE, GEAR TILT
-- and GEAR DOOR. B747.10.xt.gear.lua loads it after the PSEU's glue and uses
-- its bindings (the hydraulic pressures, the air mode, the wheels on the
-- ground) and its own (deploy_ratio, the truck angles, the lever, X-Plane's
-- handle).
dofile("B747.10.gear_model.lua")
local G = B747_gear_model

simDR_gact_deploy               = find_dataref("sim/aircraft/parts/acf_gear_deploy")
simDR_gact_time                 = find_dataref("sim/time/total_running_time_sec")
simDR_gact_rel_lagear1          = find_dataref("sim/operation/failures/rel_lagear1")
simDR_gact_rel_lagear2          = find_dataref("sim/operation/failures/rel_lagear2")
simDR_gact_rel_lagear3          = find_dataref("sim/operation/failures/rel_lagear3")
simDR_gact_rel_lagear4          = find_dataref("sim/operation/failures/rel_lagear4")
simDR_gact_rel_lagear5          = find_dataref("sim/operation/failures/rel_lagear5")
simDR_gact_rel_gear_act         = find_dataref("sim/operation/failures/rel_gear_act")
simDR_gact_rel_gear_ind         = find_dataref("sim/operation/failures/rel_gear_ind")
B747DR_gact_bus_ac              = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_gact_bus_dc              = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_gact_button              = find_dataref("laminar/B747/button_switch/position")
B747DR_gact_caution             = find_dataref("laminar/B747/CAS/caution_status")
B747DR_gact_advisory            = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_gact_annun_gear          = find_dataref("laminar/B747/gear/gear_position/annun_gear")
B747DR_gact_position            = find_dataref("laminar/B747/gear/position")
B747DR_gact_door                = find_dataref("laminar/B747/gear/door")
B747DR_gact_fail_actuator       = find_dataref("laminar/B747/gear/fail/actuator")
B747DR_gact_fail_door           = find_dataref("laminar/B747/gear/fail/door")
B747DR_gact_fail_indication     = find_dataref("laminar/B747/gear/fail/indication")
B747DR_gact_fail_tilt           = find_dataref("laminar/B747/gear/fail/truck_tilt")

-- X-Plane's gear index of the nose, left body, right body, left wing and
-- right wing gear (acf: 0 nose, 1 right body, 2 left body, 3 right wing,
-- 4 left wing; X-Plane's rel_lagearN is gear N-1, tried 2026-10-25)
local XP = {0, 2, 1, 4, 3}
local ALTN_NOSE_BODY, ALTN_WING = 1, 2      -- button_switch/position
-- EICAS slots (B747.87.xt.warning.lua)
local CAUT_GEAR_DISAGREE, CAUT_GEAR_TILT, ADV_GEAR_DOOR = 38, 39, 180
local INIT_S = 3                    -- the first reads of X-Plane's values are 0: the
                                    -- gear stays where X-Plane has it meanwhile

local gact_state = G.new()
local gact_inputs = G.inputs()
local gact_positions = {1, 1, 1, 1, 1}
local gact_rel = {0, 0, 0, 0, 0}
local gact_t0 = nil
local gact_lever_set = false

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_gear_act_flight_start()
    gact_state = G.new()
    gact_t0 = nil
    gact_lever_set = false
end

function B747_gear_act()
    local now = simDR_gact_time
    if gact_t0 == nil then gact_t0 = now end
    local init = now - gact_t0 < INIT_S
    for i = 1, 5 do gact_positions[i] = simDR_gear_deploy_ratio[XP[i]] end
    if not init and not gact_lever_set then
        -- the lever where X-Plane has put the gear: UP with all of it up (an
        -- air start), else DN
        local all_up = true
        for i = 1, 5 do if gact_positions[i] > 0.01 then all_up = false end end
        B747DR_gear_handle = all_up and 2 or 0
        G.set_to(gact_state, gact_positions)
        gact_lever_set = true
    end

    local inp = gact_inputs
    local h = B747DR_gear_handle
    inp.lever = (h < 0.5 and G.DN) or (h > 1.5 and G.UP) or G.OFF
    inp.hyd_psi[1], inp.hyd_psi[2] = B747DR_pseu_hyd_pressure_1, B747DR_pseu_hyd_pressure_4
    for i = 1, 4 do
        inp.ac[i] = B747DR_gact_bus_ac[i - 1] > 0.5
        inp.dc[i] = B747DR_gact_bus_dc[i - 1] > 0.5
    end
    inp.altn_nose_body = B747DR_gact_button[ALTN_NOSE_BODY] > 0.5
    inp.altn_wing = B747DR_gact_button[ALTN_WING] > 0.5
    inp.air = B747DR_pseu_pri_air == 1 and B747DR_pseu_alt_air == 1
    gact_rel[1], gact_rel[2], gact_rel[3] = simDR_gact_rel_lagear1, simDR_gact_rel_lagear2, simDR_gact_rel_lagear3
    gact_rel[4], gact_rel[5] = simDR_gact_rel_lagear4, simDR_gact_rel_lagear5
    local act, ind = simDR_gact_rel_gear_act == 6, simDR_gact_rel_gear_ind == 6
    for i = 1, 5 do
        local x = XP[i]
        inp.on_ground[i] = simDR_pseu_gear_on_ground[x] == 1
        inp.tilted[i] = simDR_gear_claw_angle[x] > B747_pseu_model.TILT_DEG and B747DR_gact_fail_tilt[i - 1] < 0.5
        inp.stuck[i] = act or gact_rel[x + 1] == 6 or B747DR_gact_fail_actuator[i - 1] > 0.5
        inp.door_stuck[i] = B747DR_gact_fail_door[i - 1] > 0.5
        inp.ind_fail[i] = ind or B747DR_gact_fail_indication[i - 1] > 0.5
    end

    local out
    if init then
        G.set_to(gact_state, gact_positions)
        out = G.update(gact_state, inp, 0)
    else
        out = G.update(gact_state, inp, SIM_PERIOD)
        -- X-Plane's gear where the model has it; X-Plane's handle the way the
        -- lever points (X-Plane's own travel is overwritten every frame)
        for i = 1, 5 do
            local x = XP[i]
            if math.abs(simDR_gact_deploy[x] - out.pos[i]) > 1e-6 then simDR_gact_deploy[x] = out.pos[i] end
        end
        local handle = (inp.lever == G.UP or (inp.lever == G.OFF and out.all_up)) and 0 or 1
        if simDR_gear_handle_down ~= handle then simDR_gear_handle_down = handle end
    end

    for i = 1, 5 do
        put(B747DR_gact_position, i - 1, out.pos[i])
        put(B747DR_gact_door, i - 1, out.door[i])
        put(B747DR_gact_annun_gear, i - 1, out.gear[i])
    end
    if B747DR_gear_annun_status ~= out.annun then B747DR_gear_annun_status = out.annun end
    if B747DR_EICAS1_gear_display_status ~= out.display then B747DR_EICAS1_gear_display_status = out.display end
    put(B747DR_gact_caution, CAUT_GEAR_DISAGREE, flag(out.gear_disagree))
    put(B747DR_gact_caution, CAUT_GEAR_TILT, flag(out.gear_tilt))
    put(B747DR_gact_advisory, ADV_GEAR_DOOR, flag(out.gear_door))
end
