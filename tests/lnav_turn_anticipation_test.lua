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
-- wind_kt, seconds, setup = function(env) before the first frame, armed = LNAV
-- pushed (armed) with HDG SEL on the start heading: out.engaged = {t, lat, lon}
-- when it engages; arm_at_s = HDG SEL on the start heading, LNAV off, pushed at
-- that time: out.pushed = {t, index}; hook = function(env, t, out) every frame
-- after the sequencing; tas_fn = function(t) the TAS}. A frame as the 747's:
-- the sequencing with the cross-track and VNAV's held fix (B747_getCurrentWayPoint),
-- LNAV's steering (B747_monitorAP), then the armed LNAV engaging (B747_ap_fma).
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
    if s.armed then env.B747DR_ap_lnav_state, env.simDR_autopilot_heading_deg = 1, s.heading end
    if s.arm_at_s then env.B747DR_ap_lnav_state, env.simDR_autopilot_heading_deg = 0, s.heading end
    if s.ground then env.simDR_onGround = 1 end
    if s.setup then s.setup(env) end
    local alt = s.alt_ft
    env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = alt, alt, s.vs_fpm or 0
    local out = {track = {}, switches = {}, back = false, env = env}
    local t, previous = 0, s.index
    while t < s.seconds do
        if s.tas_fn then tas = s.tas_fn(t) end
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
        env.B747_lnav_update_xtk(route)
        env.B747_lnav_update_vnav_hold(route)
        if s.hook then s.hook(env, t, out) end
        if env.B747DR_fmscurrentIndex ~= previous then
            if env.B747DR_fmscurrentIndex < previous then out.back = true end
            local fix = route[previous]
            out.switches[#out.switches + 1] = {from = previous, to = env.B747DR_fmscurrentIndex,
                nm = env.getDistance(lat, lon, fix[5], fix[6]), lat = lat, lon = lon, t = t}
            previous = env.B747DR_fmscurrentIndex
        end
        if s.arm_at_s and not out.pushed and t >= s.arm_at_s then
            env.B747DR_ap_lnav_state, out.pushed = 1, {t = t, index = env.B747DR_fmscurrentIndex}
        end
        env.B747_updateApproachHeading(route)
        if env.B747DR_ap_lnav_state == 1 then
            -- armed LNAV engaging (B747_ap_fma; before LNAV ARM it engaged at once above 50 ft)
            if env.B747_lnav_engage_armed then
                env.B747_lnav_engage_armed(route)
            elseif env.simDR_radarAlt1 > 50 then
                env.B747DR_ap_lnav_state = 2
            end
            if env.B747DR_ap_lnav_state == 2 then out.engaged = {t = t, lat = lat, lon = lon} end
        end
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
        if s.ground then env.simDR_onGround = alt <= 0 and 1 or 0 end
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
    -- [P15] beyond 150 deg the turn starts where a 150 deg turn would; from 175 deg a reversal, no fly-by
    near(anticipation(478, 0, 0, 20, 0, 160, 3, 478), radius * math.tan(math.rad(75)) + roll_in, 0.01,
        "160 deg: where a 150 deg turn starts")
    near(anticipation(478, 0, 0, 20, 0, -170, 3, 478), radius * math.tan(math.rad(75)) + roll_in, 0.01,
        "170 deg left: where a 150 deg turn starts")
    check(anticipation(478, 0, 0, 20, 0, 176, 3, 478) == 0, "176 deg: a reversal, no fly-by, the next leg once abeam "
        .."the fix (0), "..tostring(anticipation(478, 0, 0, 20, 0, 176, 3, 478)))
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

-- Turning back by more than 150 deg at 200 kt and 3,000 ft: the turn is flown once, toward the next fix, not as an
-- orbit back over the passed fix (with no lead at all the fix stayed active and LNAV flew back to it: 572 deg of
-- turning on a turn-back SID). [P15] A fly-by from where a 150 deg turn starts (R tan(75), 6.0 nm before the fix at
-- 1.6 nm of radius), the path fitting on the 10 nm leg: the 747 2.18 and 1.64 nm outside the next leg (the path
-- 2.14 and 1.60) and 266 and 261 deg of turning; passed abeam 3.22 and 3.21 nm. A reversal (178 deg) is passed abeam
-- as before.
for _, angle in ipairs({170, -165, 178}) do
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
    local side = angle > 0 and 1 or -1
    local outside = 0
    for _, q in ipairs(out.track) do
        outside = math.max(outside, -side * afds.signed_cross_track_nm(fix_lat, fix_lon, next_lat, next_lon, q.lat,
            q.lon, probe.getDistance, probe.getHeading))
    end
    local capped = afds.lnav_capped_turn and afds.lnav_capped_turn(angle, afds.turn_radius_nm(200, 20))
    if math.abs(angle) < 175 then
        check(capped ~= nil and outside <= capped.outside_nm + 0.4, string.format(
            "%s: %.2f nm outside the next leg (the fly-by path %s)", name, outside,
            capped and string.format("%.2f", capped.outside_nm) or "none"))
    else
        local at_fix = nil
        for _, sw in ipairs(out.switches) do if sw.from == 3 then at_fix = sw.nm end end
        check(at_fix ~= nil and at_fix <= 1, string.format("%s: a reversal, FIX sequenced abeam it (%s nm)", name,
            at_fix and string.format("%.2f", at_fix) or "never"))
    end
end

