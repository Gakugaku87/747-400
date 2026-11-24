-- Run from the repository root with LuaJIT: luajit tests/hyd/afds_roll_engage_test.lua
-- The A/P's inner roll loop at an engagement, in the hydraulics module as
-- XTLua runs it (tests/lib/xtlua.lua; B747.19.xt.afds_control.lua),
-- 2026-11-24: the stage 4 fixes' X-Plane check s381 (the review's AFDS-5,
-- the roll's side). The roll law's command starts from the bank at an A/P's
-- engagement (ATA22 p.348 (22-12 p.22); B747.70.afds_roll_model.lua's sync),
-- and this module reads the command a frame late: on the engagement's first
-- frame the F/D's command wound up with nobody following the bars (25
-- degrees left), on the next the bank. The jump is the law's restart, not a
-- rate of the command: before, read as 1,250 degrees a second it put the
-- ailerons right at the single channel's limit for a second, and the
-- airplane rolled 3 degrees the wrong way before the turn (s381).
local T = dofile("tests/lib/check.lua")("afds_roll_engage")
local xtlua = dofile("tests/lib/xtlua.lua")

math.randomseed(1)
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.19.xt.hydraulicsmodel/B747.19.xt.hydraulicsmodel.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")
-- XTLua's SIM_PERIOD is always 0.02 (tests/lib/xtlua.lua: still())
local DT = 0.02
local function frames(n) for _ = 1, n do rt:frame(DT) end end
local AIL = "laminar/B747/flt_ctrls/sim_roll_ratio"
local BANK, CMD = "sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", "laminar/B747/autopilot/roll_cmd"
local SERVOS = "laminar/B747/autopilot/servos_on"
frames(25)
rt:set("sim/cockpit2/gauges/indicators/airspeed_kts_pilot", 290)
rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 10000)
rt:set("laminar/B747/autopilot/FMA/active_roll_mode", 6)     -- HDG SEL
rt:set("laminar/B747/autopilot/roll_law", 1)
rt:set("laminar/B747/autopilot/cmd_L_mode/status", 1)        -- one channel
-- F/D only, HDG SEL 60 degrees left not followed: the wings level, the
-- F/D's command at the bank limit
rt:set(BANK, 0.6)
rt:set(CMD, -25)
rt:set(SERVOS, 0)
frames(50)
T.near(rt:get(AIL), 0, 0.001, "the A/P off: its aileron command neutral (" .. rt:get(AIL) .. ")")

-- CMD L: the first engaged frame still has the F/D's -25, then the law's
-- command from the bank, on at 3 degrees a second to the left
rt:set(SERVOS, 1)
frames(1)
local c = 0.2
rt:set(CMD, c)
local most_right, at_1s = 0, nil
for i = 1, 100 do
    frames(1)
    c = math.max(-25, c - 3 * DT)
    rt:set(CMD, c)
    most_right = math.max(most_right, rt:get(AIL))
    if i == 50 then at_1s = rt:get(AIL) end
end
T.check(most_right < 0.01, string.format("the 2 s after the engagement: the ailerons never right of neutral (most %.3f; before, 0.278 at the single channel's limit)", most_right))
T.check(at_1s < -0.005, string.format("a second on: left aileron for the roll to the left (%.3f)", at_1s))

-- the command's own rate still goes into the loop: the same roll-in with
-- the A/P engaged on the bank before it (no jump) asks for the same left
-- aileron within a few hundredths
rt:set(SERVOS, 0)
rt:set(CMD, 0.6)
frames(50)
rt:set(SERVOS, 1)
frames(2)
c = 0.6
local at_1s_b
for i = 1, 50 do
    frames(1)
    c = c - 3 * DT
    rt:set(CMD, c)
    if i == 50 then at_1s_b = rt:get(AIL) end
end
T.near(at_1s, at_1s_b, 0.03, string.format("a second into the roll-in: %.3f after the jump, %.3f without one", at_1s, at_1s_b))

T.done()
