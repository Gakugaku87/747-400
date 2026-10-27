-- Run from the repository root with LuaJIT: luajit tests/fms/lnav_pturn_test.lua
-- The FMC's procedure turn (6-1/6-2 step 7f, estimate: notes/ATA-34-61-FMC.md
-- §41): the LNAV model
-- (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua)
-- on a PI leg of the path model, in closed loop with the airplane of
-- tests/lib/lnav_sim.lua: over the fix outbound, the 45 degree leg, the
-- 180 degree turn its way, back onto the inbound course (the CF after it
-- captured), within the procedure's distance; right and left; the longer
-- outbound leg of a wider limit; close to the shape on the way out, round
-- the corner onto the 45 degree leg (a fly-by arc) and in the turn.
local T = dofile("tests/lib/check.lua")("lnav_pturn")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.lnav_model.lua")

local VAR = -7
local SIM = dofile("tests/lib/lnav_sim.lua")(N, R, P, L, VAR)
local route, plane, fly = SIM.route, SIM.plane, SIM.fly
local function wrap180(a) return (a + 180) % 360 - 180 end
local function mag(t) return (t - VAR) % 360 end
local function fmt(v) return string.format("%.2f", v) end

-- the procedure turn's fix F, the final approach on 270 (true) from it to
-- the runway RW; the airplane from the west over F
local F = {ident = "FFFFF", lat = 35.5, lon = 140.0}
local RW = {ident = "RW27", kind = "RWY", lat = 35.5, lon = P.point(F, 270, 8).lon}
local function legs(turn, limit)
    local pc = turn == "R" and 45 or 135     -- 45 degrees off the outbound 090
    return {
        {via = "DIRECT", fix = F},
        {via = "APPR", proc = "APPR", pt = "PI", fix = F, crs = mag(pc), turn = turn, dist = limit},
        {via = "APPR", proc = "APPR", pt = "CF", fix = F, crs = mag(270)},
        {via = "APPR", proc = "APPR", pt = "CF", fix = RW, crs = mag(270)},
    }
end
-- fly the turn: from 12 nm west of F on 090 at 220 kt; what was seen
local function fly_pt(turn, limit)
    local p0 = P.point(F, 270, 12)
    local st = route(legs(turn, limit), P.point(F, 270, 20))
    local s = L.new(P)
    local a = plane({lat = p0.lat, lon = p0.lon, hdg = 90, tas = 220, alt = 4000})
    local seen = {far = 0, bank_max = 0, roll_sign = 0, phases = {}, trk_end = nil, xt_cf = 0, xt_out = 0,
        xt_turn = 0}
    local on_cf = false
    local log = fly(st, s, a, 900, {each = function(t, s2, air, path)
        local _, d = P.course(F, air)
        if s2.ptn then
            seen.far = math.max(seen.far, d)
            local ph = s2.ptn.phase
            if seen.phases[#seen.phases] ~= ph then seen.phases[#seen.phases + 1] = ph end
            if ph == "turn" and math.abs(s2.roll) > 5 then seen.roll_sign = s2.roll > 0 and 1 or -1 end
            -- the outbound leg settled first (from 2 nm past the fix)
            if (ph == "out" and d > 2) or ph == "corner" or ph == "leg45" then
                seen.xt_out = math.max(seen.xt_out, math.abs(s2.xtk))
            elseif ph == "turn" then
                seen.xt_turn = math.max(seen.xt_turn, math.abs(s2.xtk))
            end
            seen.t = s2.ptn.t
        end
        seen.bank_max = math.max(seen.bank_max, math.abs(s2.roll))
        local e = path[1]
        if e and e.kind == "line" and e.leg and st.rte.legs[1].fix == F and st.rte.legs[1].pt == "CF" then
            on_cf = true
            local _, at = P.track(F, 90, air)
            -- settled on the final course 3 nm before F
            if at < 3 then seen.xt_cf = math.max(seen.xt_cf, math.abs(s2.xtk)); seen.trk_end = air.trk end
        end
        return #st.rte.legs == 1 and st.rte.legs[1].fix == RW
    end})
    seen.log, seen.on_cf = log, on_cf
    return seen, st
end

local seen, st = fly_pt("R", 10)
T.check(table.concat(seen.phases, " ") == "out corner leg45 turn back", "the phases in turn: " .. table.concat(seen.phases, " "))
T.check(seen.xt_out < 0.2, "out, round the corner and on the 45 degree leg within 0.2 nm: " .. fmt(seen.xt_out))
T.check(seen.xt_turn < 0.2, "in the 180 degree turn within 0.2 nm: " .. fmt(seen.xt_turn))
T.check(seen.far <= 10 and seen.far > 8, "within 10 nm of the fix (the procedure's distance), " .. fmt(seen.far))
T.equal(seen.roll_sign, 1, "the 180 degree turn to the right (the leg's turn)")
T.check(seen.bank_max <= 25.01, "25 degrees of bank at most: " .. fmt(seen.bank_max))
T.check(seen.on_cf, "then the CF into the fix")
T.check(seen.trk_end and math.abs(wrap180(seen.trk_end - 270)) < 2, "inbound on 270: " .. fmt(seen.trk_end or -1))
T.check(seen.xt_cf < 0.3, "on the final course 3 nm out: " .. fmt(seen.xt_cf))
T.equal(st.rte.legs[1].fix, RW, "the procedure turn and the fix sequenced, the runway the active waypoint")
local t = seen.t
local _, dx = P.course(F, t.x)
T.check(math.abs(P.track(F, 90, t.x)) < 0.01 and dx > 4, "the leg back meets the inbound course " .. fmt(dx) .. " nm out")

local seen2 = fly_pt("L", 10)
T.equal(seen2.roll_sign, -1, "a left procedure turn: the turn to the left")
T.check(seen2.far <= 10 and seen2.trk_end and math.abs(wrap180(seen2.trk_end - 270)) < 2, "within 10 nm, inbound on 270")
T.check(seen2.xt_out < 0.2 and seen2.xt_turn < 0.2, "left: close to the shape out and in the turn: " .. fmt(seen2.xt_out)
    .. ", " .. fmt(seen2.xt_turn))
T.check(P.track(F, 90, seen2.t.p) > 0, "its 45 degree leg on the right of the outbound course (the turn's other side)")

-- the ND's line (X-Plane's flight plan): the shape after the PI's fix
local r0 = {legs = legs("R", 10), passed = {}}
local path0 = P.build(r0.legs, P.point(F, 270, 20), {var = function() return VAR end, alt = 4000})
local txt = R.to_fms(r0, "2610", P.shape(path0, 220))
local tilde = 0
for _ in txt:gmatch("\n28 ~ DRCT") do tilde = tilde + 1 end
T.check(txt:find("\n11 FFFFF DRCT [^\n]*\n11 FFFFF DRCT [^\n]*\n28 ~ DRCT") and tilde == 9,
    "X-Plane's flight plan: the PI's fix, then its nine points (" .. tilde .. ")")

local seen3 = fly_pt("R", 15)
T.check(seen3.t.dout > seen.t.dout + 4 and seen3.far <= 15 and seen3.far > 13,
    "15 nm: a longer outbound leg (" .. fmt(seen3.t.dout) .. " nm), within 15 nm (" .. fmt(seen3.far) .. ")")

T.done()
