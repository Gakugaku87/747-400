-- The FMC's terminal procedures (6-1/6-2 step 5d; the plan and sources:
-- docs/overhaul/notes/ATA-34-61-FMC.md §18): an airport's SIDs, STARs and
-- approaches from its CIFP (B747.68.navdb.lua's `cifp`: the X-Plane CIFP
-- lines, ARINC 424 fields) as the route's legs.
--  - The parts by the route type (field 2): a SID's runway transitions (1,
--    4, F, T), common route (2, 5, M) and enroute transitions (3, 6, S, V);
--    a STAR's enroute transitions (1, 4, 7, F), common route (2, 5, 8, M)
--    and runway transitions (3, 6, 9, S); an approach's transitions (A) and
--    the final approach (its type letter), the missed approach from the
--    leg its description marks (field 9, third character M). A runway
--    part's transition names the runway ("RW16R"), both parallel ones
--    ("RW16B") or ALL.
--  - A leg: {via (the procedure), pt (the path terminator, field 12), fix
--    (the leg's end: a point of the nav DB, an airport's runway threshold;
--    nil for the conditional legs), from_fix (FA, FC, FD, FM: the fix they
--    start at), turn (L, R), flyover, navaid (the recommended navaid),
--    theta, rho (its radial and DME distance), crs (the magnetic course or
--    heading), dist (nm; minutes for the holds' times), alt, alt2, akind
--    (the constraint: "" at, "A" at or above, "B" at or below, "AB" the
--    block), spd (at or below), vangle (degrees), altterm (the legs ending
--    at an altitude: CA, FA, VA, HA), name (a conditional leg's: "(1000)",
--    "(INTC)", "VECTORS", "NRE180", "NRE/20": FCOM p.1249), faf, map,
--    missed, center and arc_r (an RF leg's arc: its centre, a point of the
--    nav DB, and its radius in nm: step 6a)}.
-- Pure: the glue gives the nav DB module and its database.
local M = setmetatable({}, {})
B747_proc_model = M

M.SID, M.STAR, M.APPCH = "sid", "star", "appch"

local PART = {
    sid = {rwy = {["1"] = true, ["4"] = true, F = true, T = true}, common = {["2"] = true, ["5"] = true, M = true},
           trans = {["3"] = true, ["6"] = true, S = true, V = true}},
    star = {trans = {["1"] = true, ["4"] = true, ["7"] = true, F = true}, common = {["2"] = true, ["5"] = true, ["8"] = true, M = true},
            rwy = {["3"] = true, ["6"] = true, ["9"] = true, S = true}},
}
-- the approaches' names on the ARRIVALS page (FCOM p.1401: ILS32R, RNV22,
-- VOR04, NDB32R, GPS32R): the CIFP's type letter as the CDU shows it
-- (estimate for the letters FCOM does not show)
local APPROACH_NAME = {I = "ILS", L = "LOC", B = "BCS", R = "RNV", P = "GPS", D = "VOR", V = "VOR", S = "VOR",
    N = "NDB", Q = "NDB", X = "LDA", U = "SDF", G = "IGS", J = "GLS", T = "TCN", M = "MLS", H = "RNP"}

local function num(s, scale)
    local v = tonumber(s)
    return v and v / (scale or 1) or nil
end

-- an altitude field: "FL180" or feet
local function alt_field(s)
    if not s or s == "" then return nil end
    local fl = s:match("^FL(%d+)$")
    if fl then return tonumber(fl) * 100 end
    return tonumber(s)
end

-- a runway designator in a transition's name: RW16R, RW16B (16L and 16R),
-- ALL
local function rwy_matches(trans, rwy)
    if trans == "ALL" or trans == "" then return true end
    if not rwy then return false end
    if trans == rwy then return true end
    local base = trans:match("^(RW%d%d)B$")
    return base ~= nil and (rwy == base .. "L" or rwy == base .. "R")
end

-- the procedures of an airport: their names in the file's order
function M.list(N, db, icao, kind)
    local c = N.cifp(db, icao)
    return c and c.order[kind] or {}
end

-- an approach's name as the CDU shows it ("I34L" -> "ILS34L")
function M.approach_name(id)
    local t, rest = id:match("^(%u)(.+)$")
    return t and (APPROACH_NAME[t] or t) .. rest or id
end

