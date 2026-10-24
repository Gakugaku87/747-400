-- Run from the repository root with LuaJIT: luajit tests/fltctrls/fltctrls_module_test.lua
-- The flight controls module as XTLua runs it (tests/lib/xtlua.lua), before
-- its rebuild (4-1): the flap load relief and >FLAP RELIEF, and the flap
-- lever snapping to the nearest detent (docs/overhaul/notes/ATA-27.md
-- FCTL-14, FCTL-23).
local T = dofile("tests/lib/check.lua")("fltctrls_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.45.xt.fltCtrls/B747.45.xt.fltCtrls.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local function get(name, i) return rt:get(name, i) end
local LEVER = "sim/cockpit2/controls/flap_ratio"
local IAS = "laminar/B747/gauges/indicators/airspeed_kts_pilot"
local FLAPS = "laminar/B747/cablecontrols/flap_ratio"   -- the flaps' command
local ADVISORY = "laminar/B747/CAS/advisory_status"
local F20, F25, F30 = 0.667, 0.833, 1.0
local function at(kt)
    rt:set(IAS, kt)
    frames(0.2)
end

-- lever 30 (FCOM p.954; ATA27 p.288-289): 30 to 25 at 178 kt, 25 to 20 at
-- 203 kt; back 20 to 25 at 195 kt, 25 to 30 at 170 kt
rt:set(LEVER, F30)
at(160)
T.near(get(FLAPS), F30, 0.001, "lever 30, 160 kt: flaps 30")
T.equal(get(ADVISORY, 142), 0, "no >FLAP RELIEF")
at(180)
T.near(get(FLAPS), F25, 0.001, "lever 30, 180 kt: relieved to 25")
T.equal(get(ADVISORY, 142), 1, ">FLAP RELIEF")
at(205)
T.near(get(FLAPS), F20, 0.001, "lever 30, 205 kt: relieved to 20")
at(200)
T.near(get(FLAPS), F20, 0.001, "lever 30, back to 200 kt: still 20 (195 kt)")
at(194)
T.near(get(FLAPS), F25, 0.001, "lever 30, 194 kt: back to 25")
at(172)
T.near(get(FLAPS), F25, 0.001, "lever 30, 172 kt: still 25 (170 kt)")
at(168)
T.near(get(FLAPS), F30, 0.001, "lever 30, 168 kt: back to 30")
T.equal(get(ADVISORY, 142), 0, ">FLAP RELIEF cleared")

-- lever 25: 25 to 20 at 203 kt, back at 195 kt
rt:set(LEVER, F25)
at(200)
T.near(get(FLAPS), F25, 0.001, "lever 25, 200 kt: flaps 25")
at(205)
T.near(get(FLAPS), F20, 0.001, "lever 25, 205 kt: relieved to 20")
at(197)
T.near(get(FLAPS), F20, 0.001, "lever 25, 197 kt: still 20")
at(193)
T.near(get(FLAPS), F25, 0.001, "lever 25, 193 kt: back to 25")
-- lever 20 and below: no relief
rt:set(LEVER, F20)
at(240)
T.near(get(FLAPS), F20, 0.001, "lever 20, 240 kt: no relief")

-- the lever between detents snaps to the nearest one 2 s after it stops
rt:set(LEVER, 0.31)
frames(1)
T.near(get(LEVER), 0.31, 0.001, "lever between detents: not yet")
frames(1.5)
T.near(get(LEVER), 0.333, 0.001, "2 s later: snapped to flaps 5")

T.done()
