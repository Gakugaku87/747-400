--[[
*****************************************************************************************
* Program Script Name : B747.25.fuel
* Author Name     : Jim Gregory
*
*   Revisions:
*   -- DATE --  --- REV NO ---    --- DESCRIPTION ---
*   2016-04-26  0.01a       Start of Dev
*
*
*
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED          *
*****************************************************************************************
--]]


--*************************************************************************************--
--**                        XLUA GLOBALS                           **--
--*************************************************************************************--

--[[

SIM_PERIOD - this contains the duration of the current frame in seconds (so it is alway a
fraction).  Use this to normalize rates,  e.g. to add 3 units of fuel per second in a
per-frame callback you’d do fuel = fuel + 3 * SIM_PERIOD.

--]]


--*************************************************************************************--
--**                         CONSTANTS                             **--
--*************************************************************************************--

NUM_FUEL_TOGGLE_SW = 4
simDR_inReplay              = find_dataref("sim/time/is_in_replay")
--replace create_command
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


--*************************************************************************************--
--**                      GLOBAL VARIABLES                         **--
--*************************************************************************************--
simDR_time_now						= find_dataref("sim/time/total_running_time_sec")
B747 = {}
B747.fuel = {}
-- CREATE FUEL TANK TABLES
local tankName = {"center_tank", "main1_tank", "main2_tank", "main3_tank", "main4_tank", "stab_tank", "res2_tank", "res3_tank"}
for _, tank_name in ipairs(tankName) do
    B747.fuel[tank_name] = {}
end

B747.fuel.engine1 = {}
B747.fuel.engine2 = {}
B747.fuel.engine3 = {}
B747.fuel.engine4 = {}

----- FUEL TANK PROPERTIES --------------------------------------------------------------

-- FUEL TANK CAPACITY (KILOGRAMS)
B747.fuel.center_tank.capacity      = 52167.0   -- XP Tank DR Index: 0
B747.fuel.main1_tank.capacity       = 13622.0   -- XP Tank DR Index: 1
B747.fuel.main2_tank.capacity       = 38132.0   -- XP Tank DR Index: 2
B747.fuel.main3_tank.capacity       = 38132.0   -- XP Tank DR Index: 3
B747.fuel.main4_tank.capacity       = 13622.0   -- XP Tank DR Index: 4
B747.fuel.res2_tank.capacity          =  4018.0   -- XP Tank DR Index: 5
B747.fuel.res3_tank.capacity      =  4018.0   -- XP Tank DR Index: 6
B747.fuel.stab_tank.capacity      = 10030.0   -- XP Tank DR Index: 7

-- FUEL TANK MIN LIMIT (KILOGRAMS)
B747.fuel.center_tank.min         =   0.0   -- XP Tank DR Index: 0
B747.fuel.main1_tank.min          =   0.0   -- XP Tank DR Index: 1
B747.fuel.main2_tank.min          =   0.0   -- XP Tank DR Index: 2
B747.fuel.main3_tank.min          =   0.0   -- XP Tank DR Index: 3
B747.fuel.main4_tank.min          =   0.0   -- XP Tank DR Index: 4
B747.fuel.res2_tank.min         =   0.0   -- XP Tank DR Index: 5
B747.fuel.res3_tank.min         =   0.0   -- XP Tank DR Index: 6
B747.fuel.stab_tank.min         =   0.0   -- XP Tank DR Index

-- PUMPS
B747.fuel.center_tank.ovrd_jett_pump_L  = {}
B747.fuel.center_tank.ovrd_jett_pump_R  = {}
B747.fuel.center_tank.scvg_pump_L1    = {}
B747.fuel.center_tank.scvg_pump_L2    = {}
B747.fuel.center_tank.scvg_pump_R1    = {}
B747.fuel.center_tank.scvg_pump_R2    = {}

B747.fuel.main1_tank.main_pump_fwd    = {}
B747.fuel.main1_tank.main_pump_aft    = {}

B747.fuel.main2_tank.main_pump_fwd    = {}
B747.fuel.main2_tank.main_pump_aft    = {}
B747.fuel.main2_tank.ovrd_jett_pump_fwd = {}
B747.fuel.main2_tank.ovrd_jett_pump_aft = {}
B747.fuel.main2_tank.apu_dc_pump    = {}

B747.fuel.main3_tank.main_pump_fwd    = {}
B747.fuel.main3_tank.main_pump_aft    = {}
B747.fuel.main3_tank.ovrd_jett_pump_fwd = {}
B747.fuel.main3_tank.ovrd_jett_pump_aft = {}

B747.fuel.main4_tank.main_pump_fwd    = {}
B747.fuel.main4_tank.main_pump_aft    = {}

B747.fuel.stab_tank.xfr_jett_pump_L   = {}
B747.fuel.stab_tank.xfr_jett_pump_R   = {}

    B747.fuel.center_tank.ovrd_jett_pump_L.on   = deferred_dataref("laminar/B747/fuel/center_tank/ovrd_jett_pump_L_on", "number")
    B747.fuel.center_tank.ovrd_jett_pump_R.on   = deferred_dataref("laminar/B747/fuel/center_tank/ovrd_jett_pump_R_on", "number")
    B747.fuel.center_tank.scvg_pump_L1.on     = deferred_dataref("laminar/B747/fuel/center_tank/scvg_pump_L1_on", "number")
    B747.fuel.center_tank.scvg_pump_L2.on     = deferred_dataref("laminar/B747/fuel/center_tank/scvg_pump_L2_on", "number")
    B747.fuel.center_tank.scvg_pump_R1.on     = deferred_dataref("laminar/B747/fuel/center_tank/scvg_pump_R1_on", "number")
    B747.fuel.center_tank.scvg_pump_R2.on     = deferred_dataref("laminar/B747/fuel/center_tank/scvg_pump_R2_on", "number")

    B747.fuel.main1_tank.main_pump_fwd.on     = deferred_dataref("laminar/B747/fuel/main1_tank/main_pump_fwd_on", "number")
    B747.fuel.main1_tank.main_pump_aft.on     = deferred_dataref("laminar/B747/fuel/main1_tank/main_pump_aft_on", "number")

    B747.fuel.main2_tank.main_pump_fwd.on     = deferred_dataref("laminar/B747/fuel/main2_tank/main_pump_fwd_on", "number")
    B747.fuel.main2_tank.main_pump_aft.on     = deferred_dataref("laminar/B747/fuel/main2_tank/main_pump_aft_on", "number")
    B747.fuel.main2_tank.ovrd_jett_pump_fwd.on      = deferred_dataref("laminar/B747/fuel/main2_tank/ovrd_jett_pump_fwd_on", "number")
    B747.fuel.main2_tank.ovrd_jett_pump_aft.on      = deferred_dataref("laminar/B747/fuel/main2_tank/ovrd_jett_pump_aft_on", "number")
    B747.fuel.main2_tank.apu_dc_pump.on         = deferred_dataref("laminar/B747/fuel/main2_tank/apu_dc_pump_on", "number")

    B747.fuel.main3_tank.main_pump_fwd.on     = deferred_dataref("laminar/B747/fuel/main3_tank/main_pump_fwd_on", "number")
    B747.fuel.main3_tank.main_pump_aft.on     = deferred_dataref("laminar/B747/fuel/main3_tank/main_pump_aft_on", "number")
    B747.fuel.main3_tank.ovrd_jett_pump_fwd.on      = deferred_dataref("laminar/B747/fuel/main3_tank/ovrd_jett_pump_fwd_on", "number")
    B747.fuel.main3_tank.ovrd_jett_pump_aft.on      = deferred_dataref("laminar/B747/fuel/main3_tank/ovrd_jett_pump_aft_on", "number")

    B747.fuel.main4_tank.main_pump_fwd.on     = deferred_dataref("laminar/B747/fuel/main4_tank/main_pump_fwd_on", "number")
    B747.fuel.main4_tank.main_pump_aft.on     = deferred_dataref("laminar/B747/fuel/main4_tank/main_pump_aft_on", "number")

    B747.fuel.stab_tank.xfr_jett_pump_L.on        = deferred_dataref("laminar/B747/fuel/stab_tank/xfr_jett_pump_L_on", "number")
    B747.fuel.stab_tank.xfr_jett_pump_R.on        = deferred_dataref("laminar/B747/fuel/stab_tank/xfr_jett_pump_R_on", "number")
    B747DR_engine_used_fuel               = deferred_dataref("laminar/B747/fuel/totaliser","array[5]")
-- VALVES
B747.fuel.center_tank.refuel_vlv_L    = {}
B747.fuel.center_tank.refuel_vlv_R    = {}
B747.fuel.center_tank.jett_vlv_L    = {}
B747.fuel.center_tank.jett_vlv_R    = {}
B747.fuel.center_tank.stab_xfr_vlv_L  = {}
B747.fuel.center_tank.stab_xfr_vlv_R  = {}
B747.fuel.center_tank.flow_eq_vlv   = {}

B747.fuel.main1_tank.refuel_vlv     = {}
B747.fuel.main1_tank.main_xfr_vlv   = {}

B747.fuel.main2_tank.refuel_vlv_L   = {}
B747.fuel.main2_tank.refuel_vlv_R   = {}
B747.fuel.main2_tank.jett_vlv     = {}
B747.fuel.main2_tank.apu_vlv      = {}

B747.fuel.main3_tank.refuel_vlv_L   = {}
B747.fuel.main3_tank.refuel_vlv_R   = {}
B747.fuel.main3_tank.jett_vlv     = {}

B747.fuel.main4_tank.refuel_vlv     = {}
B747.fuel.main4_tank.main_xfr_vlv   = {}

B747.fuel.stab_tank.refuel_vlv      = {}
B747.fuel.stab_tank.isolation_vlv_L   = {}
B747.fuel.stab_tank.xfr_jett_vlv_L    = {}
B747.fuel.stab_tank.isolation_vlv_R   = {}
B747.fuel.stab_tank.xfr_jett_vlv_R    = {}

B747.fuel.res2_tank.refuel_vlv      = {}
B747.fuel.res2_tank.xfr_vlv_A     = {}
B747.fuel.res2_tank.xfr_vlv_B     = {}

B747.fuel.res3_tank.refuel_vlv      = {}
B747.fuel.res3_tank.xfr_vlv_A     = {}
B747.fuel.res3_tank.xfr_vlv_B     = {}

B747.fuel.engine1.xfeed_vlv         = {}
B747.fuel.engine2.xfeed_vlv         = {}
B747.fuel.engine3.xfeed_vlv         = {}
B747.fuel.engine4.xfeed_vlv         = {}

B747.fuel.spar_vlv1           = {}
B747.fuel.spar_vlv2           = {}
B747.fuel.spar_vlv3           = {}
B747.fuel.spar_vlv4           = {}

