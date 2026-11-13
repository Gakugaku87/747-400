-- 747-400 landing gear actuation without X-Plane (4-2): the lever's two
-- selector valves (nose and body gear on hydraulic system 1, wing gear on
-- system 4), the doors and the sequence, the alternate extension (NOSE/BODY:
-- AC bus 4, WING: AC bus 1), the position monitoring (GEAR DISAGREE, GEAR
-- DOOR, GEAR TILT) and the EICAS gear indication. Logic and sources:
-- docs/overhaul/notes/ATA-32.md §2.1-§2.2, §3.2, §3.4, §4.3-§4.5 (FCOM
-- 14.10-14.20 p.1499-1513, p.1522; Boeing ATA 29/32 training manual
-- "ATA29_32", PDF pages).
--
--   local G = B747_gear_model             -- in XTLua, after dofile
--   local G = dofile(".../B747.10.gear_model.lua")   -- in the tests
--   local s = G.new()
--   local inp = G.inputs()               -- fill it every frame
--   G.set_to(s, {1, 1, 1, 1, 1})         -- a flight start: the gear where X-Plane has it
--   local out = G.update(s, inp, dt)     -- the same table every frame
--
-- Gears: nose, left body, right body, left wing, right wing. Positions 0 up
-- (locked) to 1 down (locked); doors 0 closed to 1 open.

local M = setmetatable({}, {})
B747_gear_model = M

M.NOSE, M.LB, M.RB, M.LW, M.RW = 1, 2, 3, 4, 5
M.SYSTEM = {1, 1, 1, 4, 4}          -- the hydraulic system moving each gear (FCOM p.1511)
M.DN, M.OFF, M.UP = 0, 1, 2         -- the lever (laminar/B747/actuator/gear_handle)
-- the indication: the normal display (annun) and each gear's box (expanded)
M.IND_UP, M.IND_DOWN, M.IND_TRANSIT, M.IND_FAIL = 0, 1, 2, 3   -- FAIL: empty box (normal), amber X (expanded)
M.DISPLAY_OFF, M.DISPLAY_NORMAL, M.DISPLAY_EXPANDED = 0, 1, 2

M.DOOR_OPEN_S = 2           -- the doors open in about 2 s (ATA29_32 p.242, p.256)
M.DOOR_CLOSE_S = 5          -- and close in about 5 s (p.248)
M.ALTN_WING_S = 20          -- alternate extension, wing gear: up to down in about 20 s (p.250)
M.ALTN_WING_DOOR = 0.5      -- the wing gear's uplock opens once its door is past 45 degrees
                            -- (p.272): half the door's travel (estimate)
