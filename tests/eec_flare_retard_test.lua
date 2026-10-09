-- Run from the repository root with Lua 5.1 or LuaJIT.
-- Autothrottle IDLE during the autoland flare: the production EEC ecc_throttle
-- must not add thrust for low speed below 50 ft RA in an autoland, and must
-- retard to idle over about 2 s instead of cutting in 0.3 s. Away from the
-- autoland flare the low-speed thrust recovery in IDLE stays.
-- Simulator interfaces are mocks; this does not validate engine dynamics.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC.lua"
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end
local function load_in(path, runtime, first_marker, last_marker)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find(first_marker, 1, true))
    local last = assert(source:find(last_marker, first, true))
    setfenv(assert(loadstring(source:sub(first, last-1), "@"..path)), runtime)()
end

local DT = 0.05
-- A fresh EEC slice per scenario: spd_target_throttle and the speed-trend
-- state are chunk locals.
local function eec_runtime(values)
    local runtime = {
        print=function() end,
        SIM_PERIOD=DT,
        simDRTime=100,
        B747DR_airspeed_Vmc=143.6,
        simDR_autopilot_airspeed_kts=156,
        B747DR_engineType=1,
        B747DR_ref_thr_limit_mode="",
        throttle_resolver_angle_GE=function() return 0 end,
        B747DR_throttle_resolver_angle={[0]=0, 0, 0, 0},
        simDR_N1_target_bug={[0]=0, 0, 0, 0},
        B747DR_vnav_energy_active=0,
        B747DR_vnav_energy_thrust_policy=0,
        B747DR_ap_FMA_autothrottle_mode=2,
        simDR_onGround=0
    }
    for key, value in pairs(values) do runtime[key] = value end
    runtime.B747DR_throttle = {[0]=values.throttle, values.throttle, values.throttle, values.throttle}
    runtime.simDR_engine_throttle_jet_all = values.throttle
    setmetatable(runtime, {__index=_G})
    load_in(EEC, runtime, "function B747_animate_value", "function B747_setMaxThrust")
    load_in(EEC, runtime, "function B747_interpolate_value", "local previous_altitude = 0")
    runtime.ecc_throttle() -- first call only starts the frame timer
    return runtime
end
local function run(runtime, seconds, ias)
    runtime.simDR_ind_airspeed_kts_pilot = ias
    runtime.simDR_ias_pilot = ias
    for _ = 1, math.floor(seconds/DT + 0.5) do
        runtime.simDRTime = runtime.simDRTime + DT
        runtime.ecc_throttle()
    end
    return runtime.simDR_engine_throttle_jet_all
end

-- E1: IDLE in the autoland flare at 28 ft. The float bleeds the speed below
-- Vmc + 10 (153.6 kt); the thrust must stay at idle.
local r = eec_runtime({B747DR_ap_autoland=1, simDR_radarAlt1=28, throttle=0})
run(r, 1, 155)
local throttle = run(r, 5, 150)
check(throttle <= 0.001, "IDLE below Vmc + 10 in the autoland flare added thrust: "..throttle)

-- E2: retard at 24 ft from the approach thrust at 0.125 per second.
r = eec_runtime({B747DR_ap_autoland=1, simDR_radarAlt1=24, throttle=0.27})
throttle = run(r, 1, 155)
check(throttle >= 0.135, "autoland retard cut the thrust too fast: "..throttle.." after 1 s")
throttle = run(r, 3, 155)
check(throttle <= 0.01, "autoland retard did not reach idle: "..throttle.." after 4 s")

-- E3: guard. Outside the autoland flare, IDLE below Vmc + 10 still recovers
-- thrust.
r = eec_runtime({B747DR_ap_autoland=0, simDR_radarAlt1=3000, throttle=0})
throttle = run(r, 5, 150)
check(throttle > 0.01, "IDLE low-speed thrust recovery lost outside the autoland flare: "..throttle)

print("EEC flare retard regression tests passed: "..checks)