B747.fuel.jett_nozzle_vlv_L       = {}
B747.fuel.jett_nozzle_vlv_R       = {}

    -- VALVE TARGET POS
    B747.fuel.center_tank.refuel_vlv_L.target_pos = 0
    B747.fuel.center_tank.refuel_vlv_R.target_pos = 0
    B747.fuel.center_tank.jett_vlv_L.target_pos   = 0
    B747.fuel.center_tank.jett_vlv_R.target_pos   = 0
    B747.fuel.center_tank.stab_xfr_vlv_L.target_pos = 0
    B747.fuel.center_tank.stab_xfr_vlv_R.target_pos = 0
    B747.fuel.center_tank.flow_eq_vlv.target_pos    = 0

    B747.fuel.main1_tank.refuel_vlv.target_pos    = 0
    B747.fuel.engine1.xfeed_vlv.target_pos        = 0
    B747.fuel.main1_tank.main_xfr_vlv.target_pos    = 0

    B747.fuel.main2_tank.refuel_vlv_L.target_pos  = 0
    B747.fuel.main2_tank.refuel_vlv_R.target_pos  = 0
    B747.fuel.engine2.xfeed_vlv.target_pos        = 0
    B747.fuel.main2_tank.jett_vlv.target_pos    = 0
    B747.fuel.main2_tank.apu_vlv.target_pos     = 0

    B747.fuel.main3_tank.refuel_vlv_L.target_pos  = 0
    B747.fuel.main3_tank.refuel_vlv_R.target_pos  = 0
    B747.fuel.engine3.xfeed_vlv.target_pos        = 0
    B747.fuel.main3_tank.jett_vlv.target_pos      = 0

    B747.fuel.main4_tank.refuel_vlv.target_pos    = 0
    B747.fuel.engine4.xfeed_vlv.target_pos        = 0
    B747.fuel.main4_tank.main_xfr_vlv.target_pos  = 0

    B747.fuel.stab_tank.refuel_vlv.target_pos   = 0
    B747.fuel.stab_tank.isolation_vlv_L.target_pos  = 0
    B747.fuel.stab_tank.xfr_jett_vlv_L.target_pos = 0
    B747.fuel.stab_tank.isolation_vlv_R.target_pos  = 0
    B747.fuel.stab_tank.xfr_jett_vlv_R.target_pos = 0

    B747.fuel.res2_tank.refuel_vlv.target_pos   = 0
    B747.fuel.res2_tank.xfr_vlv_A.target_pos        = 0
    B747.fuel.res2_tank.xfr_vlv_B.target_pos    = 0

    B747.fuel.res3_tank.refuel_vlv.target_pos   = 0
    B747.fuel.res3_tank.xfr_vlv_A.target_pos    = 0
    B747.fuel.res3_tank.xfr_vlv_B.target_pos    = 0

    B747.fuel.spar_vlv1.target_pos          = 0
    B747.fuel.spar_vlv2.target_pos          = 0
    B747.fuel.spar_vlv3.target_pos          = 0
    B747.fuel.spar_vlv4.target_pos          = 0

    B747.fuel.jett_nozzle_vlv_L.target_pos      = 0
    B747.fuel.jett_nozzle_vlv_R.target_pos      = 0


    -- VALVE POS
    B747.fuel.center_tank.refuel_vlv_L.pos      = deferred_dataref("laminar/B747/fuel/center_tank/refuel_vlv_L_pos", "number")
    B747.fuel.center_tank.refuel_vlv_R.pos      = deferred_dataref("laminar/B747/fuel/center_tank/refuel_vlv_R_pos", "number")
    B747.fuel.center_tank.jett_vlv_L.pos      = deferred_dataref("laminar/B747/fuel/center_tank/jett_vlv_L_pos", "number")
    B747.fuel.center_tank.jett_vlv_R.pos      = deferred_dataref("laminar/B747/fuel/center_tank/jett_vlv_R_pos", "number")
    B747.fuel.center_tank.stab_xfr_vlv_L.pos    = deferred_dataref("laminar/B747/fuel/center_tank/stab_xfr_vlv_L_pos", "number")
    B747.fuel.center_tank.stab_xfr_vlv_R.pos    = deferred_dataref("laminar/B747/fuel/center_tank/stab_xfr_vlv_R_pos", "number")
    B747.fuel.center_tank.flow_eq_vlv.pos     = deferred_dataref("laminar/B747/fuel/center_tank/flow_eq_vlv_pos", "number")

    B747.fuel.main1_tank.refuel_vlv.pos       = deferred_dataref("laminar/B747/fuel/main1_tank/refuel_vlv_pos", "number")
    B747.fuel.main1_tank.main_xfr_vlv.pos     = deferred_dataref("laminar/B747/fuel/main1_tank/main_xfr_vlv_pos", "number")

    B747.fuel.main2_tank.refuel_vlv_L.pos     = deferred_dataref("laminar/B747/fuel/main2_tank/refuel_vlv_L_pos", "number")
    B747.fuel.main2_tank.refuel_vlv_R.pos     = deferred_dataref("laminar/B747/fuel/main2_tank/refuel_vlv_R_pos", "number")
    B747.fuel.main2_tank.jett_vlv.pos       = deferred_dataref("laminar/B747/fuel/main2_tank/jett_vlv_pos", "number")
    B747.fuel.main2_tank.apu_vlv.pos        = deferred_dataref("laminar/B747/fuel/main2_tank/apu_vlv_pos", "number")

    B747.fuel.main3_tank.refuel_vlv_L.pos     = deferred_dataref("laminar/B747/fuel/main3_tank/refuel_vlv_L_pos", "number")
    B747.fuel.main3_tank.refuel_vlv_R.pos     = deferred_dataref("laminar/B747/fuel/main3_tank/refuel_vlv_R_pos", "number")
    B747.fuel.main3_tank.jett_vlv.pos       = deferred_dataref("laminar/B747/fuel/main3_tank/jett_vlv_pos", "number")

    B747.fuel.main4_tank.refuel_vlv.pos         = deferred_dataref("laminar/B747/fuel/main4_tank/refuel_vlv_pos", "number")
    B747.fuel.main4_tank.main_xfr_vlv.pos     = deferred_dataref("laminar/B747/fuel/main4_tank/main_xfr_vlv_pos", "number")

    B747.fuel.stab_tank.refuel_vlv.pos        = deferred_dataref("laminar/B747/fuel/stab_tank/refuel_vlv_pos", "number")
    B747.fuel.stab_tank.isolation_vlv_L.pos     = deferred_dataref("laminar/B747/fuel/stab_tank/isolation_vlv_L_pos", "number")
    B747.fuel.stab_tank.xfr_jett_vlv_L.pos      = deferred_dataref("laminar/B747/fuel/stab_tank/xfr_jett_vlv_L_pos", "number")
    B747.fuel.stab_tank.isolation_vlv_R.pos     = deferred_dataref("laminar/B747/fuel/stab_tank/isolation_vlv_R_pos", "number")
    B747.fuel.stab_tank.xfr_jett_vlv_R.pos      = deferred_dataref("laminar/B747/fuel/stab_tank/xfr_jett_vlv_R_pos", "number")

    B747.fuel.res2_tank.refuel_vlv.pos        = deferred_dataref("laminar/B747/fuel/res2_tank/refuel_vlv_pos", "number")
    B747.fuel.res2_tank.xfr_vlv_A.pos       = deferred_dataref("laminar/B747/fuel/res2_tank/xfr_vlv_A_pos", "number")
    B747.fuel.res2_tank.xfr_vlv_B.pos       = deferred_dataref("laminar/B747/fuel/res2_tank/xfr_vlv_B_pos", "number")

    B747.fuel.res3_tank.refuel_vlv.pos        = deferred_dataref("laminar/B747/fuel/res3_tank/refuel_vlv_pos", "number")
    B747.fuel.res3_tank.xfr_vlv_A.pos       = deferred_dataref("laminar/B747/fuel/res3_tank/xfr_vlv_A_pos", "number")
    B747.fuel.res3_tank.xfr_vlv_B.pos       = deferred_dataref("laminar/B747/fuel/res3_tank/xfr_vlv_B_pos", "number")

    B747.fuel.engine1.xfeed_vlv.pos           = deferred_dataref("laminar/B747/fuel/engine1/xfeed_vlv_pos", "number")
    B747.fuel.engine2.xfeed_vlv.pos           = deferred_dataref("laminar/B747/fuel/engine2/xfeed_vlv_pos", "number")
    B747.fuel.engine3.xfeed_vlv.pos           = deferred_dataref("laminar/B747/fuel/engine3/xfeed_vlv_pos", "number")
    B747.fuel.engine4.xfeed_vlv.pos           = deferred_dataref("laminar/B747/fuel/engine4/xfeed_vlv_pos", "number")

    B747.fuel.spar_vlv1.pos             = deferred_dataref("laminar/B747/fuel/spar_vlv1_pos", "number")
    B747.fuel.spar_vlv2.pos             = deferred_dataref("laminar/B747/fuel/spar_vlv2_pos", "number")
    B747.fuel.spar_vlv3.pos               = deferred_dataref("laminar/B747/fuel/spar_vlv3_pos", "number")
    B747.fuel.spar_vlv4.pos               = deferred_dataref("laminar/B747/fuel/spar_vlv4_pos", "number")

    B747.fuel.jett_nozzle_vlv_L.pos         = deferred_dataref("laminar/B747/fuel/jett_nozzle_vlv_L_pos", "number")
    B747.fuel.jett_nozzle_vlv_R.pos         = deferred_dataref("laminar/B747/fuel/jett_nozzle_vlv_R_pos", "number")



--*************************************************************************************--
--**                      LOCAL VARIABLES                          **--
--*************************************************************************************--

B747_fuel_control_toggle_sw_pos_target = deferred_dataref("laminar/B747/fuel/switch_target", "array[4]")--{}




--*************************************************************************************--
--**                        X-PLANE DATAREFS                         **--
--*************************************************************************************--

simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")

simDR_override_fuel_system          = find_dataref("sim/operation/override/override_fuel_system")

simDR_flap_deploy_ratio             = find_dataref("laminar/B747/cablecontrols/flap_ratio")
simDR_all_wheels_on_ground          = find_dataref("sim/flightmodel/failures/onground_any")
simDR_TAT                           = find_dataref("sim/cockpit2/temperature/outside_air_LE_temp_degc")

simDR_eng_fuel_flow_kg_sec          = find_dataref("sim/cockpit2/engine/indicators/fuel_flow_kg_sec")
simDR_fuel_tank_weight_kg           = find_dataref("sim/flightmodel/weight/m_fuel")  -- kgs
-- 0 = center_tank
-- 1 = main1_tank
-- 2 = main2_tank
-- 3 = main3_tank
-- 4 = main4_tank
-- 5 = res2_tank
-- 6 = res3_tank
-- 7 = stab_tank

