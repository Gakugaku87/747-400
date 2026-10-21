-- Pure AFDS calculations shared by the autopilot implementation and tests.
-- Keep this file compatible with the Lua 5.1 runtime embedded in xtlua.

local afds = {}

local KNOT_TO_MPS = 0.514444
local METERS_PER_NM = 1852.0
local GRAVITY_MPS2 = 9.80665

afds.VNAV_ENERGY_PATH_ENTER_FT = 150
afds.VNAV_ENERGY_PATH_EXIT_FT = 75
afds.VNAV_ENERGY_SPEED_ENTER_KTS = 5
afds.VNAV_ENERGY_SPEED_EXIT_KTS = 2
-- [B-13] thrust for a slow speed on or below the path ends this far above the target (vnav_energy_guidance)
afds.VNAV_ENERGY_THRUST_RELEASE_KTS = 2
afds.VNAV_ENERGY_MAX_DESCENT_FPM = -3500
afds.VNAV_ENERGY_MIN_DESCENT_FPM = 0
afds.VNAV_ENERGY_DESCENT_RATE_LIMIT_FPM_PER_SEC = 400
afds.VNAV_ENERGY_SHALLOW_RATE_LIMIT_FPM_PER_SEC = 600
afds.VNAV_ENERGY_PROTECTION_MARGIN_KTS = 15
afds.VNAV_ENERGY_PROTECTION_RELEASE_KTS = 5
afds.VNAV_ENERGY_DRAG_PATH_ERROR_FT = 1000

afds.VNAV_ENERGY_STATE_INACTIVE = 0
afds.VNAV_ENERGY_STATE_ABOVE_ABOVE = 1
afds.VNAV_ENERGY_STATE_ABOVE_BELOW = 2
afds.VNAV_ENERGY_STATE_BELOW_BELOW = 3
afds.VNAV_ENERGY_STATE_BELOW_ABOVE = 4
afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED = 5
afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED = 6
afds.VNAV_ENERGY_STATE_ON_PATH_BELOW = 7
afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE = 8
afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED = 9

afds.VNAV_ENERGY_THRUST_NORMAL = 0
afds.VNAV_ENERGY_THRUST_IDLE = 1
afds.VNAV_ENERGY_THRUST_ALLOW = 2

afds.VNAV_ENERGY_THRUST_REASON_NONE = 0
afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION = 1
afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED = 2
afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED = 3
afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED = 4

function afds.clamp(value, minimum, maximum)
    if value < minimum then return minimum end
    if value > maximum then return maximum end
    return value
end

function afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if type(speed_kts) ~= "number" or speed_kts <= 0 then return nil end
    if type(bank_angle_deg) ~= "number" or bank_angle_deg <= 0 or bank_angle_deg >= 89 then return nil end

    local speed_mps = speed_kts * KNOT_TO_MPS
    local radius_m = (speed_mps * speed_mps) / (GRAVITY_MPS2 * math.tan(math.rad(bank_angle_deg)))
    if radius_m <= 0 or radius_m ~= radius_m then return nil end
    return radius_m / METERS_PER_NM
end

function afds.turn_anticipation_nm(speed_kts, bank_angle_deg, turn_angle_deg, minimum_nm, maximum_nm)
    if type(turn_angle_deg) ~= "number" or turn_angle_deg < 0 or turn_angle_deg > 180 then return nil, nil end

    local radius_nm = afds.turn_radius_nm(speed_kts, bank_angle_deg)
    if radius_nm == nil then return nil, nil end
    if turn_angle_deg <= 1 then return 0, radius_nm end
    if turn_angle_deg >= 175 then return nil, radius_nm end

    local anticipation_nm = radius_nm * math.tan(math.rad(turn_angle_deg * 0.5))
    if anticipation_nm ~= anticipation_nm or anticipation_nm < 0 then return nil, radius_nm end
    return afds.clamp(anticipation_nm, minimum_nm or 0, maximum_nm or anticipation_nm), radius_nm
end

-- LNAV fly-by turns. LNAV steers X-Plane's HDG SEL, which turns at its bank
-- limit; the 747's flight director rolls into it at the roll rate limit of the
-- hydraulics (ROLL_FILTER_MAX_SLEW_DEG_PER_SEC, 3 deg/s outside the approach).
afds.LNAV_ROLL_RATE_DEG_PER_SEC = 3.0
-- [P15] A fly-by turn starts no farther before its fix than a turn of LNAV_FLYBY_MAX_TURN_DEG: a larger course
-- change starts there (afds.lnav_capped_turn); from LNAV_FLYBY_REVERSAL_DEG a reversal, no fly-by: the next leg once
-- abeam the fix.
afds.LNAV_FLYBY_MAX_TURN_DEG = 150
afds.LNAV_FLYBY_REVERSAL_DEG = 175
-- A wind estimate beyond this is no wind (XTLua gives 0 for a first read).
afds.LNAV_MAX_WIND_KTS = 300
-- [i-1b] LNAV's path guidance aims this long of ground speed along the path round its arcs, within these
-- distances (a short look-ahead follows them: 40 s cut them by 0.5 to 0.9 nm in the closed-loop model), and
-- on its legs this part of the turn radius (rolling out onto a leg takes room that grows with it).
afds.LNAV_PATH_LOOKAHEAD_S = 12
afds.LNAV_PATH_MIN_LOOKAHEAD_NM = 0.4
afds.LNAV_PATH_MAX_LOOKAHEAD_NM = 6
afds.LNAV_PATH_CAPTURE_RADII = 0.4

-- Distance before a fly-by fix at which the turn onto the next leg starts:
-- where a turn at the bank limit, rolled in at roll_rate_dps (half the roll-in
-- before the turn proper) and drifting with the wind, ends on the outbound
-- leg. Without wind that is R tan(turn / 2), R = TAS^2 / (g tan bank). Courses
-- are true, the inbound one at the fix; the wind is the air's motion (kt east
-- and north). 0 without a turn, a speed or a bank, and from
-- LNAV_FLYBY_REVERSAL_DEG (sequenced abeam the fix, as over a fly-over fix:
-- with no lead at all the fix stayed active once passed, and LNAV flew back to
-- it); beyond LNAV_FLYBY_MAX_TURN_DEG that many degrees' (the turn starts
-- there: afds.lnav_capped_turn).
function afds.lnav_turn_anticipation_nm(tas_kts, wind_east_kts, wind_north_kts, bank_deg, course_in_deg,
        course_out_deg, roll_rate_dps, ground_speed_kts)
    if type(tas_kts) ~= "number" or tas_kts <= 0 or type(bank_deg) ~= "number" or bank_deg <= 0 or bank_deg >= 89
        or type(course_in_deg) ~= "number" or type(course_out_deg) ~= "number" then
        return 0
    end
    local course_change = (course_out_deg - course_in_deg + 540) % 360 - 180
    if math.abs(course_change) < 1 then return 0 end
    if math.abs(course_change) >= afds.LNAV_FLYBY_REVERSAL_DEG then return 0 end
    local side = course_change > 0 and 1 or -1
    if math.abs(course_change) > afds.LNAV_FLYBY_MAX_TURN_DEG then
        course_out_deg = course_in_deg + side * afds.LNAV_FLYBY_MAX_TURN_DEG
    end
    local speed = tas_kts * KNOT_TO_MPS
    local wind_east, wind_north = (tonumber(wind_east_kts) or 0) * KNOT_TO_MPS, (tonumber(wind_north_kts) or 0) * KNOT_TO_MPS
    if math.sqrt(wind_east * wind_east + wind_north * wind_north) > afds.LNAV_MAX_WIND_KTS * KNOT_TO_MPS then
        wind_east, wind_north = 0, 0
    end
    -- the heading that holds a course in this wind
    local function heading_for(course_deg)
        local course = math.rad(course_deg)
        local cross = (wind_east * math.cos(course) - wind_north * math.sin(course)) / speed
        return course_deg + math.deg(math.asin(afds.clamp(-cross, -0.9, 0.9)))
    end
    local heading_in = heading_for(course_in_deg)
    local heading_change = (heading_for(course_out_deg) - heading_in + 540) % 360 - 180
    if heading_change * side <= 0 then heading_change = heading_change + 360 * side end
    -- the turn: an arc in the air, the wind's drift over its duration
    local turn_rate = side * GRAVITY_MPS2 * math.tan(math.rad(bank_deg)) / speed
    local duration = math.rad(heading_change) / turn_rate
    local h1, h2 = math.rad(heading_in), math.rad(heading_in + heading_change)
    local east = speed / turn_rate * (math.cos(h1) - math.cos(h2)) + wind_east * duration
    local north = speed / turn_rate * (math.sin(h2) - math.sin(h1)) + wind_north * duration
    -- that displacement is the distance before the fix along the inbound leg
    -- plus the distance after it along the outbound one
    local in_east, in_north = math.sin(math.rad(course_in_deg)), math.cos(math.rad(course_in_deg))
    local out_east, out_north = math.sin(math.rad(course_out_deg)), math.cos(math.rad(course_out_deg))
    local determinant = in_east * out_north - in_north * out_east
    if math.abs(determinant) < 1e-6 then return 0 end
    local before_m = (east * out_north - north * out_east) / determinant
    local roll_in_nm = 0
    if type(roll_rate_dps) == "number" and roll_rate_dps > 0 then
        roll_in_nm = (tonumber(ground_speed_kts) or tas_kts) / 3600 * (bank_deg / roll_rate_dps) / 2
    end
    return math.max(0, before_m / METERS_PER_NM + roll_in_nm)
end

function afds.signed_cross_track_nm(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon,
        aircraft_lat, aircraft_lon, distance_func, heading_func)
    if type(distance_func) ~= "function" or type(heading_func) ~= "function" then return nil end
    if type(leg_start_lat) ~= "number" or type(leg_start_lon) ~= "number"
        or type(leg_end_lat) ~= "number" or type(leg_end_lon) ~= "number"
        or type(aircraft_lat) ~= "number" or type(aircraft_lon) ~= "number" then
        return nil
    end

    local distance_nm = distance_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    local leg_heading = heading_func(leg_start_lat, leg_start_lon, leg_end_lat, leg_end_lon)
    local aircraft_heading = heading_func(leg_start_lat, leg_start_lon, aircraft_lat, aircraft_lon)
    if type(distance_nm) ~= "number" or type(leg_heading) ~= "number" or type(aircraft_heading) ~= "number" then
        return nil
    end

    local earth_radius_nm = 3440.065
    local angular_distance = distance_nm / earth_radius_nm
    local cross_track = math.asin(math.sin(angular_distance)
        * math.sin(math.rad(aircraft_heading - leg_heading))) * earth_radius_nm
    if cross_track ~= cross_track then return nil end
    return cross_track
