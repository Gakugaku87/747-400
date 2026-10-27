
-- small modification by crazytimtimtim

B747DR_airspeed_V1                              = deferred_dataref("laminar/B747/airspeed/V1", "number")
B747DR_airspeed_Vr                              = deferred_dataref("laminar/B747/airspeed/Vr", "number")
B747DR_airspeed_V2                              = deferred_dataref("laminar/B747/airspeed/V2", "number")
cg_lineLg	= ""
cg_lineSm	= ""
clbF_Sm = ""

function roundToIncrement(number, increment)

    local y = number / increment
    local q = math.floor(y + 0.5)
    local z = q * increment

    return z

end
--simDR_wing_flap1_deg                = find_dataref("sim/flightmodel2/wing/flap1_deg")
B747DR_airspeed_flapsRef                              = find_dataref("laminar/B747/airspeed/flapsRef")
-- the takeoff speeds (6-1/6-2 step 3b; FCOM p.1319-1320): the FMC's
-- (airspeed/V1_ref, Vr_ref, V2_ref: small font, REF and the caret) until
-- selected (the line select key with an empty scratchpad) or entered (100
-- to 300 kt: FMSPG p.107), then large; the selected ones go to the PFD
-- (airspeed/V1, Vr, V2; 999: NO V SPD). Deleted: the FMC's again. A change
-- of the performance data deletes the selected ones (TAKEOFF SPEEDS
-- DELETED), and so does, after the third engine start, a computed speed
-- changing by more than 1 kt (FCOM p.1320). Above 1,000 ft (the flaps
-- reset: B747.60.xt.fltInst02.lua) they go without a message.
B747DR_airspeed_V1_ref = find_dataref("laminar/B747/airspeed/V1_ref")
B747DR_airspeed_Vr_ref = find_dataref("laminar/B747/airspeed/Vr_ref")
B747DR_airspeed_V2_ref = find_dataref("laminar/B747/airspeed/V2_ref")
simDR_takeoff_eng_running = find_dataref("sim/flightmodel/engine/ENGN_running")
local TO_SEL = {V1 = "v1sel", VR = "vrsel", V2 = "v2sel"}
local TO_KEYS = {"V1", "VR", "V2"}
local toRefAtSel = {}
local function to_ref(k)
	if k == "V1" then return B747DR_airspeed_V1_ref end
	if k == "VR" then return B747DR_airspeed_Vr_ref end
	return B747DR_airspeed_V2_ref
end
local function to_sel(k)
	return tonumber(fmsModules["data"][TO_SEL[k]])
end
function takeoff_speeds_selected()
	for _, k in ipairs(TO_KEYS) do
		if to_sel(k) then return true end
	end
	return false
end
local function clear_takeoff_speeds()
	for _, k in ipairs(TO_KEYS) do
		fmsModules:setData(TO_SEL[k], "   ")
		toRefAtSel[k] = nil
	end
end
-- the performance data changed: the selected speeds go, TAKEOFF SPEEDS
-- DELETED on every CDU (an FMC advisory: laminar/B747/fms/notification)
function takeoff_speeds_deleted()
	if not takeoff_speeds_selected() then return end
	clear_takeoff_speeds()
	B747DR_fmc_notifications[44] = 1
end
-- a V speed line's key: select the FMC's (empty scratchpad), enter, delete
function takeoff_speed_entry(fmsO, k)
	local sp = fmsO["scratchpad"]
	if sp == "DELETE" then
		fmsModules:setData(TO_SEL[k], "   ")
		toRefAtSel[k] = nil
		fmsO["scratchpad"] = ""
		return
	end
	local v
	if sp == "" then
		local ref = to_ref(k)
		if ref == nil or ref >= 999 then fmsO["notify"] = "INVALID ENTRY" return end
		v = ref
		toRefAtSel[k] = ref
	else
		v = B747_cdu_model.parse_int(sp, 100, 300)
		if v == nil then fmsO["notify"] = "INVALID ENTRY" return end
		toRefAtSel[k] = nil
	end
	fmsModules:setData(TO_SEL[k], string.format("%3d", v))
	fmsO["scratchpad"] = ""
