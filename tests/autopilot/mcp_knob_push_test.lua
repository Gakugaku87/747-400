-- Run from the repository root with LuaJIT: luajit tests/autopilot/mcp_knob_push_test.lua
-- The MCP's altitude and speed knobs' pushes (FCOM p.649: the altitude
-- selector; p.643: the IAS/MACH selector's speed intervention in VNAV),
-- worked on each press, with or without its release (2026-11-08). Before,
-- a press while the knob's animation showed IN (its release not come: a
-- command once, the Web API's or another plugin's) only put the knob OUT
-- and did nothing else, so every other push was lost: s264's push after
-- the MCP reset kept VNAV ALT. In X-Plane through the Web API (duration 0)
-- the count went 2, 2, 3, 3 over three pushes; held 0.3 s, one each.
local T = dofile("tests/lib/check.lua")("mcp_knob_push")
local xtlua = dofile("tests/lib/xtlua.lua")

local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local PUSHES = "laminar/B747/autopilot/alt_sel_pushes"
local VNAV_STATE = "laminar/B747/autopilot/vnav_state"
local ALT_PUSH = "laminar/B747/button_switch/press_altitude"
local SPD_PUSH = "laminar/B747/button_switch/press_airspeed"

local rt = xtlua.new()
local ap = rt:load(AP)
rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("xtlua/fms", "[]")
rt:set("sim/time/total_running_time_sec", 10)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:callout("flight_start")
for _ = 1, 30 do rt:frame(1 / 30) end

-- a press alone (phase 0, as a command once that no release follows), and
-- a release alone
local function call(name, phase)
    local e = rt.commands[name]
    if e.before then e.before(phase, 0) end
    if e.handler then e.handler(phase, 0) end
    if e.after then e.after(phase, 0) end
end
local function press(name) call(name, 0) end
local function release(name) call(name, 2) end

-- the altitude selector: counted for the FMC and the AFDS on each press
local n0 = rt:get(PUSHES)
press(ALT_PUSH)
T.equal(rt:get(PUSHES), n0 + 1, "a press: one push")
press(ALT_PUSH)
T.equal(rt:get(PUSHES), n0 + 2, "a second press without the first's release: two (before: still one)")
press(ALT_PUSH)
T.equal(rt:get(PUSHES), n0 + 3, "a third: three (before: two)")
release(ALT_PUSH)
rt:command(ALT_PUSH)
T.equal(rt:get(PUSHES), n0 + 4, "a press and its release (the mouse's, a held button's): one more")
rt:command(ALT_PUSH)
T.equal(rt:get(PUSHES), n0 + 5, "and one more again")

-- the IAS/MACH selector with VNAV engaged: speed intervention on and off
-- on each press (the window's state the FMC's: laminar/B747/autopilot/
-- spd_intervention from it)
local getS = ap.ns.getVNAVState
rt:set(VNAV_STATE, 2)
rt:set("laminar/B747/autopilot/ap_monitor/switchingIASMode", 0)
local s0 = getS("manualVNAVspd")
press(SPD_PUSH)
T.equal(getS("manualVNAVspd"), 1 - s0, "a press with VNAV: speed intervention")
press(SPD_PUSH)
T.equal(getS("manualVNAVspd"), s0, "a second press without the first's release: off again (before: nothing)")
press(SPD_PUSH)
T.equal(getS("manualVNAVspd"), 1 - s0, "a third: on again (before: off, the second press lost)")
release(SPD_PUSH)
rt:command(SPD_PUSH)
T.equal(getS("manualVNAVspd"), s0, "a press and its release: off")
T.done()