end

-- Whether the aircraft, east_nm and north_nm from a fix, is past the bisector
-- of the turn there from in_course_deg to out_course_deg (true courses): past
-- it once its position along the mean of the two courses is not negative. For
-- a straight fix that is abeam it; for a reversal (LNAV_FLYBY_REVERSAL_DEG or
-- more), where the mean vanishes, it is abeam it on the inbound course. [P15]
-- Judged by the mean's size (from 174.3 deg) a capped turn's path, which never
-- passes abeam its fix, kept VNAV's held fix until 13 nm past it (a review).
function afds.past_turn_bisector(east_nm, north_nm, in_course_deg, out_course_deg)
    if type(east_nm) ~= "number" or type(north_nm) ~= "number"
        or type(in_course_deg) ~= "number" or type(out_course_deg) ~= "number" then
        return nil
    end
    local in_east, in_north = math.sin(math.rad(in_course_deg)), math.cos(math.rad(in_course_deg))
    local mean_east = in_east + math.sin(math.rad(out_course_deg))
    local mean_north = in_north + math.cos(math.rad(out_course_deg))
    local turn = (out_course_deg - in_course_deg + 540) % 360 - 180
    if math.abs(turn) >= afds.LNAV_FLYBY_REVERSAL_DEG then
        mean_east, mean_north = in_east, in_north
    end
    return east_nm * mean_east + north_nm * mean_north >= 0
end

-- [i-1b] The ground speed a fly-by arc from course_in_deg to course_out_deg
-- (true) is drawn for: the TAS plus the wind (the air's motion, kt east and
-- north) along the track, the highest of the tracks across the turn, so that
-- the 747 can follow the arc all round at the bank limit without making it
-- bigger than that (with the wind's whole speed a crosswind turn cut far
-- inside: BEDRA passed 5.9 nm from it, 3.0 before).
function afds.lnav_turn_ground_speed_kts(tas_kts, wind_east_kts, wind_north_kts, course_in_deg, course_out_deg)
    local turn = (course_out_deg - course_in_deg + 540) % 360 - 180
    local function along(course_deg)
        return wind_east_kts * math.sin(math.rad(course_deg)) + wind_north_kts * math.cos(math.rad(course_deg))
    end
    local best = math.max(along(course_in_deg), along(course_out_deg))
    local speed = math.sqrt(wind_east_kts * wind_east_kts + wind_north_kts * wind_north_kts)
    if speed > 0 then
        -- the wind's own direction, if the turn sweeps through it
        local toward = math.deg(math.atan2(wind_east_kts, wind_north_kts))
        local swept = ((toward - course_in_deg) * (turn < 0 and -1 or 1)) % 360
        if swept <= math.abs(turn) then best = speed end
    end
    return tas_kts + best
end

-- [P15] A fly-by turn of more than LNAV_FLYBY_MAX_TURN_DEG (and less than LNAV_FLYBY_REVERSAL_DEG) of turn_deg
-- (+ right) at radius_nm: it starts where a turn of LNAV_FLYBY_MAX_TURN_DEG would, R tan(75) before the fix (its own
-- tangent arc would start R tan(turn / 2) before it: 11.4 R for 170 deg, 110 nm at cruise). Round an arc of R from
-- there the 747 reaches the outbound course outside the outbound leg by R (1 - cos turn) - R tan(75) sin turn
-- (0.66 R for 160 deg, 1.34 R for 170), so the path turns on by up to LNAV_PATH_CAPPED_INTERCEPT_DEG, closes on the
-- leg on a straight line at that angle and rolls out onto it, an arc of R the other way; just past
-- LNAV_FLYBY_MAX_TURN_DEG, with less to make up, it turns on just enough and back at once. Returns before_nm (where
-- the turn starts before the fix), outside_nm, beta_deg (how far on), straight_nm and after_nm (where the path joins
-- the outbound leg after the fix); nil for other turns.
afds.LNAV_PATH_CAPPED_INTERCEPT_DEG = 45
function afds.lnav_capped_turn(turn_deg, radius_nm)
    if type(turn_deg) ~= "number" or type(radius_nm) ~= "number" or radius_nm <= 0 then return nil end
    local turn = math.abs(turn_deg)
    if turn <= afds.LNAV_FLYBY_MAX_TURN_DEG or turn >= afds.LNAV_FLYBY_REVERSAL_DEG then return nil end
    local th = math.rad(turn)
    local before = radius_nm * math.tan(math.rad(afds.LNAV_FLYBY_MAX_TURN_DEG) / 2)
    local outside = radius_nm * (1 - math.cos(th)) - before * math.sin(th)
    local max_beta = math.rad(afds.LNAV_PATH_CAPPED_INTERCEPT_DEG)
    local beta, straight = max_beta, 0
    if outside >= 2 * radius_nm * (1 - math.cos(max_beta)) then
        straight = (outside - 2 * radius_nm * (1 - math.cos(max_beta))) / math.sin(max_beta)
    else
        beta = math.acos(afds.clamp(1 - outside / (2 * radius_nm), -1, 1))
    end
    -- in the frame of an inbound course of 000 turning right: the first arc round (R, -before) to beta past the
    -- outbound course, the straight line, the second arc's end on the outbound leg
    local h1 = th + beta
    local e1, n1 = radius_nm - radius_nm * math.cos(h1), -before + radius_nm * math.sin(h1)
    local e2, n2 = e1 + straight * math.sin(h1), n1 + straight * math.cos(h1)
    local c2e, c2n = e2 - radius_nm * math.cos(h1), n2 + radius_nm * math.sin(h1)
    local e3, n3 = c2e + radius_nm * math.cos(th), c2n - radius_nm * math.sin(th)
    return {before_nm = before, outside_nm = outside, beta_deg = math.deg(beta), straight_nm = straight,
        after_nm = e3 * math.sin(th) + n3 * math.cos(th)}
end

-- How far before a fly-by fix LNAV's path leaves the inbound leg and how far after it it joins the outbound leg,
-- for a turn of turn_deg (+ right) at radius_nm: R tan(turn / 2) both up to LNAV_FLYBY_MAX_TURN_DEG, beyond it
-- afds.lnav_capped_turn's; 0, 0 from LNAV_FLYBY_REVERSAL_DEG (no fly-by).
function afds.lnav_turn_extent_nm(turn_deg, radius_nm)
    local turn = math.abs(turn_deg)
    if turn >= afds.LNAV_FLYBY_REVERSAL_DEG then return 0, 0 end
    local capped = afds.lnav_capped_turn(turn_deg, radius_nm)
    if capped then return capped.before_nm, capped.after_nm end
    local tangent = radius_nm * math.tan(math.rad(turn) / 2)
    return tangent, tangent
end

