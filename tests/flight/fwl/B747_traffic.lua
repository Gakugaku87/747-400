-- B747 test traffic for FlyWithLua NG+ (X-Plane 12): TCAS targets on set paths.
-- Part of the 747-400 overhaul flight-test kit (docs/overhaul/TESTING.md).
-- The master copy lives in the aircraft repository at tests/flight/fwl/;
-- copy it to X-Plane 12/Resources/plugins/FlyWithLua/Scripts/ to use it.
--
-- X-Plane's TCAS (sim/cockpit2/tcas/...) works on the planes in its TCAS
-- arrays. On start this takes X-Plane's AI planes (XPLMAcquirePlanes, through
-- LuaJIT's FFI), sets sim/operation/override/override_TCAS and writes each
-- target's position and velocity every frame. A target is removed by no longer
-- writing it: X-Plane drops a target not updated for 10 frames and forgets its
-- mode S address (developer.x-plane.com, "Overriding TCAS and providing
-- traffic information"). On stop it stops writing, waits RELEASE_S so that
-- X-Plane drops the targets, then lets the AI planes go. It does nothing until
-- started, so it does not touch other flights.
--
-- Commands (also reachable through the X-Plane Web API):
--   FlyWithLua/B747_traffic/start   read Output/B747_flighttest/traffic.txt and fly its targets
--   FlyWithLua/B747_traffic/stop    remove the targets and give the AI planes back
-- traffic.txt: one target per line, "key=value" pairs, "#" starts a comment:
--   tcpa  seconds from start to the closest point of approach (default 60)
--   brg   where the target comes from, degrees clockwise from our track at the
--         start (0 head-on, 90 from the right, 180 from behind; default 0)
--   gs    target ground speed, kt (default 250)
--   dh    target altitude above ours at the closest point, ft (default 0)
--   vs    target vertical speed, fpm (default 0)
--   miss  horizontal miss distance at the closest point, nm, + to the right of
--         our track (default 0)
--   ssr   target transponder mode as X-Plane's enum (default 3, mode C)
--   life  seconds after which the target is removed (default tcpa + 60)
--   ownvs 1: take our vertical speed at the start into the path (default 0:
--         our airplane taken as level)
-- Our airplane is taken as flying straight at its start velocity; if it turns
-- or changes its vertical speed, the geometry changes as it would in the air.
-- Output/B747_flighttest/traffic_log.txt gets one line per target per second.

local VERSION = "2"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 traffic: not the 747-400, inactive")
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
    typedef void (*XPLMPlanesAvailable_f)(void *inRefcon);
    int  XPLMAcquirePlanes(char **inAircraft, XPLMPlanesAvailable_f inCallback, void *inRefcon);
    void XPLMReleasePlanes(void);
    void XPLMWorldToLocal(double inLatitude, double inLongitude, double inAltitude,
                          double *outX, double *outY, double *outZ);
]]

local OUT_DIR = SYSTEM_DIRECTORY .. "Output/B747_flighttest/"
local KT = 0.514444
local FT = 0.3048
local FPM = FT / 60
local NM = 1852
local R_EARTH = 6371000
local MAX_TARGETS = 8
local RELEASE_S = 1                             -- well over 10 frames

dataref("B747TR_lat", "sim/flightmodel/position/latitude", "readonly")
dataref("B747TR_lon", "sim/flightmodel/position/longitude", "readonly")
dataref("B747TR_ele", "sim/flightmodel/position/elevation", "readonly")
dataref("B747TR_ly", "sim/flightmodel/position/local_y", "readonly")
dataref("B747TR_vx", "sim/flightmodel/position/local_vx", "readonly")
dataref("B747TR_vy", "sim/flightmodel/position/local_vy", "readonly")
dataref("B747TR_vz", "sim/flightmodel/position/local_vz", "readonly")
dataref("B747TR_time", "sim/time/total_running_time_sec", "readonly")
local tx = dataref_table("sim/cockpit2/tcas/targets/position/x")
local ty = dataref_table("sim/cockpit2/tcas/targets/position/y")
local tz = dataref_table("sim/cockpit2/tcas/targets/position/z")
local tvx = dataref_table("sim/cockpit2/tcas/targets/position/vx")
local tvy = dataref_table("sim/cockpit2/tcas/targets/position/vy")
local tvz = dataref_table("sim/cockpit2/tcas/targets/position/vz")
local tvs = dataref_table("sim/cockpit2/tcas/targets/position/vertical_speed")
local tpsi = dataref_table("sim/cockpit2/tcas/targets/position/psi")
local tthe = dataref_table("sim/cockpit2/tcas/targets/position/the")
local tphi = dataref_table("sim/cockpit2/tcas/targets/position/phi")
local twow = dataref_table("sim/cockpit2/tcas/targets/position/weight_on_wheels")
local tssr = dataref_table("sim/cockpit2/tcas/targets/ssr_mode")
local tid = dataref_table("sim/cockpit2/tcas/targets/modeS_id")
local tthreat = dataref_table("sim/cockpit2/tcas/targets/threat")
local tele = dataref_table("sim/cockpit2/tcas/targets/position/ele")

local wx, wy, wz = ffi.new("double[1]"), ffi.new("double[1]"), ffi.new("double[1]")
local acquired = false
local release_at = nil                          -- time to let the AI planes go
local targets = {}
local origin = nil
local t0 = 0
local id_base = 0
local log = nil
local last_log = -1

local function parse(line)
    local p = {tcpa = 60, brg = 0, gs = 250, dh = 0, vs = 0, miss = 0, ssr = 3, ownvs = 0}
    for k, v in string.gmatch(line, "(%a+)%s*=%s*([%-%d%.]+)") do p[k] = tonumber(v) end
    p.life = p.life or (p.tcpa + 60)
    return p
