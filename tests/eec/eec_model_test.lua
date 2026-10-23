-- Run from the repository root with LuaJIT: luajit tests/eec/eec_model_test.lua
-- The EEC model (plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua)
-- against the FCOM PI tables (PW4056 p.262-263, CF6-80C2B1F p.359-360) and
-- the CF6 thrust management (ATA70_80 p.146-151, p.208-209): the maximum
-- rated thrust, its bleed adjustments, the full-forward rating by altitude
-- and speed, and the lever command between idle and the maximum.
local T = dofile("tests/lib/check.lua")("eec_model")
local E = dofile("plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.eec_model.lua")

local PW, GE = E.TABLE.PW, E.TABLE.GE

-- table values at their grid points (read off the FCOM pages)
T.near(E.lookup(PW.clb, 0, 30000), 1.57, 1e-9, "PW max climb EPR, TAT 0, 30,000 ft")
T.near(E.lookup(PW.clb, 20, 35000), 1.39, 1e-9, "PW max climb EPR, TAT 20, 35,000 ft")
T.near(E.lookup(PW.clb, -20, 45000), 1.58, 1e-9, "PW max climb EPR, TAT -20, 45,000 ft")
T.near(E.lookup(PW.ga, 15, 0), 1.51, 1e-9, "PW go-around EPR, TAT 15, sea level")
T.near(E.lookup(PW.ga, 10, 10000), 1.67, 1e-9, "PW go-around EPR, TAT 10, 10,000 ft")
T.near(E.lookup(PW.ga, 45, -2000), 1.46, 1e-9, "PW go-around EPR, TAT 45, -2,000 ft")
T.near(E.lookup(GE.clb, -10, 35000), 105.6, 1e-9, "GE max climb N1, TAT -10, 35,000 ft")
T.near(E.lookup(GE.clb, 25, 0), 98.2, 1e-9, "GE max climb N1, TAT 25, sea level (the old table had 98.8)")
T.near(E.lookup(GE.clb, -40, 20000), 95.2, 1e-9, "GE max climb N1, TAT -40, 20,000 ft (the old table had 95.5)")
T.near(E.lookup(GE.ga, 15, 0), 103.8, 1e-9, "GE go-around N1, TAT 15, sea level")
T.near(E.lookup(GE.ga, 57, 10000), 103.8, 1e-9, "GE go-around N1, TAT 57, 10,000 ft")

-- between grid points, and where the table is blank (too warm for the altitude)
T.near(E.lookup(PW.clb, 5, 30000), 1.545, 1e-9, "PW max climb EPR between TAT 0 and 10")
T.near(E.lookup(PW.clb, 0, 32500), 1.575, 1e-9, "PW max climb EPR between 30,000 and 35,000 ft")
T.near(E.lookup(PW.clb, 30, 35000), 1.39, 1e-9, "PW max climb EPR held at the warmest row of a column")
T.near(E.lookup(PW.clb, -40, 0), 1.25, 1e-9, "PW max climb EPR held below -20")
T.near(E.lookup(PW.ga, 54, 10000), 1.44, 1e-9, "PW go-around EPR held where TAT 54 and 50 are blank")
T.near(E.lookup(GE.ga, 20, 20000), 109.8, 1e-9, "GE go-around N1 held above 10,000 ft")

-- the full-forward rating by altitude and speed (ATA70_80 p.208)
local share, tla = E.rating_mix(0, 150)
T.equal(share, 1, "takeoff rating at sea level, 150 kt")
T.equal(tla, 48, "takeoff rating reached at 48° TLA")
share = E.rating_mix(17500, 250)
T.near(share, 0.5, 1e-9, "half way to maximum continuous at 17,500 ft")
share = E.rating_mix(10000, 296.5)
T.near(share, 0.5, 1e-9, "half way to maximum continuous at 296.5 kt")
share, tla = E.rating_mix(20000, 280)
T.equal(share, 0, "no takeoff rating at 20,000 ft")
T.equal(tla, 48, "maximum continuous: reached at 48° below 22,000 ft")
share, tla = E.rating_mix(23500, 300)
T.near(tla, 41.5, 1e-9, "the lever angle for the rating moves from 48° to 35° between 22,000 and 25,000 ft")
share, tla = E.rating_mix(30000, 280)
T.equal(tla, 35, "climb rating reached at 35° above 25,000 ft")