end
-- each frame: the PFD's speeds; the selections' end
function update_takeoff()
	if simDR_onGround ~= 1 and B747DR_airspeed_flapsRef == 0 and takeoff_speeds_selected() then
		clear_takeoff_speeds()
	end
	local running = 0
	for i = 0, 3 do
		if simDR_takeoff_eng_running[i] == 1 then running = running + 1 end
	end
	if running >= 3 and simDR_onGround == 1 then
		for _, k in ipairs(TO_KEYS) do
			local r = toRefAtSel[k]
			if r and to_sel(k) and math.abs(to_ref(k) - r) > 1 then
				takeoff_speeds_deleted()
				break
			end
		end
	end
	local v1, vr, v2 = to_sel("V1") or 999, to_sel("VR") or 999, to_sel("V2") or 999
	if B747DR_airspeed_V1 ~= v1 then B747DR_airspeed_V1 = v1 end
	if B747DR_airspeed_Vr ~= vr then B747DR_airspeed_Vr = vr end
	if B747DR_airspeed_V2 ~= v2 then B747DR_airspeed_V2 = v2 end
end
-- a V speed line: large (selected or dashes), small (the FMC's with the
-- caret) and the title
local function vspeed(k)
	local sel = to_sel(k)
	if sel then return string.format("%3d", sel), "    ", k end
	local ref = to_ref(k) or 999
	if ref < 999 then return "   ", string.format("%3d>", ref), "REF " .. k end
	return "---", "    ", "REF " .. k
end

