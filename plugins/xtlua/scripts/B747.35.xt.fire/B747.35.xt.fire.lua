--[[
*****************************************************************************************
* Program Script Name	:	B747.35.fire
* Author Name			:	Jim Gregory
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2016-04-26	0.01a				Start of Dev
*   2026-10-24						The engine and APU fire protection rebuilt around
*									B747.35.fire_model.lua (notes/ATA-26.md)
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	        *
*****************************************************************************************
--]]

-- The fire protection model (B747.35.fire_model.lua, 3-4) in the
-- aircraft: reads X-Plane's engine and APU fires, the failure datarefs of
-- what X-Plane does not have (overheats, cargo smoke, wheel well fire, duct
-- leaks, lavatory and crew rest smoke, the detector loops), the fire switch
-- and squib test commands, the CARGO FIRE switches, FUEL CONTROL, FIRE/OVHT
-- TEST, the air/ground relay, the APU, the engines, the centre duct and the
-- buses; writes the fire switches' animation, the bottles, X-Plane's
-- extinguishers, the APU shutdown (the APU glue reads it), the fire, cargo
-- and squib lights and the EICAS messages.

function deferred_command(name,desc,realFunc)
	return replace_command(name,realFunc)
end
--replace deferred_dataref
function deferred_dataref(name,nilType,callFunction)
  if callFunction~=nil then
    print("WARN:" .. name .. " is trying to wrap a function to a dataref -> use xlua")
    end
    return find_dataref(name)
end

dofile("B747.35.fire_model.lua")
local F = B747_fire_model


--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_startup_running       = find_dataref("sim/operation/prefs/startup_running")
simDR_engine_on_fire        = find_dataref("sim/flightmodel2/engines/is_on_fire")
simDR_apu_fire              = find_dataref("sim/operation/failures/rel_apu_fire")
simDR_engine_fire_ext_on    = find_dataref("sim/cockpit2/engine/actuators/fire_extinguisher_on")
simDR_apu_N1                = find_dataref("sim/cockpit2/electrical/APU_N1_percent")
simDR_agl                   = find_dataref("sim/flightmodel/position/y_agl")
simDR_engine_running        = find_dataref("sim/flightmodel/engine/ENGN_running")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_CAS_warning_status                   = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status                   = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status                  = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_status_status                    = find_dataref("laminar/B747/CAS/status_status")
B747DR_fire_fuel_control                    = find_dataref("laminar/B747/fuel/fuel_control/toggle_sw_pos")
B747DR_fire_pseu_pri_gnd                    = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_fire_bus_bat_apu                     = find_dataref("laminar/B747/electrical/bus/bat_apu")
B747DR_fire_bus_hot_bat_main                = find_dataref("laminar/B747/electrical/bus/hot_bat_main")
B747DR_fire_bus_bat_main                    = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_fire_bus_ac                          = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_fire_bus_dc                          = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_fire_duct_pressure_C                 = find_dataref("laminar/B747/air/duct_pressure_C")
B747DR_button_switch_position               = find_dataref("laminar/B747/button_switch/position")
B747DR_CAS_memo_status                      = find_dataref("laminar/B747/CAS/memo_status")


--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_fire_ovht_button_pos                 = deferred_dataref("laminar/B747/fire/fire_ovht/button_pos", "number")

B747DR_engine01_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine01/ext_switch/pos_arm", "number")
B747DR_engine02_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine02/ext_switch/pos_arm", "number")
B747DR_engine03_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine03/ext_switch/pos_arm", "number")
B747DR_engine04_fire_ext_switch_pos_arm     = deferred_dataref("laminar/B747/fire/engine04/ext_switch/pos_arm", "number")

B747DR_engine01_fire_ext_switch_pos_disch   = deferred_dataref("laminar/B747/fire/engine01/ext_switch/pos_disch", "number")
B747DR_engine02_fire_ext_switch_pos_disch   = deferred_dataref("laminar/B747/fire/engine02/ext_switch/pos_disch", "number")
B747DR_engine03_fire_ext_switch_pos_disch   = deferred_dataref("laminar/B747/fire/engine03/ext_switch/pos_disch", "number")
B747DR_engine04_fire_ext_switch_pos_disch   = deferred_dataref("laminar/B747/fire/engine04/ext_switch/pos_disch", "number")

