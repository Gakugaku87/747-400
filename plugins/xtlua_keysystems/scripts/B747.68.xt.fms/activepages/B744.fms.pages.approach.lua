-- Very minor modification by crazytimtimtim
-- APPROACH REF (6-1/6-2 step 3d; FCOM p.1409-1412): GROSS WT the FMC's
-- (boxes without one) or an entry (XXX.X, kept until the CDU leaves the
-- page); FLAPS VREF for 25 and 30 at the weight shown and the landing
-- altitude (B747.68.vref_model.lua), blank without a weight; 1R and 2R
-- copy them to the scratchpad. Before: the airplane's weight from X-Plane
-- and the PFD's VREFs, an entry not shown.
local apprGW = {}       -- the entered gross weight (t) by CDU
-- the gross weight (t) a CDU shows: entered, else the FMC's (nil: none)
function B747_fms_appr_gw(fmsO)
	return apprGW[fmsO.id] or perf_gw_t()
end
-- the VREF (whole kt) a CDU shows for flaps 25 or 30; nil without a weight
function B747_fms_appr_vref(fmsO, flaps)
	local gw = B747_fms_appr_gw(fmsO)
	if gw == nil then return nil end
	return math.floor(B747_vref_model.vref(flaps, gw * 1000, B747_fms_vref_elev()) + 0.5)
end
-- GROSS WT's entry (PERF INIT's limits); DELETE: the FMC's again
function B747_fms_appr_gw_entry(fmsO, del)
	if del then apprGW[fmsO.id] = nil return end
	local v = B747_cdu_model.parse_weight(fmsO["scratchpad"])
	local t = v and perf_in(v)
	if t == nil or t < 150 or t > 400 then fmsO["notify"] = "INVALID ENTRY" return end
	apprGW[fmsO.id] = t
	fmsO["scratchpad"] = ""
end
-- each frame: an entry goes when its CDU leaves the page
function update_appr_ref()
	for id in pairs(apprGW) do
		local o = fmsModules[id]
		if o == nil or o.currentPage ~= "APPROACH" then apprGW[id] = nil end
	end
end

fmsPages["APPROACH"]=createPage("APPROACH")
fmsPages["APPROACH"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
	local o = fmsModules[fmsID]
	local gw = B747_fms_appr_gw(o)
	local gwText = gw and string.format("%5.1f", perf_out(gw)) or "***.*"
	local v25, v30 = B747_fms_appr_vref(o, 25), B747_fms_appr_vref(o, 30)
	local function vref(v) return v and string.format("%3d", v) or "   " end
    return{
"      APPROACH REF      ",
"                        ",
gwText .. "              " .. vref(v25),
"                        ",
"                   " .. vref(v30),
"                        ",
"                        ",
"                        ",
"*****  ****       "..fmsModules["data"]["flapspeed"] ,
"                        ",
"                        ",
"------------------------",
"<INDEX       THRUST LIM>"
    }
end

fmsPages["APPROACH"].getSmallPage=function(self,pgNo,fmsID)
	local o = fmsModules[fmsID]
	local blank = B747_fms_appr_gw(o) == nil
    return{

"                        ",
" GROSS WT   FLAPS   VREF",
blank and "             25`        " or "             25`      KT",
"                        ",
blank and "             30`        " or "             30`      KT",
"                        ",
"                        ",
" *******      FLAP/SPEED",
"     FT    M            ",
"                        ",
"                        ",
"------------------------",
"                        "
    }
	end

fmsFunctionsDefs["APPROACH"]={}
fmsFunctionsDefs["APPROACH"]["L6"]={"setpage","INITREF"}
fmsFunctionsDefs["APPROACH"]["R6"]={"setpage","THRUSTLIM"}
fmsFunctionsDefs["APPROACH"]["L1"]={"setdata","grosswt"}
fmsFunctionsDefs["APPROACH"]["R1"]={"setdata","vref1"}
fmsFunctionsDefs["APPROACH"]["R2"]={"setdata","vref2"}
fmsFunctionsDefs["APPROACH"]["R4"]={"setdata","flapspeed"}
