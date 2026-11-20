-- 747-400 yaw dampers without X-Plane (6-3 step 6a): the upper and lower
-- yaw damper modules (YDM), their operational modes (the power-up test,
-- the ground operation, the fade-in and fade-out, the flight mode, the
-- fault INOP mode and its autorecovery), engagement and INOP, and the
-- authority by the valid IRUs and ADCs; their command (step 6b): the
-- dutch roll damping on the sideslip rate, and the turn coordination on
-- the roll angle's rate (GAP N19-AFDS-03). Logic and sources:
-- docs/overhaul/notes/ATA-22.md §2.4, §4.7, §39, §40 and §64 (ATA22 22-21
-- p.52-90, the modes' figure p.85, the command's p.87; ATA27 p.38, p.42,
-- p.656; FCOM p.931, p.949-950, p.958; NASA_SIM p.279-280, p.591-598 for
-- the 747-100's turn coordinator).
--
--   local Y = B747_yd_model               -- in XTLua, after dofile
--   local Y = dofile(".../B747.19.yd_model.lua")   -- in the tests
--   local s = Y.new()
--   local inp = Y.inputs()                -- fill it every frame
--   local out = Y.update(s, inp, dt)      -- the same table every frame

local M = setmetatable({}, {})
B747_yd_model = M

M.UPR, M.LWR = 1, 2
-- the modes (ATA22 p.83-85): off (the switch OFF or no power), the
-- power-up test on the ground, the ground operation (engaged, no command),
-- the fade-in and fade-out, the flight mode, the fault INOP mode
M.OFF, M.TEST, M.GROUND, M.FADE_IN, M.FLIGHT, M.FADE_OUT, M.FAULT = 0, 1, 2, 3, 4, 5, 6
M.TEST_S = 5            -- the power-up test, INOP on: "5 seconds maximum" (p.83; the length an estimate)
M.FADE_S = 5            -- the fade-in and fade-out (p.83, p.85)
M.TRANSIENT_S = 5       -- a fault shorter than this recovers by itself (p.84)
-- the authority (ATA22 p.86-87; ATA27 p.656): the rudder degrees a YDM
-- commands at most (modal suppression's 1 included) by the valid IRUs and
-- the valid ADCs of its two (L and R: ATA27 p.42). One IRU with both ADCs
-- is "variable" (no value: an estimate between); no IRU, INOP
M.AUTH_FULL, M.AUTH_VAR, M.AUTH_LOW = 4.0, 2.5, 1.0
-- the command (step 6b): "positioning the rudder in response to computed
-- airplane sideslip rate and impact pressure" (ATA27 p.38). The sideslip
-- rate from the IRUs' lateral acceleration, yaw and roll rates and bank
-- and the ADCs' AOA and true airspeed; its gain, rudder degrees per degree
-- a second, inversely with the impact pressure from K_REF at K_REF_KT
-- CAS, within K_MIN to K_MAX. The gain is not in the sources: fitted to
-- the custom acf's dutch roll (tests/tools/yd_design.lua on s125 and s126,
-- the yaw dampers OFF: damping 0.05 at 150 kt with the flaps at 30, 0.21
-- at 250 kt clean) for a damping ratio of about 0.4 (an estimate)
M.K_REF, M.K_REF_KT = 2.0, 150
M.K_MIN, M.K_MAX = 0.2, 3.0
M.K_NO_ADC_KT = 250     -- without an ADC: the gain at this CAS, the ground speed for the true airspeed (an estimate)
-- the turn coordination (GAP N19-AFDS-03): the YDM's turn coordination
-- block takes the roll angle (ATA22 p.87), no gain given. The 747-100's
-- turn coordinator (NASA_SIM p.279, p.593, p.598): the rudder into the
-- roll in proportion to the roll angle's rate (derived from the INS roll
-- angle), 0.69 degree per degree a second, with the flaps down only. The
-- -400's YDM has no flap input (ATA22 p.66, p.69): the gain here falls
-- with the impact pressure instead (tc_gain), TC_REF at K_REF_KT and
-- below (the -100's value: an estimate for the -400)
M.TC_REF = 0.69
M.TAN_MAX = 5           -- the pitch's tangent at most (79 degrees), for the roll angle's rate
M.G = 9.80665

local ENGAGED = {[M.GROUND] = true, [M.FADE_IN] = true, [M.FLIGHT] = true, [M.FADE_OUT] = true}

-- What the panel, the buses and the sensors give the model each frame.
function M.inputs()
    return {
        switch = {false, false},    -- YAW DAMPER UPPER, LOWER ON (the switch powers the module: ATA22 p.69)
        power = {false, false},     -- each module's power (ATA22 p.60-62: the upper's FCE power supplies on
                                    -- the AC standby bus and the battery bus, the lower's on AC 1 and DC 1 or 2)
        air = false,                -- in the air (the air/ground system)
        iru = 0,                    -- IRUs with inertial data (NAV, or ATT)
        iru_nav = 0,                -- IRUs in NAV (one more than before: autorecovery, p.84)
        adc = 0,                    -- valid ADCs of the two
        fault = {false, false},     -- a module's own fault (laminar/B747/flt_ctrls/fail/yaw_damper)
        -- the command's inputs (step 6b; X-Plane's signs, right plus)
        cas = 0,                    -- kt (the ADCs)
        tas = 0,                    -- m/s (the ADCs)
        gs = 0,                     -- m/s (the IRUs)
        alpha = 0,                  -- degrees (the ADCs)
        pitch = 0, roll = 0,        -- degrees (the IRUs)
        p = 0, q = 0, r = 0,        -- roll, pitch and yaw rates, degrees per second (the IRUs)
        ny = 0,                     -- lateral load factor, g (the IRUs)
    }
