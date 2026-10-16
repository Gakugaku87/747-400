-- Run from the repository root with Lua 5.1 or LuaJIT.
-- LNAV fly-by turns. The production waypoint sequencing
-- (B747_getCurrentWayPoint_function, B747.70.xt.autopilot.lua), LNAV steering
-- (B747_updateApproachHeading, B747.70.xt.autopilot.monitor.lua) and flight
-- director roll filter (adaptive_roll_filter) fly a lateral model: X-Plane's
-- HDG SEL, which LNAV steers, commands 0.165 x GS / g deg of bank per deg of
-- heading error up to the bank limit, slewed at 5.9 deg/s, and the bank
-- follows the filtered command as a second order with 0.1 s delay (FL310: wn
-- 3.2 rad/s, zeta 0.22; 5,000 ft: wn 4.7, zeta 0.73), all fitted to the kit's
-- 2026-10-11 recordings (final3-L1 HDG tests, line4 DW129 and NETOM). With
-- the sequencing of 2026-10-11 the model turns where the 747 turned (DW129
-- 1.22 nm before the fix, recorded 1.21; NETOM 2.14, recorded 2.14) and
-- overshoots as it did (DW129 1.77 nm, recorded 1.61; NETOM leg 0.73, 0.77;
-- BEDRA 3.0, 3.15; BILTO 17.6, 17.2).
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local HYD = "plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/"
local afds = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")
local controls = dofile(HYD.."B747.19.xt.hydraulics_afds_helpers.lua")

local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end
local ap_source, monitor_source = read(AP.."B747.70.xt.autopilot.lua"), read(AP.."B747.70.xt.autopilot.monitor.lua")
local function slice(source, first_marker, last_marker)
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first, true), last_marker)
    return source:sub(first, last - 1)
end
local chunks = {
    slice(ap_source, "function B747_rescale(", "function getFMSData(name)"),
    slice(ap_source, "function getTriSpaceSolver(ab,ac,cb)", "local beganDescentAny"),
    slice(ap_source, "function getHeading(lat1, lon1, lat2, lon2)", "function movePoint("),
    slice(ap_source, "function movePoint(", "\nend\n").."\nend\n",
    slice(ap_source, "local LNAV_MAX_PREEMPT_XTK_NM", "function B747_getCurrentWayPoint_default(fmsO)"),
    slice(monitor_source, "function getWCAforHeading(theading)", "function B747_monitorAP(fmsO)")}

local G, KT = 9.80665, 0.514444
local function wrap(a) return (a + 180) % 360 - 180 end

local function new_runtime()
    local env = setmetatable({print = function() end, B747_afds_helpers = afds}, {__index = _G})
    for _, chunk in ipairs(chunks) do setfenv(assert(loadstring(chunk)), env)() end
    env.B747DR_CAS_caution_status, env.simDR_override_fms_progress = {}, 1
    env.setVNAVState = function() end
    env.simCMD_autopilot_heading_select = {once = function() end}
    env.simDR_radio_nav_obs_deg = {[0] = 0}
    for _, name in ipairs({"simDR_autopilot_nav_status", "simDR_autopilot_gs_status", "simDR_hsi_ldef_dots_nav1",
            "simDR_hsi_ldef_dots_nav2", "simDR_hsi_nav1_horizontal_signal", "simDR_hsi_nav2_horizontal_signal",
            "simDR_hsi_nav1_vertical_signal", "simDR_hsi_nav2_vertical_signal", "simDR_hsi_vdef_dots_pilot",
            "simDR_nav1_gs_flag", "simDR_nav2_gs_flag", "simDR_radio_nav1_bearing_deg", "simDR_radio_nav2_bearing_deg",
            "B747DR_autopilot_nav_status", "B747DR_ap_approach_mode", "B747DR_ap_ATT", "simDR_variation",
            "B747DR_ap_lnav_xtk_target", "B747DR_ap_lnav_xtk_error", "simDR_onGround", "simDR_wind_speed",
            "B747DR_ND_Wind_Bearing"}) do
        env[name] = 0
    end
    env.simDR_autopilot_heading_status, env.B747DR_ap_lastCommand, env.B747DR_ap_lnav_state = 2, -100, 2
    -- X-Plane's bank angle modes 1-6 and their limits; the 747's AUTO is mode 4
    env.simDR_autopilot_bank_limit = 4
    env.simDR_autopilot_bank_angles = {[0] = 5, 10, 15, 20, 25, 30}
    return env
end

-- One xtlua/fms entry: [2] type (1 airport, 512 fix, 2048 lat/lon), [5]/[6]
-- position, [8] name, [9] altitude, [10] active.
local function entry(name, lat, lon, alt, kind)
    return {0, kind or 512, 0, 0, lat, lon, 0, name, alt or 0, false}
end

