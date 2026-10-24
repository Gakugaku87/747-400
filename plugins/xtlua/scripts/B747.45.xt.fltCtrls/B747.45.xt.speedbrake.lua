-- The speedbrake model (B747.45.speedbrake_model.lua) in the aircraft (4-1
-- step 3): reads the speedbrake lever (the 3D and the commands write it;
-- the init script's handler snaps its detents), the thrust levers
-- (laminar/B747/engine/throttle over 50 degrees, as the EEC: the 3D's
-- levers; X-Plane's throttle ratio is the input they follow, and the EEC
-- writes their average there while the A/T is on) and reverse (prop mode
-- 3), hydraulic systems 1 and 4, the gear's primary and alternate ground
-- sensing, DC bus 1, the radio altitude, the FCUs' TE
-- flaps and the failure laminar/B747/flt_ctrls/fail/auto_speedbrake; moves
-- the lever while the auto speedbrake actuator drives it, writes X-Plane's
-- speedbrake ratio from the lever (never "armed": X-Plane's own auto
-- speedbrake stays out; the other spoilers come from the lever through the
-- hydraulics module's controlObject rows), SPEEDBRAKE AUTO and its STATUS,
-- >SPEEDBRAKES EXT and SPEEDBRAKE ARMED. X-Plane's own changes to its ratio
-- (a speedbrake axis) move the lever. B747.45.xt.fltCtrls.lua loads it.
dofile("B747.45.speedbrake_model.lua")
local B = B747_speedbrake_model

B747DR_sb_thrust_lever          = find_dataref("laminar/B747/engine/throttle")
simDR_sb_prop_mode              = find_dataref("sim/cockpit2/engine/actuators/prop_mode")
simDR_sb_radio_alt              = find_dataref("sim/cockpit2/gauges/indicators/radio_altimeter_height_ft_pilot")
B747DR_sb_hyd_1                 = find_dataref("laminar/B747/hydraulics/pressure_1")
B747DR_sb_hyd_4                 = find_dataref("laminar/B747/hydraulics/pressure_4")
B747DR_sb_alt_gnd               = find_dataref("laminar/B747/gear/air_ground/alt_gnd")
B747DR_sb_fail                  = find_dataref("laminar/B747/flt_ctrls/fail/auto_speedbrake")
B747DR_sb_freighter             = find_dataref("laminar/B747/freighter")       -- (CONFIG SPOILERS in flight, fltCtrls)

-- EICAS slots (B747.87.xt.warning.lua)
local CAUT_SPEEDBRAKES_EXT = 59
local ADV_SPEEDBRAKE_AUTO = 272
local MEMO_SPEEDBRAKE_ARMED = 45
local STATUS_SPEEDBRAKE_AUTO = 94
local LANDING_FLAPS_DEG = 21    -- flaps 25 are 22 degrees, flaps 20 are 20 (the FCU)
local RATIO_SAME = 0.01         -- X-Plane's ratio this close to what was written is ours

local sb_state = B.new()
local sb_inputs = B.inputs()
local ratio_w1, ratio_w2 = nil, nil     -- the ratio written last frame and the one before
local still_t = 0                       -- time since the actuator last moved the lever

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

-- X-Plane's speedbrake ratio from the lever and back: 0 up to the arm
-- detent, then to 1 at UP (the flight detent in the air: the in-flight
-- stop), as before
local function top() return B.UP - B747_speedbrake_stop * (B.UP - B.DETENT) end
local function ratio_of(lever)
    if lever <= B.ABOVE_ARM then return 0 end
    return B747_rescale(B.ABOVE_ARM, 0.0, top(), 1.0, lever)
end
local function lever_of(ratio)
    if ratio <= RATIO_SAME then return B.DN end
    return B.ABOVE_ARM + math.min(ratio, 1) * (top() - B.ABOVE_ARM)
end

function B747_speedbrake_flight_start()
    sb_state = B.new()
    ratio_w1, ratio_w2 = nil, nil
end

function B747_speedbrake()
    local inp = sb_inputs
    -- X-Plane's ratio changed by something else (a speedbrake axis): the
    -- lever follows (the init script's handler leaves the write alone)
    local xr = simDR_speedbrake_ratio_control
    if ratio_w1 and math.abs(xr - ratio_w1) > RATIO_SAME and math.abs(xr - (ratio_w2 or ratio_w1)) > RATIO_SAME then
        if B747DR_speedbrake_auto_ext ~= 1 then B747DR_speedbrake_auto_ext = 1 end
        still_t = 0
        B747DR_speedbrake_lever = lever_of(xr)
    end

    inp.lever = B747DR_speedbrake_lever
    for n = 1, 4 do
        inp.tla[n] = B747DR_sb_thrust_lever[n - 1] * B.TLA_STOP
        inp.reverse[n] = simDR_sb_prop_mode[n - 1] == 3
    end
    inp.hyd_psi[1], inp.hyd_psi[2] = B747DR_sb_hyd_1, B747DR_sb_hyd_4
    inp.pri_gnd = B747DR_fcu_pri_gnd == 1
    inp.alt_gnd = B747DR_sb_alt_gnd == 1
    inp.dc1 = B747DR_fcu_bus_dc[0] > 0.5
    inp.ra = simDR_sb_radio_alt
    local te = B747DR_fcu_te_deg[0]
    for i = 1, 3 do te = math.min(te, B747DR_fcu_te_deg[i]) end
    inp.landing_flaps = te >= LANDING_FLAPS_DEG
    inp.actuator_stuck = B747DR_sb_fail > 0.5

    local out = B.update(sb_state, inp, SIM_PERIOD)

    -- the actuator moving the lever: the init script's handler (which
    -- snaps the detents of the pilot's moves) leaves it alone until a second
    -- after it stops
    if out.driving ~= 0 then
        still_t = 0
        if B747DR_speedbrake_auto_ext ~= 1 then B747DR_speedbrake_auto_ext = 1 end
        if B747DR_speedbrake_lever ~= out.lever then B747DR_speedbrake_lever = out.lever end
    else
        still_t = still_t + SIM_PERIOD
        if still_t > 1 and B747DR_speedbrake_auto_ext ~= 0 then B747DR_speedbrake_auto_ext = 0 end
    end

    -- (a float: 0 and 1 are exact, so a residue near them goes too)
    local r = ratio_of(out.lever)
    if xr ~= r and (math.abs(xr - r) > 1e-4 or r == 0 or r == 1) then simDR_speedbrake_ratio_control = r end
    ratio_w2, ratio_w1 = ratio_w1, r

    -- (FCOM p.957-958; ATA27 p.184, p.205, p.740)
    put(B747DR_CAS_advisory_status, ADV_SPEEDBRAKE_AUTO, flag(out.speedbrake_auto))
    put(B747DR_fcu_status, STATUS_SPEEDBRAKE_AUTO, flag(out.speedbrake_auto))
    put(B747DR_CAS_caution_status, CAUT_SPEEDBRAKES_EXT, flag(out.speedbrakes_ext))
    put(B747DR_CAS_memo_status, MEMO_SPEEDBRAKE_ARMED, flag(out.armed))
end
