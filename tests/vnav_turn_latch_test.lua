-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] The fly-by turn LNAV hands VNAV's descent path (B747_lnav_vnav_turn, B747_lnav_update_vnav_hold) is the
-- route's as it stands:
-- 1. after a route edit at the turn's fix or the next one (NIRSI moved, NETOM's turn 40 deg instead of 86) the path is
--    the new route's: the turn, latched by its index, kept the old courses and lead, and the path stepped +303 ft at
--    the profile's refresh after the bisector and -142 ft at the old turn's end (review 27b MINOR 1);
-- 2. the turn is taken only while LNAV flies the turns on its path - engaged, no offset, no direct-to - and ends once
--    LNAV no longer does (HDG SEL, the kit's DIRECT TO) and the 747 has gone off its path, or once it is vectored away:
--    taken and kept without LNAV, flown straight past NETOM it put the path ~170 ft high behind the fix (review 27b
--    MINOR 3);
-- 3. where the turn ends before its own end (HDG SEL, a route edit) the path carries on and the step is taken out over
--    2 nm, nearer or farther: the cut the turn had taken off dropped at once;
-- 4. on a leg too short for the turn before to end before the next one begins (NIRSI's 64 deg, then AM607's 90 deg
--    2.0-4.0 nm on) the path is continuous: the next turn, taken only once the one before had ended, was taken late and
--    the path stepped -34 ft at once with a 3.2 nm leg, -375 ft with 2.6 nm (review 27b MINOR 2); below 2.4 nm the
--    747 crosses AM607's bisector inside the turn's cut, and the step there, over the blend's 250 ft, was taken at once
--    (+255 ft with 2.2 nm, +268 with 2.0: review 28 MINOR 2);
-- 5. far from the fix (the cruise) LNAV works the turn out every 5 s at most: it did every frame (review 27b NIT);
-- 6. in HDG SEL the turn stays while the 747 flies on round its path and fades out of the path as the 747 goes off
--    it: ended at the HDG SEL, the path stepped -740 to -820 ft where the fix was sequenced abeam (review 28 MAJOR 1),
--    and ended 0.5 nm off LNAV's path +330 to +500 ft (review 29 MAJOR 1);
-- 7. the turn carried on (prev) on a short leg ends with a route edit of its fix without a step (review 28 NIT);
-- 8. the turn's fade moves with the distance flown also where LNAV engages or lets go off the path (review 30 MAJOR 1),
--    and is measured from the turn carried on too on a short leg, but not from its outbound leg (review 30 NIT, review
--    31 NIT); a change carries the step still being taken out on (review 30 MINOR 2), and a route edit's own step over
--    250 ft is taken at once, that step with it (review 31 MINOR 1, review 32 MINOR 1).
-- The production LNAV (B747_lnav_update_xtk and B747_lnav_update_vnav_hold, as B747_getCurrentWayPoint calls them),
-- setDescentVSpeed (the approach's path inside 25 nm) and setDistances every 2 s (approach_model.lua's loader) on the
-- EHAM route in the production order, the 747 flown along the legs and the fly-by arcs at the bank flown, in a flat
-- frame around the first fix; LNAV's sequence emulated at the turn's bisector, as LNAV sequences a turn it flies by
-- its path.
local model = dofile("tests/approach_model.lua")
local afds = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.afds_helpers.lua")
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function slice(path, first_marker, last_marker)
    local f = assert(io.open(path)); local source = f:read("*a"); f:close()
    local first = assert(source:find(first_marker, 1, true), first_marker)
    local last = assert(source:find(last_marker, first + 1, true), last_marker)
    local _, lines = source:sub(1, first - 1):gsub("\n", "")
    return string.rep("\n", lines)..source:sub(first, last - 1), "@"..path
end

local SUGOL, NETOM, NIRSI, AM607, AM608 = 5, 6, 7, 8, 9
local function setup(mutate)
    local o = model.eham({active = NETOM, mcp_alt_ft = 2000, vnav_speed_kt = 250, at_mode = 3})
    if mutate then mutate(o.route) end
    local d = {}
    local ap = model.load(d, {fmsData = {desspdtransalt = "10000", destranspd = "240", desspd = "270",
        desrestspd = "---", desrestalt = "-----", transalt = "18000", crzalt = "FL370"},
        B747_route_constraints = o.constraints})
    model.set_datarefs(d, o, 0.05)
    -- LNAV's leg logic, its cross-track error and its hold of a fix for its turn, in the same namespace
    for _, part in ipairs({{"function B747_getCurrentWayPoint(fmsO)", "local LNAV_MAX_PREEMPT_XTK_NM"},
            {"local LNAV_MAX_PREEMPT_XTK_NM", "function B747_ap_altitude(fms)"}}) do
        local code, name = slice(AP.."B747.70.xt.autopilot.lua", part[1], part[2])
        setfenv(assert(loadstring(code, name)), ap)()
    end
    d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = 2, 150
    d.simDR_onGround, d.simDR_autopilot_bank_limit, d.simDR_autopilot_bank_angles = 0, 4, {[0] = 5, 10, 15, 20, 25, 30}
    d.B747DR_ap_lnav_state, d.B747DR_ap_approach_mode, d.B747DR_ap_lnav_xtk_target = 2, 0, 0
    d.B747DR_ap_lnav_xtk_error, d.B747DR_CAS_caution_status, d.simDR_override_fms_progress = 0, {}, 1
    d.simDR_vvi_fpm_pilot, d.simDR_AHARS_roll_deg_pilot, d.simDR_beta_deg = -1000, 0, 0
    d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
    d.B747BR_todLat, d.B747BR_todLong = o.route[2][5], o.route[2][6]
    ap.B747_reset_vnav_energy()
    return o.route, d, ap
end

local function wrap(a) return (a + 540) % 360 - 180 end
local function unit(h) return math.sin(math.rad(h)), math.cos(math.rad(h)) end
-- moves (lat, lon) nm along the bearing brg (true), on the sphere
local function move(lat, lon, nm, brg)
    local br, la, lo, df = math.rad(brg), math.rad(lat), math.rad(lon), nm / 3440.065
    local la2 = math.asin(math.sin(la) * math.cos(df) + math.cos(la) * math.sin(df) * math.cos(br))
    local lo2 = lo + math.atan2(math.sin(br) * math.sin(df) * math.cos(la), math.cos(df) - math.sin(la) * math.sin(la2))
    return math.deg(la2), math.deg(lo2)
end
-- a production local (a module's state or function) reached through the upvalues of a global function that uses it
local function upvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if n == nil or n == name then return v end
        i = i + 1
    end
end

-- Flies through the fly-by turns at the route's consecutive indexes ks: from_fix nm before the first fix on its
-- inbound leg, the arcs of each turn at the bank flown (shortened in proportion where two turns' tangents overlap on a
-- short leg; none with opts.noturn, straight on through the fixes) and `after` nm on past the last; 0.02 nm steps
-- (opts.ds) at tas kt and alt ft. opts.edit = {s, fn}: fn(route) at path distance s, the path from there the new
-- route's; opts.hooks = {{s, fn}}: fn(d, ap) at s (HDG SEL, a direct-to); opts.vector = {s, heading}: straight on that
-- heading from s; opts.maneuver = {s, radius, turn}: from s an arc of that radius through turn deg, then straight;
-- opts.offset: the path flown that far right of the track (nm, left when negative).
-- LNAV makes the next fix active as the 747 crosses the turn's bisector (opts.seq "abeam": abeam the fix, as with
-- LNAV not engaged; "start": at the turn's start, the fix then held to the bisector; "none": never;
-- opts.seq_after = {s, mode}: that mode from s). Each sample: s, the path's altitude (path), the active fix, the
-- turn's fix (tfix, 0 without one), whether released (rel), its outbound course (out), its start_nm (start), its
-- fade and the turn it carries (prev, 0 without), the fix whose arc the 747 flies (arc, 0 on a leg or flown off the
-- path), the held fix (hold), the distance to the first fix (d1) and, with opts.offsets, the 747's distance off the
-- turn's path as LNAV takes it for the fade (off, B747_lnav_turn_path_offset; nil without a turn).
local function fly(ks, opts, mutate)
    local route, d, ap = setup(mutate)
    local lat0, lon0 = route[ks[1]][5], route[ks[1]][6]
    local cl = math.cos(math.rad(lat0))
    local function toLocal(lat, lon) return (lon - lon0) * 60 * cl, (lat - lat0) * 60 end
    local function toLatLon(e, n) return lat0 + n / 60, lon0 + e / (60 * cl) end
    local tas = opts.tas
    local R0 = (tas * 0.514444) ^ 2 / (9.80665 * math.tan(math.rad(opts.bank))) / 1852
    local segs, arcStart
    local function build()
        segs, arcStart = {}, {}
        local P = {}
        for i = ks[1] - 1, ks[#ks] + 1 do P[i] = {toLocal(route[i][5], route[i][6])} end
        local function course(a, b) return math.deg(math.atan2(b[1] - a[1], b[2] - a[2])) % 360 end
        local T, R, turn, cin, cout = {}, {}, {}, {}, {}
        for _, k in ipairs(ks) do
            cin[k], cout[k] = course(P[k - 1], P[k]), course(P[k], P[k + 1])
            turn[k] = opts.noturn and 0 or wrap(cout[k] - cin[k])
            if opts.noturn then cout[k] = cin[k] end
            R[k] = R0
            T[k] = R0 * math.tan(math.rad(math.abs(turn[k]) / 2))
        end
        for j = 1, #ks - 1 do
            local a, b = ks[j], ks[j + 1]
            local legLen = math.sqrt((P[b][1] - P[a][1]) ^ 2 + (P[b][2] - P[a][2]) ^ 2)
            if T[a] + T[b] > legLen then
                local share = legLen / (T[a] + T[b])
                T[a], T[b], R[a], R[b] = T[a] * share, T[b] * share, R[a] * share, R[b] * share
            end
        end
        local ie, inn = unit(cin[ks[1]])
        local cur = {P[ks[1]][1] - opts.from_fix * ie, P[ks[1]][2] - opts.from_fix * inn}
        local s = 0
        for _, k in ipairs(ks) do
            local ue, un = unit(cin[k])
            local st = {P[k][1] - T[k] * ue, P[k][2] - T[k] * un}
            local len = math.sqrt((st[1] - cur[1]) ^ 2 + (st[2] - cur[2]) ^ 2)
            segs[#segs + 1] = {kind = "line", e = cur[1], n = cur[2], h = cin[k], len = len}
            s = s + len
            arcStart[k] = s
            if math.abs(turn[k]) >= 0.01 then
                local side = turn[k] > 0 and 1 or -1
                local alen = R[k] * math.rad(math.abs(turn[k]))
                segs[#segs + 1] = {kind = "arc", ce = st[1] + side * R[k] * un, cn = st[2] - side * R[k] * ue,
                    se = st[1], sn = st[2], side = side, R = R[k], h = cin[k], len = alen, fix = k}
                s = s + alen
            end
            local oe, on = unit(cout[k])
            cur = {P[k][1] + T[k] * oe, P[k][2] + T[k] * on}
        end
        segs[#segs + 1] = {kind = "line", e = cur[1], n = cur[2], h = cout[ks[#ks]], len = opts.after}
        return s + opts.after
    end
    local total = build()
    local function position(s)
        for _, g in ipairs(segs) do
            if s <= g.len then
                if g.kind == "line" then
                    local ue, un = unit(g.h)
                    return g.e + s * ue, g.n + s * un, g.h, g
                end
                local a = s / g.R
                local re, rn = g.se - g.ce, g.sn - g.cn
                local c, sa = math.cos(-g.side * a), math.sin(-g.side * a)
                return g.ce + re * c - rn * sa, g.cn + re * sa + rn * c, g.h + g.side * math.deg(a), g
            end
            s = s - g.len
        end
        local g = segs[#segs]
        local ue, un = unit(g.h)
        return g.e + g.len * ue, g.n + g.len * un, g.h
    end
    local along = position
    if opts.vector then
        along = function(s)
            if s <= opts.vector.s then return position(s) end
            local e, n = position(opts.vector.s)
            local ue, un = unit(opts.vector.heading)
            return e + (s - opts.vector.s) * ue, n + (s - opts.vector.s) * un, opts.vector.heading
        end
    end
    if opts.maneuver then
        -- from s on: an arc of `radius` nm through `turn` deg (+ right) from where the 747 is, then straight on
        local m, base = opts.maneuver, along
        along = function(s)
            if s <= m.s then return base(s) end
            local e0, n0, h0 = base(m.s)
            local side = m.turn > 0 and 1 or -1
            local ue, un = unit(h0)
            local ce, cn = e0 + side * m.radius * un, n0 - side * m.radius * ue
            local alen = m.radius * math.rad(math.abs(m.turn))
            local a = math.min(s - m.s, alen) / m.radius
            local re, rn = e0 - ce, n0 - cn
            local c, sa = math.cos(-side * a), math.sin(-side * a)
            local e, n, h = ce + re * c - rn * sa, cn + re * sa + rn * c, h0 + side * math.deg(a)
            if s - m.s <= alen then return e, n, h end
            local he, hn = unit(h)
            return e + (s - m.s - alen) * he, n + (s - m.s - alen) * hn, h
        end
    end
    if opts.offset then
        -- the whole path flown opts.offset nm to the right of the track (left when negative)
        local base = along
        along = function(s)
            local e, n, h = base(s)
            return e + opts.offset * math.cos(math.rad(h)), n - opts.offset * math.sin(math.rad(h)), h
        end
    end
    d.simDR_TAS_mps, d.simDR_groundspeed = tas / 1.94384, tas / 1.94384
    d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot = 250, 250
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = opts.alt, opts.alt
    local active = ks[1]
    local function set_active()
        for i = 1, #route do route[i][10] = (i == active) end
        d.B747DR_fmscurrentIndex = active
    end
    set_active()
    local e0, n0 = position(0)
    d.simDR_latitude, d.simDR_longitude = toLatLon(e0, n0)
    d.simDR_true_heading, d.simDR_ground_track_true = segs[1].h, segs[1].h
    ap.B747_lnav_update_xtk(route)
    ap.B747_lnav_update_vnav_hold(route)
    ap.setDistances(route)
    local ds = opts.ds or 0.02
    local steps_2s = math.max(1, math.floor(tas / 3600 * 2 / ds + 0.5))
    local turnOffset = opts.offsets and upvalue(ap.B747_lnav_update_vnav_hold, "B747_lnav_turn_path_offset")
    local samples = {}
    local s, step, edited, hooked = 0, 0, false, {}
    while s <= total do
        if opts.edit and not edited and s >= opts.edit.s then
            opts.edit.fn(route)
            edited = true
            total = build()
        end
        for n, h in ipairs(opts.hooks or {}) do
            if not hooked[n] and s >= h.s then h.fn(d, ap); hooked[n] = true end
        end
        local east, north, track, seg = along(s)
        d.simDR_latitude, d.simDR_longitude = toLatLon(east, north)
        d.simDR_true_heading, d.simDR_ground_track_true = track % 360, track % 360
        d.simDRTime = d.simDRTime + ds / tas * 3600
        -- LNAV's sequence of the active fix at its turn's bisector (or abeam it, or at its start)
        local k = active
        local seq = opts.seq
        if opts.seq_after and s >= opts.seq_after.s then seq = opts.seq_after.mode end
        if k <= ks[#ks] and seq == "start" then
            if arcStart[k] and s >= arcStart[k] then active = k + 1 end
        elseif k <= ks[#ks] and seq ~= "none" then
            local F = route[k]
            local dd = ap.getDistance(F[5], F[6], d.simDR_latitude, d.simDR_longitude)
            local b = math.rad(ap.getHeading(F[5], F[6], d.simDR_latitude, d.simDR_longitude))
            local cin = (ap.getHeading(F[5], F[6], route[k - 1][5], route[k - 1][6]) + 180) % 360
            local cout = ap.getHeading(F[5], F[6], route[k + 1][5], route[k + 1][6])
            if seq == "abeam" then cout = cin end
            if afds.past_turn_bisector(dd * math.sin(b), dd * math.cos(b), cin, cout) then active = k + 1 end
        end
        set_active()
        ap.B747_lnav_update_xtk(route)
        ap.B747_lnav_update_vnav_hold(route)
        local t = ap.B747_lnav_vnav_turn
        ap.setDescentVSpeed(route)
        local path = d.simDR_pressureAlt1 - d.B747BR_fpe
        if (step + 1) % steps_2s == 0 then ap.setDistances(route) end
        samples[#samples + 1] = {s = s, path = path, active = active, tfix = t and t.fix or 0, rel = t and t.released,
            out = t and t.out_course, start = t and t.start_nm, hold = d.B747DR_vnav_hold_index,
            fade = t and t.fade or 0, prev = t and t.prev and t.prev.fix or 0, arc = seg and seg.fix or 0,
            d1 = ap.getDistance(route[ks[1]][5], route[ks[1]][6], d.simDR_latitude, d.simDR_longitude),
            off = turnOffset and t and turnOffset(route, t) or nil}
        s, step = s + ds, step + 1
    end
    return samples
end

-- the largest step of the path between samples with s in (from, to], and where
local function largest_step(samples, from, to)
    local worst, where = 0, nil
    for n = 2, #samples do
        local q, p = samples[n], samples[n - 1]
        if q.s > from and q.s <= to and q.path and p.path and math.abs(q.path - p.path) > math.abs(worst) then
            worst, where = q.path - p.path, q.s
        end
    end
    return worst, where
end
-- the largest step of the path against its own slope (the step less the mean of the steps before and after it), and
-- where, between s from and to (all if nil): on a steep path (a short leg) the steps themselves are large
local function largest_jump(samples, from, to)
    local worst, where = 0, nil
    for n = 3, #samples - 1 do
        local a, p, q, b = samples[n - 2], samples[n - 1], samples[n], samples[n + 1]
        if a.path and p.path and q.path and b.path and q.s >= (from or -1e9) and q.s <= (to or 1e9) then
            local jump = (q.path - p.path) - ((p.path - a.path) + (b.path - q.path)) / 2
            if math.abs(jump) > math.abs(worst) then worst, where = jump, q.s end
        end
    end
    return worst, where
end

-- 1. A route edit while NETOM's turn is taken: NIRSI moved to 10.7 nm from NETOM on 069, so that NETOM's turn is
-- 40 deg instead of 86, 2.5 nm before NETOM (inside the 86 deg turn's lead and margin, outside the 40 deg one's); the
-- reference is the new route flown from the start
local function edit_nirsi(route)
    route[NIRSI][5], route[NIRSI][6] = move(route[NETOM][5], route[NETOM][6], 10.7, 69)
end
local opts = {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6}
local ref = fly({NETOM}, opts, edit_nirsi)
local EDIT_S = 6.5
local edited = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6,
    edit = {s = EDIT_S, fn = edit_nirsi}})
local takenBefore = false
for _, q in ipairs(edited) do
    if q.s < EDIT_S and q.tfix == NETOM then takenBefore = true end
end
check(takenBefore, "NETOM's 86 deg turn is taken before the edit")
local stale, worstDiff, worstAt = nil, 0, nil
for n, q in ipairs(edited) do
    if q.s >= EDIT_S and q.tfix == NETOM and math.abs(wrap(q.out - 69)) > 1 and stale == nil then stale = q end
    local r = ref[n]
    if q.s >= EDIT_S + 2.1 and q.path and r and r.path and math.abs(q.path - r.path) > math.abs(worstDiff) then
        worstDiff, worstAt = q.path - r.path, q.s
    end
end
check(stale == nil, string.format("after the edit NETOM's turn goes out on the new course 069: %s",
    stale and string.format("%.0f at %.2f nm", stale.out, stale.s) or "yes"))
check(math.abs(worstDiff) <= 15, string.format("from 2.1 nm after the edit (its step taken out over 2 nm) the path is "
    .."the new route's: largest difference %+.0f ft at %.2f nm", worstDiff, worstAt or -1))
local worst, where = largest_step(edited, EDIT_S - 0.02, 1e9)
check(math.abs(worst) <= 15, string.format("through the edit and after it the path is continuous: largest step %+.0f "
    .."ft in 0.02 nm at %.2f nm", worst, where or -1))

-- 2. The turn only where LNAV flies it. On to NETOM 9 nm before it at 270 kt TAS; its 86 deg turn is taken about
-- 3.9 nm before it (its lead and the margin) with LNAV engaged
local function taken_between(samples, from, to)
    for _, q in ipairs(samples) do
        if q.s >= from and q.s <= to and q.tfix ~= 0 then return q end
    end
    return nil
end
-- LNAV armed (not engaged): flown straight on through NETOM, sequenced abeam it, no turn taken
local function lnav_armed(d) d.B747DR_ap_lnav_state = 1 end
local r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true, seq = "abeam",
    hooks = {{s = 0, fn = lnav_armed}}})
local q = taken_between(r, 0, 1e9)
check(q == nil, string.format("LNAV not engaged, straight on past NETOM: no turn taken (%s)",
    q and string.format("NETOM's taken at %.2f nm", q.s) or "none"))
-- HDG SEL 3.5 nm before NETOM, after its turn was taken, flown straight on: the turn fades out of the path as the 747
-- goes off it and has ended (1.3 nm off it) 2 nm past NETOM's abeam point, and none is taken again
local function hdg_sel(d) d.B747DR_ap_lnav_state = 0 end
local function abeam_at(samples)
    for _, p in ipairs(samples) do if p.active ~= NETOM then return p.s end end
    return 1e9
end
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true, seq = "abeam",
    hooks = {{s = 5.5, fn = hdg_sel}}})
check(taken_between(r, 0, 5.48) ~= nil, "NETOM's turn taken before the HDG SEL")
q = taken_between(r, abeam_at(r) + 2, 1e9)
check(q == nil, string.format("HDG SEL 3.5 nm before NETOM, straight on: its turn has ended 2 nm past NETOM's abeam "
    .."point (%s)", q and string.format("still taken at %.2f nm", q.s) or "it had"))
-- the kit's DIRECT TO NETOM 3.5 nm before it (an LNAV direct-to, xtk target -100), straight on: the same
local function direct_to(d) d.B747DR_ap_lnav_xtk_target = -100 end
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true, seq = "abeam",
    hooks = {{s = 5.5, fn = direct_to}}})
