-- Run from the repository root with LuaJIT: luajit tests/autopilot/afds_adc_source_test.lua
-- (2026-11-13) The AFDS's altitude and vertical speed: the V/S command is
-- the MCP's V/S less the IRU's inertial V/S (ATA22 p.344), ALT's the
-- altitude difference with the inertial V/S for damping (p.346); FCC L and
-- C take the Captain's selected ADC, FCC R the F/O's (p.204). Before, the
-- glue read X-Plane's Captain's altimeter and VSI and its VVI (vh_ind_fpm):
-- with the Captain's static port blocked they stopped, and V/S -2,500 pitched to -10 degrees from
-- FL350 into the sea with the Captain's AIR DATA switch at R (s318).
-- Through the real glue (B747.70.xt.autopilot.lua) on the XTLua mock.
local xtlua = dofile("tests/lib/xtlua.lua")
local T = dofile("tests/lib/check.lua")("afds_adc_source")
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.xt.autopilot.lua"
local CMD = "laminar/B747/autopilot/button_switch/"
local PITCH = "laminar/B747/autopilot/FMA/active_pitch_mode"
local PC = "laminar/B747/autopilot/pitch_cmd"
local XP_ALT, XP_VSI = "sim/cockpit2/gauges/indicators/altitude_ft_pilot", "sim/cockpit2/gauges/indicators/vvi_fpm_pilot"
local ALT_C, ALT_F = "laminar/B747/airdata/alt_capt", "laminar/B747/airdata/alt_fo"
-- X-Plane's VVI follows the Captain's static system (0 with the port
-- blocked: s318's second run); the inertial V/S its vertical velocity
local XP_VVI, VY = "sim/flightmodel/position/vh_ind_fpm", "sim/flightmodel/position/local_vy"
local FPM = 196.850394
local IVS = VY
local ATT = "sim/cockpit2/gauges/indicators/pitch_AHARS_deg_pilot"

-- level at FL350, 280 kt, the MCP at FL300; X-Plane's Captain's altimeter
-- and VSI stopped at 35,000 ft and 0 (the static port blocked)
local function setup()
    local rt = xtlua.new()
    rt:load(AP)
    rt:set("laminar/B747/simconfig", '{"PLANE":{"engines":"PW4056"}}')
    rt:set("laminar/B747/newsimconfig", 1)
    rt:set("xtlua/fms", "[]")
    rt:set("sim/time/total_running_time_sec", 10)
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot", 2500)
    for i = 1, 3 do rt:set("laminar/B747/hydraulics/pressure_" .. i, 3000) end
    for i = 0, 3 do
        rt:set("laminar/B747/electrical/bus/ac", i, 1)
        rt:set("laminar/B747/electrical/bus/dc", i, 1)
    end
    rt:set("laminar/B747/electrical/bus/bat_main", 1)
    rt:set("laminar/B747/electrical/bus/xfr_fo", 1)
    for i = 0, 2 do
        rt:set("laminar/B747/irs/att_valid", i, 1)
        rt:set("laminar/B747/airdata/valid", i, 1)
        rt:set("laminar/B747/irs/hdg_valid", i, 1)
        rt:set("laminar/B747/irs/nav_valid", i, 1)
    end
    for i = 0, 1 do
        rt:set("laminar/B747/flt_ctrls/stab_trim/autotrim_valid", i, 1)
        rt:set("laminar/B747/flt_ctrls/stab_trim/srm_valid", i, 1)
        rt:set("laminar/B747/fms/fmc_ok", i, 1)
    end
    rt:set(XP_ALT, 35000)
    rt:set(XP_VSI, 0)
    rt:set(XP_VVI, 0)
    -- X-Plane's Captain's TAS gauge wrong (its static port blocked: s318
    -- read high); the AFDS's TAS its FCC's ADC's (B747_afds_tas)
    rt:set("sim/cockpit2/gauges/indicators/true_airspeed_kts_pilot", 900)
    rt:set(ALT_C, 35000)
    rt:set(ALT_F, 35000)
    rt:set(IVS, 0)
    rt:set(ATT, 2)
    -- (2026-11-13) the TAS 480 kt: the FCC's ADC's Mach at 15 degrees C (B747_afds_tas)
    rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15)
    rt:set("laminar/B747/airdata/mach_capt", 480 / 661.47)
    rt:set("laminar/B747/airdata/mach_fo", 480 / 661.47)
    rt:set("laminar/B747/gauges/indicators/airspeed_kts_pilot", 280)
    rt:set("sim/flightmodel/misc/machno", 0.84)
    rt:callout("flight_start")
    -- (the flight start sets the MCP altitude to 10,000 ft)
    rt:set("laminar/B747/autopilot/altitude_dial_ft", 30000)
    rt:set("laminar/B747/autopilot/heading/altitude_dial_ft", 30000)
    return rt
end
local function frames(rt, n) for _ = 1, n do rt:frame(1 / 30) end end