-- Fly s = {route, index, start = {lat, lon}, heading, tas_kt, accel_kt_s,
-- tas_max_kt, alt_ft, vs_fpm, alt_max_ft, loop = "cruise"|"low", wind_from_deg,
-- wind_kt, seconds, setup = function(env) before the first frame}.
local LOOPS = {cruise = {3.2, 0.22}, low = {4.7, 0.73}}
local function fly(s)
    local env = new_runtime()
    local route, dt = s.route, 0.05
    local wn, zeta = LOOPS[s.loop][1], LOOPS[s.loop][2]
    local lat, lon, heading, tas = s.start[1], s.start[2], s.heading, s.tas_kt
    local bank, rate, command, filtered = 0, 0, 0, 0
    local history, rates = {}, {}
    local wind_from, wind_kt = s.wind_from_deg or 0, s.wind_kt or 0
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = s.index, s.index, s.index
    if s.setup then s.setup(env) end
    local alt = s.alt_ft
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = alt, alt, s.vs_fpm or 0
    local out = {track = {}, switches = {}, back = false, env = env}
    local t, previous = 0, s.index
    while t < s.seconds do
        local v = tas * KT
        local vx = v * math.sin(math.rad(heading)) - wind_kt * KT * math.sin(math.rad(wind_from))
        local vy = v * math.cos(math.rad(heading)) - wind_kt * KT * math.cos(math.rad(wind_from))
        local gs = math.sqrt(vx * vx + vy * vy)
        local track = math.deg(math.atan2(vx, vy)) % 360
        env.simDRTime = t
        env.simDR_latitude, env.simDR_longitude = lat, lon
        env.simDR_true_heading, env.simDR_AHARS_heading_deg_pilot = heading, heading
        env.simDR_groundspeed, env.simDR_TAS_mps, env.simDR_ground_track_true = gs, v, track
        env.simDR_wind_speed_kts = wind_kt
        -- the ND wind bearing as B747.68.xt.fms makes it (relative to the heading)
        local bearing = 360 - (360 - wind_from + heading)
        env.B747DR_ND_Wind_Bearing = wrap(bearing < 0 and bearing + 180 or bearing - 180)
        for i = 1, #route do route[i][10] = (i == env.B747DR_fmscurrentIndex) end
        env.B747_getCurrentWayPoint_function(route)
        if env.B747DR_fmscurrentIndex ~= previous then
            if env.B747DR_fmscurrentIndex < previous then out.back = true end
            local fix = route[previous]
            out.switches[#out.switches + 1] = {from = previous, to = env.B747DR_fmscurrentIndex,
                nm = env.getDistance(lat, lon, fix[5], fix[6]), lat = lat, lon = lon, t = t}
            previous = env.B747DR_fmscurrentIndex
        end
        env.B747_updateApproachHeading(route)
        -- X-Plane's HDG SEL (variation 0: magnetic is true here)
        local limit = env.simDR_autopilot_bank_angles[env.simDR_autopilot_bank_limit - 1]
        local want = math.max(-limit, math.min(limit, 0.165 * gs / G * wrap(env.simDR_autopilot_heading_deg - heading)))
        command = command + math.max(-5.9 * dt, math.min(5.9 * dt, want - command))
        filtered = controls.adaptive_roll_filter(filtered, command, dt, false)
        history[#history + 1] = filtered
        local u = history[math.max(1, #history - 2)]
        rate = rate + (wn * wn * (u - bank) - 2 * zeta * wn * rate) * dt
        bank = bank + rate * dt
        local turn_rate = math.deg(G * math.tan(math.rad(bank)) / v)
        heading = (heading + turn_rate * dt) % 360
        out.turned = (out.turned or 0) + math.abs(turn_rate) * dt
        lat, lon = env.movePoint(lat, lon, gs * dt / 1852, track)
        if s.accel_kt_s then tas = math.min(s.tas_max_kt, tas + s.accel_kt_s * dt) end
        if s.vs_fpm then
            alt = math.min(s.alt_max_ft, alt + s.vs_fpm / 60 * dt)
            env.simDR_pressureAlt1, env.simDR_radarAlt1 = alt, alt
        end
        t = t + dt
        rates[#rates + 1] = rate
        out.track[#out.track + 1] = {lat = lat, lon = lon, gs = gs, t = t, alt = alt, bank = bank}
    end
    out.roll_rate = 0
    for i = 1, #rates do
        local sum, count = 0, 0
        for j = math.max(1, i - 10), math.min(#rates, i + 10) do sum, count = sum + rates[j], count + 1 end
        out.roll_rate = math.max(out.roll_rate, math.abs(sum / count))
    end
    return out
end

-- The turn at route[k]: its angle (the inbound leg's course at the fix to the
-- outbound leg's), the overshoot (the outside cross-track of the leg k -> k+1
-- between the passages of k and k+1, within 20 nm of k; a passage is the
-- closest point of the track) and the largest distance from the fly-by path
-- (the legs and the arc tangent to both at the bank limit and the ground speed
-- at the passage) within the half legs around k: + outside, - inside.
local function turn_metrics(out, route, k)
    local env = out.env
    local a, f, b = route[k - 1], route[k], route[k + 1]
    local course_in = (env.getHeading(f[5], f[6], a[5], a[6]) + 180) % 360
    local course_out = env.getHeading(f[5], f[6], b[5], b[6])
    local turn = wrap(course_out - course_in)
    local function passage(fix, from)
        local best, nm = nil, 1e9
        for i = from or 1, #out.track do
            local d = env.getDistance(fix[5], fix[6], out.track[i].lat, out.track[i].lon)
            if d < nm then best, nm = i, d end
        end
        return best, nm
    end
    local ik, passed_nm = passage(f)
    local ik1 = passage(b, ik)
    local im = passage(a)
    if im > ik then im = 1 end
    local function flat(lat, lon)
        local d, brg = env.getDistance(f[5], f[6], lat, lon), math.rad(env.getHeading(f[5], f[6], lat, lon))
        return d * math.sin(brg), d * math.cos(brg)
    end
    local ui = {math.sin(math.rad(course_in)), math.cos(math.rad(course_in))}
    local uo = {math.sin(math.rad(course_out)), math.cos(math.rad(course_out))}
    local overshoot = 0
    for i = ik, ik1 do
        local x, y = flat(out.track[i].lat, out.track[i].lon)
        local right = x * uo[2] - y * uo[1]
        local outside = turn > 0 and -right or right
        if math.sqrt(x * x + y * y) <= 20 then overshoot = math.max(overshoot, outside) end
    end
    local gs = out.track[ik].gs
    local radius = gs * gs / (G * math.tan(math.rad(20))) / 1852
    local lead = radius * math.tan(math.rad(math.abs(turn) / 2))
    local p1 = {-ui[1] * lead, -ui[2] * lead}
    local p2 = {uo[1] * lead, uo[2] * lead}
    local side = turn > 0 and 1 or -1
    local centre = {p1[1] + side * ui[2] * radius, p1[2] - side * ui[1] * radius}
    local a1 = math.atan2(p1[1] - centre[1], p1[2] - centre[2])
    local a2 = math.atan2(p2[1] - centre[1], p2[2] - centre[2])
    local function on_arc(angle)
        local function norm(v) return (v + 2 * math.pi) % (2 * math.pi) end
        if side > 0 then return norm(angle - a1) <= norm(a2 - a1) + 1e-9 end
        return norm(a1 - angle) <= norm(a1 - a2) + 1e-9
    end
    local reach = math.max(lead + 1, math.min(20, 0.5 * env.getDistance(a[5], a[6], f[5], f[6]),
        0.5 * env.getDistance(f[5], f[6], b[5], b[6])))
    local deviation = 0
    for i = im, ik1 do
        local x, y = flat(out.track[i].lat, out.track[i].lon)
        if math.sqrt(x * x + y * y) <= reach then
            local best, signed = 1e9, 0
            local function line(px, py, ux, uy, back, forward)
                local rx, ry = x - px, y - py
                local along = rx * ux + ry * uy
                if along < -back or along > forward then return end
                local right = rx * uy - ry * ux
                if math.abs(right) < best then best, signed = math.abs(right), -side * right end
            end
            line(p1[1], p1[2], ui[1], ui[2], 25, 0)
            line(p2[1], p2[2], uo[1], uo[2], 0, 25)
            if on_arc(math.atan2(x - centre[1], y - centre[2])) then
                local r = math.sqrt((x - centre[1]) ^ 2 + (y - centre[2]) ^ 2)
                local d = math.abs(r - radius)
                if d < best then best, signed = d, (r > radius) and d or -d end
            end
            if best < 1e9 and math.abs(signed) > math.abs(deviation) then deviation = signed end
        end
    end
    return turn, overshoot, deviation, passed_nm
end

local probe = new_runtime()
local function along(route, i, nm)
    local a, b = route[i - 1], route[i]
    local course = probe.getHeading(a[5], a[6], b[5], b[6])
    local lat, lon = probe.movePoint(a[5], a[6], nm, course)
    return {lat, lon}, course
end
local function fixes_in_order(out, route, first, last)
    if out.back then return false end
    local seen = {}
    for _, sw in ipairs(out.switches) do
        if sw.to ~= sw.from + 1 then return false end
        seen[sw.from] = true
    end
    for k = first, last do if not seen[k] then return false end end
    return true
end

-- 1. The anticipation itself (afds.lnav_turn_anticipation_nm): the arc of a
-- fly-by turn at the bank limit plus half the roll-in at 3 deg/s, in wind the
-- point where the turn at constant bank, drifting with the wind, ends on the
-- outbound leg.
local anticipation = afds.lnav_turn_anticipation_nm
check(type(anticipation) == "function", "afds.lnav_turn_anticipation_nm exists")
if type(anticipation) == "function" then
    local function near(value, expected, tolerance, message)
        check(value ~= nil and math.abs(value - expected) <= tolerance,
            string.format("%s: %s (expected %.2f)", message, tostring(value), expected))
    end
    local radius = (478 * KT) ^ 2 / (G * math.tan(math.rad(20))) / 1852
    local roll_in = 478 / 3600 * (20 / 3) / 2
    near(anticipation(478, 0, 0, 20, 270, 0, 3, 478), radius + roll_in, 0.01, "90 deg right at 478 kt, no wind")
    near(anticipation(478, 0, 0, 20, 0, 270, 3, 478), radius + roll_in, 0.01, "90 deg left at 478 kt, no wind")
    near(anticipation(478, 0, 0, 20, 10, 40, 3, 478), radius * math.tan(math.rad(15)) + roll_in, 0.01, "30 deg")
    near(anticipation(250, 0, 0, 25, 100, 220, 3, 250),
        (250 * KT) ^ 2 / (G * math.tan(math.rad(25))) / 1852 * math.tan(math.rad(60)) + 250 / 3600 * (25 / 3) / 2,
        0.01, "120 deg at 250 kt and 25 deg of bank")
    check(anticipation(478, 0, 0, 20, 90, 90.5, 3, 478) == 0, "no turn: no anticipation")
    check(anticipation(478, 0, 0, 20, 0, 160, 3, 478) == 0,
        "160 deg: no fly-by, the next leg once abeam the fix (0), "..tostring(anticipation(478, 0, 0, 20, 0, 160, 3, 478)))
    check(anticipation(0, 0, 0, 20, 0, 90, 3, 0) == 0 and anticipation(478, 0, 0, 0, 0, 90, 3, 478) == 0,
        "no speed or no bank: none")
    -- BEDRA at FL310 (wind from 265 at 96 kt): into the wind, then across it
    -- the turn is shorter over the ground; with it behind (BILTO, 137 deg)
    -- far longer
    local we, wn = 96 * math.sin(math.rad(85)), 96 * math.cos(math.rad(85))
    local headwind = anticipation(478, we, wn, 20, 268, 0, 3, 382)
    check(headwind and headwind < radius and headwind > 6, "into a headwind, across the wind: shorter, "..tostring(headwind))
    local tailwind = anticipation(482, we, wn, 20, 0, 137, 3, 478)
    check(tailwind and tailwind > radius * math.tan(math.rad(68.5)), "turning downwind: longer, "..tostring(tailwind))
    -- a wind estimate that cannot be (XTLua's 0 on a first read) is left out
    check(anticipation(478, 900, 300, 20, 270, 0, 3, 478) == anticipation(478, 0, 0, 20, 270, 0, 3, 478),
        "an implausible wind is ignored")
end

-- 2. Turns flown on the model.
local E = entry
local function eidw()
    return {E("EIDW", 53.4213, -6.2703, 242, 1), E("RW28R", 53.435203, -6.244964), E("DE28R", 53.437394, -6.284811),
        E("DW128", 53.465722, -6.352278), E("DW129", 53.526722, -6.348806), E("DW124", 53.522306, -6.073889),
        E("ATGOW", 53.488944, -5.842361), E("ENDEQ", 53.445661, -5.5), E("RULAV", 53.437319, -5.167014),
        E("EHAM", 52.3175, 4.7716, -11, 1)}
end
local function eham()
    return {E("EIDW", 53.4213, -6.2703, 242, 1), E("ETPOS", 52.585122, 3.414178), E("SUGOL", 52.525511, 3.96735),
        E("NETOM", 52.422444, 4.387917), E("NIRSI", 52.583878, 4.513372), E("AM607", 52.583889, 4.646889),
        E("AM608", 52.539417, 4.728139), E("AM621", 52.462694, 4.721111), E("AM622", 52.426722, 4.717806),
        E("RW18R", 52.360258, 4.711725), E("(500)", 52.3457, 4.7102, 500, 2048), E("EHAM", 52.3175, 4.7716, -11, 1)}
end
local function tst744l()
    return {E("EINN", 52.7020, -8.9248, 46, 1), E("RW23", 52.7100, -8.9000), E("EMPER", 49.0, -9.0), E("BEDRA", 49.0, -15.0),
        E("ETARI", 55.5, -15.0), E("BILTO", 56.5, -15.0), E("ELPOM", 52.560306, -9.224111), E("ASGON", 52.598444, -9.143917),
        E("RW06", 52.6933, -8.9433), E("(VECT)", 57.0, -12.0, 2000, 2048), E("EINN", 52.7020, -8.9248, 46, 1)}
end

-- EIDW 28R ENDE3J: DW129, +90 deg at 243-272 kt (line4: 1.61 nm outside)
local route = eidw()
local start, course = along(route, 5, 0.5)
local out = fly({route = route, index = 5, start = start, heading = course, tas_kt = 243, accel_kt_s = 0.45,
    tas_max_kt = 272, alt_ft = 4800, loop = "low", seconds = 240})
local turn, overshoot, deviation = turn_metrics(out, route, 5)
check(overshoot <= 0.4, string.format("DW129 %+.0f deg: overshoot %.2f nm (at most 0.4)", turn, overshoot))
check(math.abs(deviation) <= 0.3, string.format("DW129: %.2f nm from the fly-by path (at most 0.3)", deviation))
check(fixes_in_order(out, route, 5, 6), "DW129 and DW124 sequenced in order")
check(out.roll_rate <= 4.5, string.format("DW129: roll rate %.2f deg/s", out.roll_rate))

-- EHAM 18R via SUG1D: NETOM -87, NIRSI +65, AM607 +42, AM608 +51 at 266 kt
route = eham()
start, course = along(route, 4, 13)
out = fly({route = route, index = 4, start = start, heading = course, tas_kt = 266, alt_ft = 8000, loop = "low",
    seconds = 300})
for k = 4, 7 do
    turn, overshoot, deviation = turn_metrics(out, route, k)
    check(math.abs(deviation) <= 0.3, string.format("%s %+.0f deg: %.2f nm from the fly-by path (at most 0.3)",
        route[k][8], turn, deviation))
end
check(fixes_in_order(out, route, 4, 7), "NETOM to AM608 sequenced in order")

-- TST744L at FL310 and FL350, wind from 265 deg at 96 kt: BEDRA +92 deg
-- (3.15 nm outside), BILTO +137 deg downwind (master-L1: 17.2 nm outside),
-- and ELPOM -90 deg at 3,000 ft
route = tst744l()
start, course = along(route, 4, 206)
out = fly({route = route, index = 4, start = start, heading = course, tas_kt = 478, alt_ft = 31000, loop = "cruise",
    wind_from_deg = 265, wind_kt = 96, seconds = 420})
turn, overshoot, deviation = turn_metrics(out, route, 4)
check(overshoot <= 0.4, string.format("BEDRA %+.0f deg in wind: overshoot %.2f nm (at most 0.4)", turn, overshoot))
check(out.roll_rate <= 4.5, string.format("BEDRA: roll rate %.2f deg/s", out.roll_rate))
-- LNAV's path (item i-1b): the arc for the highest ground speed the wind gives across the turn (486 kt,
-- R 9.4 nm, its middle 3.9 nm from BEDRA); with the TAS plus the wind's whole speed it cut 5.9 nm inside
local bedra_nm = 1e9
for _, p in ipairs(out.track) do bedra_nm = math.min(bedra_nm, probe.getDistance(49.0, -15.0, p.lat, p.lon)) end
check(bedra_nm <= 4.5, string.format("BEDRA in wind passed %.1f nm from it (at most 4.5)", bedra_nm))
route = tst744l()
start, course = along(route, 6, 30)
out = fly({route = route, index = 6, start = start, heading = course, tas_kt = 482, alt_ft = 35000, loop = "cruise",
    wind_from_deg = 265, wind_kt = 96, seconds = 600})
turn, overshoot = turn_metrics(out, route, 6)
check(overshoot <= 1.0, string.format("BILTO %+.0f deg downwind: overshoot %.2f nm (at most 1)", turn, overshoot))
route = tst744l()
start, course = along(route, 7, probe.getDistance(56.5, -15.0, 52.560306, -9.224111) - 15)
out = fly({route = route, index = 7, start = start, heading = course, tas_kt = 245, alt_ft = 3000, loop = "low",
    seconds = 300})
turn, overshoot, deviation = turn_metrics(out, route, 7)
check(overshoot <= 0.4, string.format("ELPOM %+.0f deg: overshoot %.2f nm (at most 0.4)", turn, overshoot))

-- turns of 15 to 120 deg at 250 kt (5,000 ft) and 478 kt (FL310), 40 nm legs
for _, speed in ipairs({{250, "low", 5000}, {478, "cruise", 31000}}) do
    for _, angle in ipairs({15, 30, 45, 60, 90, 120}) do
        local lat0, lon0 = 50, -10
        local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 40, 0)
        local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, angle)
        local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, angle)
        route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
            E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("DEST", after_lat + 5, after_lon, 0, 1)}
        start, course = along(route, 3, 5)
        out = fly({route = route, index = 3, start = start, heading = course, tas_kt = speed[1], alt_ft = speed[3],
            loop = speed[2], seconds = 35 / speed[1] * 3600 + 540})
        turn, overshoot, deviation = turn_metrics(out, route, 3)
        local name = string.format("%+.0f deg at %d kt", turn, speed[1])
        check(overshoot <= 0.3, string.format("%s: overshoot %.2f nm (at most 0.3)", name, overshoot))
        check(math.abs(deviation) <= 0.3, string.format("%s: %.2f nm from the fly-by path (at most 0.3)", name, deviation))
        check(out.roll_rate <= 4.5, string.format("%s: roll rate %.2f deg/s", name, out.roll_rate))
    end
end

-- Turning back by more than 150 deg (no fly-by: the next leg once abeam the
-- fix) at 200 kt and 3,000 ft: the turn is flown once, toward the next fix,
-- not as an orbit back over the passed fix (with no lead at all the fix stayed
-- active and LNAV flew back to it: 572 deg of turning on a turn-back SID).
for _, angle in ipairs({170, -165}) do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 20, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 10, angle % 360)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 30, angle % 360)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("DEST", after_lat - 5, after_lon, 0, 1)}
    start, course = along(route, 3, 5)
    out = fly({route = route, index = 3, start = start, heading = course, tas_kt = 200, alt_ft = 3000, loop = "low",
        seconds = 720})
    local passed_next, at_next = 1e9, nil
    for _, p in ipairs(out.track) do
        local d = probe.getDistance(next_lat, next_lon, p.lat, p.lon)
        if d < passed_next then passed_next, at_next = d, p.t end
    end
    local name = string.format("%+d deg at 200 kt", angle)
    check(out.turned <= 300, string.format("%s: %.0f deg of turning in all (one turn, no orbit)", name, out.turned))
    check(fixes_in_order(out, route, 3, 4), name..": FIX and NEXT sequenced in order")
    check(passed_next <= 1.0 and at_next <= 600, string.format("%s: NEXT passed at %.2f nm after %.0f s", name,
        passed_next, at_next or -1))
