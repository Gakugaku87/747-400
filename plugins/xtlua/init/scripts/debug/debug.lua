function deferred_dataref(name,type,notifier)
	--print("Deffereed dataref: "..name)
	dref=XLuaCreateDataRef(name, type,"yes",notifier)
	return wrap_dref_any(dref,type) 
end

manipulators     = deferred_dataref("laminar/B747/debug/manipulators", "number")
electrical     = deferred_dataref("laminar/B747/debug/electrical", "number")
gear     = deferred_dataref("laminar/B747/debug/gear", "number")
com     = deferred_dataref("laminar/B747/debug/com", "number")
hydro     = deferred_dataref("laminar/B747/debug/hydro", "number")
fuel     = deferred_dataref("laminar/B747/debug/fuel", "number")
fltmgmt     = deferred_dataref("laminar/B747/debug/fltmgmt", "number")
fire     = deferred_dataref("laminar/B747/debug/fire", "number")
engines     = deferred_dataref("laminar/B747/debug/engines", "number")
fltctrls     = deferred_dataref("laminar/B747/debug/fltctrls", "number")
antiice     = deferred_dataref("laminar/B747/debug/antiice", "number")
air     = deferred_dataref("laminar/B747/debug/air", "number")
fltinst     = deferred_dataref("laminar/B747/debug/fltinst", "number")
fms     = deferred_dataref("laminar/B747/debug/fms", "number")
autopilot     = deferred_dataref("laminar/B747/debug/autopilot", "number")
safety     = deferred_dataref("laminar/B747/debug/safety", "number")
warning     = deferred_dataref("laminar/B747/debug/warning", "number")
lighting     = deferred_dataref("laminar/B747/debug/lighting", "number")
ecc     = deferred_dataref("laminar/B747/debug/ecc", "number")
ai     = deferred_dataref("laminar/B747/debug/ai", "number")
fd     = deferred_dataref("laminar/B747/debug/flight_directors", "number")
-- 1: no drag corrections (B747.45.xt.aero_corr.lua), for comparing in X-Plane
aero_corr_off     = deferred_dataref("laminar/B747/debug/aero_corr_off", "number")
-- (2026-11-22) 1: the pitch corrections' downwash (stab_downwash) or the
-- thrust's moment (stab_thrust) left out (B747.45.xt.aero_corr.lua), for
-- finding the cruise's pitch swing in X-Plane
aero_dw_off     = deferred_dataref("laminar/B747/debug/aero_dw_off", "number")
aero_tm_off     = deferred_dataref("laminar/B747/debug/aero_tm_off", "number")
-- (2026-11-24) the downwash's correction in percent of its own (0: its own),
-- for finding the low speed's pitch swing in X-Plane (the 2026-11-23
-- review's FCTL-1)
aero_dw_pct     = deferred_dataref("laminar/B747/debug/aero_dw_pct", "number")
-- the same for the thrust's moment's correction
aero_tm_pct     = deferred_dataref("laminar/B747/debug/aero_tm_pct", "number")
-- 1: the acf's own SFC figures above FL370 too (B747.42.xt.sfc_corr.lua),
-- for comparing in X-Plane and for SFC sweeps
sfc_corr_off     = deferred_dataref("laminar/B747/debug/sfc_corr_off", "number")