end

function M.new()
    local ydm = function() return {mode = M.OFF, t = 0, fade = 0, fault_t = 0} end
    return {ydm = {ydm(), ydm()}, iru_nav = 0, out = nil}
end

-- the authority (degrees) for the valid IRUs and ADCs (p.87)
function M.authority(iru, adc)
    if iru >= 2 then return M.AUTH_FULL end
    if iru == 1 then return adc >= 2 and M.AUTH_VAR or M.AUTH_LOW end
    return 0
end

-- the impact pressure for a CAS (kt), over the standard sea level pressure
local function qc(kt)
    local x = kt / 661.47
    return (1 + 0.2 * x * x) ^ 3.5 - 1
end
-- the gain (rudder degrees per degree a second of sideslip rate) at a CAS
function M.gain(kt)
    if kt <= 1 then return M.K_MAX end
    return math.max(M.K_MIN, math.min(M.K_MAX, M.K_REF * qc(M.K_REF_KT) / qc(kt)))
end
-- the sideslip rate (degrees a second; X-Plane's sign: the nose swinging
-- right of the flown path plus) from the kinematics: r cos(alpha) -
-- p sin(alpha) - (ny g + g cos(pitch) sin(bank)) / V. In a steady
-- coordinated turn the bank's term balances the yaw rate: the turn
-- coordination by bank and true airspeed (ATA27 p.38) is in it, so the
-- damping does not oppose a steady turn. It gives no steady rudder: the
-- custom acf's steady turns keep the sideslip that its yaw damping needs,
-- about 0.065 degree per degree of bank at 150 kt with the flaps at 30
-- and 0.016 at 250 kt clean (s125, s126 fitted; 2026-10-31's "0.01 degree
-- of rudder per degree" left out the yaw moments: docs/overhaul/notes/
-- ATA-22.md §64)
function M.sideslip_rate(inp, v)
    if v < 1 then return 0 end
    local a, th, ph = math.rad(inp.alpha), math.rad(inp.pitch), math.rad(inp.roll)
    local rad = math.rad(inp.r) * math.cos(a) - math.rad(inp.p) * math.sin(a)
        - (inp.ny * M.G + M.G * math.cos(th) * math.sin(ph)) / v
    return math.deg(rad)