end

-- 3. Where the turn is not anticipated: one frame on a 90 deg turn at 478 kt,
-- dist nm (8) before the fix (the lead is 9.6 nm; the old preemption took 5.6
-- nm), with o = {kind, name (of the next entry), xtk (nm right of the leg),
-- target (the LNAV offset), from_airport, ra, vs, start_name, start_kind,
-- dist, mode (bank angle mode), garbage (what the bank angles give outside
-- 0-5), next_course (90), from_fix = {bearing, nm} (placed from the fix instead)}.
local function one_frame(o)
    o = o or {}
    local env = new_runtime()
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = env.movePoint(lat0, lon0, 40, 0)
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 40, o.next_course or 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E(o.start_name or "START", lat0, lon0, 0, o.start_kind),
        E("FIX", fix_lat, fix_lon), E(o.name or "NEXT", next_lat, next_lon, 0, o.kind), E("DEST", next_lat + 5, next_lon, 0, 1)}
    local index = 3
    if o.from_airport then table.remove(route, 2) index = 2 end
    local lat, lon = env.movePoint(lat0, lon0, 40 - (o.dist or 8), 0)
    if o.xtk then lat, lon = env.movePoint(lat, lon, o.xtk, 90) end
    if o.from_fix then lat, lon = env.movePoint(fix_lat, fix_lon, o.from_fix[2], o.from_fix[1]) end
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = index, index, index
    env.B747DR_ap_lnav_xtk_target = o.target or 0
    env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading = lat, lon, 0
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 31000, o.ra or 31000, o.vs or 0
    env.simDR_groundspeed, env.simDR_TAS_mps, env.simDR_ground_track_true = 478 * KT, 478 * KT, 0
    if o.mode then env.simDR_autopilot_bank_limit = o.mode end
    if o.garbage then
        setmetatable(env.simDR_autopilot_bank_angles, {__index = function() return o.garbage end})
    end
    route[index][10] = true
    env.B747_getCurrentWayPoint_function(route)
    return env.B747DR_fmscurrentIndex - index