-- The path of afds.lnav_capped_turn at a fix (east_nm, north_nm the aircraft's position from it): its elements,
-- lines {e, n (start), h (course), len (nil: on and on), before (the inbound leg, up to its end)} and arcs {ce, cn
-- (centre), side (+1 right), h0 (the course at its start), sweep (deg)}, as afds.lnav_path_at returns it. The
-- aircraft is on the element nearest it of min_element (the caller's last) and the next, of all without one: near
-- such a fix the inbound leg and the outbound side run close (2.3 nm apart 13 nm before a 170 deg fix at 250 kt), and
-- the nearest of all took the one for the other. It is past the bisector once on the path as far as where the first arc
-- crosses the turn's bisector line (bisector_along_nm): only (180 - turn) / 2 off the inbound leg (5 deg for 170),
-- that line put the aircraft 0.9 nm inside the inbound leg 10 nm before the fix past it (a review).
local function capped_path_at(east_nm, north_nm, course_in_deg, course_out_deg, radius_nm, lookahead_nm, capture_nm,
        min_element)
    local turn = (course_out_deg - course_in_deg + 540) % 360 - 180
    local capped = afds.lnav_capped_turn(turn, radius_nm)
    local side = turn < 0 and -1 or 1
    local R = radius_nm
    local function unit(h) return math.sin(math.rad(h)), math.cos(math.rad(h)) end
    local function right(h) return math.cos(math.rad(h)), -math.sin(math.rad(h)) end
    local in_east, in_north = unit(course_in_deg)
    local se, sn = -capped.before_nm * in_east, -capped.before_nm * in_north
    local re, rn = right(course_in_deg)
    local c1e, c1n = se + side * R * re, sn + side * R * rn
    local h1 = course_in_deg + side * (math.abs(turn) + capped.beta_deg)
    local r1e, r1n = right(h1)
    local e1e, e1n = c1e - side * R * r1e, c1n - side * R * r1n
    local d1e, d1n = unit(h1)
    local e2e, e2n = e1e + capped.straight_nm * d1e, e1n + capped.straight_nm * d1n
    local c2e, c2n = e2e - side * R * r1e, e2n - side * R * r1n
    local roe, ron = right(course_out_deg)
    local e3e, e3n = c2e + side * R * roe, c2n + side * R * ron
    local elements = {
        {name = "in", e = se, n = sn, h = course_in_deg, before = true},
        {name = "arc", ce = c1e, cn = c1n, side = side, h0 = course_in_deg, sweep = math.abs(turn) + capped.beta_deg},
        {name = "straight", e = e1e, n = e1n, h = h1, len = capped.straight_nm},
        {name = "arc", ce = c2e, cn = c2n, side = -side, h0 = h1, sweep = capped.beta_deg},
        {name = "out", e = e3e, n = e3n, h = course_out_deg}}
    local function length(el)
        if el.ce then return R * math.rad(el.sweep) end
        return el.len or math.huge
    end
    local function point(el, a)
        if el.ce then
            local h = math.rad(el.h0 + el.side * math.deg(a / R))
            return el.ce - el.side * R * math.cos(h), el.cn + el.side * R * math.sin(h)
        end
        local ue, un = unit(el.h)
        return el.e + a * ue, el.n + a * un
    end
    -- each element's view of the aircraft: the distance to it, where along it, the signed cross-track, the course
    local function view(el)
        if el.ce then
            local de, dn = east_nm - el.ce, north_nm - el.cn
            local course = math.deg(math.atan2(de, dn)) + el.side * 90
            local angle = (el.side * (course - el.h0)) % 360
            if angle > el.sweep then angle = (angle - el.sweep < 360 - angle) and el.sweep or 0 end
            local pe, pn = point(el, R * math.rad(angle))
            return math.sqrt((east_nm - pe) ^ 2 + (north_nm - pn) ^ 2), R * math.rad(angle),
                el.side * (R - math.sqrt(de * de + dn * dn)), el.h0 + el.side * angle
        end
        local ue, un = unit(el.h)
        local a = (east_nm - el.e) * ue + (north_nm - el.n) * un
        local x = (east_nm - el.e) * un - (north_nm - el.n) * ue
        local along = el.before and math.min(a, 0) or math.max(0, math.min(a, el.len or a))
        local pe, pn = point(el, along)
        return math.sqrt((east_nm - pe) ^ 2 + (north_nm - pn) ^ 2), along, x, el.h
    end
    local first, last = 1, #elements
    if tonumber(min_element) then
        first = math.max(1, math.min(#elements, math.floor(tonumber(min_element))))
        last = first + 1
    end
    -- as near to two elements, the later: below about 159 deg the straight line has no length, and past the first
    -- arc's end it and that end were as near; keeping the arc, the aim stood still and the 747 circled over it (a
    -- review). As near within 1e-9 nm: the two distances are worked out two ways, and rounding kept the arc in head
    -- and tail winds (595 deg of turning: a review)
    local best, start, nearest = math.huge, 0, nil
    for i, el in ipairs(elements) do
        if i >= first and i <= last then
            local d, a, x, course = view(el)
            if d <= best + 1e-9 then
                best, nearest = d, {i = i, along = (i == 1) and a or start + a, xtk = x, course = course}
            end
        end
        if i > 1 then start = start + length(el) end
    end
    local function point_along(a)
        if a <= 0 then return point(elements[1], a) end
        local at = 0
        for i = 2, #elements do
            local el = elements[i]
            if a <= at + length(el) or i == #elements then return point(el, a - at) end
            at = at + length(el)
        end
    end
    local off = math.abs(nearest.xtk)
    local capture = math.max(lookahead_nm, tonumber(capture_nm) or lookahead_nm)
    local aim_along = nearest.along + math.max(lookahead_nm, off)
    if nearest.i == #elements then
        aim_along = nearest.along + math.max(capture, off)
    elseif nearest.i == 1 then
        aim_along = math.max(aim_along, math.min(nearest.along + math.max(capture, off), 0))
    end
    local aim_east, aim_north = point_along(aim_along)
    -- where the first arc crosses the turn's bisector line (through the fix, along the mean of the two courses)
    local out_east, out_north = unit(course_out_deg)
    local mean_east, mean_north = in_east + out_east, in_north + out_north
    local function inbound_side(along)
        local pe, pn = point(elements[2], along)
        return pe * mean_east + pn * mean_north < 0
    end
    local lo, hi = 0, length(elements[2])
    if inbound_side(hi) then
        lo = hi
    else
        for _ = 1, 40 do
            local mid = (lo + hi) / 2
            if inbound_side(mid) then lo = mid else hi = mid end
        end
    end
    local past = nearest.i > 2 or (nearest.i == 2 and nearest.along >= lo)
    return {element = elements[nearest.i].name, element_index = nearest.i, xtk_nm = nearest.xtk,
        course_deg = nearest.course % 360, along_nm = nearest.along, past_bisector = past, bisector_along_nm = lo,
        arc_start_nm = capped.before_nm, aim_east_nm = aim_east, aim_north_nm = aim_north}
end

-- [i-1b] The lateral path at a fly-by fix: the inbound leg on course_in_deg,
-- the arc of radius_nm tangent to it and to the outbound leg on course_out_deg
-- (true courses), R tan(turn / 2) before and after the fix, and the outbound
-- leg; east_nm and north_nm are the aircraft's position from the fix. Returns
-- the element the aircraft is abeam ("in", "arc", "out"), whether it is past
-- the turn's bisector (as afds.past_turn_bisector, where the FMC sequences the
-- turn), its signed cross-track from the path (+ right of it; from the arc while abeam it), the
-- path's course there, its distance along the path from the arc's start
-- (negative on the inbound leg), the arc's start before the fix, and the point
-- a look-ahead further along the path that a pure-pursuit guidance aims at,
-- never nearer than the cross-track (on a leg at most 45 deg off its course).
-- On the legs the aim is capture_nm along (rolling out onto a leg takes room
-- that grows with the turn radius; the look-ahead without it), but on the
-- inbound leg it waits at the arc's start until the look-ahead reaches it (a
-- longer one starts the turn early). nil without a radius, a look-ahead or
-- courses, and from LNAV_FLYBY_REVERSAL_DEG (no fly-by); beyond
-- LNAV_FLYBY_MAX_TURN_DEG the path of afds.lnav_capped_turn (elements "in",
-- "arc", "straight", "arc", "out"; its element_index, from min_element on).
function afds.lnav_path_at(east_nm, north_nm, course_in_deg, course_out_deg, radius_nm, lookahead_nm, capture_nm,
        min_element)
    if type(east_nm) ~= "number" or type(north_nm) ~= "number" or type(course_in_deg) ~= "number"
        or type(course_out_deg) ~= "number" or type(radius_nm) ~= "number" or radius_nm <= 0
        or type(lookahead_nm) ~= "number" or lookahead_nm <= 0 then
        return nil
    end
    local turn = (course_out_deg - course_in_deg + 540) % 360 - 180
    if math.abs(turn) >= afds.LNAV_FLYBY_REVERSAL_DEG then return nil end
    if math.abs(turn) > afds.LNAV_FLYBY_MAX_TURN_DEG then
        return capped_path_at(east_nm, north_nm, course_in_deg, course_out_deg, radius_nm, lookahead_nm, capture_nm,
            min_element)
    end
    local side = turn < 0 and -1 or 1
    local in_east, in_north = math.sin(math.rad(course_in_deg)), math.cos(math.rad(course_in_deg))
    local out_east, out_north = math.sin(math.rad(course_out_deg)), math.cos(math.rad(course_out_deg))
    local tangent = radius_nm * math.tan(math.rad(math.abs(turn)) / 2)
    local start_east, start_north = -tangent * in_east, -tangent * in_north
    local end_east, end_north = tangent * out_east, tangent * out_north
    -- the centre lies R to the turn's side of the inbound leg at the arc's start
    local centre_east = start_east + side * radius_nm * in_north
    local centre_north = start_north - side * radius_nm * in_east
    local arc_nm = radius_nm * math.rad(math.abs(turn))
    local start_bearing = math.atan2(start_east - centre_east, start_north - centre_north)
    local function point_at(along_nm)
        if along_nm <= 0 then
            return start_east + along_nm * in_east, start_north + along_nm * in_north
        end
        if along_nm >= arc_nm then
            return end_east + (along_nm - arc_nm) * out_east, end_north + (along_nm - arc_nm) * out_north
        end
        local bearing = start_bearing + side * along_nm / radius_nm
        return centre_east + radius_nm * math.sin(bearing), centre_north + radius_nm * math.cos(bearing)
    end
    local before = (east_nm - start_east) * in_east + (north_nm - start_north) * in_north
    local after = (east_nm - end_east) * out_east + (north_nm - end_north) * out_north
    -- the turn's bisector (through the fix and the centre) parts the inbound leg's side from the outbound
    -- leg's: past a turn of more than 90 deg the outbound leg also lies behind the arc's start
    local inbound_side = east_nm * (in_east + out_east) + north_nm * (in_north + out_north) < 0
    local element, along, xtk, course
    if inbound_side and before <= 0 then
        element, along, course = "in", before, course_in_deg
        xtk = (east_nm - start_east) * in_north - (north_nm - start_north) * in_east
    elseif not inbound_side and after >= 0 then
        element, along, course = "out", arc_nm + after, course_out_deg
        xtk = (east_nm - end_east) * out_north - (north_nm - end_north) * out_east
    else
        local d_east, d_north = east_nm - centre_east, north_nm - centre_north
        local bearing = math.atan2(d_east, d_north)
        local angle = (side * (bearing - start_bearing) + math.pi) % (2 * math.pi) - math.pi
        element = "arc"
        along = math.max(0, math.min(arc_nm, radius_nm * angle))
        xtk = side * (radius_nm - math.sqrt(d_east * d_east + d_north * d_north))
        course = math.deg(bearing) + side * 90
    end
    local off = math.abs(xtk)
    local capture = math.max(lookahead_nm, tonumber(capture_nm) or lookahead_nm)
    local aim_along = along + math.max(lookahead_nm, off)
    if element == "out" then
        aim_along = along + math.max(capture, off)
    elseif element == "in" then
        aim_along = math.max(aim_along, math.min(along + math.max(capture, off), 0))
    end
    local aim_east, aim_north = point_at(aim_along)
    return {element = element, xtk_nm = xtk, course_deg = course % 360, along_nm = along, past_bisector = not inbound_side,
        arc_start_nm = tangent, aim_east_nm = aim_east, aim_north_nm = aim_north}
end

function afds.flap_speed_bucket(flap_ratio)
    if type(flap_ratio) ~= "number" or flap_ratio <= 0 then return 0 end
    if flap_ratio <= 0.168 then return 1 end
    if flap_ratio <= 0.34 then return 5 end
    if flap_ratio <= 0.5 then return 10 end
    if flap_ratio <= 0.668 then return 20 end
    if flap_ratio <= 0.84 then return 25 end
    return 30
end

function afds.climb_speed_key_for_state(state)
    if state == "aptres" then return "clbrestspd" end
    if state == "spcres" then return "transpd" end
    if state == "nores" then return "clbspd" end
    return nil
end

function afds.climb_speed_for_state(state, data_source)
    local key = afds.climb_speed_key_for_state(state)
    if key == nil then return nil end
    if type(data_source) == "function" then return tonumber(data_source(key)) end
    if type(data_source) == "table" then return tonumber(data_source[key]) end
    return nil
end

function afds.first_changed_value(previous, current, watched_values)
    if previous == nil or current == nil then return nil end
    for i = 1, #watched_values do
        local item = watched_values[i]
        if previous[item.key] ~= current[item.key] then
            return item.reason or item.key
        end
    end
    return nil
end

function afds.vnav_speed_change_reason(previous, current, conditions, watched_values)
    if previous == nil or current == nil then return nil end

    if conditions ~= nil and type(conditions.above) == "number" and conditions.above > 0
        and previous.pressure_alt_ft <= conditions.above and current.pressure_alt_ft > conditions.above then
        return conditions.above_reason or "crossed upper speed boundary"
    end
    if conditions ~= nil and type(conditions.below) == "number" and conditions.below > 0
        and previous.pressure_alt_ft >= conditions.below and current.pressure_alt_ft < conditions.below then
        return conditions.below_reason or "crossed lower speed boundary"
    end

    return afds.first_changed_value(previous, current, watched_values)
end

function afds.should_schedule_ias_update(timer_is_scheduled)
    return timer_is_scheduled ~= true
end

local function hysteresis_axis(value, previous_axis, enter_threshold, exit_threshold)
    value = tonumber(value) or 0
    previous_axis = tonumber(previous_axis) or 0

    if previous_axis > 0 and value >= exit_threshold then return 1 end
    if previous_axis < 0 and value <= -exit_threshold then return -1 end
    if value >= enter_threshold then return 1 end
    if value <= -enter_threshold then return -1 end
    return 0
end

function afds.vnav_energy_axes(path_error_ft, speed_error_kts, previous_path_axis, previous_speed_axis)
    return hysteresis_axis(path_error_ft, previous_path_axis,
            afds.VNAV_ENERGY_PATH_ENTER_FT, afds.VNAV_ENERGY_PATH_EXIT_FT),
        hysteresis_axis(speed_error_kts, previous_speed_axis,
            afds.VNAV_ENERGY_SPEED_ENTER_KTS, afds.VNAV_ENERGY_SPEED_EXIT_KTS)
end

function afds.vnav_energy_state(path_axis, speed_axis)
    if path_axis > 0 and speed_axis > 0 then return afds.VNAV_ENERGY_STATE_ABOVE_ABOVE end
    if path_axis > 0 and speed_axis < 0 then return afds.VNAV_ENERGY_STATE_ABOVE_BELOW end
    if path_axis < 0 and speed_axis < 0 then return afds.VNAV_ENERGY_STATE_BELOW_BELOW end
    if path_axis < 0 and speed_axis > 0 then return afds.VNAV_ENERGY_STATE_BELOW_ABOVE end
    if path_axis > 0 then return afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED end
    if path_axis < 0 then return afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED end
    if speed_axis < 0 then return afds.VNAV_ENERGY_STATE_ON_PATH_BELOW end
    if speed_axis > 0 then return afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE end
    return afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED
end

function afds.vnav_energy_state_name(state)
    local names = {
        [afds.VNAV_ENERGY_STATE_INACTIVE] = "INACTIVE",
        [afds.VNAV_ENERGY_STATE_ABOVE_ABOVE] = "ABOVE_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ABOVE_BELOW] = "ABOVE_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_BELOW] = "BELOW_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_ABOVE] = "BELOW_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ABOVE_ON_SPEED] = "ABOVE_PATH_ON_SPEED",
        [afds.VNAV_ENERGY_STATE_BELOW_ON_SPEED] = "BELOW_PATH_ON_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_BELOW] = "ON_PATH_BELOW_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_ABOVE] = "ON_PATH_ABOVE_SPEED",
        [afds.VNAV_ENERGY_STATE_ON_PATH_ON_SPEED] = "ON_PATH_ON_SPEED"
    }
    return names[state] or "UNKNOWN"