simDR_fueL_tank_weight_total_kg     = find_dataref("sim/flightmodel/weight/m_fuel_total")  -- kgs
simDR_engine_has_fuel               = find_dataref("sim/flightmodel2/engines/has_fuel_flow_before_mixture")

simDR_fuel_filter_block_01          = find_dataref("sim/operation/failures/rel_fuel_block0")
simDR_fuel_filter_block_02          = find_dataref("sim/operation/failures/rel_fuel_block1")
simDR_fuel_filter_block_03          = find_dataref("sim/operation/failures/rel_fuel_block2")
simDR_fuel_filter_block_04          = find_dataref("sim/operation/failures/rel_fuel_block3")

simDR_fuel_totalizer_kg       = find_dataref("sim/cockpit2/fuel/fuel_totalizer_init_kg")


--*************************************************************************************--
--**                      FIND CUSTOM DATAREFS                         **--
--*************************************************************************************--

B747DR_button_switch_position       = find_dataref("laminar/B747/button_switch/position")
--[[
  
BUTTON SWITCH INDEXES:

    misc_fuel_xfr_1_4           = 43
    fuel_jet_nozzle_vlv_L       = 46
    fuel_jet_nozzle_vlv_R       = 47
    fuel_xfeed_vlv_1            = 48
    fuel_xfeed_vlv_2            = 49
    fuel_xfeed_vlv_3            = 50
    fuel_xfeed_vlv_4            = 51
    fuel_ctr_wing_tnk_pump_L    = 52
    fuel_ctr_wing_tnk_pump_R    = 53
    fuel_stab_tnk_pump_L        = 54
    fuel_stab_tnk_pump_R        = 55
    fuel_main_pump_fwd_1        = 56
    fuel_main_pump_fwd_2        = 57
    fuel_main_pump_fwd_3        = 58
    fuel_main_pump_fwd_4        = 59
    fuel_main_pump_aft_1        = 60
    fuel_main_pump_aft_2        = 61
    fuel_main_pump_aft_3        = 62
    fuel_main_pump_aft_4        = 63
    fuel_overd_pump_fwd_2       = 64
    fuel_overd_pump_fwd_3       = 65
    fuel_overd_pump_aft_2       = 66
    fuel_overd_pump_aft_3       = 67

--]]

B747DR_engine_fuel_valve_pos        = find_dataref("laminar/B747/engines/fuel_valve_pos")

--B747DR_CAS_warning_status           = find_dataref("laminar/B747/CAS/warning_status")
B747DR_CAS_caution_status           = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")



--*************************************************************************************--
--**                CREATE READ-ONLY CUSTOM DATAREFS                         **--
--*************************************************************************************--

B747DR_fuel_jettison_sel_dial_pos       = deferred_dataref("laminar/B747/fuel/fuel_jettison/sel_dial_pos", "number")
B747DR_fuel_control_toggle_switch_pos   = deferred_dataref("laminar/B747/fuel/fuel_control/toggle_sw_pos", "array[4]")

B747DR_stab_fuel_pump_press_low_L       = deferred_dataref("laminar/B747/fuel/stab_pump_L/pressure_low", "number")
B747DR_stab_fuel_pump_press_low_R       = deferred_dataref("laminar/B747/fuel/stab_pump_R/pressure_low", "number")

B747DR_stab_xfr_status                  = deferred_dataref("laminar/B747/fuel/stab_xfr_status", "number")
B747DR_res2_xfr_status                  = deferred_dataref("laminar/B747/fuel/res2_xfr_status", "number")
B747DR_res3_xfr_status                  = deferred_dataref("laminar/B747/fuel/res3_xfr_status", "number")
B747DR_ctr_scvg_L_status                = deferred_dataref("laminar/B747/fuel/ctr_scvg_L_status", "number")
B747DR_ctr_scvg_R_status                = deferred_dataref("laminar/B747/fuel/ctr_scvg_R_status", "number")

B747DR_fuel_temperature                 = deferred_dataref("laminar/B747/fuel/temperature", "number")

B747DR_jett_time                        = deferred_dataref("laminar/B747/fuel/jettison_time", "number")


B747DR_gen_fuel_XFmfld_status           = deferred_dataref("laminar/B747/fuel/gen_XFmfld_status", "number")

B747DR_gen_fuel_engine1_status          = deferred_dataref("laminar/B747/fuel/engine1_status", "number")
B747DR_gen_fuel_engine2_status          = deferred_dataref("laminar/B747/fuel/engine2_status", "number")
B747DR_gen_fuel_engine3_status          = deferred_dataref("laminar/B747/fuel/engine3_status", "number")
B747DR_gen_fuel_engine4_status          = deferred_dataref("laminar/B747/fuel/engine4_status", "number")

B747DR_gen_fuel_OJpump2_status          = deferred_dataref("laminar/B747/fuel/oj_pump2_status", "number")
B747DR_gen_fuel_OJpump3_status          = deferred_dataref("laminar/B747/fuel/oj_pump3_status", "number")

B747DR_gen_jett_valve_status            = deferred_dataref("laminar/B747/fuel/jett_vlv_status", "number")
B747DR_gen_jett_OJctrL_status           = deferred_dataref("laminar/B747/fuel/jett/OJctrL_status", "number")
B747DR_gen_jett_OJctrR_status           = deferred_dataref("laminar/B747/fuel/jett/OJctrR_status", "number")
B747DR_gen_jett_OJmain2_status          = deferred_dataref("laminar/B747/fuel/jett/OJmain2_status", "number")
B747DR_gen_jett_OJmain3_status          = deferred_dataref("laminar/B747/fuel/jett/OJmain3_status", "number")
B747DR_gen_jett_OJstab_status           = deferred_dataref("laminar/B747/fuel/jett/OJstab_status", "number")
B747DR_gen_jett_mfldL1_status           = deferred_dataref("laminar/B747/fuel/jett/mfldL1_status", "number")
B747DR_gen_jett_mfldL2_status           = deferred_dataref("laminar/B747/fuel/jett/mfldL2_status", "number")
B747DR_gen_jett_mfldL3_status           = deferred_dataref("laminar/B747/fuel/jett/mfldL3_status", "number")
B747DR_gen_jett_mfldR1_status           = deferred_dataref("laminar/B747/fuel/jett/mfldR1_status", "number")
B747DR_gen_jett_mfldR2_status           = deferred_dataref("laminar/B747/fuel/jett/mfldR2_status", "number")
B747DR_gen_jett_mfldR3_status           = deferred_dataref("laminar/B747/fuel/jett/mfldR3_status", "number")
B747DR_gen_jett_Xmfld_status            = deferred_dataref("laminar/B747/fuel/jett/mXmfld_status", "number")

B747DR_gen_xfeed_vlv1_status            = deferred_dataref("laminar/B747/fuel/gen/xfeed_vlv1_status", "number")
B747DR_gen_xfeed_vlv2_status            = deferred_dataref("laminar/B747/fuel/gen/xfeed_vlv2_status", "number")
B747DR_gen_xfeed_vlv3_status            = deferred_dataref("laminar/B747/fuel/gen/xfeed_vlv3_status", "number")
B747DR_gen_xfeed_vlv4_status            = deferred_dataref("laminar/B747/fuel/gen/xfeed_vlv4_status", "number")
B747DR_refuel             = deferred_dataref("laminar/B747/fuel/refuel", "number")
B747DR_fuel_preselect         = deferred_dataref("laminar/B747/fuel/preselect", "number")
B747DR_fuel_add             = deferred_dataref("laminar/B747/fuel/add_fuel", "number")
B747DR_init_fuel_CD                     = deferred_dataref("laminar/B747/fuel/init_CD", "number")


--*************************************************************************************--
--**               READ-WRITE CUSTOM DATAREF HANDLERS                      **--
--*************************************************************************************--

-- FUEL TO REMAIN
function B747DR_fuel_to_remain_rheo_DRhandler()
    print("DR handler")


end


--*************************************************************************************--
--**               CREATE READ-WRITE CUSTOM DATAREFS                         **--
--*************************************************************************************--

-- FUEL TO REMAIN
B747DR_fuel_to_remain_rheo      = deferred_dataref("laminar/B747/fuel/fuel_to_remain/rheostat", "number", B747DR_fuel_to_remain_rheo_DRhandler)

-- FUEL TANK WEIGHT DISPLAY QTY (8 TANKS)
B747DR_fuel_tank_display_qty      = deferred_dataref("laminar/B747/fuel/fuel_tank_display_qty", "array[8]")

-- FUEL TOTAL WEIGHT DISPLAY QTY
B747DR_fuel_total_display_qty     = deferred_dataref("laminar/B747/fuel/fuel_total_display_qty", "number")

-- FUEL FLOW PER SECOND
B747DR_fuel_flow_sec_display      = deferred_dataref("laminar/B747/fuel/fuel_flow_sec_display", "array[4]")

-- FUEL DISPLAY TOGGLE (EICAS)
B747DR_fuel_display_units_eicas     = deferred_dataref("laminar/B747/fuel/fuel_display_units_eicas", "number")

-- Temp location for fuel preselect for displaying in correct units
B747DR_fuel_preselect_temp        = deferred_dataref("laminar/B747/fuel/fuel_preselect_temp", "number")

-- Holds all SimConfig options
B747DR_simconfig_data         = deferred_dataref("laminar/B747/simconfig", "string")
B747DR_newsimconfig_data				= deferred_dataref("laminar/B747/newsimconfig", "number")

--*************************************************************************************--
--**                     X-PLANE COMMAND HANDLERS                        **--
--*************************************************************************************--



--*************************************************************************************--
--**                         X-PLANE COMMANDS                            **--
--*************************************************************************************--



--*************************************************************************************--
--**                      CUSTOM COMMAND HANDLERS                      **--
--*************************************************************************************--

-- AUTO IGNITION
function B747_fuel_jettison_sel_up_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_fuel_jettison_sel_dial_pos = math.min(B747DR_fuel_jettison_sel_dial_pos+1, 2)
    end
end
function B747_fuel_jettison_sel_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_fuel_jettison_sel_dial_pos = math.max(B747DR_fuel_jettison_sel_dial_pos-1, 0)
    end
end





-- TQ FUEL CONTROL SWITCHES
B747DR_dsp_synoptic_display                     = find_dataref("laminar/B747/dsp/synoptic_display")

-- a FUEL CONTROL switch moved; to CUTOFF in flight it brings up the
-- secondary engine display (FCOM p.843, p.872; it used to come up at every
-- move, RUN or CUTOFF, on the ground too: ENG-23)
local function B747_fuel_control_toggle(i)
    local target = 1.0 - B747_fuel_control_toggle_sw_pos_target[i]
    B747_fuel_control_toggle_sw_pos_target[i] = target
    if target < 0.5 and B747DR_pseu_pri_air == 1 then
        B747DR_dsp_synoptic_display = 1
    end
