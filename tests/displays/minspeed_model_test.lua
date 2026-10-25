-- Run from the repository root with LuaJIT: luajit tests/displays/minspeed_model_test.lua
-- The minimum speed model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.minspeed_model.lua, 5-2 step 3b) without
-- X-Plane: the stick shaker speeds against the FCTM's charts (p.261-262),
-- the load factor, the minimum maneuvering speed's rules (FCOM p.973), the
-- buffet onset against the FCOM's maximum operating altitudes (PI.11.1),
-- the maximum maneuvering speed (FCOM p.969), the stick shaker and AIRSPEED
-- LOW (FCOM p.1556, p.1605).
local T = dofile("tests/lib/check.lua")("minspeed_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.minspeed_model.lua")

local function run(set)
    local s, inp = M.new(), M.inputs()
    inp.weight_kg, inp.alt_ft, inp.flap_deg, inp.nz, inp.air = 300000, 10000, 0, 1, true
    inp.vref30, inp.vmax, inp.ra_ft = 157, 365, 5000
    for k, v in pairs(set or {}) do inp[k] = v end
    local out = M.update(s, inp, 10)        -- a long step settles the smoothing
    return out, s, inp
end

-- the air data conversions
local d = M.delta(31000)
T.near(M.mach_to_cas(M.cas_to_mach(300, d), d), 300, 1e-6, "CAS -> Mach -> CAS")
T.near(M.mach_to_cas(0.861, M.delta(31000)), 322, 1.5, "M .861 at 31,000 ft is 322 KIAS (FCOM PI.11.2)")

-- the stick shaker speeds at 10,000 ft and 1 g: the FCTM's charts
local FCTM = {          -- flaps: {weight t, kt}
    [0] = {{200, 163.5}, {300, 204.7}, {400, 240.6}},
    [10] = {{200, 123.8}, {300, 153.6}, {400, 178.8}},
    [20] = {{200, 118.3}, {300, 146.3}, {400, 170.1}},
    [30] = {{200, 110.7}, {300, 135.1}, {400, 159.6}},
}
for flap, pts in pairs(FCTM) do
    for _, p in ipairs(pts) do
        local out = run({flap_deg = flap, weight_kg = p[1] * 1000})
        T.near(out.vss, p[2], 1.1, string.format("flaps %d, %d t: the FCTM's %.1f kt", flap, p[1], p[2]))
    end
end
-- flaps 25: VREF25 / 1.23 at 10,000 ft times the flaps 20-30 ratio (estimate)
local v20, v25, v30 = run({flap_deg = 20}).vss, run({flap_deg = 25}).vss, run({flap_deg = 30}).vss
T.check(v25 < v20 and v25 > v30, "flaps 25 between 20 and 30 (" .. v25 .. ")")
T.near(v25, (164 + 2.5) / 1.23 * 1.04, 1.0, "flaps 25 at 300 t")
-- between the detents by the flap angle
local v10, v15 = run({flap_deg = 10}).vss, run({flap_deg = 15}).vss
T.near(v15, (v10 + v20) / 2, 0.3, "15 deg: halfway between 10 and 20")
-- a lower altitude: lower (Mach), like VREF's 1 kt per 4,000 ft (FCOM PI.10.2)
local v30sl = run({flap_deg = 30, alt_ft = 0}).vss
T.check(v30sl < v30 and v30 - v30sl < 3, "flaps 30 at sea level 0-3 kt lower (" .. v30 - v30sl .. ")")

-- the load factor raises the minimum speed (about the square root at low Mach)
local v1 = run({flap_deg = 30}).vss
local v13 = run({flap_deg = 30, nz = 1.3}).vss
T.near(v13 / v1, math.sqrt(1.3), 0.015, "1.3 g: about sqrt(1.3) higher (the charts' Mach trend adds a little)")