end

function afds.vnav_energy_thrust_reason_name(reason)
    local names = {
        [afds.VNAV_ENERGY_THRUST_REASON_NONE] = "none",
        [afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION] = "underspeed protection",
        [afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED] = "below path and below speed",
        [afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED] = "path recovery limited",
        [afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED] = "on path and below speed",
        [afds.VNAV_ENERGY_THRUST_REASON_SPEEDBRAKE_HOLD] = "speedbrake hold"
    }
    return names[reason] or "unknown"
end

function afds.rate_limit(current_value, target_value, elapsed_sec, decreasing_rate_per_sec,
        increasing_rate_per_sec)
    if type(target_value) ~= "number" then return current_value end
    if type(current_value) ~= "number" then return target_value end
    elapsed_sec = afds.clamp(tonumber(elapsed_sec) or 0, 0, 1)
    decreasing_rate_per_sec = math.max(tonumber(decreasing_rate_per_sec) or 0, 0)
    increasing_rate_per_sec = math.max(tonumber(increasing_rate_per_sec) or decreasing_rate_per_sec, 0)
    if target_value < current_value then
        return math.max(target_value, current_value - decreasing_rate_per_sec * elapsed_sec)
    end
    return math.min(target_value, current_value + increasing_rate_per_sec * elapsed_sec)
end

function afds.vnav_energy_mode_is_active(input)
    input = input or {}
    return (tonumber(input.in_vnav_descent) or 0) > 0
        and (tonumber(input.vnav_state) or 0) > 0
        and (tonumber(input.active_pitch_mode) or 0) == 6
        and (tonumber(input.vs_status) or 0) == 2
        and (tonumber(input.flch_status) or 0) == 0
        and (tonumber(input.alt_hold_status) or 0) ~= 2
        and (tonumber(input.gs_status) or 0) < 1
        and (tonumber(input.actual_gs_status) or 0) < 1
        and (tonumber(input.approach_mode) or 0) == 0
        and (tonumber(input.actual_approach_status) or 0) < 1
        and (tonumber(input.autoland) or 0) ~= 1
        and (tonumber(input.active_land) or 0) < 1
        and (tonumber(input.radar_alt_ft) or 0) > 1000
        and (tonumber(input.altitude_to_capture_ft) or 0)
            > math.max(600, tonumber(input.capture_window_ft) or 0)
end

function afds.vnav_energy_guidance(input)
    input = input or {}
    local path_error_ft = tonumber(input.path_error_ft) or 0
    local path_trend_fpm = tonumber(input.path_trend_fpm) or 0
    local target_speed_kts = tonumber(input.target_speed_kts) or 0
    local actual_speed_kts = tonumber(input.actual_speed_kts) or target_speed_kts
    local speed_trend_kts_per_sec = tonumber(input.speed_trend_kts_per_sec) or 0
    local nominal_vspeed_fpm = tonumber(input.nominal_vspeed_fpm) or 0
    local min_safe_speed_kts = tonumber(input.min_safe_speed_kts) or 0
    local maximum_descent_fpm = tonumber(input.maximum_descent_fpm)
        or afds.VNAV_ENERGY_MAX_DESCENT_FPM
    local minimum_descent_fpm = tonumber(input.minimum_descent_fpm)
        or afds.VNAV_ENERGY_MIN_DESCENT_FPM
    local speed_error_kts = actual_speed_kts - target_speed_kts
    local path_axis, speed_axis = afds.vnav_energy_axes(path_error_ft, speed_error_kts,
        input.previous_path_axis, input.previous_speed_axis)
    local state = afds.vnav_energy_state(path_axis, speed_axis)

    local worsening_path_fpm = 0
    if path_axis > 0 then
        worsening_path_fpm = math.max(path_trend_fpm, 0)
    elseif path_axis < 0 then
        worsening_path_fpm = math.min(path_trend_fpm, 0)
    end
    local path_correction_fpm = afds.clamp(path_error_ft * 0.45 + worsening_path_fpm * 0.20,
        -900, 1200)
    local speed_adjustment_fpm = 0

    if state == afds.VNAV_ENERGY_STATE_ABOVE_BELOW then
        speed_adjustment_fpm = -math.min(math.abs(speed_error_kts) * 45, 900)
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_BELOW then
        speed_adjustment_fpm = math.min(math.abs(speed_error_kts) * 35, 700)
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_ABOVE then
        speed_adjustment_fpm = math.min(speed_error_kts * 25, 500)
    elseif state == afds.VNAV_ENERGY_STATE_ON_PATH_BELOW then
        speed_adjustment_fpm = math.min(math.abs(speed_error_kts) * 20, 400)
    end

    local unconstrained_vspeed_fpm = nominal_vspeed_fpm - path_correction_fpm + speed_adjustment_fpm
    local target_vspeed_fpm = afds.clamp(unconstrained_vspeed_fpm,
        maximum_descent_fpm, minimum_descent_fpm)
    local recovery_limited = unconstrained_vspeed_fpm < maximum_descent_fpm
    local protection_speed_kts = math.max(min_safe_speed_kts,
        target_speed_kts - afds.VNAV_ENERGY_PROTECTION_MARGIN_KTS)
    local protection_active = actual_speed_kts <= protection_speed_kts
    if input.protection_active == true then
        protection_active = actual_speed_kts
            < protection_speed_kts + afds.VNAV_ENERGY_PROTECTION_RELEASE_KTS
    end

    -- Thrust allowed while the path is out of pitch reach is kept until the
    -- recovery limit clears or the speed is high.  Re-deciding it from the
    -- speed trend every sample switched IDLE and SPD each time the thrust
    -- stopped the deceleration.
    local previous_thrust_reason = tonumber(input.previous_thrust_reason)
    local recovery_hold = path_axis > 0 and speed_axis <= 0 and recovery_limited
        and tonumber(input.previous_thrust_policy) == afds.VNAV_ENERGY_THRUST_ALLOW
    local recovery_thrust = (state == afds.VNAV_ENERGY_STATE_ABOVE_BELOW and recovery_limited
        and speed_error_kts <= -afds.VNAV_ENERGY_SPEED_ENTER_KTS
        and speed_trend_kts_per_sec <= 0)
        or (recovery_hold
            and previous_thrust_reason == afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED)
    local speedbrake_extended = afds.vnav_energy_speedbrake_extended(input.speedbrake_lever)
    -- [B-13] Thrust allowed for a speed below the target on or below the path is kept while the aircraft is not
    -- above the path and the speed is less than VNAV_ENERGY_THRUST_RELEASE_KTS above the target. Released as soon as
    -- the speed was back within VNAV_ENERGY_SPEED_EXIT_KTS of the target, the A/T went to IDLE on a path it needed
    -- thrust for, slowed again and went back to SPD every 15-35 s through the descents (p20-line1: about 40 times,
    -- p20-L1: about 30); a real 747-400's A/T in SPD holds the speed with the thrust it needs. On a path steep enough
    -- at idle the speed goes past the target and the thrust ends.
    -- [B-13] Released 2 kt past the target only with the A/T's levers at idle (input.thrust_at_idle) and the speed not
    -- falling: idle holds the speed on this path. After the A/T's speed loop overshot (3-4 kt) its levers came to idle
    -- and the thrust ended on a path idle could not hold the speed on, which slowed it to SPD again (p21-line1: SPD,
    -- IDLE, HOLD, SPD on the path). Without thrust_at_idle, released at 2 kt past the target, as before.
    local at_idle = input.thrust_at_idle
    local released = speed_error_kts >= afds.VNAV_ENERGY_THRUST_RELEASE_KTS
        and (at_idle == nil or (at_idle == true and speed_trend_kts_per_sec >= 0))
    local below_hold = tonumber(input.previous_thrust_policy) == afds.VNAV_ENERGY_THRUST_ALLOW
        and (previous_thrust_reason == afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED
            or previous_thrust_reason == afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED)
        and path_axis <= 0 and not released

    local thrust_policy = afds.VNAV_ENERGY_THRUST_IDLE
    local thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_NONE
    if protection_active then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION
    elseif state == afds.VNAV_ENERGY_STATE_BELOW_BELOW then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED
    elseif state == afds.VNAV_ENERGY_STATE_ON_PATH_BELOW then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_ON_PATH_BELOW_SPEED
    elseif below_hold then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = previous_thrust_reason
    elseif speedbrake_extended and recovery_hold
        and previous_thrust_reason == afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION then
        -- With the speedbrake out the speed decays again as soon as the
        -- protection releases, so keep the protection thrust while the
        -- recovery is limited instead of cycling through its release band.
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION
    elseif recovery_thrust and speedbrake_extended then
        -- Do not run thrust against an extended speedbrake; underspeed
        -- protection still adds thrust if the speed decays that far.
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_SPEEDBRAKE_HOLD
    elseif recovery_thrust then
        thrust_policy = afds.VNAV_ENERGY_THRUST_ALLOW
        thrust_reason = afds.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED
    end

    local drag_required = path_axis > 0
        and ((speed_axis > 0 and speed_error_kts >= 10)
            or (recovery_limited and path_error_ft >= afds.VNAV_ENERGY_DRAG_PATH_ERROR_FT))

    return {
        path_axis = path_axis,
        speed_axis = speed_axis,
        state = state,
        state_name = afds.vnav_energy_state_name(state),
        speed_error_kts = speed_error_kts,
        target_vspeed_fpm = target_vspeed_fpm,
        unconstrained_vspeed_fpm = unconstrained_vspeed_fpm,
        thrust_policy = thrust_policy,
        thrust_reason = thrust_reason,
        thrust_reason_name = afds.vnav_energy_thrust_reason_name(thrust_reason),
        protection_active = protection_active,
        protection_speed_kts = protection_speed_kts,
        recovery_limited = recovery_limited,
        drag_required = drag_required
    }