-- P&W at sea level, 15 °C: full forward gives the takeoff (go-around) EPR
local inp = E.inputs()
inp.type, inp.alt, inp.tat, inp.kias = "PW", 0, 15, 0
inp.idle = {1.0, 1.0, 1.0, 1.0}
inp.lever = {1.0, 0.96, 0.48, 0}
local out = E.update(inp)
for n = 1, 4 do T.near(out.max[n], 1.51, 1e-9, "PW max EPR at sea level, engine " .. n) end
T.near(out.command[1], 1.51, 1e-9, "full forward commands the max EPR")
T.near(out.command[2], 1.51, 1e-9, "48° TLA commands the max EPR")
T.near(out.command[3], 1.255, 1e-9, "24° TLA commands half way from idle")
T.near(out.command[4], 1.0, 1e-9, "idle lever commands idle")

-- bleed: three packs off adds 0.02 to the go-around EPR; engine anti-ice on one
-- engine changes only that engine's climb EPR
inp.packs_on = 0
out = E.update(inp)
T.near(out.max[1], 1.53, 1e-9, "PW max EPR with 3 packs off")
inp.packs_on = 3
inp.alt, inp.tat, inp.kias = 30000, -20, 280
inp.nai = {true, false, false, false}
inp.lever = {0.7, 0.7, 0.35, 1.0}
out = E.update(inp)
T.near(out.max[2], 1.57, 1e-9, "PW max climb EPR at 30,000 ft, TAT -20")
T.near(out.max[1], 1.53, 1e-9, "engine anti-ice on engine 1: -0.04 at 30,000 ft")
T.near(out.command[2], 1.57, 1e-9, "35° TLA reaches the climb rating above 25,000 ft")
T.near(out.command[4], 1.57, 1e-9, "full forward gives the climb rating above 25,000 ft")
T.near(out.command[3], 1.285, 1e-9, "17.5° TLA commands half way from idle")
inp.wai = true
out = E.update(inp)
T.near(out.max[1], 1.50, 1e-9, "engine and wing anti-ice: -0.07 at 30,000 ft")
T.near(out.max[2], 1.57, 1e-9, "wing anti-ice alone does not change an engine without engine anti-ice")
inp.wai, inp.nai = false, {false, false, false, false}

-- a type the model does not know runs on the P&W data (the glue keeps RR,
-- which has no source, on its previous thrust logic)
inp.type = "RR"
out = E.update(inp)
T.near(out.max[1], 1.57, 1e-9, "an unknown type falls back to the P&W tables")

-- GE at sea level, 15 °C, then climbing through the blend to the climb rating
inp.type, inp.alt, inp.tat, inp.kias = "GE", 0, 15, 150
inp.idle = {25, 25, 25, 25}
inp.lever = {1, 1, 1, 1}
inp.nai = {false, true, false, false}
out = E.update(inp)
T.near(out.max[1], 103.8, 1e-9, "GE max N1 at sea level, TAT 15")
T.near(out.max[2], 103.3, 1e-9, "GE engine anti-ice: -0.5 at sea level")
inp.nai = {false, false, false, false}
inp.alt, inp.tat, inp.kias = 17500, -5, 290
out = E.update(inp)
local ga = E.lookup(GE.ga, -5, 10000)
local clb = E.lookup(GE.clb, -5, 17500)
T.near(out.max[1], 0.5 * ga + 0.5 * clb, 1e-9, "GE half way between the takeoff and the climb rating at 17,500 ft")
inp.alt = 26000
out = E.update(inp)
T.near(out.max[1], E.lookup(GE.clb, -5, 26000), 1e-9, "GE climb rating at 26,000 ft")
inp.lever = {0, 0, 0, 0}
inp.idle = {120, 120, 120, 120}
out = E.update(inp)
T.near(out.command[1], out.max[1], 1e-9, "an idle above the maximum is held at the maximum")

T.done()
