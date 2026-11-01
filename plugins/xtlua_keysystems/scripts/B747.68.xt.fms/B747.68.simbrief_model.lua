-- The sim's airline operations (6-1/6-2 step 12h; notes/ATA-34-61-FMC.md
-- §122): the company's flight plan, winds and OFP come from SimBrief's
-- files the crew puts in the aircraft folder's simbrief folder
-- (2026-11-01 the user: route and winds as the FMC's company uplinks, the
-- weights, cruise altitude and step climbs as an ACARS text the crew enters
-- by hand).
--  - parse_fms: X-Plane's flight plan (.fms, version 1100: SimBrief's
--    "X-Plane 11/12" file; version 3 without airways too).
--  - parse_ofp: SimBrief's OFP in XML (its API's xml.fetcher.php): the
--    general data, origin and destination, fuel, weights and the navigation
--    log with each fix's winds by altitude.
--  - route_uplink: the flight plan uplink (FMSPG p.372-376): origin,
--    destination, runway, procedures and the route's elements (an airway to
--    its last fix, else DIRECT), from the .fms or, without one, the OFP.
--  - wind_uplink and forecast_uplink: the en route winds for the route's
--    waypoints at up to 4 cruise altitudes and the descent forecast's 4
--    altitudes (FMSPG p.377-380; which altitudes: estimates).
--  - ofp_text: the OFP's weights, fuel, cruise altitude and step climbs as
--    the ACARS message's lines (24 characters).
-- Pure: the glue reads the files (io.open) and gives their text.
--   local S = B747_simbrief_model                     -- in XTLua, after dofile
--   local S = dofile(".../B747.68.simbrief_model.lua") -- in the tests
local M = setmetatable({}, {})
B747_simbrief_model = M

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- X-Plane's .fms: "I", "1100 Version", keyword lines (CYCLE, ADEP or DEP,
-- DEPRWY, SID, SIDTRANS, ADES or DES, DESRWY, STAR, STARTRANS, APP,
-- APPTRANS, NUMENR) and the waypoints "type ident via alt lat lon" (type
-- 1 airport, 2 NDB, 3 VOR, 11 fix, 28 latitude/longitude; via ADEP, ADES,
-- DRCT or an airway). Version 3: "type ident alt lat lon", no airways.
local KINDS = {["1"] = "apt", ["2"] = "ndb", ["3"] = "vor", ["11"] = "wpt", ["28"] = "ltlg"}
local KEYS = {CYCLE = "cycle", ADEP = "origin", DEP = "origin", DEPRWY = "dep_rwy", SID = "sid",
    SIDTRANS = "sidtrans", ADES = "dest", DES = "dest", DESRWY = "des_rwy", STAR = "star",
    STARTRANS = "startrans", APP = "app", APPTRANS = "apptrans"}

