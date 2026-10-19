-- Run from the repository root with Lua 5.1 or LuaJIT.
-- [B-14] VNAV's descent path through a fly-by turn (setDescentVSpeed) is continuous and takes the fix's altitude at
-- the turn's bisector, where the FMC sequences the fix. It measured the path straight to the point: to the fix held
-- for its turn (B747DR_vnav_hold_index) the arc's distance inside the fix (about 1 nm at NETOM's 86 deg) made the
-- path about 200 ft high at the bisector, and once the fix was let go there the straight distance to the next fix
-- cut the turn, so the path dropped by 300-380 ft at once (review 26: p27-line1's path error +351 ft at NETOM, 3 of
-- its 5 A/T changes). The production LNAV (B747_lnav_update_vnav_hold, the hold and its release at the bisector),
-- setDistances and setDescentVSpeed (approach_model.lua's loader) on the EHAM route, the 747 flown at 250 kt along
-- the inbound leg, the fly-by arc from the turn's lead (afds.lnav_turn_anticipation_nm at LNAV's 20 deg of bank, and
-- a tighter 25 deg one) and the outbound leg, NIRSI made the active fix at the turn's start as LNAV does; the path's
-- altitude is the 747's less the path error.
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

local SUGOL, NETOM, NIRSI = 5, 6, 7
local o = model.eham({active = NETOM, mcp_alt_ft = 2000, vnav_speed_kt = 250, at_mode = 3})
local route = o.route
local d = {}
local ap = model.load(d, {fmsData = {desspdtransalt = "10000", destranspd = "240", desspd = "270",
    desrestspd = "---", desrestalt = "-----", transalt = "18000", crzalt = "FL370"},
    B747_route_constraints = o.constraints})
model.set_datarefs(d, o, 0.05)
-- LNAV's leg logic and its hold of a fix for its turn, in the same namespace
for _, part in ipairs({{"function B747_getCurrentWayPoint(fmsO)", "local LNAV_MAX_PREEMPT_XTK_NM"},
        {"local LNAV_MAX_PREEMPT_XTK_NM", "function B747_ap_altitude(fms)"}}) do
    local code, name = slice(AP.."B747.70.xt.autopilot.lua", part[1], part[2])
    setfenv(assert(loadstring(code, name)), ap)()
end
local TAS_MS = 250 * 1.94384 ^ -1 * 1.16          -- 250 KIAS at 8,000 ft: about 290 kt TAS, no wind
d.simDR_TAS_mps, d.simDR_groundspeed, d.simDR_alpha_deg, d.B747DR_airspeed_Vmc = TAS_MS, TAS_MS, 2, 150
d.simDR_ind_airspeed_kts_pilot, d.simDR_ias_pilot = 250, 250
d.simDR_onGround, d.simDR_autopilot_bank_limit, d.simDR_autopilot_bank_angles = 0, 4, {[0] = 5, 10, 15, 20, 25, 30}
d.B747DR_ap_lnav_state, d.B747DR_ap_approach_mode, d.B747DR_ap_lnav_xtk_target = 2, 0, 0
d.B747DR_ap_lnav_xtk_error, d.B747DR_CAS_caution_status, d.simDR_override_fms_progress = 0, {}, 1
d.simDR_pressureAlt1, d.simDR_radarAlt1, d.simDR_vvi_fpm_pilot = 8000, 8000, -1000
d.B747BR_cruiseAlt, d.B747BR_tod = 37000, 400
d.B747BR_todLat, d.B747BR_todLong = route[2][5], route[2][6]
ap.B747_reset_vnav_energy()

-- the geometry round NETOM (east/north nm from it), its courses at NETOM as LNAV takes them
local F = route[NETOM]
local inCourse = (ap.getHeading(F[5], F[6], route[SUGOL][5], route[SUGOL][6]) + 180) % 360
local outCourse = ap.getHeading(F[5], F[6], route[NIRSI][5], route[NIRSI][6])
local turn = ((outCourse - inCourse + 540) % 360) - 180          -- + right
local tas_kt = TAS_MS * 1.94384
local function unit(h) return math.sin(math.rad(h)), math.cos(math.rad(h)) end
local ie, inn = unit(inCourse)
local oe, on = unit(outCourse)
local side = turn > 0 and 1 or -1
local function at(east, north)
    local dist = math.sqrt(east * east + north * north)
    if dist < 1e-9 then return F[5], F[6] end
    return ap.movePoint(F[5], F[6], dist, math.deg(math.atan2(east, north)) % 360)
end