end
-- LNAV flies this turn by its path (item i-1b): the arc of R 9.16 nm (478 kt, 20 deg), sequenced at its
-- bisector (its middle is 3.79 nm from the fix on 135), as the FMC does, not at the anticipation's lead
check(one_frame() == 0, "8 nm before a 90 deg fly-by at 478 kt, on its path: still the fix")
check(one_frame({from_fix = {140, 3.79}}) == 0, "on the arc, before its bisector: still the fix")
check(one_frame({from_fix = {130, 3.79}}) == 1, "on the arc, past its bisector: the next leg")
check(one_frame({kind = 2048}) == 0, "the next entry a lat/lon point: not anticipated")
check(one_frame({name = "VECTORS"}) == 0, "the next entry VECTORS: not anticipated")
check(one_frame({xtk = 2.5}) == 0, "2.5 nm off the leg: not anticipated")
check(one_frame({target = -100}) == 0, "a direct-to: not anticipated")
check(one_frame({from_airport = true}) == 0, "the leg from the origin airport: not anticipated")
-- no turn starts below 400 ft above the ground (a SID's first fix close to
-- the runway was skipped at 20 ft and the turn began at LNAV's 50 ft)
check(one_frame({ra = 300, vs = 2000}) == 0, "300 ft above the ground: not anticipated")
check(one_frame({ra = 500, vs = 2000, from_fix = {130, 3.79}}) == 1, "500 ft above the ground, past the bisector: the next leg")
-- a leg from VECTORS (or a discontinuity, a hold) is flown direct to its fix,
-- so its turn is anticipated as after "(650)" below (60 deg here: 5.7 nm)
check(one_frame({start_name = "VECTORS", next_course = 60, dist = 5}) == 1,
    "the leg from VECTORS, 5 nm before a 60 deg turn: anticipated")
check(one_frame({start_name = "(VECT)", start_kind = 2048, next_course = 60, dist = 5}) == 1,
    "the leg from (VECT), 5 nm before a 60 deg turn: anticipated")
check(one_frame({start_name = "VECTORS", next_course = 60, dist = 8}) == 0,
    "the leg from VECTORS, 8 nm before a 60 deg turn: not yet")
-- a fix's name that only begins like it is no VECTORS: its leg keeps the
-- 2 nm cross-track limit
check(one_frame({start_name = "VECTA", xtk = 2.5}) == 0, "the leg from a fix VECTA, 2.5 nm off it: not anticipated")
-- On a leg LNAV flies by its path the rest of the sequencing's bookkeeping still runs: LNAV's heading mode
-- follows the fix flown to once LNAV is engaged (0 when it engages after take-off: the steering wrote no
-- heading until the next sequencing), and UNABLE RNP (CAS 66) within 40 nm of the destination, 1 nm off a leg.
local function frame_on_path(o)
    local env = new_runtime()
    local lat0, lon0 = 54.0, -10.0
    local fix_lat, fix_lon = env.movePoint(lat0, lon0, 30, 0)
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 20, 90)
    local after_lat, after_lon = env.movePoint(next_lat, next_lon, 20, 90)
    route = {E("ORIG", 53.0, -10.0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("DEST", next_lat, next_lon + 0.2, 0, 1)}
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = 3, 3, o.mode or 3
    local lat, lon = env.movePoint(lat0, lon0, 20, 0)
    lat, lon = env.movePoint(lat, lon, o.xtk or 0, 90)
    env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading, env.simDR_ground_track_true = lat, lon, 0, 0
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 5000, 5000, 0
    env.simDR_groundspeed, env.simDR_TAS_mps = 250 * KT, 250 * KT
    route[3][10] = true
    env.B747_getCurrentWayPoint_function(route)
    return env
end
local env_mode = frame_on_path({mode = 0})
check(env_mode.B747DR_fmscurrentIndex == 3 and env_mode.B747DR_ap_lnavHeading_mode == 3,
    "LNAV engaged with its heading mode 0, on the path: the mode follows FIX, got "
    ..tostring(env_mode.B747DR_ap_lnavHeading_mode))
local env_rnp = frame_on_path({xtk = 1.5})
check(env_rnp.B747DR_fmscurrentIndex == 3 and env_rnp.B747DR_CAS_caution_status[66] == 1,
    "1.5 nm off the leg 27 nm from the destination, on the path: UNABLE RNP, got "
    ..tostring(env_rnp.B747DR_CAS_caution_status[66]))
check(frame_on_path({xtk = 0.2}).B747DR_CAS_caution_status[66] == 0, "0.2 nm off it: no UNABLE RNP")
-- an altitude leg's end at the fix before (a CA leg's "(5000)", typed as a fix here) is no fix listed twice:
-- not passed with the fix before it, below its altitude
do
    local env = new_runtime()
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = env.movePoint(lat0, lon0, 30, 0)
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 30, 60)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("(5000)", fix_lat, fix_lon, 5000, 512), E("NEXT", next_lat, next_lon), E("DEST", next_lat + 5, next_lon, 0, 1)}
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = 4, 4, 4
    env.simDR_latitude, env.simDR_longitude = env.movePoint(fix_lat, fix_lon, 0.5, 0)
    env.simDR_true_heading, env.simDR_ground_track_true = 0, 0
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 3000, 3000, 2000
    env.simDR_groundspeed, env.simDR_TAS_mps = 250 * KT, 250 * KT
    route[4][10] = true
    env.B747_getCurrentWayPoint_function(route)
    check(env.B747DR_fmscurrentIndex == 4, "(5000) at FIX, at 3,000 ft: not passed, got "..env.B747DR_fmscurrentIndex)
