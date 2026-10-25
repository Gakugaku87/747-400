-- The ND's route data (5-2 step 5c): with that side's DATA switch on, under
-- each route waypoint in PLAN, MAP and MAP CTR, its altitude (entered or
-- procedural: the altitude of X-Plane's FMS entry) and the FMC's ETA
-- (laminar/B747/fms/route_eta, B747.68.xt.fms.lua), magenta for the active
-- waypoint and white for the others (FCOM p.1040, p.1148; FMSPG p.50: KILMR,
-- 12000, 0835Z). Pure functions; B747.61.xt.nd.lua fills its slots with
-- them:
--   local D = B747_nd_data                 -- in XTLua, after dofile
--   local D = dofile("./B747.61.nd_data.lua")   -- in the tests
local M = setmetatable({}, {})
B747_nd_data = M

M.SLOTS = 20                    -- the slots with route data lines: the route waypoints take the first slots
M.NONE, M.WHITE, M.MAGENTA = 0, 1, 2
M.TRANS_ALT_FT = 18000          -- the FMC's transition altitude when it gives none (as the PFD's)

-- the altitude line: none for an entry without an altitude (X-Plane gives
-- 0); a flight level at and above the FMC's transition altitude (estimate:
-- the sources show 12000 only; the CDU's way)
function M.alt_text(alt_ft, trans_alt_ft)
    if type(alt_ft) ~= "number" or alt_ft < 1 then return nil end
    if alt_ft >= trans_alt_ft then return string.format("FL%03d", math.floor(alt_ft / 100 + 0.5)) end
    return string.format("%d", math.floor(alt_ft + 0.5))
end

-- the ETA line: the zulu time of day in minutes as HHMMZ; none for -1
function M.eta_text(minutes)
    if type(minutes) ~= "number" or minutes < 0 then return nil end
    local m = math.floor(minutes) % 1440
    return string.format("%02d%02dZ", math.floor(m / 60), m % 60)
end

-- STA's high altitude navaids (FCOM p.1040: high and low altitude navaids
-- at 10, 20 and 40 NM, high altitude ones on the longer ranges): a VOR or
-- NDB with X-Plane's reception range of 100 NM and more (earth_nav.dat:
-- VORs 125, 130, 150 high, 40 low, 25 terminal; NDBs 75 and less); a line
-- of earth_nav.dat gives its identifier and position, or nil
M.NAV_HIGH_NM = 100
M.NAV_LINES = 500               -- earth_nav.dat lines read a frame
function M.nav_line(line)
    local t, lat, lon, rng, id = line:match("^%s*(%d+)%s+(%S+)%s+(%S+)%s+%S+%s+%S+%s+(%S+)%s+%S+%s+(%S+)")
    if t ~= "2" and t ~= "3" then return nil end
    rng = tonumber(rng)
    if not rng or rng < M.NAV_HIGH_NM then return nil end
    lat, lon = tonumber(lat), tonumber(lon)
    if not lat or not lon then return nil end
    return id, lat, lon
end

-- a navaid among the positions {lat, lon, lat, lon, ...} kept for its
-- identifier: within 0.1 degree
function M.nav_near(list, lat, lon)
    if list == nil then return false end
    for k = 1, #list, 2 do
        if math.abs(list[k] - lat) < 0.1 and math.abs(list[k + 1] - lon) < 0.1 then return true end
    end
    return false
end

-- a slot's colour and two lines: the altitude, then the ETA; the ETA on the
-- first line when there is no altitude (estimate: the sources show a
-- waypoint with both); none without the DATA switch or data
function M.lines(on, active, alt, eta)
    if not on or (alt == nil and eta == nil) then return M.NONE, " ", " " end
    local color = active and M.MAGENTA or M.WHITE
    if alt == nil then return color, eta, " " end
    return color, alt, eta or " "
end