q = taken_between(r, abeam_at(r) + 2, 1e9)
check(q == nil, string.format("a direct-to NETOM 3.5 nm before it, straight on: its turn has ended 2 nm past NETOM's "
    .."abeam point (%s)", q and string.format("still taken at %.2f nm", q.s) or "it had"))
-- turned away from NETOM 3.5 nm before it, LNAV still engaged: the turn ends 1 nm farther from NETOM than where it was
-- taken, not before
local function bearing(a, b)
    local la1, lo1, la2, lo2 = math.rad(a[5]), math.rad(a[6]), math.rad(b[5]), math.rad(b[6])
    local y = math.sin(lo2 - lo1) * math.cos(la2)
    local x = math.cos(la1) * math.sin(la2) - math.sin(la1) * math.cos(la2) * math.cos(lo2 - lo1)
    return math.deg(math.atan2(y, x)) % 360
end
local rt = model.eham({}).route
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 8, seq = "none",
    vector = {s = 5.5, heading = (bearing(rt[SUGOL], rt[NETOM]) + 180) % 360}})
local start, early, late = nil, nil, nil
for _, p in ipairs(r) do
    if p.tfix == NETOM and start == nil then start = p.start end
    if start and p.s > 5.5 then
        if p.tfix == 0 and p.d1 < start + 0.98 and early == nil then early = p end
        if p.tfix ~= 0 and p.d1 > start + 1.02 and late == nil then late = p end
    end
