-- Run from the repository root with LuaJIT: luajit tests/fdr/fdr_model_test.lua
-- (2026-11-13; the 2026-11-12 review's FDR, the user's "FDRは欲しい") The
-- FDR's event recording (plugins/xtlua_fdr/scripts/B747.01.xt.fdr/
-- B747.01.fdr_model.lua): nothing in a steady flight; at an event the 20 s
-- of 1 s samples before it, then one a second for 60 s; an FMA change, an
-- A/P disconnect, the load factor 0.15 g off 1 (counted once as it begins),
-- the vertical speed 500 fpm different from 5 s before, a frame of more
-- than 0.25 s of real time; an event within a burst extends it.
local T = dofile("tests/lib/check.lua")("fdr_model")
local json = dofile("plugins/xtlua/scripts/B747.05.xt.simconfig/json/json.lua")
local M = dofile("plugins/xtlua_fdr/scripts/B747.01.xt.fdr/B747.01.fdr_model.lua")

local s = M.new()
local inp = {t = 0, clock = 0, fma = {9, 2, 3}, ap = true, vs = 0, g = 1}
inp.sample = function() return {t = inp.t, vs = inp.vs, g = inp.g, alt = 35000, ias = 280, fma = {inp.fma[1], inp.fma[2], inp.fma[3]}} end
local written = {}
local function fly(seconds, dt)
    dt = dt or 0.05
    local n = 0
    for _ = 1, math.floor(seconds / dt + 0.5) do
        inp.t, inp.clock = inp.t + dt, inp.clock + dt
        local lines = M.update(s, inp)
        for _, l in ipairs(lines or {}) do written[#written + 1] = l; n = n + 1 end
    end
    return n
end
local function count(kind)
    local n = 0
    for _, l in ipairs(written) do if l[kind] then n = n + 1 end end
    return n
end

T.equal(fly(60), 0, "a steady minute: nothing written")
inp.fma[1] = 4                                   -- VNAV SPD
fly(0.05)
T.equal(count("event"), 1, "an FMA change: an event")
T.equal(written[1].event, "FMA", "its kind")
T.check(#written[1].before >= 19 and #written[1].before <= 21, "with the 20 s before it (" .. #written[1].before .. " samples)")
fly(70)
T.check(count("sample") >= 59 and count("sample") <= 61, "then one sample a second for 60 s (" .. count("sample") .. ")")
local bytes = 0
for _, l in ipairs(written) do bytes = bytes + #json.encode(l) end
T.check(bytes < 16000, "an event's size: " .. bytes .. " bytes")
written = {}
T.equal(fly(30), 0, "after the burst: nothing")

inp.g = 1.2
fly(10)
T.equal(count("event"), 1, "1.2 g for 10 s: one event as it began")
inp.g = 1
fly(70)
written = {}
inp.ap = false
fly(1)
T.equal(written[1] and written[1].event, "A/P disconnect", "an A/P disconnect")
inp.ap = true
fly(70)
written = {}
inp.vs = -700
fly(2)
T.equal(written[1] and written[1].event, "vertical speed", "700 fpm off the V/S of 5 s before")
fly(70)
written = {}
inp.vs = -700
inp.clock = inp.clock + 1.0                       -- X-Plane stood still for a second
fly(0.05)
T.equal(written[1] and written[1].event, "long frame", "a frame of a second of real time")
fly(30)
inp.fma[2] = 6                                   -- within the burst: HDG SEL
fly(0.05)
T.equal(count("event"), 2, "an event within the burst")
T.check(written[#written].before == nil, "without a second copy of the samples before")
local n0 = count("sample")
fly(75)
local extra = count("sample") - n0
T.check(extra >= 58 and extra <= 62, "the burst extended to 60 s after the second event (30 s were left of the first): " .. extra)
T.done()