-- 17. [P15] Fly-by turns of more than 150 deg at FL350 and 480 kt (R 9.2 nm at 20 deg of bank; 13.3 nm drawn for
-- the 96 kt wind): the turn starts where a 150 deg turn's arc would, R tan(75) before the fix (34 nm; 50 in the
-- wind), and the 747 follows the path - on round the arc by up to 45 deg past the outbound course, a straight line
-- closing on the outbound leg, an arc back onto it - within 0.5 nm, no farther outside the outbound leg than the
-- path (6.1 nm for 160 deg, 12.3 for 170) and on it within 0.15 nm once the path has joined it; FIX sequenced at the
-- turn's bisector, NEXT after it. Passed abeam (no fly-by) the 747 turned only at the fix and went 18.1-18.5 nm
-- outside (24.3 in the wind), with 295-326 deg of turning.
for _, c in ipairs({{160, 0, 0}, {170, 0, 0}, {-170, 0, 0}, {165, 270, 96}}) do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 80, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 110, c[1] % 360)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 60, c[1] % 360)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("DEST", after_lat - 5, after_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(fix_lat, fix_lon, 70, 180)
    -- the heading for a 000 track in the wind
    local cross = -c[3] * math.sin(math.rad(c[2]))
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = (-math.deg(math.asin(cross / 480))) % 360,
        tas_kt = 480, alt_ft = 35000, loop = "cruise", wind_from_deg = c[2], wind_kt = c[3], seconds = 1500})
    local name = string.format("%+d deg at 480 kt%s", c[1], c[3] > 0 and string.format(" in %03d/%d", c[2], c[3]) or "")
    local R = afds.turn_radius_nm(480 + c[3], 20)
    local capped = afds.lnav_capped_turn and afds.lnav_capped_turn(c[1], R)
    check(capped ~= nil, name..": a capped fly-by turn")
    if capped then
        local in_course = (probe.getHeading(fix_lat, fix_lon, lat0, lon0) + 180) % 360
        local out_course = probe.getHeading(fix_lat, fix_lon, next_lat, next_lon)
        local side = c[1] > 0 and 1 or -1
        local deviation, outside, rejoined, start_nm = 0, 0, 0, nil
        for _, q in ipairs(out.track) do
            local d = probe.getDistance(fix_lat, fix_lon, q.lat, q.lon)
            local b = math.rad(probe.getHeading(fix_lat, fix_lon, q.lat, q.lon))
            local pth = afds.lnav_path_at(d * math.sin(b), d * math.cos(b), in_course, out_course, R, 1.6, 3.7)
            local x = afds.signed_cross_track_nm(fix_lat, fix_lon, next_lat, next_lon, q.lat, q.lon, probe.getDistance,
                probe.getHeading)
            local along_out = d * math.cos(b - math.rad(out_course))
            if pth and pth.along_nm > -30 and along_out < capped.after_nm + 5 then
                deviation = math.max(deviation, math.abs(pth.xtk_nm))
            end
            if pth and pth.past_bisector then outside = math.max(outside, -side * x) end
            if pth and pth.element == "out" and along_out > capped.after_nm + 5 and along_out < 100 then
                rejoined = math.max(rejoined, math.abs(x))
            end
            if start_nm == nil and q.bank * side > 5 then
                start_nm = -(d * math.cos(b - math.rad(in_course)))
            end
        end
        check(start_nm ~= nil and start_nm >= capped.before_nm - 0.5 and start_nm <= capped.before_nm + 2.5,
            string.format("%s: turned from %s nm before the fix (the path's arc from %.1f)", name,
            start_nm and string.format("%.1f", start_nm) or "nowhere", capped.before_nm))
        check(deviation <= 0.5, string.format("%s: %.2f nm from the path at most (0.5)", name, deviation))
        check(outside <= capped.outside_nm + 0.5, string.format("%s: %.2f nm outside the outbound leg (the path %.2f)",
            name, outside, capped.outside_nm))
        check(rejoined <= 0.15, string.format("%s: %.2f nm off the outbound leg after the path joins it (0.15)", name,
            rejoined))
        -- and the heading's crab into the wind, which changes round the turn
        local crab = math.deg(math.asin(c[3] / 480))
        check(out.turned <= math.abs(c[1]) + 2 * capped.beta_deg + 20 + 2 * crab, string.format(
            "%s: %.0f deg of turning in all (%d, twice %.0f on and back, twice %.0f of crab)", name, out.turned,
            math.abs(c[1]), capped.beta_deg, crab))
        check(fixes_in_order(out, route, 3, 4), name..": FIX and NEXT sequenced in order")
    end
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
    env.B747DR_ap_approach_mode = o.approach or 0
    local lat, lon = env.movePoint(lat0, lon0, 30 - (o.before or 10), 0)
    lat, lon = env.movePoint(lat, lon, o.xtk or 0, 90)
    env.simDR_latitude, env.simDR_longitude = lat, lon
    env.simDR_true_heading, env.simDR_ground_track_true = o.track or 0, o.track or 0
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
-- with APP armed (0.3 nm) on FIX's arc in the first half of its 90 deg turn (40 deg round, 0.59 nm inside the leg
-- to FIX at 250 kt and 20 deg of bank): no UNABLE RNP, the 747 on the path (from the straight leg it flashed in
-- such turns); 0.4 nm off the leg 10 nm before FIX, where the path is the leg: UNABLE RNP
do
    local radius = afds.turn_radius_nm(250, 20)
    local round = math.rad(40)
    local env_arc = frame_on_path({approach = 1, before = radius * (1 - math.sin(round)),
        xtk = radius * (1 - math.cos(round)), track = 40})
    check(env_arc.B747DR_fmscurrentIndex == 3 and env_arc.B747DR_CAS_caution_status[66] == 0,
        string.format("APP armed, on FIX's arc %.2f nm inside the leg to it: no UNABLE RNP, got %s",
            radius * (1 - math.cos(round)), tostring(env_arc.B747DR_CAS_caution_status[66])))
    check(frame_on_path({approach = 1, xtk = 0.4}).B747DR_CAS_caution_status[66] == 1,
        "APP armed, 0.4 nm off the leg 10 nm before FIX: UNABLE RNP")
end
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

-- 11. A turn whose next fix, a short leg on, turns less than a degree the same way: no leg to share with it,
-- the arc keeps its radius (squeezed to end at that fix, it could not be flown: 2.2 nm outside the leg after it
-- for 120 deg at 250 kt with a 1.5 nm leg, 9.5 nm at 480 kt with 4.5 nm).
for _, c in ipairs({{250, "low", 5000, 1.5, 0.4}, {480, "cruise", 33000, 4.5, 1.0}}) do
    local lat0, lon0 = 50, -10
    local f2_lat, f2_lon = probe.movePoint(lat0, lon0, 40, 0)
    local f3_lat, f3_lon = probe.movePoint(f2_lat, f2_lon, c[4], 120)
    local f4_lat, f4_lon = probe.movePoint(f3_lat, f3_lon, 40, 122)
    local f5_lat, f5_lon = probe.movePoint(f4_lat, f4_lon, 40, 122)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("F2", f2_lat, f2_lon), E("F3", f3_lat, f3_lon),
        E("F4", f4_lat, f4_lon), E("F5", f5_lat, f5_lon), E("DEST", f5_lat + 5, f5_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(lat0, lon0, 20, 0)}, heading = 0, tas_kt = c[1],
        alt_ft = c[3], loop = c[2], seconds = (20 + c[4] + 30) / c[1] * 3600 + 120})
    local outside = 0
    for _, q in ipairs(out.track) do
        local d = probe.getDistance(f3_lat, f3_lon, q.lat, q.lon)
        local brg = probe.getHeading(f3_lat, f3_lon, q.lat, q.lon)
        if d < 25 and math.abs(wrap(brg - 122)) < 90 then
            outside = math.max(outside, -afds.signed_cross_track_nm(f3_lat, f3_lon, f4_lat, f4_lon, q.lat, q.lon,
                probe.getDistance, probe.getHeading))
        end
    end
    check(outside <= c[5], string.format("+120 deg then %.1f nm to a 2 deg turn at %d kt: %.2f nm outside the leg after it "
        .."(at most %.1f)", c[4], c[1], outside, c[5]))
end

-- 12. A turn-back (more than 150 deg) and a 90 deg turn 10-15 nm on at 200 kt. 170 deg then 10 nm: the turn-back's
-- fly-by path (P15) would join the leg only 9.6 nm on, past where the 90 deg turn's arc starts (8.4 nm), so it is
-- passed abeam; the leg between is steered as before, and the 747, not yet on it when the 90 deg turn is sequenced
-- (flying direct to its fix), rolls the turn's way and is no farther outside the leg after it than before i-1b
-- (0.54 nm; flown by, still 45 deg on there, 1.16). The 90 deg turn's arc, drawn from the leg the 747 was not on,
-- first rolled it the wrong way: 1.16 nm outside. 165 deg then 15 nm: flown by, 0.03 nm (passed abeam 0.24; the
-- wrong way 0.42).
for _, c in ipairs({{170, 10, -90, 0.6, false}, {-165, 15, 90, 0.1, true}}) do
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 20, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, c[2], c[1] % 360)
    local course = (c[1] + c[3]) % 360
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 30, course)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 30, course)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon), E("DEST", far_lat - 5, far_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {probe.movePoint(lat0, lon0, 15, 0)}, heading = 0, tas_kt = 200,
        alt_ft = 3000, loop = "low", seconds = 700})
    local outside, side = 0, c[3] > 0 and 1 or -1
    for _, q in ipairs(out.track) do
        local d = probe.getDistance(next_lat, next_lon, q.lat, q.lon)
        local brg = probe.getHeading(next_lat, next_lon, q.lat, q.lon)
        if d < 20 and math.abs(wrap(brg - course)) < 90 then
            outside = math.max(outside, -side * afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon,
                q.lat, q.lon, probe.getDistance, probe.getHeading))
        end
    end
    local name = string.format("turn-back %+d deg, %d nm, then %+d deg", c[1], c[2], c[3])
    check(outside <= c[4], string.format("%s: %.2f nm outside the leg after it (at most %.1f)", name, outside, c[4]))
    local sequenced, roll = nil, 0
    for _, sw in ipairs(out.switches) do if sw.from == 4 then sequenced = sw.t end end
    for _, q in ipairs(out.track) do
        if sequenced and q.t > sequenced and math.abs(q.bank) > 5 then roll = q.bank break end
    end
    check(roll * side > 0, string.format("%s: first rolled %+.0f deg after NEXT was sequenced (its turn's way)", name, roll))
    check(fixes_in_order(out, route, 3, 4), name..": FIX and NEXT sequenced in order")
    local fix_at = nil
    for _, sw in ipairs(out.switches) do if sw.from == 3 then fix_at = sw.nm end end
    check(fix_at ~= nil and (c[5] and fix_at >= 2 or not c[5] and fix_at <= 1), string.format(
        "%s: the turn-back %s, FIX sequenced %s nm from it", name, c[5] and "flown by"
        or "passed abeam (its path does not fit)", fix_at and string.format("%.1f", fix_at) or "never"))
