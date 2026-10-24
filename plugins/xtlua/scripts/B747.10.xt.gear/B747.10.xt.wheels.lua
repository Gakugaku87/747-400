-- The brake temperature model (B747.10.btms_model.lua) and the tire
-- pressure model (B747.10.tpis_model.lua) in the aircraft (4-2 step 5):
-- reads the energy X-Plane's brakes absorb (brake_absorbed_J, each main gear
-- truck's four brakes sharing it), the outside air, the PSEU and the gear's
-- positions (the gear down in flight cools the brakes), each gear's weight on
-- its wheels and X-Plane's tire failures (rel_tire1-5, gear 0-4), the thrust
-- levers and the failures; writes each brake's temperature
-- (laminar/B747/gear/brake_temp, °C: the synoptic's colour and the 3D brake
-- glow) and indication (brake_temp_ind, 0-9), the tires' pressures
-- (tire_pressure, psi), BRAKE TEMP, >TIRE PRESSURE, BRAKE TEMP SYS and
-- TIRE PRESS SYS.
-- B747.10.xt.gear.lua loads it after the steering's glue and uses its
-- bindings (the PSEU, the gear's positions, the thrust levers).
dofile("B747.10.btms_model.lua")
dofile("B747.10.tpis_model.lua")
local BT = B747_btms_model
local TP = B747_tpis_model

simDR_whl_absorbed              = find_dataref("sim/flightmodel2/gear/brake_absorbed_J")
simDR_whl_on_ground             = find_dataref("sim/flightmodel2/gear/on_ground")
simDR_whl_oat                   = find_dataref("sim/cockpit2/temperature/outside_air_temp_degc")
simDR_whl_time                  = find_dataref("sim/time/total_running_time_sec")
simDR_whl_tire_fail             = {
    find_dataref("sim/operation/failures/rel_tire1"), find_dataref("sim/operation/failures/rel_tire2"),
    find_dataref("sim/operation/failures/rel_tire3"), find_dataref("sim/operation/failures/rel_tire4"),
    find_dataref("sim/operation/failures/rel_tire5")}
B747DR_whl_brake_temp           = find_dataref("laminar/B747/gear/brake_temp")
B747DR_whl_brake_temp_ind       = find_dataref("laminar/B747/gear/brake_temp_ind")
B747DR_whl_tire_pressure        = find_dataref("laminar/B747/gear/tire_pressure")
B747DR_whl_fail_btms            = find_dataref("laminar/B747/gear/fail/btms")
B747DR_whl_fail_tpis            = find_dataref("laminar/B747/gear/fail/tpis")
B747DR_whl_status               = find_dataref("laminar/B747/CAS/status_status")

-- X-Plane's gear (0 nose, 1 right body, 2 left body, 3 right wing, 4 left
-- wing) of the brakes 1-4 (left wing), 5-8 (left body), 9-12 (right body),
-- 13-16 (right wing), and of the tires 17-18 (nose)
local XP_TRUCK = {4, 2, 1, 3}
-- EICAS slots (B747.87.xt.warning.lua)
local ADV_BRAKE_TEMP, ADV_TIRE_PRESSURE = 46, 290
local STATUS_BRAKE_TEMP_SYS, STATUS_TIRE_PRESS_SYS = 97, 98
local INIT_S = 3                    -- the first reads are 0: no heat from them
-- estimates (no values in the sources): the tires' pressures as serviced
-- (198-210 psi, as before), 10 psi more with the weight on them, how fast a
-- pressure changes (a burst tire empties in seconds); the thrust lever angle
-- of the takeoff thrust inhibiting >TIRE PRESSURE
local LOADED_PSI = 10
local FLAT_PSI = 5
local PSI_RATE, FLAT_RATE = 2, 50
local TAKEOFF_LEVER = 0.7

local whl_btms = BT.new(15)
local whl_btms_in = BT.inputs()
local whl_tpis_in = TP.inputs()
local whl_last_j = {}
local whl_t0 = nil
local whl_serviced = {}
math.randomseed(os.time())
for i = 1, 18 do whl_serviced[i] = math.random(198, 210) end

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

local function toward(x, target, step)
    if x < target then return math.min(x + step, target) end
    return math.max(x - step, target)
end

function B747_wheels_flight_start()
    whl_btms = BT.new(simDR_whl_oat)
    whl_last_j = {}
    whl_t0 = nil
end

function B747_wheels()
    local now = simDR_whl_time
    if whl_t0 == nil then whl_t0 = now end
    local init = now - whl_t0 < INIT_S

    -- the brakes: each truck's absorbed energy shared by its four brakes
    local bi = whl_btms_in
    for t = 1, 4 do
        local j = simDR_whl_absorbed[XP_TRUCK[t]]
        local dj = 0
        if not init and whl_last_j[t] ~= nil and j > whl_last_j[t] then dj = (j - whl_last_j[t]) / 4 end
        whl_last_j[t] = j
        for k = 1, 4 do bi.heat_j[(t - 1) * 4 + k] = dj end
    end
    bi.oat = simDR_whl_oat
    bi.airflow = B747DR_pseu_pri_air == 1 and B747DR_pseu_alt_air == 1 and B747DR_gact_position[1] > 0.5
    bi.fail = B747DR_whl_fail_btms > 0.5
    local bo = BT.update(whl_btms, bi, SIM_PERIOD)
    for i = 1, BT.BRAKES do
        put(B747DR_whl_brake_temp, i - 1, bo.temp[i])
        put(B747DR_whl_brake_temp_ind, i - 1, bo.level[i])
    end
    for i = 16, 17 do                    -- the nose wheels have no brakes
        put(B747DR_whl_brake_temp, i, simDR_whl_oat)
        put(B747DR_whl_brake_temp_ind, i, 0)
    end
    put(B747DR_gact_advisory, ADV_BRAKE_TEMP, flag(bo.brake_temp))
    put(B747DR_whl_status, STATUS_BRAKE_TEMP_SYS, flag(bo.sys))

    -- the tires: as serviced, more with the weight on them, flat with
    -- X-Plane's tire failure of their gear
    local ti = whl_tpis_in
    for i = 1, 18 do
        local xp = i <= 16 and XP_TRUCK[math.floor((i - 1) / 4) + 1] or 0
        local target = whl_serviced[i] + (simDR_whl_on_ground[xp] == 1 and LOADED_PSI or 0)
        local rate = PSI_RATE
        if simDR_whl_tire_fail[xp + 1] == 6 then target, rate = FLAT_PSI, FLAT_RATE end
        local p = B747DR_whl_tire_pressure[i - 1]
        if init then p = target else p = toward(p, target, rate * SIM_PERIOD) end
        put(B747DR_whl_tire_pressure, i - 1, p)
        ti.psi[i] = p
        ti.fail[i] = B747DR_whl_fail_tpis > 0.5
    end
    local lever = 0
    for i = 0, 3 do lever = math.max(lever, B747DR_brk_throttle[i]) end
    ti.takeoff = B747DR_pseu_pri_gnd == 1 and lever >= TAKEOFF_LEVER
    local to = TP.update(ti)
    put(B747DR_gact_advisory, ADV_TIRE_PRESSURE, flag(to.tire_pressure))
    put(B747DR_whl_status, STATUS_TIRE_PRESS_SYS, flag(B747DR_whl_fail_tpis > 0.5))
end
