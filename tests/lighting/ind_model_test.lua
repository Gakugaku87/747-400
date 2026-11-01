-- Run from the repository root with LuaJIT: luajit tests/lighting/ind_model_test.lua
-- The indicator lights' master dim and test (B747.90.ind_model.lua;
-- notes/ATA-33.md §13): BRT, DIM, TEST dimmed after 10 s, STORM, power.
local T = dofile("tests/lib/check.lua")("ind_model")
local I = dofile("plugins/xtlua_keysystems/scripts/B747.90.xt.lighting/B747.90.ind_model.lua")

local s = I.new()
local function at(sel, t, o)
    o = o or {}
    local function default(v, d) if v == nil then return d end return v end
    return I.update(s, {sel = sel, t = t, storm = o.storm or false,
        bat = default(o.bat, true), dc1 = default(o.dc1, true), dc3 = default(o.dc3, true)})
end

local r = at(0, 0)
T.near(r.lit, 0.8, 1e-9, "BRT: lit lights at 0.8")
T.check(r.test == nil and not r.dim, "BRT: no TEST, not dimmed")
r = at(-1, 1)
T.near(r.lit, 0.4, 1e-9, "DIM: 0.4")
T.check(r.dim, "DIM: the dim relays on")

-- TEST (ATA33 p.67): every tested light bright at once, dimmed after 10 s
-- while held (before, 1.0 while held)
r = at(1, 100)
T.near(r.test, 0.8, 1e-9, "TEST pushed: tested lights bright")
T.near(r.lit, 0.8, 1e-9, "TEST pushed: lit lights bright")
T.near(at(1, 109.9).test, 0.8, 1e-9, "TEST held 9.9 s: still bright")
r = at(1, 110)
T.near(r.test, 0.4, 1e-9, "TEST held 10 s: dimmed")
T.check(r.dim, "TEST held 10 s: the dim relays on")
T.near(at(1, 130).lit, 0.4, 1e-9, "TEST held 30 s: lit lights dimmed too")
r = at(0, 131)
T.check(r.test == nil, "TEST released: no TEST")
T.near(r.lit, 0.8, 1e-9, "TEST released to BRT: bright again")
T.near(at(1, 140).test, 0.8, 1e-9, "TEST again: bright, the timer starts again")
at(0, 141)

-- STORM: lit lights bright on DIM and after the TEST's 10 s (FCOM p.501)
r = at(-1, 150, {storm = true})
T.near(r.lit, 0.8, 1e-9, "STORM on DIM: bright")
T.check(not r.dim, "STORM on DIM: not dimmed")
at(1, 160, {storm = true})
T.near(at(1, 175, {storm = true}).test, 0.8, 1e-9, "STORM, TEST held 15 s: bright")
at(0, 176)

-- power (estimate: the battery bus or DC bus 1 or 3; the relays DC 1 or 3)
r = at(0, 200, {bat = false, dc1 = false, dc3 = false})
T.equal(r.lit, 0, "no power: lit lights out")
T.check(r.test == nil, "no power: no TEST")
T.near(r.own, 0.8, 1e-9, "no power: a light on its own power (EXT PWR AVAIL) at BRT")
r = at(1, 201, {dc1 = false, dc3 = false})
T.near(r.lit, 0.8, 1e-9, "battery bus alone: lit lights bright")
T.check(r.test == nil, "battery bus alone: no TEST (the test relays on DC 1 or 3)")
r = at(-1, 202, {dc1 = false, dc3 = false})
T.near(r.lit, 0.8, 1e-9, "battery bus alone, DIM: bright (the dim relays off)")
r = at(-1, 203, {bat = false, dc1 = false})
T.near(r.lit, 0.4, 1e-9, "DC bus 3 alone, DIM: 0.4")
T.near(r.own, 0.4, 1e-9, "DIM: a light on its own power dimmed too")
T.done()