-- the minimum maneuvering speed (FCOM p.973)
local out = run({flap_deg = 20})
T.near(out.vmin_man, run({flap_deg = 20, nz = 1.3}).vss, 0.05, "flaps down: 1.3 g to the stick shaker")
out = run({flap_deg = 0, vref30 = 157})
T.near(out.vmin_man, 237, 1e-9, "flaps up below 20,200 ft: VREF30 + 80 when less than 1.3 g to the shaker")
out = run({flap_deg = 0, vref30 = 170})
T.near(out.vmin_man, run({flap_deg = 0, nz = 1.3}).vss, 0.05, "flaps up: 1.3 g to the shaker when less than VREF30 + 80")
out = run({flap_deg = 0, vref30 = 157, alt_ft = 25000})
T.check(out.vmin_man > 237 + 5, "above 20,200 ft: 1.3 g to low speed buffet, no VREF30 + 80 (" .. out.vmin_man .. ")")

-- the buffet onset: the FCOM's maximum operating altitudes (PI.11.1) put
-- 1.30 g at M .86 for 400 t at 32,100 ft and 1.50 g for 300 t at 35,100 ft
T.near(M.low_mach(1.3 * 400000 / M.delta(32100), 0), 0.86, 0.004, "400 t, 32,100 ft: 1.3 g at M .86")
T.near(M.low_mach(1.5 * 300000 / M.delta(35100), 0), 0.86, 0.004, "300 t, 35,100 ft: 1.5 g at M .86")
T.check(M.low_mach(1.3 * 400000 / M.delta(30000), 0) < 0.83, "400 t, 30,000 ft: 1.3 g below M .83")
-- cruise: 300 t at FL350, LRC M .861 is 295 KIAS (PI.11.2): the minimum
-- maneuvering speed below it, the minimum speed well below
out = run({alt_ft = 35000, vmax = 330})
T.check(out.vmin_man < 295 and out.vmin_man > 250, "FL350, 300 t: minimum maneuvering below LRC (" .. out.vmin_man .. ")")
T.check(out.vss < out.vmin_man - 20, "FL350, 300 t: the minimum speed lower (" .. out.vss .. ")")

-- the maximum maneuvering speed: not at low altitude; near the 1.3 g
-- ceiling, above the minimum maneuvering speed and below the maximum speed
out = run({alt_ft = 10000})
T.check(not out.show_vmax_man and out.vmax_man == 365, "10,000 ft: no maximum maneuvering speed (the maximum speed)")
out = run({weight_kg = 400000, alt_ft = 32500, vmax = 340})
T.check(out.show_vmax_man, "400 t at 32,500 ft: the maximum maneuvering speed shown")
T.check(out.vmax_man > out.vmin_man and out.vmax_man < 340, "between the minimum maneuvering and the maximum speed ("
    .. out.vmin_man .. ", " .. out.vmax_man .. ")")
out = run({weight_kg = 400000, alt_ft = 36000, vmax = 340})
T.near(out.vmax_man, out.vmin_man, 12, "above the 1.3 g ceiling: the two bands meet")

-- the stick shaker: the lift needed above the limit at the present Mach
local vss = run({flap_deg = 30}).vss
local s, inp
out, s, inp = run({flap_deg = 30, mach = M.cas_to_mach(vss + 2, M.delta(10000))})
T.check(not out.shaker, "2 kt above the shaker speed: no shaker")
inp.mach = M.cas_to_mach(vss - 1, M.delta(10000))
out = M.update(s, inp, 1)
T.check(out.shaker, "1 kt below: the shaker")
inp.mach = M.cas_to_mach(vss + 0.5, M.delta(10000))
out = M.update(s, inp, 1)
T.check(out.shaker, "0.5 kt above: still on (hysteresis)")
inp.mach = M.cas_to_mach(vss + 3, M.delta(10000))
out = M.update(s, inp, 1)
T.check(not out.shaker, "3 kt above: off")
inp.mach, inp.air = M.cas_to_mach(vss - 10, M.delta(10000)), false
out = M.update(s, inp, 1)
T.check(not out.shaker, "on the ground: no shaker")
inp.air, inp.nz = true, 1.0
inp.mach = M.cas_to_mach(vss + 5, M.delta(10000))
out = M.update(s, inp, 1)
T.check(not out.shaker, "5 kt above at 1 g: no shaker")
inp.nz = 1.3
out = M.update(s, inp, 1)
T.check(out.shaker, "5 kt above at 1.3 g: the shaker (the angle of attack rises with the load factor)")

