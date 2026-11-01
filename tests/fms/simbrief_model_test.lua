-- Run from the repository root with LuaJIT: luajit tests/fms/simbrief_model_test.lua
-- The sim's airline operations from SimBrief's files (6-1/6-2 step 12h;
-- notes/ATA-34-61-FMC.md §122): X-Plane's .fms (1100 and 3), SimBrief's
-- OFP in XML, the flight plan uplink's elements (FMSPG p.372-376), the en
-- route winds and the descent forecast (FMSPG p.377-380), the ACARS text.
local T = dofile("tests/lib/check.lua")("simbrief_model")
local S = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.simbrief_model.lua")

local function read(name)
    local f = assert(io.open("tests/fms/data/simbrief/" .. name, "rb"))
    local s = f:read("*a")
    f:close()
    return s
end

-- X-Plane's .fms, version 1100
local plan = assert(S.parse_fms(read("ZZAAZZBB01.fms")))
T.equal(plan.origin .. "-" .. plan.dest .. " " .. plan.dep_rwy .. "/" .. plan.des_rwy, "ZZAA-ZZBB 16R/09",
    "1100: ADEP, ADES and the runways without RW")
T.equal(plan.sid .. "." .. plan.sidtrans .. " " .. plan.app .. " " .. plan.cycle, "ZULU1.ALPHA R09 2610", "SID, SIDTRANS, APP, CYCLE")
T.equal(#plan.points, 7, "the 7 points")
T.equal(plan.points[4].ident .. " " .. plan.points[4].via .. " " .. plan.points[4].kind, "BRAVO Z1 wpt", "a point: ident, airway, kind")
T.check(math.abs(plan.points[2].lat - 35.2) < 1e-9 and math.abs(plan.points[2].lon - 140.2) < 1e-9, "its position")

-- the flight plan uplink: the SID's points (by its name) the FMC's, the
-- airway's consecutive points as the airway to its last
local ofp = assert(S.parse_ofp(read("ofp_zzaa_zzbb.xml")))
local up = S.route_uplink(plan, ofp, "ZZAAZZBB01")
T.equal(up.origin .. "-" .. up.dest .. " " .. up.runway .. " " .. up.sid .. "." .. up.sidtrans .. " " .. up.app,
    "ZZAA-ZZBB 16R ZULU1.ALPHA R09", "the uplink's origin, destination, runway, SID and approach (FCOM p.1290)")
T.equal(up.flt_no .. " " .. up.co_route, "JAL123 ZZAAZZBB01", "FLT NO from the OFP, CO ROUTE")
T.equal(#up.elements, 1, "one element: Z1")
T.equal(up.elements[1].via .. " " .. up.elements[1].fix.ident .. " " .. #up.elements[1].points, "Z1 DELTA 3",
    "Z1 to DELTA through BRAVO and CHARL")

-- version 3: no airways, the airports the first and last points
local plan3 = assert(S.parse_fms(read("ZZAAZZBB03.fms")))
T.equal(plan3.origin .. "-" .. plan3.dest .. " " .. #plan3.points, "ZZAA-ZZBB 5", "version 3 (CR LF): the first and last airports")
local up3 = S.route_uplink(plan3, nil, nil)
local names = {}
for _, e in ipairs(up3.elements) do names[#names + 1] = e.via .. " " .. e.fix.ident end
T.equal(table.concat(names, ", "), "DIRECT ALPHA, DIRECT DELTA, DIRECT +36.500_+141.000", "every point DIRECT")
T.equal(up3.elements[3].fix.kind, "ltlg", "a latitude/longitude point")
T.equal(up3.flt_no, nil, "no OFP: no FLT NO")
T.equal(up3.runway, nil, "no runway")

-- not flight plans
local p, err = S.parse_fms("hello")
T.equal(tostring(p) .. " " .. err, "nil NOT A FLIGHT PLAN", "not a flight plan")
p, err = S.parse_fms(nil)
T.equal(err, "NO FILE", "no file")
p, err = S.parse_fms("I\n1100 Version\nNUMENR 1\n11 ALPHA DRCT 0 35.5 140.5\n")
T.equal(err, "NO ORIGIN OR DESTINATION", "no airports")

-- SimBrief's OFP
T.equal(ofp.units .. " " .. ofp.airline .. ofp.flight_number .. " CI" .. ofp.costindex .. " " .. ofp.initial_altitude,
    "kgs JAL123 CI100 25000", "units, flight, cost index, initial altitude")
T.equal(#ofp.steps .. " " .. ofp.steps[2].fix .. " " .. ofp.steps[2].alt, "2 CHARL 27000", "the step climbs (hundreds of feet)")
T.equal(ofp.origin.icao .. " " .. ofp.origin.plan_rwy .. " " .. ofp.origin.trans_alt, "ZZAA 16R 14000", "origin")
T.equal(ofp.dest.icao .. " " .. ofp.dest.trans_level .. " " .. ofp.altn.icao, "ZZBB 6000 ZZAA", "destination, alternate")
T.equal(ofp.fuel.plan_ramp .. " " .. ofp.fuel.plan_takeoff .. " " .. ofp.weights.est_zfw .. " " .. ofp.weights.pax_count,
    "36900 36100 225000 395", "fuel and weights")
T.equal(#ofp.fixes, 8, "the navigation log's 8 fixes (not the OFP text's escaped <fix>)")
T.equal(ofp.fixes[1].ident .. " " .. ofp.fixes[1].kind .. " " .. tostring(ofp.fixes[1].sid_star) .. " " .. ofp.fixes[1].via,
    "ZZV vor true ZULU1", "a SID's point")
T.equal(#ofp.fixes[8].levels .. " " .. ofp.fixes[8].levels[2].alt .. " " .. ofp.fixes[8].levels[2].dir,
    "4 10000 180", "the destination's forecast levels")
T.equal(S.flt_no(ofp), "JAL123", "FLT NO")
p, err = S.parse_ofp("<html></html>")
T.equal(err, "NOT AN OFP", "not an OFP")

-- the route from the OFP alone: the SID's name from its points, TOC/TOD out
local upo = S.route_uplink(nil, ofp, nil)
T.equal(upo.origin .. "-" .. upo.dest .. " " .. upo.runway .. " " .. upo.sid, "ZZAA-ZZBB 16R ZULU1", "the OFP's route: runway, SID")
T.equal(#upo.elements .. " " .. upo.elements[1].via .. " " .. upo.elements[1].fix.ident, "1 Z1 DELTA", "Z1 to DELTA")

-- the winds between the forecast's levels (as vectors)
local w = S.wind_at(ofp.fixes[4], 25000)
T.equal(w.dir .. "/" .. w.spd .. " " .. w.oat, "283/59 -35", "BRAVO FL250: between 270/40 and 290/80")
w = S.wind_at(ofp.fixes[4], 35000)
T.equal(w.dir .. "/" .. w.spd, "290/80", "above the highest level: its wind")
w = S.wind_at(ofp.fixes[3], 25000)
T.equal(w, nil, "TOC: no forecast")

-- the en route wind uplink: the cruise altitudes, the cruise points
T.equal(table.concat(S.cruise_alts(ofp), " "), "27000 25000", "the cruise altitudes: the initial and the step's")
local wu = S.wind_uplink(ofp)
names = {}
for _, q in ipairs(wu.points) do names[#names + 1] = q.ident end
T.equal(table.concat(names, " "), "BRAVO CHARL DELTA", "the cruise points (no TOC, TOD, climb or descent)")
T.equal(#wu.points[1].winds .. " " .. wu.points[1].winds[2].alt .. " " .. wu.points[1].winds[2].dir .. "/" .. wu.points[1].winds[2].spd,
    "2 25000 283/59", "BRAVO's winds at FL270 and FL250")
T.equal(wu.points[1].oat, -35, "its temperature at the lowest cruise altitude")

-- the descent forecast: the top of descent's altitude and 3 below to 5000
local fu = S.forecast_uplink(ofp)
names = {}
for _, l in ipairs(fu.levels) do names[#names + 1] = l.alt .. ":" .. l.dir .. "/" .. l.spd end
T.equal(table.concat(names, " "), "27000:270/54 20000:270/40 12000:207/18 5000:153/11", "the 4 altitudes' winds at the destination")
T.equal(fu.trans_lvl, 6000, "the destination's transition level")

-- the ACARS text
local lines = S.ofp_text(ofp)
T.equal(lines[1], "OFP ZZAA-ZZBB JAL123", "the title line")
T.equal(lines[2], "CRZ ALT FL250 CI 100", "CRZ ALT and cost index")
T.equal(lines[3], "STEP FL270 AT CHARL", "the step climb (not the initial altitude's)")
T.equal(lines[4] .. "|" .. lines[5], "WT/FUEL IN 1000 KG|ZFW 225.0", "the units, ZFW")
T.equal(lines[9], "TRIP 21.5  RSV 5.3", "trip fuel and reserve")
local long = true
for _, l in ipairs(lines) do if #l > 24 then long = false end end
T.check(long, "every line 24 characters or fewer")

T.done()