end

-- [b] VNAV button on the ground and VNAV engage height

-- What a VNAV button press does, in the existing order: PERF/VNAV UNAVAILABLE
-- first (no cruise altitude, or less than 10 NM to T/D on the ground), then a
-- press with VNAV armed or active turns it off. On the ground, or in TO/GA,
-- VNAV is only armed and VNAV_CLB engages it after takeoff. Only an airborne
-- press outside TO/GA engages VNAV at once.
afds.VNAV_BUTTON_REFUSE = 1
afds.VNAV_BUTTON_DISARM = 2
afds.VNAV_BUTTON_ARM = 3
afds.VNAV_BUTTON_ENGAGE = 4

-- Lowest radio altitude at which an armed VNAV may engage (as in VNAV_CLB).
afds.VNAV_ENGAGE_MIN_RA_FT = 400

function afds.vnav_button_action(vnav_state, cruise_alt_ft, dist_to_tod_nm, on_ground, active_pitch_mode)
    local grounded = tonumber(on_ground) == 1
    if (tonumber(cruise_alt_ft) or 0) < 10
        or ((tonumber(dist_to_tod_nm) or 0) < 10 and grounded) then
        return afds.VNAV_BUTTON_REFUSE
    end
    if (tonumber(vnav_state) or 0) > 0 then return afds.VNAV_BUTTON_DISARM end
    if grounded or tonumber(active_pitch_mode) == 1 then return afds.VNAV_BUTTON_ARM end
    return afds.VNAV_BUTTON_ENGAGE
end

function afds.vnav_engage_height_reached(on_ground, radio_alt_ft)
    return tonumber(on_ground) ~= 1
        and (tonumber(radio_alt_ft) or 0) > afds.VNAV_ENGAGE_MIN_RA_FT
end