-- AIRSPEED LOW and the amber box: below the minimum maneuvering speed with
-- its band shown, above 100 ft RA
out, s, inp = run({flap_deg = 20, show_mins = true})
inp.cas = out.vmin_man - 1
T.check(M.update(s, inp, 1).airspeed_low, "below the minimum maneuvering speed: AIRSPEED LOW")
inp.cas = out.vmin_man + 1
T.check(not M.update(s, inp, 1).airspeed_low, "above: none")
inp.cas, inp.show_mins = out.vmin_man - 10, false
T.check(not M.update(s, inp, 1).airspeed_low, "the band not shown yet (before the first flap retraction): none")
inp.show_mins, inp.ra_ft = true, 50
T.check(not M.update(s, inp, 1).airspeed_low, "below 100 ft RA: none")

-- the pitch limit indication (step 4c; FCOM p.975: the stick shaker point,
-- 109 with the flaps not up): degrees of angle of attack to the shaker
local d10 = M.delta(10000)
out, s, inp = run({flap_deg = 20})
local vss20 = out.vss
inp.cas = vss20 * 1.3
inp.mach = M.cas_to_mach(inp.cas, d10)
out = M.update(s, inp, 10)
T.check(out.show_pli, "flaps 20 at 1.3 Vss: the PLI shown")
T.check(out.pli_deg > 7 and out.pli_deg < 12, "1.3 Vss: about 7 to 12 degrees above the airplane symbol (" .. out.pli_deg .. ")")
inp.cas = vss20
inp.mach = M.cas_to_mach(inp.cas, d10)
out = M.update(s, inp, 10)
T.near(out.pli_deg, 0, 0.3, "at the shaker speed: at the airplane symbol (the shaker's point)")
inp.cas = vss20 * 0.97
inp.mach = M.cas_to_mach(inp.cas, d10)
out = M.update(s, inp, 10)
T.check(out.pli_deg < 0 and M.update(s, inp, 0.1).shaker, "below it: under the airplane symbol, the shaker on")
inp.nz, inp.cas = 1.3, vss20 * math.sqrt(1.3)
inp.mach = M.cas_to_mach(inp.cas, d10)
out = M.update(s, inp, 10)
T.near(out.pli_deg, 0, 0.5, "1.3 g at sqrt(1.3) Vss: at the airplane symbol (the load factor counts)")
out, s, inp = run({flap_deg = 0})
inp.cas = out.vss * 1.3
inp.mach = M.cas_to_mach(inp.cas, d10)
T.check(not M.update(s, inp, 10).show_pli, "flaps up: no PLI (109)")
out, s, inp = run({flap_deg = 20, air = false, alt_ft = 0, alpha_deg = 0})
inp.cas = 120
inp.mach = M.cas_to_mach(120, M.delta(0))
out = M.update(s, inp, 1)
T.check(out.show_pli and out.pli_deg > 8 and out.pli_deg < 16, "on the ground at 120 kt: the shaker's angle of attack above (" .. out.pli_deg .. ")")
inp.cas = 40
inp.mach = M.cas_to_mach(40, M.delta(0))
T.check(not M.update(s, inp, 1).show_pli, "at 40 kt: not shown")
inp.cas, inp.air_data = 120, false
T.check(not M.update(s, inp, 1).show_pli, "no valid air data: not shown")

T.done()