B747DR_fire_ext_bottle_0102A_psi            = deferred_dataref("laminar/B747/fire/engine01_02A/ext_bottle/psi", "number")
B747DR_fire_ext_bottle_0102B_psi            = deferred_dataref("laminar/B747/fire/engine01_02B/ext_bottle/psi", "number")
B747DR_fire_ext_bottle_0304A_psi            = deferred_dataref("laminar/B747/fire/engine03_04A/ext_bottle/psi", "number")
B747DR_fire_ext_bottle_0304B_psi            = deferred_dataref("laminar/B747/fire/engine03_04B/ext_bottle/psi", "number")
B747DR_fire_apu_ext_bottle_psi              = deferred_dataref("laminar/B747/fire/apu/ext_bottle/psi", "number")
B747DR_fire_apu_ext_switch_pos_arm          = deferred_dataref("laminar/B747/fire/apu/ext_switch/pos_arm", "number")
B747DR_fire_apu_ext_switch_pos_disch        = deferred_dataref("laminar/B747/fire/apu/ext_switch/pos_disch", "number")
B747DR_fire_apu_shutdown                    = deferred_dataref("laminar/B747/fire/apu_shutdown", "number")
B747DR_fire_apu_horn                        = deferred_dataref("laminar/B747/fire/apu_horn", "number")
B747DR_fire_light_btl_disch                 = deferred_dataref("laminar/B747/fire/light/btl_disch", "array[5]")
B747DR_fire_fail_loop_a                     = deferred_dataref("laminar/B747/fire/fail/loop_a", "array[13]")
B747DR_fire_fail_loop_b                     = deferred_dataref("laminar/B747/fire/fail/loop_b", "array[13]")
B747DR_fire_fail_eng_ovht                   = deferred_dataref("laminar/B747/fire/fail/eng_ovht", "array[4]")
B747DR_fire_fail_cargo_smoke                = deferred_dataref("laminar/B747/fire/fail/cargo_smoke", "array[4]")
B747DR_fire_fail_wheel_well                 = deferred_dataref("laminar/B747/fire/fail/wheel_well", "number")
B747DR_fire_fail_duct_leak                  = deferred_dataref("laminar/B747/fire/fail/duct_leak", "array[3]")
B747DR_fire_fail_lav_smoke                  = deferred_dataref("laminar/B747/fire/fail/lav_smoke", "number")
B747DR_fire_fail_rest_smoke                 = deferred_dataref("laminar/B747/fire/fail/rest_smoke", "number")
B747DR_fire_cargo_ext_bottle_psi            = deferred_dataref("laminar/B747/fire/cargo/ext_bottle/psi", "array[4]")
B747DR_fire_light_cargo                     = deferred_dataref("laminar/B747/fire/light/cargo", "array[3]")
B747DR_fire_light_squib                     = deferred_dataref("laminar/B747/fire/light/squib", "array[9]")
B747DR_fire_squib_test_pos                  = deferred_dataref("laminar/B747/fire/squib_test/button_pos", "array[2]")
B747DR_engine_fire                          = deferred_dataref("laminar/B747/annunciators/engine_fires", "array[5]")

B747DR_init_fire_CD                         = deferred_dataref("laminar/B747/fire/init_CD", "number")


--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- the commands reach the model as one-frame inputs
local fire_inputs = F.inputs()

----- FIRE/OVERHEAT TEST ----------------------------------------------------------------
function B747_fire_ovht_test_button_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_fire_ovht_button_pos = 1
    elseif phase == 2 then
        B747DR_fire_ovht_button_pos = 0
    end
end

----- FIRE EXTINGUISHER SWITCHES --------------------------------------------------------
-- pull (or push back in), rotate towards bottle A or B, Fire Override
local function eng_toggle(n, phase) if phase == 0 then fire_inputs.eng_toggle[n] = true end end
local function eng_to_a(n, phase) if phase == 0 then fire_inputs.eng_rotate[n] = F.A_DIR[n] end end
local function eng_to_b(n, phase) if phase == 0 then fire_inputs.eng_rotate[n] = -F.A_DIR[n] end end
local function eng_override(n, phase) if phase == 0 then fire_inputs.eng_override[n] = true end end