function M.parse_fms(text)
    if type(text) ~= "string" then return nil, "NO FILE" end
    local plan = {points = {}}
    local version
    for raw in (text .. "\n"):gmatch("([^\r\n]*)\r?\n") do
        local line = trim(raw)
        local v = line:match("^(%d+)%s+[Vv]ersion$")
        if v then
            version = tonumber(v)
        elseif version then
            local f = {}
            for w in line:gmatch("%S+") do f[#f + 1] = w end
            local key = f[1] and KEYS[f[1]]
            if key and f[2] then
                plan[key] = f[2]
            elseif f[1] and KINDS[f[1]] and version >= 1100 and #f >= 6 then
                plan.points[#plan.points + 1] = {kind = KINDS[f[1]], ident = f[2], via = f[3],
                    alt = tonumber(f[4]), lat = tonumber(f[5]), lon = tonumber(f[6])}
            elseif f[1] and KINDS[f[1]] and version < 1100 and #f >= 5 then
                plan.points[#plan.points + 1] = {kind = KINDS[f[1]], ident = f[2], via = "DRCT",
                    alt = tonumber(f[3]), lat = tonumber(f[4]), lon = tonumber(f[5])}
            end
        end
    end
    if not version then return nil, "NOT A FLIGHT PLAN" end
    local pts = plan.points
    for _, p in ipairs(pts) do
        if not (p.lat and p.lon) then return nil, "INVALID POINT " .. p.ident end
    end
    -- version 3 and files without ADEP/ADES: the first and last airports
    if not plan.origin and pts[1] and pts[1].kind == "apt" then plan.origin = pts[1].ident end
    if not plan.dest and #pts > 1 and pts[#pts].kind == "apt" then plan.dest = pts[#pts].ident end
    if not (plan.origin and plan.dest) then return nil, "NO ORIGIN OR DESTINATION" end
    -- runways without "RW"
    for _, k in ipairs({"dep_rwy", "des_rwy"}) do
        if plan[k] then plan[k] = plan[k]:gsub("^RW", "") end
    end
    return plan
end

-- SimBrief's XML: the text of a tag in a block ("" for <tag/>)
local ENTITIES = {amp = "&", lt = "<", gt = ">", quot = '"', apos = "'"}
local function unescape(s)
    return (s:gsub("&(#?x?)(%w+);", function(pre, name)
        if pre == "" then return ENTITIES[name] end
        local n = tonumber(name, pre == "#x" and 16 or 10)
        return n and n < 128 and string.char(n) or "?"
    end))
end
local function tag(block, name)
    if not block then return nil end
    local v = block:match("<" .. name .. ">(.-)</" .. name .. ">")
    if v then return unescape(trim(v)) end
    if block:find("<" .. name .. "%s*/>") then return "" end
    return nil
end
local function num(block, name)
    local v = tag(block, name)
    return v and tonumber(v)
end
local function block(text, name)
    return text:match("<" .. name .. ">(.-)</" .. name .. ">")
end

local FUEL = {"taxi", "enroute_burn", "contingency", "alternate_burn", "reserve", "etops", "extra",
    "min_takeoff", "plan_takeoff", "plan_ramp", "plan_landing"}
local WEIGHTS = {"oew", "pax_count", "bag_count", "cargo", "payload", "est_zfw", "max_zfw",
    "est_tow", "max_tow", "est_ldw", "max_ldw", "est_ramp"}

local function airport(text, name)
    local b = block(text, name)
    if not b then return nil end
    return {icao = tag(b, "icao_code"), plan_rwy = tag(b, "plan_rwy"), trans_alt = num(b, "trans_alt"),
        trans_level = num(b, "trans_level"), elevation = num(b, "elevation"),
        lat = num(b, "pos_lat"), lon = num(b, "pos_long")}
end

-- "CYYZ/0290/BAREE/0310": the fixes and their altitudes in hundreds of feet
function M.parse_steps(s)
    local steps = {}
    if not s then return steps end
    local parts = {}
    for p in s:gmatch("[^/%s]+") do parts[#parts + 1] = p end
    for i = 1, #parts - 1, 2 do
        local alt = tonumber(parts[i + 1])
        if alt then steps[#steps + 1] = {fix = parts[i], alt = alt * 100} end
    end
    return steps
end

function M.parse_ofp(text)
    if type(text) ~= "string" then return nil, "NO FILE" end
    if not text:find("<OFP>", 1, true) then return nil, "NOT AN OFP" end
    local ofp = {}
    local params, general = block(text, "params"), block(text, "general")
    ofp.units = (tag(params, "units") or "kgs"):lower()
    ofp.airline = tag(general, "icao_airline")
    ofp.flight_number = tag(general, "flight_number")
    ofp.costindex = num(general, "costindex")
    ofp.initial_altitude = num(general, "initial_altitude")
    ofp.steps = M.parse_steps(tag(general, "stepclimb_string"))
    ofp.cruise_mach = num(general, "cruise_mach")
    ofp.route = tag(general, "route")
    ofp.origin, ofp.dest, ofp.altn = airport(text, "origin"), airport(text, "destination"), airport(text, "alternate")
    if not (ofp.origin and ofp.origin.icao and ofp.dest and ofp.dest.icao) then return nil, "NO ORIGIN OR DESTINATION" end
    local fuel, weights = block(text, "fuel"), block(text, "weights")
    ofp.fuel, ofp.weights = {}, {}
    for _, k in ipairs(FUEL) do ofp.fuel[k] = num(fuel, k) end
    for _, k in ipairs(WEIGHTS) do ofp.weights[k] = num(weights, k) end
    ofp.fixes = {}
    local navlog = block(text, "navlog") or ""
    for f in navlog:gmatch("<fix>(.-)</fix>") do
        local fix = {ident = tag(f, "ident"), kind = tag(f, "type"), via = tag(f, "via_airway"),
            sid_star = tag(f, "is_sid_star") == "1", stage = tag(f, "stage"),
            lat = num(f, "pos_lat"), lon = num(f, "pos_long"), alt = num(f, "altitude_feet"),
            wind_dir = num(f, "wind_dir"), wind_spd = num(f, "wind_spd"), oat = num(f, "oat"), levels = {}}
        local wd = block(f, "wind_data") or ""
        for l in wd:gmatch("<level>(.-)</level>") do
            local alt = num(l, "altitude")
            if alt then
                fix.levels[#fix.levels + 1] = {alt = alt, dir = num(l, "wind_dir"), spd = num(l, "wind_spd"), oat = num(l, "oat")}
            end
        end
        table.sort(fix.levels, function(a, b) return a.alt < b.alt end)
        if fix.ident and fix.lat and fix.lon then ofp.fixes[#ofp.fixes + 1] = fix end
    end
    return ofp
end

-- the flight number for the RTE page's FLT NO (10 characters)
function M.flt_no(ofp)
    if not (ofp and ofp.flight_number and ofp.flight_number ~= "") then return nil end
    return ((ofp.airline or "") .. ofp.flight_number):upper():sub(1, 10)
end

-- the route's elements: consecutive points on one airway as the airway to
-- its last point, every other point DIRECT; a point is {ident, kind, lat,
-- lon}; points: the element's points in order (for the FMC to go DIRECT
-- to each when it cannot take the airway)
local function elements(points)
    local out = {}
    for _, p in ipairs(points) do
        local via = p.via
        if not via or via == "" or via == "DRCT" or via == "DCT" or via == "DIRECT" then via = "DIRECT" end
        local fix = {ident = p.ident, kind = p.kind, lat = p.lat, lon = p.lon}
        local last = out[#out]
        if via ~= "DIRECT" and last and last.via == via then
            last.fix = fix
            last.points[#last.points + 1] = fix
        else
            out[#out + 1] = {via = via, fix = fix, points = {fix}}
        end
    end
    return out
end

-- the flight plan uplink from the .fms (preferred) or the OFP's navigation
-- log: {origin, dest, runway, sid, sidtrans, star, startrans, app,
-- apptrans, flt_no, co_route, elements}. The procedures' own points are not
-- elements (the FMC builds them from its database).
function M.route_uplink(plan, ofp, co_route)
    local up = {co_route = co_route, flt_no = M.flt_no(ofp)}
    if plan then
        up.origin, up.dest, up.runway = plan.origin, plan.dest, plan.dep_rwy
        up.sid, up.sidtrans, up.star, up.startrans = plan.sid, plan.sidtrans, plan.star, plan.startrans
        up.app, up.apptrans, up.des_rwy = plan.app, plan.apptrans, plan.des_rwy
        -- the procedures' points (by the procedure's name) are the FMC's
        local procs = {ADEP = true, ADES = true, SID = true, STAR = true, APP = true}
        for _, k in ipairs({"sid", "sidtrans", "star", "startrans", "app", "apptrans"}) do
            if plan[k] then procs[plan[k]] = true end
        end
        local pts = {}
        for i, p in ipairs(plan.points) do
            local endpoint = (i == 1 and p.ident == plan.origin) or (i == #plan.points and p.ident == plan.dest)
            if not endpoint and not procs[p.via] then pts[#pts + 1] = p end
        end
        up.elements = elements(pts)
    elseif ofp then
        up.origin, up.dest = ofp.origin.icao, ofp.dest.icao
        up.runway = ofp.origin.plan_rwy
        local pts = {}
        local fixes = ofp.fixes
        for i, f in ipairs(fixes) do
            local endpoint = f.kind == "apt" and (i == 1 or i == #fixes)
            -- the SID's and STAR's points (their names: the procedures) and
            -- the climb's and descent's pseudo points (TOC, TOD) are the FMC's
            if f.sid_star and not endpoint then
                if #pts == 0 then up.sid = up.sid or f.via else up.star = f.via end
            elseif not endpoint and not f.ident:find("^TO[CD]$") then
                pts[#pts + 1] = f
            end
        end
        up.elements = elements(pts)
    else
        return nil
    end
    if up.runway == "" then up.runway = nil end
    return up
end

-- a fix's wind and temperature at an altitude, linear between the
-- forecast's levels (above the highest or below the lowest: that level's)
function M.wind_at(fix, alt)
    local lv = fix.levels
    if not lv or #lv == 0 then
        if fix.wind_dir and fix.wind_spd then return {dir = fix.wind_dir, spd = fix.wind_spd, oat = fix.oat} end
        return nil
    end
    if alt <= lv[1].alt then return {dir = lv[1].dir, spd = lv[1].spd, oat = lv[1].oat} end
    for i = 2, #lv do
        local a, b = lv[i - 1], lv[i]
        if alt <= b.alt then
            local t = (alt - a.alt) / (b.alt - a.alt)
            -- the wind as a vector (the direction it comes from)
            local ra, rb = math.rad(a.dir or 0), math.rad(b.dir or 0)
            local x = (1 - t) * (a.spd or 0) * math.sin(ra) + t * (b.spd or 0) * math.sin(rb)
            local y = (1 - t) * (a.spd or 0) * math.cos(ra) + t * (b.spd or 0) * math.cos(rb)
            local spd = math.sqrt(x * x + y * y)
            local dir = spd > 0.5 and math.deg(math.atan2(x, y)) % 360 or 0
            local oat = a.oat and b.oat and (1 - t) * a.oat + t * b.oat or (a.oat or b.oat)
            return {dir = math.floor(dir + 0.5) % 360, spd = math.floor(spd + 0.5), oat = oat and math.floor(oat + 0.5)}
        end
    end
    local l = lv[#lv]
    return {dir = l.dir, spd = l.spd, oat = l.oat}
end

-- the cruise altitudes the en route winds are for: the initial altitude and
-- the step climbs' (up to 4, the WIND page's lines: estimate)
function M.cruise_alts(ofp)
    local alts, seen = {}, {}
    local function add(a)
        if a and a > 0 and not seen[a] and #alts < 4 then seen[a] = true alts[#alts + 1] = a end
    end
    add(ofp.initial_altitude)
    for _, s in ipairs(ofp.steps) do add(s.alt) end
    table.sort(alts, function(a, b) return a > b end)
    return alts
end

-- the en route wind uplink: {alts, points = {{ident, lat, lon, winds =
-- {{alt, dir, spd}}, oat (at the first cruise altitude)}}} for the OFP's
-- cruise points (stage CRZ; the climb's and descent's are not the RTE DATA
-- page's: estimate)
function M.wind_uplink(ofp)
    if not ofp then return nil end
    local alts = M.cruise_alts(ofp)
    if #alts == 0 then return nil end
    local up = {alts = alts, points = {}}
    for _, f in ipairs(ofp.fixes) do
        if f.stage == "CRZ" and not f.ident:find("^TO[CD]$") then
            local p = {ident = f.ident, lat = f.lat, lon = f.lon, winds = {}}
            for _, a in ipairs(alts) do
                local w = M.wind_at(f, a)
                if w then p.winds[#p.winds + 1] = {alt = a, dir = w.dir, spd = w.spd} end
            end
            local w = M.wind_at(f, alts[#alts])
            p.oat = w and w.oat
            if #p.winds > 0 then up.points[#up.points + 1] = p end
        end
    end
    if #up.points == 0 then return nil end
    return up
end

-- the descent forecast uplink: {trans_lvl, levels = {{alt, dir, spd}} (4,
-- highest first)} from the destination's forecast at the top of descent's
-- altitude and 3 below, evenly to 5000 ft (which altitudes: estimate)
function M.forecast_uplink(ofp)
    if not ofp then return nil end
    local dest = ofp.fixes[#ofp.fixes]
    if not dest or not dest.levels or #dest.levels == 0 then return nil end
    local top = 0
    for _, f in ipairs(ofp.fixes) do
        if f.stage == "CRZ" and f.alt and f.alt > top then top = f.alt end
    end
    if top == 0 then top = ofp.initial_altitude or 0 end
    if top <= 5000 then return nil end
    local up = {trans_lvl = ofp.dest.trans_level, levels = {}}
    for i = 0, 3 do
        local a = math.floor((top - (top - 5000) * i / 3) / 1000 + 0.5) * 1000
        local w = M.wind_at(dest, a)
        if w then up.levels[#up.levels + 1] = {alt = a, dir = w.dir, spd = w.spd} end
    end
    return up
end

-- the OFP's ACARS text: 24-character lines (the weights in the OFP's units:
-- the FMC's in thousands)
local function thousands(v) return v and string.format("%.1f", v / 1000) or "-" end
local function fl(a) return a and (a >= 18000 and string.format("FL%03d", math.floor(a / 100 + 0.5)) or tostring(a)) or "-" end
function M.ofp_text(ofp)
    local u = ofp.units == "lbs" and "LB" or "KG"
    local lines = {}
    local function add(s) lines[#lines + 1] = s:sub(1, 24) end
    add(string.format("OFP %s-%s %s", ofp.origin.icao, ofp.dest.icao, M.flt_no(ofp) or ""))
    add(string.format("CRZ ALT %s CI %s", fl(ofp.initial_altitude), ofp.costindex and tostring(ofp.costindex) or "-"))
    for _, s in ipairs(ofp.steps) do
        if s.alt ~= ofp.initial_altitude then add(string.format("STEP %s AT %s", fl(s.alt), s.fix)) end
    end
    add("WT/FUEL IN 1000 " .. u)
    add(string.format("ZFW %s", thousands(ofp.weights.est_zfw)))
    add(string.format("TOW %s  LDW %s", thousands(ofp.weights.est_tow), thousands(ofp.weights.est_ldw)))
    add(string.format("RAMP FUEL %s", thousands(ofp.fuel.plan_ramp)))
    add(string.format("TO FUEL %s", thousands(ofp.fuel.plan_takeoff)))
    add(string.format("TRIP %s  RSV %s", thousands(ofp.fuel.enroute_burn), thousands(ofp.fuel.reserve)))
    if ofp.altn and ofp.altn.icao then add(string.format("ALTN %s", ofp.altn.icao)) end
    if ofp.weights.pax_count then add(string.format("PAX %d", ofp.weights.pax_count)) end
    return lines
end

return M
