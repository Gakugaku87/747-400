-- Run from the repository root with Lua 5.1 or LuaJIT.
-- VNAV PTH energy thrust while the aircraft is high on the path and pitch
-- alone cannot recover it.  Once that limit has allowed thrust (reason 3),
-- the A/T must stay in SPD until the limit clears instead of switching back
-- to IDLE whenever the speed trend turns positive.  With the speedbrake
-- extended beyond ARM the A/T holds IDLE instead (reason 5) until underspeed
-- protection takes over, and then keeps that thrust while the limit lasts.
-- Part A calls the pure helper; part B runs the production setDescentVSpeed
-- loaded through the XTLua dofile.  Logic only; this does not validate
-- flight dynamics.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local nav = dofile(AP.."B747.70.xt.autopilot.afds_helpers.lua")

local checks = 0
local failures = {}
local function equal(actual, expected, message)
    checks = checks + 1
    if actual ~= expected then
        failures[#failures + 1] = message..": "..tostring(actual).." ~= "..tostring(expected)
    end
end

local IDLE = nav.VNAV_ENERGY_THRUST_IDLE
local ALLOW = nav.VNAV_ENERGY_THRUST_ALLOW
local NONE = nav.VNAV_ENERGY_THRUST_REASON_NONE
local PROTECTION = nav.VNAV_ENERGY_THRUST_REASON_UNDERSPEED_PROTECTION
local BELOW_PATH = nav.VNAV_ENERGY_THRUST_REASON_BELOW_PATH_BELOW_SPEED
local RECOVERY = nav.VNAV_ENERGY_THRUST_REASON_PATH_RECOVERY_LIMITED
local SPEEDBRAKE = 5

equal(nav.VNAV_ENERGY_THRUST_REASON_SPEEDBRAKE_HOLD, SPEEDBRAKE, "speedbrake hold reason number")
equal(nav.vnav_energy_thrust_reason_name(SPEEDBRAKE), "speedbrake hold", "speedbrake hold reason name")
equal(nav.VNAV_ENERGY_SPEEDBRAKE_EXTENDED_LEVER, 0.15, "extended threshold sits just above ARM (0.125)")

-- A: 2000 ft high, 9 kt slow and still slowing, nominal -2500 fpm: pitch
-- recovery is limited by the -3500 fpm descent limit.
local function guidance(changes)
    local input = {
        path_error_ft = 2000,
        path_trend_fpm = 0,
        target_speed_kts = 270,
        actual_speed_kts = 261,
        speed_trend_kts_per_sec = -0.1,
        nominal_vspeed_fpm = -2500,
        min_safe_speed_kts = 165,
        previous_path_axis = 1,
        previous_speed_axis = -1
    }
    for key, value in pairs(changes or {}) do input[key] = value end
    return nav.vnav_energy_guidance(input)
end
local function expect(result, policy, reason, message)
    equal(result.thrust_policy, policy, message.." (policy)")
    equal(result.thrust_reason, reason, message.." (reason)")
end

local first = guidance()
expect(first, ALLOW, RECOVERY, "A1 limited recovery still allows thrust with no previous policy")
equal(first.recovery_limited, true, "A1 the base case is recovery limited")

expect(guidance({previous_thrust_policy = ALLOW, previous_thrust_reason = RECOVERY,
    actual_speed_kts = 264, speed_trend_kts_per_sec = 0.4}),
    ALLOW, RECOVERY, "A2 allowed thrust is kept while it stops the deceleration")
expect(guidance({previous_thrust_policy = ALLOW, previous_thrust_reason = RECOVERY,
    actual_speed_kts = 270.5, path_error_ft = 3000}),
    ALLOW, RECOVERY, "A3 allowed thrust is kept on speed while the recovery is still limited")
local released = guidance({previous_thrust_policy = ALLOW, previous_thrust_reason = RECOVERY,
    actual_speed_kts = 270.5, path_error_ft = 1500})
expect(released, IDLE, NONE, "A4 the hold ends once pitch can recover the path")
equal(released.recovery_limited, false, "A4 the recovery limit has cleared")
expect(guidance({previous_thrust_policy = ALLOW, previous_thrust_reason = RECOVERY,
    actual_speed_kts = 276, path_error_ft = 3000}),
    IDLE, NONE, "A5 the hold ends when the speed is high")
expect(guidance({previous_thrust_policy = IDLE, previous_thrust_reason = NONE,
    actual_speed_kts = 264, speed_trend_kts_per_sec = 0.4}),
    IDLE, NONE, "A6 an idle descent does not start thrust while the speed is recovering")

local speedbrake_idle = guidance({speedbrake_lever = 0.53,
    previous_thrust_policy = IDLE, previous_thrust_reason = NONE})
expect(speedbrake_idle, IDLE, SPEEDBRAKE, "A7 speedbrake extended holds idle instead of reason 3")
equal(speedbrake_idle.thrust_reason_name, "speedbrake hold", "A7 reason name for the log")
equal(speedbrake_idle.drag_required, true, "A7 DRAG REQUIRED does not depend on the speedbrake")
expect(guidance({speedbrake_lever = 0.53, actual_speed_kts = 254}),
    ALLOW, PROTECTION, "A8 underspeed protection still adds thrust with the speedbrake out")
expect(guidance({speedbrake_lever = 0.53, previous_thrust_policy = ALLOW,
    previous_thrust_reason = PROTECTION, actual_speed_kts = 261, protection_active = true}),
    ALLOW, PROTECTION, "A9 protection thrust is kept above its release band while the recovery is limited")
expect(guidance({speedbrake_lever = 0.53, previous_thrust_policy = ALLOW,
    previous_thrust_reason = PROTECTION, actual_speed_kts = 261, protection_active = true,
    path_error_ft = 1000}),
    IDLE, NONE, "A9 protection thrust is not kept once pitch can recover the path")
expect(guidance({speedbrake_lever = 0.53, previous_thrust_policy = ALLOW,
    previous_thrust_reason = RECOVERY}),
    IDLE, SPEEDBRAKE, "A10 extending the speedbrake returns held recovery thrust to idle")

expect(guidance({speedbrake_lever = 0.2}), IDLE, SPEEDBRAKE,
    "lever 0.2 (beyond ARM) counts as extended")
expect(guidance({speedbrake_lever = 0.125}), ALLOW, RECOVERY,
    "lever 0.125 (ARM only) does not count as extended")
expect(guidance({speedbrake_lever = 0.53, path_error_ft = 1500, actual_speed_kts = 270.5}),
    IDLE, NONE, "speedbrake hold is reported only when thrust was otherwise wanted")
expect(guidance({speedbrake_lever = 0.53, path_error_ft = -500, actual_speed_kts = 261,
    previous_path_axis = -1}),
    ALLOW, BELOW_PATH, "below path and slow still allows thrust with the speedbrake out")

-- B: the production VNAV module, loaded with the XTLua dofile so it gets the
-- helper table through its own chunk, then sampled every 0.5 s.
local function load_in_environment(path, environment)
    local chunk, load_error = loadfile(path)
    assert(chunk ~= nil, load_error)
    setfenv(chunk, environment)
    chunk()
end

local runtime = {}
setmetatable(runtime, {__index = _G})
load_in_environment("plugins/xtlua_keysystems/init.lua", runtime)
runtime.XLuaGetCode = function(requested_path)
    local resolved_path = requested_path
    if not string.find(requested_path, "/", 1, true) then
        resolved_path = AP..requested_path
    end
    local chunk, load_error = loadfile(resolved_path)
    assert(chunk ~= nil, load_error)
    return chunk
end

local vnav = {}
setmetatable(vnav, {__index = _G})
vnav.dofile = runtime.get_run_file_in_namespace(vnav)
vnav.dofile(AP.."B747.70.xt.autopilot.vnav.lua")

-- 3000 ft high with 50 NM to a 10000 ft constraint at FL300, MCP 3000 ft,
-- Mach target, 270 kt selected and 262 kt slowing: VNAV PTH, energy control
-- active and the pitch recovery limited.
local sim = {
    simDRTime = 100,
    B747BR_totalDistance = 10, B747BR_fpe = 3000, B747BR_vnavProfile = "",
    B747DR_fmstargetDistance = 50, B747DR_ap_vnav_target_alt = 10000,
    simDR_pressureAlt1 = 30000, simDR_autopilot_altitude_ft = 3000,
    simDR_groundspeed = 230, simDR_radarAlt1 = 30000,
    B747DR_ap_inVNAVdescent = 2, B747DR_ap_vnav_state = 2,
    B747DR_ap_FMA_active_pitch_mode = 6, simDR_autopilot_vs_status = 2,
    simDR_autopilot_flch_status = 0, simDR_autopilot_alt_hold_status = 0,
    B747DR_autopilot_gs_status = 0, simDR_autopilot_gs_status = 0,
    B747DR_ap_approach_mode = 0, simDR_autopilot_approach_status = 0,
    B747DR_ap_autoland = 0, B747DR_ap_active_land = 0,
    B747DR_alt_capture_window = 1000,
    simDR_autopilot_airspeed_is_mach = 1, simDR_autopilot_airspeed_kts = 270,
    simDR_ind_airspeed_kts_pilot = 262, simDR_vvi_fpm_pilot = -3500,
    simDR_autopilot_vs_fpm = -2500, B747DR_airspeed_Vmc = 150,
    B747DR_speedbrake_lever = 0.53
}
for key, value in pairs(sim) do vnav[key] = value end

local function fly(samples, lever, ias_trend_kts_per_sec)
    for i = 1, samples do
        vnav.B747DR_speedbrake_lever = lever
        vnav.setDescentVSpeed({})
        vnav.simDRTime = vnav.simDRTime + 0.5
        vnav.simDR_ind_airspeed_kts_pilot = vnav.simDR_ind_airspeed_kts_pilot
            + ias_trend_kts_per_sec * 0.5
    end
end

fly(21, 0.53, -0.1)
equal(vnav.B747DR_vnav_energy_active, 1, "B energy control is active in VNAV PTH")
equal(vnav.B747DR_vnav_energy_thrust_policy, IDLE,
    "B speedbrake extended keeps the A/T at IDLE for 10 s while slowing")
equal(vnav.B747DR_vnav_energy_thrust_reason, SPEEDBRAKE,
    "B speedbrake hold is reported on the thrust reason dataref")
equal(vnav.B747DR_vnav_energy_drag_required, 1, "B DRAG REQUIRED stays set")

fly(12, 0, -0.1)
equal(vnav.B747DR_vnav_energy_thrust_policy, ALLOW,
    "B speedbrake stowed: limited recovery allows thrust after the entry delay")
equal(vnav.B747DR_vnav_energy_thrust_reason, RECOVERY, "B thrust reason is path recovery limited")

fly(16, 0, 0.4)
equal(vnav.B747DR_vnav_energy_thrust_policy, ALLOW,
    "B allowed thrust stays while the speed recovers and the recovery is still limited")
equal(vnav.B747DR_vnav_energy_thrust_reason, RECOVERY, "B thrust reason stays path recovery limited")

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV speedbrake thrust tests passed: "..checks)
