-- Run from the repository root with LuaJIT: luajit tests/gear/tpis_model_test.lua
-- The tire pressure model (plugins/xtlua/scripts/B747.10.xt.gear/B747.10.tpis_model.lua)
-- against ATA29_32 p.376 and FCOM p.1522 (docs/overhaul/notes/ATA-32.md
-- §4.11): >TIRE PRESSURE below 100 psi, 18 % off the main gear's average,
-- an axle's pair more than 25 % apart, the nose pair more than 12 % apart;
-- failed channels out of the average; inhibited at takeoff thrust.
local T = dofile("tests/lib/check.lua")("tpis_model")
local M = dofile("plugins/xtlua/scripts/B747.10.xt.gear/B747.10.tpis_model.lua")

local function fresh()
    local inp = M.inputs()
    for i = 1, M.TIRES do inp.psi[i] = 205 end
    return inp
end

local inp = fresh()
local out = M.update(inp)
T.check(not out.tire_pressure, "all at 205 psi: none")
-- below 100 psi
inp.psi[17], inp.psi[18] = 95, 95
out = M.update(inp)
T.check(out.tire_pressure and out.abnormal[17], "the nose tires at 95 psi: >TIRE PRESSURE")
-- the nose pair 12 %
inp = fresh()
inp.psi[17], inp.psi[18] = 200, 226
out = M.update(inp)
T.check(out.tire_pressure and out.abnormal[18], "the nose tires 13 % apart: >TIRE PRESSURE")
inp.psi[18] = 222
out = M.update(inp)
T.check(not out.tire_pressure, "11 % apart: none")
-- the axle's pair 25 % (a main gear tire 18 % low trips first: the
-- average is of all 16)
inp = fresh()
inp.psi[3] = 170
out = M.update(inp)
T.check(not out.tire_pressure, "one tire 17 % low: none")
inp.psi[3] = 165
out = M.update(inp)
T.check(out.tire_pressure and out.abnormal[3], "one tire 19 % low: >TIRE PRESSURE (18 % off the average)")
T.check(not out.abnormal[1], "the others normal")
inp = fresh()
inp.psi[9], inp.psi[10] = 230, 180
out = M.update(inp)
T.check(out.tire_pressure and out.abnormal[9] and out.abnormal[10], "an axle 230/180 (28 % of the lower): >TIRE PRESSURE")
-- a failed channel: out of the average and not compared
inp = fresh()
inp.psi[5] = 0
inp.fail[5] = true
out = M.update(inp)
T.check(not out.tire_pressure, "a failed channel reading 0: not a tire pressure (not averaged)")
-- a whole truck deflated (X-Plane's tire failure)
inp = fresh()
for i = 13, 16 do inp.psi[i] = 5 end
out = M.update(inp)
T.check(out.tire_pressure and out.abnormal[13] and out.abnormal[16], "a truck at 5 psi: >TIRE PRESSURE")
-- inhibited at takeoff thrust (estimate)
inp.takeoff = true
out = M.update(inp)
T.check(not out.tire_pressure, "takeoff thrust: inhibited (estimate)")
T.done()