-- 1. CMD L, V/S -2,500; the AIR DATA switch at the center ADC: the
-- Captain's ADC altitude descends at the inertial V/S, X-Plane's
-- altimeter and VSI stay
local rt = setup()
frames(rt, 30)
-- descending 1,840 fpm (inertial), the VSI stopped at 0: CMD L's V/S
-- synchronizes to the inertial V/S (before, to the VSI's 0)
rt:set(IVS, -1840 / FPM)
rt:command(CMD .. "cmd_L")
frames(rt, 5)
T.equal(rt:get("laminar/B747/autopilot/servos_on"), 1, "CMD L: the A/P engaged")
rt:command(CMD .. "vs_mode")
frames(rt, 3)
T.equal(rt:get(PITCH), 7, "V/S")
T.equal(rt:get("sim/cockpit2/autopilot/vvi_dial_fpm"), -1800, "V/S synchronized to the inertial -1,840 fpm: -1,800 (the VSI stopped at 0)")
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", -2500)
rt:set(ATT, -1)
rt:set(IVS, -2500 / FPM)
local alt = 35000
local c0
for i = 1, 30 * 10 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_C, alt)
    rt:frame(1 / 30)
    if i == 30 then c0 = rt:get(PC) end
end
local c1 = rt:get(PC)
T.check(math.abs(c1 - c0) < 0.5, string.format("10 s at the MCP's -2,500 fpm (inertial), the VSI stopped at 0: the command held (%.2f from %.2f)", c1, c0))
T.equal(rt:get(PITCH), 7, "still V/S above the capture")
-- down to the MCP altitude on the ADC's altitude: ALT captures
local capt_at
alt = 31500
for _ = 1, 30 * 60 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_C, alt)
    rt:frame(1 / 30)
    if rt:get(PITCH) == 9 then capt_at = alt; break end
end
-- (at 2,500 fpm the level-off's 720 ft and 10 s of it: 1,136 ft above; on a
-- V/S of 0 only within CAPTURE_NEAR, 20 ft)
T.check(capt_at ~= nil and capt_at > 30900 and capt_at < 31200,
    "the capture of FL300 on the ADC's altitude and the inertial V/S, 1,136 ft above (X-Plane's altimeter stopped at 35,000): at " .. tostring(capt_at and math.floor(capt_at)))
-- the capture's pull-up on the inertial V/S: still 2,500 fpm down 300 ft
-- above (the level-off's V/S there 1,614 fpm), the command up
local pc0 = rt:get(PC)
while alt > 30300 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_C, alt)
    rt:frame(1 / 30)
end
-- (the command's rate the 0.05 g limit at the ADC's 480 kt: 1.77 degrees;
-- on the wrong gauge's 900 kt 0.94: s318's slow capture)
T.check(rt:get(PC) > pc0 + 1.4, string.format("2,500 fpm down 300 ft above: the command up at the ADC's TAS's rate (%.2f from %.2f at the capture)", rt:get(PC), pc0))

-- 2. CMD R alone: the F/O's ADC. The Captain's ADC altitude stopped at
-- 35,000 (a blocked static on ADC L), the F/O's descends: ALT captures
rt = setup()
frames(rt, 30)
rt:command(CMD .. "cmd_R")
frames(rt, 5)
T.equal(rt:get("laminar/B747/autopilot/cmd_R_mode/status"), 1, "CMD R: engaged")
T.equal(rt:get("laminar/B747/autopilot/cmd_L_mode/status"), 0, "CMD L: off")
rt:command(CMD .. "vs_mode")
frames(rt, 3)
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", -2500)
rt:set(IVS, -2500 / FPM)
capt_at = nil
alt = 31500
for _ = 1, 30 * 60 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_F, alt)
    rt:frame(1 / 30)
    if rt:get(PITCH) == 9 then capt_at = alt; break end
end
T.check(capt_at ~= nil and capt_at > 30900 and capt_at < 31200,
    "CMD R: the capture on the F/O's ADC (the Captain's stopped at 35,000): at " .. tostring(capt_at and math.floor(capt_at)))

-- 3. CMD L with the same air data: FCC L's ADC is the Captain's, stopped
-- above the MCP altitude: no capture (the crew selects the other ADC)
rt = setup()
frames(rt, 30)
rt:command(CMD .. "cmd_L")
frames(rt, 5)
rt:command(CMD .. "vs_mode")
frames(rt, 3)
rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", -2500)
rt:set(IVS, -2500 / FPM)
local captured = false
alt = 31500
for _ = 1, 30 * 50 do
    alt = alt - 2500 / 60 / 30
    rt:set(ALT_F, alt)
    rt:frame(1 / 30)
    if rt:get(PITCH) == 9 then captured = true; break end
end
T.check(not captured, "CMD L: the F/O's ADC through FL300 is not FCC L's: no capture (V/S on)")
T.equal(rt:get(PITCH), 7, "V/S still")

-- 4. the inertial V/S up at the airplane: 48 km from X-Plane's local
-- frame's origin, flying away from it at 150 m/s, the frame's y velocity
-- alone is 222 fpm low (X-Plane: -234 fpm against the VVI's -58); with the
-- earth's curve -1,840 fpm: V/S synchronized to -1,800 (local_vy alone
-- -2,062: -2,100)
rt = setup()
rt:set("sim/flightmodel/position/local_z", -48000)
rt:set("sim/flightmodel/position/local_vz", -150)
rt:set(VY, (-1840 - 150 * 48000 / 6371000 * FPM) / FPM)
frames(rt, 30)
rt:command(CMD .. "cmd_L")
frames(rt, 5)
rt:command(CMD .. "vs_mode")
frames(rt, 3)
T.equal(rt:get("sim/cockpit2/autopilot/vvi_dial_fpm"), -1800,
    "48 km from the local frame's origin: the V/S up at the airplane -1,840 fpm, synchronized to -1,800")

T.done()
