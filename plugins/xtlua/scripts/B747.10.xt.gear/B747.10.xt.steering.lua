-- The steering model (B747.10.steering_model.lua) in the aircraft (4-2 step
-- 4): reads the tillers (X-Plane's nosewheel tiller axis, or
-- laminar/B747/gear/steering/tiller with no such axis), the rudder pedals
-- with the rudder trim (laminar/B747/flt_ctrls/rudder_input), hydraulic
-- system 1 with the gear lever DN (the gear down pressure), the PSEU (nose
-- gear compressed, air/ground), the groundspeed, the option of the pedals as
-- the tiller (laminar/B747/gear/steering/pedal_tiller: not the aircraft) and
-- the failures; steers X-Plane's nose wheels and body gear
-- (override_wheel_steer always on, tire_steer_command_deg), writes the
-- trucks' locks (laminar/B747/gear/steering/body_unlocked: CONFIG GEAR CTR,
-- the gear lever's lock), >BODY GEAR STRG, BODY GR STRG SYS and PEDAL
-- STEERING. B747.10.xt.gear.lua loads it after the brakes' glue and uses its
-- bindings (the PSEU, system 1's pressure, the gear lever).
dofile("B747.10.steering_model.lua")
local S = B747_steering_model

simDR_strg_override             = find_dataref("sim/operation/override/override_wheel_steer")
simDR_strg_command              = find_dataref("sim/flightmodel2/gear/tire_steer_command_deg")
simDR_strg_axis_avail           = find_dataref("sim/joystick/joy_mapped_axis_avail")
simDR_strg_axis_value           = find_dataref("sim/joystick/joy_mapped_axis_value")
simDR_strg_hw_assign            = find_dataref("sim/joystick/joystick_axis_assignments")
simDR_strg_hw_value             = find_dataref("sim/joystick/joystick_axis_values")
simDR_strg_hw_min               = find_dataref("sim/joystick/joystick_axis_minimum")
simDR_strg_hw_max               = find_dataref("sim/joystick/joystick_axis_maximum")
simDR_strg_hw_reverse           = find_dataref("sim/joystick/joystick_axis_reverse")
simDR_strg_actual               = find_dataref("sim/flightmodel2/gear/tire_steer_actual_deg")
simDR_strg_gs                   = find_dataref("sim/flightmodel/position/groundspeed")
B747DR_strg_rudder_input        = find_dataref("laminar/B747/flt_ctrls/rudder_input")
B747DR_strg_tiller              = find_dataref("laminar/B747/gear/steering/tiller")
B747DR_strg_pedal_tiller        = find_dataref("laminar/B747/gear/steering/pedal_tiller")
B747DR_strg_body_unlocked       = find_dataref("laminar/B747/gear/steering/body_unlocked")
B747DR_strg_fail_pedal          = find_dataref("laminar/B747/gear/fail/pedal_steering")
B747DR_strg_fail_body           = find_dataref("laminar/B747/gear/fail/body_steering")
B747DR_strg_status              = find_dataref("laminar/B747/CAS/status_status")

-- X-Plane's joystick axis assignment "Nosewheel tiller", which
-- joy_mapped_axis_avail/value are indexed by (developer.x-plane.com,
-- "joystick datarefs")
local AXIS_TILLER = 37
-- (2026-11-05) the user's tiller axis (another PC, X-Plane 12.4.4) did not
-- steer, the pedals did: also the hardware axis assigned the nosewheel
-- tiller (joystick_axis_assignments), its raw value over the range seen
-- (joystick_axis_minimum/maximum), reversed as set, with its own null zone
-- (X-Plane's processing not applied), when joy_mapped_axis gives nothing.
-- The assignments looked through every RAW_SCAN_S (500 of them), not each
-- frame
local RAW_AXES, RAW_SCAN_S, RAW_NULL = 500, 2, 0.05
-- joy_mapped_axis_avail/value: 81 functions (DataRefs.txt); the report's
-- assignment lines at most SCAN_MAX a load
local MAPPED_AXES, SCAN_MAX = 81, 20
-- EICAS slots (B747.87.xt.warning.lua)
local ADV_BODY_GEAR_STRG = 43
local STATUS_BODY_GR_STRG_SYS, STATUS_PEDAL_STEERING = 95, 96
-- X-Plane's gear: 0 nose, 1 right body, 2 left body, 3 right wing, 4 left wing
local XP_NOSE, XP_RB, XP_LB, XP_RW, XP_LW = 0, 1, 2, 3, 4

local strg_state = S.new()
local strg_inputs = S.inputs()
local raw_axis, raw_scan_t, raw_logged, scan_n = nil, 0, nil, 0
-- the hardware axes assigned, from the scan (the report's)
local raw_list = {}

local function flag(v)
    if v then return 1 end
    return 0
end

local function put(dref, i, v)
    if dref[i] ~= v then dref[i] = v end
end

-- the hardware axis assigned the nosewheel tiller, nil without one. The
-- assignments ("axis=assignment") and the functions X-Plane says hardware
-- provides (joy_mapped_axis_avail 1) go to Output/B747_steering.txt when
-- they change, for the users' reports (XTLua's print reaches no log)
local function find_raw_axis()
    local found, parts, list, avail = nil, {}, {}, {}
    for i = 0, RAW_AXES - 1 do
        local a = simDR_strg_hw_assign[i]
        if a ~= 0 then
            parts[#parts + 1] = i .. "=" .. a
            list[#list + 1] = i
            if a == AXIS_TILLER and not found then found = i end
        end
    end
    for i = 0, MAPPED_AXES - 1 do
        if simDR_strg_axis_avail[i] == 1 then avail[#avail + 1] = i end
    end
    raw_list = list
    local text = table.concat(parts, " ") .. "; the tiller (37) on axis " .. tostring(found)
        .. "; X-Plane's mapped functions (joy_mapped_axis_avail 1): " .. table.concat(avail, " ")
    if text ~= raw_logged and scan_n < SCAN_MAX then
        raw_logged = text
        scan_n = scan_n + 1
        local f = io and io.open("Output/B747_steering.txt", "a")
        if f then
            f:write((os and os.date and os.date("%Y-%m-%d %H:%M:%S ")) or "",
                "joystick axes (axis=assignment): ", text, "\n")
            f:close()
        end
    end
    return found
end

-- the tiller from the raw axis: -1 .. 1, + right. (2026-11-05) The range
-- seen only when it is a ratio's (X-Plane 12 keeps 9.9e9 and -9.9e9 before
-- calibrating, and may keep the device's units after: this PC's joystick
-- settings); reversed when the flag is above 0 (FlyWithLua's sample: it
-- may be the axis's number)
local function raw_tiller(i)
    local v = simDR_strg_hw_value[i]
    local lo, hi = simDR_strg_hw_min[i], simDR_strg_hw_max[i]
    if hi - lo > 0.1 and lo >= -0.5 and hi <= 1.5 then v = (v - lo) / (hi - lo) end
    v = math.min(1, math.max(0, v))
    if simDR_strg_hw_reverse[i] > 0 then v = 1 - v end
    local t = v * 2 - 1
    if math.abs(t) <= RAW_NULL then return 0 end
    return (t - (t > 0 and RAW_NULL or -RAW_NULL)) / (1 - RAW_NULL)
end

-- (2026-11-05) the tiller's and the pedals' values to Output/B747_steering.txt
-- when they move, for the user's report: with a rudder axis the tiller axis
-- did nothing, without one it steered (X-Plane giving it as the rudder?).
-- Every DIAG_S, a line when something moved DIAG_STEP or more: the tiller
-- used, the pedals, the hardware axes assigned ("raw": joystick_axis_values)
-- and all X-Plane's processed functions ("mapped": joy_mapped_axis_value,
-- the tiller perhaps under another one), the ones moved since their last
-- line (the first line: every raw one, the mapped ones off 0); DIAG_MAX
-- lines a load. The nose wheels: commanded, X-Plane's actual, the override
-- (another plugin may take it)
local DIAG_S, DIAG_STEP, DIAG_MAX = 0.5, 0.1, 60
local diag_t, diag_n, diag_last, diag_raw, diag_map = 0, 0, {}, {}, {}

local function diag_moved(out, name, dref, i, last, all)
    local v = dref[i]
    if all or math.abs(v - (last[i] or 0)) >= DIAG_STEP then
        out[#out + 1] = string.format("%s %d %.3f", name, i, v)
        last[i] = v
    end
end

local function diag(raw_i, t, pedal, nose)
    diag_t = diag_t - SIM_PERIOD
    if diag_n >= DIAG_MAX or diag_t > 0 then return end
    diag_t = DIAG_S
    local first, ch = diag_n == 0, {}
    for _, i in ipairs(raw_list) do diag_moved(ch, "raw", simDR_strg_hw_value, i, diag_raw, first) end
    for i = 0, MAPPED_AXES - 1 do
        if not first or simDR_strg_axis_value[i] ~= 0 then
            diag_moved(ch, "mapped", simDR_strg_axis_value, i, diag_map, first)
        end
    end
    if not first and #ch == 0 and math.abs(t - diag_last[1]) < DIAG_STEP
        and math.abs(pedal - diag_last[2]) < DIAG_STEP then return end
    diag_last[1], diag_last[2] = t, pedal
    diag_n = diag_n + 1
    local raw = "none"
    if raw_i then
        raw = string.format("%d value %.3f min %.3f max %.3f reverse %s", raw_i, simDR_strg_hw_value[raw_i],
            simDR_strg_hw_min[raw_i], simDR_strg_hw_max[raw_i], tostring(simDR_strg_hw_reverse[raw_i]))
    end
    local line = string.format("%s tiller: joy_mapped_axis[37] avail %s value %.3f; raw axis %s; tiller used %.3f; pedal %.3f; nose %.1f deg (X-Plane's %.1f, override %s); %s %s\n",
        (os and os.date and os.date("%H:%M:%S")) or "", tostring(simDR_strg_axis_avail[AXIS_TILLER]),
        simDR_strg_axis_value[AXIS_TILLER], raw, t, pedal, nose, simDR_strg_actual[XP_NOSE],
        tostring(simDR_strg_override), first and "axes:" or "moved:", #ch > 0 and table.concat(ch, ", ") or "-")
    local f = io and io.open("Output/B747_steering.txt", "a")
    if f then
        f:write(line)
        f:close()
    end
end

function B747_steering_aircraft_load()
    -- the pedals as the tiller for users without a tiller axis, on unless set
    -- off (not the aircraft: docs/overhaul/notes/ATA-32.md §13)
    B747DR_strg_pedal_tiller = 1
end

function B747_steering_flight_start()
    strg_state = S.new()
end

function B747_steering()
    local inp = strg_inputs
    raw_scan_t = raw_scan_t - SIM_PERIOD
    if raw_scan_t <= 0 then
        raw_scan_t = RAW_SCAN_S
        raw_axis = find_raw_axis()
    end
    local mapped = simDR_strg_axis_avail[AXIS_TILLER] == 1
    local t = mapped and simDR_strg_axis_value[AXIS_TILLER] or 0
    if raw_axis and math.abs(t) <= S.TILLER_DEADBAND then t = raw_tiller(raw_axis) end
    inp.tiller_avail = mapped or raw_axis ~= nil
    if inp.tiller_avail then inp.tiller = t else inp.tiller = B747DR_strg_tiller end
    inp.pedal = B747DR_strg_rudder_input
    inp.pedal_tiller = B747DR_strg_pedal_tiller > 0.5
    inp.down_psi = B747DR_gear_handle < 0.5 and B747DR_pseu_hyd_pressure_1 or 0
    inp.ng_compressed = B747DR_pseu_ng_compressed == 1
    inp.gnd_both = B747DR_pseu_pri_gnd == 1 and B747DR_pseu_alt_gnd == 1
    inp.air = B747DR_pseu_pri_air == 1 or B747DR_pseu_alt_air == 1
    -- the wing gear wheels' speed taken as the groundspeed (estimate)
    inp.iru_kt = simDR_strg_gs * 1.94384
    inp.wheel_kt = inp.iru_kt
    inp.fail_pedal = B747DR_strg_fail_pedal > 0.5
    inp.fail_body = B747DR_strg_fail_body > 0.5
    local out = S.update(strg_state, inp, SIM_PERIOD)

    -- the report's diagnostics never stop the gear module (one Lua error
    -- stops every module of this plugin)
    pcall(diag, raw_axis, inp.tiller, inp.pedal, out.nose)
    if simDR_strg_override ~= 1 then simDR_strg_override = 1 end
    put(simDR_strg_command, XP_NOSE, out.nose)
    put(simDR_strg_command, XP_LB, out.body[1])
    put(simDR_strg_command, XP_RB, out.body[2])
    put(simDR_strg_command, XP_RW, 0)
    put(simDR_strg_command, XP_LW, 0)
    local unlocked = flag(out.unlocked)
    if B747DR_strg_body_unlocked ~= unlocked then B747DR_strg_body_unlocked = unlocked end
    put(B747DR_gact_advisory, ADV_BODY_GEAR_STRG, flag(out.body_gear_strg))
    put(B747DR_strg_status, STATUS_BODY_GR_STRG_SYS, flag(out.body_gear_strg))
    put(B747DR_strg_status, STATUS_PEDAL_STEERING, flag(out.pedal_steering))
end
