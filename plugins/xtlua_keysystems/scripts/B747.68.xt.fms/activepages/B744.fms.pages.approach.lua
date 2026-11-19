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

-- (2026-11-19, notes/ATA-34-61-FMC.md §170 1) the runway length line (4L;
-- FCOM p.1409-1411): the departure runway's until the destination runway
-- (the active approach's) is in the active route and the airplane is more
-- than 50 NM from the departure airport or halfway to the destination;
-- then the destination runway's. The airport and the runway in the header
-- ("KBFI13R"), the length in feet and meters (FT and M small: p.1409's
-- figure). Blank without an active route or the runway: the flight
-- completion clears the route ("Display clears at flight completion").
-- Estimates: halfway from the direct distances from the departure airport
-- and to the destination (as the landing altitude's,
-- B747.68.ldgalt_model.lua); the length REF NAV DATA's (B747_navdb.
-- runway_length: the CIFP has none); a shorter number left-aligned with
-- FT after it; blank once switched to an approach without a runway.
-- Before: fixed boxes (*****  **** and *******).
local APPR_RWY_SWITCH_NM = 50
-- the line's header, feet and meters (nil, nil, nil: blank)
function B747_fms_appr_runway()
	local st = B747_fmc_route
	local r = st and st.active and st.rte or nil
	if not r then return nil end
	local N = B747_navdb
	local o, d = r.origin, r.dest
	local apt, id = nil, nil
	if d and r.appr then
		local lat, lon = simDR_latitude, simDR_longitude
		local from = o and o.lat and N.distance(o.lat, o.lon, lat, lon) or nil
		local to = d.lat and N.distance(lat, lon, d.lat, d.lon) or nil
		if o == nil or (from and from > APPR_RWY_SWITCH_NM) or (from and to and from > to) then
			if not r.appr.rwy then return nil end
			apt, id = d, r.appr.rwy
		end
	end
	if apt == nil and o and r.runway then apt, id = o, r.runway.ident end
	if apt == nil then return nil end
	local ft = N.runway_length(N.cifp(B747_fmc_navdb, apt.ident), id)
	if ft == nil then return nil end
	return apt.ident .. id:gsub("^RW", ""), math.floor(ft + 0.5), math.floor(ft * 0.3048 + 0.5)
end

fmsPages["APPROACH"]=createPage("APPROACH")
fmsPages["APPROACH"].getPage=function(self,pgNo,fmsID)--dynamic pages need to be this way
	local o = fmsModules[fmsID]
	local gw = B747_fms_appr_gw(o)
	local gwText = gw and string.format("%5.1f", perf_out(gw)) or "***.*"
	local v25, v30 = B747_fms_appr_vref(o, 25), B747_fms_appr_vref(o, 30)
	local function vref(v) return v and string.format("%3d", v) or "   " end
	local _, ft, m = B747_fms_appr_runway()
	local len = ft and (ft .. "  " .. m) or ""
    return{
"      APPROACH REF      ",
"                        ",
gwText .. "              " .. vref(v25),
"                        ",
"                   " .. vref(v30),
"                        ",
"                        ",
"                        ",
string.format("%-18s", len) .. fmsModules["data"]["flapspeed"] ,
"                        ",
"                        ",
"------------------------",
"<INDEX       THRUST LIM>"
    }
end

fmsPages["APPROACH"].getSmallPage=function(self,pgNo,fmsID)
	local o = fmsModules[fmsID]
	local blank = B747_fms_appr_gw(o) == nil
	local hdr, ft, m = B747_fms_appr_runway()
	local units = ft and (string.rep(" ", #tostring(ft)) .. "FT" .. string.rep(" ", #tostring(m)) .. "M") or ""
    return{

"                        ",
" GROSS WT   FLAPS   VREF",
blank and "             25`        " or "             25`      KT",
"                        ",
blank and "             30`        " or "             30`      KT",
"                        ",
"                        ",
" " .. string.format("%-13s", hdr or "") .. "FLAP/SPEED",
string.format("%-24s", units),
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
