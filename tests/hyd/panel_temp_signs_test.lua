-- Run from the repository root with LuaJIT: luajit tests/hyd/panel_temp_signs_test.lua
-- (2026-11-24, the stage 4 review's PNL-8 = SYS-4 and SYS-5) The minus signs
-- of the custom acf's panel temperatures. gen_LED shows the absolute value
-- (ROUNDING ROUND_ROUND), so each LED whose temperature can go below zero
-- has the fuel temperature's sign (IMAGE CRT Displays/EICAS Upper/
-- TAT_negSign, gen_rotary with SHOW_LESS) next to its digits, with the LED's
-- HIDE, light mode, rheostat and bus:
--  * the hydraulic fluid (STAT's and the HYD synoptic's LED Temp 1-4,
--    laminar/B747/hydraulics/temp_N[0], 3 digits right-aligned, 8 px a
--    digit): two digits (-9.5 and under) the sign in the cell before the
--    tens (x - 2.5), one digit (-9.5 to -0.5) in the tens' cell (x + 5.5:
--    a GROUP with SHOW_GREATER -9.5 around a SHOW_LESS -0.5, for an element
--    takes one condition);
--  * the ECS synoptic's zones and cargo compartments (laminar/B747/air/temp/
--    zone_actual[0..6], cargo[0..1], 2 digits with the leading zero): one
--    sign 12 px left of the field, SHOW_LESS -0.5.
-- None from -0.5 up (the LED's 0). The signs' y the LED's - 0.5, as the
-- fuel's. X-Plane's bounds are inclusive: at exactly -9.5 both hydraulic
-- signs show (one float value; the LED then shows 10). notes/ATA-29.md §17,
-- ATA-21.md §13; X-Plane: s426_cold_panel_signs (-1, -10, -22). Before, no
-- sign: the cruise's -24 C showed as 24 (the review's PNL-8).
local T = dofile("tests/lib/check.lua")("panel_temp_signs")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")
local SIGN = "CRT Displays/EICAS Upper/TAT_negSign"

-- a float32's value, as X-Plane holds the dataref
local function f32(v)
    if v == 0 then return 0 end
    local m, ex = math.frexp(v)
    m = math.floor(m * 2 ^ 24 + 0.5) / 2 ^ 24
    return math.ldexp(m, ex)
end
-- the LED's digits: the absolute value rounded
local function digits(v) return math.floor(math.abs(v) + 0.5) end