end
check(start ~= nil and early == nil and late == nil, string.format("turned back 3.5 nm before NETOM: the turn taken %s "
    .."nm from it ends 1 nm farther (%s)", start and string.format("%.2f", start) or "never",
    early and string.format("ended early at %.2f nm from NETOM", early.d1) or late and string.format("still "
    .."taken at %.2f nm from NETOM", late.d1) or "it does"))

-- 3. Where the turn ends before its own end - HDG SEL, a route edit (1.) - the cut it had taken off is not dropped at
-- once: taken out over 2 nm, as a change of the next point. HDG SEL 2.5 nm before NETOM, 1.5 nm into the turn's taper
-- (about 75 ft of its cut taken off), flown straight on and sequenced abeam
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true, seq = "abeam",
    hooks = {{s = 6.5, fn = hdg_sel}}})
local abeam = nil
for _, p in ipairs(r) do
    if p.active ~= NETOM and abeam == nil then abeam = p.s end
end
worst, where = largest_step(r, 6.4, (abeam or 1e9) - 0.03)
check(math.abs(worst) <= 15, string.format("HDG SEL 2.5 nm before NETOM: the path continuous up to the sequence abeam "
    .."NETOM (%.2f nm): largest step %+.0f ft in 0.02 nm at %.2f nm", abeam or -1, worst, where or -1))
