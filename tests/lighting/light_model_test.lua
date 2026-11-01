-- Run from the repository root with LuaJIT: luajit tests/lighting/light_model_test.lua
-- The exterior lights' model (B747.90.light_model.lua; notes/ATA-33.md §12):
-- each light from its switch, its bus, the gear lever and the ground mode.
local T = dofile("tests/lib/check.lua")("light_model")
local L = dofile("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.light_model.lua")

-- all switches on (or as given), all buses powered, gear lever DOWN, ground
local function input(o)
    o = o or {}
    local sw = {landing = o.landing or {true, true, true, true}, turnoff = o.turnoff or {true, true}}
    for _, k in ipairs({"taxi", "beacon", "nav", "strobe", "wing", "logo"}) do
        if o[k] == nil then sw[k] = true else sw[k] = o[k] end
    end
    local ac = o.ac or {true, true, true, true}
    local function default(v, d) if v == nil then return d end return v end
    return {sw = sw, ac = ac, gsb = default(o.gsb, true), ground = default(o.ground, true),
        gear_down = default(o.gear_down, true)}
end
local NAMES = {"OUTBD L", "INBD L", "INBD R", "OUTBD R"}
local function landing(out, want, what)
    for i = 1, 4 do T.near(out.landing[i], want[i], 1e-9, what .. ": " .. NAMES[i]) end
end

-- everything on
local out = L.update(input())
landing(out, {1, 1, 1, 1}, "all on, lever DOWN: the landing lights bright")
T.check(out.turnoff[1] == 1 and out.turnoff[2] == 1 and out.taxi == 1, "on the ground: the turnoff and taxi lights on")
T.check(out.beacon == 1 and out.nav == 1 and out.strobe == 1 and out.wing == 1 and out.logo == 1,
    "the ground service bus: beacon, nav, strobe, wing, logo on")

-- the landing lights' dimming (ATA33 p.328, p.330): the lever not DOWN and the
-- side's INBD switch ON dim that side to 70 % (before, all four at 50 %)
landing(L.update(input({gear_down = false})), {0.7, 0.7, 0.7, 0.7}, "lever UP, all on: 70 %")
landing(L.update(input({gear_down = false, landing = {true, false, true, true}})), {1, 0, 0.7, 0.7},
    "lever UP, INBD L OFF: OUTBD L bright, the right dimmed")
landing(L.update(input({gear_down = false, landing = {false, false, true, false}})), {0, 0, 0.7, 0},
    "lever UP, INBD R alone: 70 %")
landing(L.update(input({gear_down = false, landing = {true, false, false, true}})), {1, 0, 0, 1},
    "lever UP, the OUTBDs alone: bright")
landing(L.update(input({landing = {true, false, false, true}})), {1, 0, 0, 1}, "lever DOWN, the OUTBDs alone: bright")
T.equal(L.LANDING_DIM, 0.7, "the dimmed ratio")

-- their AC buses (ATA33 p.330-331): INBD AC 1, OUTBD AC 3
landing(L.update(input({ac = {false, true, true, true}})), {1, 0, 0, 1}, "AC bus 1 off: the INBDs out")
landing(L.update(input({ac = {true, true, false, true}})), {0, 1, 1, 0}, "AC bus 3 off: the OUTBDs out")
landing(L.update(input({ac = {true, false, true, false}})), {1, 1, 1, 1}, "AC buses 2 and 4 off: all lit")
landing(L.update(input({gsb = false})), {1, 1, 1, 1}, "no ground service bus: the landing lights lit")

-- the ground service bus (ATA33 p.326, p.334, p.340, p.348, p.354, p.358)
out = L.update(input({gsb = false}))
for _, k in ipairs({"taxi", "beacon", "nav", "strobe", "wing", "logo"}) do
    T.equal(out[k], 0, "no ground service bus: " .. k .. " out")
end
T.check(out.turnoff[1] == 0 and out.turnoff[2] == 0, "no ground service bus: the turnoff lights out")

-- the ground mode (ATA33 p.334; FCOM p.451, p.500): turnoff and taxi only
out = L.update(input({ground = false}))
T.check(out.turnoff[1] == 0 and out.turnoff[2] == 0 and out.taxi == 0, "in the air: the turnoff and taxi lights out")
T.check(out.beacon == 1 and out.nav == 1 and out.strobe == 1 and out.wing == 1 and out.logo == 1,
    "in the air: beacon, nav, strobe, wing, logo on")
landing(out, {1, 1, 1, 1}, "in the air, lever DOWN: the landing lights bright")

-- each switch its light
out = L.update(input({landing = {false, false, false, false}, turnoff = {true, false}, taxi = false,
    beacon = false, nav = true, strobe = false, wing = true, logo = false}))
landing(out, {0, 0, 0, 0}, "the landing switches OFF")
T.check(out.turnoff[1] == 1 and out.turnoff[2] == 0, "turnoff L on, R off")
T.check(out.taxi == 0 and out.beacon == 0 and out.strobe == 0 and out.logo == 0, "taxi, beacon, strobe, logo off")
T.check(out.nav == 1 and out.wing == 1, "nav and wing on")

-- (7-2d) the emergency lights (ATA33 p.264-268; FCOM p.452-453, p.547)
local E = {[L.EMER_OFF] = "OFF", [L.EMER_ARMED] = "ARMED", [L.EMER_ON] = "ON"}
for _, c in ipairs({
    -- P5, cabin, DC bus 4 -> lit, >EMER LIGHTS
    {L.EMER_ARMED, false, true, false, false},
    {L.EMER_ARMED, false, false, true, false},
    {L.EMER_OFF, false, false, false, true},
    {L.EMER_OFF, false, true, false, true},
    {L.EMER_ON, false, true, true, true},
    {L.EMER_ARMED, true, true, true, true},
    {L.EMER_OFF, true, true, true, true},
}) do
    local lit, msg = L.emer(c[1], c[2], c[3])
    local what = E[c[1]] .. (c[2] and ", cabin ON" or "") .. (c[3] and ", DC bus 4" or ", no DC bus 4")
    T.equal(lit, c[4], what .. ": lit")
    T.equal(msg, c[5], what .. ": >EMER LIGHTS")
end
T.done()