-- The origin and destination airports and their runways (step 5c, FCOM
-- p.1149), in MAP, MAP CTR and PLAN whatever the ARPT switch, in white: on
-- 80 NM and more the airport symbol with its identifier and the selected
-- runway's under it, a line from the symbol along the runway; on 10 to 40
-- NM the selected runway to scale, dashed centrelines 14.2 NM from both
-- ends, its identifier at its threshold.
M.RWY_NEAR_NM = 6               -- a runway entry this near its airport (estimate)
M.APT_RANGE_NM = 80             -- the airport symbol from this range up; the runway below it
M.CL_NM = 14.2                  -- the dashed runway centrelines (FCOM p.1149)
-- the dashes: 12 pixels and 10 apart from 4 beyond the runway's end, 30 a
-- side for 14.2 NM at 10 NM (estimate: FCOM's figure); the runway image's
-- frames: 4, 8, ... 160 pixels long
M.DASH_PX, M.DASH_GAP_PX, M.DASH_START_PX = 12, 10, 4
M.DASHES = 30
M.RWY_FRAME_PX, M.RWY_FRAMES = 4, 40
-- the map's visible part, in pixels from the airplane symbol (the selected
-- range is 465) up the display's top: expanded, the range arc ahead within
-- the display's sides (as the POS radials: B747.60.nd_model.lua's edge_px);
-- MAP CTR and PLAN, the circles of the map symbols' limits (makeIcon: 250
-- and 450 of 640 units)
M.PX_PER_RANGE = 465
M.EXP_ARC_PX, M.EXP_LEFT_PX, M.EXP_RIGHT_PX = 465, 329, 348
M.CTR_PX = 250 / 640 * 465
M.PLAN_PX = 450 / 640 * 465
M.EXPANDED, M.CENTRED, M.PLAN = 1, 2, 3

local FT_PER_NM = 6076.12

-- the distance (NM) from one position to another near it, and its east and
-- north parts
local function flat(lat1, lon1, lat2, lon2)
    local dy = (lat2 - lat1) * 60
    local dx = (lon2 - lon1) * 60 * math.cos(math.rad((lat1 + lat2) / 2))
    return math.sqrt(dx * dx + dy * dy), dx, dy
end

-- a runway entry's identifier without its RW ("RW25C": "25C"), or nil
function M.rwy_id(id)
    if type(id) ~= "string" then return nil end
    local n, s = id:match("^RW(%d%d)([LCR]?)%s*$")
    if not n then return nil end
    return n .. s
end

-- the identifier of the runway's other end: RW25C RW07C, RW26R RW08L, RW18
-- RW36
function M.rwy_opposite(id)
    local n, s = (id or ""):match("^RW(%d%d)([LCR]?)%s*$")
    if not n then return nil end
    return string.format("RW%02d%s", (tonumber(n) + 17) % 36 + 1, ({L = "R", R = "L", C = "C"})[s] or "")
end

-- the route's origin and destination and their selected runways, as
-- X-Plane's FMS keeps them (xtlua/fms: [2] type, 1 an airport, [5] [6]
-- position, [8] identifier): the first entry the origin airport, the last
-- the destination airport (the FMS takes no destination without an
-- origin); the departure runway follows the origin, the approach's runway
-- comes before the missed approach and the destination: an entry RW and the
-- runway's number within RWY_NEAR_NM of the airport. Indices or nil.
function M.route_ends(fms)
    local n = #fms
    local o, orw, d, drw
    if n >= 1 and fms[1][2] == 1 then o = 1 end
    if n >= 2 and fms[n][2] == 1 then d = n end
    local function near(a, e)
        return M.rwy_id(e[8]) ~= nil and flat(a[5], a[6], e[5], e[6]) <= M.RWY_NEAR_NM
    end
    if o then
        for i = 2, (d or n + 1) - 1 do
            if near(fms[o], fms[i]) then orw = i break end
        end
    end
    if d then
        for i = d - 1, (o or 0) + 1, -1 do
            if near(fms[d], fms[i]) then drw = i break end
        end
    end
    return o, orw, d, drw
end

-- a runway threshold in X-Plane's CIFP file of the airport (the navigation
-- data's CIFP/<airport>.dat: "RWY:RW25C,...;N50024246,E008351313,0000;"):
-- its identifier, position and displaced threshold (feet), or nil
function M.cifp_rwy(line)
    local id, ns, la, lm, ls, ew, lo, om, os, disp = line:match(
        "^RWY:(RW%d%d[LCR]?)%s*,.-;([NS])(%d%d)(%d%d)(%d%d%d%d),([EW])(%d%d%d)(%d%d)(%d%d%d%d),(%d+)")
    if not id then return nil end
    local lat = tonumber(la) + tonumber(lm) / 60 + tonumber(ls) / 360000
    local lon = tonumber(lo) + tonumber(om) / 60 + tonumber(os) / 360000
    if ns == "S" then lat = -lat end
    if ew == "W" then lon = -lon end
    return id, lat, lon, tonumber(disp)
end

