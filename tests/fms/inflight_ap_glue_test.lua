-- Run from the repository root with LuaJIT: luajit tests/fms/inflight_ap_glue_test.lua
-- The in-flight start in the FMS module as XTLua runs it (activate_inflightAP,
-- tests/lib/xtlua.lua): a flight started in the air with the engines running
-- turns F/D L on, arms the A/T, then ALT HOLD and CMD L. The F/D waits for
-- two IRUs' headings (laminar/B747/irs/hdg_valid): the F/D's HDG HOLD with
-- fewer fails until a new mode (the AFDS's mode failures, 6-3 step 5c), and
-- the IRS module starts 3 s after the load (2026-11-01: s179's air start kept
-- HDG HOLD failed). Without them, it goes on after 30 s. The mock's timers
-- are XTLua's (a run_after_time set again from its own function is lost:
-- the first version of the wait never turned the F/D on in X-Plane, s180).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("inflight_ap_glue")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local HDG = "laminar/B747/irs/hdg_valid"
local function headings(a, b, c)
    rt:set(HDG, 0, a)
    rt:set(HDG, 1, b)
    rt:set(HDG, 2, c)
end
local function count(name)
    local n = 0
    for _, e in ipairs(rt.command_log) do
        if e.name == name and e.phase == "once" then n = n + 1 end
    end
    return n
end
local FD = "laminar/B747/toggle_switch/flight_dir_L"
local AT = "laminar/B747/authrottle_arm"
local ALT = "laminar/B747/autopilot/button_switch/alt_hold_mode"
local CMD = "laminar/B747/autopilot/button_switch/cmd_L"

-- the airspeed now and the old minimum (Vmc + 10 = 214.6 kt)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 334)
rt:set("laminar/B747/airspeed/Vmc", 204.6)
-- the IRUs' headings late, as the IRS module 3 s after the load
headings(0, 0, 0)
rt:callout("flight_start")
frames(6)
T.equal(count(FD), 0, "no heading: F/D L not on")
T.equal(count(AT), 0, "no heading: the A/T not armed")
T.equal(count(CMD), 0, "no heading: no CMD L")
headings(1, 0, 0)
frames(1)
T.equal(count(FD), 0, "one IRU's heading: F/D L not on")
headings(1, 0, 1)
frames(0.6)
T.equal(count(FD), 1, "two IRUs' headings: F/D L on")
T.equal(count(AT), 1, "the A/T armed")
T.equal(rt:get("laminar/B747/autopilot/speed/target"), 334, "the MCP's speed: the airspeed now (before: min with Vmc + 10, 214)")
T.equal(count(ALT), 0, "ALT HOLD a second later")
frames(1.1)
T.equal(count(ALT), 1, "then ALT HOLD")
T.check(count(CMD) >= 1, "and CMD L (again every 0.5 s until it engages)")
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)
local cmd1 = count(CMD)
frames(2)
T.equal(count(CMD), cmd1, "CMD L engaged: not pressed again")
T.equal(count(FD), 1, "F/D L once")

-- a new flight in the air, the IRUs never valid: on after 30 s (slow:
-- the MCP's speed not below Vmc + 10)
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 0)
rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 180)
headings(0, 0, 0)
local fd0, cmd0 = count(FD), count(CMD)
rt:callout("flight_start")
frames(20)
T.equal(count(FD), fd0, "20 s without the headings: F/D L not on")
T.equal(count(CMD), cmd0, "nor CMD L")
frames(14)
T.equal(count(FD), fd0 + 1, "after 30 s: F/D L on anyway")
T.equal(rt:get("laminar/B747/autopilot/speed/target"), 214, "180 kt: the MCP's speed Vmc + 10")
T.check(count(CMD) > cmd0, "and CMD L")

-- on the ground: none of it
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
headings(1, 1, 1)
fd0 = count(FD)
rt:callout("flight_start")
frames(6)
T.equal(count(FD), fd0, "on the ground: F/D L not switched")

T.done()