end
-- the steering with a ground speed that is no number (NaN): no path, the heading LNAV writes a number
do
    local env = new_runtime()
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = env.movePoint(lat0, lon0, 40, 0)
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 40, 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("DEST", next_lat + 5, next_lon, 0, 1)}
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = 3, 3, 3
    env.simDR_latitude, env.simDR_longitude = env.movePoint(lat0, lon0, 20, 0)
    env.simDR_true_heading, env.simDR_ground_track_true, env.simDR_wind_speed_kts, env.simDRTime = 0, 0, 0, 10
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 31000, 31000, 0
    env.simDR_groundspeed, env.simDR_TAS_mps = 0 / 0, 478 * KT
    route[3][10] = true
    env.B747_updateApproachHeading(route)
    local heading = env.simDR_autopilot_heading_deg
    check(type(heading) == "number" and heading == heading, "a ground speed that is no number: the heading "
        ..tostring(heading))
end
-- with an offset the new lead is not taken from the route's turn point
check(one_frame({target = 2, xtk = 2}) == 0, "on a 2 nm offset: not anticipated")
-- a bank angle mode outside 1-6 (XTLua's 0 on a first read) is the 20 deg of
-- AUTO, whatever the array gives there: 12 nm before the fix is not yet the
-- 9.6 nm lead
check(one_frame({dist = 12}) == 0, "12 nm before the fix: not yet")
check(one_frame({dist = 12, mode = 0, garbage = 3}) == 0, "bank angle mode 0: 20 deg, not yet at 12 nm")
check(one_frame({dist = 12, mode = 7, garbage = 3}) == 0, "bank angle mode 7: 20 deg, not yet at 12 nm")

-- After an altitude-terminated leg ("(650)", its altitude reached) the leg to
-- the active fix is a direct-to from where that altitude was reached, so the
-- turn at the fix is from the aircraft's course to it (EIDW DW128: 003 deg,
-- where DE28R-DW128 is 305 deg and made a 57 deg turn of a 3 deg one).
do
    local env = new_runtime()
    local fix_lat, fix_lon = 53.465722, -6.352278
    local lat, lon = env.movePoint(fix_lat, fix_lon, 0.8, 183)               -- 0.8 nm before it on 003
    local dep_lat, dep_lon = env.movePoint(fix_lat, fix_lon, 6, 125)        -- DE28R-like, 6 nm out on 305
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 4, 6)
    route = {E("EIDW", 53.4213, -6.2703, 242, 1), E("RW28R", 53.435203, -6.244964), E("DEP", dep_lat, dep_lon),
        E("(650)", 53.44, -6.30, 650, 2048), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("EHAM", 52.3175, 4.7716, -11, 1)}
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = 5, 5, 5
    env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading = lat, lon, 3
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 3000, 2800, 2000
    env.simDR_groundspeed, env.simDR_TAS_mps, env.simDR_ground_track_true = 180 * KT, 180 * KT, 3
    route[5][10] = true
    env.B747_getCurrentWayPoint_function(route)
    check(env.B747DR_fmscurrentIndex == 5, "after (650), 0.8 nm before a 3 deg turn: still the fix, index "
        ..env.B747DR_fmscurrentIndex)