M.DISAGREE_S, M.DOOR_S = 30, 30     -- GEAR DISAGREE, GEAR DOOR (ATA29_32 p.662-664)
M.TILT_S = 15                       -- GEAR TILT (p.336-337)
M.UP_BLANK_S = 10                   -- UP blanks after 10 s (FCOM p.1505)
-- estimates (no values in the sources): the gear's travel, the acf's cycle
-- times (the nose and body gear's free fall in the alternate extension
-- taken as the same); the pressure the gear actuators need; the pressure
-- below which GEAR TILT is inhibited (the PSEU's HYDIM pressure high)
M.GEAR_S = {12, 9, 9, 7, 7}
M.POWER_PSI = 1000
M.TILT_PSI = 1500
M.LOCK = 1e-6
-- (2026-11-13; the 2026-11-12 review HA-1, 案 26) the flow each gear's
-- actuators take while it or its doors move at the normal speed, gpm; with
-- less from its system (inputs.spare_gpm) they move slower in proportion.
-- Estimates (no values in the sources): with all engines windmilling the
-- extension may take up to two and a half minutes (FCTM p.286 (8.8)); the
-- three gears of system 1 and the two of system 4 take 18 gpm a system,
-- under what an engine pump gives at flight idle (37.5 gpm at its rated
-- speed, ATA29_32 p.26, in proportion to N2: B747.19.hyd_model.lua), so
-- that the normal extension and retraction keep their times
M.GEAR_GPM = {4, 7, 7, 9, 9}

local function five(v) return {v, v, v, v, v} end
local function wing(i) return i == M.LW or i == M.RW end

function M.inputs()
    return {
        lever = M.DN,
        hyd_psi = {3000, 3000},             -- hydraulic systems 1 and 4
        -- (案 26) the flow systems 1 and 4 can give the gear, gpm (the
        -- hydraulic model's spare_gpm)
        spare_gpm = {math.huge, math.huge},
        ac = {true, true, true, true}, dc = {true, true, true, true},
        altn_nose_body = false,             -- ALTN GEAR EXTEND NOSE/BODY pushed (on)
        altn_wing = false,                  -- ALTN GEAR EXTEND WING pushed (on)
        on_ground = five(true),             -- each gear carrying weight (it cannot retract)
        air = false,                        -- the PSEU in air mode (primary and alternate)
        tilted = five(true),                -- each main gear's truck tilted ([1], the nose, unused)
        -- failures (no X-Plane equivalents)
        stuck = five(false),                -- the gear does not move
        door_stuck = five(false),           -- its door does not move
        ind_fail = five(false),             -- its position indication lost (primary and alternate)
        -- (2026-11-04) one subsystem's position sensing of the gear failed:
        -- the other keeps the indication; GEAR MONITOR (ATA29_32 p.666)
        sensor_fail = five(false),
    }
end

function M.new()
    -- (2026-11-13, FG-7) altn_on: last frame's alternate switch pushed with
    -- its motor's power; s.lever: last frame's lever (nil at a start)
    local s = {pos = five(1), door = five(0), altn = five(false), released = five(false),
        altn_on = five(false), disagree_t = five(0), door_t = 0, tilt_t = 0, up_t = M.UP_BLANK_S}
    s.out = {
        pos = five(1), door = five(0),
        downlocked = five(true), uplocked = five(false),
        all_down = true, all_up = false, moving = false,
        gear = five(M.IND_DOWN),            -- each gear's box (expanded display)
        annun = M.IND_DOWN,                 -- the normal display
        display = M.DISPLAY_NORMAL,
        gear_disagree = false, gear_door = false, gear_tilt = false,
        gear_monitor = false,               -- (2026-11-04) STATUS GEAR MONITOR
        hyd_gpm = {0, 0},                   -- (案 26) the flow the gear takes from systems 1 and 4
    }
    return s
end

-- a flight start: the gear and the doors where X-Plane has put the gear
function M.set_to(s, positions)
    local all_up = true
    for i = 1, 5 do
        s.pos[i] = positions[i]
        s.door[i] = 0
        s.altn[i], s.released[i], s.altn_on[i] = false, false, false
        s.disagree_t[i] = 0
        if positions[i] > M.LOCK then all_up = false end
    end
    s.door_t, s.tilt_t, s.lever = 0, 0, nil
    s.up_t = all_up and M.UP_BLANK_S or 0
end

-- a step towards the target, landing on it exactly (no rounding residue)
local function toward(x, target, step)
    if x < target then
        x = x + step
        if x >= target - M.LOCK then return target end
    elseif x > target then
        x = x - step
        if x <= target + M.LOCK then return target end
    end
    return x
end

-- (案 26) the normal system's target for gear i: 1 down, 0 up, nil none
-- (on the alternate extension, no pressure, the lever OFF, UP carrying
-- weight)
local function normal_target(s, inp, i)
    if s.altn[i] then return nil end
    local psi = (M.SYSTEM[i] == 1) and inp.hyd_psi[1] or inp.hyd_psi[2]
    if psi < M.POWER_PSI then return nil end
    if inp.lever == M.DN then return 1 end
    if inp.lever == M.UP and not inp.on_ground[i] then return 0 end
    return nil
end

-- (案 26) whether gear i's actuators move towards the target: its doors
-- opening, the gear travelling, its doors closing
local function normal_moving(s, inp, i, target)
    if math.abs(s.pos[i] - target) > M.LOCK then
        if s.door[i] < 1 then return not inp.door_stuck[i] end
        return not inp.stuck[i]
    end
    return s.door[i] > 0 and not inp.door_stuck[i]
end

function M.update(s, inp, dt)
    local out = s.out
    -- the alternate extension: each switch, with its motor's power, starts a
    -- cycle that runs to the end (ATA29_32 p.276-282). All doors remain open
    -- after an alternate extension (FCOM p.1513); the normal system does not
    -- move that gear meanwhile (estimate).
    -- (2026-11-13; the 2026-11-12 review FG-7) a cycle starts as the switch is
    -- pushed with its motor's power, or as the power comes with the switch
    -- pushed, and runs once: no recycling is needed after it (p.276-278).
    -- Once that gear is down and locked, the lever moved to UP in the air
    -- gives the gear back to the normal system, which retracts it and closes
    -- its doors (estimate: the sources do not say). Before, the gear stayed
    -- on the alternate extension for the flight, even after a push on the
    -- ground
    local nb_power = inp.ac[4] and inp.dc[4]            -- p.270, p.279 figure
    local w_power = inp.ac[1]                           -- p.272, p.281 figure
    local any_altn = inp.altn_nose_body or inp.altn_wing
    local to_up = inp.lever == M.UP and s.lever ~= nil and s.lever ~= M.UP
    s.lever = inp.lever
    for i = 1, 5 do
        local pushed = wing(i) and inp.altn_wing or (not wing(i) and inp.altn_nose_body)
        local on = (pushed and ((wing(i) and w_power) or (not wing(i) and nb_power))) or false
        if on and not s.altn_on[i] then s.altn[i] = true end
        s.altn_on[i] = on
        if s.altn[i] and to_up and s.pos[i] >= 1 - M.LOCK and not inp.on_ground[i] then
            s.altn[i], s.released[i] = false, false
        end
        if s.altn[i] then any_altn = true end
    end

    -- (案 26) the flow the normal system's moving gears and doors need from
    -- systems 1 and 4, and the share of it their systems give
    local need1, need4 = 0, 0
    for i = 1, 5 do
        local target = normal_target(s, inp, i)
        if target and normal_moving(s, inp, i, target) then
            if M.SYSTEM[i] == 1 then need1 = need1 + M.GEAR_GPM[i] else need4 = need4 + M.GEAR_GPM[i] end
        end
    end
    local f1 = need1 > 0 and math.min(1, inp.spare_gpm[1] / need1) or 1
    local f4 = need4 > 0 and math.min(1, inp.spare_gpm[2] / need4) or 1
    out.hyd_gpm[1], out.hyd_gpm[2] = need1 * f1, need4 * f4

    local moving = false
    for i = 1, 5 do
        local was = s.pos[i]
        if s.altn[i] then
            -- alternate: the nose and body gear fall as their uplocks and
            -- door locks let go and push the doors open; the wing gear's
            -- motor opens the door first (p.270-274)
            if wing(i) then
                if not inp.door_stuck[i] and w_power then s.door[i] = toward(s.door[i], 1, dt / M.DOOR_OPEN_S) end
                if s.door[i] >= M.ALTN_WING_DOOR then s.released[i] = true end
                if s.released[i] and not inp.stuck[i] then
                    s.pos[i] = toward(s.pos[i], 1, dt / (M.ALTN_WING_S - M.DOOR_OPEN_S * M.ALTN_WING_DOOR))
                end
            else
                s.released[i] = true
                if not inp.stuck[i] then s.pos[i] = toward(s.pos[i], 1, dt / M.GEAR_S[i]) end
                if not inp.door_stuck[i] then s.door[i] = math.max(s.door[i], math.min(1, s.pos[i] * 4)) end
            end
        else
            -- normal: the lever's selector valve and the system's pressure;
            -- OFF or no pressure holds the gear where it is (estimate). A gear
            -- carrying weight does not come up. (案 26) The doors and the
            -- gear at the share of the flow their system gives
            local target = normal_target(s, inp, i)
            local step = dt * ((M.SYSTEM[i] == 1) and f1 or f4)
            if target then
                if math.abs(s.pos[i] - target) > M.LOCK then
                    if not inp.door_stuck[i] then s.door[i] = toward(s.door[i], 1, step / M.DOOR_OPEN_S) end
                    if s.door[i] >= 1 and not inp.stuck[i] then
                        s.pos[i] = toward(s.pos[i], target, step / M.GEAR_S[i])
                    end
                elseif not inp.door_stuck[i] then
                    s.door[i] = toward(s.door[i], 0, step / M.DOOR_CLOSE_S)
                end
            end
        end
        if s.pos[i] ~= was then moving = true end
    end

    -- positions, locks and the monitoring (ATA29_32 p.658-666)
    local all_down, all_up, any_door, any_disagree, all_fail = true, true, false, false, true
    for i = 1, 5 do
        local down, up = s.pos[i] >= 1 - M.LOCK, s.pos[i] <= M.LOCK
        out.pos[i], out.door[i] = s.pos[i], s.door[i]
        out.downlocked[i], out.uplocked[i] = down, up
        if not down then all_down = false end
        if not up then all_up = false end
        if s.door[i] > M.LOCK then any_door = true end
        if inp.ind_fail[i] then out.gear[i] = M.IND_FAIL
        elseif down then out.gear[i] = M.IND_DOWN
        elseif up then out.gear[i] = M.IND_UP
        else out.gear[i] = M.IND_TRANSIT end
        if not inp.ind_fail[i] then all_fail = false end
        -- disagree: the lever DN and not down and locked, or not DN and not up and locked
        local disagree = (inp.lever == M.DN and not down) or (inp.lever ~= M.DN and not up)
        if disagree then s.disagree_t[i] = s.disagree_t[i] + dt else s.disagree_t[i] = 0 end
        if s.disagree_t[i] >= M.DISAGREE_S then any_disagree = true end
    end
    out.all_down, out.all_up, out.moving = all_down, all_up, moving
    out.gear_disagree = any_disagree
    -- (2026-11-04) GEAR MONITOR: the primary and alternate position
    -- indication disagree, found by the PSEU's BITE; no MULTIPLE GEAR
    -- display (ATA29_32 p.666)
    local monitor = false
    for i = 1, 5 do if inp.sensor_fail[i] then monitor = true end end
    out.gear_monitor = monitor
    -- GEAR DOOR: a door not closed; not with an alternate extension selected
    -- or used (ATA29_32 p.664, p.673)
    if any_door and not any_altn then s.door_t = s.door_t + dt else s.door_t = 0 end
    out.gear_door = s.door_t >= M.DOOR_S
    -- GEAR TILT: a main gear's truck not tilted in air mode; not with system 1
    -- or 4 low (p.336-337, p.341)
    local untilted = false
    for i = 2, 5 do if not inp.tilted[i] then untilted = true end end
    local tilt_ok = inp.hyd_psi[1] >= M.TILT_PSI and inp.hyd_psi[2] >= M.TILT_PSI
    if inp.air and untilted and tilt_ok then s.tilt_t = s.tilt_t + dt else s.tilt_t = 0 end
    out.gear_tilt = s.tilt_t >= M.TILT_S

    -- the indication (FCOM p.1505-1506, p.1513; ATA29_32 p.658-660): expanded
    -- with GEAR DISAGREE or the alternate extension used; UP blanks after 10 s
    if all_up then s.up_t = s.up_t + dt else s.up_t = 0 end
    if all_fail then out.annun = M.IND_FAIL
    elseif all_down then out.annun = M.IND_DOWN
    elseif all_up then out.annun = M.IND_UP
    else out.annun = M.IND_TRANSIT end
    if any_disagree or any_altn then out.display = M.DISPLAY_EXPANDED
    elseif all_up and s.up_t >= M.UP_BLANK_S and not all_fail then out.display = M.DISPLAY_OFF
    else out.display = M.DISPLAY_NORMAL end
    return out
end

return M
