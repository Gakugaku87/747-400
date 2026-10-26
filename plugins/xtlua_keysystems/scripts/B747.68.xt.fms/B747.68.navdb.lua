-- The FMC's navigation database (6-1/6-2 step 4; the plan and sources:
-- docs/overhaul/notes/ATA-34-61-FMC.md §10). Read from the navigation data
-- X-Plane flies with, the files the ND's map reads (B747.61.xt.nd.lua): the
-- Custom Data folder when it has them (a Navigraph cycle), else
-- Resources/default data. The glue picks the folder and gives the opener.
--  - earth_aptmeta.dat: the airports: position, elevation, transition
--    altitude and level (the CLB page's TRANS ALT from the origin, FCOM
--    p.1328-1329; the descent's transition level, p.1396);
--  - earth_nav.dat: VOR (with VOR/DME, VORTAC, TACAN), NDB, DME, ILS and
--    LOC (the glideslope's angle on its ILS);
--  - earth_fix.dat: the waypoints, the enroute ones by identifier, the
--    terminal ones by their airport (the procedures name them);
--  - earth_awy.dat: the airways;
--  - earth_hold.dat: the published holds;
--  - CIFP/<airport>.dat: the airport's runways and procedures, read when the
--    airport is needed (a few hundred lines; the legs are read in step 5).
-- The big files go a block of bytes a call (M.load) so that no frame waits.
-- The data cycle: the AIRAC cycle in the files' header, its 28 days from
-- AIRAC 2001 (2 January 2020); the IDENT page's ACTIVE dates and NAV DATA
-- OUT OF DATE (FCOM p.1271, p.1284, p.1433).
-- Pure: the glue gives the opener (io.open on the folder in XTLua, a
-- fixture folder in the tests).
--   local N = B747_navdb                       -- in XTLua, after dofile
--   local N = dofile(".../B747.68.navdb.lua")  -- in the tests
local M = setmetatable({}, {})
B747_navdb = M

-- the kinds of the records
M.WPT, M.VOR, M.NDB, M.DME, M.LOC, M.APT = "WPT", "VOR", "NDB", "DME", "LOC", "APT"
M.FILES = {"earth_aptmeta.dat", "earth_nav.dat", "earth_fix.dat", "earth_awy.dat", "earth_hold.dat"}
M.BLOCK = 16384
-- earth_nav.dat's row codes kept: NDB, VOR, localizer (ILS and LOC alone,
-- LDA, SDF), glideslope, DME with a VOR or an ILS, DME alone
local NAV_KIND = {[2] = M.NDB, [3] = M.VOR, [4] = M.LOC, [5] = M.LOC, [13] = M.DME}
-- earth_awy.dat's and earth_hold.dat's fix types: a waypoint, an NDB, a VOR
local AWY_KIND = {["11"] = M.WPT, ["2"] = M.NDB, ["3"] = M.VOR}

local floor, tonumber, sub, find, match = math.floor, tonumber, string.sub, string.find, string.match
local rad, sin, cos, asin, sqrt = math.rad, math.sin, math.cos, math.asin, math.sqrt

-- days since 1 January 1970 of a Gregorian date, and back (H. Hinnant's
-- days_from_civil and civil_from_days)
local function days(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end
local function civil(z)
    z = z + 719468
    local era = floor(z / 146097)
    local doe = z - era * 146097
    local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
    local y = yoe + era * 400
    local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
    local mp = floor((5 * doy + 2) / 153)
    local d = doy - floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    if m <= 2 then y = y + 1 end
    return y, m, d
end
M.days, M.civil = days, civil

-- the first day of an AIRAC cycle "YYNN" (days since 1970) and its last (27
-- days later): the cycles go every 28 days from AIRAC 2001, 2 January 2020;
-- NN counts the cycles starting in the year 20YY
local AIRAC_2001 = days(2020, 1, 2)
function M.airac(cycle)
    local yy, nn = match(cycle or "", "^(%d%d)(%d%d)$")
    if not yy then return nil end
    yy, nn = 2000 + tonumber(yy), tonumber(nn)
    local k = floor((days(yy, 1, 1) - AIRAC_2001) / 28)
    while civil(AIRAC_2001 + 28 * k) < yy do k = k + 1 end
    local first = AIRAC_2001 + 28 * (k + nn - 1)
    if nn < 1 or civil(first) ~= yy then return nil end
    return first, first + 27
end

-- great circle distance in nautical miles
function M.distance(lat1, lon1, lat2, lon2)
    local p1, p2 = rad(lat1), rad(lat2)
    local dp, dl = p2 - p1, rad(lon2 - lon1)
    local a = sin(dp / 2) ^ 2 + cos(p1) * cos(p2) * sin(dl / 2) ^ 2
    return 2 * asin(math.min(1, sqrt(a))) * 3440.065
end

-- a database to fill with M.load; `open(name)` opens a file of the folder
-- ("earth_fix.dat", "CIFP/RJAA.dat") or returns nil. With a metatable, so
-- that XTLua does not copy it when the glue keeps it in a global.
function M.new(open)
    return setmetatable({
        open = open, ready = false, step = 0, file = nil, rest = "",
        cycle = nil, first_day = nil, last_day = nil, missing = {},
        -- waypoints and navaids: parallel arrays, chained by identifier
        n = 0, kind = {}, ident = {}, lat = {}, lon = {}, region = {}, nxt = {}, first = {},
        nav = {},    -- point index -> {freq, elev, range, var, name, dme, gs}
        term = {},   -- airport -> its terminal waypoints' lines, one string
        apt = {},    -- ICAO -> {lat, lon, elev, ta, tl}
        awy = {},    -- airway -> its segments' lines
        hold = {},   -- "IDENT REGION" -> the holds' lines
        cifp = {},   -- ICAO -> the CIFP read (false: none)
    }, {})
end

local function add_point(db, kind, ident, lat, lon, region)
    local i = db.n + 1
    db.n = i
    db.kind[i], db.ident[i], db.lat[i], db.lon[i], db.region[i] = kind, ident, lat, lon, region
    db.nxt[i] = db.first[ident]
    db.first[ident] = i
    return i
end

-- the header's cycle: "1200 Version - data cycle 2610, build ..."
local function header(db, line)
    local c = match(line, "data cycle (%d%d%d%d)")
    if c and not db.cycle then
        db.cycle = c
        db.first_day, db.last_day = M.airac(c)
    end
end

-- one line of each file
local parse = {}
-- "RJAA RJ  35.765277778  140.385555556   135 C 13100 I 14000 FL140"
parse["earth_aptmeta.dat"] = function(db, l)
    local icao, region, lat, lon, elev, ta, tl = match(l, "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+%S+%s+%S+%s+%S+%s+(%S+)%s+(%S+)")
    lat, lon = tonumber(lat), tonumber(lon)
    if not (lat and lon) then return end
    local tlv = tonumber(match(tl, "^FL(%d+)$") or "")
    db.apt[icao] = {icao = icao, region = region, lat = lat, lon = lon, elev = tonumber(elev) or 0,
        ta = tonumber(ta), tl = tlv and tlv * 100 or nil}
end
-- " 3  32.480236111  130.160966667   351  11345  130   -7.000  AKE ENRT RJ AMAKUSA VOR/DME"
parse["earth_nav.dat"] = function(db, l)
    local code, lat, lon, elev, freq, range, var, ident, terminal, region, name =
        match(l, "^%s*(%d+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(.-)%s*$")
    code = tonumber(code)
    if not code then return end
    lat, lon = tonumber(lat), tonumber(lon)
    local kind = NAV_KIND[code]
    if kind then
        local i = add_point(db, kind, ident, lat, lon, region)
        local rec = {freq = tonumber(freq), elev = tonumber(elev), range = tonumber(range),
            var = tonumber(var), name = name, terminal = terminal}
        if kind == M.LOC then
            -- the course: 360 * magnetic + true (XP 1200)
            local v = rec.var or 0
            rec.crs_true = v % 360
            rec.crs_mag = floor(v / 360)
            rec.runway = name and match(name, "^(%S+)")
        end
        db.nav[i] = rec
    elseif code == 6 or code == 12 then
        -- the glideslope or the DME of a VOR or an ILS: on the navaid with
        -- the identifier and region nearby
        local i = db.first[ident]
        while i do
            local k = db.kind[i]
            if db.region[i] == region and (k == M.VOR or k == M.LOC)
                and math.abs(db.lat[i] - lat) < 0.5 and math.abs(db.lon[i] - lon) < 0.5 then
                local rec = db.nav[i]
                if code == 12 then
                    rec.dme = true
                    rec.dme_lat, rec.dme_lon, rec.dme_elev = lat, lon, tonumber(elev)
                elseif k == M.LOC then
                    rec.gs = floor((tonumber(var) or 0) / 1000) / 100
                    rec.gs_lat, rec.gs_lon, rec.gs_elev = lat, lon, tonumber(elev)
                end
                return
            end
            i = db.nxt[i]
        end
    end
end
-- " 35.702802778  140.419977778  30LOC RJAA RJ 4608073 IYQ157005"
parse["earth_fix.dat"] = function(db, l)
    local lat, lon, ident, terminal, region = match(l, "^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
    lat, lon = tonumber(lat), tonumber(lon)
    if not (lat and lon) then return end
    if terminal == "ENRT" then
        add_point(db, M.WPT, ident, lat, lon, region)
    else
        local t = db.term[terminal]
        if not t then t = {}; db.term[terminal] = t end
        t[#t + 1] = ident .. " " .. region .. " " .. lat .. " " .. lon
    end
end
-- "ABTEK UB 11 EKRAM UB 11 N 1  75 660 Y124" (several airways: "A1-B2")
parse["earth_awy.dat"] = function(db, l)
    local names = match(l, "^%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+%S+%s+(%S+)")
    if not names then return end
    for name in names:gmatch("[^%-]+") do
        local t = db.awy[name]
        if not t then t = {}; db.awy[name] = t end
        t[#t + 1] = l
    end
end
-- "AE701 DA DAAE 11    171.0      1.0      0.0 R     5580    14000      230"
parse["earth_hold.dat"] = function(db, l)
    local ident, region = match(l, "^(%S+)%s+(%S+)%s+%S+%s+%S+%s+%S+")
    if not ident then return end
    local key = ident .. " " .. region
    local t = db.hold[key]
    if not t then t = {}; db.hold[key] = t end
    t[#t + 1] = l
end

-- after the waypoints and the airways: each airport's terminal waypoints
-- and each airway's segments joined into one string (far fewer objects for
-- the garbage collector to go through), some keys a call
local FINISH_KEYS = 200
local function finish(db)
    local t = db[db.fin]
    for _ = 1, FINISH_KEYS do
        local k, v = next(t, db.fin_key)
        if k == nil then db.fin, db.fin_key = nil, nil; return end
        if type(v) == "table" then t[k] = table.concat(v, "\n") end
        db.fin_key = k
    end
end
local FINISH = {["earth_fix.dat"] = "term", ["earth_awy.dat"] = "awy"}

-- the lines of a joined string, or of the table not yet joined
local function each_line(v)
    if type(v) == "string" then return v:gmatch("[^\n]+") end
    local i = 0
    return function() i = i + 1; return v and v[i] end
end

-- reads up to `bytes` (M.BLOCK by default) of the files in turn; true when
-- all are read. A missing file is skipped (db.missing).
function M.load(db, bytes)
    bytes = bytes or M.BLOCK
    while not db.ready and bytes > 0 do
        if db.fin then
            finish(db)
            bytes = bytes - FINISH_KEYS * 64
        elseif not db.file then
            db.step = db.step + 1
            local name = M.FILES[db.step]
            if not name then db.ready = true; break end
            db.file = db.open(name)
            db.rest, db.lines = "", 0
            if not db.file then db.missing[#db.missing + 1] = name end
        end
        local f = db.file
        if f then
            local name = M.FILES[db.step]
            local block = f:read(math.min(bytes, M.BLOCK))
            if block then
                bytes = bytes - #block
                local text = db.rest .. block
                local last = 1
                local p = parse[name]
                for line, e in text:gmatch("([^\n]*)\n()") do
                    db.lines = db.lines + 1
                    if db.lines <= 3 then
                        header(db, line)
                    elseif line ~= "99" and line ~= "99\r" then
                        p(db, line)
                    end
                    last = e
                end
                db.rest = sub(text, last)
            else
                if db.rest ~= "" and db.rest ~= "99" then parse[name](db, db.rest) end
                f:close()
                db.file = nil
                if FINISH[name] then db.fin, db.fin_key = FINISH[name], nil end
            end
        else
            db.file = nil
        end
    end
    return db.ready
end

-- a point's record
local function record(db, i)
    local r = {kind = db.kind[i], ident = db.ident[i], lat = db.lat[i], lon = db.lon[i], region = db.region[i]}
    local nav = db.nav[i]
    if nav then for k, v in pairs(nav) do r[k] = v end end
    return r
end

-- an airport's record
function M.airport(db, icao)
    local a = db.apt[icao]
    if not a then return nil end
    return {kind = M.APT, ident = a.icao, region = a.region, lat = a.lat, lon = a.lon, elev = a.elev, ta = a.ta, tl = a.tl}
end

-- the terminal waypoints of an airport with this identifier
function M.terminal(db, icao, ident)
    local list = {}
    local prefix = ident .. " "
    for l in each_line(db.term[icao]) do
        if sub(l, 1, #prefix) == prefix then
            local region, lat, lon = match(l, "^%S+ (%S+) (%S+) (%S+)")
            list[#list + 1] = {kind = M.WPT, ident = ident, region = region, lat = tonumber(lat), lon = tonumber(lon), terminal = icao}
        end
    end
    return list
end

-- every record with this identifier: waypoints, navaids, the airport, and
-- the terminal waypoints of the airports listed in `airports` (the origin's
-- and the destination's: estimated). With lat and lon, nearest first.
function M.find(db, ident, lat, lon, airports)
    local list = {}
    local i = db.first[ident]
    while i do
        list[#list + 1] = record(db, i)
        i = db.nxt[i]
    end
    local a = M.airport(db, ident)
    if a then list[#list + 1] = a end
    for _, icao in ipairs(airports or {}) do
        for _, r in ipairs(M.terminal(db, icao, ident) or {}) do list[#list + 1] = r end
    end
    if lat and lon then
        for _, r in ipairs(list) do r.dist = M.distance(lat, lon, r.lat, r.lon) end
        table.sort(list, function(a, b) return a.dist < b.dist end)
    end
    return list
end

-- the point with this identifier, region and kind (a waypoint, a VOR, an
-- NDB: as airways and holds name them); a terminal waypoint of `airport`
-- when there is no enroute one
function M.point(db, ident, region, kind, airport)
    local i = db.first[ident]
    while i do
        if db.region[i] == region and (not kind or db.kind[i] == kind
            or (kind == M.VOR and db.kind[i] == M.DME)) then
            return record(db, i)
        end
        i = db.nxt[i]
    end
    if airport then
        for _, r in ipairs(M.terminal(db, airport, ident) or {}) do
            if r.region == region then return r end
        end
    end
    return nil
end

-- an airway's segments: {from = {ident, region, kind}, to = ..., dir ("N":
-- both ways, "F": from -> to only, "B": to -> from only), level (1 low, 2
-- high), base, top (hundreds of feet)}
function M.airway(db, name)
    local t = db.awy[name]
    if not t then return nil end
    local list = {}
    for l in each_line(t) do
        local i1, r1, t1, i2, r2, t2, dir, lvl, base, top =
            match(l, "^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        list[#list + 1] = {from = {ident = i1, region = r1, kind = AWY_KIND[t1]},
            to = {ident = i2, region = r2, kind = AWY_KIND[t2]},
            dir = dir, level = tonumber(lvl), base = tonumber(base), top = tonumber(top)}
    end
    return list
end

-- the points along an airway from one identifier to another, both included,
-- in the direction flown (a one-way segment only its way); nil when either
-- is not on it or no way joins them. Several branches: the fewest points.
function M.airway_path(db, name, from, to)
    local segs = M.airway(db, name)
    if not segs then return nil end
    local key = function(p) return p.ident .. " " .. p.region end
    local nodes, links = {}, {}
    local function link(a, b)
        local ka, kb = key(a), key(b)
        nodes[ka], nodes[kb] = a, b
        links[ka] = links[ka] or {}
        links[ka][#links[ka] + 1] = kb
    end
    for _, s in ipairs(segs) do
        if s.dir ~= "B" then link(s.from, s.to) end
        if s.dir ~= "F" then link(s.to, s.from) end
    end
    -- the start: each node with the identifier (several regions possible)
    local queue, prev, head = {}, {}, 1
    for k, p in pairs(nodes) do
        if p.ident == from then queue[#queue + 1] = k; prev[k] = false end
    end
    while queue[head] do
        local k = queue[head]
        head = head + 1
        if nodes[k].ident == to and prev[k] ~= false then
            local path = {}
            while k do
                table.insert(path, 1, nodes[k])
                k = prev[k] or nil
            end
            return path
        end
        for _, n in ipairs(links[k] or {}) do
            if prev[n] == nil then prev[n] = k; queue[#queue + 1] = n end
        end
    end
    return nil
end

-- the published holds at a point: {inbound (magnetic), time (minutes, 0:
-- by distance), dist (nm), turn ("L"/"R"), min_alt, max_alt (feet, 0:
-- none), speed (kt, 0: none), terminal ("ENRT" or the airport)}
function M.holds(db, ident, region)
    local t = db.hold[ident .. " " .. region]
    local list = {}
    for _, l in ipairs(t or {}) do
        local term, kind, inb, time, dist, turn, amin, amax, spd =
            match(l, "^%S+%s+%S+%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)")
        if term then
            list[#list + 1] = {terminal = term, kind = AWY_KIND[kind], inbound = tonumber(inb),
                time = tonumber(time), dist = tonumber(dist), turn = turn,
                min_alt = tonumber(amin), max_alt = tonumber(amax), speed = tonumber(spd)}
        end
    end
    return list
end

-- "N35481872" (degrees, minutes, seconds and hundredths) in degrees
local function dms(s)
    local h, d, m, sec = match(s or "", "^([NSEW])(%d+)(%d%d)(%d%d%d%d)$")
    if not h then return nil end
    local v = tonumber(d) + tonumber(m) / 60 + tonumber(sec) / 360000
    return (h == "S" or h == "W") and -v or v
end
M.dms = dms

-- an airport's CIFP: {runways = {RW16L = {ident, lat, lon, elev (feet),
-- loc (the localizer's identifier or nil), cat, displaced (feet)}},
-- sid/star/appch = {name = {transition = {the legs' fields}}}, order =
-- {sid/star/appch = the names in the file's order}}. Read once; nil when
-- the airport has none.
function M.cifp(db, icao)
    local c = db.cifp[icao]
    if c ~= nil then return c or nil end
    local f = db.open("CIFP/" .. icao .. ".dat")
    if not f then db.cifp[icao] = false; return nil end
    c = {runways = {}, sid = {}, star = {}, appch = {}, order = {sid = {}, star = {}, appch = {}}}
    local KIND = {SID = "sid", STAR = "star", APPCH = "appch"}
    for line in f:lines() do
        line = line:gsub("\r$", "")
        local rtype, rest = match(line, "^(%u+):(.*)$")
        if rtype == "RWY" then
            -- RWY:RW16L,     ,      ,00135, ,ITM ,1,   ;N35481872,E140224119,0000;
            -- the runway, gradient, ellipsoid height, threshold elevation,
            -- TCH indicator, localizer, category; the threshold, displaced by
            local head, la, lo, disp = match(rest, "^([^;]*);([^,]*),([^,]*),([^;]*);")
            if head then
                local fields = {}
                for v in (head .. ","):gmatch("([^,]*),") do fields[#fields + 1] = v:match("^%s*(.-)%s*$") end
                local id, lat, lon = fields[1], dms(la), dms(lo)
                if id and lat and lon then
                    c.runways[id] = {ident = id, lat = lat, lon = lon, elev = tonumber(fields[4]) or 0,
                        loc = fields[6] ~= "" and fields[6] or nil, cat = tonumber(fields[7]),
                        displaced = tonumber(disp) or 0}
                end
            end
        elseif KIND[rtype] then
            local fields = {}
            for v in (rest:gsub(";$", "") .. ","):gmatch("([^,]*),") do fields[#fields + 1] = v:match("^%s*(.-)%s*$") end
            local kind, name, trans = KIND[rtype], fields[3], fields[4]
            local procs = c[kind]
            local p = procs[name]
            if not p then
                p = {}; procs[name] = p
                c.order[kind][#c.order[kind] + 1] = name
            end
            local legs = p[trans]
            if not legs then legs = {}; p[trans] = legs end
            legs[#legs + 1] = fields
        end
    end
    f:close()
    db.cifp[icao] = c
    return c
end

-- the IDENT page's date range of a cycle starting on `first` (FCOM p.1283:
-- "APR14MAY12/05"): its first day, the next cycle's, the first's year
local MONTHS = {"JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"}
function M.date_range(first)
    local y1, m1, d1 = civil(first)
    local _, m2, d2 = civil(first + 28)
    return string.format("%s%02d%s%02d/%02d", MONTHS[m1], d1, MONTHS[m2], d2, y1 % 100)
end

-- a date past the database's cycle (NAV DATA OUT OF DATE: FCOM p.1433)
function M.out_of_date(db, y, m, d)
    return db.last_day ~= nil and days(y, m, d) > db.last_day
end

-- the data cycle: the AIRAC cycle, its first and last day (days since 1970)
function M.cycle_info(db)
    return db.cycle, db.first_day, db.last_day
end

return M