end
-- Such a direct-to's turn is anticipated only once the aircraft tracks within
-- 30 deg of the fix (not while it still turns to it after the altitude, as on
-- a turn-back SID), after an altitude leg's end (a departure or a missed
-- approach) only up to 90 deg (beyond, the fix is passed within 0.3 nm), and a
-- fix passed within 0.5 nm abeam is passed.
local function direct_to(o)
    local env = new_runtime()
    local fix_lat, fix_lon = 53.465722, -6.352278
    local lat, lon = env.movePoint(fix_lat, fix_lon, o.dist, (o.from + 180) % 360)
    local dep_lat, dep_lon = env.movePoint(fix_lat, fix_lon, 6, 125)
    local next_lat, next_lon = env.movePoint(fix_lat, fix_lon, 10, o.next_course)
    route = {E("EIDW", 53.4213, -6.2703, 242, 1), E("RW28R", 53.435203, -6.244964), E("DEP", dep_lat, dep_lon),
        E("(650)", 53.44, -6.30, 650, 2048), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("EHAM", 52.3175, 4.7716, -11, 1)}
    env.B747DR_fmscurrentIndex, env.B747DR_fms_setCurrent, env.B747DR_ap_lnavHeading_mode = 5, 5, 5
    env.simDR_latitude, env.simDR_longitude, env.simDR_true_heading = lat, lon, o.track
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 1500, 1300, 2000
    env.simDR_groundspeed, env.simDR_TAS_mps, env.simDR_ground_track_true = 200 * KT, 200 * KT, o.track
    route[5][10] = true
    env.B747_getCurrentWayPoint_function(route)
    return env.B747DR_fmscurrentIndex - 5
end
-- 60 deg at the fix, 200 kt: lead 1.1 nm; the aircraft 1.0 nm short of it on its 003 course
check(direct_to({dist = 1.0, from = 3, track = 3, next_course = 63}) == 1,
    "after (650), 1.0 nm before a 60 deg turn, tracking to the fix: anticipated")
check(direct_to({dist = 1.0, from = 3, track = 183, next_course = 63}) == 0,
    "after (650), 1.0 nm from a 60 deg turn, tracking away from the fix: not anticipated")
check(direct_to({dist = 1.0, from = 3, track = 63, next_course = 63}) == 0,
    "after (650), 1.0 nm from a 60 deg turn, tracking 60 deg off the fix: not anticipated")
-- 120 deg at the fix: no fly-by from a direct-to; passed at 0.3 nm
check(direct_to({dist = 1.0, from = 3, track = 3, next_course = 123}) == 0,
    "after (650), 1.0 nm before a 120 deg turn: not anticipated")
check(direct_to({dist = 0.25, from = 3, track = 3, next_course = 123}) == 1,
    "after (650), 0.25 nm before a 120 deg turn: passed")
-- passing 0.4 nm abeam the fix (it lies 90 deg off the track): passed
check(direct_to({dist = 0.4, from = 93, track = 3, next_course = 123}) == 1,
    "after (650), 0.4 nm abeam the fix: passed")
check(direct_to({dist = 0.8, from = 93, track = 3, next_course = 123}) == 0,
    "after (650), 0.8 nm abeam the fix: not passed")

-- A turn-back SID flown: runway 27 heading to 1,000 ft, direct to ABC (2 nm
-- north and 2 nm east of the airport), then DEF on 300 deg at 175-220 kt. The
-- turn at ABC was anticipated 6 nm before it while the aircraft still turned
-- to it, and ABC was missed by 3.4 nm.
do
    local lat0, lon0 = 52.0, 0.0
    local abc_lat, abc_lon = probe.movePoint(lat0, lon0, math.sqrt(8), 45)
    local def_lat, def_lon = probe.movePoint(abc_lat, abc_lon, 10, 300)
    local ghi_lat, ghi_lon = probe.movePoint(def_lat, def_lon, 20, 300)
    local alt_lat, alt_lon = probe.movePoint(lat0, lon0, 0.6, 270)
    route = {E("ORIG", lat0, lon0, 0, 1), E("RW27", lat0, lon0 + 0.02), E("(1000)", alt_lat, alt_lon, 1000, 2048),
        E("ABC", abc_lat, abc_lon), E("DEF", def_lat, def_lon), E("GHI", ghi_lat, ghi_lon), E("DEST", 50, 0, 0, 1)}
    out = fly({route = route, index = 3, start = {lat0, lon0}, heading = 270, tas_kt = 175, accel_kt_s = 0.3,
        tas_max_kt = 220, alt_ft = 600, vs_fpm = 2000, alt_max_ft = 6000, loop = "low", seconds = 600})
    local abc_nm, def_nm = 1e9, 1e9
    for _, p in ipairs(out.track) do
        abc_nm = math.min(abc_nm, probe.getDistance(abc_lat, abc_lon, p.lat, p.lon))
        def_nm = math.min(def_nm, probe.getDistance(def_lat, def_lon, p.lat, p.lon))
    end
    check(abc_nm <= 0.5, string.format("turn-back SID: ABC passed at %.2f nm (at most 0.5)", abc_nm))
    -- two reversals (205 deg to ABC, 195 deg to DEF) and 25 deg at DEF; an
    -- orbit adds 360
    check(def_nm <= 0.5 and out.turned <= 480, string.format("turn-back SID: DEF at %.2f nm, %.0f deg of turning",
        def_nm, out.turned))
    check(fixes_in_order(out, route, 4, 5), "turn-back SID: ABC and DEF sequenced in order")
end

