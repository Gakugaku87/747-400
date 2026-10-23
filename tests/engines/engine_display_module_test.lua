-- Run from the repository root with LuaJIT: luajit tests/engines/engine_display_module_test.lua
-- The engine indications in the engine module as XTLua runs it
-- (tests/lib/xtlua.lua): the displayed EGT, FUEL CONTROL, the running
-- engines, the TO/GA command and X-Plane's oil values in; the EGT flags the
-- upper EICAS draws with and the secondary EICAS's oil and vibration
-- out, through the glue (B747.40.xt.engine_display.lua). The model's
-- behaviour is tested in engine_display_model_test.lua; this checks the
-- wiring.
local T = dofile("tests/lib/check.lua")("engine_display_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.40.xt.engines/B747.40.xt.engines.lua")
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/engines/type", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local EGT = "laminar/B747/engines/EGT/"
local FUEL_CONTROL = "laminar/B747/fuel/fuel_control/toggle_sw_pos"
local function flags(i)
    return {white = rt:get(EGT .. "white_on", i), amber = rt:get(EGT .. "amber_on", i),
        red = rt:get(EGT .. "red_on", i), line = rt:get(EGT .. "start_limit_on", i)}
end

-- P&W, all four at CUTOFF: the start limit line, red from 535 °C
for i = 0, 3 do rt:set(FUEL_CONTROL, i, 0) end
rt:set("laminar/B747/engines/display_EGT", 0, 300)
rt:set("laminar/B747/engines/display_EGT", 1, 540)
frames(1)
local f = flags(0)
T.equal(f.line, 1, "CUTOFF: start limit line")
T.equal(f.white, 1, "CUTOFF, EGT 300: white")
T.equal(flags(1).red, 1, "CUTOFF, EGT 540: red at the P&W start limit")
T.equal(rt:get(EGT .. "amber_inhibit", 0), 0, "the amber band is always shown")

-- running at RUN: no line; amber in the band, white after a TO/GA push, red at the red line
for i = 0, 3 do
    rt:set(FUEL_CONTROL, i, 1)
    rt:set("sim/flightmodel/engine/ENGN_running", i, 1)
end
rt:set("laminar/B747/engines/display_EGT", 0, 640)
rt:set("laminar/B747/engines/display_EGT", 1, 660)
frames(1)
f = flags(0)
T.equal(f.line, 0, "running at RUN: no start limit line")
T.equal(f.amber, 1, "EGT 640: amber (P&W continuous limit)")
T.equal(f.white, 0, "EGT 640: not white")
T.equal(flags(1).red, 1, "EGT 660: red (P&W takeoff limit)")
rt:command("sim/engines/TOGA_power")
frames(1)
T.equal(flags(0).white, 1, "after the TO/GA switch: white in the amber band")
T.equal(flags(0).amber, 0, "after the TO/GA switch: no amber")
T.equal(flags(1).red, 1, "after the TO/GA switch: still red at the red line")

-- the oil and vibration: X-Plane's oil values in, the secondary EICAS's
-- indications and ENG n OIL PRESS, ENG n OIL TEMP out
local ADV = "laminar/B747/CAS/advisory_status"
local OIL = "sim/cockpit2/engine/indicators/"
local ENG = "laminar/B747/engines/"
for i = 0, 3 do
    rt:set(ENG .. "display_N1", i, 30)
    rt:set(ENG .. "display_N2", i, 70)
    rt:set(OIL .. "oil_pressure_psi", i, 150)
    rt:set(OIL .. "oil_temperature_deg_C", i, 100)
    rt:set(OIL .. "oil_quantity_ratio", i, 1)
end
rt:set(OIL .. "oil_pressure_psi", 1, 50)
rt:set(OIL .. "oil_temperature_deg_C", 2, 170)
rt:set(OIL .. "oil_quantity_ratio", 3, 0.5)
frames(1)
local p0 = rt:get(ENG .. "oil_press_psi", 0)
T.check(p0 > 150.6 and p0 < 154.3, "oil pressure: X-Plane's 150 psi and the spread (" .. p0 .. ")")
T.equal(rt:get(ENG .. "EICAS2_oil_press_status", 1), 1, "P&W at RUN, 50 psi: red")
T.equal(rt:get(ENG .. "EICAS2_oil_press_status", 0), 0, "150 psi: white")
T.equal(rt:get(ADV, 318), 1, "ENG 2 OIL PRESS")
T.equal(rt:get(ADV, 317), 0, "no ENG 1 OIL PRESS")
T.equal(rt:get(ADV, 120), 1, "ENG 3 OIL TEMP at 170 °C")
T.equal(rt:get(ADV, 118), 0, "no ENG 1 OIL TEMP at 100 °C")
local q0, q3 = rt:get(ENG .. "oil_qty_liters", 0), rt:get(ENG .. "oil_qty_liters", 3)
T.check(q0 >= 22 and q0 <= 30, "oil quantity running: 22-30 L (" .. q0 .. ")")
T.check(q3 >= 11 and q3 <= 15, "engine 4 with its own ratio 0.5 (" .. q3 .. ")")
local v0 = rt:get(ENG .. "vibration", 0)
T.check(v0 > 0 and v0 < 0.6, "vibration at 70 % N2 (" .. v0 .. ")")
rt:set(FUEL_CONTROL, 1, 0)
frames(1)
T.equal(rt:get(ENG .. "EICAS2_oil_press_status", 1), 0, "CUTOFF: oil pressure stays white")
rt:set(FUEL_CONTROL, 1, 1)

-- GE reads its own EGT (display_GE_EGT) and limits; a new flight clears the inhibit
rt:set("laminar/B747/engines/type", 1)
rt:callout("flight_start")
rt:set("laminar/B747/engines/display_GE_EGT", 0, 930)
rt:set("laminar/B747/engines/display_GE_EGT", 1, 900)
rt:set("laminar/B747/engines/display_EGT", 1, 900)
frames(1)
T.equal(flags(0).amber, 1, "GE EGT 930: amber (continuous limit 925)")
T.equal(flags(1).white, 1, "GE EGT 900: white (the P&W limits do not apply)")

T.done()