end

-- 14. After a leg LNAV steered as before (from VECTORS), a 747 established on it flies the next fix's arc from the
-- hand-over (by the lead), also where the arc - drawn for the highest ground speed across the turn - began before
-- the lead in the wind and the 747 was already 0.4 nm into it, the arc's course 9 deg round (250 kt, +90 deg,
-- 000/40): it was taken for a 747 off the path, and LNAV flew the next leg's 45 deg capture instead.
local function handover_runtime()
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 30, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, 90)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 40, 90)
    local r = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon),
        E("DEST", far_lat + 5, far_lon, 0, 1)}
    local env = new_runtime()
    -- the track LNAV's path commands with AFTER flown to, before_nm before NEXT and off_nm right of the leg to it,
    -- on track, at 250 kt TAS in 000/40
    local function steer(before_nm, off_nm, track)
        local lat, lon = env.movePoint(next_lat, next_lon, before_nm, 180)
        lat, lon = env.movePoint(lat, lon, off_nm, 90)
        env.simDR_latitude, env.simDR_longitude = lat, lon
        env.simDR_true_heading, env.simDR_ground_track_true = track, track
        env.simDR_TAS_mps, env.simDR_groundspeed = 250 * KT, 210 * KT
        env.simDR_pressureAlt1, env.simDR_radarAlt1 = 5000, 5000
        env.B747DR_fmscurrentIndex = 5
        return env.B747_lnav_path_track(r, 5)
    end
    return env, steer, r
end
do
    local _, steer = handover_runtime()
    local track = steer(2.09, 0, 0)
    check(track ~= nil and track < 38, string.format(
        "on the leg from VECTORS at NEXT's hand-over in 000/40, 0.4 nm into its arc: NEXT's arc (track %s; the next leg's capture 45)",
        tostring(track and math.floor(track + 0.5))))
    _, steer = handover_runtime()
    track = steer(2.09, 0.5, 0)
    check(track ~= nil and track >= 40, string.format(
        "0.5 nm off the leg at the hand-over: the next leg's path (track %s)", tostring(track and math.floor(track + 0.5))))
    -- decided again when NEXT is sequenced again (a reposition, back-sequencing: FIX flown to in between); the
    -- first decision was kept for the same fixes
    local env, r
    env, steer, r = handover_runtime()
    steer(2.09, 0.5, 0)
    env.B747DR_fmscurrentIndex = 3
    env.B747_lnav_path_track(r, 3)
    track = steer(2.09, 0, 0)
    check(track ~= nil and track < 38, string.format(
        "NEXT sequenced again after FIX flown to, on the leg: NEXT's arc (track %s), decided again",
        tostring(track and math.floor(track + 0.5))))
end

