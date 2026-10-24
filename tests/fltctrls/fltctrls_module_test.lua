-- Run from the repository root with LuaJIT: luajit tests/fltctrls/fltctrls_module_test.lua
-- The flight controls module as XTLua runs it (tests/lib/xtlua.lua), with
-- the flap control units (B747.45.xt.fcu.lua, 4-1): the lever, the
-- hydraulic systems 1 and 4, the ducts, the buses and the airspeed in; the
-- surfaces for the hydraulics module, the FCUs' command, the indication,
-- the EICAS slots out; and the flap lever snapping to the nearest detent.
-- The FCU's behaviour is tested in fcu_model_test.lua; this checks the
-- wiring and the names (docs/overhaul/notes/ATA-27.md §4.3-§4.4).
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
local CMD = "laminar/B747/cablecontrols/flap_ratio"     -- the FCUs' command
local FCU = "laminar/B747/flt_ctrls/fcu/"
local CAUTION = "laminar/B747/CAS/caution_status"
local ADVISORY = "laminar/B747/CAS/advisory_status"
local STATUS = "laminar/B747/CAS/status_status"
local DISPLAY = "laminar/B747/flt_ctrls/flaps/EICAS1_display_status"
local TRANS = "laminar/B747/flt_ctrls/flap/transition_status"
local F20, F25, F30 = 4 / 6, 5 / 6, 1.0

-- power, hydraulics 1-4 and the ducts up, on the ground
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
rt:set("laminar/B747/hydraulics/pressure_4", 3000)
rt:set("laminar/B747/air/duct_pressure_L", 35)
rt:set("laminar/B747/air/duct_pressure_R", 35)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
for i = 0, 2 do rt:set("sim/flightmodel2/gear/deploy_ratio", i, 1) end
frames(4)                       -- past the start (3 s)
T.equal(get(DISPLAY), 0, "flaps up: no indication")

-- lever 1: group A out in about 9 s, the TE stay up; the indication shows,
-- the lever mark magenta, then green (FCOM p.954)
rt:set(LEVER, 1 / 6)
frames(4)
T.check(get(FCU .. "slat", 0) > 0.3 and get(FCU .. "slat", 0) < 0.6, "lever 1, 4 s: group A on its way")
T.equal(get(FCU .. "slat", 1), 0, "group B in")
T.equal(get(DISPLAY), 1, "normal indication")
T.equal(get(TRANS), 1, "moving: magenta")
frames(6)
T.equal(get(FCU .. "slat", 0), 1, "lever 1, 10 s: group A out")
T.equal(get(FCU .. "te_deg", 1), 0, "TE up at flaps 1")
T.equal(get(TRANS), 0, "in place: green")
T.near(get("laminar/B747/gauges/indicators/flap_deployed_ratio"), 1 / 6, 1e-6, "tape at 1")
-- lever 5: TE 5 at the stock rate (30 degrees in 45 s), group B
rt:set(LEVER, 2 / 6)
frames(9.5)
for i = 0, 3 do T.near(get(FCU .. "te_deg", i), 5, 1e-6, "lever 5: TE panel " .. i .. " at 5 degrees") end
T.equal(get(FCU .. "slat", 1), 1, "group B out")
T.equal(get(FCU .. "te_moving"), 0, "TE at rest")
T.equal(get(FCU .. "te_down"), 1, "TE out: to the demand pumps")
T.near(get(CMD), 2 / 6, 1e-6, "the FCUs' command: lever 5")

-- system 1 lost with a command: the inboard TE to secondary after 4 s,
-- FLAPS PRIMARY, expanded indication; back with the pressure
rt:set("laminar/B747/hydraulics/pressure_1", 0)
rt:set(LEVER, 3 / 6)
frames(4.5)
T.equal(get(FCU .. "te_mode", 0), 1, "system 1 lost: inboard TE secondary")
T.equal(get(CAUTION, 30), 1, "FLAPS PRIMARY")
T.equal(get(DISPLAY), 2, "expanded indication")
rt:set("laminar/B747/hydraulics/pressure_1", 3000)
frames(4.5)
T.equal(get(FCU .. "te_mode", 0), 0, "pressure back: primary")
frames(10)
T.equal(get(CAUTION, 30), 0, "no FLAPS PRIMARY")
T.near(get(FCU .. "te_deg", 1), 10, 1e-6, "flaps 10")