-- and turned back there, the step is taken out as the distance grows too: the path as without the turn 2.1 nm on
local back = (bearing(rt[SUGOL], rt[NETOM]) + 180) % 360
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 8, seq = "none",
    hooks = {{s = 6.5, fn = hdg_sel}}, vector = {s = 6.5, heading = back}})
local plain = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 8, seq = "none",
    hooks = {{s = 0, fn = hdg_sel}}, vector = {s = 6.5, heading = back}})
worstDiff, worstAt = 0, nil
for n, p in ipairs(r) do
    local w = plain[n]
    if p.s >= 6.5 + 2.1 and p.path and w and w.path and math.abs(p.path - w.path) > math.abs(worstDiff) then
        worstDiff, worstAt = p.path - w.path, p.s
    end
end
check(math.abs(worstDiff) <= 15, string.format("HDG SEL and turned back 2.5 nm before NETOM: from 2.1 nm on the path "
    .."is the one without the turn: largest difference %+.0f ft at %.2f nm", worstDiff, worstAt or -1))

-- 4. Short legs: NIRSI's 64 deg turn, then AM607's 90 deg one with AM607 moved to 2.0-4.0 nm after NIRSI (AM608 4 nm
-- on, 90 deg right), on the approach's path at 270 kt TAS. The path is steep there (5563 to 4272 ft in 2.6 nm, and
-- the turn's cut: 15-17 ft in 0.02 nm), so the steps are taken against its own slope, in 0.01 nm steps: a change of the
-- turn holds the path for one step (its own fall in that step, 9-11 ft in 0.02 nm here; a frame's, about 1 ft, at
-- 50 Hz)
local function short_leg(leg)
    return function(route)
        route[AM607][5], route[AM607][6] = move(route[NIRSI][5], route[NIRSI][6], leg, 87.4)
        route[AM608][5], route[AM608][6] = move(route[AM607][5], route[AM607][6], 4, 177.4)
    end