function B747_eng01_fire_ext_switch_arm_CMDhandler(phase, duration) eng_toggle(1, phase) end
function B747_eng02_fire_ext_switch_arm_CMDhandler(phase, duration) eng_toggle(2, phase) end
function B747_eng03_fire_ext_switch_arm_CMDhandler(phase, duration) eng_toggle(3, phase) end
function B747_eng04_fire_ext_switch_arm_CMDhandler(phase, duration) eng_toggle(4, phase) end
function B747_eng01_fire_ext_switch_A_CMDhandler(phase, duration) eng_to_a(1, phase) end
function B747_eng01_fire_ext_switch_B_CMDhandler(phase, duration) eng_to_b(1, phase) end
function B747_eng02_fire_ext_switch_A_CMDhandler(phase, duration) eng_to_a(2, phase) end
function B747_eng02_fire_ext_switch_B_CMDhandler(phase, duration) eng_to_b(2, phase) end
function B747_eng03_fire_ext_switch_A_CMDhandler(phase, duration) eng_to_a(3, phase) end
function B747_eng03_fire_ext_switch_B_CMDhandler(phase, duration) eng_to_b(3, phase) end
function B747_eng04_fire_ext_switch_A_CMDhandler(phase, duration) eng_to_a(4, phase) end
function B747_eng04_fire_ext_switch_B_CMDhandler(phase, duration) eng_to_b(4, phase) end
function B747_eng01_fire_ext_switch_override_CMDhandler(phase, duration) eng_override(1, phase) end
function B747_eng02_fire_ext_switch_override_CMDhandler(phase, duration) eng_override(2, phase) end
function B747_eng03_fire_ext_switch_override_CMDhandler(phase, duration) eng_override(3, phase) end
function B747_eng04_fire_ext_switch_override_CMDhandler(phase, duration) eng_override(4, phase) end

-- the APU fire switch (no 3D manipulator: commands only)
function B747_apu_fire_ext_switch_arm_CMDhandler(phase, duration)
    if phase == 0 then fire_inputs.apu_toggle = true end
end
function B747_apu_fire_ext_switch_rotate_L_CMDhandler(phase, duration)
    if phase == 0 then fire_inputs.apu_rotate = -1 end
end
function B747_apu_fire_ext_switch_rotate_R_CMDhandler(phase, duration)
    if phase == 0 then fire_inputs.apu_rotate = 1 end
end
function B747_apu_fire_ext_switch_override_CMDhandler(phase, duration)
    if phase == 0 then fire_inputs.apu_override = true end
end

-- SQUIB TEST 1, 2 (P461; no 3D manipulator): held; back out 0.3 s after
-- the last event (XTLua does not always pass the end of a short press)
local SQUIB_SPRING_S = 0.3
local squib_spring = {0, 0}
local function squib_test(i, phase)
    if phase == 0 then B747DR_fire_squib_test_pos[i - 1] = 1 end
    if phase < 2 then squib_spring[i] = SQUIB_SPRING_S else squib_spring[i] = 0 end
end
function B747_fire_squib_test_1_CMDhandler(phase, duration) squib_test(1, phase) end
function B747_fire_squib_test_2_CMDhandler(phase, duration) squib_test(2, phase) end

function B747_ai_fire_quick_start_CMDhandler(phase, duration)
	if phase == 0 then
		B747_set_fire_all_modes()
		B747_set_fire_CD()
		B747_set_fire_ER()
	end
end


--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

----- FIRE/OVERHEAT TEST ----------------------------------------------------------------
B747CMD_fire_ovht_test_button       = deferred_command("laminar/B747/fire/button/fire_ovht_test", "Fire/Overheat Test", B747_fire_ovht_test_button_CMDhandler)

----- FIRE EXTINGUISHER SWITCHES --------------------------------------------------------
B747CMD_eng01_fire_ext_switch_arm   = deferred_command("laminar/B747/fire/engine01/ext_switch_arm", "Fire Extinguisher Switch 01 Arm", B747_eng01_fire_ext_switch_arm_CMDhandler)
B747CMD_eng02_fire_ext_switch_arm   = deferred_command("laminar/B747/fire/engine02/ext_switch_arm", "Fire Extinguisher Switch 02 Arm", B747_eng02_fire_ext_switch_arm_CMDhandler)
B747CMD_eng03_fire_ext_switch_arm   = deferred_command("laminar/B747/fire/engine03/ext_switch_arm", "Fire Extinguisher Switch 03 Arm", B747_eng03_fire_ext_switch_arm_CMDhandler)
B747CMD_eng04_fire_ext_switch_arm   = deferred_command("laminar/B747/fire/engine04/ext_switch_arm", "Fire Extinguisher Switch 04 Arm", B747_eng04_fire_ext_switch_arm_CMDhandler)

