-- Run from the repository root with LuaJIT: luajit tests/air/panel_dp_digits_test.lua
-- (2026-11-24, the stage 4 review's PNL-2 = SYS-1) The primary EICAS's ΔP
-- readout in the custom acf's panel (GROUP Diff Press: one gen_LED a colour
-- on sim/cockpit2/pressurization/indicators/pressure_diffential_psi, one
-- decimal): some colour shows at every ΔP, and the colour is the one for the
-- value shown - ATA21 p.452 (21-30 Page 60, increasing pressure): white -0.4
-- to +8.8, amber +8.9 to +9.0 and -0.5 and below, red +9.1 and greater
-- (displayed values: the bounds of the raw value are 8.85, 9.05, -0.45);
-- FCOM p.586 (2.10.34). The data block's own threshold is the same
-- (B747.55.xt.press.lua: dp >= 8.85 or dp <= -0.45, FCOM p.585). Before,
-- white up to 8.8 and amber from 8.9 (and gaps at 9.0-9.1, -0.5 to -0.49):
-- the cruise's ΔP 8.800002 showed nothing (v06_dp_digits, 2026-11-23).
local T = dofile("tests/lib/check.lua")("panel_dp_digits")
local P = dofile("tests/lib/panel.lua")
local panel = P.load("747-400_custom.acf")
local DP = "sim/cockpit2/pressurization/indicators/pressure_diffential_psi"

local group = P.find(panel, {kind = "GROUP", name = "Diff Press"})
T.check(group ~= nil, "GROUP Diff Press")
local leds = P.find_all(panel, {kind = "gen_LED", dref = DP, under = group})
T.equal(#leds, 4, "four ΔP readouts (red, amber, white, low amber)")
local colour = {}
for _, e in ipairs(leds) do
    local c = e.image:match("%.(%a+)$")
    T.check(e.DECIMALS == "1", e.name .. ": one decimal")
    T.check(#e.show > 0 and e.show[#e.show].dref == DP, e.name .. ": shown by ΔP itself")
    colour[#colour + 1] = {e = e, c = c}
end

-- a float32's value, as X-Plane holds the dataref
local function f32(v)
    if v == 0 then return 0 end
    local m, ex = math.frexp(v)
    m = math.floor(m * 2 ^ 24 + 0.5) / 2 ^ 24
    return math.ldexp(m, ex)
end
-- the value shown (ROUND_ROUND, one decimal)
local function shown_value(v)
    local x = math.abs(v) * 10
    local r = math.floor(x + 0.5) / 10
    return v < 0 and -r or r
end
local function want(d)
    if d >= 9.1 - 1e-9 then return "red" end
    if d >= 8.9 - 1e-9 then return "amber" end
    if d >= -0.4 - 1e-9 then return "white" end
    return "amber"
end

local blank, wrong = 0, 0
local first_blank, first_wrong
local function try(v)
    local values = {[DP] = v}
    local on = {}
    for _, x in ipairs(colour) do
        if P.own_shown(x.e, values) then on[#on + 1] = x.c end
    end
    if #on == 0 then
        blank = blank + 1
        first_blank = first_blank or v
        return
    end
    local d = shown_value(v)
    -- off the exact half-way values the one colour of the value shown
    local half = math.abs(v * 10 - math.floor(v * 10) - 0.5) < 1e-4
    if not half and (#on ~= 1 or on[1] ~= want(d)) then
        wrong = wrong + 1
        first_wrong = first_wrong or string.format("%.6f shows %s (want %s)", v, table.concat(on, "+"), want(d))
    end
end
for i = -3000, 10500 do try(f32(i / 1000)) end
-- the cruise (B747.55.press_model.lua CRUISE_DP 8.8) and around each bound
for _, v in ipairs({8.8, 8.800002, 8.8007, 8.84, 8.849999, 8.85, 8.850001, 9.049999, 9.05, 9.050001,
    -0.449999, -0.45, -0.450001, -0.49, -0.5}) do
    try(f32(v))
end
T.equal(blank, 0, "ΔP values with no readout (first " .. tostring(first_blank) .. ")")
T.equal(wrong, 0, "ΔP values in the wrong colour (first " .. tostring(first_wrong) .. ")")

-- the data block comes up by itself where the amber starts (press.lua)
local press = io.open("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.xt.press.lua"):read("*a")
T.check(press:find("dp >= 8.85 or dp <= -0.45", 1, true) ~= nil, "the data block's threshold is 8.85 / -0.45 psi")

T.done()