-- Direct from VECTORS to an IF and onto a final 80, 110 and 130 deg off at
-- 180 kt: the turn onto final is anticipated as a fly-by (with none LNAV went
-- 1.5 nm through the final, with the departures' 90 deg limit 1.4-1.9 nm).
for _, side in ipairs({80, 110, 130}) do
    local if_lat, if_lon = 52.5, 4.7
    local faf_lat, faf_lon = probe.movePoint(if_lat, if_lon, 4, 180)
    local rw_lat, rw_lon = probe.movePoint(faf_lat, faf_lon, 5, 180)
    local vec_lat, vec_lon = probe.movePoint(if_lat, if_lon, 25, side)
    route = {E("ORIG", 53.4, -6.3, 0, 1), E("VECTORS", vec_lat, vec_lon), E("IF", if_lat, if_lon), E("FAF", faf_lat, faf_lon),
        E("RW18", rw_lat, rw_lon), E("DEST", rw_lat - 0.02, rw_lon, 0, 1)}
    start = {probe.movePoint(if_lat, if_lon, 12, side)}
    out = fly({route = route, index = 3, start = start, heading = (side + 180) % 360, tas_kt = 180, alt_ft = 3000,
        loop = "low", seconds = 400})
    turn, overshoot = turn_metrics(out, route, 3)
    check(overshoot <= 0.4, string.format("VECTORS - IF %+.0f deg onto the final: overshoot %.2f nm (at most 0.4)", turn,
        overshoot))
end

-- 4. LNAV's path guidance (item i-1b): LNAV steers along the lateral path, the legs and the fly-by arcs
-- between them (afds.lnav_path_at), at a point a look-ahead along it, never nearer than the cross-track (an
-- intercept of at most 45 deg). Before, it aimed 5 nm along the leg, or at the fix within 10 nm of it: 1 nm
-- off a leg it took 162 s to come within 0.1 nm of it, 10 nm off 384 s at up to 59 deg, and 90 s after DW129
-- it was still 0.24 nm off the leg to DW124.
local function xtk_from(out, a, b, t)
    for _, p in ipairs(out.track) do
        if p.t >= t then
            return afds.signed_cross_track_nm(a[5], a[6], b[5], b[6], p.lat, p.lon, probe.getDistance, probe.getHeading)
        end
    end
end
route = eidw()
start, course = along(route, 5, 0.5)
out = fly({route = route, index = 5, start = start, heading = course, tas_kt = 243, accel_kt_s = 0.45,
    tas_max_kt = 272, alt_ft = 4800, loop = "low", seconds = 240})
for _, t in ipairs({90, 120}) do
    local x = xtk_from(out, route[5], route[6], t)
    check(x ~= nil and math.abs(x) <= 0.1, string.format("%d s after DW129: %.2f nm off the leg to DW124 (at most 0.1)",
        t, x or 99))
end
-- 1, 3 and 10 nm left of a 60 nm leg on 090, flying 090 at 250 kt: back within 0.1 nm in 60, 120 and 300 s, at
-- most 45 deg to the leg, and not 0.2 nm through it
for _, o in ipairs({{1, 60}, {3, 120}, {10, 300}}) do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 60, 90)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("DEST", next_lat + 5, next_lon, 0, 1)}
    local slat, slon = probe.movePoint(lat0, lon0, 5, 90)
    slat, slon = probe.movePoint(slat, slon, o[1], 0)
    out = fly({route = route, index = 3, start = {slat, slon}, heading = 90, tas_kt = 250, alt_ft = 5000, loop = "low",
        seconds = 600})
    local within, intercept, through, previous = nil, 0, 0, nil
    for _, p in ipairs(out.track) do
        local x = afds.signed_cross_track_nm(lat0, lon0, fix_lat, fix_lon, p.lat, p.lon, probe.getDistance,
            probe.getHeading)
        if previous then
            intercept = math.max(intercept, math.abs(wrap(probe.getHeading(previous.lat, previous.lon, p.lat, p.lon) - 90)))
        end
        previous = p
        if not within and math.abs(x) <= 0.1 then within = p.t end
        through = math.max(through, x)
    end
    local name = string.format("%d nm left of the leg", o[1])
    check(within ~= nil and within <= o[2], string.format("%s: within 0.1 nm after %s s (at most %d)", name,
        tostring(within), o[2]))
    check(intercept <= 46, string.format("%s: up to %.0f deg to the leg (at most 45)", name, intercept))
    check(through <= 0.2, string.format("%s: %.2f nm through the leg (at most 0.2)", name, through))
end

-- 5. A turn LNAV flies by its path is sequenced at its bisector (item i-1b), where the FMC sequences it: the
-- path's arc, whose radius allows for the wind, starts earlier than the anticipation's lead in a wind not
-- behind the turn, and from the lead the 747 was already more than 2 nm into the arc: the fix was never
-- sequenced and LNAV flew on past the next (BILTO's 137 deg at FL350 in a wind from 355 at 96 kt, from 58 nm
-- before it, passed ELPOM without turning).
local function sequenced_at_bisector(out, route, k)
    for _, sw in ipairs(out.switches) do
        if sw.from == k then
            local f, a, b = route[k], route[k - 1], route[k + 1]
            local d = probe.getDistance(f[5], f[6], sw.lat, sw.lon)
            local brg = math.rad(probe.getHeading(f[5], f[6], sw.lat, sw.lon))
            local cin = (probe.getHeading(f[5], f[6], a[5], a[6]) + 180) % 360
            local cout = probe.getHeading(f[5], f[6], b[5], b[6])
            return sw.to == k + 1 and afds.past_turn_bisector(d * math.sin(brg), d * math.cos(brg), cin, cout) == true
                and afds.past_turn_bisector((d - 0.3) * math.sin(brg), (d - 0.3) * math.cos(brg), cin, cout) ~= nil, sw
        end
    end
    return false
end
route = tst744l()
out = fly({route = route, index = 6, start = {probe.movePoint(56.5, -15.0, 58, 180)}, heading = 0, tas_kt = 482,
    alt_ft = 35000, loop = "cruise", wind_from_deg = 355, wind_kt = 96, seconds = 1500})
local at_bisector, sw = sequenced_at_bisector(out, route, 6)
check(at_bisector, string.format("BILTO in a 355/96 wind from 58 nm: sequenced at its bisector, %s",
    sw and string.format("%d -> %d %.1f nm from it", sw.from, sw.to, sw.nm) or "never"))
turn, overshoot = turn_metrics(out, route, 6)
check(overshoot <= 1.0, string.format("BILTO in a 355/96 wind: overshoot %.2f nm (at most 1)", overshoot))
-- 130 deg at 480 kt in a 90 kt wind across the turn, from 50 nm before the fix
do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 60, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 60, 130)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 60, 130)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("DEST", after_lat + 5, after_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(fix_lat, fix_lon, 50, 180)}, heading = 0, tas_kt = 480,
        alt_ft = 35000, loop = "cruise", wind_from_deg = 40, wind_kt = 90, seconds = 900})
    at_bisector, sw = sequenced_at_bisector(out, route, 3)
    check(at_bisector, string.format("130 deg at 480 kt in a 040/90 wind: sequenced at its bisector, %s",
        sw and string.format("%.1f nm from the fix", sw.nm) or "never"))
    check(fixes_in_order(out, route, 3, 4), "130 deg at 480 kt in a 040/90 wind: FIX and NEXT in order")
end