-- 15. LNAV ARM: LNAV pushed in flight engages within 2.5 nm of the active leg's line on any track, before the leg's
-- start too, or on a track towards the line at up to 90 deg that crosses it before the active fix, where the turn
-- onto it begins; otherwise it stays armed and the 747 keeps its selected heading (HDG SEL), Aerowinx PSX's 747-400
-- and the user's choices of 2026-10-16 and 2026-10-17. It engaged at once wherever the 747 was and turned it back to
-- the leg (the kit's TST744L rejoin after the AFDS block: 19.7 nm off, at 76 deg).
do
    local a_lat, a_lon = 52, -12
    local b_lat, b_lon = probe.movePoint(a_lat, a_lon, 300, 270)
    local c_lat, c_lon = probe.movePoint(b_lat, b_lon, 100, 270)
    route = {E("ORIG", 53, -11, 0, 1), E("A", a_lat, a_lon), E("B", b_lat, b_lon), E("C", c_lat, c_lon),
        E("DEST", c_lat, c_lon - 2, 0, 1)}
    local function start(along_nm, off_nm)
        local lat, lon = probe.movePoint(a_lat, a_lon, along_nm, 270)
        return {probe.movePoint(lat, lon, off_nm, 0)}
    end
    local function xtk(lat, lon)
        return afds.signed_cross_track_nm(a_lat, a_lon, b_lat, b_lon, lat, lon, probe.getDistance, probe.getHeading)
    end
    local function cruise(o)
        return fly({route = route, index = 3, start = o.start, heading = o.heading, tas_kt = 480, alt_ft = 33000,
            loop = "cruise", seconds = o.seconds, armed = true})
    end
    -- 20 nm right of the leg on a parallel heading: armed after 10 min, the heading kept
    out = cruise({start = start(50, 20), heading = 270, seconds = 600})
    local last = out.track[#out.track]
    check(out.engaged == nil and out.env.B747DR_ap_lnav_state == 1, string.format(
        "LNAV pushed 20 nm off the leg on a parallel heading: still armed after 10 min (engaged %s)",
        out.engaged and string.format("at %.0f s", out.engaged.t) or "never"))
    check(math.abs(wrap(out.env.simDR_true_heading - 270)) <= 1 and xtk(last.lat, last.lon) >= 19, string.format(
        "... on its heading %.0f, %.1f nm off the leg", out.env.simDR_true_heading, xtk(last.lat, last.lon)))
    -- 45 and 90 deg towards the leg: engaged where the turn onto it begins (its anticipation across the leg: 3.0 and
    -- 9.7 nm at 480 kt and 20 deg; never nearer than 2.5 nm), then onto it without going through it
    for _, c in ipairs({{225, 3.0}, {180, 9.7}}) do
        out = cruise({start = start(50, 20), heading = c[1], seconds = 900})
        local at = out.engaged and xtk(out.engaged.lat, out.engaged.lon)
        local name = string.format("LNAV pushed 20 nm off the leg, %d deg towards it", 270 - c[1])
        check(at ~= nil and math.abs(at - c[2]) <= 0.3, string.format("%s: engaged %s nm off it (%.1f)", name,
            at and string.format("%.2f", at) or "never", c[2]))
        local through = 0
        for _, q in ipairs(out.track) do through = math.max(through, -xtk(q.lat, q.lon)) end
        last = out.track[#out.track]
        local final = math.abs(xtk(last.lat, last.lon))
        check(through <= 0.2 and final <= 0.1, string.format(
            "%s: then onto the leg, %.2f nm through it at most (0.2), %.2f nm off at the end (0.1)", name, through, final))
    end
    -- 1 nm off: at once
    out = cruise({start = start(50, 1), heading = 270, seconds = 2})
    check(out.engaged ~= nil and out.engaged.t <= 0.1, "LNAV pushed 1 nm off the leg: engaged at once")
    -- 1 nm off the leg's line 10 nm before its start (A): engaged at once and onto the line, along it to A and the leg
    -- (counting the line before the start only within 2.5 nm of A, LNAV engaged 58 s later)
    out = cruise({start = start(-10, 1), heading = 270, seconds = 120})
    last = out.track[#out.track]
    check(out.engaged ~= nil and out.engaged.t <= 0.1 and math.abs(xtk(last.lat, last.lon)) <= 0.1, string.format(
        "LNAV pushed 1 nm off the leg's line 10 nm before its start: engaged %s (at once), %.2f nm off at the end (0.1)",
        out.engaged and string.format("at %.0f s", out.engaged.t) or "never", math.abs(xtk(last.lat, last.lon))))
    -- 12 nm off, 85 deg towards the leg's line 1 nm before its start: engaged as 1 nm past it, where the turn onto it
    -- begins (8.9 nm off), and onto the leg (only within 2.5 nm of A before its start it engaged 2.5 nm off and went
    -- 6.4 nm through the leg; a review, at 90 deg: 2.3 and 7.4 nm).
    local engaged_at = {}
    for _, along_nm in ipairs({1, -1}) do
        out = cruise({start = start(along_nm, 12), heading = 185, seconds = 900})
        local at = out.engaged and xtk(out.engaged.lat, out.engaged.lon)
        engaged_at[along_nm] = at
        local through = 0
        for _, q in ipairs(out.track) do through = math.max(through, -xtk(q.lat, q.lon)) end
        last = out.track[#out.track]
        local final = math.abs(xtk(last.lat, last.lon))
        check(at ~= nil and at >= 8 and through <= 0.2 and final <= 0.1, string.format(
            "LNAV pushed 12 nm off the leg, 85 deg towards it, 1 nm %s its start: engaged %s nm off it, then %.2f nm through it at most (0.2), %.2f nm off at the end (0.1)",
            along_nm < 0 and "before" or "past", at and string.format("%.2f", at) or "never", through, final))
    end
    check(engaged_at[1] and engaged_at[-1] and math.abs(engaged_at[1] - engaged_at[-1]) <= 0.3, string.format(
        "... 1 nm before the start engaged as 1 nm past it (%s, %s nm off)", tostring(engaged_at[-1]),
        tostring(engaged_at[1])))
    -- 45 deg towards the leg's line, crossing it 6 nm before its start: engaged where the turn onto it begins (3.0 nm
    -- off) and onto the line and the leg
    local c_lat, c_lon = probe.movePoint(a_lat, a_lon, 6, 90)
    local s45 = {probe.movePoint(c_lat, c_lon, 15, 45)}
    out = cruise({start = s45, heading = 225, seconds = 600})
    do
        local at = out.engaged and xtk(out.engaged.lat, out.engaged.lon)
        local through = 0
        for _, q in ipairs(out.track) do through = math.max(through, -xtk(q.lat, q.lon)) end
        last = out.track[#out.track]
        local final = math.abs(xtk(last.lat, last.lon))
        check(at ~= nil and math.abs(at - 3.0) <= 0.3 and through <= 0.3 and final <= 0.1, string.format(
            "LNAV pushed 45 deg towards the leg's line crossing it 6 nm before its start: engaged %s nm off it (3.0), then %.2f nm through it at most (0.3), %.2f nm off at the end (0.1)",
            at and string.format("%.2f", at) or "never", through, final))
    end
    -- 20 nm before the start also where the turn begins and onto the line 19 nm before the start, along it to A and
    -- the leg (counting the line before the start only where the turn ends near A, armed across the line)
    out = cruise({start = start(-20, 12), heading = 185, seconds = 600})
    do
        local at = out.engaged and xtk(out.engaged.lat, out.engaged.lon)
        local through = 0
        for _, q in ipairs(out.track) do through = math.max(through, -xtk(q.lat, q.lon)) end
        last = out.track[#out.track]
        local final = math.abs(xtk(last.lat, last.lon))
        check(at ~= nil and at >= 8 and through <= 0.2 and final <= 0.1, string.format(
            "LNAV pushed 12 nm off the leg's line 20 nm before its start, 85 deg towards it: engaged %s nm off it, then %.2f nm through it at most (0.2), %.2f nm off at the end (0.1)",
            at and string.format("%.2f", at) or "never", through, final))
    end
end
-- On a track towards the active leg at 45 deg (480 kt, the turn onto it beginning 3.0 nm off) that crosses its line
-- 1 nm past the active fix (NEXT, the leg after it straight on): engaged only within 2.5 nm of the line; crossing it
-- 1 nm before NEXT, where the turn begins. Both onto the line (near NEXT LNAV's path guidance aims only its 12 s
-- look-ahead ahead, holds the 45 deg intercept to 1.6 nm off and goes 0.7-1.5 nm through the line).
do
    local lat0, lon0 = 52, -12
    local next_lat, next_lon = probe.movePoint(lat0, lon0, 20, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 20, 0)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 60, 0)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon), E("DEST", far_lat + 1, far_lon, 0, 1)}
    local function line_xtk(lat, lon)
        return afds.signed_cross_track_nm(lat0, lon0, next_lat, next_lon, lat, lon, probe.getDistance, probe.getHeading)
    end
    for _, c in ipairs({{1, 2.5, "past"}, {-1, 3.0, "before"}}) do
        local s_lat, s_lon = probe.movePoint(next_lat, next_lon, 8 - c[1], 180)
        s_lat, s_lon = probe.movePoint(s_lat, s_lon, 8, 90)
        out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 315, tas_kt = 480, alt_ft = 33000,
            loop = "cruise", seconds = 300, armed = true})
        local at = out.engaged and line_xtk(out.engaged.lat, out.engaged.lon)
        local last = out.track[#out.track]
        local final = math.abs(line_xtk(last.lat, last.lon))
        check(at ~= nil and math.abs(at - c[2]) <= 0.15 and final <= 0.1, string.format(
            "LNAV pushed 45 deg towards the leg, crossing its line 1 nm %s the active fix: engaged %s nm off it (%.1f), %.2f nm off at the end (0.1)",
            c[3], at and string.format("%.2f", at) or "never", c[2], final))
    end
end
-- LNAV pushed just past a fly-by fix the 747 flew straight through in HDG SEL (1 nm past NEXT, 0.5 nm outside its
-- +90 deg turn, NEXT sequenced, so the next leg starts behind the 747's abeam point): engaged at once, 1 nm off the
-- next leg's line, then onto that leg. Waiting to be abeam the leg past its start it stayed armed while HDG SEL flew away (a
-- review: 42-44 nm off after 10 min).
do
    local lat0, lon0 = 52, -12
    local next_lat, next_lon = probe.movePoint(lat0, lon0, 40, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, 90)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 40, 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon), E("DEST", far_lat, far_lon + 1, 0, 1)}
    local s_lat, s_lon = probe.movePoint(next_lat, next_lon, 1, 0)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 0.5, 270)
    out = fly({route = route, index = 4, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000, loop = "low",
        seconds = 300, armed = true})
    local through, last = 0, out.track[#out.track]
    for _, q in ipairs(out.track) do
        through = math.max(through, afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon, q.lat, q.lon,
            probe.getDistance, probe.getHeading))
    end
    local final = math.abs(afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon, last.lat, last.lon,
        probe.getDistance, probe.getHeading))
    check(out.engaged ~= nil and out.engaged.t <= 0.1 and through <= 0.3 and final <= 0.1, string.format(
        "LNAV pushed 1 nm past a fly-by fix flown through in HDG SEL: engaged %s, %.2f nm through the next leg, %.2f off it at the end",
        out.engaged and string.format("at %.1f s", out.engaged.t) or "never", through, final))