fmsPages["TAKEOFF"]=createPage("TAKEOFF")
-- the TAKEOFF REF lines (6-1/6-2 step 3b; FCOM p.1318-1321): FLAP/ACCEL
-- HT, E/O ACCEL HT and THR REDUCTION (defaults 1000 FT, 1000 FT and FLAPS
-- 5 as FCOM's figure, small; entries large), WIND/SLOPE (dashes until
-- entered), TRIM/CG, POS SHIFT (RTE 1's runway: step 5b),
-- PRE-FLT (the first page not complete) or THRUST LIM
-- the performance data PERF INIT requires (the RTE page's 6R too: FCOM
-- p.1290)
function perf_init_complete()
  local d = fmsModules["data"]
  return perf_gw_t() ~= nil and d.crzalt ~= "*****" and tonumber(d.costindex) ~= nil and tonumber(d.reserves) ~= nil
end
local function preflight_page()
  if B747DR_nav_irs_set_pos == 1 then return "POSINIT", "POS INIT>" end
  -- the route until RTE 1 is activated (FCOM p.1290; step 5b)
  if not B747_fmc_route.active then return "RTE" .. B747_fmc_route.num, "ROUTE>" end
  if not perf_init_complete() then return "PERFINIT", "PERF INIT>" end
  return nil, "THRUST LIM>"
end
function takeoff_preflight()
  local page = preflight_page()
  return page or "THRUSTLIM"
end
local function set_text(k) return str_trim(fmsModules["data"][k]) ~= "" end
local function height_text(k) return str_trim(fmsModules["data"][k]) .. "FT" end
local function thrred_text()
  local v = str_trim(fmsModules["data"].thrred)
  if v == "5" then return "FLAPS 5" end
  return v .. "FT"
end
-- POS SHIFT's runway: RTE 1's departure runway (FCOM p.1321; step 5b)
local function shift_rwy()
  local r = B747_fmc_route.rte.runway
  return string.format("%-5s", r and r.ident or "RW***")
end
local function shift_text()
  local s = str_trim(fmsModules["data"].posshift)
  if s == "---" then return "--00M" end
  return s .. "00M"
end
fmsPages["TAKEOFF"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
  local flaps = string.format("%02d",roundToIncrement(B747DR_airspeed_flapsRef, 5))
  if B747DR_airspeed_flapsRef==0 then flaps="**" end
  local clbV=" "
  if clbderate>0 then
    clbV=""..clbderate
  end
	--Marauder28
	if string.len(cg_lineLg) == 0 then
		if str_trim(fmsModules["data"].cg_mac) == "--" then
			cg_lineSm = "--%"
		else
			cg_lineSm = string.format("%2.0f%%>", tonumber(fmsModules["data"].cg_mac))
		end
	else
		cg_lineLg = string.format("%2.0f%%", tonumber(fmsModules["data"].cg_mac))
		cg_lineSm = ""
	end
	--Marauder28
  local v1 = vspeed("V1")
  local vr = vspeed("VR")
  local v2 = vspeed("V2")
  local accel = set_text("accelset") and ("/" .. height_text("accelht")) or ""
  local eo = set_text("eoaccelset") and height_text("eoaccelht") or ""
  local thr = set_text("thrredset") and thrred_text() or ""
  local wind = str_trim(fmsModules["data"].towind) .. "/" .. str_trim(fmsModules["data"].toslope)
  local _, pre = preflight_page()
  return{
  "      TAKEOFF REF       ",
  "                        ",
  string.format("%-21s%s", flaps .. accel, v1),
  "                        ",
  string.format("%-21s%s", eo, vr),
  "                        ",
  string.format("%-8s CLB %1s       %s", thr, clbV, v2),
  "                        ",
  string.format("%-21s%-3s", wind, cg_lineLg),
  "                        ",
  "            " .. shift_rwy() .. " " .. string.format("%-6s", shift_text()),
  "                        ",
  string.format("<INDEX%18s", pre)
  }
end

fmsPages["TAKEOFF"].getSmallPage=function(self,pgNo,fmsID)

  --Marauder28
  local stab_trim = ""

  if string.len(cg_lineLg) > 0 then
	  if fmsModules["data"].stab_trim ~= "    " then
			stab_trim = string.format("%3.1f", tonumber(fmsModules["data"].stab_trim))
	  else
			stab_trim = fmsModules["data"].stab_trim
	  end
  end
  --Marauder28

  local _, v1S, v1T = vspeed("V1")
  local _, vrS, vrT = vspeed("VR")
  local _, v2S, v2T = vspeed("V2")
  local accel = set_text("accelset") and "" or ("  /" .. height_text("accelht"))
  local eo = set_text("eoaccelset") and "" or height_text("eoaccelht")
  local thr = set_text("thrredset") and "" or thrred_text()
  local page = preflight_page()
    return{

"                        ",
string.format(" FLAP/ACCEL HT%10s", v1T),
string.format("%-20s%s", accel, v1S),
string.format(" E/O ACCEL HT%11s", vrT),
string.format("%-20s%s", eo, vrS),
string.format(" THR REDUCTION%10s", v2T),
string.format("%-20s%s", thr, v2S),
" WIND/SLOPE    TRIM   CG",
"                "..string.format("%-4s", stab_trim).." "..string.format("%-3s", cg_lineSm),
"               POS SHIFT",
"                        ",
page and "-----------------PRE-FLT" or "------------------------",
"                        "
    }
end


fmsFunctionsDefs["TAKEOFF"]={}
fmsFunctionsDefs["TAKEOFF"]["L1"]={"setdata","toflaps"}
fmsFunctionsDefs["TAKEOFF"]["L2"]={"setdata","eoaccelht"}
fmsFunctionsDefs["TAKEOFF"]["L3"]={"setdata","thrred"}
fmsFunctionsDefs["TAKEOFF"]["L4"]={"setdata","towind"}
fmsFunctionsDefs["TAKEOFF"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["TAKEOFF"]["R1"]={"setDref","V1"}
fmsFunctionsDefs["TAKEOFF"]["R2"]={"setDref","VR"}
fmsFunctionsDefs["TAKEOFF"]["R3"]={"setDref","V2"}
fmsFunctionsDefs["TAKEOFF"]["R4"]={"setdata","cg_mac"}
fmsFunctionsDefs["TAKEOFF"]["R5"]={"setdata","posshift"}
fmsFunctionsDefs["TAKEOFF"]["R6"]={"setdata","topreflt"}