B747CMD_eng01_fire_ext_switch_A     = deferred_command("laminar/B747/fire/engine01/ext_switch_A", "Fire Extinguisher Switch A", B747_eng01_fire_ext_switch_A_CMDhandler)
B747CMD_eng01_fire_ext_switch_B     = deferred_command("laminar/B747/fire/engine01/ext_switch_B", "Fire Extinguisher Switch B", B747_eng01_fire_ext_switch_B_CMDhandler)
B747CMD_eng02_fire_ext_switch_A     = deferred_command("laminar/B747/fire/engine02/ext_switch_A", "Fire Extinguisher Switch A", B747_eng02_fire_ext_switch_A_CMDhandler)
B747CMD_eng02_fire_ext_switch_B     = deferred_command("laminar/B747/fire/engine02/ext_switch_B", "Fire Extinguisher Switch B", B747_eng02_fire_ext_switch_B_CMDhandler)
B747CMD_eng03_fire_ext_switch_A     = deferred_command("laminar/B747/fire/engine03/ext_switch_A", "Fire Extinguisher Switch A", B747_eng03_fire_ext_switch_A_CMDhandler)
B747CMD_eng03_fire_ext_switch_B     = deferred_command("laminar/B747/fire/engine03/ext_switch_B", "Fire Extinguisher Switch B", B747_eng03_fire_ext_switch_B_CMDhandler)
B747CMD_eng04_fire_ext_switch_A     = deferred_command("laminar/B747/fire/engine04/ext_switch_A", "Fire Extinguisher Switch A", B747_eng04_fire_ext_switch_A_CMDhandler)
B747CMD_eng04_fire_ext_switch_B     = deferred_command("laminar/B747/fire/engine04/ext_switch_B", "Fire Extinguisher Switch B", B747_eng04_fire_ext_switch_B_CMDhandler)

B747CMD_eng01_fire_ext_switch_override = deferred_command("laminar/B747/fire/engine01/ext_switch_override", "Fire Override 01 (unlocks and pulls the fire switch)", B747_eng01_fire_ext_switch_override_CMDhandler)
B747CMD_eng02_fire_ext_switch_override = deferred_command("laminar/B747/fire/engine02/ext_switch_override", "Fire Override 02 (unlocks and pulls the fire switch)", B747_eng02_fire_ext_switch_override_CMDhandler)
B747CMD_eng03_fire_ext_switch_override = deferred_command("laminar/B747/fire/engine03/ext_switch_override", "Fire Override 03 (unlocks and pulls the fire switch)", B747_eng03_fire_ext_switch_override_CMDhandler)
B747CMD_eng04_fire_ext_switch_override = deferred_command("laminar/B747/fire/engine04/ext_switch_override", "Fire Override 04 (unlocks and pulls the fire switch)", B747_eng04_fire_ext_switch_override_CMDhandler)

B747CMD_apu_fire_ext_switch_arm      = deferred_command("laminar/B747/fire/apu/ext_switch_arm", "APU Fire Switch Pull/Push", B747_apu_fire_ext_switch_arm_CMDhandler)
B747CMD_apu_fire_ext_switch_rotate_L = deferred_command("laminar/B747/fire/apu/ext_switch_rotate_L", "APU Fire Switch Rotate Left", B747_apu_fire_ext_switch_rotate_L_CMDhandler)
B747CMD_apu_fire_ext_switch_rotate_R = deferred_command("laminar/B747/fire/apu/ext_switch_rotate_R", "APU Fire Switch Rotate Right", B747_apu_fire_ext_switch_rotate_R_CMDhandler)
B747CMD_apu_fire_ext_switch_override = deferred_command("laminar/B747/fire/apu/ext_switch_override", "APU Fire Override (unlocks and pulls the fire switch)", B747_apu_fire_ext_switch_override_CMDhandler)

B747CMD_fire_squib_test_1          = deferred_command("laminar/B747/fire/squib_test_1", "Squib Test 1 (hold)", B747_fire_squib_test_1_CMDhandler)
B747CMD_fire_squib_test_2          = deferred_command("laminar/B747/fire/squib_test_2", "Squib Test 2 (hold)", B747_fire_squib_test_2_CMDhandler)

-- AI
B747CMD_ai_fire_quick_start			= deferred_command("laminar/B747/ai/fire_quick_start", "number", B747_ai_fire_quick_start_CMDhandler)