-- Altitude-terminated legs (CA, VA, FA): X-Plane names the end of such a leg
-- after its altitude, "(650)" for 28R heading to 650 ft at EIDW. The leg ends
-- where the altitude is reached; with the 747 overriding X-Plane's sequencing
-- that point then stays about 0.05 NM ahead of the aircraft. Returns the
-- altitude (the entry's route altitude, else the one in its name), nil for any
-- other entry ("(VECT)", "(INTC)", a fix).
function afds.altitude_leg_end_ft(entry)
    if type(entry) ~= "table" then return nil end
    local digits = string.match(tostring(entry[8] or ""), "^%((%d+)%)$")
    if digits == nil then return nil end
    local altitude = tonumber(entry[9])
    if altitude == nil or altitude <= 0 then altitude = tonumber(digits) end
    return altitude
end

-- [c] Route end of descent and VNAV descent path entry
-- Whether a route entry is a runway (RW06, RW18R), by its name.
local function is_runway_entry(entry)
    return string.match(tostring(entry[8] or ""), "^RW%d%d[LRC]?$") ~= nil
end

-- Index of the end of descent in an xtlua/fms route: the first entry within
-- radius_nm of the destination (the last entry) after the entry farthest from
-- it. On an A to B route this is the first entry inside the radius, as before.
-- On a route that starts and ends at the same airport the departure entries
-- are inside the radius too, and must not end the route there. If no entry
-- qualifies, or the whole route is inside the radius, the destination is used.
-- The missed approach after the arrival runway (the last runway entry inside
-- the radius with route outside it before) is left out: X-Plane ends a
-- missed approach's vectors leg ("(VECT)") hundreds of NM away, which would
-- otherwise be the farthest point and put the EOD at the destination.
function afds.route_eod_index(route, distance_fn, radius_nm)
    local count = #route
    if count < 2 or type(distance_fn) ~= "function" then return count end
    local destination = route[count]
    local distances = {}
    for i = 1, count - 1 do
        distances[i] = distance_fn(route[i][5], route[i][6], destination[5], destination[6])
    end
    local last = count - 1
    for i = count - 1, 1, -1 do
        if is_runway_entry(route[i]) and distances[i] < radius_nm then
            for k = 1, i - 1 do
                if distances[k] >= radius_nm then
                    last = i
                    break
                end
            end
            break
        end
    end
    local farthest_index, farthest_nm = 1, -1
    for i = 1, last do
        if distances[i] > farthest_nm then
            farthest_index, farthest_nm = i, distances[i]
        end
    end
    if farthest_nm < radius_nm then return count end
    for i = farthest_index + 1, last do
        if distances[i] < radius_nm then return i end
    end
    return count
end

-- Gradient (ft/nm) and target altitude of one VNAV profile entry. The path
-- normally starts at the previous constraint; from_tod starts it at the T/D
-- instead, at CRZ ALT or at a higher previous route altitude. An unset
-- previous altitude (below zero) or a leg of 0.1 NM or less gives no gradient,
-- and only a real previous altitude may replace the target altitude.
function afds.vnav_entry_slope(previous_alt_ft, alt_ft, distance_nm, from_tod, cruise_alt_ft)
    local start_alt_ft = previous_alt_ft
    if from_tod then start_alt_ft = math.max(previous_alt_ft, cruise_alt_ft) end
    if start_alt_ft <= 0 or distance_nm <= 0.1 then
        if previous_alt_ft > 0 then return 0, previous_alt_ft end
        return 0, alt_ft
    end
    return (start_alt_ft - alt_ft) / distance_nm, alt_ft
end

-- [B-14] A route point's altitude on VNAV's descent path (setDistances' profile): the native FMS's ([9], 0 without
-- one) inside the point's descent constraint from the CIFP (B747_route_constraints' entry: floor and/or ceiling, phase
-- "descent"; nil without one): raised to the floor, lowered to the ceiling; without [9] the floor, else the ceiling;
-- 0 without either. A real 747-400's FMC builds its descent path through the constraints, and its AFDS levels off at
-- the MCP altitude only.
function afds.vnav_path_alt(native_alt_ft, constraint)
    local alt = tonumber(native_alt_ft) or 0
    if type(constraint) ~= "table" or constraint.phase ~= "descent" then return alt end
    local floor, ceiling = tonumber(constraint.floor), tonumber(constraint.ceiling)
    if alt <= 0 then return floor or ceiling or 0 end
    if floor ~= nil and alt < floor then alt = floor end
    if ceiling ~= nil and alt > ceiling then alt = ceiling end
    return alt
end

-- [B-14] The distance VNAV's descent path (setDescentVSpeed) takes to a point through a fly-by turn at the fix F:
-- along the legs, as the profile's gradients are (fix to fix), and not straight to the point, with F's altitude the
-- path's at the turn's bisector, where the FMC sequences F. east_nm, north_nm: the aircraft from F; the turn from
-- in_course_deg to out_course_deg (true) starts lead_nm before F (B747_lnav_vnav_turn, as LNAV flies it), and F was
-- held start_nm from it (nil: lead_nm); to_fix:
-- the distance to F (held for its turn until the bisector), else to the next fix, leg_nm from F; direct_nm: the
-- straight distance to that point, taken from 2 nm off the leg (vectored; 1 nm more than the arc's middle where that
-- is farther) to all of it 2 nm farther. On the legs the
-- along-track distance; the arc's middle lies cut_nm (lead (1 - cos(turn / 2))) short of F along the inbound leg and
-- as far past it along the outbound one, which is taken off from where F was held to the bisector and given back
-- from there to the turn's end, so the path is continuous at the bisector and at F's altitude there. The straight
-- distance made the path about 200 ft high at NETOM's bisector (86 deg, 1 nm inside the fix) and, cutting the turn to
-- the next fix, 300-380 ft lower once F was let go there. extra_nm (0 if nil) is added to the distance along the legs:
-- what the turn before F, on a leg too short for it to end before F's begins, still gives back
-- (afds.vnav_turn_give_back_nm).
function afds.vnav_turn_distance_nm(east_nm, north_nm, in_course_deg, out_course_deg, lead_nm, start_nm, to_fix,
        leg_nm, direct_nm, extra_nm)
    local turn = math.abs(((out_course_deg - in_course_deg + 540) % 360) - 180)
    local cut = lead_nm * (1 - math.cos(math.rad(turn / 2)))
    local course = to_fix and in_course_deg or out_course_deg
    local ue, un = math.sin(math.rad(course)), math.cos(math.rad(course))
    local along = east_nm * ue + north_nm * un                  -- past F along the leg, negative before it
    local cross = math.abs(east_nm * un - north_nm * ue)
    local distance
    if to_fix then
        local before = -along
        local from = start_nm or lead_nm
        local w = 1
        if from > cut then w = math.max(0, math.min(1, (from - before) / (from - cut))) end
        distance = before - cut * w
    else
        distance = leg_nm - along + afds.vnav_turn_give_back_nm(east_nm, north_nm, in_course_deg, out_course_deg,
            lead_nm)
    end
    distance = distance + (extra_nm or 0)
    local inside = turn > 0.5 and cut / math.tan(math.rad(turn / 2)) or 0
    local off = math.max(0, math.min(1, (cross - math.max(2, inside + 1)) / 2))
    return distance + (direct_nm - distance) * off
end

-- [B-14] While LNAV does not fly the turns, a fly-by turn fades out of VNAV's path from VNAV_TURN_FADE_FROM_NM off its
-- path over VNAV_TURN_FADE_NM more (B747_vnav_turn_distance), the fade moving by at most the distance flown over
-- VNAV_TURN_FADE_RATE_NM, and LNAV ends it once it has (B747_lnav_update_vnav_hold)
afds.VNAV_TURN_FADE_FROM_NM = 0.3
afds.VNAV_TURN_FADE_NM = 1.0
afds.VNAV_TURN_FADE_RATE_NM = 2.0

-- [B-14] What a fly-by turn at F still gives back of its cut past the bisector (afds.vnav_turn_distance_nm), the
-- aircraft east_nm, north_nm from F: all of it (cut_nm, lead (1 - cos(turn / 2))) up to cut_nm along the outbound
-- course past F, none from the turn's end (lead_nm past it), in proportion between
function afds.vnav_turn_give_back_nm(east_nm, north_nm, in_course_deg, out_course_deg, lead_nm)
    local turn = math.abs(((out_course_deg - in_course_deg + 540) % 360) - 180)
    local cut = lead_nm * (1 - math.cos(math.rad(turn / 2)))
    local along = east_nm * math.sin(math.rad(out_course_deg)) + north_nm * math.cos(math.rad(out_course_deg))
    local w = 1
    if lead_nm > cut then w = math.max(0, math.min(1, (along - cut) / (lead_nm - cut))) end
    return cut * (1 - w)
end

-- [B-14] A route point's altitude on VNAV's descent path, route[i] with its descent constraint from the CIFP
-- (constraints[i], as B747_route_constraints): afds.vnav_path_alt for a point with the native FMS's altitude ([9]); for
-- one without, the path's altitude there, interpolated along the route (distance_fn) between the nearest points with
-- one on either side, kept inside the constraint (its floor or ceiling where the straight path would break it). It
-- took the floor, else the ceiling, whatever the points around: a floor far under the straight path put a dive and a
-- level-off into it, and a ceiling above the point before a level-off until the path came down to it (review 26
-- MINOR 5). Without points on both sides, the floor or ceiling, as before. After a point in the cruise (its altitude
-- within 100 ft of cruise_alt_ft, CRZ ALT; nil: none known) the path is level to the T/D and comes down at the T/D's
-- VNAV_TOD_FT_PER_NM: the point takes that line back from the point after it (CRZ ALT at most), not the straight line
-- from the cruise point, which put it thousands of feet off the path (review 27 MINOR 4).
function afds.vnav_route_point_alt(route, i, constraints, distance_fn, cruise_alt_ft)
    local entry = route[i]
    if entry == nil then return 0 end
    local constraint = constraints ~= nil and constraints[i] or nil
    local native = tonumber(entry[9]) or 0
    if native > 0 or type(constraint) ~= "table" or constraint.phase ~= "descent"
        or type(distance_fn) ~= "function" then
        return afds.vnav_path_alt(native, constraint)
    end
    local function nearest(step)
        local k, along = i, 0
        while route[k + step] ~= nil do
            along = along + distance_fn(route[k][5], route[k][6], route[k + step][5], route[k + step][6])
            k = k + step
            local alt = tonumber(route[k][9]) or 0
            if alt > 0 and route[k][2] ~= 1 then return alt, along end
        end
        return nil, nil
    end
    local before, before_nm = nearest(-1)
    local after, after_nm = nearest(1)
    if before == nil or after == nil or before_nm + after_nm <= 0 then return afds.vnav_path_alt(0, constraint) end
    local cruise = tonumber(cruise_alt_ft)
    if cruise ~= nil and cruise > 0 and before >= cruise - 100 then
        return afds.vnav_path_alt(math.min(cruise, after + afds.VNAV_TOD_FT_PER_NM * after_nm), constraint)
    end
    return afds.vnav_path_alt(before + (after - before) * before_nm / (before_nm + after_nm), constraint)
end

-- [d] Cruise climb after the ALT selector push
-- The climb starts 2 s after the push.  By then CRZ ALT may be back at the
-- level being flown (put back, or the step cancelled), and close to T/D a
-- climb would only be followed by the descent: a 2,000 ft step takes 15-20 NM
-- and VNAV leaves the cruise climb 10 NM before T/D.
afds.CRUISE_CLIMB_TOD_MARGIN_NM = 50

-- Returns "climb", "cancelled" (CRZ ALT not above the aircraft by more than
-- the capture window) or "tod" (T/D within CRUISE_CLIMB_TOD_MARGIN_NM, or
-- already passed).
function afds.cruise_climb_action(cruise_alt_ft, altitude_ft, distance_to_tod_nm, capture_window_ft)
    local cruise_alt = tonumber(cruise_alt_ft)
    local altitude = tonumber(altitude_ft)
    local window = tonumber(capture_window_ft) or 0
    if cruise_alt == nil or altitude == nil or cruise_alt <= altitude + window then
        return "cancelled"
    end
    local distance = tonumber(distance_to_tod_nm)
    if distance == nil or distance <= afds.CRUISE_CLIMB_TOD_MARGIN_NM then
        return "tod"
    end
    return "climb"
end

-- [e] Approach LOC and G/S capture windows
-- LOC captures within 2 dots while closing on the localizer, or within 1 dot
-- when settled; G/S captures only after LOC, with both within 1.5 dots.
afds.LOC_CAPTURE_MAX_DOTS = 2.0
afds.LOC_CAPTURE_STEADY_DOTS = 1.0
afds.LOC_CAPTURE_CLOSING_DOTS_PER_SEC = 0.01
afds.LOC_CAPTURE_STEADY_GROWTH_DOTS_PER_SEC = 0.02
afds.LOC_CAPTURE_MAX_INTERCEPT_DEG = 90
afds.LOC_CAPTURE_SAMPLE_SEC = 1.0
afds.GS_CAPTURE_MAX_LOC_DOTS = 1.5
afds.GS_CAPTURE_MAX_GS_DOTS = 1.5

-- Mean LOC deviation of the two receivers, in dots without sign.
function afds.loc_deviation_dots(nav1_dots, nav2_dots)
    nav1_dots = tonumber(nav1_dots)
    nav2_dots = tonumber(nav2_dots)
    if nav1_dots == nil or nav2_dots == nil then return nil end
    return math.abs((nav1_dots + nav2_dots) / 2)
end

local function heading_difference_deg(from_deg, to_deg)
    local difference = math.fmod(to_deg - from_deg, 360)
    if difference > 180 then difference = difference - 360 end
    if difference < -180 then difference = difference + 360 end
    return difference
end

-- input.sample is an earlier {time, dots} reading of loc_deviation_dots; it
-- must be at least LOC_CAPTURE_SAMPLE_SEC older than input.time so the rate
-- of change is measured over a useful interval.
function afds.loc_capture_ready(input)
    input = input or {}
    if (tonumber(input.nav1_signal) or 0) ~= 1 or (tonumber(input.nav2_signal) or 0) ~= 1 then
        return false
    end
    local course_deg = tonumber(input.course_deg)
    local heading_deg = tonumber(input.heading_deg)
    if course_deg == nil or heading_deg == nil
        or math.abs(heading_difference_deg(course_deg, heading_deg)) > afds.LOC_CAPTURE_MAX_INTERCEPT_DEG then
        return false
    end
    local dots = afds.loc_deviation_dots(input.nav1_dots, input.nav2_dots)
    if dots == nil or dots > afds.LOC_CAPTURE_MAX_DOTS then return false end

    local sample = input.sample
    local time = tonumber(input.time)
    if type(sample) ~= "table" or time == nil
        or tonumber(sample.time) == nil or tonumber(sample.dots) == nil then
        return false
    end
    local elapsed = time - tonumber(sample.time)
    if elapsed < afds.LOC_CAPTURE_SAMPLE_SEC then return false end
    local rate = (dots - tonumber(sample.dots)) / elapsed
    if rate <= -afds.LOC_CAPTURE_CLOSING_DOTS_PER_SEC then return true end
    return dots <= afds.LOC_CAPTURE_STEADY_DOTS and rate < afds.LOC_CAPTURE_STEADY_GROWTH_DOTS_PER_SEC
end

function afds.gs_capture_ready(input)
    input = input or {}
    if input.loc_captured ~= true then return false end
    local loc_dots = afds.loc_deviation_dots(input.nav1_dots, input.nav2_dots)
    local gs_dots = tonumber(input.gs_dots)
    return loc_dots ~= nil and loc_dots <= afds.GS_CAPTURE_MAX_LOC_DOTS
        and gs_dots ~= nil and math.abs(gs_dots) < afds.GS_CAPTURE_MAX_GS_DOTS
        and (tonumber(input.nav1_gs_flag) or 1) == 0 and (tonumber(input.nav2_gs_flag) or 1) == 0
        and (tonumber(input.nav1_vertical_signal) or 0) == 1
        and (tonumber(input.nav2_vertical_signal) or 0) == 1
end

-- [c-4] T/D from the descent constraints and the end of descent altitude
-- Planned descent gradient of the T/D (2.9 NM per 1,000 ft, as before).
afds.VNAV_TOD_FT_PER_NM = 290

-- Distance (NM) before the destination at which the descent from cruise_alt_ft
-- starts, and the end of descent altitude. As in setDistances, the route runs
-- to the end of descent (eod_index) and then straight to the destination (the
-- last entry). The end of descent altitude is its route altitude ([9]), reached
-- at the end of descent, or the destination elevation when it has none ([3] is
-- a frequency on a navaid).
-- Each descent constraint up to the end of descent must also be reached at
-- 290 ft/nm from CRZ ALT, so the T/D is the earliest of these. Walking back
-- from the end of descent, the descent constraints are the route altitudes
-- that lie after the T/D found so far (one at or above CRZ ALT there cannot
-- move it). A route altitude before it is cruise (such as the older CRZ ALT
-- left in [9] after a step climb), and an entry closer to the start of the
-- route than to its end is climb (a SID constraint). Passed constraints count
-- as well, so the T/D does not move while the aircraft passes them on the
-- descent.
-- [P49] The distance (NM) from each entry up to the end of descent along the route to it, then straight to the
-- destination (the last entry), as the T/D (afds.route_tod_distance) and setDistances' remaining distance measure
-- it: {[i] = NM} for i = 1 .. the end of descent's index (eod_index, the last entry when nil).
function afds.route_distance_to_end(route, eod_index, distance_fn)
    local count = #route
    local to_end = {}
    if count < 1 or type(distance_fn) ~= "function" then return to_end end
    local eod = math.max(1, math.min(tonumber(eod_index) or count, count))
    to_end[eod] = distance_fn(route[eod][5], route[eod][6], route[count][5], route[count][6])
    for i = eod - 1, 1, -1 do
        to_end[i] = to_end[i + 1] + distance_fn(route[i][5], route[i][6], route[i + 1][5], route[i + 1][6])
    end
    return to_end
end

function afds.route_tod_distance(route, eod_index, cruise_alt_ft, distance_fn, constraints)
    local count = #route
    if count < 1 then return 0, 0 end
    local cruise_alt = tonumber(cruise_alt_ft) or 0
    local eod = math.max(1, math.min(tonumber(eod_index) or count, count))
    local eod_alt = tonumber(route[eod][9]) or 0
    if eod_alt <= 0 then eod_alt = tonumber(route[count][9]) or 0 end
    local tod_nm = (cruise_alt - eod_alt) / afds.VNAV_TOD_FT_PER_NM
    if type(distance_fn) ~= "function" then return tod_nm, eod_alt end
    local to_end = afds.route_distance_to_end(route, eod, distance_fn)
    for i = eod, 1, -1 do
        -- the route altitude of the end of descent applies there, even when CRZ ALT is
        -- so close to it that the T/D from the destination lies after that point
        if i < eod and (to_end[i] >= tod_nm or to_end[i] * 2 > to_end[1]) then break end
        -- [B-14] the point's altitude on the descent path: [9] inside its CIFP constraint (constraints, as
        -- B747_route_constraints; afds.vnav_route_point_alt), as setDistances' profile takes it
        local alt = afds.vnav_route_point_alt(route, i, constraints, distance_fn, cruise_alt_ft)
        if alt > 0 and alt < cruise_alt then
            tod_nm = math.max(tod_nm, to_end[i] + (cruise_alt - alt) / afds.VNAV_TOD_FT_PER_NM)
        end
    end
    return tod_nm, eod_alt
