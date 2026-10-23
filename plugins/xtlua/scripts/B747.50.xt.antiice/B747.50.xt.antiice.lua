--[[
*****************************************************************************************
* Program Script Name	:	B747.50.antiice
* Author Name			:	Jim Gregory
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2016-04-26	0.01a				Start of Dev
*   2026-10-24						The systems rebuilt around B747.50.antiice_model.lua
*									(notes/ATA-30.md)
*
*****************************************************************************************
*        COPYRIGHT � 2016 JIM GREGORY / LAMINAR RESEARCH - ALL RIGHTS RESERVED	        *
*****************************************************************************************
--]]

-- The ice and rain protection model (B747.50.antiice_model.lua) in the
-- aircraft: reads the P5 anti-ice, window heat and wiper controls, each
-- engine's bleed air to its NAI valve (the bleed air model), the engines,
-- the air/ground relay, TAT, X-Plane's ice detection and the failures of
-- its heaters, the buses; writes the NAI and WAI valves, the P5 lights,
-- X-Plane's inlet, wing, window and probe heat, its ice detection and
-- wipers, and the EICAS messages of the system.

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

dofile("B747.50.antiice_model.lua")
local I = B747_antiice_model


--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--
simDR_version                       = find_dataref("sim/version/xplane_internal_version")
simDR_startup_running               = find_dataref("sim/operation/prefs/startup_running")
simDR_engine_running                = find_dataref("sim/flightmodel/engine/ENGN_running")
simDR_agl                           = find_dataref("sim/flightmodel/position/y_agl")
simDR_tat                           = find_dataref("sim/weather/aircraft/temperature_leadingedge_deg_c")
simDR_ice_detected                  = find_dataref("sim/cockpit2/annunciators/ice")
-- X-Plane's heat and detection, set from the model
simDR_inlet_heat                    = find_dataref("sim/cockpit2/ice/ice_inlet_heat_on_per_engine")
simDR_wing_heat_L                   = find_dataref("sim/cockpit2/ice/ice_surfce_heat_left_on")
simDR_wing_heat_R                   = find_dataref("sim/cockpit2/ice/ice_surfce_heat_right_on")
simDR_window_heat                   = find_dataref("sim/cockpit2/ice/ice_window_heat_on_window")
simDR_pitot_heat_pilot              = find_dataref("sim/cockpit2/ice/ice_pitot_heat_on_pilot")
simDR_pitot_heat_copilot            = find_dataref("sim/cockpit2/ice/ice_pitot_heat_on_copilot")
simDR_pitot_heat_stby               = find_dataref("sim/cockpit2/ice/ice_pitot_heat_on_standby")
simDR_static_heat_pilot             = find_dataref("sim/cockpit2/ice/ice_static_heat_on_pilot")
simDR_static_heat_copilot           = find_dataref("sim/cockpit2/ice/ice_static_heat_on_copilot")
simDR_static_heat_stby              = find_dataref("sim/cockpit2/ice/ice_static_heat_on_standby")
simDR_aoa_heat_pilot                = find_dataref("sim/cockpit2/ice/ice_AOA_heat_on")
simDR_aoa_heat_copilot              = find_dataref("sim/cockpit2/ice/ice_AOA_heat_on_copilot")
simDR_tat_heat_pilot                = find_dataref("sim/cockpit2/ice/ice_TAT_heat_on")
simDR_tat_heat_copilot              = find_dataref("sim/cockpit2/ice/ice_TAT_heat_on_copilot")
simDR_ice_detect_on                 = find_dataref("sim/cockpit2/ice/ice_detect_on")
simDR_windshield_wiper_speed        = find_dataref("sim/cockpit2/switches/wiper_speed_switch")
simDR_windshield_wiper_speedXP11    = find_dataref("sim/cockpit2/switches/wiper_speed")
-- X-Plane's failures (6 = failed), for the model's heaters, valves and detectors
simDR_fail_window_L                 = find_dataref("sim/operation/failures/rel_ice_window_heat")
simDR_fail_window_R                 = find_dataref("sim/operation/failures/rel_ice_window_heat_cop")
simDR_fail_pitot_1                  = find_dataref("sim/operation/failures/rel_ice_pitot_heat1")
simDR_fail_pitot_2                  = find_dataref("sim/operation/failures/rel_ice_pitot_heat2")
simDR_fail_pitot_stby               = find_dataref("sim/operation/failures/rel_ice_pitot_heat_stby")
simDR_fail_static_1                 = find_dataref("sim/operation/failures/rel_ice_static_heat")
simDR_fail_static_2                 = find_dataref("sim/operation/failures/rel_ice_static_heat2")
simDR_fail_static_stby              = find_dataref("sim/operation/failures/rel_ice_static_heat_stby")
simDR_fail_aoa_1                    = find_dataref("sim/operation/failures/rel_ice_AOA_heat")
simDR_fail_aoa_2                    = find_dataref("sim/operation/failures/rel_ice_AOA_heat2")
simDR_fail_tat_1                    = find_dataref("sim/operation/failures/rel_ice_TAT_heat")
simDR_fail_tat_2                    = find_dataref("sim/operation/failures/rel_ice_TAT_heat2")
simDR_fail_detect                   = find_dataref("sim/operation/failures/rel_ice_detect")
simDR_fail_inlet_1                  = find_dataref("sim/operation/failures/rel_ice_inlet_heat")
simDR_fail_inlet_2                  = find_dataref("sim/operation/failures/rel_ice_inlet_heat2")
simDR_fail_inlet_3                  = find_dataref("sim/operation/failures/rel_ice_inlet_heat3")
simDR_fail_inlet_4                  = find_dataref("sim/operation/failures/rel_ice_inlet_heat4")
simDR_fail_wing_L                   = find_dataref("sim/operation/failures/rel_ice_surf_heat")
simDR_fail_wing_R                   = find_dataref("sim/operation/failures/rel_ice_surf_heat2")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_button_switch_position       = find_dataref("laminar/B747/button_switch/position")
B747DR_engine1_bleed_air_psi        = find_dataref("laminar/B747/air/engine1/bleed_air_psi")
B747DR_engine2_bleed_air_psi        = find_dataref("laminar/B747/air/engine2/bleed_air_psi")
B747DR_engine3_bleed_air_psi        = find_dataref("laminar/B747/air/engine3/bleed_air_psi")
B747DR_engine4_bleed_air_psi        = find_dataref("laminar/B747/air/engine4/bleed_air_psi")
B747DR_ice_pseu_pri_gnd             = find_dataref("laminar/B747/gear/air_ground/pri_gnd")
B747DR_ice_elec_ac                  = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_ice_elec_dc                  = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_CAS_caution_status           = find_dataref("laminar/B747/CAS/caution_status")
B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_status_status            = find_dataref("laminar/B747/CAS/status_status")