end

function B747_fuel_control_switch1_CMDhandler(phase, duration)
    if phase == 0 then B747_fuel_control_toggle(0) end
end

function B747_fuel_control_switch2_CMDhandler(phase, duration)
    if phase == 0 then B747_fuel_control_toggle(1) end
end

function B747_fuel_control_switch3_CMDhandler(phase, duration)
    if phase == 0 then B747_fuel_control_toggle(2) end
end

function B747_fuel_control_switch4_CMDhandler(phase, duration)
    if phase == 0 then B747_fuel_control_toggle(3) end
end




function B747_ai_fuek_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
    B747_set_fuel_all_modes() 
    B747_set_fuel_CD()
    B747_set_fuel_ER()  
  end   
end 



--*************************************************************************************--
--**                      CREATE CUSTOM COMMANDS                         **--
--*************************************************************************************--

-- FUEL JETTISON SELECTOR
B747CMD_fuel_jettison_sel_up  = deferred_command("laminar/B747/fuel/fuel_jett/el_dial_up", "Fuel Jettison Selector Dial Up", B747_fuel_jettison_sel_up_CMDhandler)
B747CMD_fuel_jettison_sel_dn  = deferred_command("laminar/B747/fuel/fuel_jett/sel_dial_dn", "Fuel Jettison Selector Dial Down", B747_fuel_jettison_sel_dn_CMDhandler)



-- TQ FUEL CONTROL SWITCHES
B747CMD_fuel_control_switch1  = deferred_command("laminar/B747/fuel/fuel_control_1/toggle_switch", "Fuel Control Switch 1", B747_fuel_control_switch1_CMDhandler)
B747CMD_fuel_control_switch2  = deferred_command("laminar/B747/fuel/fuel_control_2/toggle_switch", "Fuel Control Switch 2", B747_fuel_control_switch2_CMDhandler)
B747CMD_fuel_control_switch3  = deferred_command("laminar/B747/fuel/fuel_control_3/toggle_switch", "Fuel Control Switch 3", B747_fuel_control_switch3_CMDhandler)
B747CMD_fuel_control_switch4  = deferred_command("laminar/B747/fuel/fuel_control_4/toggle_switch", "Fuel Control Switch 4", B747_fuel_control_switch4_CMDhandler)


-- AI
B747CMD_ai_fuel_quick_start   = deferred_command("laminar/B747/ai/fuel_quick_start", "number", B747_ai_fuek_quick_start_CMDhandler)



--*************************************************************************************--
--**                      OBJECT CONSTRUCTORS                      **--
--*************************************************************************************--



--*************************************************************************************--
--**                       CREATE SYSTEM OBJECTS                     **--
--*************************************************************************************--



--*************************************************************************************--
--**                          SYSTEM FUNCTIONS                       **--
--*************************************************************************************--

----- TERNARY CONDITIONAL ---------------------------------------------------------------
function B747_ternary(condition, ifTrue, ifFalse)
    if condition then return ifTrue else return ifFalse end
end





----- ANIMATION UNILITY -----------------------------------------------------------------
function B747_set_anim_value(current_value, target, min, max, speed)

    local fps_factor = math.min(1.0, speed * SIM_PERIOD)

    if target >= (max - 0.001) and current_value >= (max - 0.01) then
        return max
    elseif target <= (min + 0.001) and current_value <= (min + 0.01) then
       return min
    else
        return current_value + ((target - current_value) * fps_factor)
    end

end





----- TOGGLE SWITCH POSITION ANIMATION --------------------------------------------------
function B747_fuel_toggle_switch_animation()

    for i = 0, NUM_FUEL_TOGGLE_SW-1 do

        B747DR_fuel_control_toggle_switch_pos[i] = B747_set_anim_value(B747DR_fuel_control_toggle_switch_pos[i], B747_fuel_control_toggle_sw_pos_target[i], 0.0, 1.0, 20.0)
    end

end

----- FUEL TEMPERATURE ------------------------------------------------------------------
local B747_fuel_temp_init_flag = 0

function B747_init_fuel_temp()
    B747DR_fuel_temperature = simDR_TAT
    B747_fuel_temp_init_flag = 1
end

function B747_fuel_temp()

    if B747_fuel_temp_init_flag == 0 then
        if is_timer_scheduled(B747_init_fuel_temp) == false then
            run_after_time(B747_init_fuel_temp, 1.0)
        end
    else
        B747DR_fuel_temperature = B747_set_anim_value(B747DR_fuel_temperature, simDR_TAT, -47.0, 99.0, 0.0001)
    end

end







----- SYNOPTIC - FUEL TRANSFER ----------------------------------------------------------
function B747_fuel_xfr_synoptic()

    -- STAB TO CENTER TRANSFER
    
    if (B747.fuel.stab_tank.xfr_jett_pump_L.on == 1 or B747.fuel.stab_tank.xfr_jett_pump_R.on == 1)
        and
        (B747.fuel.center_tank.stab_xfr_vlv_L.pos > 0.05 or B747.fuel.center_tank.stab_xfr_vlv_R.pos > 0.05)
    then
        B747DR_stab_xfr_status = 1
        if simDR_fuel_tank_weight_kg[7] > 0.0 then
            B747DR_stab_xfr_status = 2
        end
    else
        B747DR_stab_xfr_status = 0
    end


    -- RES2 TO MAIN2 TRANSFER
    
    if B747.fuel.res2_tank.xfr_vlv_A.pos > 0.05 or B747.fuel.res2_tank.xfr_vlv_B.pos > 0.05 then
         B747DR_res2_xfr_status = 1
         if simDR_fuel_tank_weight_kg[5] > 0.0 then
            B747DR_res2_xfr_status = 2
         end
    else
        B747DR_res2_xfr_status = 0
    end


    -- RES3 TO MAIN3 TRANSFER
    
    if B747.fuel.res3_tank.xfr_vlv_A.pos > 0.05 or B747.fuel.res3_tank.xfr_vlv_B.pos > 0.05 then
         B747DR_res3_xfr_status = 1
         if simDR_fuel_tank_weight_kg[6] > 0.0 then
            B747DR_res3_xfr_status = 2
         end
    else
        B747DR_res3_xfr_status = 0
    end


    -- CENTER TO MAIN 2
    
    if B747.fuel.center_tank.scvg_pump_L1.on == 1 or B747.fuel.center_tank.scvg_pump_L2.on == 1 then
        B747DR_ctr_scvg_L_status = 1
        if simDR_fuel_tank_weight_kg[0] > 0.0 then
            B747DR_ctr_scvg_L_status = 2
        end
    else
        B747DR_ctr_scvg_L_status = 0
    end

    -- CENTER TO MAIN 3
    
    if B747.fuel.center_tank.scvg_pump_R1.on == 1 or B747.fuel.center_tank.scvg_pump_R2.on == 1 then
        B747DR_ctr_scvg_R_status = 1
        if simDR_fuel_tank_weight_kg[0] > 0.0 then
            B747DR_ctr_scvg_R_status = 2
        end
    else
        B747DR_ctr_scvg_R_status = 0    
    end

end





----- SYNOPTIC - FUEL JETTISON ----------------------------------------------------------
function B747_fuel_jett_synoptic()

    -- CENTER OJ
    
    if B747.fuel.center_tank.ovrd_jett_pump_L.on == 1
        and B747DR_gen_jett_valve_status == 1
    then
        B747DR_gen_jett_OJctrL_status = 1
    else
        B747DR_gen_jett_OJctrL_status = 0
    end

    
    if B747.fuel.center_tank.ovrd_jett_pump_R.on == 1
        and B747DR_gen_jett_valve_status == 1
    then
        B747DR_gen_jett_OJctrR_status = 1
    else
        B747DR_gen_jett_OJctrR_status = 0
    end

    -- MAIN2 OJ
    
    if (B747.fuel.main2_tank.ovrd_jett_pump_fwd.on == 1 or B747.fuel.main2_tank.ovrd_jett_pump_aft.on == 1)
        and B747DR_gen_jett_valve_status == 1
    then
        B747DR_gen_jett_OJmain2_status = 1
    else
        B747DR_gen_jett_OJmain2_status = 0
    end

     -- MAIN3 OJ
    
    if (B747.fuel.main3_tank.ovrd_jett_pump_fwd.on == 1 or B747.fuel.main3_tank.ovrd_jett_pump_aft.on == 1)
        and B747DR_gen_jett_valve_status == 1
    then
        B747DR_gen_jett_OJmain3_status = 1
    else
        B747DR_gen_jett_OJmain3_status = 0
    end

    -- STABILIZER
    
    if (B747.fuel.stab_tank.xfr_jett_pump_L.on == 1 or B747.fuel.stab_tank.xfr_jett_pump_R.on == 1)
        and B747DR_gen_jett_valve_status == 1
    then
        B747DR_gen_jett_OJstab_status = 1
    else
        B747DR_gen_jett_OJstab_status = 0
    end




    -- MANIFOLD 1 LEFT
    
    if B747DR_gen_jett_OJctrL_status == 1
        or B747DR_gen_jett_OJmain2_status == 1
    then
        B747DR_gen_jett_mfldL1_status = 1
    else
        B747DR_gen_jett_mfldL1_status = 0
    end

    -- MANIFOLD 2LEFT
    
    if B747DR_gen_jett_OJctrL_status == 1
        or B747DR_gen_jett_OJctrR_status == 1
        or B747DR_gen_jett_OJmain2_status == 1
        or B747DR_gen_jett_OJmain3_status == 1
        or B747DR_gen_jett_OJstab_status == 1
    then
        B747DR_gen_jett_mfldL2_status = 1
    else
        B747DR_gen_jett_mfldL2_status = 0
    end

    -- MANIFOLD 3 LEFT
    
    if B747DR_gen_jett_mfldL2_status == 1 or B747DR_gen_jett_Xmfld_status == 1
    then
        B747DR_gen_jett_mfldL3_status = 1
    else
        B747DR_gen_jett_mfldL3_status = 0
    end

    -- MANIFOLD 1 RIGHT
    
    if B747DR_gen_jett_OJctrR_status == 1
        or B747DR_gen_jett_OJmain3_status == 1
    then
        B747DR_gen_jett_mfldR1_status = 1
    else
        B747DR_gen_jett_mfldR1_status = 0
    end

     -- MANIFOLD 2 RIGHT
    
    if B747DR_gen_jett_OJctrL_status == 1
        or B747DR_gen_jett_OJctrR_status == 1
        or B747DR_gen_jett_OJmain2_status == 1
        or B747DR_gen_jett_OJmain3_status == 1
        or B747DR_gen_jett_OJstab_status == 1
    then
        B747DR_gen_jett_mfldR2_status = 1
    else
        B747DR_gen_jett_mfldR2_status = 0
    end

    -- MANIFOLD 3 RIGHT
    
    if B747DR_gen_jett_mfldR2_status == 1 or B747DR_gen_jett_Xmfld_status == 1
    then
        B747DR_gen_jett_mfldR3_status = 1
    else
        B747DR_gen_jett_mfldR3_status = 0
    end

    -- CROSS MANIFOLD
    
    if B747DR_gen_jett_mfldL2_status == 1
        or B747DR_gen_jett_mfldR2_status == 1
        or B747DR_gen_jett_OJstab_status == 1
    then
        B747DR_gen_jett_Xmfld_status = 1
    else
        B747DR_gen_jett_Xmfld_status = 0
    end

