--[[
*****************************************************************************************
* Program Script Name	:	B747.36.oxygen
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2026-10-24						The crew and passenger oxygen (notes/ATA-35.md)
*
*****************************************************************************************
--]]

-- The oxygen model (B747.36.oxygen_model.lua) in the aircraft: reads the
-- cabin altitude, the PASS OXYGEN and THERAPEUTIC OXYGEN switches and the
-- crew masks (commands: the 3D cockpit has no oxygen controls), the forward
-- cargo temperature (the cylinders), the DC buses and X-Plane's passenger
-- oxygen failure; writes the cylinder pressures (the STATUS page), the
-- passenger and therapeutic oxygen (the lighting module's signs), the EICAS
-- messages, and X-Plane's oxygen: the altitude the crew feel and the crew
-- cylinder.

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

dofile("B747.36.oxygen_model.lua")
local O = B747_oxygen_model


--*************************************************************************************--
--** 				                X-PLANE DATAREFS            			    	 **--
--*************************************************************************************--

simDR_cabin_altitude                = find_dataref("sim/cockpit2/pressurization/indicators/cabin_altitude_ft")
simDR_override_oxygen               = find_dataref("sim/operation/override/override_oxygen_system")
simDR_felt_altitude                 = find_dataref("sim/cockpit2/oxygen/indicators/pilot_felt_altitude_ft")
simDR_o2_bottle_psi                 = find_dataref("sim/cockpit2/oxygen/indicators/o2_bottle_pressure_psi")
simDR_o2_valve_on                   = find_dataref("sim/cockpit2/oxygen/actuators/o2_valve_on")
simDR_fail_pass_o2_on               = find_dataref("sim/operation/failures/rel_pass_o2_on")


--*************************************************************************************--
--** 				              FIND CUSTOM DATAREFS             			    	 **--
--*************************************************************************************--

B747DR_oxy_elec_dc                  = find_dataref("laminar/B747/electrical/bus/dc")
B747DR_oxy_cargo_temp               = find_dataref("laminar/B747/air/temp/cargo")
B747DR_CAS_advisory_status          = find_dataref("laminar/B747/CAS/advisory_status")
B747DR_CAS_status_status            = find_dataref("laminar/B747/CAS/status_status")
B747DR_CAS_memo_status              = find_dataref("laminar/B747/CAS/memo_status")


--*************************************************************************************--
--** 				        CREATE READ-ONLY CUSTOM DATAREFS               	         **--
--*************************************************************************************--

B747DR_oxy_crew_press               = deferred_dataref("laminar/B747/oxygen/crew_press_psi", "number")
B747DR_oxy_pass_press               = deferred_dataref("laminar/B747/oxygen/pass_press_psi", "number")
B747DR_oxy_pass_sw_pos              = deferred_dataref("laminar/B747/oxygen/pass_oxy_sw_pos", "number")
B747DR_oxy_therap_sw_pos            = deferred_dataref("laminar/B747/oxygen/therap_oxy_sw_pos", "number")
B747DR_oxy_crew_mask_on             = deferred_dataref("laminar/B747/oxygen/crew_mask_on", "number")
B747DR_oxy_pass_on                  = deferred_dataref("laminar/B747/oxygen/pass_oxy_on", "number")
B747DR_oxy_therap_on                = deferred_dataref("laminar/B747/oxygen/therap_oxy_on", "number")


--*************************************************************************************--
--** 				              CUSTOM COMMAND HANDLERS            			     **--
--*************************************************************************************--

-- A spring-loaded position springs back to NORM 0.3 s after the command's
-- last event: XTLua does not always pass the end of a press shorter than
-- a frame (X-Plane's "once"). A press that short still reaches the model.
local SPRING_S = 0.3
local pass_pressed, therap_pressed = 0, 0
local pass_spring, therap_spring = 0, 0

-- PASS OXYGEN: ON and RESET spring back to NORM (FCOM p.456)
function B747_oxy_pass_sw_on_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_oxy_pass_sw_pos = 1
        pass_pressed = 1
    end
    if phase < 2 then pass_spring = SPRING_S else pass_spring = 0 end
end
function B747_oxy_pass_sw_reset_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_oxy_pass_sw_pos = -1
        pass_pressed = -1
    end
    if phase < 2 then pass_spring = SPRING_S else pass_spring = 0 end
end

-- THERAPEUTIC OXYGEN: RESET springs back to NORM, ON stays (FCOM p.457)
function B747_oxy_therap_sw_up_CMDhandler(phase, duration)
    if phase == 0 then B747DR_oxy_therap_sw_pos = math.min(B747DR_oxy_therap_sw_pos + 1, 1) end
end
function B747_oxy_therap_sw_dn_CMDhandler(phase, duration)
    if phase == 0 then
        B747DR_oxy_therap_sw_pos = math.max(B747DR_oxy_therap_sw_pos - 1, -1)
        if B747DR_oxy_therap_sw_pos < 0 then therap_pressed = -1 end
    end
    if phase < 2 then therap_spring = SPRING_S else therap_spring = 0 end
end

-- the crew masks: out of their boxes, or stowed and RESET/TEST pushed (FCOM p.511)
function B747_oxy_crew_masks_toggle_CMDhandler(phase, duration)
    if phase == 0 then B747DR_oxy_crew_mask_on = 1 - B747DR_oxy_crew_mask_on end
end


--*************************************************************************************--
--** 				              CREATE CUSTOM COMMANDS              			     **--
--*************************************************************************************--

B747CMD_oxy_pass_sw_on              = deferred_command("laminar/B747/oxygen/pass_oxy_sw_on", "Passenger Oxygen Switch ON (hold)", B747_oxy_pass_sw_on_CMDhandler)
B747CMD_oxy_pass_sw_reset           = deferred_command("laminar/B747/oxygen/pass_oxy_sw_reset", "Passenger Oxygen Switch RESET (hold)", B747_oxy_pass_sw_reset_CMDhandler)
B747CMD_oxy_therap_sw_up            = deferred_command("laminar/B747/oxygen/therap_oxy_sw_up", "Therapeutic Oxygen Switch Up", B747_oxy_therap_sw_up_CMDhandler)
B747CMD_oxy_therap_sw_dn            = deferred_command("laminar/B747/oxygen/therap_oxy_sw_dn", "Therapeutic Oxygen Switch Down (RESET: hold)", B747_oxy_therap_sw_dn_CMDhandler)
B747CMD_oxy_crew_masks_toggle       = deferred_command("laminar/B747/oxygen/crew_masks_toggle", "Crew Oxygen Masks On/Stow", B747_oxy_crew_masks_toggle_CMDhandler)


--*************************************************************************************--
--** 				                  SYSTEM FUNCTIONS           	    			 **--
--*************************************************************************************--

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_CREW_OXY_LOW, ADV_PASS_OXY_ON = 53, 256
local STATUS_PASS_OXY_ON = 39
local MEMO_THERAP_OXY_ON = 36

local oxy_state = O.new()
local oxy_inputs = O.inputs()

local function flag(v)
    if v then return 1 end
    return 0
end

local function springs(dt)
    if B747DR_oxy_pass_sw_pos ~= 0 then
        pass_spring = pass_spring - dt
        if pass_spring <= 0 then B747DR_oxy_pass_sw_pos = 0 end
    end
    if B747DR_oxy_therap_sw_pos < 0 then
        therap_spring = therap_spring - dt
        if therap_spring <= 0 then B747DR_oxy_therap_sw_pos = 0 end
    end
end

local function read_inputs(inp)
    inp.cabin_alt_ft = simDR_cabin_altitude
    inp.pass_sw = B747DR_oxy_pass_sw_pos
    if inp.pass_sw == 0 then inp.pass_sw = pass_pressed end
    pass_pressed = 0
    inp.therap_sw = B747DR_oxy_therap_sw_pos
    if inp.therap_sw == 0 then inp.therap_sw = therap_pressed end
    therap_pressed = 0
    inp.crew_masks = B747DR_oxy_crew_mask_on > 0.5
    inp.dc = B747DR_oxy_elec_dc[0] > 0.5 or B747DR_oxy_elec_dc[1] > 0.5 or B747DR_oxy_elec_dc[2] > 0.5
        or B747DR_oxy_elec_dc[3] > 0.5
    inp.cylinder_c = B747DR_oxy_cargo_temp[0]   -- the cylinders are in the forward cargo compartment
    inp.pass_failed_on = simDR_fail_pass_o2_on == 6
end

-- datarefs: read first, write when different (TESTING.md §1.2)
local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

local function write_outputs(out)
    local crew, pass = math.floor(out.crew_psi + 0.5), math.floor(out.pass_psi + 0.5)
    if B747DR_oxy_crew_press ~= crew then B747DR_oxy_crew_press = crew end
    if B747DR_oxy_pass_press ~= pass then B747DR_oxy_pass_press = pass end
    local pass_on, therap_on = flag(out.pass_on), flag(out.therap_on)
    if B747DR_oxy_pass_on ~= pass_on then B747DR_oxy_pass_on = pass_on end
    if B747DR_oxy_therap_on ~= therap_on then B747DR_oxy_therap_on = therap_on end
    put(B747DR_CAS_advisory_status, ADV_CREW_OXY_LOW, flag(out.crew_low_alert))
    put(B747DR_CAS_advisory_status, ADV_PASS_OXY_ON, flag(out.pass_on_alert))
    put(B747DR_CAS_status_status, STATUS_PASS_OXY_ON, flag(out.pass_on_status))
    put(B747DR_CAS_memo_status, MEMO_THERAP_OXY_ON, flag(out.therap_memo))
    -- X-Plane's oxygen, taken over (init B747.36.oxygen)
    if simDR_override_oxygen ~= 1 then simDR_override_oxygen = 1 end
    if math.abs(simDR_felt_altitude - out.felt_alt_ft) > 1 then simDR_felt_altitude = out.felt_alt_ft end
    if simDR_o2_bottle_psi ~= crew then simDR_o2_bottle_psi = crew end
    local valve = flag(out.crew_flow)
    if simDR_o2_valve_on ~= valve then simDR_o2_valve_on = valve end
end

function B747_oxygen()
    springs(SIM_PERIOD)
    read_inputs(oxy_inputs)
    write_outputs(O.update(oxy_state, oxy_inputs, SIM_PERIOD))
end


----- FLIGHT START ----------------------------------------------------------------------
-- full cylinders, the switches in NORM, the masks stowed (estimate: the
-- sources give no dispatch pressures; FCOM p.455 shows 1850 and 1850)
function B747_flight_start_oxygen()
    oxy_state = O.new()
    pass_pressed, therap_pressed = 0, 0
    pass_spring, therap_spring = 0, 0
    B747DR_oxy_pass_sw_pos = 0
    B747DR_oxy_therap_sw_pos = 0
    B747DR_oxy_crew_mask_on = 0
end


--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

function flight_start()
    B747_flight_start_oxygen()
end

function after_physics()
    B747_oxygen()
end