local targets = {}
for n = 1, 4 do targets[#targets + 1] = {dref = "laminar/B747/hydraulics/temp_" .. n .. "[0]", kind = "hyd", leds = 2} end
for n = 0, 6 do targets[#targets + 1] = {dref = "laminar/B747/air/temp/zone_actual[" .. n .. "]", kind = "ecs", leds = 1} end
for n = 0, 1 do targets[#targets + 1] = {dref = "laminar/B747/air/temp/cargo[" .. n .. "]", kind = "ecs", leds = 1} end

-- the element after `e` in its parent with this kind and name (the names
-- repeat: STAT's and the HYD synoptic's LED Temp 1)
local function next_in_parent(e, kind, name)
    local best
    for _, x in ipairs(panel) do
        if x.parent == e.parent and x.kind == kind and x.name == name and x.line > e.line
            and (best == nil or x.line < best.line) then
            best = x
        end
    end
    return best
end

local function same_props(sign, led, what)
    for _, k in ipairs({"HIDE", "LIGHT_MODE", "LIGHT_RHEOSTAT", "BUS_SRC"}) do
        T.equal(sign[k], led[k], string.format("%s: %s as the LED's", what, k))
    end
end

local function sign_ok(sign, led, dx, bound, what)
    T.check(sign ~= nil, what .. ": there")
    if not sign then return false end
    T.equal(sign.image, SIGN, what .. ": the fuel temperature's sign")
    T.near(sign.x, led.x + dx, 0.01, what .. string.format(": x the LED's %+.1f", dx))
    T.near(sign.y, led.y - 0.5, 0.01, what .. ": y the LED's - 0.5")
    T.check(#sign.show == 1 and sign.show[1].op == "LESS" and sign.show[1].dref == led.dref
        and math.abs(sign.show[1].v - bound) < 1e-6, what .. string.format(": SHOW_LESS %.1f on the LED's dataref", bound))
    same_props(sign, led, what)
    return true
end

local n_led = 0
for _, t in ipairs(targets) do
    local leds = P.find_all(panel, {kind = "gen_LED", dref = t.dref})
    T.equal(#leds, t.leds, t.dref .. ": its LEDs")
    for _, led in ipairs(leds) do
        n_led = n_led + 1
        local where = P.path(led) .. " / " .. led.name
        local s2, s1, g1
        if t.kind == "hyd" then
            T.equal(led.DIGITS, "3", where .. ": 3 digits")
            s2 = next_in_parent(led, "gen_rotary", "NEG Sign " .. led.name)
            g1 = next_in_parent(led, "GROUP", "NEG Sign 1 " .. led.name)
            sign_ok(s2, led, -2.5, -9.5, where .. " two digits' sign")
            T.check(g1 ~= nil, where .. ": the one digit sign's group")
            if g1 then
                T.check(#g1.show == 1 and g1.show[1].op == "GREATER" and g1.show[1].dref == led.dref
                    and math.abs(g1.show[1].v + 9.5) < 1e-6, where .. ": the group's SHOW_GREATER -9.5")
                T.equal(g1.HIDE, led.HIDE, where .. ": the group's HIDE as the LED's")
                s1 = P.find(panel, {kind = "gen_rotary", name = "NEG Sign 1 " .. led.name, under = g1})
                sign_ok(s1, led, 5.5, -0.5, where .. " one digit's sign")
            end
        else
            T.equal(led.DIGITS, "2", where .. ": 2 digits")
            s1 = next_in_parent(led, "gen_rotary", "NEG Sign " .. led.name)
            sign_ok(s1, led, -12, -0.5, where .. " sign")
        end
        -- the signs against the digits shown, -40 to +5 C (not the bounds
        -- themselves: see the head)
        local bad, first_bad = 0, nil
        for i = -40000, 5000, 7 do
            local v = f32(i / 1000)
            if v ~= -9.5 and v ~= -0.5 then
                local values = {[led.dref] = v}
                local d = digits(v)
                local on2 = s2 ~= nil and P.shown(s2, values, led.parent)
                local on1 = s1 ~= nil and P.shown(s1, values, led.parent)
                local want2 = t.kind == "hyd" and v < 0 and d >= 10
                local want1 = v < 0 and d >= 1 and (t.kind == "ecs" or d <= 9)
                if on2 ~= want2 or on1 ~= want1 then
                    bad = bad + 1
                    first_bad = first_bad or v
                end
            end
        end
        T.equal(bad, 0, where .. string.format(": the sign as the digits shown from -40 to +5 C (first wrong %s)", tostring(first_bad)))
        -- the cases seen in X-Plane (s426): -1.13, -10.0, -21.8
        if t.kind == "hyd" then
            T.check(s1 and P.shown(s1, {[led.dref] = f32(-1.13)}, led.parent) and not P.shown(s2, {[led.dref] = f32(-1.13)}, led.parent),
                where .. ": -1.13 shows -1 with the sign next to the digit")
            T.check(s2 and P.shown(s2, {[led.dref] = f32(-10.004)}, led.parent) and not P.shown(s1, {[led.dref] = f32(-10.004)}, led.parent),
                where .. ": -10.0 shows -10")
        else
            T.check(s1 and P.shown(s1, {[led.dref] = f32(-21.8)}, led.parent), where .. ": -21.8 shows -22")
        end
        T.check(not (s1 and P.shown(s1, {[led.dref] = f32(-0.3)}, led.parent)) and not (s2 and P.shown(s2, {[led.dref] = f32(-0.3)}, led.parent)),
            where .. ": -0.3 (shown 0): no sign")
    end
end
T.equal(n_led, 17, "17 LEDs with a sign (8 hydraulic, 9 ECS)")
T.done()