-- 6. A fix listed twice in a row (a leg of no length, whose course is none): one turn, the fixes in order. LNAV's
-- path took the zero-length leg's course as 000 or 180 and orbited (966 deg of turning at 250 kt, the second
-- entry never sequenced).
for _, speed in ipairs({{250, "low", 5000}, {480, "cruise", 33000}}) do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 60, 90)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 50, 150)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 50, 150)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon), E("FIX2", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("DEST", after_lat + 5, after_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(lat0, lon0, 30, 90)}, heading = 90, tas_kt = speed[1],
        alt_ft = speed[3], loop = speed[2], seconds = 70 / speed[1] * 3600})
    local name = string.format("FIX twice at %d kt", speed[1])
    check(out.turned <= 120, string.format("%s: %.0f deg of turning in all (one 60 deg turn)", name, out.turned))
    check(fixes_in_order(out, route, 3, 4), name..": FIX and FIX2 sequenced in order")
end

-- 7. No turn starts below 400 ft above the ground (as the anticipation): a SID's first fix 1.5 nm past the
-- lift-off with a 90 deg turn, climbing at 1,800 fpm at 165 kt. LNAV's path started its arc at once, banking
-- at 118 ft.
do
    local rw = {52.0, 0.0}
    local f1 = {probe.movePoint(rw[1], rw[2], 2.5, 270)}
    local f2 = {probe.movePoint(f1[1], f1[2], 20, 0)}
    local f3 = {probe.movePoint(f2[1], f2[2], 20, 0)}
    route = {E("ORIG", rw[1], rw[2] + 0.01, 0, 1), E("RW27", rw[1], rw[2]), E("FIX1", f1[1], f1[2]), E("FIX2", f2[1], f2[2]),
        E("FIX3", f3[1], f3[2]), E("DEST", 50, 0, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(rw[1], rw[2], 1.0, 270)}, heading = 270, tas_kt = 165,
        alt_ft = 30, vs_fpm = 1800, alt_max_ft = 6000, loop = "low", seconds = 200})
    local first
    for _, p in ipairs(out.track) do
        if first == nil and math.abs(p.bank) > 3 then first = p end
    end
    check(first ~= nil and first.alt >= 400, string.format("FIX1 1.5 nm past the lift-off: banking from %s ft (at least 400)",
        first and string.format("%.0f", first.alt) or "-"))
end

-- 8. The 747's own DIRECT TO (B747DR_ap_lnav_xtk_target -100, made 0 within 10 nm of the fix by the steering):
-- flown direct to the fix until it is passed. LNAV's path took the leg back once the target was 0 and passed
-- the fix 4 to 7.5 nm off; from 30 nm on courses 60 deg right and 40 deg left of the leg START-FIX (090).
for _, case in ipairs({{250, "low", 5000, -60}, {480, "cruise", 33000, -60}, {250, "low", 5000, 40}}) do
    local speed = case
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 60, 90)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 150)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, 150)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("DEST", after_lat + 5, after_lon, 0, 1)}
    local bearing = (270 + case[4]) % 360
    out = fly({route = route, index = 3, start = {probe.movePoint(fix_lat, fix_lon, 30, bearing)}, heading = (bearing + 180) % 360,
        tas_kt = speed[1], alt_ft = speed[3], loop = speed[2], seconds = 60 / speed[1] * 3600,
        setup = function(env) env.B747DR_ap_lnav_xtk_target = -100 end})
    local passed = 1e9
    for _, p in ipairs(out.track) do passed = math.min(passed, probe.getDistance(fix_lat, fix_lon, p.lat, p.lon)) end
    check(passed <= 1.0, string.format("DIRECT TO FIX at %d kt from %03d: passed %.2f nm from it (at most 1)", speed[1],
        bearing, passed))
end

-- 9. A leg LNAV steers as before (no path: after an altitude leg's end, from VECTORS, after a turn passed
-- abeam) keeps the anticipation's lead for the turn at its end. With the bisector's sequencing there, LNAV
-- flew straight at the fix, reached the bisector only at the fix and went 2.7 nm outside EIDW's DW129: the
-- native route has "(650)" (the CA leg's end) before DW128, which is flown direct.
route = eidw()
table.insert(route, 4, E("(650)", 53.4375, -6.2866, 650, 2048))
start, course = along(route, 6, 0.5)
out = fly({route = route, index = 6, start = start, heading = course, tas_kt = 243, accel_kt_s = 0.45, tas_max_kt = 272,
    alt_ft = 4800, loop = "low", seconds = 240})
turn, overshoot = turn_metrics(out, route, 6)
check(overshoot <= 0.4, string.format("DW129 after (650) %+.0f deg: overshoot %.2f nm (at most 0.4)", turn, overshoot))
-- from VECTORS: FIX flown direct, then NEXT's 90 deg turn at 250 kt
do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 20, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 20, 90)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 20, 180)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("DEST", after_lat - 5, after_lon, 0, 1)}
    start, course = along(route, 4, 0.5)
    out = fly({route = route, index = 4, start = start, heading = course, tas_kt = 250, alt_ft = 5000, loop = "low",
        seconds = 360})
    turn, overshoot = turn_metrics(out, route, 4)
    check(overshoot <= 0.4, string.format("NEXT after FIX from VECTORS %+.0f deg: overshoot %.2f nm (at most 0.4)", turn,
        overshoot))
end

-- 10. Two turns the same way at the ends of a short leg: their arcs share it (no overlap), so the path turns
-- the right way round. Overlapping, they handed the 747 over to the next leg's capture while it still faced
-- away from it, and it turned the wrong way round (527 deg of turning for two 120 deg turns 2 nm apart at
-- 250 kt). Opposite turns (an S) keep their arcs.
for _, c in ipairs({{120, 2, 120, 360}, {145, 4, 120, 400}}) do
    local lat0, lon0 = 50, -10
    local f1_lat, f1_lon = probe.movePoint(lat0, lon0, 40, 0)
    local f2_lat, f2_lon = probe.movePoint(f1_lat, f1_lon, c[2], c[1])
    local f3_lat, f3_lon = probe.movePoint(f2_lat, f2_lon, 40, c[1] + c[3])
    local f4_lat, f4_lon = probe.movePoint(f3_lat, f3_lon, 40, c[1] + c[3])
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("F1", f1_lat, f1_lon), E("F2", f2_lat, f2_lon),
        E("F3", f3_lat, f3_lon), E("F4", f4_lat, f4_lon), E("DEST", f4_lat + 5, f4_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(lat0, lon0, 20, 0)}, heading = 0, tas_kt = 250,
        alt_ft = 5000, loop = "low", seconds = (20 + c[2] + 30) / 250 * 3600 + 120})
    local name = string.format("%+d deg, %d nm, %+d deg at 250 kt", c[1], c[2], c[3])
    check(out.turned <= c[4], string.format("%s: %.0f deg of turning in all (at most %d)", name, out.turned, c[4]))
    check(fixes_in_order(out, route, 3, 4), name..": F1 and F2 sequenced in order")
end

print("LNAV turn anticipation tests passed: "..checks)