end
-- LNAV pushed beside the leg into the active leg's start fix A, which the FMC sequenced while LNAV was not engaged
-- (A->B on 090 active, the leg into A from the north, a -90 deg turn at A), 12 nm off A->B and 1 nm past A at 90 deg
-- towards it, 1 nm off the leg into A: engaged and onto A->B, not round A's arc, which LNAV did not fly (from A's
-- leg and arc at 250 kt it turned 208-216 deg and went 0.7-2.0 nm through A->B).
do
    local a_lat, a_lon = 52, -12
    local p_lat, p_lon = probe.movePoint(a_lat, a_lon, 40, 0)
    local p0_lat, p0_lon = probe.movePoint(p_lat, p_lon, 40, 0)
    local b_lat, b_lon = probe.movePoint(a_lat, a_lon, 60, 90)
    local c_lat, c_lon = probe.movePoint(b_lat, b_lon, 60, 90)
    route = {E("ORIG", p0_lat - 1, p0_lon, 0, 1), E("P0", p0_lat, p0_lon), E("P", p_lat, p_lon), E("A", a_lat, a_lon),
        E("B", b_lat, b_lon), E("C", c_lat, c_lon), E("DEST", c_lat, c_lon + 3, 0, 1)}
    local s_lat, s_lon = probe.movePoint(a_lat, a_lon, 1, 90)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 12, 0)
    out = fly({route = route, index = 5, start = {s_lat, s_lon}, heading = 180, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 400, armed = true})
    local function ab_xtk(lat, lon)
        return afds.signed_cross_track_nm(a_lat, a_lon, b_lat, b_lon, lat, lon, probe.getDistance, probe.getHeading)
    end
    -- HDG SEL holds 180 until LNAV engages: the heading's changes all after that
    local through = 0
    for _, q in ipairs(out.track) do through = math.max(through, ab_xtk(q.lat, q.lon)) end
    local last = out.track[#out.track]
    local final = math.abs(ab_xtk(last.lat, last.lon))
    check(out.engaged ~= nil and out.turned <= 120 and through <= 0.3 and final <= 0.1, string.format(
        "LNAV pushed beside the leg into the active leg's start fix (sequenced while LNAV was not engaged): engaged %s, turned %.0f deg (120), %.2f nm through A->B (0.3), %.2f off it at the end (0.1)",
        out.engaged and string.format("%.2f nm off A->B", math.abs(ab_xtk(out.engaged.lat, out.engaged.lon))) or "never",
        out.turned, through, final))
end
-- LNAV pushed 5 nm before a fly-by fix (480 kt, +90 deg at NEXT, its lead 9.7 nm) in HDG SEL 1.5 nm left of the leg
-- to it: NEXT not yet sequenced (while LNAV is not engaged the FMC sequences abeam the fix, not at its lead), engaged
-- at the push, abeam the leg to NEXT, and flown as LNAV engaging at once flies it, the heading closing on the next
-- leg (000) or not (345). Sequenced at the lead (6.1 nm before NEXT, once HDG SEL was 2 nm off its arc) the active
-- leg started ahead: within 2.5 nm of NEXT only it engaged 22.5 s late, 7.7 nm outside the next leg (at once 4.8), or
-- never (72 nm off after 10 min; a review).
do
    local lat0, lon0 = 52, -12
    local next_lat, next_lon = probe.movePoint(lat0, lon0, 60, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 60, 90)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 60, 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon), E("DEST", far_lat, far_lon + 1, 0, 1)}
    -- at the push 5 nm before NEXT and 1.5 nm left of the leg to it, on the heading for 5 nm before that
    local p_lat, p_lon = probe.movePoint(next_lat, next_lon, 5, 180)
    p_lat, p_lon = probe.movePoint(p_lat, p_lon, 1.5, 270)
    local push = 5 / 480 * 3600
    local function arm(heading, at_once)
        local s_lat, s_lon = probe.movePoint(p_lat, p_lon, 5, (heading + 180) % 360)
        local o = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = heading, tas_kt = 480,
            alt_ft = 33000, loop = "cruise", seconds = 600, arm_at_s = push,
            setup = at_once and function(env) env.B747_lnav_engage_armed = nil end or nil})
        local outside = 0
        for _, q in ipairs(o.track) do
            outside = math.max(outside, -afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon, q.lat,
                q.lon, probe.getDistance, probe.getHeading))
        end
        return o, outside
    end
    for _, heading in ipairs({0, 345}) do
        local o, outside = arm(heading)
        local _, reference = arm(heading, true)
        local name = string.format("LNAV pushed 5 nm before NEXT on HDG SEL %03d", heading)
        check(o.pushed and o.pushed.index == 3, name..": NEXT not sequenced before the push (abeam, not at its lead)")
        check(o.engaged ~= nil and o.engaged.t - o.pushed.t <= 0.1 and math.abs(outside - reference) <= 0.1,
            string.format("%s: engaged %s, %.2f nm outside the next leg (engaged at once %.2f)", name,
                o.engaged and string.format("%.1f s after the push", o.engaged.t - o.pushed.t) or "never", outside,
                reference))
    end
    -- NEXT sequenced (LNAV engaged at its lead, then HDG SEL) with the 747 on the leg to it, 1 nm off: only the active
    -- leg's line counts. 10 and 20 nm before NEXT flying away from it, armed; 20 nm before it flying towards it (at
    -- 90 deg to the active leg's line), engaged where the turn onto that line begins, 9.7 nm before it. The leg to
    -- NEXT counted within NEXT's lead and 2.5 nm, where the FMC sequenced it while LNAV was only armed: engaged at once
    -- 10 nm before NEXT on any track, flying away from it too, and 12.2 nm before it flying towards it.
    for _, c in ipairs({{20, 180}, {20, 0}, {10, 180}}) do
        local b_lat, b_lon = probe.movePoint(next_lat, next_lon, c[1], 180)
        b_lat, b_lon = probe.movePoint(b_lat, b_lon, 1, 270)
        out = fly({route = route, index = 4, start = {b_lat, b_lon}, heading = c[2], tas_kt = 480, alt_ft = 33000,
            loop = "cruise", seconds = 90, armed = true})
        local name = string.format("LNAV pushed %d nm before NEXT (sequenced) on the leg to it, HDG SEL %03d", c[1], c[2])
        if c[2] == 180 then
            check(out.engaged == nil, string.format("%s, flying away from NEXT: armed (engaged %s)", name,
                out.engaged and string.format("at %.1f s", out.engaged.t) or "never"))
        else
            local t_turn = (20 - 9.7) / 480 * 3600
            check(out.engaged ~= nil and math.abs(out.engaged.t - t_turn) <= 3, string.format(
                "%s, towards NEXT: engaged %s (where the turn onto the active leg's line begins, 9.7 nm before it, at %.0f s)",
                name, out.engaged and string.format("at %.1f s", out.engaged.t) or "never", t_turn))
        end
    end
    -- the leg to NEXT only up to NEXT: 10 nm past it, 0.5 nm outside its turn, flying on away from the next leg
    -- (10 nm off it), armed
    local q_lat, q_lon = probe.movePoint(next_lat, next_lon, 10, 0)
    q_lat, q_lon = probe.movePoint(q_lat, q_lon, 0.5, 270)
    out = fly({route = route, index = 4, start = {q_lat, q_lon}, heading = 0, tas_kt = 480, alt_ft = 33000,
        loop = "cruise", seconds = 60, armed = true})
    check(out.engaged == nil, string.format(
        "LNAV pushed 10 nm past NEXT on the line of the leg to it, flying away from the next leg: armed (engaged %s)",
        out.engaged and string.format("at %.1f s", out.engaged.t) or "never"))
end
-- A dogleg at 480 kt: +90 deg at FIX onto a 3 nm leg, -90 deg at NEXT, NEXT->AFTER parallel to the leg to FIX and
-- 3 nm across. LNAV pushed at FIX in HDG SEL along the leg to it: NEXT not sequenced (abeam only while LNAV is not
-- engaged; at the leads, both longer than the short leg, the FMC had sequenced FIX and NEXT and left the active leg
-- parallel, 3 nm across), engaged at the push and onto NEXT->AFTER.
do
    local lat0, lon0 = 52, -12
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 60, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 3, 90)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 60, 0)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 60, 0)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon),
        E("DEST", far_lat + 1, far_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(fix_lat, fix_lon, 15, 180)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 480, alt_ft = 33000,
        loop = "cruise", seconds = 600, arm_at_s = 15 / 480 * 3600})
    local last = out.track[#out.track]
    local final = math.abs(afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon, last.lat, last.lon,
        probe.getDistance, probe.getHeading))
    check(out.pushed and out.pushed.index <= 4 and out.engaged ~= nil and out.engaged.t - out.pushed.t <= 0.1
        and final <= 0.1, string.format(
        "LNAV pushed at a dogleg's FIX, NEXT not sequenced (index %s): engaged %s, %.2f nm off NEXT->AFTER at the end",
        tostring(out.pushed and out.pushed.index), out.engaged and string.format("%.1f s after the push",
        out.engaged.t - out.pushed.t) or "never", final))
