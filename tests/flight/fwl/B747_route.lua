-- B747 test route for FlyWithLua NG+ (X-Plane 12): loads a set flight plan
-- into X-Plane's FMS, the one the aircraft's FMC and ND read (xtlua/fms).
-- Part of the 747-400 overhaul flight-test kit (docs/overhaul/TESTING.md).
-- The master copy lives in the aircraft repository at tests/flight/fwl/;
-- copy it to X-Plane 12/Resources/plugins/FlyWithLua/Scripts/ to use it.
--
-- Commands (also reachable through the X-Plane Web API):
--   FlyWithLua/B747_route/load    read Output/B747_flighttest/route.txt and load it
--   FlyWithLua/B747_route/clear   empty the flight plan
--   FlyWithLua/B747_route/dump    write every entry of the flight plan to
--                                 Output/B747_flighttest/route_dump.txt
-- route.txt: one entry per line, "#" starts a comment:
--   IDENT LAT LON ALT [ACTIVE]
-- IDENT is looked up among the airports, VORs, NDBs and fixes nearest to
-- LAT LON (XPLMFindNavAid, through LuaJIT's FFI); without a match the entry
-- is the position LAT LON named IDENT (X-Plane 12's
-- XPLMSetFMSFlightPlanEntryLatLonWithId: a runway threshold as the FMS's
-- DEP ARR puts it, RW26R; unnamed where the function is missing). ALT is
-- the entry's altitude in feet (0: none).
-- ACTIVE makes the entry the one being flown to (XPLMSetDestinationFMSEntry).
-- Output/B747_flighttest/route_log.txt gets what was loaded.
-- route_dump.txt: "INDEX TYPE IDENT ALT LAT LON" per entry (TYPE: X-Plane's
-- navaid type, 1 airport, 2 NDB, 4 VOR, 512 fix, 2048 position), then the
-- entry being flown to and the one displayed.

local VERSION = "3"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 route: not the 747-400, inactive")
    return
end

local ffi = require("ffi")
local XPLM
if SYSTEM == "IBM" then
    XPLM = ffi.load("XPLM_64")
elseif SYSTEM == "LIN" then
    XPLM = ffi.load("Resources/plugins/XPLM_64.so")
else
    XPLM = ffi.load("Resources/plugins/XPLM.framework/XPLM")
end
ffi.cdef [[
    typedef int XPLMNavRef;
    typedef int XPLMNavType;
    XPLMNavRef XPLMFindNavAid(const char *inNameFragment, const char *inIDFragment, float *inLat, float *inLon,
                              int *inFrequency, XPLMNavType inType);
    void XPLMGetNavAidInfo(XPLMNavRef inRef, XPLMNavType *outType, float *outLatitude, float *outLongitude,
                           float *outHeight, int *outFrequency, float *outHeading, char *outID, char *outName,
                           char *outReg);
    int  XPLMCountFMSEntries(void);
    void XPLMSetFMSEntryInfo(int inIndex, XPLMNavRef inRef, int inAltitude);
    void XPLMSetFMSEntryLatLon(int inIndex, float inLat, float inLon, int inAltitude);
    void XPLMSetFMSFlightPlanEntryLatLonWithId(int inFlightPlan, int inIndex, float inLat, float inLon, int inAltitude,
                                               const char *inId, unsigned int inIdLength);
    void XPLMClearFMSEntry(int inIndex);
    void XPLMSetDestinationFMSEntry(int inIndex);
    void XPLMSetDisplayedFMSEntry(int inIndex);
    void XPLMGetFMSEntryInfo(int inIndex, XPLMNavType *outType, char *outID, XPLMNavRef *outRef, int *outAltitude,
                             float *outLat, float *outLon);
    int  XPLMGetDestinationFMSEntry(void);
    int  XPLMGetDisplayedFMSEntry(void);
]]

local OUT_DIR = SYSTEM_DIRECTORY .. "Output/B747_flighttest/"
local NAV_TYPES = 1 + 2 + 4 + 512               -- airport, NDB, VOR, fix
local NAV_NOT_FOUND = -1
local FPL_PILOT_PRIMARY = 0                     -- xplm_Fpl_Pilot_Primary
local HAS_WITH_ID = pcall(function() return XPLM.XPLMSetFMSFlightPlanEntryLatLonWithId end)

local function read_route()
    local f = io.open(OUT_DIR .. "route.txt", "r")
    if f == nil then return {} end
    local out = {}
    for line in f:lines() do
        line = line:gsub("#.*$", "")
        local id, lat, lon, alt, rest = line:match("^%s*(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
        if id and tonumber(lat) and tonumber(lon) and tonumber(alt) then
            out[#out + 1] = {id = id, lat = tonumber(lat), lon = tonumber(lon), alt = math.floor(tonumber(alt) + 0.5),
                active = rest:upper() == "ACTIVE"}
        end
    end
    f:close()
    return out
end

function B747RT_clear()
    for i = XPLM.XPLMCountFMSEntries() - 1, 0, -1 do XPLM.XPLMClearFMSEntry(i) end
end

function B747RT_load()
    local route = read_route()
    if #route == 0 then
        logMsg("B747 route: no entries in " .. OUT_DIR .. "route.txt")
        return
    end
    B747RT_clear()
    local log = io.open(OUT_DIR .. "route_log.txt", "w")
    local active = 0
    for i, e in ipairs(route) do
        local lat, lon = ffi.new("float[1]", e.lat), ffi.new("float[1]", e.lon)
        local ref = XPLM.XPLMFindNavAid(nil, e.id, lat, lon, nil, NAV_TYPES)
        local found = ""
        if ref ~= NAV_NOT_FOUND then
            local id = ffi.new("char[32]")
            local nlat, nlon = ffi.new("float[1]"), ffi.new("float[1]")
            XPLM.XPLMGetNavAidInfo(ref, nil, nlat, nlon, nil, nil, nil, id, nil, nil)
            if ffi.string(id) == e.id then
                XPLM.XPLMSetFMSEntryInfo(i - 1, ref, e.alt)
                found = string.format("%s %.4f %.4f", ffi.string(id), nlat[0], nlon[0])
            else
                ref = NAV_NOT_FOUND
            end
        end
        if ref == NAV_NOT_FOUND and HAS_WITH_ID then
            XPLM.XPLMSetFMSFlightPlanEntryLatLonWithId(FPL_PILOT_PRIMARY, i - 1, e.lat, e.lon, e.alt, e.id, #e.id)
            found = string.format("position %.4f %.4f named %s", e.lat, e.lon, e.id)
        elseif ref == NAV_NOT_FOUND then
            XPLM.XPLMSetFMSEntryLatLon(i - 1, e.lat, e.lon, e.alt)
            found = string.format("position %.4f %.4f", e.lat, e.lon)
        end
        if e.active then active = i - 1 end
        if log then log:write(string.format("%d %s alt %d: %s%s\n", i - 1, e.id, e.alt, found, e.active and " active" or "")) end
    end
    XPLM.XPLMSetDestinationFMSEntry(active)
    XPLM.XPLMSetDisplayedFMSEntry(active)
    if log then log:close() end
    logMsg(string.format("B747 route: %d entries loaded, entry %d active", #route, active))
end

function B747RT_dump()
    local log = io.open(OUT_DIR .. "route_dump.txt", "w")
    if log == nil then return end
    local n = XPLM.XPLMCountFMSEntries()
    local typ, id, ref, alt = ffi.new("int[1]"), ffi.new("char[256]"), ffi.new("int[1]"), ffi.new("int[1]")
    local lat, lon = ffi.new("float[1]"), ffi.new("float[1]")
    for i = 0, n - 1 do
        XPLM.XPLMGetFMSEntryInfo(i, typ, id, ref, alt, lat, lon)
        log:write(string.format("%d %d %s %d %.6f %.6f\n", i, typ[0], ffi.string(id), alt[0], lat[0], lon[0]))
    end
    log:write(string.format("entries %d, flown to %d, displayed %d\n", n, XPLM.XPLMGetDestinationFMSEntry(),
        XPLM.XPLMGetDisplayedFMSEntry()))
    log:close()
    logMsg(string.format("B747 route: %d entries written", n))
end

create_command("FlyWithLua/B747_route/load", "B747 test route: load route.txt into the FMS", "B747RT_load()", "", "")
create_command("FlyWithLua/B747_route/clear", "B747 test route: empty the FMS", "B747RT_clear()", "", "")
create_command("FlyWithLua/B747_route/dump", "B747 test route: write the FMS entries", "B747RT_dump()", "", "")
logMsg("B747 route v" .. VERSION .. ": ready")
