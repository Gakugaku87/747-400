-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-13] VNAV PTH's V/S through the last nm before a point of the descent's path (the FMC's profile, more than 15 nm
-- from the end of the descent): the path's own V/S, its gradient at the ground speed, corrected by the path error.
-- setDescentVSpeed aimed at the point's altitude over the time to it, with the distance held at 1 nm when nearer: on
-- the path the V/S fell with the distance to 0 at the point (p23-line1: -1,700 to 0 fpm in the last 8 s at each
-- point), the 747 levelled off, and with the next segment's path below it the descent went on 130-275 ft above the
-- path, the A/T to IDLE and HOLD (SPD again once the speed fell). The production setDescentVSpeed and energy mode
-- (vnav.lua through the XTLua dofile) with the 747 on the path at 400 kt from 3 nm before the point.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

local function load_in_environment(path, environment)
    local chunk, load_error = loadfile(path)
    assert(chunk ~= nil, load_error)
    setfenv(chunk, environment)
    chunk()
end
local runtime = setmetatable({}, {__index = _G})
load_in_environment("plugins/xtlua_keysystems/init.lua", runtime)
runtime.XLuaGetCode = function(requested_path)
    local resolved_path = requested_path
    if not string.find(requested_path, "/", 1, true) then resolved_path = AP..requested_path end
    local chunk, load_error = loadfile(resolved_path)
    assert(chunk ~= nil, load_error)
    return chunk
end
local vnav = setmetatable({}, {__index = _G})
vnav.dofile = runtime.get_run_file_in_namespace(vnav)
vnav.dofile(AP.."B747.70.xt.autopilot.vnav.lua")
-- the autopilot script's getDistance (nm), which vnav.lua calls
do
    local file = assert(io.open(AP.."B747.70.xt.autopilot.lua"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("function getDistance(lat1, lon1, lat2, lon2)", 1, true))
    local last = assert(source:find("\nend\n", first, true))
    local chunk = assert(loadstring(source:sub(first, last + 4)))
    setfenv(chunk, vnav)
    chunk()
end

-- the point: 21,438 ft at 52.5 N 4.5 E, its path 266 ft/nm (LAMSO's on the EHAM route), approached from the west
local P_LAT, P_LON, P_ALT, GRADIENT = 52.5, 4.5, 21438, 266
local profile = {{P_LAT, P_LON, P_ALT, true, GRADIENT}}
vnav.json = {decode = function() return profile end}
local GS_KT = 400
local NM_DEG_LON = 1 / (60 * math.cos(math.rad(P_LAT)))
local sim = {
    simDRTime = 100, B747BR_totalDistance = 40, B747BR_fpe = 0, B747BR_vnavProfile = "[[p]]",
    B747DR_fmstargetDistance = 3, B747DR_ap_vnav_target_alt = P_ALT,
    simDR_autopilot_altitude_ft = 7000, simDR_groundspeed = GS_KT / 1.94384,
    B747DR_ap_inVNAVdescent = 2, B747DR_ap_vnav_state = 2,
    B747DR_ap_FMA_active_pitch_mode = 6, simDR_autopilot_vs_status = 2,
    simDR_autopilot_flch_status = 0, simDR_autopilot_alt_hold_status = 0,
    B747DR_autopilot_gs_status = 0, simDR_autopilot_gs_status = 0,
    B747DR_ap_approach_mode = 0, simDR_autopilot_approach_status = 0,
    B747DR_ap_autoland = 0, B747DR_ap_active_land = 0, B747DR_alt_capture_window = 1000,
    -- a Mach target (deceleratedDesent wants the FMC's speed transition without one), on speed
    simDR_autopilot_airspeed_is_mach = 1, simDR_autopilot_airspeed_kts = 270, simDR_ind_airspeed_kts_pilot = 270,
    simDR_vvi_fpm_pilot = -GRADIENT * GS_KT / 60, simDR_autopilot_vs_fpm = -GRADIENT * GS_KT / 60,
    B747DR_airspeed_Vmc = 150, B747DR_speedbrake_lever = 0, simDR_allThrottle = 0,
    simDR_radarAlt1 = 21000}
for key, value in pairs(sim) do vnav[key] = value end
-- B747_vnav_approach_path: no approach path here
vnav.B747_vnav_approach_path = function() return nil end
vnav.B747_reset_vnav_energy()

-- on the path from 3 nm before the point, 20 frames a second: the V/S commanded each frame at its distance
local path_vs = -GRADIENT * GS_KT / 60
local dt = 0.05
local worst, worst_d = 0, nil
local d = 3.0
while d > 0.1 do
    vnav.simDR_latitude, vnav.simDR_longitude = P_LAT, P_LON - d * NM_DEG_LON
    vnav.simDR_pressureAlt1 = P_ALT + GRADIENT * d
    vnav.setDescentVSpeed({})
    if d <= 1.0 then
        local off = math.abs(vnav.simDR_autopilot_vs_fpm - path_vs) / math.abs(path_vs)
        if off > worst then worst, worst_d = off, d end
    end
    vnav.simDRTime = vnav.simDRTime + dt
    d = d - GS_KT / 3600 * dt
end
check(worst <= 0.15, string.format(
    "on the path in the last nm before the point the V/S stays within 15 %% of the path's %.0f fpm (%.0f %% off at %.2f nm,"
    .. " %.0f fpm at the end)", path_vs, 100 * worst, worst_d or 0, vnav.simDR_autopilot_vs_fpm))

-- 100 ft above the path in the last nm: the V/S steeper than the path's, as at 1 nm (the path error over the time
-- the 1 nm takes)
vnav.B747_reset_vnav_energy()
vnav.simDRTime = vnav.simDRTime + 10
d = 0.6
for _ = 1, 40 do
    vnav.simDR_latitude, vnav.simDR_longitude = P_LAT, P_LON - d * NM_DEG_LON
    vnav.simDR_pressureAlt1 = P_ALT + GRADIENT * d + 100
    vnav.setDescentVSpeed({})
    vnav.simDRTime = vnav.simDRTime + dt
end
check(vnav.simDR_autopilot_vs_fpm < path_vs - 100, string.format(
    "100 ft above the path at 0.6 nm the V/S is steeper than the path's: %.0f fpm (path %.0f)",
    vnav.simDR_autopilot_vs_fpm, path_vs))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV descent point tests passed: "..checks)
