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

-- The navigation sensors (PLAN 5-1; notes/ATA-34.md §10): the air data
-- (B747.34.xt.airdata.lua, step 1), the IRS and the GPS (B747.34.xt.irs.lua,
-- B747.34.xt.gps.lua, step 2), the radio altimeters and the GPWS
-- (B747.34.xt.ra.lua, B747.34.xt.gpws.lua, step 4), the transponders and
-- the TCAS (B747.34.xt.tcas.lua, step 5), the weather radar control
-- (B747.34.xt.wxr.lua, step 5c).
-- Each glue runs its model every frame.

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

-- the glues' helpers: 1/0 from a flag; an array element written only when it changes
function B747_nav_flag(v)
    if v then return 1 end
    return 0
end

function B747_nav_put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

-- the air data: the ADCs, the source selection, OVERSPEED, the disagree
-- messages, the altitude alert
dofile("B747.34.xt.airdata.lua")
-- the IRS: the IRUs, alignment, the position entry, ATT, power, messages
dofile("B747.34.xt.irs.lua")
-- the GPS: power, the first fix, failures, messages
dofile("B747.34.xt.gps.lua")
-- the radio altimeters: power, failures, each PFD's source, the GPWC's
dofile("B747.34.xt.ra.lua")
-- the GPWS: modes 1-7, the callouts, the GND PROX panel, lights, messages
dofile("B747.34.xt.gpws.lua")
-- the transponders and the TCAS: X-Plane's transponder, TA/RA, the ND's
-- traffic and messages, the voices, messages
dofile("B747.34.xt.tcas.lua")
-- the weather radar control: the 570 panel, the R/T, X-Plane's radar for each ND
dofile("B747.34.xt.wxr.lua")


--*************************************************************************************--
--** 				                  EVENT CALLBACKS           	    			 **--
--*************************************************************************************--

function flight_start()
    B747_airdata_flight_start()
    B747_irs_flight_start()
    B747_gps_flight_start()
    B747_ra_flight_start()
    B747_gpws_flight_start()
    B747_tcas_flight_start()
    B747_wxr_flight_start()
end

function after_physics()
    B747_airdata()
    B747_irs()
    B747_gps()
    B747_ra()
    B747_gpws()
    B747_tcas()
    B747_wxr()
end