end

-- [A-5] The approach's descent path to the runway
-- In the approach VNAV PTH flies the FMC's descent path, built back from the
-- end of descent at the runway: the runway entry's route altitude (the
-- CIFP's threshold crossing altitude, RW18R 37 ft), up the final approach
-- angle (the CIFP's, 3.0 deg without one) to where it meets the altitude of
-- the fix before it (the glide slope intercept), then through the route
-- altitudes ([9]) of the fixes before, each no lower than the one after it
-- (a descent path does not climb: EINN's ASGON 3,046 ft after ELPOM's 3,000),
-- and from the farthest of them up to CRZ ALT at the T/D's 290 ft/nm. Route
-- altitudes at or above the transition altitude are cruise, as are those
-- before them. The approach is within 25 NM of the runway along the route, and
-- once in it, within 27 NM (radar vectors or a hold about 25 NM out).
afds.VNAV_APPROACH_RANGE_NM = 25
afds.VNAV_APPROACH_LEAVE_NM = 27
afds.VNAV_APPROACH_GLIDE_DEG = 3.0
-- V/S along the path: its gradient at the ground speed, and 1.5 fpm per ft of
-- path error, at most 1,500 fpm, back to it
afds.VNAV_PATH_GAIN_FPM_PER_FT = 1.5
afds.VNAV_PATH_MAX_CORRECTION_FPM = 1500

-- Index of the arrival runway in an xtlua/fms route: the last runway entry
-- within radius_nm of the destination (the last entry) with an entry outside
-- the radius before it (not the departure runway of a route back to the
-- departure airport), or nil.
function afds.route_runway_index(route, distance_fn, radius_nm)
    local count = #route
    if count < 3 or type(distance_fn) ~= "function" then return nil end
    local destination = route[count]
    local function inside(i)
        return distance_fn(route[i][5], route[i][6], destination[5], destination[6]) < radius_nm
    end
    for i = count - 1, 2, -1 do
        if is_runway_entry(route[i]) and inside(i) then
            for k = 1, i - 1 do
                if not inside(k) then return i end
            end
            return nil
        end
    end
    return nil
end

-- The path from the runway (runway_index) back to the fix before first_index
-- (the fix flown to, or one sequenced early for its turn): points {d = NM to
-- the runway along the route, alt = ft, index = the route entry of a fix or
-- the runway} from the runway out, and the distance
-- along the route from each entry up to the runway to it. Only the fixes from
-- the route's farthest point from the destination on: on a route back to the
-- departure airport (a circuit) the way out is not the approach, and its
-- fixes (the departure runway at 41 ft) are left out; before that point the
-- path is the one beyond its far end. (After a DIRECT TO that left only the
-- origin before it, the fix flown to is that farthest point.)
function afds.vnav_approach_path(route, runway_index, first_index, distance_fn, transition_alt_ft,
        cruise_alt_ft, glide_deg, constraints)
    local destination = route[#route]
    local far_index, far_nm = 1, -1
    for i = 1, runway_index - 1 do
        local nm = distance_fn(route[i][5], route[i][6], destination[5], destination[6])
        if nm > far_nm then far_index, far_nm = i, nm end
    end
    local to_runway = {}
    to_runway[runway_index] = 0
    for i = runway_index - 1, 1, -1 do
        to_runway[i] = to_runway[i + 1]
            + distance_fn(route[i][5], route[i][6], route[i + 1][5], route[i + 1][6])
    end
    local transition_alt = tonumber(transition_alt_ft) or 18000
    local fixes = {}
    for i = math.max(1, first_index - 1, far_index), runway_index - 1 do
        -- [B-14] inside its CIFP constraint (constraints, as B747_route_constraints; afds.vnav_route_point_alt), as the
        -- descent profile's points: the path took [9] alone, and a point below its floor was kept above it only by the
        -- AFDS's altitude at the floor, now the MCP's (review 26 MINOR 6)
        local alt = afds.vnav_route_point_alt(route, i, constraints, distance_fn, cruise_alt_ft)
        if route[i][2] ~= 1 and string.sub(tostring(route[i][8] or ""), 1, 1) ~= "(" and not is_runway_entry(route[i])
            and alt > 0 then
            if alt >= transition_alt then
                fixes = {}
            else
                fixes[#fixes + 1] = {d = to_runway[i], alt = alt, index = i}
            end
        end
    end
    local lowest = math.huge
    for k = 1, #fixes do
        fixes[k].alt = math.min(fixes[k].alt, lowest)
        lowest = fixes[k].alt
    end
    local end_alt = tonumber(route[runway_index][9]) or 0
    if end_alt <= 0 then end_alt = (tonumber(route[#route][9]) or 0) + 50 end
    end_alt = math.min(end_alt, lowest)
    local points = {{d = 0, alt = end_alt, index = runway_index}}
    if #fixes > 0 then
        local final = fixes[#fixes]
        local gradient = math.tan(math.rad(tonumber(glide_deg) or afds.VNAV_APPROACH_GLIDE_DEG)) * 6076.12
        local intercept = (final.alt - end_alt) / gradient
        if intercept < final.d - 0.01 then points[#points + 1] = {d = intercept, alt = final.alt} end
    end
    for k = #fixes, 1, -1 do points[#points + 1] = fixes[k] end
    local far = points[#points]
    local cruise_alt = tonumber(cruise_alt_ft) or 0
    if cruise_alt > far.alt then
        points[#points + 1] = {d = far.d + (cruise_alt - far.alt) / afds.VNAV_TOD_FT_PER_NM, alt = cruise_alt}
    end
    return points, to_runway
end

-- The path's altitude (ft) and gradient (ft/NM, positive descending to the
-- runway) distance_nm before the runway; past its far end, level there.
function afds.vnav_path_at(points, distance_nm)
    if distance_nm <= points[1].d then
        if #points < 2 then return points[1].alt, 0 end
        return points[1].alt, (points[2].alt - points[1].alt) / math.max(points[2].d - points[1].d, 0.001)
    end
    for k = 1, #points - 1 do
        local a, b = points[k], points[k + 1]
        if distance_nm <= b.d then
            local gradient = (b.alt - a.alt) / math.max(b.d - a.d, 0.001)
            return a.alt + (distance_nm - a.d) * gradient, gradient
        end
    end
    return points[#points].alt, 0
end

-- V/S along the path (fpm): its gradient at the ground speed, less the path
-- error times VNAV_PATH_GAIN_FPM_PER_FT (at most VNAV_PATH_MAX_CORRECTION_FPM);
-- never a climb, nor below VNAV_ENERGY_MAX_DESCENT_FPM. With speed_margin_kts
-- (the speed limit less the IAS) the path keeps the speed within its limit, as
-- VNAV PTH does, departing the path when it must: the correction down fades
-- over the last VNAV_PATH_SPEED_FADE_KTS below the limit, and beyond it the
-- descent shallows, level VNAV_PATH_SPEED_LEVEL_KTS over.
afds.VNAV_PATH_SPEED_FADE_KTS = 5
afds.VNAV_PATH_SPEED_LEVEL_KTS = 10
function afds.vnav_path_vspeed(gradient_ft_per_nm, groundspeed_kts, path_error_ft, speed_margin_kts)
    local nominal = -gradient_ft_per_nm * groundspeed_kts / 60
    local correction = afds.clamp(path_error_ft * afds.VNAV_PATH_GAIN_FPM_PER_FT,
        -afds.VNAV_PATH_MAX_CORRECTION_FPM, afds.VNAV_PATH_MAX_CORRECTION_FPM)
    local margin = tonumber(speed_margin_kts)
    if margin ~= nil then
        if correction > 0 then
            correction = correction * afds.clamp(margin / afds.VNAV_PATH_SPEED_FADE_KTS, 0, 1)
        end
        if margin < 0 then
            nominal = nominal * afds.clamp(1 + margin / afds.VNAV_PATH_SPEED_LEVEL_KTS, 0, 1)
        end
    end
    return afds.clamp(nominal - correction, afds.VNAV_ENERGY_MAX_DESCENT_FPM, 0)
end

-- [f] Autoland flare law, derotation and thrust retard height
-- The flare commands a sink rate that shrinks with height and turns the sink
-- rate error into a pitch target, instead of holding a fixed attitude. The
-- autoland retards the thrust at the same height as the EEC SPD cut
-- (radarAlt1 < 25.1 in B747.42.xt.EEC.lua spd_throttle).
-- The constants are tuned against a point-mass model fitted to the X-Plane
-- circuits of 2026-10-10 (ground effect, the AFDS pitch loop: damping about
-- 0.15, 0.8 rad/s, 0.8 s delay, and the ground falling about 25 ft under the
-- flare at EINN 06): with the lightly damped loop the law needs a strong
-- pitch-rate damping term and a firm sink-rate gain, and the sink it aims
-- for at touchdown is about 220 fpm.
afds.FLARE_HEIGHT_FT = 43
afds.FLARE_RETARD_FT = 25
afds.FLARE_SINK_TIME_CONSTANT_SEC = 5.5
afds.FLARE_HEIGHT_BIAS_FT = 20
afds.FLARE_MIN_SINK_FPM = 60
afds.FLARE_PITCH_PER_FPM = 0.008
afds.FLARE_PITCH_INTEGRAL_PER_FPM_SEC = 0.0007
afds.FLARE_PITCH_RATE_DAMPING_SEC = 2.4
afds.FLARE_PITCH_UP_RATE_DEG_PER_SEC = 1.3
afds.FLARE_PITCH_DOWN_RATE_DEG_PER_SEC = 1.3
afds.FLARE_PITCH_BELOW_BASE_DEG = 0.5
afds.FLARE_PITCH_ABOVE_BASE_DEG = 3.5
afds.FLARE_MAX_PITCH_DEG = 7.5
afds.DEROTATION_RATE_DEG_PER_SEC = 1.0
afds.DEROTATION_PITCH_DEG = -0.5

local FPM_PER_KNOT = 101.269

-- Sink rate the flare asks for: 60*(RA + 20)/5.5 fpm, never deeper than the
-- sink rate at flare entry and never shallower than 60 fpm, so the
-- aircraft keeps sinking onto the runway instead of floating.
function afds.flare_vspeed_command_fpm(radio_altitude_ft, entry_vspeed_fpm)
    local command_fpm = -60 * (radio_altitude_ft + afds.FLARE_HEIGHT_BIAS_FT)
        / afds.FLARE_SINK_TIME_CONSTANT_SEC
    command_fpm = math.max(command_fpm, math.min(entry_vspeed_fpm, -afds.FLARE_MIN_SINK_FPM))
    return math.min(command_fpm, -afds.FLARE_MIN_SINK_FPM)
end

-- Flare pitch target. state keeps tp (last target), entry_vs (sink rate at
-- flare entry) and trim (integral term) between calls; missing fields start
-- from the current values. The target is the approach pitch plus the change
-- in flight-path angle the sink command needs, a PI term on the sink rate
-- error and pitch rate damping. It stays between base - 0.5 and
-- min(base + 3.5, 7.5) and moves at most 1.3 deg/s up or down.
-- An entry sink rate that is not a descent is not kept: XTLua gave start_flare
-- 0 for its first read of vh_ind_fpm (X-Plane 2026-10-10), which held the
-- command at -100 fpm from 50 ft; the first descending sample is used instead.
function afds.flare_pitch_target(state, base_pitch_deg, radio_altitude_ft, vspeed_fpm,
        airspeed_kts, pitch_rate_deg_sec, elapsed_sec)
    if state.entry_vs == nil or state.entry_vs > -afds.FLARE_MIN_SINK_FPM then
        state.entry_vs = nil
        if vspeed_fpm < -afds.FLARE_MIN_SINK_FPM then state.entry_vs = vspeed_fpm end
    end
    local entry_vs = state.entry_vs or vspeed_fpm
    local command_fpm = afds.flare_vspeed_command_fpm(radio_altitude_ft, entry_vs)
    local error_fpm = command_fpm - vspeed_fpm
    state.trim = afds.clamp((state.trim or 0)
        + afds.FLARE_PITCH_INTEGRAL_PER_FPM_SEC * error_fpm * elapsed_sec,
        -1, afds.FLARE_PITCH_ABOVE_BASE_DEG)
    local path_change_deg = math.deg((command_fpm - entry_vs)
        / (math.max(airspeed_kts, 100) * FPM_PER_KNOT))
    local target = base_pitch_deg + path_change_deg + state.trim
        + afds.FLARE_PITCH_PER_FPM * error_fpm
        - afds.FLARE_PITCH_RATE_DAMPING_SEC * pitch_rate_deg_sec
    target = afds.clamp(target, base_pitch_deg - afds.FLARE_PITCH_BELOW_BASE_DEG,
        math.min(base_pitch_deg + afds.FLARE_PITCH_ABOVE_BASE_DEG, afds.FLARE_MAX_PITCH_DEG))
    state.tp = afds.rate_limit(state.tp or base_pitch_deg, target, elapsed_sec,
        afds.FLARE_PITCH_DOWN_RATE_DEG_PER_SEC, afds.FLARE_PITCH_UP_RATE_DEG_PER_SEC)
    return state.tp
end

-- Approach pitch measured during the steady part of the approach. With no
-- steady sample the current pitch is used instead of dividing 0 by 0.
function afds.flare_base_pitch(pitch_sum_deg, pitch_samples, current_pitch_deg)
    if pitch_samples == nil or pitch_samples <= 0 then return current_pitch_deg end
    return pitch_sum_deg / pitch_samples
end

-- After main gear touchdown the nose comes down at 1.0 deg/s to -0.5 deg.
function afds.derotation_pitch_target(current_pitch_deg, elapsed_sec)
    return afds.rate_limit(current_pitch_deg, afds.DEROTATION_PITCH_DEG, elapsed_sec,
        afds.DEROTATION_RATE_DEG_PER_SEC, afds.DEROTATION_RATE_DEG_PER_SEC)
end

-- [g-3] Climb CAS/Mach crossover judged on the CAS target

-- ISA pressure ratio p/p0 at a pressure altitude, as in
-- B744.fms.performance.lua (mach_to_cas_kts).
local function isa_pressure_ratio(pressure_alt_ft)
    local altitude_m = math.max(0, tonumber(pressure_alt_ft) or 0) * 0.3048
    if altitude_m <= 11000 then
        return (1.0 - 2.25577e-5 * altitude_m) ^ 5.25588
    end
    return 0.223361 * math.exp(-(altitude_m - 11000) / 6341.62)
end

-- Mach number of a calibrated airspeed at a pressure altitude: the inverse
-- of performance.mach_to_cas_kts (340.294 m/s is the sea-level speed of
-- sound). nil for a missing or non-positive speed.
function afds.cas_to_mach(cas_kts, pressure_alt_ft)
    local cas = tonumber(cas_kts)
    if cas == nil or cas <= 0 then return nil end
    local cas_ratio = (cas / 1.94384449) / 340.294
    local impact_pressure_ratio = ((1.0 + 0.2 * cas_ratio * cas_ratio) ^ 3.5 - 1.0)
        / isa_pressure_ratio(pressure_alt_ft)
    return math.sqrt(5.0 * ((impact_pressure_ratio + 1.0) ^ (2.0 / 7.0) - 1.0))
end

-- Calibrated airspeed (kt) of a Mach number at a pressure altitude, as
-- performance.mach_to_cas_kts. nil for a missing or non-positive Mach.
function afds.mach_to_cas(mach, pressure_alt_ft)
    local m = tonumber(mach)
    if m == nil or m <= 0 then return nil end
    local impact_pressure_ratio = isa_pressure_ratio(pressure_alt_ft) * ((1.0 + 0.2 * m * m) ^ 3.5 - 1.0)
    return 340.294 * math.sqrt(5.0 * ((impact_pressure_ratio + 1.0) ^ (2.0 / 7.0) - 1.0)) * 1.94384449
end

afds.CLIMB_MACH_CROSSOVER_HYSTERESIS = 0.005

-- Whether the climb flies the climb Mach instead of the CAS target: when the
-- CAS target is at or above the climb Mach at this altitude (0.005 lower
-- while Mach is already selected, so the choice does not flip back and forth
-- as the Mach changes), or, as before, when the current Mach is above the
-- climb Mach.
function afds.climb_speed_uses_mach(cas_target_kts, climb_mach, pressure_alt_ft, current_mach, is_mach)
    climb_mach = tonumber(climb_mach)
    if climb_mach == nil then return false end
    if (tonumber(current_mach) or 0) > climb_mach then return true end
    local target_mach = afds.cas_to_mach(cas_target_kts, pressure_alt_ft)
    if target_mach == nil then return false end
    local threshold = climb_mach
    if tonumber(is_mach) == 1 then threshold = threshold - afds.CLIMB_MACH_CROSSOVER_HYSTERESIS end
    return target_mach >= threshold
end

-- [g-5] Autopilot Mach target written with the speed mode

-- Mach target for the X-Plane autopilot: limited to Mmo - 0.01, as
-- B747_ap_ias_mach_mode limits the dial Mach. An unset or implausible Mmo
-- (below M.50) does not limit it.
function afds.limited_mach_target(mach, max_mach)
    max_mach = tonumber(max_mach)
    if max_mach == nil or max_mach < 0.5 then return mach end
    return math.min(mach, max_mach - 0.01)
end

-- [h-2] VNAV PTH thrust with the speedbrake extended
-- Lever positions beyond ARM (0.125) count as extended.
afds.VNAV_ENERGY_SPEEDBRAKE_EXTENDED_LEVER = 0.15
afds.VNAV_ENERGY_THRUST_REASON_SPEEDBRAKE_HOLD = 5

function afds.vnav_energy_speedbrake_extended(speedbrake_lever)
    return (tonumber(speedbrake_lever) or 0) >= afds.VNAV_ENERGY_SPEEDBRAKE_EXTENDED_LEVER
end

-- [h-3] TO/GA roll mode
-- TO/GA pitch and roll share one status flag. The roll annunciation stays
-- TO/GA only until a roll mode replaces it: active LNAV, LOC capture, or
-- HDG SEL / HDG HOLD selected in flight (roll_cleared).
function afds.toga_roll_mode_active(toga_status, lnav_state, nav_status, roll_cleared)
    return toga_status ~= 0 and lnav_state ~= 2 and nav_status ~= 2 and not roll_cleared
end

return afds
