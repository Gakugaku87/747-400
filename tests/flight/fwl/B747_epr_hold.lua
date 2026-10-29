-- B747 EPR hold for FlyWithLua NG+ (X-Plane 12): the thrust levers at the
-- FCOM's Max Climb EPR, for measuring the custom acf's climb (PROGRESS.md 5f,
-- docs/overhaul/notes/AERO.md). Part of the 747-400 overhaul flight-test kit
-- (docs/overhaul/TESTING.md). The master copy lives in the aircraft
-- repository at tests/flight/fwl/; copy it to
-- X-Plane 12/Resources/plugins/FlyWithLua/Scripts/ to use it.
--
-- The aircraft's A/T sets the climb thrust from a fixed climb rate (ATHR-04,
-- to be rebuilt in 6-4), not the rating. With the A/T off, this moves the
-- thrust levers every frame so that the four engines' mean EPR as the EICAS
-- shows it (laminar/B747/engines/display_EPR: the EEC and the A/T hold that,
-- not X-Plane's ENGN_EPR; v3) is the PW4056 Max Climb EPR of FCOM
-- PI.10.36 (p.262: 3 packs on, engine and wing anti-ice off) at the pressure
-- altitude and TAT (sim/weather/aircraft/temperature_leadingedge_deg_c),
-- interpolated in both. The table's speeds (340 KIAS, .84) are not looked
-- at (estimate: the climb at 290 KIAS takes the same EPR). It does nothing
-- until started, so it does not touch other flights.
--
-- Commands (also reachable through the X-Plane Web API):
--   FlyWithLua/B747_epr_hold/max_climb   hold the Max Climb EPR (A/T off first)
--   FlyWithLua/B747_epr_hold/stop        stop moving the levers
-- B747/test/epr_hold_target (float): the EPR held, 0 when stopped.

local VERSION = "3"

if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then
    logMsg("B747 EPR hold: not the 747-400, inactive")
    return
end

-- FCOM PI.10.36: pressure altitude (1000 ft) columns, TAT (deg C) rows from
-- the hottest; nil where the table is empty
local ALT = {0, 5, 10, 15, 20, 25, 30, 35, 40, 45}
local TAT = {60, 50, 40, 30, 20, 10, 0, -10, -20}
local EPR = {
    {1.19, 1.19, 1.18},
    {1.23, 1.23, 1.22, 1.21},
    {1.25, 1.29, 1.28, 1.27, 1.25},
    {1.25, 1.30, 1.35, 1.35, 1.33, 1.32},
    {1.25, 1.30, 1.35, 1.39, 1.42, 1.42, 1.42, 1.39},
    {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.52, 1.48, 1.44, 1.41},
    {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.58, 1.54, 1.51},
    {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
    {1.25, 1.30, 1.35, 1.39, 1.43, 1.48, 1.57, 1.64, 1.61, 1.58},
}
-- lever per EPR error per second (the EEC follows the lever: an integral
-- outer loop, slow beside the engines)
local GAIN = 1.0

dataref("B747EH_palt", "sim/flightmodel2/position/pressure_altitude", "readonly")
dataref("B747EH_tat", "sim/weather/aircraft/temperature_leadingedge_deg_c", "readonly")
dataref("B747EH_time", "sim/time/total_running_time_sec", "readonly")
dataref("B747EH_epr0", "laminar/B747/engines/display_EPR", "readonly", 0)
dataref("B747EH_epr1", "laminar/B747/engines/display_EPR", "readonly", 1)
dataref("B747EH_epr2", "laminar/B747/engines/display_EPR", "readonly", 2)
dataref("B747EH_epr3", "laminar/B747/engines/display_EPR", "readonly", 3)
-- the levers read and written with get() and set() while holding: a
-- "writable" dataref variable would be written back every frame, fighting
-- the A/T while stopped (docs/overhaul/TESTING.md)
local LEVER = "sim/cockpit2/engine/actuators/throttle_ratio_all"
define_shared_DataRef("B747/test/epr_hold_target", "Float")
dataref("B747EH_target", "B747/test/epr_hold_target", "writable")

-- a row's EPR at pressure altitude a (1000 ft), nil outside its values
local function in_row(row, a)
    a = math.max(ALT[1], math.min(ALT[#ALT], a))
    for i = 1, #ALT - 1 do
        if a <= ALT[i + 1] then
            local e0, e1 = row[i], row[i + 1]
            if not e0 then return nil end
            if not e1 then return e0 end
            return e0 + (e1 - e0) * (a - ALT[i]) / (ALT[i + 1] - ALT[i])
        end
    end
    return row[#ALT]
end
-- the Max Climb EPR at a (1000 ft) and t (TAT): rows interpolated, an empty
-- cell taken from the next colder row
local function max_climb(a, t)
    t = math.max(TAT[#TAT], math.min(TAT[1], t))
    for j = 1, #TAT - 1 do
        if t >= TAT[j + 1] then
            local hot, cold = in_row(EPR[j], a), in_row(EPR[j + 1], a)
            if not cold then return hot end
            if not hot then return cold end
            return cold + (hot - cold) * (t - TAT[j + 1]) / (TAT[j] - TAT[j + 1])
        end
    end
    return in_row(EPR[#TAT], a)
end

local active, last = false, nil
function B747EH_start()
    active, last = true, nil
    logMsg("B747 EPR hold: holding the Max Climb EPR")
end
function B747EH_stop()
    active = false
    B747EH_target = 0
    logMsg("B747 EPR hold: stopped")
end
function B747EH_frame()
    if not active then return end
    local now = B747EH_time
    local dt = last and math.max(0, math.min(0.1, now - last)) or 0
    last = now
    local tgt = max_climb(B747EH_palt / 1000, B747EH_tat)
    if not tgt then return end
    local epr = (B747EH_epr0 + B747EH_epr1 + B747EH_epr2 + B747EH_epr3) / 4
    set(LEVER, math.max(0, math.min(1, get(LEVER) + GAIN * (tgt - epr) * dt)))
    B747EH_target = tgt
end

create_command("FlyWithLua/B747_epr_hold/max_climb", "B747 EPR hold: the FCOM's Max Climb EPR", "B747EH_start()", "", "")
create_command("FlyWithLua/B747_epr_hold/stop", "B747 EPR hold: stop", "B747EH_stop()", "", "")
do_every_frame("B747EH_frame()")
B747EH_target = 0
logMsg("B747 EPR hold v" .. VERSION .. ": ready")
