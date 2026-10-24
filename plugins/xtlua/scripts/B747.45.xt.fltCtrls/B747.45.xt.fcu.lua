-- The flap control unit model (B747.45.fcu_model.lua) in the aircraft (4-1):
-- reads the flap lever, hydraulic systems 1 and 4, the bleed ducts, the AC
-- and DC buses, the captain's airspeed, ALTN FLAPS, the air/ground relays,
-- the reverse thrust, the gear in transit and the failures
-- (laminar/B747/flt_ctrls/fail/..., X-Plane's flap actuator); writes the
-- trailing edge panels and the slats, which the hydraulics module puts on
-- the surfaces (laminar/B747/flt_ctrls/fcu/...), the FCUs' command
-- (laminar/B747/cablecontrols/flap_ratio: the lever's detent, or the load
-- relief's, for the engines, fuel, AFDS and FDR), the indication
-- (flap_deployed_ratio and 1-4, transition_status, EICAS1_display_status),
-- FLAPS CONTROL, FLAPS DRIVE, FLAPS PRIMARY, >FLAP RELIEF and the STATUS
-- messages. B747.45.xt.fltCtrls.lua loads it and binds the lever, the
-- buttons, ALTN FLAPS, the CAS arrays, the indication and the airspeed.
dofile("B747.45.fcu_model.lua")
local F = B747_fcu_model

simDR_fcu_lever                 = find_dataref("sim/cockpit2/controls/flap_ratio")
simDR_fcu_hyd_1                 = find_dataref("laminar/B747/hydraulics/pressure_1")
simDR_fcu_hyd_4                 = find_dataref("laminar/B747/hydraulics/pressure_4")
B747DR_fcu_duct_L               = find_dataref("laminar/B747/air/duct_pressure_L")
B747DR_fcu_duct_R               = find_dataref("laminar/B747/air/duct_pressure_R")
B747DR_fcu_bus_ac               = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_fcu_bus_dc               = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_fcu_pri_gnd              = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
simDR_fcu_agl                   = find_dataref("sim/flightmodel/position/y_agl")
simDR_fcu_prop_mode             = find_dataref("sim/cockpit2/engine/actuators/prop_mode")
simDR_fcu_gear                  = find_dataref("sim/flightmodel2/gear/deploy_ratio")
simDR_fcu_time                  = find_dataref("sim/time/total_running_time_sec")
B747DR_fcu_status               = find_dataref("laminar/B747/CAS/status_status")
B747DR_fcu_te_deg               = find_dataref("laminar/B747/flt_ctrls/fcu/te_deg")
B747DR_fcu_slat                 = find_dataref("laminar/B747/flt_ctrls/fcu/slat")
B747DR_fcu_le                   = find_dataref("laminar/B747/flt_ctrls/fcu/le")
B747DR_fcu_te_mode              = find_dataref("laminar/B747/flt_ctrls/fcu/te_mode")
B747DR_fcu_le_mode              = find_dataref("laminar/B747/flt_ctrls/fcu/le_mode")
B747DR_fcu_te_moving            = find_dataref("laminar/B747/flt_ctrls/fcu/te_moving")
B747DR_fcu_te_down              = find_dataref("laminar/B747/flt_ctrls/fcu/te_down")
B747DR_fcu_fail_fcu             = find_dataref("laminar/B747/flt_ctrls/fail/fcu")
B747DR_fcu_fail_te_primary      = find_dataref("laminar/B747/flt_ctrls/fail/te_primary")
B747DR_fcu_fail_te_secondary    = find_dataref("laminar/B747/flt_ctrls/fail/te_secondary")
B747DR_fcu_fail_te_stuck        = find_dataref("laminar/B747/flt_ctrls/fail/te_stuck")
B747DR_fcu_fail_le_primary      = find_dataref("laminar/B747/flt_ctrls/fail/le_primary")
B747DR_fcu_fail_le_secondary    = find_dataref("laminar/B747/flt_ctrls/fail/le_secondary")

local ALTN_ARM = 0                  -- button_switch/position[0]: ALTN FLAPS ARM
-- EICAS slots (B747.87.xt.warning.lua)
local CAUT_FLAPS_CONTROL, CAUT_FLAPS_DRIVE, CAUT_FLAPS_PRIMARY = 28, 29, 30
local ADV_FLAP_RELIEF = 142
local STATUS_TE_FLAPS = 81          -- TE FLAPS, LE SINGLE DRIVE, LE MULT DRIVE: 81-83
local STATUS_FLAP_CONTROL = 84      -- FLAP CONTROL L, C, R: 84-86
local STATUS_LOAD_RELIEF = 87       -- FLAP LOAD RELIEF
local INIT_S = 3                    -- the first reads of other modules' values are 0:
                                    -- the flaps start where the lever is meanwhile

local fcu_state = F.new()
local fcu_inputs = F.inputs()
local fcu_t0 = nil

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

function B747_fcu_flight_start()
    fcu_state = F.new()
    fcu_t0 = nil
end

function B747_fcu()
    local inp = fcu_inputs
    local now = simDR_fcu_time
    if fcu_t0 == nil then fcu_t0 = now end
    local init = now - fcu_t0 < INIT_S

    inp.lever = simDR_fcu_lever * 6
    inp.hyd_psi[1], inp.hyd_psi[2] = simDR_fcu_hyd_1, simDR_fcu_hyd_4
    inp.duct_psi[1], inp.duct_psi[2] = B747DR_fcu_duct_L, B747DR_fcu_duct_R
    for i = 1, 4 do
        inp.ac[i] = B747DR_fcu_bus_ac[i - 1] > 0.5
        inp.dc[i] = B747DR_fcu_bus_dc[i - 1] > 0.5
        inp.reverse[i] = simDR_fcu_prop_mode[i - 1] == 3     -- reverse thrust selected
    end
    inp.ias_kt = simDR_ind_airspeed_kts_pilot
    inp.altn_arm = B747DR_button_switch_position[ALTN_ARM] > 0.5
    local sel = B747DR_alt_flaps_sel_dial_pos
    inp.altn_sel = (sel > 0.5 and 1) or (sel < -0.5 and -1) or 0
    if init then
        inp.on_ground = simDR_fcu_agl < 15
    else
        inp.on_ground = B747DR_fcu_pri_gnd == 1
    end
    local gear_moving = false
    for i = 0, 2 do
        local r = simDR_fcu_gear[i]
        if r > 0.01 and r < 0.99 then gear_moving = true end
    end
    inp.gear_moving = gear_moving

    -- failures: X-Plane's flap actuator stops the TE hydraulic drives
    local act = simDR_flap_control_fail == 6
    for i = 1, 3 do inp.fcu_fail[i] = B747DR_fcu_fail_fcu[i - 1] > 0.5 end
    for g = 1, 2 do
        inp.te_pri_fail[g] = act or B747DR_fcu_fail_te_primary[g - 1] > 0.5
        inp.te_sec_fail[g] = B747DR_fcu_fail_te_secondary[g - 1] > 0.5
        inp.te_stuck[g] = B747DR_fcu_fail_te_stuck[g - 1] > 0.5
    end
    for g = 1, 3 do
        inp.le_pri_fail[g] = B747DR_fcu_fail_le_primary[g - 1] > 0.5
        inp.le_sec_fail[g] = B747DR_fcu_fail_le_secondary[g - 1] > 0.5
    end

    if init then F.set_to(fcu_state, inp) end
    local out = F.update(fcu_state, inp, SIM_PERIOD)

    -- the surfaces (the hydraulics module writes them to X-Plane)
    for i = 1, 4 do put(B747DR_fcu_te_deg, i - 1, out.te_deg[i]) end
    put(B747DR_fcu_slat, 0, out.slat_a)
    put(B747DR_fcu_slat, 1, out.slat_b)
    for g = 1, 3 do
        put(B747DR_fcu_le, 2 * g - 2, out.le[g][1])
        put(B747DR_fcu_le, 2 * g - 1, out.le[g][2])
        local l = fcu_state.le[g]
        put(B747DR_fcu_le_mode, g - 1, (l.stall and F.OFF) or l.mode)
    end
    for g = 1, 2 do
        local t = fcu_state.te[g]
        put(B747DR_fcu_te_mode, g - 1, ((t.stall or t.asym) and F.OFF) or t.mode)
    end
    local moving, down = flag(out.te_moving), flag(out.te_down)
    if B747DR_fcu_te_moving ~= moving then B747DR_fcu_te_moving = moving end
    if B747DR_fcu_te_down ~= down then B747DR_fcu_te_down = down end
    local cmd = out.cmd_detent / 6
    if B747DR_flap_ratio ~= cmd then B747DR_flap_ratio = cmd end

    -- the indication: 1 normal, 2 expanded (ALTN shows expanded: the panel
    -- has no alternate marks, FCTL-12)
    local tape, t1, t2, t3, t4 = out.tape, out.tapes[1], out.tapes[2], out.tapes[3], out.tapes[4]
    if B747DR_flap_deployed_ratio ~= tape then B747DR_flap_deployed_ratio = tape end
    if B747DR_flap_deployed_ratio1 ~= t1 then B747DR_flap_deployed_ratio1 = t1 end
    if B747DR_flap_deployed_ratio2 ~= t2 then B747DR_flap_deployed_ratio2 = t2 end
    if B747DR_flap_deployed_ratio3 ~= t3 then B747DR_flap_deployed_ratio3 = t3 end
    if B747DR_flap_deployed_ratio4 ~= t4 then B747DR_flap_deployed_ratio4 = t4 end
    local trans = flag(out.moving)
    if B747DR_flap_trans_status ~= trans then B747DR_flap_trans_status = trans end
    local display = 0
    if out.show then display = out.expanded and 2 or 1 end
    if B747DR_EICAS1_flap_display_status ~= display then B747DR_EICAS1_flap_display_status = display end

    -- messages (FCOM p.957; ATA27 p.133, p.337, p.411)
    put(B747DR_CAS_caution_status, CAUT_FLAPS_CONTROL, flag(out.flaps_control))
    put(B747DR_CAS_caution_status, CAUT_FLAPS_DRIVE, flag(out.flaps_drive))
    put(B747DR_CAS_caution_status, CAUT_FLAPS_PRIMARY, flag(out.flaps_primary))
    put(B747DR_CAS_advisory_status, ADV_FLAP_RELIEF, flag(out.relief))
    put(B747DR_fcu_status, STATUS_TE_FLAPS, flag(out.st_te_flaps))
    put(B747DR_fcu_status, STATUS_TE_FLAPS + 1, flag(out.st_le_single))
    put(B747DR_fcu_status, STATUS_TE_FLAPS + 2, flag(out.st_le_mult))
    for i = 1, 3 do put(B747DR_fcu_status, STATUS_FLAP_CONTROL + i - 1, flag(out.st_fcu[i])) end
    put(B747DR_fcu_status, STATUS_LOAD_RELIEF, flag(out.st_load_relief))
end