-- flies the inbound leg, the fly-by arc for bank_deg (from its lead before NETOM to as far past it) and the outbound
-- leg in 0.02 nm steps, the profile rebuilt every 8 (2 s); the samples of the hold, the path's altitude and the target
local function fly(bank_deg)
    local lead = afds.lnav_turn_anticipation_nm(tas_kt, 0, 0, bank_deg, inCourse, outCourse,
        afds.LNAV_ROLL_RATE_DEG_PER_SEC, tas_kt)
    local radius = lead / math.tan(math.rad(math.abs(turn) / 2))
    local se, sn = -lead * ie, -lead * inn                           -- the turn's start
    local ce, cn = se + side * radius * inn, sn - side * radius * ie -- the arc's centre
    local arcLen = radius * math.rad(math.abs(turn))
    local function position(s)
        if s <= 6 then return se - (6 - s) * ie, sn - (6 - s) * inn, inCourse end
        if s <= 6 + arcLen then
            local a = (s - 6) / radius
            local re, rn = se - ce, sn - cn
            local c, sa = math.cos(-side * a), math.sin(-side * a)
            return ce + re * c - rn * sa, cn + re * sa + rn * c, inCourse + side * math.deg(a)
        end
        local ee, en = lead * oe, lead * on
        return ee + (s - 6 - arcLen) * oe, en + (s - 6 - arcLen) * on, outCourse
    end
    local samples, active = {}, NETOM
    d.B747DR_fmscurrentIndex = NETOM
    ap.B747_lnav_update_vnav_hold(route)
    local s, step = 0, 0
    while s <= 6 + arcLen + 4 do
        local east, north, track = position(s)
        d.simDR_latitude, d.simDR_longitude = at(east, north)
        d.simDR_true_heading, d.simDR_ground_track_true = track % 360, track % 360
        if active == NETOM and s >= 6 then active = NIRSI end        -- LNAV makes NIRSI active at the turn's start
        for i = 1, #route do route[i][10] = (i == active) end
        d.B747DR_fmscurrentIndex = active
        ap.B747_lnav_update_vnav_hold(route)
        -- the profile every 2 s (8 steps at 290 kt), as B747_fltmgmt_setILS builds it; the path every step
        if step % 8 == 0 then ap.setDistances(route) end
        ap.setDescentVSpeed(route)
        samples[#samples + 1] = {s = s, east = east, north = north, hold = d.B747DR_vnav_hold_index,
            path = d.simDR_pressureAlt1 - d.B747BR_fpe, target = d.B747DR_ap_vnav_target_alt}
        s, step = s + 0.02, step + 1
    end
    local held, released = nil, nil
    for k, q in ipairs(samples) do
        if q.hold == NETOM and held == nil then held = k end
        if held and q.hold == 0 and released == nil then released = k end
    end
    local worst, where = 0, samples[1]
    for k = 2, #samples do
        local step = math.abs(samples[k].path - samples[k - 1].path)
        if step > worst then worst, where = step, samples[k] end
    end
    return samples, held, released, worst, where
end

-- 1. the arc LNAV draws (its bank limit, 20 deg here)
local samples, held, released, worst, where = fly(20)
check(held ~= nil and released ~= nil, "LNAV held NETOM from its turn's start and let it go at the bisector")
if held and released then
    check(worst <= 15, string.format("the path through NETOM's %.0f deg turn is continuous: largest step %.0f ft "
        .."in 0.02 nm at %.2f nm (the release at the bisector: %.2f nm)", math.abs(turn), worst, where.s,
        samples[released].s))
    local b = samples[released]
    check(math.abs(b.path - F[9]) <= 30, string.format("at the bisector the path is at NETOM's %d ft: %.0f ft", F[9],
        b.path))
    -- before the turn and after it, on the legs, the path as before: the distance to the point
    local first, last = samples[1], samples[#samples]
    local g_in = (route[SUGOL][9] - F[9]) / ap.getDistance(route[SUGOL][5], route[SUGOL][6], F[5], F[6])
    local lat1, lon1 = at(first.east, first.north)
    local want_first = F[9] + ap.getDistance(lat1, lon1, F[5], F[6]) * g_in
    check(math.abs(first.path - want_first) <= 5, string.format("6 nm before the turn on the inbound leg: %.0f ft "
        .."(the leg's path %.0f)", first.path, want_first))
    local leg = ap.getDistance(F[5], F[6], route[NIRSI][5], route[NIRSI][6])
    local g_out = (F[9] - route[NIRSI][9]) / leg
    local lat, lon = at(last.east, last.north)
    local want_last = route[NIRSI][9] + ap.getDistance(lat, lon, route[NIRSI][5], route[NIRSI][6]) * g_out
    check(math.abs(last.path - want_last) <= 10, string.format("4 nm along the outbound leg after the turn: %.0f ft "
        .."(the leg's path %.0f)", last.path, want_last))
end
-- 2. a tighter arc than LNAV's lead (25 deg flown, 20 deg drawn): still continuous
samples, held, released, worst, where = fly(25)
check(held ~= nil and released ~= nil and worst <= 15, string.format("a 25 deg arc against LNAV's 20 deg lead: "
    .."largest step %.0f ft in 0.02 nm at %.2f nm", worst, where.s))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV turn path tests passed: "..checks)
