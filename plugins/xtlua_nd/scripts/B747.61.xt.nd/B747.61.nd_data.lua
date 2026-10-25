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

return M