end
for _, leg in ipairs({4.0, 3.2, 2.6, 2.4, 2.2, 2.0}) do
    for _, bank in ipairs({20, 25}) do
        r = fly({NIRSI, AM607}, {tas = 270, bank = bank, alt = 6000, from_fix = 5, after = 3, ds = 0.01},
            short_leg(leg))
        local all = true
        for _, p in ipairs(r) do if p.path == nil then all = false end end
        worst, where = largest_jump(r)
        check(all and math.abs(worst) <= 8, string.format("a %.1f nm leg from NIRSI's turn to AM607's, %d deg arcs: "
            .."largest step against the path's slope %+.0f ft in 0.01 nm at %.2f nm%s", leg, bank, worst, where or -1,
            all and "" or " (not on the approach's path all the way)"))
    end
end

-- 5. Far from the fix - 40 nm before NETOM at 480 kt, the cruise's distances - LNAV works the active fix's turn out
-- (its courses, the wind and the lead: getHeading twice) every 5 s at most, not every frame
do
    local route, d, ap = setup()
    local F = route[NETOM]
    local inCourse = bearing(route[SUGOL], F)
    d.simDR_TAS_mps, d.simDR_groundspeed = 480 / 1.94384, 480 / 1.94384
    d.simDR_pressureAlt1, d.simDR_radarAlt1 = 37000, 37000
    d.B747DR_fmscurrentIndex = NETOM
    for i = 1, #route do route[i][10] = (i == NETOM) end
    d.simDR_true_heading, d.simDR_ground_track_true = inCourse, inCourse
    local calls, getHeading = 0, ap.getHeading
    ap.getHeading = function(...) calls = calls + 1 return getHeading(...) end
    for n = 0, 249 do
        d.simDR_latitude, d.simDR_longitude = move(F[5], F[6], 40 - n * 480 / 3600 * 0.02, (inCourse + 180) % 360)
        d.simDRTime = d.simDRTime + 0.02
        ap.B747_lnav_update_vnav_hold(route)
    end
    ap.getHeading = getHeading
    check(calls <= 10, string.format("40 nm before NETOM, 5 s of frames at 50 Hz: its turn worked out every 5 s at "
        .."most (getHeading called %d times)", calls))