end







----- SYNOPTIC - FUEL STANDARD -----------------------------------------------------------
function B747_fuel_std_synoptic()

    -- CROSSFEED MANIFOLD
    B747DR_gen_fuel_XFmfld_status = B747_ternary(
        B747.fuel.main2_tank.ovrd_jett_pump_fwd.on == 1 or
        B747.fuel.main2_tank.ovrd_jett_pump_aft.on == 1 or
        B747.fuel.center_tank.ovrd_jett_pump_L.on == 1 or
        B747.fuel.center_tank.ovrd_jett_pump_R.on == 1 or
        B747.fuel.main3_tank.ovrd_jett_pump_fwd.on == 1 or
        B747.fuel.main3_tank.ovrd_jett_pump_aft.on == 1
        , 1, 0)


    -- OJ PUMP(S) 2
    
    if B747.fuel.main2_tank.ovrd_jett_pump_fwd.on == 1 or B747.fuel.main2_tank.ovrd_jett_pump_aft.on == 1 then
        B747DR_gen_fuel_OJpump2_status = 1
    else
      B747DR_gen_fuel_OJpump2_status = 0
    end

    -- OJ PUMP(S) 3
    
    if B747.fuel.main3_tank.ovrd_jett_pump_fwd.on == 1 or B747.fuel.main3_tank.ovrd_jett_pump_aft.on == 1 then
        B747DR_gen_fuel_OJpump3_status = 1
    else
      B747DR_gen_fuel_OJpump3_status = 0
    end



    ----- XFEED VALVES ------------------------------------------------------------------

    -- VALVE 1 COMMANDED OPEN
    if B747.fuel.engine1.xfeed_vlv.target_pos == 1.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine1.xfeed_vlv.pos < 0.99 then
            B747DR_gen_xfeed_vlv1_status = 0                                -- TRANSITION TO OPEN
        else
            B747DR_gen_xfeed_vlv1_status = 1                                -- OPEN
        end

    -- VALVE 1 COMMANDED CLOSED
    elseif B747.fuel.engine1.xfeed_vlv.target_pos == 0.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine1.xfeed_vlv.pos > 0.01 then
            B747DR_gen_xfeed_vlv1_status = 2                                -- TRANSITION TO CLOSED
        else
            B747DR_gen_xfeed_vlv1_status = 3                                -- CLOSED
        end
    end


    -- VALVE 2 COMMANDED OPEN
    if B747.fuel.engine2.xfeed_vlv.target_pos == 1.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine2.xfeed_vlv.pos < 0.99 then
            B747DR_gen_xfeed_vlv2_status = 0                                -- TRANSITION TO OPEN
        else
            B747DR_gen_xfeed_vlv2_status = 1                                -- OPEN
        end

    -- VALVE 2 COMMANDED CLOSED
    elseif B747.fuel.engine2.xfeed_vlv.target_pos == 0.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine2.xfeed_vlv.pos > 0.01 then
            B747DR_gen_xfeed_vlv2_status = 2                                -- TRANSITION TO CLOSED
        else
            B747DR_gen_xfeed_vlv2_status = 3                                -- CLOSED
        end
    end


    -- VALVE 3 COMMANDED OPEN
    if B747.fuel.engine3.xfeed_vlv.target_pos == 1.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine3.xfeed_vlv.pos < 0.99 then
            B747DR_gen_xfeed_vlv3_status = 0                                -- TRANSITION TO OPEN
        else
            B747DR_gen_xfeed_vlv3_status = 1                                -- OPEN
        end

    -- VALVE 3 COMMANDED CLOSED
    elseif B747.fuel.engine3.xfeed_vlv.target_pos == 0.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine3.xfeed_vlv.pos > 0.01 then
            B747DR_gen_xfeed_vlv3_status = 2                                -- TRANSITION TO CLOSED
        else
            B747DR_gen_xfeed_vlv3_status = 3                                -- CLOSED
        end
    end


    -- VALVE 4 COMMANDED OPEN
    if B747.fuel.engine4.xfeed_vlv.target_pos == 1.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine4.xfeed_vlv.pos < 0.99 then
            B747DR_gen_xfeed_vlv4_status = 0                                -- TRANSITION TO OPEN
        else
            B747DR_gen_xfeed_vlv4_status = 1                                -- OPEN
        end

    -- VALVE 4 COMMANDED CLOSED
    elseif B747.fuel.engine4.xfeed_vlv.target_pos == 0.0 then
        -- POSITION DISAGREE
        if B747.fuel.engine4.xfeed_vlv.pos > 0.01 then
            B747DR_gen_xfeed_vlv4_status = 2                                -- TRANSITION TO CLOSED
        else
            B747DR_gen_xfeed_vlv4_status = 3                                -- CLOSED
        end
    end


end

-- :: ****************************************************************************************
-- :: B744 Tank Manager for Sparky 744 and Default 747-400
-- :: by Garen Evans (@giwiganz) garen.evans@gmail.com
-- :: https://discord.com/channels/713625220568842260/713625220568842263/844535310745731112
-- :: 
-- :: Automaticallly toggles override and crossfeed tanks.
-- :: Exclusively for B744 ICAO
-- ::
-- :: Version 1.0 - February 12, 2021 (initial release)
-- :: Version 1.0.1 - February 23, 2024 (mSparks converted and incorporated to XTLua)
-- ::
-- :: 
-- :: ****************************************************************************************
B747CMD_fuel_overd_pump_fwd_2       = find_command("laminar/B747/button_switch/fuel_overd_pump_fwd_2")
B747CMD_fuel_overd_pump_fwd_3       = find_command("laminar/B747/button_switch/fuel_overd_pump_fwd_3")
B747CMD_fuel_overd_pump_aft_2       = find_command("laminar/B747/button_switch/fuel_overd_pump_aft_2")
B747CMD_fuel_overd_pump_aft_3       = find_command("laminar/B747/button_switch/fuel_overd_pump_aft_3")
B747CMD_fuel_xfeed_vlv_1            = find_command("laminar/B747/button_switch/fuel_xfeed_vlv_1")
B747CMD_fuel_xfeed_vlv_4            = find_command("laminar/B747/button_switch/fuel_xfeed_vlv_4")

function ToggleCrossFeedsOverrides()
    B747CMD_fuel_overd_pump_fwd_2:once()
    B747CMD_fuel_overd_pump_fwd_3:once()
    B747CMD_fuel_overd_pump_aft_2:once()
    B747CMD_fuel_overd_pump_aft_3:once()
    B747CMD_fuel_xfeed_vlv_1:once()
    B747CMD_fuel_xfeed_vlv_4:once()
end
local lastFuelHelper=0
function tank_helper()
    --if simDR_all_wheels_on_ground == 1 then return end
    local diff=simDR_time_now-lastFuelHelper
    if diff<1 then return end
    lastFuelHelper=simDR_time_now
    local needsTankEng=false

    if ((simDR_fuel_tank_weight_kg[2] <= simDR_fuel_tank_weight_kg[1]) and (simDR_fuel_tank_weight_kg[3] <= simDR_fuel_tank_weight_kg[4]))
        then
        needsTankEng=true
    end

    --if needsTankEng and fuel_tankToEngine==1 then return end
    --if not needsTankEng and fuel_tankToEngine==0 then return end
    
    if needsTankEng then
        if B747DR_button_switch_position[64] > 0.95 then B747CMD_fuel_overd_pump_fwd_2:once() return end
        if B747DR_button_switch_position[65] > 0.95 then B747CMD_fuel_overd_pump_fwd_3:once() return end
        if B747DR_button_switch_position[66] > 0.95 then B747CMD_fuel_overd_pump_aft_2:once() return end
        if B747DR_button_switch_position[67] > 0.95 then B747CMD_fuel_overd_pump_aft_3:once() return end  
        if B747DR_button_switch_position[48] > 0.95 then B747CMD_fuel_xfeed_vlv_1:once() return end
        if B747DR_button_switch_position[51] > 0.95 then B747CMD_fuel_xfeed_vlv_4:once() return end
    else
        if B747DR_button_switch_position[64] < 0.05 then B747CMD_fuel_overd_pump_fwd_2:once() return end
        if B747DR_button_switch_position[65] < 0.05 then B747CMD_fuel_overd_pump_fwd_3:once() return end
        if B747DR_button_switch_position[66] < 0.05 then B747CMD_fuel_overd_pump_aft_2:once() return end
        if B747DR_button_switch_position[67] < 0.05 then B747CMD_fuel_overd_pump_aft_3:once() return end
        if B747DR_button_switch_position[48] < 0.05 then B747CMD_fuel_xfeed_vlv_1:once() return end
        if B747DR_button_switch_position[51] < 0.05 then B747CMD_fuel_xfeed_vlv_4:once() return end
        
    end
    --[[fob = simDR_fuel_tank_weight_kg[0] + simDR_fuel_tank_weight_kg[1] + simDR_fuel_tank_weight_kg[2] + simDR_fuel_tank_weight_kg[3] + simDR_fuel_tank_weight_kg[4] + simDR_fuel_tank_weight_kg[5] + simDR_fuel_tank_weight_kg[6] + simDR_fuel_tank_weight_kg[7]
    fob = math.floor(fob * 2.2046)

    -- if have fuel and all crossfeeds are off, then turn em om
    if(fob > 120000) then
        if(B747DR_gen_xfeed_vlv1_status==3 and B747DR_gen_xfeed_vlv2_status==3 and B747DR_gen_xfeed_vlv3_status==3 and B747DR_gen_xfeed_vlv4_status==3) then
            if(B747.fuel.main2_tank.ovrd_jett_pump_fwd.on==0 
            and B747.fuel.main2_tank.ovrd_jett_pump_aft.on==0 
            and B747.fuel.main3_tank.ovrd_jett_pump_fwd.on==0 
            and B747.fuel.main3_tank.ovrd_jett_pump_aft.on==0) then
                ToggleCrossFeedsOverrides()
            end
        end
    else
        if(B747DR_gen_xfeed_vlv1_status~=3 and B747DR_gen_xfeed_vlv2_status~=3 and B747DR_gen_xfeed_vlv3_status~=3 and B747DR_gen_xfeed_vlv4_status~=3) then
            if(B747.fuel.main2_tank.ovrd_jett_pump_fwd.on~=0 
            and B747.fuel.main2_tank.ovrd_jett_pump_aft.on~=0 
            and B747.fuel.main3_tank.ovrd_jett_pump_fwd.on~=0 
            and B747.fuel.main3_tank.ovrd_jett_pump_aft.on~=0) then
                ToggleCrossFeedsOverrides()
            end
        end
    end]]--

