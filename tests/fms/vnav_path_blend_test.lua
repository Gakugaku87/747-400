-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_path_blend_test.lua
-- (2026-11-09) The descent's path rounded at its breaks (B747.68.vnav_model.lua
-- path_blend, PATH_BLEND_S and PATH_LEAD_S: estimates; notes/ATA-34-61-FMC.md
-- §160), flown in a closed loop: the FMC's VNAV PTH law (M.update), the
-- AFDS's VNAV V/S law (B747.70.afds_pitch_model.lua, within its 0.05 g) and
-- an airplane lagged as X-Plane's 747 in s107 (the attitude 2 s behind the
-- command, the flight path 3 s behind the attitude; also 1.5 times as slow).
-- s273's third run: from the idle descent's 2,700 fpm into the 500 fpm
-- deceleration (FCOM p.1264) at FL294 the airplane went 386 ft under the
-- path. Here, on the old law (no rounding) 582 ft under it; rounded within
-- 60 ft of the path, within 0.05 g; the T/D's corner (level into the idle
-- line, the level deceleration before it) and two breaks in a row the same.
local T = dofile("tests/lib/check.lua")("vnav_path_blend")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.pred_model.lua")
local V = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vnav_model.lua")
local AP = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_pitch_model.lua")

local DT = 0.1
local GS = 480                          -- kt, no wind: the true airspeed too
local G_FT = 9.80665 / 0.3048
local clb = {cas = 340, mach = 0.84, trans_cas = 250, trans_alt = 10000}
local des = {cas = 290, mach = 0.84, trans_cas = 240, trans_alt = 10000}

-- fly from e0 NM to the E/D down to e1 on path, from alt0 (on the path or
-- at CRZ ALT); the deviation from the FMC's path (its path_dev) and from
-- the polyline, the most normal acceleration
local function fly(path, crz, e0, e1, alt0, tau_t, tau_g)
    local s = V.new()
    local ap = AP.new()
    local i = AP.inputs()
    i.active, i.tas, i.mode = true, GS, "VNAV"
    local e, v = e0, GS * 1852 / 3600
    i.alt = alt0
    local h0, g0 = V.path_at(path, e0)
    local vs0 = (alt0 < crz - 1) and -g0 * GS / 60 or 0
    local gam = math.deg(math.asin(vs0 / 60 * 0.3048 / v))
    i.vs, i.pitch = vs0, gam + 2
    local r = {dmin = 1e9, dmax = -1e9, pmin = 1e9, pmax = -1e9, g = 0, des = false}
    local last = i.vs
    while e > e1 do
        local o = V.update(s, {P = P, sched = PM.schedule, crz = PM.crz_mach, alt = i.alt, vs = i.vs, gs = GS,
            ground = false, active = true, kg = 300000, crz_alt = crz, mcp_alt = 10000, clb = clb, des = des,
            crzspd = {mach = 0.85}, path = path, d_ed = e})
        if o.vs then
            i.vnav_law, i.vnav_vs = "VS", o.vs
        else
            i.vnav_law, i.vnav_alt = "ALT", o.alt or crz
        end
        local c = AP.update(ap, i, DT)
        if c then i.pitch = i.pitch + (c - i.pitch) * DT / tau_t end
        gam = gam + ((i.pitch - 2) - gam) * DT / tau_g
        i.vs = v * math.sin(math.rad(gam)) / 0.3048 * 60
        i.alt = i.alt + i.vs / 60 * DT
        e = e - GS * DT / 3600
        if o.phase == "DES" and o.path_dev then
            r.des = true
            r.dmin, r.dmax = math.min(r.dmin, o.path_dev), math.max(r.dmax, o.path_dev)
            local hp = math.min(V.path_at(path, e), crz)
            r.pmin, r.pmax = math.min(r.pmin, i.alt - hp), math.max(r.pmax, i.alt - hp)
        end
        r.g = math.max(r.g, math.abs(i.vs - last) / 60 / DT / G_FT)
        last = i.vs
    end
    return r
end

local function blend(on)
    if on then
        V.PATH_BLEND_S, V.PATH_LEAD_S, V.TD_BLEND_MAX_S = 30, 6, 90
    else
        V.PATH_BLEND_S, V.PATH_LEAD_S, V.TD_BLEND_MAX_S = 0, 0, 0
    end
end

