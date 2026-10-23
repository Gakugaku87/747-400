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

-- The datarefs and commands of the oxygen module (B747.36.xt.oxygen). The
-- 3D cockpit has no oxygen controls: the PASS OXYGEN and THERAPEUTIC OXYGEN
-- switches and the crew masks are commands (for key bindings).

function null_command(phase, duration)
end
--replace create command
function deferred_command(name,desc,nilFunc)
	c = XLuaCreateCommand(name,desc)
	return nil
end
--replace create_dataref
function deferred_dataref(name,type,notifier)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type)
end

-- the cylinders' pressures on the STATUS page (psi)
B747DR_oxy_crew_press               = deferred_dataref("laminar/B747/oxygen/crew_press_psi", "number")
B747DR_oxy_pass_press               = deferred_dataref("laminar/B747/oxygen/pass_press_psi", "number")
-- the switches: -1 RESET, 0 NORM, 1 ON (PASS OXYGEN: RESET and ON spring-loaded;
-- THERAPEUTIC OXYGEN: RESET spring-loaded)
B747DR_oxy_pass_sw_pos              = deferred_dataref("laminar/B747/oxygen/pass_oxy_sw_pos", "number")
B747DR_oxy_therap_sw_pos            = deferred_dataref("laminar/B747/oxygen/therap_oxy_sw_pos", "number")
-- the crew masks out of their boxes (1)
B747DR_oxy_crew_mask_on             = deferred_dataref("laminar/B747/oxygen/crew_mask_on", "number")
-- the passenger and therapeutic oxygen actuated (1; the lighting module's signs read it)
B747DR_oxy_pass_on                  = deferred_dataref("laminar/B747/oxygen/pass_oxy_on", "number")
B747DR_oxy_therap_on                = deferred_dataref("laminar/B747/oxygen/therap_oxy_on", "number")

B747CMD_oxy_pass_sw_on              = deferred_command("laminar/B747/oxygen/pass_oxy_sw_on", "Passenger Oxygen Switch ON (hold)", B747_oxy_pass_sw_on_CMDhandler)
B747CMD_oxy_pass_sw_reset           = deferred_command("laminar/B747/oxygen/pass_oxy_sw_reset", "Passenger Oxygen Switch RESET (hold)", B747_oxy_pass_sw_reset_CMDhandler)
B747CMD_oxy_therap_sw_up            = deferred_command("laminar/B747/oxygen/therap_oxy_sw_up", "Therapeutic Oxygen Switch Up", B747_oxy_therap_sw_up_CMDhandler)
B747CMD_oxy_therap_sw_dn            = deferred_command("laminar/B747/oxygen/therap_oxy_sw_dn", "Therapeutic Oxygen Switch Down (RESET: hold)", B747_oxy_therap_sw_dn_CMDhandler)
B747CMD_oxy_crew_masks_toggle       = deferred_command("laminar/B747/oxygen/crew_masks_toggle", "Crew Oxygen Masks On/Stow", B747_oxy_crew_masks_toggle_CMDhandler)

-- X-Plane's oxygen system is taken over: the module writes the altitude the
-- crew feel (X-Plane's hypoxia) and the crew cylinder's pressure
simDR_override_oxygen               = find_dataref("sim/operation/override/override_oxygen_system")
function aircraft_load()
    simDR_override_oxygen = 1
end
function aircraft_unload()
    simDR_override_oxygen = 0
end
