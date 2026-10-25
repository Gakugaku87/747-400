-- B747 test route for FlyWithLua NG+ (X-Plane 12): loads a set flight plan
-- into X-Plane's FMS, the one the aircraft's FMC and ND read (xtlua/fms).
-- Part of the 747-400 overhaul flight-test kit (docs/overhaul/TESTING.md).
-- The master copy lives in the aircraft repository at tests/flight/fwl/;
-- copy it to X-Plane 12/Resources/plugins/FlyWithLua/Scripts/ to use it.
--
-- Commands (also reachable through the X-Plane Web API):
--   FlyWithLua/B747_route/load    read Output/B747_flighttest/route.txt and load it
--   FlyWithLua/B747_route/clear   empty the flight plan
-- route.txt: one entry per line, "#" starts a comment:
--   IDENT LAT LON ALT [ACTIVE]
-- IDENT is looked up among the airports, VORs, NDBs and fixes nearest to
-- LAT LON (XPLMFindNavAid, through LuaJIT's FFI); without a match the entry
-- is the position LAT LON. ALT is the entry's altitude in feet (0: none).
-- ACTIVE makes the entry the one being flown to (XPLMSetDestinationFMSEntry).
-- Output/B747_flighttest/route_log.txt gets what was loaded.

local VERSION = "1"

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
    void XPLMClearFMSEntry(int inIndex);
    void XPLMSetDestinationFMSEntry(int inIndex);
    void XPLMSetDisplayedFMSEntry(int inIndex);
]]

local OUT_DIR = SYSTEM_DIRECTORY .. "Output/B747_flighttest/"
local NAV_TYPES = 1 + 2 + 4 + 512               -- airport, NDB, VOR, fix
local NAV_NOT_FOUND = -1

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
        if ref == NAV_NOT_FOUND then
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

create_command("FlyWithLua/B747_route/load", "B747 test route: load route.txt into the FMS", "B747RT_load()", "", "")
create_command("FlyWithLua/B747_route/clear", "B747 test route: empty the FMS", "B747RT_clear()", "", "")
logMsg("B747 route v" .. VERSION .. ": ready")