-- load relief (FCOM p.954; ATA27 p.288-289): lever 30, 30->25 at 178 kt,
-- 25->20 at 203 kt; back 20->25 at 195 kt, 25->30 at 170 kt; >FLAP RELIEF
local function at(kt)
    rt:set(IAS, kt)
    frames(0.2)
end
rt:set(LEVER, F30)
at(160)
T.near(get(CMD), F30, 0.001, "lever 30, 160 kt: flaps 30")
T.equal(get(ADVISORY, 142), 0, "no >FLAP RELIEF")
at(180)
T.near(get(CMD), F25, 0.001, "lever 30, 180 kt: relieved to 25")
T.equal(get(ADVISORY, 142), 1, ">FLAP RELIEF")
at(205)
T.near(get(CMD), F20, 0.001, "lever 30, 205 kt: relieved to 20")
at(200)
T.near(get(CMD), F20, 0.001, "lever 30, back to 200 kt: still 20 (195 kt)")
at(194)
T.near(get(CMD), F25, 0.001, "lever 30, 194 kt: back to 25")
at(172)
T.near(get(CMD), F25, 0.001, "lever 30, 172 kt: still 25 (170 kt)")
at(168)
T.near(get(CMD), F30, 0.001, "lever 30, 168 kt: back to 30")
T.equal(get(ADVISORY, 142), 0, ">FLAP RELIEF cleared")
rt:set(LEVER, F25)
at(205)
T.near(get(CMD), F20, 0.001, "lever 25, 205 kt: relieved to 20")
at(193)
T.near(get(CMD), F25, 0.001, "lever 25, 193 kt: back to 25")
at(140)

-- the failures X-Plane does not have: an LE pneumatic drive (electric after
-- 30 s, LE SINGLE DRIVE), an FCU (STATUS FLAP CONTROL L)
rt:set(LEVER, 0)
frames(60)
T.equal(get(FCU .. "slat", 0), 0, "UP: all in")
rt:set(FCU:gsub("fcu/$", "fail/") .. "le_primary", 2, 1)
rt:set(LEVER, 2 / 6)
frames(31)
T.equal(get(FCU .. "le_mode", 2), 1, "outboard LE pneumatic drive failed: electric")
T.equal(get(CAUTION, 30), 1, "FLAPS PRIMARY")
T.equal(get(STATUS, 82), 1, "STATUS LE SINGLE DRIVE")
rt:set(FCU:gsub("fcu/$", "fail/") .. "le_primary", 2, 0)
rt:set(FCU:gsub("fcu/$", "fail/") .. "fcu", 0, 1)
frames(1)
T.equal(get(STATUS, 84), 1, "FCU L failed: STATUS FLAP CONTROL L")
T.equal(get(CAUTION, 28), 0, "two FCUs left: no FLAPS CONTROL")
rt:set(FCU:gsub("fcu/$", "fail/") .. "fcu", 0, 0)

-- ALTN FLAPS ARM: FLAPS CONTROL, expanded indication, the lever does
-- nothing; EXT drives all groups
rt:set("laminar/B747/button_switch/position", 0, 1)
frames(1)
T.equal(get(CAUTION, 28), 1, "ALTN ARM: FLAPS CONTROL")
T.equal(get(DISPLAY), 2, "expanded indication")
local was = get(FCU .. "te_deg", 1)
rt:set(LEVER, F30)
frames(3)
T.near(get(FCU .. "te_deg", 1), was, 1e-6, "the lever does nothing")
rt:set("laminar/B747/flt_ctrls/alt_flaps/sel_dial_pos", 1)
frames(3)
T.check(get(FCU .. "te_deg", 1) > was, "ALTN EXT: the TE move (electric)")
rt:set("laminar/B747/flt_ctrls/alt_flaps/sel_dial_pos", 0)
rt:set("laminar/B747/button_switch/position", 0, 0)
frames(1)
T.equal(get(CAUTION, 28), 0, "disarmed: no FLAPS CONTROL")

-- the lever between detents snaps to the nearest one 2 s after it stops
rt:set(LEVER, 0.31)
frames(1)
T.near(get(LEVER), 0.31, 0.001, "lever between detents: not yet")
frames(1.5)
T.near(get(LEVER), 0.333, 0.001, "2 s later: snapped to flaps 5")

T.done()