end
-- 16. While LNAV is not engaged (off, or only armed) the FMC sequences the active fix as the aircraft passes abeam it,
-- past the perpendicular to its leg at the fix within 21 nm of the leg, not at the turn's lead (LNAV flies the lead
-- only while it steers): at 480 kt along the leg to NEXT (+90 deg, its lead 9.7 nm) in HDG SEL, with LNAV off and
-- with LNAV armed, NEXT is sequenced at the fix; 15 nm off the leg abeam NEXT, 25 nm off not at all.
do
    local lat0, lon0 = 52, -12
    local next_lat, next_lon = probe.movePoint(lat0, lon0, 60, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 60, 90)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 60, 90)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("NEXT", next_lat, next_lon),
        E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon), E("DEST", far_lat, far_lon + 1, 0, 1)}
    local function along_leg(off_nm, armed)
        local s_lat, s_lon = probe.movePoint(next_lat, next_lon, 20, 180)
        s_lat, s_lon = probe.movePoint(s_lat, s_lon, math.abs(off_nm), off_nm < 0 and 270 or 90)
        local o = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 480, alt_ft = 33000,
            loop = "cruise", seconds = 240, armed = armed, arm_at_s = (not armed) and 1e9 or nil,
            setup = armed and function(env) env.B747_lnav_engage_armed = function() end end or nil})
        for _, sw in ipairs(o.switches) do
            if sw.from == 3 then
                local d_lat, d_lon = sw.lat, sw.lon
                local along = probe.getDistance(next_lat, next_lon, d_lat, d_lon) * math.cos(math.rad(
                    probe.getHeading(next_lat, next_lon, d_lat, d_lon)))
                return along, o
            end
        end
        return nil, o
    end
    for _, c in ipairs({{0, false, "LNAV off"}, {0, true, "LNAV armed"},
            {-15, false, "LNAV off, 15 nm left of the leg"}}) do
        local at = along_leg(c[1], c[2])
        check(at ~= nil and math.abs(at) <= 0.5, string.format(
            "%s along the leg to NEXT (+90 deg at 480 kt): NEXT sequenced %s (abeam it, not 9.7 nm before)", c[3],
            at and string.format("%.1f nm %s it", math.abs(at), at < 0 and "before" or "past") or "never"))
    end
    local at = along_leg(-25, false)
    check(at == nil, string.format("LNAV off 25 nm left of the leg to NEXT: NEXT not sequenced passing abeam it (%s)",
        at and string.format("sequenced %.1f nm along", at) or "not sequenced"))
end
-- LNAV armed with HDG SEL parallel to the leg into a +30 deg fix B at 480 kt, 2.6 nm inside the turn: B sequenced
-- abeam it (LNAV not engaged), and LNAV engaging there in the same frame (within 2.5 nm of the leg after B) flies
-- that leg, not B's arc, which LNAV did not fly. Noted on the first call after the change of fix, B was taken for
-- one sequenced with LNAV engaged: 0.92 nm through the leg after B and 63 deg of turning (a review).
do
    local a_lat, a_lon = 50, -10
    local b_lat, b_lon = probe.movePoint(a_lat, a_lon, 60, 0)
    local c_lat, c_lon = probe.movePoint(b_lat, b_lon, 60, 30)
    local d_lat, d_lon = probe.movePoint(c_lat, c_lon, 60, 30)
    route = {E("ORIG", 49, -10, 0, 1), E("A", a_lat, a_lon), E("B", b_lat, b_lon), E("C", c_lat, c_lon),
        E("D", d_lat, d_lon), E("DEST", d_lat + 1, d_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(b_lat, b_lon, 25, 180)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 2.6, 90)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 480, alt_ft = 31000,
        loop = "cruise", seconds = 600, armed = true})
    local function bc_xtk(lat, lon)
        return afds.signed_cross_track_nm(b_lat, b_lon, c_lat, c_lon, lat, lon, probe.getDistance, probe.getHeading)
    end
    local x0, through, turned, last_heading = nil, 0, 0, nil
    for _, q in ipairs(out.track) do
        if out.engaged and q.t >= out.engaged.t then
            local x = bc_xtk(q.lat, q.lon)
            x0 = x0 or x
            if x * x0 < 0 then through = math.max(through, math.abs(x)) end
        end
    end
    local last = out.track[#out.track]
    check(out.engaged ~= nil and through <= 0.1 and out.turned <= 45 and math.abs(bc_xtk(last.lat, last.lon)) <= 0.1,
        string.format("LNAV armed parallel to the leg into a +30 deg fix, 2.6 nm inside, engaging as the fix is sequenced abeam: %s, %.2f nm through the next leg (0.1), %.0f deg of turning (45)",
        out.engaged and string.format("engaged at %.0f s", out.engaged.t) or "never", through, out.turned))
end
-- A leg flown direct to its fix (here from VECTORS) runs from where the 747 was when the fix became active: with
-- LNAV off it is sequenced abeam the fix, past that leg's wayline, like any leg. HDG SEL 000 from 20 nm before FIX
-- and 1.2 nm east passes it 1.2 nm abeam: FIX sequenced there. Judged by the distance only (within 0.3 or 0.5 nm),
-- FIX stayed active once passed, and LNAV pushed then engaged at once and turned back to it (after EIDW's "(650)" a
-- 747 passing DW128 0.75-1.24 nm off turned up to 180 deg back: a review).
do
    local lat0, lon0 = 52, -12
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 40, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 60)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("DEST", next_lat + 1, next_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(fix_lat, fix_lon, 20, 180)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 1.2, 90)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 22 / 250 * 3600, arm_at_s = 1e9})
    local at = nil
    for _, sw in ipairs(out.switches) do
        if sw.from == 3 then
            at = probe.getDistance(fix_lat, fix_lon, sw.lat, sw.lon) * math.cos(math.rad(
                probe.getHeading(fix_lat, fix_lon, sw.lat, sw.lon)))
        end
    end
    check(at ~= nil and math.abs(at) <= 0.5, string.format(
        "LNAV off on a leg flown direct to FIX from VECTORS, passing it 1.2 nm abeam: FIX sequenced %s",
        at and string.format("%.2f nm %s abeam it", math.abs(at), at < 0 and "before" or "past") or "never"))
end
-- The start of such a leg is noted with its fix: not a position of 0/0, XTLua's first read after a script reload (the
-- leg ran from 0N 0E), and again when another fix takes the active one's place at the same index (a route edit: the
-- leg ran from where the 747 was when the fix before it became active: a review). HDG SEL 000 with LNAV off from 20 nm
-- before FIX and 10 nm east: FIX sequenced where the 747 crosses the wayline of the leg from there.
local function direct_leg_switch(setup)
    local lat0, lon0 = 52, -12
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 40, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 60)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("DEST", next_lat + 1, next_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(fix_lat, fix_lon, 20, 180)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 10, 90)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 36 / 250 * 3600, arm_at_s = 1e9, setup = function(env)
            env.simDR_pressureAlt1, env.simDR_radarAlt1, env.simDR_vvi_fpm_pilot = 5000, 5000, 0
            env.simDR_groundspeed, env.simDR_TAS_mps, env.simDR_true_heading = 250 * KT, 250 * KT, 0
            setup(env, route, s_lat, s_lon)
        end})
    local in_course = (probe.getHeading(fix_lat, fix_lon, s_lat, s_lon) + 180) % 360
    for _, sw in ipairs(out.switches) do
        if sw.from == 3 then
            return probe.getDistance(fix_lat, fix_lon, sw.lat, sw.lon) * math.cos(math.rad(
                probe.getHeading(fix_lat, fix_lon, sw.lat, sw.lon) - in_course))
        end
    end