end

local function read_targets()
    local f = io.open(OUT_DIR .. "traffic.txt", "r")
    if f == nil then return nil end
    local list = {}
    for line in f:lines() do
        line = string.gsub(line, "#.*", "")
        if string.find(line, "=") and #list < MAX_TARGETS then list[#list + 1] = parse(line) end
    end
    f:close()
    return list
end

-- the target's path in a flat east-north-up frame at our position at the start
local function plan(p, ve, vn, vu)
    local spd = math.sqrt(ve * ve + vn * vn)
    local ue, un = 0, 1
    if spd > 1 then ue, un = ve / spd, vn / spd end
    local re, rn = un, -ue                          -- to the right of our track
    local own_track = math.atan2(ue, un)
    local trk = own_track + math.rad(p.brg + 180)
    local gs = p.gs * KT
    local v = {e = gs * math.sin(trk), n = gs * math.cos(trk), u = p.vs * FPM}
    if p.ownvs ~= 1 then vu = 0 end
    local c = {e = ve * p.tcpa + re * p.miss * NM, n = vn * p.tcpa + rn * p.miss * NM,
               u = vu * p.tcpa + p.dh * FT}
    return {
        q0 = {e = c.e - v.e * p.tcpa, n = c.n - v.n * p.tcpa, u = c.u - v.u * p.tcpa},
        v = v, psi = (math.deg(trk) + 360) % 360,
        the = math.deg(math.atan2(v.u, gs)), ssr = p.ssr, life = p.life,
    }
end

local function release()
    if acquired then
        set("sim/operation/override/override_TCAS", 0)
        XPLM.XPLMReleasePlanes()
        acquired = false
    end
    release_at = nil
end

function B747TR_stop()
    targets = {}
    if acquired and release_at == nil then release_at = B747TR_time + RELEASE_S end
    if log ~= nil then log:close() log = nil end
    logMsg("B747 traffic: stopped")
end

function B747TR_start()
    targets = {}
    if log ~= nil then log:close() log = nil end
    local list = read_targets()
    if list == nil or #list == 0 then
        logMsg("B747 traffic: no targets in " .. OUT_DIR .. "traffic.txt")
        return
    end
    if not acquired then
        if XPLM.XPLMAcquirePlanes(nil, nil, nil) ~= 1 then
            logMsg("B747 traffic: X-Plane's AI planes are taken by another plugin")
            return
        end
        acquired = true
        -- written once with set(): a "writable" dataref variable would be written
        -- back every frame, and X-Plane flags writes while the planes are not ours
        set("sim/operation/override/override_TCAS", 1)
    end
    release_at = nil
    origin = {lat = B747TR_lat, lon = B747TR_lon, ele = B747TR_ele}
    -- XPLMWorldToLocal's height and the flight model's elevation differ by a
    -- few hundred feet (seen in X-Plane 12.4); our local y puts the targets
    -- at the heights asked for relative to us
    XPLM.XPLMWorldToLocal(origin.lat, origin.lon, origin.ele, wx, wy, wz)
    origin.dy = B747TR_ly - wy[0]
    local ve, vn, vu = B747TR_vx, -B747TR_vz, B747TR_vy
    for i, p in ipairs(list) do targets[i] = plan(p, ve, vn, vu) end
    t0 = B747TR_time
    -- a new mode S address for each start, so that a new target never takes
    -- the address of one X-Plane may still remember
    id_base = 0x100000 + (os.time() * 16) % 0xE00000
    last_log = -1
    log = io.open(OUT_DIR .. "traffic_log.txt", "w")
    logMsg(string.format("B747 traffic v%s: %d target(s)", VERSION, #targets))
end

function B747TR_frame()
    if not acquired then return end
    if release_at ~= nil then
        if B747TR_time >= release_at then release() end
        return
    end
    local t = B747TR_time - t0
    local coslat = math.cos(math.rad(origin.lat))
    local write_log = log ~= nil and math.floor(t) ~= last_log
    for n, g in ipairs(targets) do
        if t <= g.life then         -- after its life it is no longer written
            local e = g.q0.e + g.v.e * t
            local nn = g.q0.n + g.v.n * t
            local u = g.q0.u + g.v.u * t
            local lat = origin.lat + math.deg(nn / R_EARTH)
            local lon = origin.lon + math.deg(e / (R_EARTH * coslat))
            XPLM.XPLMWorldToLocal(lat, lon, origin.ele + u, wx, wy, wz)
            tx[n], ty[n], tz[n] = wx[0], wy[0] + origin.dy, wz[0]
            tvx[n], tvy[n], tvz[n] = g.v.e, g.v.u, -g.v.n
            tvs[n] = g.v.u / FPM
            tpsi[n], tthe[n], tphi[n] = g.psi, g.the, 0
            twow[n] = 0
            tssr[n] = g.ssr
            tid[n] = id_base + n
            if write_log then
                log:write(string.format("%.0f %d %.6f %.6f rel=%.0fft threat=%d\n", t, n, lat, lon,
                    (tele[n] - tele[0]) / FT, tthreat[n]))
            end
        end
    end
    if write_log then last_log = math.floor(t) log:flush() end
end

function B747TR_exit()
    if log ~= nil then log:close() log = nil end
    release()
end

create_command("FlyWithLua/B747_traffic/start", "B747 test traffic: start", "B747TR_start()", "", "")
create_command("FlyWithLua/B747_traffic/stop", "B747 test traffic: stop", "B747TR_stop()", "", "")
do_every_frame("B747TR_frame()")
do_on_exit("B747TR_exit()")
logMsg("B747 traffic v" .. VERSION .. ": ready")