end

-- 6. HDG SEL in NETOM's turn, the 747 turning on round its arc (a heading on towards the next leg), sequenced abeam the
-- fix as with LNAV not engaged: the turn stays while the 747 is on its path; ended at the HDG SEL, the path ran
-- straight to the fix and stepped -740 to -820 ft where the fix was sequenced abeam (review 28 MAJOR 1)
for _, at in ipairs({6.0, 7.0, 8.0}) do
    r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6,
        hooks = {{s = at, fn = hdg_sel}}, seq_after = {s = at, mode = "abeam"}})
    worst, where = largest_step(r, 0, 1e9)
    check(math.abs(worst) <= 15, string.format("HDG SEL %.1f nm before NETOM, turning on round its arc: largest step "
        .."%+.0f ft in 0.02 nm at %.2f nm", 9 - at, worst, where or -1))
end
-- NETOM held for its turn (sequenced at the turn's start), HDG SEL 2 nm before it and LNAV again 1 nm on, round the
-- arc: the path continuous (-327 ft at the release)
local function lnav_on(d) d.B747DR_ap_lnav_state = 2 end
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, seq = "start",
    hooks = {{s = 7.0, fn = hdg_sel}, {s = 8.0, fn = lnav_on}}})
worst, where = largest_step(r, 0, 1e9)
check(math.abs(worst) <= 15, string.format("NETOM held for its turn, HDG SEL 2 nm before it, LNAV again 1 nm on: "
    .."largest step %+.0f ft in 0.02 nm at %.2f nm", worst, where or -1))
-- off LNAV's path in HDG SEL the turn fades out of the path with the 747's distance off it: kept until 0.5 nm off and
-- ended there, it stepped +330 to +500 ft at once (review 29 MAJOR 1). LNAV's arc drawn for a 300 kt target (324 kt
-- TAS, as for the highest ground speed in a wind), the 747 turning at 20 deg of bank for its 270 kt from 0.3 nm into it
local cinN = (bearing(rt[NETOM], rt[SUGOL]) + 180) % 360
local turnN = wrap(bearing(rt[NETOM], rt[NIRSI]) - cinN)
local leadL = afds.lnav_turn_anticipation_nm(324, 0, 0, 20, cinN, cinN + turnN, afds.LNAV_ROLL_RATE_DEG_PER_SEC, 324)
local R270 = (270 * 0.514444) ^ 2 / (9.80665 * math.tan(math.rad(20))) / 1852
local function target_300(d) d.simDR_autopilot_airspeed_is_mach, d.simDR_autopilot_airspeed_kts = 0, 300 end
local at = 9 - leadL + 0.3
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true,
    hooks = {{s = 0, fn = target_300}, {s = at, fn = hdg_sel}}, seq_after = {s = at, mode = "abeam"},
    maneuver = {s = at, radius = R270, turn = turnN}})
worst, where = largest_step(r, 0, 1e9)
check(math.abs(worst) <= 15, string.format("LNAV's arc drawn for 324 kt, HDG SEL 0.3 nm into it, the 747 turning at "
    .."20 deg inside it: largest step %+.0f ft in 0.02 nm at %.2f nm", worst, where or -1))
-- straight on before a 110 deg turn (NIRSI moved): HDG SEL 0.8 nm before LNAV's arc and 0.2 nm into it
local function turn_110(route)
    local cin = (bearing(route[NETOM], route[SUGOL]) + 180) % 360
    route[NIRSI][5], route[NIRSI][6] = move(route[NETOM][5], route[NETOM][6], 10.7, (cin - 110) % 360)
