-- 747-400 yaw dampers without X-Plane (6-3 step 6a): the upper and lower
-- yaw damper modules (YDM), their operational modes (the power-up test,
-- the ground operation, the fade-in and fade-out, the flight mode, the
-- fault INOP mode and its autorecovery), engagement and INOP, and the
-- authority by the valid IRUs and ADCs. Logic and sources:
-- docs/overhaul/notes/ATA-22.md §2.4, §4.7 and §39 (ATA22 22-21 p.52-90,
-- the modes' figure p.85, the command's p.87; ATA27 p.42, p.656; FCOM
-- p.931, p.949-950, p.958).
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
    local out = s.out or {mode = {}, engaged = {}, inop = {}, fade = {}, authority = {}}
    local nav_up = inp.iru_nav > s.iru_nav
    s.iru_nav = inp.iru_nav
    local auth = M.authority(inp.iru, inp.adc)
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
    end
    s.out = out
    return out
end

return M