--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_windshield_wiper_sel_L_pos   = deferred_dataref("laminar/B747/antiice/wndshlsd_wiper_L/sel_dial_pos", "number")
B747DR_windshield_wiper_sel_R_pos   = deferred_dataref("laminar/B747/antiice/wndshlsd_wiper_R/sel_dial_pos", "number")
B747DR_nacelle_ai_valve_pos         = deferred_dataref("laminar/B747/antiice/nacelle/valve_pos", "array[4]")
B747DR_wing_ai_valve_pos            = deferred_dataref("laminar/B747/antiice/wing/valve_pos", "array[2]")
B747DR_antiice_light_nai_valve      = deferred_dataref("laminar/B747/antiice/light/nai_valve", "array[4]")
B747DR_antiice_light_wai_valve      = deferred_dataref("laminar/B747/antiice/light/wai_valve", "number")
B747DR_antiice_light_window_inop    = deferred_dataref("laminar/B747/antiice/light/window_inop", "array[2]")
B747DR_init_ice_CD                  = deferred_dataref("laminar/B747/ice/init_CD", "number")


--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- WINDSHIELD WIPERS: the selectors (X-Plane's speed comes from the model)
function B747_windshield_wiper_sel_L_up_CMDhandler(phase, duration)
    if phase == 0 then B747DR_windshield_wiper_sel_L_pos = math.min(B747DR_windshield_wiper_sel_L_pos + 1, 2) end
end
function B747_windshield_wiper_sel_L_dn_CMDhandler(phase, duration)
    if phase == 0 then B747DR_windshield_wiper_sel_L_pos = math.max(B747DR_windshield_wiper_sel_L_pos - 1, 0) end
end
function B747_windshield_wiper_sel_R_up_CMDhandler(phase, duration)
    if phase == 0 then B747DR_windshield_wiper_sel_R_pos = math.min(B747DR_windshield_wiper_sel_R_pos + 1, 2) end
end
function B747_windshield_wiper_sel_R_dn_CMDhandler(phase, duration)
    if phase == 0 then B747DR_windshield_wiper_sel_R_pos = math.max(B747DR_windshield_wiper_sel_R_pos - 1, 0) end
end

function B747_ai_antiice_quick_start_CMDhandler(phase, duration)
    if phase == 0 then
        B747_set_ice_all_modes()
        B747_set_ice_CD()
        B747_set_ice_ER()
    end
end


--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

-- WINDSHIELD WIPERS
B747CMD_windshield_wiper_sel_L_up 	= deferred_command("laminar/B747/antiice/wndshlsd_wiper_L/sel_dial_up", "Windshield Wiper Selector Dial Left Up", B747_windshield_wiper_sel_L_up_CMDhandler)
B747CMD_windshield_wiper_sel_L_dn 	= deferred_command("laminar/B747/antiice/wndshlsd_wiper_L/sel_dial_dn", "Windshield Wiper Selector Dial Left Down", B747_windshield_wiper_sel_L_dn_CMDhandler)
B747CMD_windshield_wiper_sel_R_up 	= deferred_command("laminar/B747/antiice/wndshlsd_wiper_R/sel_dial_up", "Windshield Wiper Selector Dial Right Up", B747_windshield_wiper_sel_R_up_CMDhandler)
B747CMD_windshield_wiper_sel_R_dn 	= deferred_command("laminar/B747/antiice/wndshlsd_wiper_R/sel_dial_dn", "Windshield Wiper Selector Dial Right Down", B747_windshield_wiper_sel_R_dn_CMDhandler)

-- AI
B747CMD_ai_antiice_quick_start		= deferred_command("laminar/B747/ai/antiice_quick_start", "number", B747_ai_antiice_quick_start_CMDhandler)


--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

local NAI_SWITCH, WAI_SWITCH, WINDOW_SWITCH = 68, 72, 73   -- button_switch/position: [68-71], [72], [73-74]
local INIT_S = 3                -- the first seconds: the air/ground by the height (XTLua's first reads of
                                -- the other modules' datarefs are 0)
-- EICAS slots (B747.87.xt.warning.lua)
local CAUT_ICING = 45
local ADV_ANTI_ICE, ADV_ICE_DETECTORS, ADV_NO_ICING = 7, 222, 247
local ADV_NAI_VALVE, ADV_WAI_VALVE, ADV_HEAT_WINDOW = 242, 296, 194    -- 242-245, 296-297, 194-195
-- HEAT P/S CAPT, F/O, L AUX, R AUX, L AOA, R AOA, L TAT, R TAT (the model's probes)
local ADV_PROBE = {188, 189, 190, 191, 186, 192, 187, 193}
local STATUS_ICE_DETECTOR = 37  -- ICE DETECTOR L, R: 37-38

local ice_state = I.new()
local ice_inputs = I.inputs()
local ice_t = 0

local function flag(v)
    if v then return 1 end
    return 0
end

-- X-Plane's datarefs: read first, write when different (TESTING.md §1.2)
local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

local function bleed_psi(n)
    if n == 1 then return B747DR_engine1_bleed_air_psi
    elseif n == 2 then return B747DR_engine2_bleed_air_psi
    elseif n == 3 then return B747DR_engine3_bleed_air_psi end
    return B747DR_engine4_bleed_air_psi
end

local function inlet_failed(n)
    if n == 1 then return simDR_fail_inlet_1 == 6
    elseif n == 2 then return simDR_fail_inlet_2 == 6
    elseif n == 3 then return simDR_fail_inlet_3 == 6 end
    return simDR_fail_inlet_4 == 6
end

local function read_inputs(inp)
    for n = 1, 4 do
        inp.nai_on[n] = B747DR_button_switch_position[NAI_SWITCH + n - 1] > 0.95
        inp.nai_psi[n] = bleed_psi(n)
        inp.engine_running[n] = simDR_engine_running[n - 1] == 1
        inp.nai_failed[n] = inlet_failed(n)
        inp.ac[n] = B747DR_ice_elec_ac[n - 1] > 0.5
        inp.dc[n] = B747DR_ice_elec_dc[n - 1] > 0.5
    end
    inp.wai_on = B747DR_button_switch_position[WAI_SWITCH] > 0.95
    inp.window_on[1] = B747DR_button_switch_position[WINDOW_SWITCH] > 0.95
    inp.window_on[2] = B747DR_button_switch_position[WINDOW_SWITCH + 1] > 0.95
    inp.wiper[1] = math.floor(B747DR_windshield_wiper_sel_L_pos + 0.5)
    inp.wiper[2] = math.floor(B747DR_windshield_wiper_sel_R_pos + 0.5)
    if ice_t < INIT_S then inp.on_ground = simDR_agl < 15 else inp.on_ground = B747DR_ice_pseu_pri_gnd == 1 end
    inp.tat_c = simDR_tat
    inp.icing = simDR_ice_detected == 1
    inp.wai_failed[1] = simDR_fail_wing_L == 6
    inp.wai_failed[2] = simDR_fail_wing_R == 6
    inp.window_failed[1] = simDR_fail_window_L == 6
    inp.window_failed[2] = simDR_fail_window_R == 6
    -- the probes (estimate: the AUX ones on X-Plane's standby pitot and static)
    inp.probe_failed[1] = simDR_fail_pitot_1 == 6 or simDR_fail_static_1 == 6
    inp.probe_failed[2] = simDR_fail_pitot_2 == 6 or simDR_fail_static_2 == 6
    inp.probe_failed[3] = simDR_fail_pitot_stby == 6
    inp.probe_failed[4] = simDR_fail_static_stby == 6
    inp.probe_failed[5] = simDR_fail_aoa_1 == 6
    inp.probe_failed[6] = simDR_fail_aoa_2 == 6
    inp.probe_failed[7] = simDR_fail_tat_1 == 6
    inp.probe_failed[8] = simDR_fail_tat_2 == 6
    -- one detector failure in X-Plane: both detectors
    inp.detector_failed[1] = simDR_fail_detect == 6
    inp.detector_failed[2] = simDR_fail_detect == 6
end

local function write_outputs(out)
    for n = 1, 4 do
        local i = n - 1
        put(B747DR_nacelle_ai_valve_pos, i, out.nai_valve[n])
        put(B747DR_antiice_light_nai_valve, i, flag(out.nai_light[n]))
        put(simDR_inlet_heat, i, flag(out.nai_valve[n] > 0.5))     -- the EICAS NAI (acf) and X-Plane's inlet
        put(B747DR_CAS_advisory_status, ADV_NAI_VALVE + i, flag(out.nai_alert[n]))
    end
    put(B747DR_wing_ai_valve_pos, 0, out.wai_valve[1])
    put(B747DR_wing_ai_valve_pos, 1, out.wai_valve[2])
    local wai_l, wai_r, wai_light = flag(out.wai_valve[1] > 0.5), flag(out.wai_valve[2] > 0.5), flag(out.wai_light)
    if simDR_wing_heat_L ~= wai_l then simDR_wing_heat_L = wai_l end    -- the EICAS WAI (acf) and X-Plane's wings
    if simDR_wing_heat_R ~= wai_r then simDR_wing_heat_R = wai_r end
    if B747DR_antiice_light_wai_valve ~= wai_light then B747DR_antiice_light_wai_valve = wai_light end
    put(B747DR_CAS_advisory_status, ADV_WAI_VALVE, flag(out.wai_alert[1]))
    put(B747DR_CAS_advisory_status, ADV_WAI_VALVE + 1, flag(out.wai_alert[2]))
    -- X-Plane's windows: 1 and 2 the windshields, 3 and 4 the side windows
    for w = 1, 2 do
        put(simDR_window_heat, w - 1, flag(out.window_heat[w]))
        put(simDR_window_heat, w + 1, flag(out.side_window_heat))
        put(B747DR_antiice_light_window_inop, w - 1, flag(out.window_inop[w]))
        put(B747DR_CAS_advisory_status, ADV_HEAT_WINDOW + w - 1, flag(out.window_alert[w]))
    end
    -- the probes: CAPT and F/O on X-Plane's pilot and copilot pitot and
    -- static, L AUX on its standby pitot, R AUX on its standby static
    -- (estimate: X-Plane has no AUX probes)
    local h = out.probe_heat
    local v = flag(h[1])
    if simDR_pitot_heat_pilot ~= v then simDR_pitot_heat_pilot = v end
    if simDR_static_heat_pilot ~= v then simDR_static_heat_pilot = v end
    v = flag(h[2])
    if simDR_pitot_heat_copilot ~= v then simDR_pitot_heat_copilot = v end
    if simDR_static_heat_copilot ~= v then simDR_static_heat_copilot = v end
    v = flag(h[3])
    if simDR_pitot_heat_stby ~= v then simDR_pitot_heat_stby = v end
    v = flag(h[4])
    if simDR_static_heat_stby ~= v then simDR_static_heat_stby = v end
    v = flag(h[5])
    if simDR_aoa_heat_pilot ~= v then simDR_aoa_heat_pilot = v end
    v = flag(h[6])
    if simDR_aoa_heat_copilot ~= v then simDR_aoa_heat_copilot = v end
    v = flag(h[7])
    if simDR_tat_heat_pilot ~= v then simDR_tat_heat_pilot = v end
    v = flag(h[8])
    if simDR_tat_heat_copilot ~= v then simDR_tat_heat_copilot = v end
    for p = 1, 8 do put(B747DR_CAS_advisory_status, ADV_PROBE[p], flag(out.probe_alert[p])) end
    local detect = flag(out.detector_on)
    if simDR_ice_detect_on ~= detect then simDR_ice_detect_on = detect end
    put(B747DR_CAS_caution_status, CAUT_ICING, flag(out.icing_alert))
    put(B747DR_CAS_advisory_status, ADV_NO_ICING, flag(out.no_icing_alert))
    put(B747DR_CAS_advisory_status, ADV_ANTI_ICE, flag(out.anti_ice_alert))
    put(B747DR_CAS_advisory_status, ADV_ICE_DETECTORS, flag(out.detectors_alert))
    put(B747DR_CAS_status_status, STATUS_ICE_DETECTOR, flag(out.detector_status[1]))
    put(B747DR_CAS_status_status, STATUS_ICE_DETECTOR + 1, flag(out.detector_status[2]))
    if simDR_version < 120000 then
        local speed = math.max(out.wiper_speed[1], out.wiper_speed[2])
        if simDR_windshield_wiper_speedXP11 ~= speed then simDR_windshield_wiper_speedXP11 = speed end
    else
        put(simDR_windshield_wiper_speed, 0, out.wiper_speed[1])
        put(simDR_windshield_wiper_speed, 1, out.wiper_speed[2])
    end
end

function B747_antiice()
    ice_t = ice_t + SIM_PERIOD
    read_inputs(ice_inputs)
    write_outputs(I.update(ice_state, ice_inputs, SIM_PERIOD))
end


----- MONITOR AI FOR AUTO-BOARD CALL ----------------------------------------------------
function B747_ice_monitor_AI()

    if B747DR_init_ice_CD == 1 then
        B747_set_ice_all_modes()
        B747_set_ice_CD()
        B747DR_init_ice_CD = 2
    end

end


----- SET STATE FOR ALL MODES -----------------------------------------------------------
function B747_set_ice_all_modes()

	B747DR_init_ice_CD = 0

end


----- SET STATE TO COLD & DARK ----------------------------------------------------------
function B747_set_ice_CD()

    B747DR_windshield_wiper_sel_L_pos = 0
    B747DR_windshield_wiper_sel_R_pos = 0

end


----- SET STATE TO ENGINES RUNNING ------------------------------------------------------
function B747_set_ice_ER()

end


----- FLIGHT START ----------------------------------------------------------------------
function B747_flight_start_antiIce()

    -- ALL MODES ------------------------------------------------------------------------
    B747_set_ice_all_modes()
    ice_state = I.new()
    ice_t = 0

    -- COLD & DARK ----------------------------------------------------------------------
    if simDR_startup_running == 0 then

        B747_set_ice_CD()

    -- ENGINES RUNNING ------------------------------------------------------------------
    elseif simDR_startup_running == 1 then

		B747_set_ice_ER()

    end

end


--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

function flight_start()

    B747_flight_start_antiIce()

end

debug_antiice     = deferred_dataref("laminar/B747/debug/antiice", "number")
function after_physics()
    if debug_antiice > 0 then return end

    B747_antiice()
    B747_ice_monitor_AI()

end