end
do
    -- XTLua's first frame after a reload reads the position 0/0
    local at = direct_leg_switch(function(env, r)
        for i = 1, #r do r[i][10] = (i == 3) end
        env.simDR_latitude, env.simDR_longitude, env.simDR_ground_track_true = 0, 0, 0
        env.B747_getCurrentWayPoint_function(r)
    end)
    check(at ~= nil and math.abs(at) <= 0.5, string.format(
        "a leg flown direct to FIX, the first read 0/0, passing FIX 10 nm off: sequenced %s the wayline of the leg from the first position (0.5)",
        at and string.format("%.2f nm %s", math.abs(at), at < 0 and "before" or "past") or "never at"))
    -- before the edit another fix was active at index 3, made so 20 nm west of where the 747 is
    at = direct_leg_switch(function(env, r, lat, lon)
        local before = {}
        for i = 1, #r do before[i] = r[i] end
        before[3] = E("OTHER", probe.movePoint(r[3][5], r[3][6], 3, 270))
        for i = 1, #before do before[i][10] = (i == 3) end
        env.simDR_latitude, env.simDR_longitude = probe.movePoint(lat, lon, 20, 270)
        env.simDR_ground_track_true = 0
        env.B747_getCurrentWayPoint_function(before)
    end)
    check(at ~= nil and math.abs(at) <= 0.5, string.format(
        "the active fix replaced at its index (a route edit) on a leg flown direct, passed 10 nm off: sequenced %s the wayline of the leg from the edit (0.5)",
        at and string.format("%.2f nm %s", math.abs(at), at < 0 and "before" or "past") or "never at"))
end
-- [P15] LNAV pushed 1 nm before a +165 deg fix at 250 kt after HDG SEL flew on along the leg to it, 0.3-2 nm
-- outside the turn, past where the turn's path starts (9.3 nm before the fix): engaged at once, the turn passed abeam
-- as before P15 (217-241 deg of turning, no bank reversal) rather than round the path from there (514-595 deg, 3-4
-- reversals), and onto the next leg.
for _, off in ipairs({-2, -1, -0.3}) do
    local lat0, lon0 = 50, -10
    local start_lat, start_lon = probe.movePoint(lat0, lon0, 20, 0)
    local fix_lat, fix_lon = probe.movePoint(start_lat, start_lon, 30, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 0)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, 165)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 40, 165)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", start_lat, start_lon), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon),
        E("DEST", far_lat + 3, far_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(next_lat, next_lon, 15, 180)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, math.abs(off), off < 0 and 270 or 90)
    out = fly({route = route, index = 4, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 14 / 250 * 3600 + 420, arm_at_s = 14 / 250 * 3600})
    local reversals, last_sign = 0, 0
    for _, q in ipairs(out.track) do
        if math.abs(q.bank) > 5 then
            local sign = q.bank > 0 and 1 or -1
            if last_sign ~= 0 and sign ~= last_sign then reversals = reversals + 1 end
            last_sign = sign
        end
    end
    local last = out.track[#out.track]
    local final = math.abs(afds.signed_cross_track_nm(next_lat, next_lon, after_lat, after_lon, last.lat, last.lon,
        probe.getDistance, probe.getHeading))
    local name = string.format("LNAV pushed 1 nm before a +165 deg fix at 250 kt, %.1f nm outside the turn", -off)
    check(out.engaged ~= nil and out.engaged.t - out.pushed.t <= 0.1, name..": engaged at once")
    check(out.turned <= 260 and reversals <= 1, string.format(
        "%s: passed abeam, %.0f deg of turning (260) and %d bank reversals (1)", name, out.turned, reversals))
    check(final <= 0.2 and fixes_in_order(out, route, 4, 4), string.format(
        "%s: NEXT sequenced, %.2f nm off the leg after it at the end (0.2)", name, final))
end
-- [review 15] A turn of more than 150 deg is decided once, as the 747 comes to where its path starts: flown by its path
-- if LNAV is engaged then, the 747 on the leg into it (within 2 nm, its track within 90 deg of the leg), the fix before
-- flown by and the path fitting on its legs; else passed abeam as before. The 747's place on the path only moves on,
-- and the FMC sequences the fix where the path crosses the turn's bisector. The routes are at 250 kt, +170 deg unless
-- said, the turn starting 9.3 nm before the fix.
local function capped_route(turn, into_nm, out_nm, next_turn, before_kind)
    local lat0, lon0 = 50, -10
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, into_nm, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, out_nm, turn % 360)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, (turn + (next_turn or 0)) % 360)
    local far_lat, far_lon = probe.movePoint(after_lat, after_lon, 40, (turn + (next_turn or 0)) % 360)
    local r = {E("ORIG", lat0 - 1, lon0, 0, 1), E(before_kind or "START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon), E("FAR", far_lat, far_lon),
        E("DEST", far_lat - 3, far_lon, 0, 1)}
    return r, fix_lat, fix_lon
end
local function fix_switch_nm(o)
    for _, sw in ipairs(o.switches) do if sw.from == 3 then return sw.nm end end
end
-- [review 17] A turn of 150 to about 159 deg has no straight line between its arcs (the first arc closes on the
-- outbound leg at less than 45 deg): past the first arc's end the straight line of no length and that end were as near,
-- the first arc was kept and the aim stood still; the 747 flew over it and circled (+-150.5 deg at 250 kt: 1348-1687
-- deg of turning, NEXT never reached; a review). +150.5, +153 and -158 deg at 250 kt, LNAV engaged on the leg 30 nm
-- before the fix: within 700 s FIX sequenced, at most 300 deg of turning and on the leg after it within 0.5 nm.
for _, turn in ipairs({150.5, 153, -158}) do
    route = capped_route(turn, 60, 40)
    local s_lat, s_lon = probe.movePoint(route[3][5], route[3][6], 30, 180)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 700})
    local last = out.track[#out.track]
    local off = math.abs(afds.signed_cross_track_nm(route[3][5], route[3][6], route[4][5], route[4][6], last.lat,
        last.lon, probe.getDistance, probe.getHeading))
    check(fix_switch_nm(out) ~= nil and out.turned <= 300 and off <= 0.5, string.format(
        "%+.1f deg at 250 kt, LNAV on the leg: FIX sequenced (%s), %.0f deg of turning (300), %.2f nm off the leg after it (0.5)",
        turn, tostring(fix_switch_nm(out) ~= nil), out.turned, off))
end
-- LNAV armed 1.5 nm inside the leg into a +170 deg fix 14 nm before it, and into a +174 deg one 20 nm before it: the
-- fix sequenced where the path crosses its bisector, 7.6 and 8.0 nm before it, not at once (inside the leg the 747 was
-- taken for one on the path's outbound side past the bisector: 14.1 and 20.1 nm before the fix; a review).
for _, c in ipairs({{170, 14}, {174, 20}}) do
    route = capped_route(c[1], 60, 40)
    local s_lat, s_lon = probe.movePoint(route[3][5], route[3][6], c[2], 180)
    s_lat, s_lon = probe.movePoint(s_lat, s_lon, 1.5, 90)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 600, armed = true})
    local at = fix_switch_nm(out)
    check(at ~= nil and at >= 6 and at <= 9, string.format(
        "LNAV armed 1.5 nm inside the leg into a +%d deg fix %d nm before it: the fix sequenced %s nm before it (6-9)",
        c[1], c[2], at and string.format("%.1f", at) or "never"))
