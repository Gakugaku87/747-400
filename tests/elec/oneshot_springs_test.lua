-- Run from the repository root with LuaJIT: luajit tests/elec/oneshot_springs_test.lua
-- (2026-11-12 review SM-2, DSP-6; REVIEW_2026-11-12.md case 13) Spring-loaded
-- switches pressed by a one-shot command (X-Plane's "once": a hardware
-- button, the Web API at duration 0, the CDU's EICAS MODES; XTLua passes
-- the press without its release, PROGRESS.md) come back by themselves: IND
-- LTS TEST (FCOM p.441), OUTFLOW VALVE MANUAL OPEN and CLOSE (p.574), PACK
-- RESET, ZONE RESET, CARGO FIRE DISCH, the C and R seats' PTT (p.683-684),
-- RCL (p.1528). A press held (its events every frame) keeps them. Before,
-- such a press left them held (TEST lit for good, the outflow valve
-- driving, the PTT keyed, RECALL on). CLOSE from OPEN too.
local T = dofile("tests/lib/check.lua")("oneshot_springs")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.01.xt.manipulators/B747.01.xt.manipulators.lua")
rt:load("plugins/xtlua/scripts/B747.15.xt.com/B747.15.xt.com.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("laminar/B747/electrical/bus/bat_main", 1)
rt:set("laminar/B747/electrical/bus/bat_apu", 1)
rt:callout("flight_start")
local function settle(s) for _ = 1, math.floor(s * 30) do rt:frame(1 / 30) end end
settle(2)

-- the press's events: phase 0 only (the release never comes), or held
local function once(name)
    local e = rt.commands[name]
    assert(e, "no handler: " .. name)
    if e.before then e.before(0, 0) end
    if e.handler then e.handler(0, 0) end
    if e.after then e.after(0, 0) end
end
local function held(name, seconds)
    local e = rt.commands[name]
    local function call(phase, d)
        if e.before then e.before(phase, d) end
        if e.handler then e.handler(phase, d) end
        if e.after then e.after(phase, d) end
    end
    call(0, 0)
    local t = 0
    while t < seconds do rt:frame(1 / 30); t = t + 1 / 30; call(1, t) end
end
local TS, BS = "laminar/B747/toggle_switch/position", "laminar/B747/button_switch/position"
local ATS = "laminar/B747/ap/toggle_sw_pos"

-- IND LTS TEST
rt:set(TS, 13, 0)
once("laminar/B747/toggle_switch/ind_light_up")
settle(0.1)
T.equal(rt:get(TS, 13) > 0.5, true, "IND LTS: TEST on the press")
settle(2)
T.equal(rt:get(TS, 13), 0, "IND LTS: back to BRT by itself (FCOM p.441)")
held("laminar/B747/toggle_switch/ind_light_up", 1.5)
T.equal(rt:get(TS, 13), 1, "IND LTS: TEST while held")
settle(2)
T.equal(rt:get(TS, 13), 0, "and back")

-- OUTFLOW VALVE MANUAL: OPEN, CLOSE, CLOSE from OPEN
once("laminar/B747/toggle_switch/outflow_valve_open")
settle(2)
T.equal(rt:get(TS, 22), 0, "OUTFLOW OPEN: back to the centre by itself (FCOM p.574)")
once("laminar/B747/toggle_switch/outflow_valve_close")
settle(0.15)
T.equal(rt:get(TS, 22) < -0.5, true, "OUTFLOW CLOSE on the press")
settle(2)
T.equal(rt:get(TS, 22), 0, "OUTFLOW CLOSE: back to the centre")
held("laminar/B747/toggle_switch/outflow_valve_open", 1)
once("laminar/B747/toggle_switch/outflow_valve_close")
settle(0.15)
T.equal(rt:get(TS, 22) < -0.5, true, "OUTFLOW CLOSE from OPEN")
settle(2)

-- the reset and discharge buttons
for _, b in ipairs({{"temp_pack_rst", 42}, {"temp_zone_rst", 36}, {"cargo_fire_disch", 86}}) do
    once("laminar/B747/button_switch/" .. b[1])
    settle(2)
    T.equal(rt:get(BS, b[2]), 0, b[1] .. ": back out by itself")
end

-- the C and R seats' PTT
for i, seat in ipairs({"C", "R"}) do
    once("laminar/B747/ap_" .. seat .. "/ptt/sel_switch_up")
    settle(2)
    T.check(math.abs(rt:get(ATS, i)) < 0.01, seat .. "'s PTT R/T: back to the centre (FCOM p.683-684): " .. rt:get(ATS, i))
    once("laminar/B747/ap_" .. seat .. "/ptt/sel_switch_dn")
    settle(2)
    T.check(math.abs(rt:get(ATS, i)) < 0.01, seat .. "'s PTT INT: back to the centre: " .. rt:get(ATS, i))
end

-- RCL: RECALL out after the switch comes back by itself
once("laminar/B747/dsp/rcl_switch")
settle(0.1)
T.equal(rt:get("laminar/B747/CAS/recall_ind"), 1, "RCL: RECALL on the press")
settle(3)
T.equal(rt:get("laminar/B747/CAS/recall_ind"), 0, "RCL: RECALL out by itself (1 s after the switch came back)")
T.equal(rt:get("laminar/B747/dsp/rcl_switch_pos") or 0, 0, "RCL: the switch back")
T.done()