-- a runway from its thresholds, the selected one first, and their displaced
-- thresholds (feet: the runway's ends that far behind them): its middle,
-- its length (NM) and the true bearing from the middle to the selected
-- threshold's end; nil for thresholds at one place
function M.runway(lat1, lon1, d1, lat2, lon2, d2)
    local len, dx, dy = flat(lat1, lon1, lat2, lon2)
    if len < 0.05 then return nil end
    local ux, uy = dx / len, dy / len
    local f1, f2 = (d1 or 0) / FT_PER_NM, (d2 or 0) / FT_PER_NM
    -- the ends from the selected threshold, NM east and north
    local mx = (-f1 * ux + dx + f2 * ux) / 2
    local my = (-f1 * uy + dy + f2 * uy) / 2
    local mlat = lat1 + my / 60
    local mlon = lon1 + mx / (60 * math.cos(math.rad((lat1 + lat2) / 2)))
    return mlat, mlon, len + f1 + f2, math.deg(math.atan2(-ux, -uy)) % 360
end

-- a point on the map's visible part (view: EXPANDED, CENTRED, PLAN)
function M.inside(x, y, view)
    if view == M.EXPANDED then
        return y >= 0 and x >= -M.EXP_LEFT_PX and x <= M.EXP_RIGHT_PX and x * x + y * y <= M.EXP_ARC_PX * M.EXP_ARC_PX
    end
    local r = view == M.CENTRED and M.CTR_PX or M.PLAN_PX
    return x * x + y * y <= r * r
end

-- the runway image's frame for its length in pixels
function M.rwy_frame(len_px)
    local f = math.floor(len_px / M.RWY_FRAME_PX + 0.5) - 1
    return math.max(0, math.min(M.RWY_FRAMES - 1, f))
end

-- the dashed centrelines of a runway, its middle at x, y (pixels from the
-- airplane symbol), dir the display's bearing to its selected threshold's
-- end (degrees clockwise from the top), len_px its length: out[base + e *
-- DASHES + j] 1 for dash j beyond that end (e 0) or the other (e 1) within
-- 14.2 NM and on the visible part, else 0
function M.dashes(x, y, dir, len_px, px_per_nm, view, out, base)
    local ux, uy = math.sin(math.rad(dir)), math.cos(math.rad(dir))
    local limit = M.CL_NM * px_per_nm
    for e = 0, 1 do
        local s = e == 0 and 1 or -1
        for j = 0, M.DASHES - 1 do
            local a = M.DASH_START_PX + j * (M.DASH_PX + M.DASH_GAP_PX)
            local v = 0
            if a < limit then
                local c = s * (len_px / 2 + a + M.DASH_PX / 2)
                if M.inside(x + c * ux, y + c * uy, view) then v = 1 end
            end
            out[base + e * M.DASHES + j] = v
        end
    end
end

-- The manually tuned VORs' course lines (step 5c, FCOM p.1145: "When a
-- navaid is manually tuned, the selected course and reciprocal display"),
-- in MAP and MAP CTR: a dashed line through the station along the NAV
-- RADIO page's course, both ways to the map's edge, the course and the
-- reciprocal along it on each side, in green (estimate: the tuned navaid's
-- colour; the dashes as the runways', the numbers 50 pixels from the
-- station as the POS radials' text). The panel draws CRS_DASHES dashes
-- each side of the line's point nearest the airplane, their pattern fixed
-- to the station (a dash's middle at (m + 1/2) dash periods from it).
M.CRS_DASHES = 42               -- 924 pixels each side: the display's diagonal
M.CRS_LABEL_PX = 50

-- a course's text, 001 to 360
function M.crs_text(deg)
    local d = math.floor(deg + 0.5) % 360
    if d == 0 then d = 360 end
    return string.format("%03d", d)
end

-- a line's label along it and readable: turned to the line's right (side 1)
-- for directions 0 to 180, else to its left (side 2), as the POS radials'
function M.crs_label(dir)
    local d = (dir + 180) % 360 - 180
    if d >= 0 then return d - 90, 1 end
    return d + 90, 2
end

-- the course line of a station at sx, sy (pixels from the airplane symbol,
-- up the display's top) along dir (degrees clockwise from the top): its
-- point nearest the airplane, the dashes' shift along the line from it,
-- and out[base + j + CRS_DASHES] 1 for dash j (-CRS_DASHES to CRS_DASHES)
-- on the map's visible part; whether any is
function M.crs_line(sx, sy, dir, view, out, base)
    local ux, uy = math.sin(math.rad(dir)), math.cos(math.rad(dir))
    local s = -(sx * ux + sy * uy)          -- the nearest point from the station
    local fx, fy = sx + s * ux, sy + s * uy
    local p = M.DASH_PX + M.DASH_GAP_PX
    local phase = p / 2 - (s - math.floor(s / p) * p)
    local any = false
    for j = -M.CRS_DASHES, M.CRS_DASHES do
        local c = phase + j * p
        local v = 0
        if M.inside(fx + c * ux, fy + c * uy, view) then v = 1 any = true end
        out[base + j + M.CRS_DASHES] = v
    end
    return fx, fy, phase, any
end

return M