end
local lead110 = afds.lnav_turn_anticipation_nm(270, 0, 0, 20, cinN, cinN - 110, afds.LNAV_ROLL_RATE_DEG_PER_SEC, 270)
for _, off in ipairs({-0.8, 0.2}) do
    at = 9 - lead110 + off
    r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true,
        hooks = {{s = at, fn = hdg_sel}}, seq_after = {s = at, mode = "abeam"}}, turn_110)
    worst, where = largest_step(r, 0, 1e9)
    check(math.abs(worst) <= 15, string.format("a 110 deg turn at NETOM, HDG SEL %.1f nm %s LNAV's arc, straight on: "
        .."largest step %+.0f ft in 0.02 nm at %.2f nm", math.abs(off), off < 0 and "before" or "into", worst,
        where or -1))
end

-- 7. The fix of the turn carried on (prev) moved while the next turn carries it (NIRSI nudged 1 m north on a 3.2 nm leg
-- to AM607): the path takes out what that turn gave back; dropped from the turn in place, it stepped -105 ft at once
-- (review 28 NIT)
for _, at in ipairs({5.2, 5.8}) do
    r = fly({NIRSI, AM607}, {tas = 270, bank = 25, alt = 6000, from_fix = 5, after = 3, ds = 0.01,
        edit = {s = at, fn = function(route) route[NIRSI][5] = route[NIRSI][5] + 0.00001 end}}, short_leg(3.2))
    worst, where = largest_jump(r, at - 0.05, at + 0.1)
    check(math.abs(worst) <= 8, string.format("NIRSI nudged at %.1f nm while AM607's turn carries its turn: largest "
        .."step against the path's slope %+.0f ft in 0.01 nm at %.2f nm", at, worst, where or -1))
end

-- 8. LNAV engaged again, or let go, off the turn's path: the turn's fade moves with the distance flown, not at once;
-- set from the distance off the path in each frame, it stepped as LNAV's state changed (review 30 MAJOR 1). And a turn
-- that ends where the path's point is unchanged, while the step at its bisector is still being taken out, keeps that
-- going: dropped there, -503 ft at once (review 30 MINOR 2)
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true,
    hooks = {{s = 6.0, fn = hdg_sel}, {s = 8.5, fn = lnav_on}}, seq_after = {s = 6.0, mode = "abeam"}})
worst, where = largest_step(r, 0, 1e9)
check(math.abs(worst) <= 15, string.format("HDG SEL 3 nm before NETOM, straight on, LNAV again about 0.8 nm off its "
    .."path: largest step %+.0f ft in 0.02 nm at %.2f nm", worst, where or -1))
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true,
    hooks = {{s = 9 - lead110 + 0.2, fn = hdg_sel}, {s = 7.4, fn = lnav_on}},
    seq_after = {s = 9 - lead110 + 0.2, mode = "abeam"}}, turn_110)
worst, where = largest_step(r, 0, 1e9)
check(math.abs(worst) <= 15, string.format("a 110 deg turn, HDG SEL 0.2 nm into LNAV's arc, straight on, LNAV again "
    .."about 1.0 nm off its path: largest step %+.0f ft in 0.02 nm at %.2f nm", worst, where or -1))
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, offset = 1.0,
    hooks = {{s = 6.8, fn = hdg_sel}}, seq_after = {s = 6.8, mode = "abeam"}})
worst, where = largest_step(r, 0, 1e9)
check(math.abs(worst) <= 15, string.format("LNAV engaged 1 nm outside NETOM's turn, then HDG SEL 2.2 nm before NETOM: "
    .."largest step %+.0f ft in 0.02 nm at %.2f nm", worst, where or -1))
-- HDG SEL on a 2.6 nm leg while AM607's turn carries NIRSI's and the 747 flies on round NIRSI's arc: on the path,
-- the 747 is on it as LNAV takes it and the turn does not fade (taken from AM607's path alone, up to 0.27 nm off on
-- the arc here, 0.5 nm with arcs LNAV shares between the turns: faded 0.23; review 30 NIT, review 32 NIT 2)
r = fly({NIRSI, AM607}, {tas = 270, bank = 20, alt = 6000, from_fix = 5, after = 3, offsets = true,
    hooks = {{s = 5.3, fn = hdg_sel}}, seq_after = {s = 5.3, mode = "abeam"}}, short_leg(2.6))
local carried, offArc, onArc = 0, 0, 0
for _, p in ipairs(r) do
    if p.s > 5.3 and p.prev ~= 0 and p.arc == NIRSI then
        onArc = onArc + 1
        if p.fade > carried then carried = p.fade end
        if (p.off or 1) > offArc then offArc = p.off or 1 end
    end
end
check(onArc > 0 and offArc <= 0.05 and carried <= 0.1, string.format("HDG SEL on a 2.6 nm leg, the 747 on NIRSI's arc "
    .."while AM607's turn carries it (%d samples): off the turn's path at most %.2f nm, its fade at most %.2f", onArc,
    offArc, carried))
-- and HDG SEL straight on along that leg past AM607's arc: NIRSI's outbound leg - AM607's inbound - does not keep the
-- turn on its path; measured from it, AM607's turn lived on 0.9 nm longer (review 31 NIT)
for _, at in ipairs({5.6, 6.0}) do
    r = fly({NIRSI, AM607}, {tas = 270, bank = 20, alt = 6000, from_fix = 5, after = 4,
        hooks = {{s = at, fn = hdg_sel}}, seq_after = {s = at, mode = "abeam"}, vector = {s = at, heading = 87.4}},
        short_leg(2.6))
    local lastTurn = 0
    for _, p in ipairs(r) do
        if p.tfix == AM607 then lastTurn = p.s end
    end
    check(lastTurn <= 8.3, string.format("HDG SEL %.1f nm on, straight on past AM607's arc on a 2.6 nm leg: its turn "
        .."has ended by 8.3 nm (last at %.2f)", at, lastTurn))
