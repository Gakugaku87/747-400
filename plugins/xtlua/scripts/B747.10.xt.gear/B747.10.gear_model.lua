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

local function five(v) return {v, v, v, v, v} end
local function wing(i) return i == M.LW or i == M.RW end

function M.inputs()
    return {
        lever = M.DN,
        hyd_psi = {3000, 3000},             -- hydraulic systems 1 and 4
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
    }
end

function M.new()
    local s = {pos = five(1), door = five(0), altn = five(false), released = five(false),
        disagree_t = five(0), door_t = 0, tilt_t = 0, up_t = M.UP_BLANK_S}
    s.out = {
        pos = five(1), door = five(0),
        downlocked = five(true), uplocked = five(false),
        all_down = true, all_up = false, moving = false,
        gear = five(M.IND_DOWN),            -- each gear's box (expanded display)
        annun = M.IND_DOWN,                 -- the normal display
        display = M.DISPLAY_NORMAL,
        gear_disagree = false, gear_door = false, gear_tilt = false,
    }
    return s
end

-- a flight start: the gear and the doors where X-Plane has put the gear
function M.set_to(s, positions)
    local all_up = true
    for i = 1, 5 do
        s.pos[i] = positions[i]
        s.door[i] = 0
        s.altn[i], s.released[i] = false, false
        s.disagree_t[i] = 0
        if positions[i] > M.LOCK then all_up = false end
    end
    s.door_t, s.tilt_t = 0, 0
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

function M.update(s, inp, dt)
    local out = s.out
    -- the alternate extension: each switch, with its motor's power, starts a
    -- cycle that runs to the end (ATA29_32 p.276-282). The gear stays on it
    -- for the flight: all doors remain open after an alternate extension
    -- (FCOM p.1513); the normal system no longer moves that gear (estimate)
    local nb_power = inp.ac[4] and inp.dc[4]            -- p.270, p.279 figure
    local w_power = inp.ac[1]                           -- p.272, p.281 figure
    local any_altn = inp.altn_nose_body or inp.altn_wing
    for i = 1, 5 do
        local pushed = wing(i) and inp.altn_wing or (not wing(i) and inp.altn_nose_body)
        if pushed and (wing(i) and w_power or (not wing(i) and nb_power)) then s.altn[i] = true end
        if s.altn[i] then any_altn = true end
    end

    local moving = false
    for i = 1, 5 do
        local psi = (M.SYSTEM[i] == 1) and inp.hyd_psi[1] or inp.hyd_psi[2]
        local powered = psi >= M.POWER_PSI
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
            -- carrying weight does not come up.
            local target = nil
            if powered and inp.lever == M.DN then target = 1
            elseif powered and inp.lever == M.UP and not inp.on_ground[i] then target = 0 end
            if target then
                if math.abs(s.pos[i] - target) > M.LOCK then
                    if not inp.door_stuck[i] then s.door[i] = toward(s.door[i], 1, dt / M.DOOR_OPEN_S) end
                    if s.door[i] >= 1 and not inp.stuck[i] then
                        s.pos[i] = toward(s.pos[i], target, dt / M.GEAR_S[i])
                    end
                elseif not inp.door_stuck[i] then
                    s.door[i] = toward(s.door[i], 0, dt / M.DOOR_CLOSE_S)
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