end
-- the turn coordination's gain (rudder degrees per degree a second of the
-- roll angle's rate) at a CAS: TC_REF at K_REF_KT and below, above it
-- inversely with the square of the impact pressure (an estimate: the
-- rudder's power goes with the impact pressure, the yaw rate a roll needs
-- with 1/V and the AOA; fitted to the custom acf's yaw dampers OFF, s125
-- and s126, it wants about 0.6 at 150 kt with the flaps at 30 and 0.07 at
-- 250 kt clean, where the -100's flaps-up switch had none)
function M.tc_gain(kt)
    if kt <= M.K_REF_KT then return M.TC_REF end
    local x = qc(M.K_REF_KT) / qc(kt)
    return M.TC_REF * x * x
end
-- the roll angle's rate (degrees a second, right plus): p + (q sin(bank)
-- + r cos(bank)) tan(pitch), the rate the -100's circuit derived from the
-- roll angle (NASA_SIM p.593), here from the IRUs' rates and attitude
-- instead of a difference over time (XTLua's SIM_PERIOD is a constant
-- 0.02, not the frame's time). Nought in a steady turn, where the body
-- roll rate is not (-turn rate x sin(pitch))
function M.roll_angle_rate(inp)
    local th, ph = math.rad(inp.pitch), math.rad(inp.roll)
    local t = math.tan(th)
    if t > M.TAN_MAX then t = M.TAN_MAX elseif t < -M.TAN_MAX then t = -M.TAN_MAX end
    return inp.p + (inp.q * math.sin(ph) + inp.r * math.cos(ph)) * t
end

-- One module for one frame (the figure p.85). Without its switch or power
-- it is off; powered, it tests itself on the ground (INOP) and goes to the
-- ground operation, or fades in in the air. A fault (its own, or no IRU:
-- FCOM p.958 "IRUs off or in align") disengages it into the fault INOP
-- mode; it recovers when an IRU goes into NAV or when the fault lasted
-- less than TRANSIENT_S (p.84), else with its switch cycled. In the air it
-- fades in, on the ground it fades out (p.83).
local function step(y, inp, i, dt, nav_up)
    if not (inp.switch[i] and inp.power[i]) then
        y.mode, y.t, y.fade, y.fault_t = M.OFF, 0, 0, 0
        return
    end
    if y.mode == M.OFF then
        y.mode, y.t = inp.air and M.FADE_IN or M.TEST, 0
    end
    y.t = y.t + dt
    local fault = inp.fault[i] or inp.iru == 0
    if y.mode == M.FAULT then
        if fault then
            y.fault_t = y.fault_t + dt
        elseif nav_up or y.fault_t < M.TRANSIENT_S then
            y.mode, y.t, y.fault_t = inp.air and M.FADE_IN or M.GROUND, 0, 0
        end
        return
    end
    if fault then
        -- disengaged: the actuator to neutral by its springs (p.90)
        y.mode, y.t, y.fade, y.fault_t = M.FAULT, 0, 0, dt
        return
    end
    if y.mode == M.TEST then
        if y.t >= M.TEST_S then y.mode, y.t = M.GROUND, 0 end
    elseif y.mode == M.GROUND then
        if inp.air then y.mode, y.t = M.FADE_IN, 0 end
    elseif y.mode == M.FADE_IN or y.mode == M.FLIGHT then
        if not inp.air then
            y.mode, y.t = M.FADE_OUT, 0
        elseif y.mode == M.FADE_IN then
            y.fade = math.min(1, y.fade + dt / M.FADE_S)
            if y.fade >= 1 then y.mode, y.t = M.FLIGHT, 0 end
        end
    elseif y.mode == M.FADE_OUT then
        if inp.air then
            y.mode, y.t = M.FADE_IN, 0
        else
            y.fade = math.max(0, y.fade - dt / M.FADE_S)
            if y.fade <= 0 then y.mode, y.t = M.GROUND, 0 end
        end
    end
end

-- One frame. dt in seconds.
function M.update(s, inp, dt)
    local out = s.out or {mode = {}, engaged = {}, inop = {}, fade = {}, authority = {}, cmd = {}}
    local nav_up = inp.iru_nav > s.iru_nav
    s.iru_nav = inp.iru_nav
    local auth = M.authority(inp.iru, inp.adc)
    -- the command (step 6b): the dutch roll damping, the rudder against the
    -- sideslip rate; no modal suppression (X-Plane's airframe does not bend:
    -- its 1 degree and the ADC overspeed's cutoff, p.86, have nothing to do)
    local kt = inp.adc == 0 and M.K_NO_ADC_KT or inp.cas
    local v, gain = inp.adc == 0 and inp.gs or inp.tas, M.gain(kt)
    local beta_rate = M.sideslip_rate(inp, v)
    out.beta_rate = beta_rate
    -- the turn coordination (GAP N19-AFDS-03): the rudder into the roll
    -- with the roll angle's rate, summed with the damping before the
    -- authority limit (ATA22 p.87)
    local tc = M.tc_gain(kt) * M.roll_angle_rate(inp)
    out.tc = tc
    local c0 = -gain * beta_rate + tc
    for i = 1, 2 do
        local y = s.ydm[i]
        step(y, inp, i, dt, nav_up)
        local engaged = ENGAGED[y.mode] == true
        out.mode[i] = y.mode
        out.engaged[i] = engaged
        -- the INOP light and >YAW DAMPER UPR, LWR: the module disengaged or
        -- off (ATA22 p.72, p.88; FCOM p.931, p.958), the power-up test too
        out.inop[i] = not engaged
        -- the command's share: none in the ground operation (p.83)
        out.fade[i] = engaged and y.fade or 0
        out.authority[i] = engaged and auth or 0
        -- each module's rudder (degrees, right plus) within its authority
        -- (p.86-87; ATA27 p.656), faded
        local c = math.max(-out.authority[i], math.min(out.authority[i], c0))
        out.cmd[i] = c * out.fade[i]
    end
    s.out = out
    return out
end

return M