-- s273's: the idle line (337.5 ft/NM, 2,700 fpm at 480 kt) into the
-- deceleration's 500 fpm (62.5 ft/NM) at 27,500 ft
local pD = {e = {0, 30, 70}, h = {27500 - 62.5 * 30, 27500, 27500 + 337.5 * 40}, k = {"decel", "decel", "idle"}}
local function on_pD(e) return 27500 + (e - 30) * 337.5 end
blend(false)
local r = fly(pD, 41000, 45, 15, on_pD(45), 2, 3)
T.check(r.dmin < -400, string.format("the old law (no rounding): %.0f ft under the path into the deceleration (s273: 386)", r.dmin))
blend(true)
for _, lag in ipairs({{2, 3}, {3, 4.5}, {1, 1.5}}) do
    r = fly(pD, 41000, 45, 15, on_pD(45), lag[1], lag[2])
    T.check(r.dmin > -60 and r.dmax < 60, string.format("lagged %g/%g s: within 60 ft of the rounded path (%.0f to %.0f ft)",
        lag[1], lag[2], r.dmin, r.dmax))
    T.check(r.g <= 0.05, string.format("lagged %g/%g s: within 0.05 g (%.3f)", lag[1], lag[2], r.g))
    T.check(r.pmax < 200 and r.pmin > -60, string.format("lagged %g/%g s: off the polyline %.0f to %.0f ft (the rounding, over it at the break)",
        lag[1], lag[2], r.pmin, r.pmax))
end

-- the T/D's corner: level at FL370, the level deceleration (td_decel 5 NM)
-- before it, into the idle line
local pT = {e = {0, 30, 70}, h = {27500 - 62.5 * 30, 27500, 27500 + 337.5 * 40}, k = {"decel", "decel", "idle"},
    td_decel = 5}
local ecT = 30 + (37000 - 27500) / 337.5
blend(false)
r = fly(pT, 37000, ecT + 12, 32, 37000, 2, 3)
T.check(r.des and r.dmax > 400, string.format("the old law: %.0f ft over the path past the T/D", r.dmax))
blend(true)
r = fly(pT, 37000, ecT + 12, 32, 37000, 2, 3)
T.check(r.dmin > -60 and r.dmax < 80, string.format("rounded: within 80 ft of the path past the T/D (%.0f to %.0f ft)", r.dmin, r.dmax))
T.check(r.g <= 0.05, string.format("within 0.05 g (%.3f)", r.g))

-- (2026-11-09) a T/D without a level deceleration (s273's fourth run: M.858
-- on from FL370) into a steep idle line, 4,000 fpm (500 ft/NM at 480 kt):
-- the rounding over 59 s (0.035 g) and the descent begun 4.7 NM before the
-- corner. Before (begun at the corner) 1,448 ft over the path in X-Plane
local pN = {e = {0, 30, 60}, h = {27500 - 62.5 * 30, 27500, 27500 + 500 * 30}, k = {"decel", "decel", "idle"}}
local ecN = 30 + (37000 - 27500) / 500
blend(false)
r = fly(pN, 37000, ecN + 12, 32, 37000, 2, 3)
T.check(r.des and r.dmax > 1000, string.format("no level deceleration, the old law: %.0f ft over the path past the T/D", r.dmax))
blend(true)
r = fly(pN, 37000, ecN + 12, 32, 37000, 2, 3)
T.check(r.dmin > -60 and r.dmax < 80, string.format("no level deceleration, rounded: within 80 ft of the path (%.0f to %.0f ft)", r.dmin, r.dmax))
T.check(r.g <= 0.05, string.format("within 0.05 g (%.3f)", r.g))

-- two breaks in a row: the idle line, a constraints' line (1,650 fpm,
-- 206 ft/NM) for 5 NM, the deceleration's 500 fpm
local pL = {e = {0, 30, 35, 75}, h = {27500 - 62.5 * 30, 27500, 27500 + 206.25 * 5, 27500 + 206.25 * 5 + 337.5 * 40},
    k = {"decel", "decel", "spd", "idle"}}
local function on_pL(e) return 27500 + 206.25 * 5 + (e - 35) * 337.5 end
r = fly(pL, 45000, 50, 15, on_pL(50), 2, 3)
T.check(r.dmin > -60 and r.dmax < 60, string.format("two breaks 5 NM apart: within 60 ft (%.0f to %.0f ft)", r.dmin, r.dmax))
T.check(r.g <= 0.05, string.format("within 0.05 g (%.3f)", r.g))
T.done()
