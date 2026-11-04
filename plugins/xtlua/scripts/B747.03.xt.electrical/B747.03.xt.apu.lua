-- The APU model (B747.49.apu_model.lua) in the aircraft: reads the APU
-- selector, the BATTERY switch, X-Plane's APU (N1, running), the fire
-- protection's APU shutdown (B747.35.xt.fire.lua) and main tank 2; runs the model every frame and writes X-Plane's
-- APU starter switch, the inlet door, the generators' availability (the APU
-- GEN switches and the electrical model), the STATUS page N2 and oil, and the
-- EICAS messages APU, APU DOOR and APU RUNNING (docs/overhaul/notes/ATA-49.md).
-- B747.03.xt.electrical.lua loads it after its bindings and the electrical
-- glue; B747_apu() runs before B747_elec_buses(), which takes the generator
-- readiness from B747_apu_gen_ready().
dofile("B747.49.apu_model.lua")
local A = B747_apu_model

-- an APU fire detected, or the APU fire switch out (B747.35.xt.fire.lua)
B747DR_apu_fire_shutdown        = find_dataref("laminar/B747/fire/apu_shutdown")
simDR_apu_fuel_tank_kg          = find_dataref("sim/flightmodel/weight/m_fuel")
B747DR_apu_n2_display           = find_dataref("laminar/B747/apu/n2")
B747DR_apu_oil_display          = find_dataref("laminar/B747/apu/oil")
-- (2026-11-04) the failures (notes/ATA-49.md §11)
B747DR_apu_fail_limit_in        = find_dataref("laminar/B747/apu/fail/limit")
B747DR_apu_fail_duct_leak_in    = find_dataref("laminar/B747/apu/fail/duct_leak")
B747DR_apu_fail_door_in         = find_dataref("laminar/B747/apu/fail/door")

local MAIN2_TANK = 2                -- main tank 2 in X-Plane's tank list (B747.25.xt.fuel.lua)
local BATTERY_SWITCH = 13           -- button_switch/position[13]
-- EICAS slots (laminar/B747/CAS/*_status, B747.87.xt.warning.lua)
local ADV_APU, ADV_APU_DOOR = 13, 14
local MEMO_APU_RUNNING = 1

local apu_state = A.new()
local apu_inputs = A.inputs()
B747_apu_start_pushed = false       -- the selector handler sets it when the selector reaches START

local function flag(v)
    if v then return 1 end
    return 0
end

-- a new flight: the APU starts from OFF (a running X-Plane APU is taken over)
function B747_apu_flight_start()
    apu_state = A.new()
    B747_apu_start_pushed = false
end

-- the APU generators may connect (the electrical model adds the ground rule)
function B747_apu_gen_ready()
    return apu_state.out.gen_ready
end

-- every frame, before the electrical glue
function B747_apu()
    local inp = apu_inputs
    inp.selector = B747DR_elec_apu_sel_pos
    inp.start_pushed = B747_apu_start_pushed
    B747_apu_start_pushed = false
    inp.battery = B747DR_button_switch_position[BATTERY_SWITCH] > 0.5
    inp.n1 = simDR_apu_N1_pct
    inp.running = simDR_apu_running == 1
    inp.fire = B747DR_apu_fire_shutdown > 0.5
    inp.fuel = simDR_apu_fuel_tank_kg[MAIN2_TANK] > 0
    inp.limit_fail = B747DR_apu_fail_limit_in > 0.5
    inp.duct_leak = B747DR_apu_fail_duct_leak_in > 0.5
    inp.door_stuck = B747DR_apu_fail_door_in > 0.5
    -- (2026-11-04; APU-09) the starter's power (FCOM p.895-896): the 109 and
    -- 405 (P&W, RR) need both batteries charged, the 570 (GE) the main
    -- battery and the APU start TR on utility bus 4 or the APU battery (the
    -- electrical model's last frame: the batteries' charge, the buses)
    local eo = B747_elec_last_out and B747_elec_last_out()
    local sp = true
    if eo and eo.battery then
        local main, apub = eo.battery.main.ah > 0, eo.battery.apu.ah > 0
        if B747DR_elec_engine_type == 1 then
            sp = main and (apub or (eo.util ~= nil and eo.util[4] == true))
        else
            sp = main and apub
        end
    end
    inp.start_power = sp
    local out = A.update(apu_state, inp, SIM_PERIOD)

    -- X-Plane's APU spins as the model commands (read every frame, written
    -- only when different: ARCHITECTURE.md §9a)
    if simDR_apu_start_switch_mode ~= out.starter then simDR_apu_start_switch_mode = out.starter end
    B747DR_elec_apu_inlet_door_pos = out.door
    local avail = flag(out.gen_ready and B747DR_elec_pseu_air == 0)   -- ground only (FCOM p.895)
    B747DR_elec_apu_pwr1_available = avail
    B747DR_elec_apu_pwr2_available = avail
    B747DR_apu_n2_display = out.n2
    B747DR_apu_oil_display = out.oil
    B747DR_CAS_advisory_status[ADV_APU] = flag(out.adv_apu)
    B747DR_CAS_advisory_status[ADV_APU_DOOR] = flag(out.adv_door)
    B747DR_CAS_memo_status[MEMO_APU_RUNNING] = flag(out.memo_running)
end