end



--*************************************************************************************--
--**                          FUEL SYSTEM (MODEL)                                    **--
--*************************************************************************************--
-- The fuel model (B747.28.fuel_model.lua) in the aircraft (2-2). Every frame
-- this reads the overhead and jettison switches, the fuel control and fire
-- switches, the buses, air/ground, the flap lever, pitch and X-Plane's engine
-- fuel flow, runs the model, and writes the tank quantities (m_fuel), the
-- engines' fuel supply (has_fuel_flow_before_mixture), the pump and valve
-- datarefs (sounds, synoptic), the synoptic status codes, the overhead
-- lights (laminar/B747/fuel/light/*, read by the lighting module), the
-- totaliser and the EICAS messages (docs/overhaul/notes/ATA-28.md).
dofile("B747.28.fuel_model.lua")
local F = B747_fuel_model

simDR_engine_running            = find_dataref("sim/flightmodel/engine/ENGN_running")
simDR_pitch                     = find_dataref("sim/flightmodel/position/theta")
simDR_tank_ratio                = find_dataref("sim/aircraft/overflow/acf_tank_rat")
simDR_fuel_capacity_kg          = find_dataref("sim/aircraft/weight/acf_m_fuel_tot")
simDR_apu_starter_switch        = find_dataref("sim/cockpit2/electrical/APU_starter_switch")
B747DR_elec_bus_ac              = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_elec_bus_dc              = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_elec_bus_utility         = find_dataref("laminar/B747/electrical/bus/utility")
B747DR_elec_bus_bat_main        = find_dataref("laminar/B747/electrical/bus/bat_main")
B747DR_elec_bus_hot_bat_main    = find_dataref("laminar/B747/electrical/bus/hot_bat_main")
B747DR_elec_bus_bat_apu         = find_dataref("laminar/B747/electrical/bus/bat_apu")
B747DR_elec_bus_gnd_svc         = find_dataref("laminar/B747/electrical/bus/gnd_svc")
B747DR_pseu_pri_air             = find_dataref("laminar/B747/gear/air_ground/pri_air")
B747DR_is_freighter             = find_dataref("laminar/B747/freighter")
B747DR_engine01_fire_ext_switch_pos_arm = find_dataref("laminar/B747/fire/engine01/ext_switch/pos_arm")
B747DR_engine02_fire_ext_switch_pos_arm = find_dataref("laminar/B747/fire/engine02/ext_switch/pos_arm")
B747DR_engine03_fire_ext_switch_pos_arm = find_dataref("laminar/B747/fire/engine03/ext_switch/pos_arm")
B747DR_engine04_fire_ext_switch_pos_arm = find_dataref("laminar/B747/fire/engine04/ext_switch/pos_arm")
B747DR_fuel_light_pump_press    = find_dataref("laminar/B747/fuel/light/pump_press")
B747DR_fuel_light_xfeed_valve   = find_dataref("laminar/B747/fuel/light/xfeed_valve")
B747DR_fuel_light_nozzle_valve  = find_dataref("laminar/B747/fuel/light/nozzle_valve")

-- X-Plane's tanks (m_fuel, acf_tank_rat)
local TANK_OF_INDEX = {[0] = "ctr", "m1", "m2", "m3", "m4", "r2", "r3", "stab"}
-- the switches (laminar/B747/button_switch/position)
local PUMP_SWITCH = {m1_fwd = 56, m2_fwd = 57, m3_fwd = 58, m4_fwd = 59, m1_aft = 60, m2_aft = 61, m3_aft = 62,
    m4_aft = 63, oj2_fwd = 64, oj3_fwd = 65, oj2_aft = 66, oj3_aft = 67, ctr_l = 52, ctr_r = 53, stab_l = 54, stab_r = 55}
local XFEED_SWITCH, XFER14_SWITCH, NOZZLE_SWITCH = 48, 43, 46       -- X FEED 1-4 are 48-51, NOZZLE L and R 46-47
-- EICAS slots (laminar/B747/CAS/*_status, B747.87.xt.warning.lua); 67 and
-- 68 are advisories kept in the caution list
local CAUTION = {jett_sys = 31, press_eng1 = 32, press_eng2 = 33, press_eng3 = 34, press_eng4 = 35, qty_low = 36,
    stab_xfr = 37, pres_stab_l = 67, pres_stab_r = 68, press_ctr_l = 69, press_ctr_r = 70}
local ADVISORY = {apu_fuel = 15, imbalance = 148, imbal14 = 149, imbal23 = 150, ovd_ctr_l = 153, ovd_ctr_r = 154,
    oj2_aft = 155, oj3_aft = 156, oj2_fwd = 157, oj3_fwd = 158, pmp_stab_l = 159, pmp_stab_r = 160,
    m1_aft = 161, m2_aft = 162, m3_aft = 163, m4_aft = 164, m1_fwd = 165, m2_fwd = 166, m3_fwd = 167, m4_fwd = 168,
    res_xfr2 = 169, res_xfr3 = 170, tank_eng = 171, temp_low = 172, xfeed1 = 175, xfeed2 = 176, xfeed3 = 177,
    xfeed4 = 178, xfer14 = 179, jett_noz = 235, jett_noz_l = 236, jett_noz_r = 237, jett_nozzle_l = 238,
    jett_nozzle_r = 239, xfeed_config = 299, low_ctr_l = 302, low_ctr_r = 303}
local FILTER_ADVISORY = 114          -- ENG 1-4 FUEL FILT (114-117), from X-Plane's filter failures
local SETTLE_S = 2                   -- after a flight start (the previous code waited too)
local REFUEL_AFTER_S = 10            -- the refuelling starts after this, as before
local EXTERNAL_KG = 20               -- a tank further than this from our last write was changed outside (weight dialog, replay)

-- the datarefs of the model's pumps and valves (B747.fuel tables above)
local PUMP_DREF = {
    m1_fwd = B747.fuel.main1_tank.main_pump_fwd, m1_aft = B747.fuel.main1_tank.main_pump_aft,
    m2_fwd = B747.fuel.main2_tank.main_pump_fwd, m2_aft = B747.fuel.main2_tank.main_pump_aft,
    m3_fwd = B747.fuel.main3_tank.main_pump_fwd, m3_aft = B747.fuel.main3_tank.main_pump_aft,
    m4_fwd = B747.fuel.main4_tank.main_pump_fwd, m4_aft = B747.fuel.main4_tank.main_pump_aft,
    oj2_fwd = B747.fuel.main2_tank.ovrd_jett_pump_fwd, oj2_aft = B747.fuel.main2_tank.ovrd_jett_pump_aft,
    oj3_fwd = B747.fuel.main3_tank.ovrd_jett_pump_fwd, oj3_aft = B747.fuel.main3_tank.ovrd_jett_pump_aft,
    ctr_l = B747.fuel.center_tank.ovrd_jett_pump_L, ctr_r = B747.fuel.center_tank.ovrd_jett_pump_R,
    stab_l = B747.fuel.stab_tank.xfr_jett_pump_L, stab_r = B747.fuel.stab_tank.xfr_jett_pump_R,
    apu_dc = B747.fuel.main2_tank.apu_dc_pump,
}
local VALVE_DREF = {
    x1 = B747.fuel.engine1.xfeed_vlv, x2 = B747.fuel.engine2.xfeed_vlv,
    x3 = B747.fuel.engine3.xfeed_vlv, x4 = B747.fuel.engine4.xfeed_vlv,
    s1 = B747.fuel.spar_vlv1, s2 = B747.fuel.spar_vlv2, s3 = B747.fuel.spar_vlv3, s4 = B747.fuel.spar_vlv4,
    res2a = B747.fuel.res2_tank.xfr_vlv_A, res2b = B747.fuel.res2_tank.xfr_vlv_B,
    res3a = B747.fuel.res3_tank.xfr_vlv_A, res3b = B747.fuel.res3_tank.xfr_vlv_B,
    xfer1 = B747.fuel.main1_tank.main_xfr_vlv, xfer4 = B747.fuel.main4_tank.main_xfr_vlv,
    jett_ctr_l = B747.fuel.center_tank.jett_vlv_L, jett_ctr_r = B747.fuel.center_tank.jett_vlv_R,
    jett_m2 = B747.fuel.main2_tank.jett_vlv, jett_m3 = B747.fuel.main3_tank.jett_vlv,
    noz_l = B747.fuel.jett_nozzle_vlv_L, noz_r = B747.fuel.jett_nozzle_vlv_R,
    apu = B747.fuel.main2_tank.apu_vlv,
}
local TANK_TABLE = {ctr = B747.fuel.center_tank, m1 = B747.fuel.main1_tank, m2 = B747.fuel.main2_tank,
    m3 = B747.fuel.main3_tank, m4 = B747.fuel.main4_tank, r2 = B747.fuel.res2_tank, r3 = B747.fuel.res3_tank,
    stab = B747.fuel.stab_tank}

local fuel_state = F.new()
local fuel_inputs = F.inputs()
local fuel_written = {}             -- what we last wrote to m_fuel, by X-Plane index
local fuel_settle_left = SETTLE_S   -- seconds of settling left after a flight start
local fuel_age = 0                  -- seconds since the flight start

local function flag(v)
    if v then return 1 end
    return 0
end

-- the tank quantities by X-Plane index for the refuelling functions below:
-- they change the model's quantities (B747_fuel_system writes m_fuel),
-- kept within the tank capacities
local fuel_qty = setmetatable({}, {
    __index = function(_, i) return fuel_state.qty[TANK_OF_INDEX[i]] end,
    __newindex = function(_, i, kg)
        local tank = TANK_OF_INDEX[i]
        fuel_state.qty[tank] = math.max(0, math.min(fuel_inputs.cap[tank], kg))
    end,
})
local function fuel_total()
    local total = 0
    for i = 0, 7 do total = total + fuel_qty[i] end
    return total
end

-- the tank capacities from the acf (both acfs: CWT 0.300, mains 1 and 4
-- 0.078, 2 and 3 0.220, reserves 0.023, stabilizer 0.058 of 173,069 kg), so
-- that the model, the refuelling and X-Plane agree (FUEL-19)
local function read_capacities()
    local total = simDR_fuel_capacity_kg
    if total <= 0 then return end
    for i = 0, 7 do
        local tank = TANK_OF_INDEX[i]
        fuel_inputs.cap[tank] = simDR_tank_ratio[i] * total
        TANK_TABLE[tank].capacity = fuel_inputs.cap[tank]
    end
end

-- take X-Plane's quantities: all of them, or the tanks changed outside since
-- our last write (more than one frame of flow)
local function sync_tanks(all)
    for i = 0, 7 do
        local kg = simDR_fuel_tank_weight_kg[i]
        if all or math.abs(kg - (fuel_written[i] or 0)) > EXTERNAL_KG then
            fuel_state.qty[TANK_OF_INDEX[i]] = math.max(0, kg)
            fuel_written[i] = kg
        end
    end
end

local function write_tanks()
    for i = 0, 7 do
        local kg = fuel_state.qty[TANK_OF_INDEX[i]]
        if math.abs(simDR_fuel_tank_weight_kg[i] - kg) > 0.001 then simDR_fuel_tank_weight_kg[i] = kg end
        fuel_written[i] = kg
    end
end

local function read_inputs(inp)
    for id, i in pairs(PUMP_SWITCH) do inp.sw[id] = B747DR_button_switch_position[i] > 0.5 end
    for n = 1, 4 do
        inp.xfeed[n] = B747DR_button_switch_position[XFEED_SWITCH + n - 1] > 0.5
        inp.fuel_control[n] = B747DR_fuel_control_toggle_switch_pos[n - 1] > 0.95
        inp.ac[n] = B747DR_elec_bus_ac[n - 1] > 0.5
        inp.util[n] = B747DR_elec_bus_utility[n - 1] > 0.5
        inp.dc[n] = B747DR_elec_bus_dc[n - 1] > 0.5
        inp.ff[n] = simDR_eng_fuel_flow_kg_sec[n - 1]
        inp.running[n] = simDR_engine_running[n - 1] == 1
    end
    inp.fire_out[1] = B747DR_engine01_fire_ext_switch_pos_arm > 0.5
    inp.fire_out[2] = B747DR_engine02_fire_ext_switch_pos_arm > 0.5
    inp.fire_out[3] = B747DR_engine03_fire_ext_switch_pos_arm > 0.5
    inp.fire_out[4] = B747DR_engine04_fire_ext_switch_pos_arm > 0.5
    inp.xfer_main14 = B747DR_button_switch_position[XFER14_SWITCH] > 0.5
    inp.nozzle[1] = B747DR_button_switch_position[NOZZLE_SWITCH] > 0.5
    inp.nozzle[2] = B747DR_button_switch_position[NOZZLE_SWITCH + 1] > 0.5
    inp.jett_sel = B747DR_fuel_jettison_sel_dial_pos
    inp.ftr = B747DR_fuel_to_remain_rheo * 1000.0
    inp.main_bat = B747DR_elec_bus_bat_main > 0.5
    inp.hot_bat = B747DR_elec_bus_hot_bat_main > 0.5
    inp.apu_bat = B747DR_elec_bus_bat_apu > 0.5
    inp.gs_bus = B747DR_elec_bus_gnd_svc > 0.5
    inp.on_ground = B747DR_pseu_pri_air == 0
    inp.flap_lever = simDR_flap_deploy_ratio
    inp.pitch = simDR_pitch
    inp.apu_fuel = simDR_apu_starter_switch >= 1          -- the APU model starts or runs X-Plane's APU
    inp.temp = B747DR_fuel_temperature
    -- the stabilizer tank: airplane 109, the passenger airplane (FCOM p.1453, p.1456)
    inp.has_stab = simDR_tank_ratio[7] > 0 and B747DR_is_freighter == 0
end

-- the synoptic's engine feed: 1 from its own tank (suction feed too), 2
-- through the crossfeed manifold, 0 none or the spar valve closed (the
-- synoptic's flow comes from the valves and pumps: FCOM p.1447)
local function engine_status(out, n)
    if fuel_state.valve["s" .. n] < 0.5 then return 0 end
    local feed = out.feed[n]
    if (feed[F.MAIN[n]] or 0) >= 1 then return 1 end
    for _, share in pairs(feed) do
        if share > 0 then return 2 end
    end
    return 0
end

-- settling: the running engines keep their fuel and no message is shown
local function write_outputs(out, settling)
    local s, inp = fuel_state, fuel_inputs
    for id, p in pairs(PUMP_DREF) do p.on = flag(out.pump[id]) end
    -- the jet pumps of the scavenge (no motors): on while the CWT flows into main 2 or 3
    local scav_l, scav_r = flag(out.flow["ctr>m2"]), flag(out.flow["ctr>m3"])
    B747.fuel.center_tank.scvg_pump_L1.on = scav_l
    B747.fuel.center_tank.scvg_pump_L2.on = scav_l
    B747.fuel.center_tank.scvg_pump_R1.on = scav_r
    B747.fuel.center_tank.scvg_pump_R2.on = scav_r
    for name, v in pairs(VALVE_DREF) do
        v.pos = s.valve[name]
        v.target_pos = s.cmd[name] and 1.0 or 0.0
    end
    -- the stabilizer tank's valves are not in the model: open while its pump
    -- runs, to the CWT or overboard (estimate, for the synoptic)
    B747.fuel.stab_tank.xfr_jett_vlv_L.pos = flag(out.pump.stab_l)
    B747.fuel.stab_tank.xfr_jett_vlv_R.pos = flag(out.pump.stab_r)
    B747.fuel.center_tank.stab_xfr_vlv_L.pos = flag(out.pump.stab_l and not out.jett)
    B747.fuel.center_tank.stab_xfr_vlv_R.pos = flag(out.pump.stab_r and not out.jett)
    B747DR_stab_fuel_pump_press_low_L = flag(out.low.stab_l)
    B747DR_stab_fuel_pump_press_low_R = flag(out.low.stab_r)
    B747DR_gen_fuel_engine1_status = engine_status(out, 1)
    B747DR_gen_fuel_engine2_status = engine_status(out, 2)
    B747DR_gen_fuel_engine3_status = engine_status(out, 3)
    B747DR_gen_fuel_engine4_status = engine_status(out, 4)
    B747DR_gen_jett_valve_status = flag(s.valve.noz_l > 0.05 or s.valve.noz_r > 0.05)
    B747DR_jett_time = out.jett_min
    -- X-Plane's fuel to the engines (read every frame, written only when
    -- different: ARCHITECTURE.md §9a). While settling it is only switched on,
    -- as the previous code kept it on after a flight start.
    for n = 1, 4 do
        local has = flag(out.has_fuel[n] and B747DR_engine_fuel_valve_pos[n - 1] > 0)
        if settling then
            if out.has_fuel[n] or inp.running[n] then has = 1 else has = simDR_engine_has_fuel[n - 1] end
        end
        if simDR_engine_has_fuel[n - 1] ~= has then simDR_engine_has_fuel[n - 1] = has end
    end
    for i, p in ipairs(F.PUMPS) do B747DR_fuel_light_pump_press[i - 1] = flag(out.light[p.id]) end
    for n = 1, 4 do B747DR_fuel_light_xfeed_valve[n - 1] = flag(out.light["x" .. n]) end
    B747DR_fuel_light_nozzle_valve[0] = flag(out.light.noz_l)
    B747DR_fuel_light_nozzle_valve[1] = flag(out.light.noz_r)
    local c = out.cas
    for key, i in pairs(CAUTION) do B747DR_CAS_caution_status[i] = flag(c[key] and not settling) end
    for key, i in pairs(ADVISORY) do B747DR_CAS_advisory_status[i] = flag(c[key] and not settling) end
    B747DR_CAS_advisory_status[FILTER_ADVISORY] = flag(simDR_fuel_filter_block_01 == 6)
    B747DR_CAS_advisory_status[FILTER_ADVISORY + 1] = flag(simDR_fuel_filter_block_02 == 6)
    B747DR_CAS_advisory_status[FILTER_ADVISORY + 2] = flag(simDR_fuel_filter_block_03 == 6)
    B747DR_CAS_advisory_status[FILTER_ADVISORY + 3] = flag(simDR_fuel_filter_block_04 == 6)
end

-- the totaliser: each engine's flow, and FUEL USED (PROGRESS page 2) as the
-- engines' flow (FCOM p.1274; the previous code added the APU's burn)
local function count_fuel_used(inp, dt)
    local engines = 0
    for n = 1, 4 do
        local kg = math.max(0, inp.ff[n]) * dt         -- X-Plane's flow goes negative in a start
        B747DR_engine_used_fuel[n - 1] = B747DR_engine_used_fuel[n - 1] + kg
        engines = engines + kg
    end
    B747DR_engine_used_fuel[4] = B747DR_engine_used_fuel[4] + engines
end

-- Kept from the previous code (no source, FUEL-21): a flight that starts on
-- the ground with more than 100 t gets a fixed loading of the main and
-- reserve tanks, and the rest goes to the refuelling (B747_refueling). The
-- previous code lost the 1,428 kg between 100 t and the fixed loading.
local INITIAL_LOAD = {[0] = 0, 11976, 33793, 33793, 11976, 3517, 3517, 0}
local function initial_load()
    local total, loaded = fuel_total(), 0
    for i = 0, 7 do loaded = loaded + INITIAL_LOAD[i] end
    if total <= 100000 then return end
    for i = 0, 7 do fuel_qty[i] = INITIAL_LOAD[i] end
    B747DR_refuel = total - loaded
end

-- a new flight: the model starts again from X-Plane's quantities
function B747_fuel_system_start()
    fuel_state = F.new()
    fuel_settle_left = SETTLE_S
    fuel_age = 0
end

-- every frame
function B747_fuel_system()
    local inp = fuel_inputs
    local dt = math.max(0, math.min(1, SIM_PERIOD))
    fuel_age = fuel_age + dt
    read_inputs(inp)
    if simDR_inReplay == 1 then
        sync_tanks(true)
        return
    end
    if fuel_settle_left > 0 then
        -- after a flight start: take X-Plane's quantities (in XTLua the first
        -- reads of a dataref give 0), put the valves where they are
        -- commanded, keep the running engines fed and burn nothing
        fuel_settle_left = fuel_settle_left - dt
        read_capacities()
        sync_tanks(true)
        F.settle(fuel_state, inp)
        write_outputs(fuel_state.out, true)
        if fuel_settle_left <= 0 then
            if simDR_all_wheels_on_ground == 1 then initial_load() end
            write_tanks()
        end
        return
    end
    sync_tanks(false)
    local out = F.update(fuel_state, inp, dt)
    count_fuel_used(inp, dt)
    write_tanks()
    write_outputs(out, false)
end

--Marauder28
-- The refuelling (FMC ground service: laminar/B747/fuel/refuel). It changes
-- the model's quantities through fuel_qty (B747_fuel_system writes m_fuel).
function B747_fuel_balance_check()
  local total = fuel_total()
  --Initial check to ensure that this balance function only runs once
  --(the totaliser is a float dataref: compared within 1 kg)
  if math.abs(simDR_fuel_totalizer_kg - total) > 1 then
    return
  end

  --Determine amount for each tank based on existing fuel and load order.
  --Load order is:
  --1) Even distribution in Main1, Main2, Main3, Main4 (Wing)
  --3) Reserve 5 & Reserve 6 (Wing)
  --4) Center 0
  --5) Horizontal Stabilizer 7

  local overage = 0

  --Use and rebalance any existing fuel into their proper tanks before starting the refueling process
  --Start by placing all fuel into the first 2 main tanks and then take overages and place it in tanks in the order above
  --(the tanks are kept within their capacities, so the overages are taken from the total)
  local main1, main4 = total / 4, total / 4
  local main2, main3 = total / 4, total / 4
  local res2, res3, center, stab = 0, 0, 0, 0

  --Move overages from Main1 to Main2
  if main1 > B747.fuel.main1_tank.capacity then
    overage = main1 - B747.fuel.main1_tank.capacity
    main1 = B747.fuel.main1_tank.capacity
    main2 = main2 + overage
  end
  --Move overages from Main4 to Main3
  if main4 > B747.fuel.main4_tank.capacity then
    overage = main4 - B747.fuel.main4_tank.capacity
    main4 = B747.fuel.main4_tank.capacity
    main3 = main3 + overage
  end
  --Move overages from Main2 to Reserve5
  if main2 > B747.fuel.main2_tank.capacity then
    res2 = main2 - B747.fuel.main2_tank.capacity
    main2 = B747.fuel.main2_tank.capacity
  end
  --Move overages from Main3 to Reserve6
  if main3 > B747.fuel.main3_tank.capacity then
    res3 = main3 - B747.fuel.main3_tank.capacity
    main3 = B747.fuel.main3_tank.capacity
  end
  --Move overages from Reserve5 to Center0 (Reserve5 is also known as res2 in previous code)
  if res2 > B747.fuel.res2_tank.capacity then
    center = res2 - B747.fuel.res2_tank.capacity
    res2 = B747.fuel.res2_tank.capacity
  end
  --Move overages from Reserve6 to Center0 (Reserve6 is also known as res3 in previous code)
  if res3 > B747.fuel.res3_tank.capacity then
    center = center + res3 - B747.fuel.res3_tank.capacity
    res3 = B747.fuel.res3_tank.capacity
  end
  --Move overages from Center0 to Stab7
  if center > B747.fuel.center_tank.capacity then
    stab = center - B747.fuel.center_tank.capacity
    center = B747.fuel.center_tank.capacity
  end

  fuel_qty[1], fuel_qty[2], fuel_qty[3], fuel_qty[4] = main1, main2, main3, main4
  fuel_qty[5], fuel_qty[6], fuel_qty[0], fuel_qty[7] = res2, res3, center, stab
end
--Marauder28

function B747_refueling()
  if B747DR_refuel<=0.0 then
  --Marauder28
  --Set the totalizer to the current fuel amount after refueling
  --(an X-Plane dataref: written only when different, ARCHITECTURE.md §9a)
  local total = fuel_total()
  if math.abs(simDR_fuel_totalizer_kg - total) > 0.5 then simDR_fuel_totalizer_kg = total end
  --Marauder28

  return
  end


  local fuelIn=math.min(10,B747DR_refuel)       -- kg per tank per frame, as the previous code
  --print("sending fuel "..fuelIn)

  --Marauder28
  B747_fuel_balance_check()  --Ensure existing fuel is ordered in the tanks correctly before refueling

  --Now start adding fuel
  --Load order is:
  --1) Even distribution in Main1, Main2, Main3, Main4 (Wing)  e.g. BLOCK FUEL / 4
  --3) Reserve 5 & Reserve 6 (Wing)
  --4) Center 0
  --5) Horizontal Stabilizer 7

  --Finish filling Main1 - Main4 First
  if fuel_qty[1] < B747.fuel.main1_tank.capacity then
    B747DR_refuel = B747DR_refuel - fuelIn
    fuel_qty[1] = fuel_qty[1] + fuelIn
  end
  if fuel_qty[4] < B747.fuel.main4_tank.capacity then
    B747DR_refuel = B747DR_refuel - fuelIn
    fuel_qty[4] = fuel_qty[4] + fuelIn
  end
  if fuel_qty[2] < B747.fuel.main2_tank.capacity then
    B747DR_refuel = B747DR_refuel - fuelIn
    fuel_qty[2] = fuel_qty[2] + fuelIn
  end
  if fuel_qty[3] < B747.fuel.main3_tank.capacity then
    B747DR_refuel = B747DR_refuel - fuelIn
    fuel_qty[3] = fuel_qty[3] + fuelIn
  end

  --Now deal with overflows in Main1 - Main4 using Reserve5 & Reserve6 (known as Res2 & Res3 in other code)
  if fuel_qty[1] == B747.fuel.main1_tank.capacity and
    fuel_qty[4] == B747.fuel.main4_tank.capacity then
    if fuel_qty[2] < B747.fuel.main2_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[2] = fuel_qty[2] + fuelIn
    elseif fuel_qty[5] < B747.fuel.res2_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[5] = fuel_qty[5] + fuelIn
    end
    if fuel_qty[3] < B747.fuel.main3_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[3] = fuel_qty[3] + fuelIn
    elseif fuel_qty[6] < B747.fuel.res3_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[6] = fuel_qty[6] + fuelIn
    end
  end

  --Reserve5 & Reserve6 are full so move on to Center 0
  if fuel_qty[5] == B747.fuel.res2_tank.capacity and
    fuel_qty[6] == B747.fuel.res3_tank.capacity then
    if fuel_qty[0] < B747.fuel.center_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[0] = fuel_qty[0] + fuelIn
    elseif fuel_qty[7] < B747.fuel.stab_tank.capacity then
      B747DR_refuel = B747DR_refuel - fuelIn
      fuel_qty[7] = fuel_qty[7] + fuelIn
    end
  end

  -- Don't overfill
  if fuel_qty[7] == B747.fuel.stab_tank.capacity then
    B747DR_refuel = 0
  end

end



----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_fuel_monitor_AI()

    if B747DR_init_fuel_CD == 1 then
        B747_set_fuel_all_modes()
        B747_set_fuel_CD()
        B747DR_init_fuel_CD = 2
    end

end





----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_fuel_all_modes()

	B747DR_init_fuel_CD = 0
    B747DR_fuel_to_remain_rheo = 9.6
    B747DR_fuel_jettison_sel_dial_pos = 0

end





----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_fuel_CD()

    for i = 0, NUM_FUEL_TOGGLE_SW-1 do
        B747_fuel_control_toggle_sw_pos_target[i] = 0
    end
end





----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_fuel_ER()

    -- the running engines keep their fuel until the fuel system has settled
    -- (B747_fuel_system), as the previous code did
    for i = 0, 3 do
        simDR_engine_has_fuel[i] = 1
    end

    for i = 0, NUM_FUEL_TOGGLE_SW-1 do
        B747_fuel_control_toggle_sw_pos_target[i] = 1.0
        B747DR_fuel_control_toggle_switch_pos[i] = 1.0
    end

end

dofile("json/json.lua")

--Simulator Config Options
simConfigData = {}
if string.len(B747DR_simconfig_data) > 1 then
	simConfigData["data"] = json.decode(B747DR_simconfig_data)
else
	simConfigData["data"] = json.decode("[]")
end

-- FUEL DISPLAY UNITS CALCULATION
--[[
* Determine the current selected display units (from the Maintenance page of the FMC)
* and use a multiplication factor to convert KGS to LBS if needed.  This will be stored
* in a dataref that is used on the 3D display panel for the upper and lower EICAS to
* display the fuel quantities in the correct units.
--]]
function B747_calculate_fuel_display_units ()
	local fuel_calculation_factor = 1 -- Initially set to 1 (i.e. KGS) unless LBS is selected
	local x = 0

	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		fuel_calculation_factor = simConfigData["data"].SIM.kgs_to_lbs
	end

	B747DR_fuel_total_display_qty = simDR_fueL_tank_weight_total_kg * fuel_calculation_factor

	B747DR_fuel_preselect = B747DR_fuel_preselect_temp * fuel_calculation_factor

	for x = 0, 7 do
		B747DR_fuel_tank_display_qty[x] = simDR_fuel_tank_weight_kg[x] * fuel_calculation_factor
	end

	-- Determine fuel flow rate for display on EICAS based on fuel calculation factor
	for x = 0, 3 do
		B747DR_fuel_flow_sec_display[x] = simDR_eng_fuel_flow_kg_sec[x] * fuel_calculation_factor
	end

	-- Set correct fuel units displayed on EICAS
	if simConfigData["data"].SIM.weight_display_units == "LBS" then
		B747DR_fuel_display_units_eicas = 1
	else
		B747DR_fuel_display_units_eicas = 0
	end

end





----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_fuel()
    print("B747_flight_start_fuel")
    B747_fuel_system_start()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_fuel_all_modes()


    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_fuel_CD()


    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

	B747_set_fuel_ER()

    end

end





--*************************************************************************************--
--**                          EVENT CALLBACKS                        **--
--*************************************************************************************--

function aircraft_load()

    simDR_override_fuel_system = 1
end

function aircraft_unload()

    simDR_override_fuel_system = 0

end

function flight_start()

    B747_flight_start_fuel()

end

--function flight_crash() end

debug_fuel     = deferred_dataref("laminar/B747/debug/fuel", "number")

local setSimConfig=false
function hasSimConfig()
	if B747DR_newsimconfig_data==1 then
		if string.len(B747DR_simconfig_data) > 1 then
			simConfigData["data"] = json.decode(B747DR_simconfig_data)
			setSimConfig=true
		else
			return false
		end
	end
	return setSimConfig
end
function after_physics()
    collectgarbage("collect")
    if debug_fuel>0 then return end
    B747_fuel_system()
    B747_fuel_temp()
    B747_fuel_std_synoptic()
    B747_fuel_xfr_synoptic()
    B747_fuel_jett_synoptic()
    B747_fuel_toggle_switch_animation()
    B747_fuel_monitor_AI()
    if fuel_age >= REFUEL_AFTER_S then
        B747_refueling()
    end
    if hasSimConfig()==false then return end
    --auto tank to engine
    if simConfigData["data"].SIM.auto_fuel_mgmt =="YES" then tank_helper() end
    --Display Fuel Units
    B747_calculate_fuel_display_units()
end

--function after_replay() end