end
-- HDG SEL 0.8 nm before LNAV's arc, the 747 turning at 15 deg of bank inside it: the step at NETOM's bisector (+623 ft)
-- is still being taken out where the turn ends at the same point, and goes on (-503 ft at once there). The path falls
-- about 7 ft in 0.01 nm while that step is taken out, so the steps are taken against its slope, in 0.01 nm steps (the
-- turn's end holds the path for one step, as in 4.) (after the turn is taken there: before it, no turn at all, NETOM is
-- passed abeam only 5 nm on - a sequence of LNAV not engaged, not the turn's)
local R15 = (270 * 0.514444) ^ 2 / (9.80665 * math.tan(math.rad(15))) / 1852
at = 5.3
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, noturn = true, ds = 0.01,
    hooks = {{s = at, fn = hdg_sel}}, seq_after = {s = at, mode = "abeam"},
    maneuver = {s = at, radius = R15, turn = turnN}})
local ended
for n = 2, #r do
    if ended == nil and r[n - 1].tfix ~= 0 and r[n].tfix == 0 then ended = r[n].s end
end
worst, where = largest_jump(r)
check(ended ~= nil and math.abs(worst) <= 15, string.format("HDG SEL 0.8 nm before LNAV's arc, the 747 turning at "
    .."15 deg of bank, the turn ended at %.2f nm: largest step against the path's slope %+.0f ft in 0.01 nm at %.2f nm",
    ended or -1, worst, where or -1))

-- a route edit making NETOM's 110 deg turn straight on (NIRSI moved on along the inbound course) 3 nm before NETOM,
-- with the turn's cut partly taken off: the path is the new route's at once, its step (+258 ft) over the 250 ft that
-- are taken out; blended up to 1000 ft as a turn's end at NETOM, it ran up to 258 ft off the new path (review 31
-- MINOR 1)
local function straight_on(route)
    local cin = (bearing(route[NETOM], route[SUGOL]) + 180) % 360
    route[NIRSI][5], route[NIRSI][6] = move(route[NETOM][5], route[NETOM][6], 10.7, cin)
end
local reference = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6}, straight_on)
r = fly({NETOM}, {tas = 270, bank = 20, alt = 8000, from_fix = 9, after = 6, edit = {s = 6.0, fn = straight_on}},
    turn_110)
worstDiff, worstAt = 0, nil
for n, p in ipairs(r) do
    local w = reference[n]
    if p.s >= 6.2 and p.path and w and w.path and math.abs(p.path - w.path) > math.abs(worstDiff) then
        worstDiff, worstAt = p.path - w.path, p.s
    end
end
check(math.abs(worstDiff) <= 20, string.format("NETOM's 110 deg turn edited to straight on 3 nm before it: the new "
    .."route's path at once, largest difference %+.0f ft at %.2f nm", worstDiff, worstAt or -1))
-- and a route edit while the step at a short leg's bisector is still being taken out (AM608 moved 1 nm back along its
-- leg 0.05-0.8 nm after AM607's bisector on a 2.0 nm leg, that step -270 ft): the edit's own step (+266 ft) is over
-- the 250 ft that are taken out, so the path is the new route's at once, the bisector's blend with it - as with the
-- blend's state cleared at the edit; the blend carried on through the edit, the path stepped -265 ft at once and ran
-- up to 265 ft off the new route's path (review 32 MINOR 1)
local function clear_blend(d, ap)
    upvalue(ap.setDescentVSpeed, "vnavPathBlend").lat = nil
    upvalue(ap.B747_vnav_approach_path, "approachPathBlend").lat = nil
end
local function am608_back(route)
    route[AM608][5], route[AM608][6] = move(route[AM607][5], route[AM607][6], 3, 177.4)
end
local function short_opts(extra)
    local o = {tas = 270, bank = 20, alt = 6000, from_fix = 5, after = 3, ds = 0.01}
    for k, v in pairs(extra or {}) do o[k] = v end
    return o
end
r = fly({NIRSI, AM607}, short_opts(), short_leg(2.0))
local switch
for _, p in ipairs(r) do
    if switch == nil and p.active == AM608 then switch = p.s end
end
check(switch ~= nil, "a 2.0 nm leg: AM608 made active at AM607's bisector")
for _, after in ipairs({0.05, 0.3, 0.8}) do
    local e = (switch or 0) + after
    r = fly({NIRSI, AM607}, short_opts({edit = {s = e, fn = am608_back}}), short_leg(2.0))
    reference = fly({NIRSI, AM607}, short_opts({edit = {s = e, fn = am608_back}, hooks = {{s = e, fn = clear_blend}}}),
        short_leg(2.0))
    worstDiff, worstAt = 0, nil
    for n, p in ipairs(r) do
        local w = reference[n]
        if p.s >= e and p.path and w and w.path and math.abs(p.path - w.path) > math.abs(worstDiff) then
            worstDiff, worstAt = p.path - w.path, p.s
        end
    end
    check(math.abs(worstDiff) <= 5, string.format("AM608 moved 1 nm back %.2f nm after AM607's bisector on a 2.0 nm "
        .."leg: the new route's path at once, largest difference %+.0f ft at %.2f nm", after, worstDiff, worstAt or -1))
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV turn latch tests passed: "..checks)
