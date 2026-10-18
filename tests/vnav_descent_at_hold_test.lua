-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The A/T's FMA in an idle VNAV PTH descent: IDLE while the A/T takes the
-- thrust levers back, then HOLD once they are at idle (the servos off), as on
-- a real 747-400 (THR, IDLE, HOLD); SPD when VNAV allows thrust for a slow
-- speed. It stayed IDLE all the way down.
-- The production B747_ap_fma runs in the autopilot's namespace
-- (approach_model.lua's loader) against mocked datarefs.
local model = dofile("tests/approach_model.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end

-- the EINN route, the 747 at FL250 well before the approach in a VNAV PTH descent with the energy guidance on
local o = model.einn()
local d = {}
local ap = model.load(d, {fmsData = o.fms_data, B747_route_constraints = o.constraints})
model.set_datarefs(d, o, 0.01)
local route = o.route
local elpom, bilto = route[6], route[5]
d.simDR_latitude, d.simDR_longitude = ap.movePoint(elpom[5], elpom[6], 80,
    ap.getHeading(elpom[5], elpom[6], bilto[5], bilto[6]))
for i = 1, #route do route[i][10] = (i == 6) end
d.B747DR_fmscurrentIndex = 6
d.simDR_pressureAlt1, d.simDR_radarAlt1 = 25000, 24950
d.simDR_ind_airspeed_kts_pilot, d.simDR_groundspeed = 270, 400 * 0.514444
d.simDR_vvi_fpm_pilot = -2000
d.B747DR_engine_TOGA_mode, d.B747DR_ap_autoland, d.B747DR_ap_thrust_mode = 0, 0, 0
d.B747DR_ap_vnav_state, d.B747DR_ap_inVNAVdescent = 2, 1
d.B747DR_autothrottle_active, d.B747DR_ap_autothrottle_armed = 1, 1
d.B747DR_vnav_energy_active = 1
d.simDRTime = 1000

local IDLE_POLICY = ap.B747_afds_helpers.VNAV_ENERGY_THRUST_IDLE
local ALLOW = ap.B747_afds_helpers.VNAV_ENERGY_THRUST_ALLOW
local function fma(policy, lever)
    d.B747DR_vnav_energy_thrust_policy = policy
    d.simDR_allThrottle = lever
    d.B747DR_throttle = {[0] = lever, lever, lever, lever}
    ap.B747_ap_fma(route)
    return d.B747DR_ap_FMA_autothrottle_mode
end

d.B747DR_ap_FMA_autothrottle_mode = 3
check(fma(IDLE_POLICY, 0.30) == 2, "levers coming back for the idle descent: IDLE, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.10) == 2, "still coming back: IDLE, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.0) == 1, "at idle: HOLD, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.0) == 1, "at idle on: HOLD, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(ALLOW, 0.0) == 3, "VNAV allows thrust for a slow speed: SPD, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(ALLOW, 0.15) == 3, "thrust on: SPD, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.15) == 2, "idle again, levers coming back: IDLE, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.0) == 1, "at idle again: HOLD, got "..d.B747DR_ap_FMA_autothrottle_mode)
-- from SPD straight to the idle policy with the levers already at idle: IDLE first, then HOLD
d.B747DR_ap_FMA_autothrottle_mode = 3
check(fma(IDLE_POLICY, 0.0) == 2, "from SPD with the levers at idle: IDLE first, got "..d.B747DR_ap_FMA_autothrottle_mode)
check(fma(IDLE_POLICY, 0.0) == 1, "then HOLD, got "..d.B747DR_ap_FMA_autothrottle_mode)

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("VNAV descent A/T HOLD tests passed: "..checks)