end
-- The decision once: +170 deg with NEXT 17.6 nm on and +90 deg there, the path's fit on that leg at 250.4 kt, the TAS
-- 250 +-1.5 kt every 20 s: one decision, the bank reversing beyond 10 deg only where the path does (into the second arc,
-- into NEXT's turn); decided every frame it flipped 20 times, the bank swinging +19.8, -6.0, +17.5, -9.4 deg (a
-- review). The speed's own swing leaves a few rolls of 5-6 deg.
do
    route = capped_route(170, 60, 17.6, 90)
    local s_lat, s_lon = probe.movePoint(route[3][5], route[3][6], 20, 180)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 900, tas_fn = function(t) return 250 + 1.5 * math.sin(2 * math.pi * t / 20) end})
    local reversals, sign = 0, 0
    for _, q in ipairs(out.track) do
        if math.abs(q.bank) > 10 then
            local sg = q.bank > 0 and 1 or -1
            if sign ~= 0 and sg ~= sign then reversals = reversals + 1 end
            sign = sg
        end
    end
    check(reversals <= 2 and fixes_in_order(out, route, 3, 4), string.format(
        "+170 deg, its fit at the TAS of 250 +-1.5 kt: decided once, %d bank reversals beyond 10 deg (2), the fixes in order",
        reversals))
end
-- After a leg LNAV steers as before (here the leg to PREV from VECTORS, then PREV -> FIX 25 nm), in 40 kt from 090: the
-- turn at FIX passed abeam, FIX passed within 1 nm (sequenced at the 150 deg turn's lead it was 7.5 nm before FIX and
-- its path given up, closest 5.3 nm; a review).
do
    local lat0, lon0 = 50, -10
    local prev_lat, prev_lon = probe.movePoint(lat0, lon0, 20, 0)
    local fix_lat, fix_lon = probe.movePoint(prev_lat, prev_lon, 25, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 170)
    local after_lat, after_lon = probe.movePoint(next_lat, next_lon, 40, 170)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("PREV", prev_lat, prev_lon),
        E("FIX", fix_lat, fix_lon), E("NEXT", next_lat, next_lon), E("AFTER", after_lat, after_lon),
        E("DEST", after_lat - 3, after_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(prev_lat, prev_lon, 5, 180)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 900, wind_from_deg = 90, wind_kt = 40})
    local closest = math.huge
    for _, q in ipairs(out.track) do closest = math.min(closest, probe.getDistance(fix_lat, fix_lon, q.lat, q.lon)) end
    local at = nil
    for _, sw in ipairs(out.switches) do if sw.from == 4 then at = sw.nm end end
    check(closest <= 1 and at ~= nil and at <= 1.5, string.format(
        "+170 deg after a leg LNAV steers as before: FIX passed %.1f nm off, sequenced %s nm from it (passed abeam)",
        closest, at and string.format("%.1f", at) or "never"))
end
-- Decided again when the 747 is back on the leg before the path's start: on the leg 3 nm before FIX flying away with
-- LNAV off (passed abeam: past the start, LNAV not engaged), turned back and onto the leg with LNAV from 35 nm before
-- FIX: the turn flown, FIX sequenced 6-9 nm before it (latched once, it was passed abeam for good; a review).
do
    route = capped_route(170, 60, 40)
    local s_lat, s_lon = probe.movePoint(route[3][5], route[3][6], 3, 180)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 180, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 1500, arm_at_s = 1e9,
        hook = function(env, t)
            if t >= 460 and t < 460 + 0.05 then env.simDR_autopilot_heading_deg = 0 end
            if t >= 560 and t < 560 + 0.05 then
                env.simDR_autopilot_heading_deg = 330
                env.B747DR_ap_lnav_state = 1
            end
        end})
    local at = fix_switch_nm(out)
    check(out.engaged ~= nil and at ~= nil and at >= 6 and at <= 9, string.format(
        "+170 deg passed abeam once, back on the leg before its start with LNAV: flown, FIX sequenced %s nm before it (6-9)",
        at and string.format("%.1f", at) or "never"))
end
-- VNAV's held fix let go once the 747 is past the turn's bisector also for +174.6 deg: within 5 s of the sequencing
-- (taken abeam the fix on the inbound course from 174.3 deg it was kept 153-155 s, let go 13 nm from FIX; a review).
do
    route = capped_route(174.6, 60, 40)
    local s_lat, s_lon = probe.movePoint(route[3][5], route[3][6], 20, 180)
    local held_until = nil
    local sequenced = nil
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 700,
        hook = function(env, t)
            if env.B747DR_fmscurrentIndex == 4 and sequenced == nil then sequenced = t end
            if sequenced and env.B747DR_vnav_hold_index == 3 then held_until = t end
        end})
    check(sequenced ~= nil and (held_until == nil or held_until - sequenced <= 5), string.format(
        "+174.6 deg: VNAV's held fix let go within 5 s of FIX's sequencing (%s s)",
        sequenced and string.format("%.0f", (held_until or sequenced) - sequenced) or "never sequenced"))
end
-- the leg flown direct (from VECTORS) or the 747's own direct-to: engaged at once as before (a leg from where the
-- 747 is); on the runway armed, engaged above 50 ft
do
    local lat0, lon0 = 52, -12
    local fix_lat, fix_lon = probe.movePoint(lat0, lon0, 40, 0)
    local next_lat, next_lon = probe.movePoint(fix_lat, fix_lon, 40, 0)
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("VECTORS", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("DEST", next_lat + 1, next_lon, 0, 1)}
    local s_lat, s_lon = probe.movePoint(lat0, lon0, 10, 90)
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 2, armed = true})
    check(out.engaged ~= nil and out.engaged.t <= 0.1, "LNAV pushed 10 nm off the line from VECTORS (flown direct): engaged at once")
    route = {E("ORIG", lat0 - 1, lon0, 0, 1), E("START", lat0, lon0), E("FIX", fix_lat, fix_lon),
        E("NEXT", next_lat, next_lon), E("DEST", next_lat + 1, next_lon, 0, 1)}
    out = fly({route = route, index = 3, start = {s_lat, s_lon}, heading = 0, tas_kt = 250, alt_ft = 5000,
        loop = "low", seconds = 2, armed = true, setup = function(env) env.B747DR_ap_lnav_xtk_target = -100 end})
    check(out.engaged ~= nil and out.engaged.t <= 0.1, "LNAV pushed 10 nm off the leg after the 747's own DIRECT TO: engaged at once")
    out = fly({route = route, index = 3, start = {lat0, lon0}, heading = 0, tas_kt = 160, alt_ft = 0, vs_fpm = 1500,
        alt_max_ft = 3000, loop = "low", seconds = 10, armed = true})
    check(out.engaged ~= nil and out.engaged.t >= 1.5 and out.engaged.t <= 2.5, string.format(
        "LNAV armed on the runway: engaged above 50 ft (%s)", out.engaged and string.format("at %.1f s", out.engaged.t) or "never"))
    -- armed on the ground 1 nm before the leg's start (a runway end fix ahead): engaged above 50 ft as before
    local r_lat, r_lon = probe.movePoint(lat0, lon0, 1, 180)
    out = fly({route = route, index = 3, start = {r_lat, r_lon}, heading = 0, tas_kt = 160, alt_ft = 0, vs_fpm = 1500,
        alt_max_ft = 3000, loop = "low", seconds = 10, armed = true, ground = true})
    check(out.engaged ~= nil and out.engaged.t >= 1.5 and out.engaged.t <= 2.5, string.format(
        "LNAV armed on the ground 1 nm before the leg's start: engaged above 50 ft (%s)",
        out.engaged and string.format("at %.1f s", out.engaged.t) or "never"))
end

print("LNAV turn anticipation tests passed: "..checks)
