-- The GPS model (B747.34.gps_model.lua) in the aircraft: reads the buses
-- (L: the AC standby bus, R: AC bus 2), X-Plane's GPS failures (rel_gps,
-- rel_gps2) and laminar/B747/gps/fail[2]; writes each GPS/MMR's validity
-- (laminar/B747/gps/valid: the FMC's GPS lines read it) and >GPS,
-- >GPS LEFT, >GPS RIGHT. B747.34.xt.nav.lua loads it.

dofile("B747.34.gps_model.lua")
local GP = B747_gps_model

simDR_gps_fail_1                = find_dataref("sim/operation/failures/rel_gps")
simDR_gps_fail_2                = find_dataref("sim/operation/failures/rel_gps2")
simDR_gps_time                  = find_dataref("sim/time/total_running_time_sec")
B747DR_gps_bus_stby             = find_dataref("laminar/B747/electrical/bus/stby_main")
B747DR_gps_bus_ac               = find_dataref("laminar/B747/electrical/bus/ac")
B747DR_gps_fail                 = find_dataref("laminar/B747/gps/fail")
B747DR_gps_valid                = find_dataref("laminar/B747/gps/valid")
B747DR_gps_CAS_advisory         = find_dataref("laminar/B747/CAS/advisory_status")

-- EICAS slots (B747.87.xt.warning.lua)
local ADV_GPS, ADV_GPS_L, ADV_GPS_R = 182, 183, 184
local INIT_S = 3                                -- the first reads are 0

local gps_state = GP.new()
local gps_inputs = GP.inputs()
local gps_t0 = nil
local gps_started = false

function B747_gps()
    local now = simDR_gps_time
    if gps_t0 == nil then gps_t0 = now end
    if now - gps_t0 < INIT_S then return end

    local inp = gps_inputs
    inp.power[1] = B747DR_gps_bus_stby > 0.5
    inp.power[2] = B747DR_gps_bus_ac[1] > 0.5
    inp.fail[1] = simDR_gps_fail_1 == 6 or B747DR_gps_fail[0] > 0.5
    inp.fail[2] = simDR_gps_fail_2 == 6 or B747DR_gps_fail[1] > 0.5
    if not gps_started then
        -- a flight started with the GPS powered (engines running, in the air)
        -- has it working
        gps_started = true
        GP.fix_now(gps_state, inp)
    end
    local out = GP.update(gps_state, inp, SIM_PERIOD)
    for i = 1, 2 do B747_nav_put(B747DR_gps_valid, i - 1, B747_nav_flag(out.valid[i])) end
    B747_nav_put(B747DR_gps_CAS_advisory, ADV_GPS, B747_nav_flag(out.msg_both))
    B747_nav_put(B747DR_gps_CAS_advisory, ADV_GPS_L, B747_nav_flag(out.msg_l))
    B747_nav_put(B747DR_gps_CAS_advisory, ADV_GPS_R, B747_nav_flag(out.msg_r))
end

function B747_gps_flight_start()
    gps_state = GP.new()
    gps_t0 = nil
    gps_started = false
end
