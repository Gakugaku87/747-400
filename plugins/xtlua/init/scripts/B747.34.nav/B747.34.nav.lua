--[[
*****************************************************************************************
* Program Script Name	:	B747.34.nav
*
*   Revisions:
*   -- DATE --	--- REV NO ---		--- DESCRIPTION ---
*   2026-10-25						The navigation sensors (notes/ATA-34.md, 5-1)
*
*****************************************************************************************
--]]

function deferred_dataref(name,type,notifier)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type)
end

-- The air data (B747.34.airdata_model.lua, ARCHITECTURE.md): the ADC on each
-- pilot's displays (1 L, 2 C, 3 R), each ADC valid (power, not failed) and
-- each pilot's air data valid (for the PFD's SPD, ALT and MACH flags), the
-- altitude alert's white box (approaching) and amber box (departing), each
-- PFD's altitude (ft, that pilot's baro setting) and Mach from the selected
-- ADC; failures (L and R also from X-Plane's ADC failures): each ADC.
B747DR_airdata_src_capt         = deferred_dataref("laminar/B747/airdata/src_capt", "number")
B747DR_airdata_src_fo           = deferred_dataref("laminar/B747/airdata/src_fo", "number")
B747DR_airdata_valid            = deferred_dataref("laminar/B747/airdata/valid", "array[3]")
B747DR_airdata_valid_capt       = deferred_dataref("laminar/B747/airdata/valid_capt", "number")
B747DR_airdata_valid_fo         = deferred_dataref("laminar/B747/airdata/valid_fo", "number")
B747DR_airdata_alt_advise       = deferred_dataref("laminar/B747/airdata/alt_advise", "number")
B747DR_airdata_alt_alert        = deferred_dataref("laminar/B747/airdata/alt_alert", "number")
B747DR_airdata_alt_capt         = deferred_dataref("laminar/B747/airdata/alt_capt", "number")
B747DR_airdata_alt_fo           = deferred_dataref("laminar/B747/airdata/alt_fo", "number")
B747DR_airdata_mach_capt        = deferred_dataref("laminar/B747/airdata/mach_capt", "number")
B747DR_airdata_mach_fo          = deferred_dataref("laminar/B747/airdata/mach_fo", "number")
B747DR_airdata_fail             = deferred_dataref("laminar/B747/airdata/fail/adc", "array[3]")