--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

local INIT_S = 3            -- the first seconds: the air/ground by the height (XTLua's first reads of
                            -- the other modules' datarefs are 0)
-- EICAS slots (B747.87.xt.warning.lua)
local WARN_FIRE_APU, WARN_FIRE_ENG = 8, 11                      -- FIRE ENG 1-4: 11-14
local WARN_TEST_FAIL, WARN_TEST_PASS, WARN_TEST_IN_PROG = 19, 20, 24
local CAUT_OVHT_NAC = 79                                        -- OVHT ENG 1-4 NAC: 79-82
local ADV_BTL_LO = {47, 48, 321, 322}                           -- >BTL LO L ENG A, B, R ENG A, B
local ADV_BOTTLE_LOW_APU, ADV_DET_FIRE_APU, ADV_DET_FIRE_OHT = 44, 58, 59   -- >DET FIRE/OHT 1-4: 59-62
local WARN_FIRE_CARGO = {10, 9}                                 -- FIRE CARGO FWD, AFT
local WARN_FIRE_WHEEL_WELL = 21
local CAUT_DUCT_LEAK = {7, 6, 8}                                -- BLD DUCT LEAK L, C, R
local CAUT_SMOKE_REST = 52                                      -- SMOKE DR 5 REST
local ADV_CARGO_DET_AIR, ADV_CGO_BTL_DISCH, ADV_SMOKE_LAV = 49, 51, 264
local SW_CARGO_ARM_FWD, SW_CARGO_ARM_AFT, SW_CARGO_DISCH = 84, 85, 86  -- button_switch/position
local CARGO_AIR_PSI = 5     -- the venturi draws with the centre duct above this (estimate: the
                            -- sources give inches of water at the venturi, ATA26_28 p.144)
-- STATUS: ENG n FIRE LP A, B (40-47), ENG n OVHT LP A, B (48-55), APU FIRE
-- LOOP A, B (56-57), FIRE/OVHT SYS (58), BTL LOW L/R ENG A/B (59-62),
-- BOTTLE LOW APU (63)
local STATUS_FIRE_LP, STATUS_OVHT_LP, STATUS_APU_LOOP, STATUS_FIRE_SYS = 40, 48, 56, 58
local STATUS_BTL_LOW, STATUS_BOTTLE_LOW_APU = 59, 63
-- STATUS: FWD CARGO 1, 2 and AFT CARGO 3, 4 LP A, B (64-71), CARGO DET FWD,
-- AFT (72-73), CARGO DET AIR (74), BTL LOW CARGO A-D (75-78), BLD DUCT LEAK
-- L, R (79-80)
local STATUS_CARGO_LP, STATUS_CARGO_DET, STATUS_CARGO_DET_AIR = 64, 72, 74
local STATUS_BTL_LOW_CARGO, STATUS_DUCT_LEAK = 75, 79

local fire_state = F.new()
local fire_t = 0
local animation = {arm = {0, 0, 0, 0}, disch = {0, 0, 0, 0}}

local function flag(v)
    if v then return 1 end
    return 0
end

-- datarefs: read first, write when different (TESTING.md §1.2)
local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

----- ANIMATION UTILITY -----------------------------------------------------------------
function B747_set_animation_position(current_value, target, min, max, speed)

    local fps_factor = math.min(1.0, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end

local function read_inputs(inp)
    for n = 1, 4 do
        inp.eng_fire_heat[n] = simDR_engine_on_fire[n - 1] > 0
        inp.eng_ovht_heat[n] = B747DR_fire_fail_eng_ovht[n - 1] > 0.5
        inp.fuel_cutoff[n] = B747DR_fire_fuel_control[n - 1] < 0.5
    end
    inp.apu_fire_heat = simDR_apu_fire == 6
    for z = 1, F.ZONES do
        inp.loop_failed_a[z] = B747DR_fire_fail_loop_a[z - 1] > 0.5
        inp.loop_failed_b[z] = B747DR_fire_fail_loop_b[z - 1] > 0.5
    end
    inp.det_power = B747DR_fire_bus_bat_apu > 0.5
    inp.hot_bat = B747DR_fire_bus_hot_bat_main > 0.5
    inp.test = B747DR_fire_ovht_button_pos > 0.5
    if fire_t < INIT_S then inp.on_ground = simDR_agl < 15 else inp.on_ground = B747DR_fire_pseu_pri_gnd == 1 end
    inp.apu_n1 = simDR_apu_N1
    local running = 0
    for n = 0, 3 do if simDR_engine_running[n] == 1 then running = running + 1 end end
    inp.engines_running = running
    for k = 1, 4 do inp.cargo_smoke[k] = B747DR_fire_fail_cargo_smoke[k - 1] > 0.5 end
    inp.cargo_airflow = B747DR_fire_duct_pressure_C > CARGO_AIR_PSI
    inp.wheel_well_heat = B747DR_fire_fail_wheel_well > 0.5
    inp.wheel_well_power = B747DR_fire_bus_ac[1] > 0.5
    for d = 1, 3 do inp.duct_leak[d] = B747DR_fire_fail_duct_leak[d - 1] > 0.5 end
    inp.duct_power = B747DR_fire_bus_dc[1] > 0.5 or B747DR_fire_bus_bat_main > 0.5
    inp.lav_smoke = B747DR_fire_fail_lav_smoke > 0.5
    inp.rest_smoke = B747DR_fire_fail_rest_smoke > 0.5
    inp.squib_test[1] = B747DR_fire_squib_test_pos[0] > 0.5
    inp.squib_test[2] = B747DR_fire_squib_test_pos[1] > 0.5
    inp.cargo_arm[1] = B747DR_button_switch_position[SW_CARGO_ARM_FWD] > 0.5
    inp.cargo_arm[2] = B747DR_button_switch_position[SW_CARGO_ARM_AFT] > 0.5
    inp.cargo_disch = B747DR_button_switch_position[SW_CARGO_DISCH] > 0.5
end

-- the squib test buttons spring back
local function squib_springs(dt)
    for i = 1, 2 do
        if B747DR_fire_squib_test_pos[i - 1] > 0.5 then
            squib_spring[i] = squib_spring[i] - dt
            if squib_spring[i] <= 0 then B747DR_fire_squib_test_pos[i - 1] = 0 end
        end
    end
end

-- the commands were consumed by this frame's update
local function clear_commands(inp)
    for n = 1, 4 do
        inp.eng_toggle[n], inp.eng_override[n], inp.eng_rotate[n] = false, false, 0
    end
    inp.apu_toggle, inp.apu_override, inp.apu_rotate = false, false, 0
end

local function write_switches(out)
    for n = 1, 4 do
        animation.arm[n] = B747_set_animation_position(animation.arm[n], out.pulled[n] and 1 or 0, 0.0, 1.0, 10)
        animation.disch[n] = B747_set_animation_position(animation.disch[n], out.rot[n], -1.0, 1.0, 10)
    end
    local a, d = animation.arm, animation.disch
    if B747DR_engine01_fire_ext_switch_pos_arm ~= a[1] then B747DR_engine01_fire_ext_switch_pos_arm = a[1] end
    if B747DR_engine02_fire_ext_switch_pos_arm ~= a[2] then B747DR_engine02_fire_ext_switch_pos_arm = a[2] end
    if B747DR_engine03_fire_ext_switch_pos_arm ~= a[3] then B747DR_engine03_fire_ext_switch_pos_arm = a[3] end
    if B747DR_engine04_fire_ext_switch_pos_arm ~= a[4] then B747DR_engine04_fire_ext_switch_pos_arm = a[4] end
    if B747DR_engine01_fire_ext_switch_pos_disch ~= d[1] then B747DR_engine01_fire_ext_switch_pos_disch = d[1] end
    if B747DR_engine02_fire_ext_switch_pos_disch ~= d[2] then B747DR_engine02_fire_ext_switch_pos_disch = d[2] end
    if B747DR_engine03_fire_ext_switch_pos_disch ~= d[3] then B747DR_engine03_fire_ext_switch_pos_disch = d[3] end
    if B747DR_engine04_fire_ext_switch_pos_disch ~= d[4] then B747DR_engine04_fire_ext_switch_pos_disch = d[4] end
    local apu_arm, apu_disch = flag(out.apu_pulled), out.apu_rot
    if B747DR_fire_apu_ext_switch_pos_arm ~= apu_arm then B747DR_fire_apu_ext_switch_pos_arm = apu_arm end
    if B747DR_fire_apu_ext_switch_pos_disch ~= apu_disch then B747DR_fire_apu_ext_switch_pos_disch = apu_disch end
end

local function write_outputs(out)
    write_switches(out)
    -- the bottles and their lights (BTL DISCH: the lighting module)
    local p = out.btl_psi
    if B747DR_fire_ext_bottle_0102A_psi ~= p[1] then B747DR_fire_ext_bottle_0102A_psi = p[1] end
    if B747DR_fire_ext_bottle_0102B_psi ~= p[2] then B747DR_fire_ext_bottle_0102B_psi = p[2] end
    if B747DR_fire_ext_bottle_0304A_psi ~= p[3] then B747DR_fire_ext_bottle_0304A_psi = p[3] end
    if B747DR_fire_ext_bottle_0304B_psi ~= p[4] then B747DR_fire_ext_bottle_0304B_psi = p[4] end
    if B747DR_fire_apu_ext_bottle_psi ~= p[F.APU_BTL] then B747DR_fire_apu_ext_bottle_psi = p[F.APU_BTL] end
    for b = 1, F.BOTTLES do put(B747DR_fire_light_btl_disch, b - 1, flag(out.btl_low[b])) end
    -- X-Plane's extinguishers; its APU fire goes out with the APU bottle (estimate:
    -- X-Plane has no APU extinguisher)
    for n = 1, 4 do put(simDR_engine_fire_ext_on, n - 1, flag(out.extinguish[n])) end
    if out.apu_extinguish and simDR_apu_fire == 6 then simDR_apu_fire = 0 end
    -- the APU (B747.03.xt.apu.lua) and its horn
    local shutdown, horn = flag(out.apu_shutdown), flag(out.apu_horn)
    if B747DR_fire_apu_shutdown ~= shutdown then B747DR_fire_apu_shutdown = shutdown end
    if B747DR_fire_apu_horn ~= horn then B747DR_fire_apu_horn = horn end
    -- the fire warning lights: the engine and APU fire switches
    for n = 1, 4 do put(B747DR_engine_fire, n - 1, flag(out.eng_light[n])) end
    put(B747DR_engine_fire, 4, flag(out.apu_light))
    -- EICAS (FCOM p.921-923; ATA26_28 p.34, p.46, p.78, p.102, p.130)
    for n = 1, 4 do
        local fire_z, ovht_z = F.ENG_FIRE + n, F.ENG_OVHT + n
        put(B747DR_CAS_warning_status, WARN_FIRE_ENG + n - 1, flag(out.fire[fire_z]))
        put(B747DR_CAS_caution_status, CAUT_OVHT_NAC + n - 1, flag(out.fire[ovht_z]))
        put(B747DR_CAS_advisory_status, ADV_DET_FIRE_OHT + n - 1, flag(out.det_failed[fire_z] or out.det_failed[ovht_z]))
        put(B747DR_CAS_advisory_status, ADV_BTL_LO[n], flag(out.btl_low[n]))
        put(B747DR_CAS_status_status, STATUS_FIRE_LP + 2 * (n - 1), flag(out.lp_a[fire_z]))
        put(B747DR_CAS_status_status, STATUS_FIRE_LP + 2 * (n - 1) + 1, flag(out.lp_b[fire_z]))
        put(B747DR_CAS_status_status, STATUS_OVHT_LP + 2 * (n - 1), flag(out.lp_a[ovht_z]))
        put(B747DR_CAS_status_status, STATUS_OVHT_LP + 2 * (n - 1) + 1, flag(out.lp_b[ovht_z]))
        put(B747DR_CAS_status_status, STATUS_BTL_LOW + n - 1, flag(out.btl_low[n]))
    end
    put(B747DR_CAS_warning_status, WARN_FIRE_APU, flag(out.fire[F.APU]))
    put(B747DR_CAS_advisory_status, ADV_DET_FIRE_APU, flag(out.det_failed[F.APU]))
    put(B747DR_CAS_advisory_status, ADV_BOTTLE_LOW_APU, flag(out.btl_low[F.APU_BTL]))
    put(B747DR_CAS_status_status, STATUS_APU_LOOP, flag(out.lp_a[F.APU]))
    put(B747DR_CAS_status_status, STATUS_APU_LOOP + 1, flag(out.lp_b[F.APU]))
    put(B747DR_CAS_status_status, STATUS_FIRE_SYS, flag(out.sys_power))
    put(B747DR_CAS_status_status, STATUS_BOTTLE_LOW_APU, flag(out.btl_low[F.APU_BTL]))
    put(B747DR_CAS_warning_status, WARN_TEST_IN_PROG, flag(out.test_in_prog))
    put(B747DR_CAS_warning_status, WARN_TEST_PASS, flag(out.test_pass))
    put(B747DR_CAS_warning_status, WARN_TEST_FAIL, flag(out.test_fail))
    -- the lower cargo compartments, the wheel well, the ducts, the smoke
    -- (FCOM p.619, p.908, p.921-923; ATA26_28 p.164, p.194, p.286)
    for c = 1, 2 do
        put(B747DR_CAS_warning_status, WARN_FIRE_CARGO[c], flag(out.cargo_fire[c]))
        put(B747DR_fire_light_cargo, c - 1, flag(out.cargo_light[c]))
        put(B747DR_CAS_status_status, STATUS_CARGO_DET + c - 1, flag(out.cargo_det_status[c]))
    end
    put(B747DR_fire_light_cargo, 2, flag(out.cargo_disch_light))
    for k = 1, 4 do
        local z = F.CARGO + k
        put(B747DR_CAS_status_status, STATUS_CARGO_LP + 2 * (k - 1), flag(out.lp_a[z]))
        put(B747DR_CAS_status_status, STATUS_CARGO_LP + 2 * (k - 1) + 1, flag(out.lp_b[z]))
        local b = F.CGO_A + k - 1
        put(B747DR_fire_cargo_ext_bottle_psi, k - 1, out.btl_psi[b])
        put(B747DR_CAS_status_status, STATUS_BTL_LOW_CARGO + k - 1, flag(out.btl_low[b]))
    end
    put(B747DR_CAS_advisory_status, ADV_CARGO_DET_AIR, flag(out.cargo_det_air))
    put(B747DR_CAS_status_status, STATUS_CARGO_DET_AIR, flag(out.cargo_det_air_status))
    put(B747DR_CAS_advisory_status, ADV_CGO_BTL_DISCH, flag(out.cgo_btl_disch))
    put(B747DR_CAS_warning_status, WARN_FIRE_WHEEL_WELL, flag(out.wheel_well_fire))
    for d = 1, 3 do put(B747DR_CAS_caution_status, CAUT_DUCT_LEAK[d], flag(out.duct_leak[d])) end
    put(B747DR_CAS_status_status, STATUS_DUCT_LEAK, flag(out.duct_leak_status[1]))
    put(B747DR_CAS_status_status, STATUS_DUCT_LEAK + 1, flag(out.duct_leak_status[2]))
    put(B747DR_CAS_caution_status, CAUT_SMOKE_REST, flag(out.rest_smoke))
    put(B747DR_CAS_advisory_status, ADV_SMOKE_LAV, flag(out.lav_smoke))
    for i = 1, 9 do put(B747DR_fire_light_squib, i - 1, flag(out.squib_light[i])) end
    -- the agent puts the cargo smoke out (estimate: like X-Plane's engine fire)
    for c = 1, 2 do
        if out.cargo_agent[c] then
            put(B747DR_fire_fail_cargo_smoke, 2 * c - 2, 0)
            put(B747DR_fire_fail_cargo_smoke, 2 * c - 1, 0)
        end
    end
end

function B747_fire()
    fire_t = fire_t + SIM_PERIOD
    squib_springs(SIM_PERIOD)
    read_inputs(fire_inputs)
    local out = F.update(fire_state, fire_inputs, SIM_PERIOD)
    clear_commands(fire_inputs)
    write_outputs(out)
end


----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_fire_monitor_AI()

    if B747DR_init_fire_CD == 1 then
        B747_set_fire_all_modes()
        B747_set_fire_CD()
        B747DR_init_fire_CD = 2
    end

end


----- SET STATE FOR ALL MODES -----------------------------------------------------------
-- full bottles, the switches in (FCOM p.105, NP.21.11)
function B747_set_fire_all_modes()

	B747DR_init_fire_CD = 0
    fire_state = F.new()
    clear_commands(fire_inputs)
    B747DR_smoke_evac_handle = 0

end


----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_fire_CD()

end


----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_fire_ER()

end


----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_fire()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_fire_all_modes()
    fire_t = 0

    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_fire_CD()

    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_fire_ER()

    end

end


--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

function flight_start()

    B747_flight_start_fire()

end

debug_fire                  = deferred_dataref("laminar/B747/debug/fire", "number")
function after_physics()
    if debug_fire > 0 then return end

    B747_fire()
    B747_fire_monitor_AI()

end