-- a procedure's transitions by part: {rwy = {...}, trans = {...}} (a SID's
-- runways and enroute transitions, a STAR's enroute and runway
-- transitions, an approach's transitions in `trans`)
function M.transitions(N, db, icao, kind, name)
    local c = N.cifp(db, icao)
    local p = c and c[kind][name]
    local out = {rwy = {}, trans = {}}
    if not p then return out end
    local seen = {}
    for tname, legs in pairs(p) do
        local rt = legs[1] and legs[1][2]
        local part
        if kind == M.APPCH then
            part = rt == "A" and "trans" or nil
        else
            local P = PART[kind]
            part = P.rwy[rt] and "rwy" or P.trans[rt] and "trans" or nil
        end
        if part and tname ~= "" and not seen[part .. tname] then
            seen[part .. tname] = true
            out[part][#out[part] + 1] = tname
        end
    end
    table.sort(out.rwy)
    table.sort(out.trans)
    return out
end

-- the runways a SID or a STAR serves (the runway parts' runways, both of
-- a "B" pair; all the airport's when a part says ALL or there is none)
function M.runways(N, db, icao, kind, name)
    local c = N.cifp(db, icao)
    local p = c and c[kind][name]
    local all, out, seen = {}, {}, {}
    for id in pairs(c and c.runways or {}) do all[#all + 1] = id end
    table.sort(all)
    if not p then return all end
    local any = false
    for tname, legs in pairs(p) do
        local rt = legs[1] and legs[1][2]
        local P = PART[kind]
        if P and (P.rwy[rt] or (P.common[rt] and tname:match("^RW"))) then
            any = true
            for _, id in ipairs(all) do
                if rwy_matches(tname, id) and not seen[id] then seen[id] = true; out[#out + 1] = id end
            end
            if tname == "ALL" then return all end
        end
    end
    if not any then return all end
    table.sort(out)
    return out
end

-- one CIFP leg as the route's leg
local KIND = {D = "VOR", E = "WPT", P = "WPT"}
local function leg_of(N, db, c, icao, f, via)
    local pt = f[12]
    local id, region, sec, sub = f[5], f[6], f[7], f[8]
    local point = nil
    if id ~= "" then
        if sec == "P" and sub == "G" then
            local rw = c.runways[id]
            if rw then point = {kind = "RWY", ident = id, lat = rw.lat, lon = rw.lon, elev = rw.elev} end
        elseif sec == "P" and sub == "N" or sec == "D" and sub == "B" then
            point = N.point(db, id, region, "NDB", icao)
        else
            point = N.point(db, id, region, KIND[sec], icao)
        end
    end
    local navaid = f[14] ~= "" and N.point(db, f[14], f[15], nil, icao) or nil
    local desc = f.desc or f[9] or ""
    local l = {via = via, pt = pt, turn = (f[10] == "L" or f[10] == "R") and f[10] or nil,
        flyover = desc:sub(2, 2) == "Y", navaid = navaid, theta = num(f[19], 10), rho = num(f[20], 10),
        crs = num(f[21], 10), dist = num(f[22], 10), spd = num(f[28]), vangle = num(f[29], 100),
        faf = desc:sub(4, 4) == "F", map = desc:sub(4, 4) == "M", missed = desc:sub(3, 3) == "M",
        altterm = pt == "CA" or pt == "FA" or pt == "VA" or pt == "HA"}
    -- the altitude constraint (field 23 the description, 24 and 25 the
    -- altitudes): + at or above, - at or below, B the block (25 to 24), C
    -- at or above the second; the glide slope codes as at or above or at
    -- the first (estimate)
    local d, a1, a2 = f[23], alt_field(f[24]), alt_field(f[25])
    if a1 then
        if d == "+" or d == "H" or d == "J" or d == "V" then l.alt, l.akind = a1, "A"
        elseif d == "-" or d == "Y" then l.alt, l.akind = a1, "B"
        elseif d == "B" and a2 then l.alt, l.alt2, l.akind = a2, a1, "AB"
        elseif d == "C" and a2 then l.alt, l.akind = a2, "A"
        else l.alt, l.akind = a1, "" end
    end
    -- where the leg ends
    if pt == "FA" or pt == "FC" or pt == "FD" or pt == "FM" then
        l.from_fix = point
    elseif pt:sub(1, 1) == "C" and pt ~= "CF" or pt:sub(1, 1) == "V" then
        -- conditional
    else
        l.fix = point
    end
    -- an RF leg's arc (step 6a; FCOM p.1247): the centre (fields 31-34) and
    -- the radius (field 18, thousandths of a nm)
    if pt == "RF" and f[31] and f[31] ~= "" then
        l.center = N.point(db, f[31], f[32], KIND[f[33]], icao)
        l.arc_r = num(f[18], 1000)
    end
    -- a conditional leg's name (FCOM p.1249): an altitude in parentheses,
    -- (INTC), VECTORS, a radial (the navaid and the radial), a DME
    -- distance (the navaid / the distance)
    local nav = navaid and navaid.ident or ""
    if pt == "CA" or pt == "FA" or pt == "VA" then
        l.name = "(" .. tostring(l.alt or 0) .. ")"
    elseif pt == "CI" or pt == "VI" then
        l.name = "(INTC)"
    elseif pt == "VM" or pt == "FM" then
        l.name = "VECTORS"
    elseif pt == "CR" or pt == "VR" then
        l.name = nav .. string.format("%03d", math.floor((l.theta or 0) + 0.5))
    elseif pt == "CD" or pt == "VD" or pt == "FD" then
        l.name = nav .. "/" .. tostring(math.floor((l.dist or 0) + 0.5))
    elseif pt == "FC" then
        l.name = "(" .. tostring(math.floor((l.dist or 0) + 0.5)) .. ")"
    end
    return l
end

-- the parts' legs one after the other, the point where two parts meet once
local function join(out, legs)
    for k, l in ipairs(legs) do
        local last = out[#out]
        if not (k == 1 and l.pt == "IF" and last and last.fix and l.fix and last.fix.ident == l.fix.ident) then
            out[#out + 1] = l
        end
    end
end

-- a part's legs: the enroute transition `want`, or the runway's runway
-- transition or common route; with no runway yet a common route the only
-- one there is (a STAR's runway's common route: FCOM p.1403)
local function part_legs(N, db, c, icao, p, kind, part, want, rwy, via)
    local P = PART[kind]
    local pick, count = nil, 0
    for tname, legs in pairs(p) do
        local rt = legs[1] and legs[1][2]
        if P[part][rt] then
            count = count + 1
            if (part == "trans" and tname == want) or (part ~= "trans" and rwy_matches(tname, rwy)) then
                pick = legs
                break
            end
            if part == "common" and not rwy then pick = pick or legs end
        end
    end
    if part == "common" and not rwy and count > 1 then
        -- several runways' common routes and no runway: not chosen yet
        local blank = p[""] or p.ALL
        pick = blank
    end
    local out = {}
    for _, f in ipairs(pick or {}) do out[#out + 1] = leg_of(N, db, c, icao, f, via) end
    return out
end

-- a SID's legs: the runway's transition, the common route, the enroute
-- transition `trans` (FCOM p.1301-1302)
function M.sid_legs(N, db, icao, name, rwy, trans)
    local c = N.cifp(db, icao)
    local p = c and c.sid[name]
    if not p then return nil end
    local via = trans and (name .. "." .. trans) or name
    local out = {}
    join(out, part_legs(N, db, c, icao, p, M.SID, "rwy", nil, rwy, via))
    join(out, part_legs(N, db, c, icao, p, M.SID, "common", nil, rwy, via))
    if trans then join(out, part_legs(N, db, c, icao, p, M.SID, "trans", trans, rwy, via)) end
    return out
end

-- a STAR's legs: the enroute transition `trans`, the common route, the
-- runway's transition (FCOM p.1401-1404)
function M.star_legs(N, db, icao, name, trans, rwy)
    local c = N.cifp(db, icao)
    local p = c and c.star[name]
    if not p then return nil end
    local via = trans and (trans .. "." .. name) or name
    local out = {}
    if trans then join(out, part_legs(N, db, c, icao, p, M.STAR, "trans", trans, rwy, via)) end
    join(out, part_legs(N, db, c, icao, p, M.STAR, "common", nil, rwy, via))
    join(out, part_legs(N, db, c, icao, p, M.STAR, "rwy", nil, rwy, via))
    return out
end

-- an approach's legs: its transition `trans`, the final approach and the
-- missed approach (FCOM p.1401-1405); the runway it lands on
function M.approach_legs(N, db, icao, id, trans)
    local c = N.cifp(db, icao)
    local p = c and c.appch[id]
    if not p then return nil end
    local name = M.approach_name(id)
    local out, rwy = {}, nil
    if trans and p[trans] then
        local legs = {}
        for _, f in ipairs(p[trans]) do legs[#legs + 1] = leg_of(N, db, c, icao, f, trans) end
        join(out, legs)
    end
    local final = {}
    local missed = false
    for tname, legs in pairs(p) do
        if legs[1] and legs[1][2] ~= "A" then
            for _, f in ipairs(legs) do
                local l = leg_of(N, db, c, icao, f, name)
                missed = missed or l.missed
                l.missed = missed
                if l.fix and l.fix.kind == "RWY" and not rwy then rwy = l.fix.ident end
                final[#final + 1] = l
            end
            break
        end
    end
    join(out, final)
    return out, rwy
end

return M
