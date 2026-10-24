-- 747-400 flaps without X-Plane (4-1): the three flap control units (FCU)
-- driving the trailing edge flaps (inboard and outboard groups: hydraulic
-- primary, electric secondary) and the leading edge flaps (inboard,
-- midspan and outboard groups: pneumatic primary, electric secondary),
-- the alternate mode, the sequencing, the load relief, the protections,
-- the indication state and the EICAS messages. Logic and sources:
-- docs/overhaul/notes/ATA-27.md §4.3-§4.4 (FCOM 9.20.13-15 p.953-955;
-- ATA27 27-50 p.224-414).
--
--   local F = B747_fcu_model             -- in XTLua, after dofile
--   local F = dofile(".../B747.27.fcu_model.lua")   -- in the tests
--   local s = F.new()
--   local inp = F.inputs()               -- fill it every frame
--   local out = F.update(s, inp, dt)     -- the same table every frame
--
-- Positions: the trailing edge flaps in degrees (0 up .. 30; flaps 25 is
-- 22 degrees, as the stock tables and the 3D have it: ATA-27 notes §6.2),
-- each group on each wing (the groups' two sides are tied together and part only when a
-- side is stuck: asymmetry); the leading edge groups as a ratio (0 in, 1
-- out) on each wing.

local M = setmetatable({}, {})
B747_fcu_model = M

M.IB, M.OB = 1, 2                   -- trailing edge groups (hydraulic systems 1, 4)
M.LE_IB, M.LE_MID, M.LE_OB = 1, 2, 3    -- leading edge groups (A = inboard + midspan, B = outboard)
M.L, M.R = 1, 2
M.PRI, M.SEC, M.OFF = 0, 1, 2       -- a group's drive: primary, secondary (electric), stopped

-- the lever detents UP, 1, 5, 10, 20, 25, 30 (index 0-6): the trailing
-- edge command in degrees; group A out from 1, group B from 5 (FCOM p.954)
M.TE_DEG = {[0] = 0, 0, 5, 10, 20, 22, 30}
M.GROUP_A_DETENT, M.GROUP_B_DETENT = 1, 2
M.B_RETRACT_DEG = 4.5       -- lever 1: group B in once the inboard TE are below 4.5 units, degrees here (ATA27 p.381)
M.TE_ALTN_MAX = 22          -- alternate: the TE stop at flaps 25 (FCOM p.954)

-- trailing edge protection (ATA27 p.284, p.290-294; FCOM p.953)
M.TE_DISAGREE_S = 7         -- commanded, not moving: that group to secondary
M.TE_DISAGREE_GEAR_S = 42   -- the same while the gear moves
M.TE_LOW_PSI, M.TE_HIGH_PSI = 1400, 1600    -- below 1400 for 4 s: secondary; above 1600 for 4 s: back
M.TE_PSI_S = 4
M.TE_PRIORITY_PSI = 2000    -- the flaps' priority valve opens above 2000 psi (ATA27 p.241)
M.TE_BACK_S = 10            -- in secondary with pressure: back to primary 10 s after fully up
M.TE_SEC_STALL_S = 25       -- secondary, not moving for 25 s: FLAPS DRIVE, STATUS TE FLAPS
M.TE_ASYM = {0.062, 0.034}  -- left and right of a group apart by 6.2 % (IB), 3.4 % (OB) of the travel
M.TE_ASYM_S = 0.1
-- leading edge (ATA27 p.363, p.381-387; FCOM p.953)
M.LE_PRI_S = 9              -- pneumatic: in to out in about 9 s
M.LE_SEC_S = 90             -- electric: about 90 s
M.LE_DISAGREE_S = 30        -- pneumatic, not moving: both wings' group to electric after 20-45 s
                            -- (FCOM p.953; 30 s chosen in that range)
M.LE_DUCT_PSI = 10          -- duct pressure that drives the pneumatic drives (estimate: not in
                            -- the sources; the ducts run at 30-40 psi)
-- the load relief (FCOM p.954; ATA27 p.288-289)
M.RELIEF = {
    [6] = {up = {178, 203}, down = {195, 170}},     -- lever 30: 30->25 at 178, 25->20 at 203; back at 195, 170
    [5] = {up = {203}, down = {195}},               -- lever 25: 25->20 at 203; back at 195
}
M.SHOW_S = 10               -- the indication goes 10 s after all flaps are up (FCOM p.954)
-- estimates (no value in the sources)
M.TE_PRI_DEG_S = 30 / 45    -- primary: the stock rate, 30 degrees in 45 s
M.TE_SEC_DEG_S = M.TE_PRI_DEG_S / 10   -- secondary and alternate: "much slower" (FCOM p.953;
                            -- FCTM p.290): a tenth, as the LE's 9 s and 90 s (ATA27 p.363)
M.LE_SEC_STALL_S = 25       -- electric, not moving: FLAPS DRIVE (like the TE)

local function two(v) return {v, v} end
local function three(v) return {v, v, v} end
local function four(v) return {v, v, v, v} end

function M.inputs()
    return {
        lever = 0,                      -- the flap lever's detent, 0 (UP) .. 6 (30)
        hyd_psi = {3000, 3000},         -- hydraulic systems 1 (IB TE) and 4 (OB TE)
        duct_psi = {35, 35},            -- left and right bleed ducts (each wing's LE drives)
        ac = four(true), dc = four(true),
        ias_kt = 0, ias_valid = true,   -- the air data to the FCUs (load relief)
        altn_arm = false,               -- ALTN FLAPS ARM
        altn_sel = 0,                   -- ALTN FLAPS: -1 RET, 0 OFF, 1 EXT
        on_ground = true,
        reverse = four(false),          -- each engine's reverser out
        gear_moving = false,
        -- failures (no X-Plane equivalents)
        fcu_fail = three(false),        -- FCU L, C, R
        te_pri_fail = two(false),       -- the TE groups' hydraulic drives (PDU) do not move
        te_sec_fail = two(false),       -- their electric drives
        te_stuck = two(false),          -- the left side of a group stuck (broken drive shaft: asymmetry)
        le_pri_fail = three(false),     -- the LE groups' pneumatic drives
        le_sec_fail = three(false),     -- their electric drives
    }
end

local function te_group()
    return {pos = {0, 0}, mode = M.PRI, why_psi = false, low_t = 0, high_t = 0,
        still_t = 0, back_t = 0, asym_t = 0, asym = false, stall = false}
end
local function le_group()
    return {pos = {0, 0}, mode = M.PRI, still_t = 0, stall = false}
end

function M.new()
    local s = {te = {te_group(), te_group()}, le = {le_group(), le_group(), le_group()},
        relief_to = nil, up_t = M.SHOW_S, last_lever = 0, altn_was = false}
    s.out = {
        te = {two(0), two(0)},          -- [group][wing], degrees
        te_deg = four(0),               -- the panels L OB, L IB, R IB, R OB
        le = {two(0), two(0), two(0)},  -- [group][wing]
        slat_a = 0, slat_b = 0,         -- X-Plane's two slat ratios (group A, B)
        cmd_detent = 0,                 -- the FCUs' command (the lever, or the load relief's)
        relief = false,                 -- >FLAP RELIEF
        show = false, expanded = false, moving = false,
        tape = 0, tapes = four(0),      -- the indication's tapes (0 UP .. 1 flaps 30)
        flaps_control = false, flaps_drive = false, flaps_primary = false,
        st_te_flaps = false, st_le_single = false, st_le_mult = false,
        st_fcu = three(false), st_load_relief = false,
        te_moving = false, te_down = false,    -- to the hydraulic demand pumps (ATA-29 §4.2)
    }
    return s
end

local function clamp(x, a, b) if x < a then return a elseif x > b then return b end return x end
-- a step towards the target, landing on it exactly (no rounding residue)
local function toward(x, target, step)
    if x < target then
        x = x + step
        if x >= target - 1e-9 then return target end
    elseif x > target then
        x = x - step
        if x <= target + 1e-9 then return target end
    end
    return x
end

-- the trailing edge degrees as the indication's scale: 0 UP, 1/6 flaps 1,
-- 2/6 5, 3/6 10, 4/6 20, 5/6 25 (22 degrees), 1 30
local SCALE_U = {0, 5, 10, 20, 22, 30}
local SCALE_T = {1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6, 1}
local function scale(u)
    if u <= 0 then return SCALE_T[1] end
    for i = 2, #SCALE_U do
        if u <= SCALE_U[i] then
            local a = (u - SCALE_U[i - 1]) / (SCALE_U[i] - SCALE_U[i - 1])
            return SCALE_T[i - 1] + a * (SCALE_T[i] - SCALE_T[i - 1])
        end
    end
    return 1
end
M.scale = scale

-- start with the flaps where the lever is (a flight starting with flaps out)
function M.set_to(s, inp)
    local lever = clamp(math.floor(inp.lever + 0.5), 0, 6)
    local u = M.TE_DEG[lever]
    for g = 1, 2 do
        local t = s.te[g]
        t.pos[1], t.pos[2] = u, u
        t.mode, t.still_t, t.asym, t.stall = M.PRI, 0, false, false
    end
    for g = 1, 3 do
        local l = s.le[g]
        local out = (g == M.LE_OB and lever >= M.GROUP_B_DETENT) or (g ~= M.LE_OB and lever >= M.GROUP_A_DETENT)
        l.pos[1], l.pos[2] = out and 1 or 0, out and 1 or 0
        l.mode, l.still_t, l.stall = M.PRI, 0, false
    end
    s.relief_to, s.last_lever = nil, lever
    s.up_t = (lever == 0) and M.SHOW_S or 0
end

function M.update(s, inp, dt)
    local out = s.out
    local fcus = 0
    for i = 1, 3 do
        out.st_fcu[i] = inp.fcu_fail[i]
        if not inp.fcu_fail[i] then fcus = fcus + 1 end
    end
    local altn = inp.altn_arm
    local control = fcus > 0 and not altn      -- ALTN ARM takes the control from all three (ATA27 p.284)
    local lever = clamp(math.floor(inp.lever + 0.5), 0, 6)
    local lever_moved = lever ~= s.last_lever
    s.last_lever = lever
    if altn ~= s.altn_was then
        -- out of alternate the FCUs take the flaps to the lever again (ATA27 p.302)
        for g = 1, 2 do s.te[g].still_t = 0 end
        for g = 1, 3 do s.le[g].still_t = 0 end
        s.altn_was = altn
    end

    -- ======== load relief: hydraulic (primary) TE only (FCOM p.954)
    local te1, te2 = s.te[M.IB], s.te[M.OB]
    local ias = inp.ias_kt
    if not (control and inp.ias_valid and te1.mode == M.PRI and te2.mode == M.PRI) or lever < 5 then
        s.relief_to = nil
    elseif lever == 5 then
        if s.relief_to == 5 then s.relief_to = nil end                       -- from lever 30's relief
        if s.relief_to == nil and ias > 203 then s.relief_to = 4
        elseif s.relief_to == 4 and ias < 195 then s.relief_to = nil end
    else
        if s.relief_to == nil and ias > 178 then s.relief_to = 5 end
        if s.relief_to == 5 and ias > 203 then s.relief_to = 4 end
        if s.relief_to == 4 and ias < 195 then s.relief_to = 5 end
        if s.relief_to == 5 and ias < 170 then s.relief_to = nil end
    end
    local cmd = s.relief_to or lever
    out.cmd_detent, out.relief = cmd, s.relief_to ~= nil
    out.st_load_relief = control and not inp.ias_valid     -- STATUS FLAP LOAD RELIEF (ATA27 p.337)

    -- ======== trailing edge
    local te_target = M.TE_DEG[cmd]
    if altn then
        if inp.altn_sel > 0 then te_target = M.TE_ALTN_MAX
        elseif inp.altn_sel < 0 then te_target = 0 end
    end
    local te_moving, te_down = false, false
    for g = 1, 2 do
        local t = s.te[g]
        local psi = inp.hyd_psi[g]
        local motor = (g == M.IB and inp.ac[4]) or (g == M.OB and inp.ac[3])    -- ATA27 p.339
        local sec_ok = motor and not inp.te_sec_fail[g]
        local target, rate = t.pos[2], 0
        if altn then
            -- the alternate motors, straight from the selector; at 25 the EXT stops
            if inp.altn_sel ~= 0 and sec_ok then
                target = te_target
                if inp.altn_sel > 0 and t.pos[2] >= M.TE_ALTN_MAX then target = t.pos[2] end
                rate = M.TE_SEC_DEG_S
            end
        elseif control then
            if lever_moved then t.stall, t.asym, t.asym_t = false, false, 0 end    -- tried again
            -- the hydraulic pressure: below 1400 psi for 4 s while the group
            -- has somewhere to go, secondary; above 1600 for 4 s, back (a
            -- group at rest stays: no FLAPS PRIMARY at the gate without
            -- pressure; estimate, the sources describe the flaps driven)
            local pending = math.abs(te_target - t.pos[1]) > 1e-6 or math.abs(te_target - t.pos[2]) > 1e-6
            if psi < M.TE_LOW_PSI and pending and not (t.stall or t.asym) then
                t.low_t = t.low_t + dt
            else
                t.low_t = 0
            end
            if psi > M.TE_HIGH_PSI then t.high_t = t.high_t + dt else t.high_t = 0 end
            if t.mode == M.PRI and t.low_t >= M.TE_PSI_S then t.mode, t.why_psi, t.still_t = M.SEC, true, 0 end
            if t.mode == M.SEC and t.why_psi and t.high_t >= M.TE_PSI_S then
                t.mode, t.why_psi, t.still_t = M.PRI, false, 0
            end
            -- secondary for a fault: back to primary 10 s after fully up
            if t.mode == M.SEC and not t.why_psi then
                if t.pos[1] <= 0 and t.pos[2] <= 0 and te_target <= 0 then
                    t.back_t = t.back_t + dt
                    if t.back_t >= M.TE_BACK_S then t.mode, t.back_t, t.still_t = M.PRI, 0, 0 end
                else
                    t.back_t = 0
                end
            end
            if not (t.stall or t.asym) then
                target = te_target
                if t.mode == M.PRI then
                    -- the input actuator (AC 1, DC 1) and the PDU behind the priority valve
                    if inp.ac[1] and inp.dc[1] and psi > M.TE_PRIORITY_PSI and not inp.te_pri_fail[g] then
                        rate = M.TE_PRI_DEG_S
                    end
                elseif sec_ok then
                    rate = M.TE_SEC_DEG_S
                end
            end
        end
        -- move: the left side holds when its drive shaft is broken
        local was = t.pos[2]
        local step = rate * dt
        if not inp.te_stuck[g] then t.pos[1] = toward(t.pos[1], target, step) end
        t.pos[2] = toward(t.pos[2], target, step)
        local moved = t.pos[2] ~= was
        if moved then te_moving = true end
        if math.max(t.pos[1], t.pos[2]) > 0.5 then te_down = true end
        -- commanded and not moving (FCU control only)
        if control and not (t.stall or t.asym) and math.abs(target - t.pos[2]) > 1e-6 and not moved then
            t.still_t = t.still_t + dt
            if t.mode == M.PRI then
                if t.still_t >= (inp.gear_moving and M.TE_DISAGREE_GEAR_S or M.TE_DISAGREE_S) then
                    t.mode, t.why_psi, t.still_t = M.SEC, false, 0     -- FLAPS PRIMARY
                end
            elseif t.still_t >= M.TE_SEC_STALL_S then
                t.stall = true                                          -- FLAPS DRIVE, TE FLAPS
            end
        else
            t.still_t = 0
        end
        -- asymmetry: the sides apart; no secondary either (FCOM p.953)
        if control and math.abs(t.pos[1] - t.pos[2]) / 30 > M.TE_ASYM[g] then
            t.asym_t = t.asym_t + dt
            if t.asym_t >= M.TE_ASYM_S then t.asym = true end
        else
            t.asym_t = 0
        end
        out.te[g][1], out.te[g][2] = t.pos[1], t.pos[2]
    end
    out.te_moving, out.te_down = te_moving, te_down

    -- ======== leading edge
    local ib_te_up = te1.pos[1] <= 0 and te1.pos[2] <= 0
    local ob_te_up = te2.pos[1] <= 0 and te2.pos[2] <= 0
    local function le_target(g, now)
        if g == M.LE_OB then
            if cmd >= M.GROUP_B_DETENT then return 1 end
            if cmd <= 1 and math.max(te1.pos[1], te1.pos[2]) < M.B_RETRACT_DEG then return 0 end
        else
            if cmd >= M.GROUP_A_DETENT then return 1 end
            if ob_te_up then return 0 end
        end
        return now
    end
    -- the reversers on engines 1 and 4 or 2 and 3 on the ground: group A in
    -- while its drives are pneumatic (ATA27 p.382; FCOM p.955)
    local rev = (inp.reverse[1] and inp.reverse[4]) or (inp.reverse[2] and inp.reverse[3])
    local a_pneumatic = s.le[M.LE_IB].mode == M.PRI and s.le[M.LE_MID].mode == M.PRI
    local auto_in = control and inp.on_ground and rev and a_pneumatic
    out.le_auto_in = auto_in
    local le_power = inp.ac[1] or inp.ac[3] or inp.ac[4]       -- the LE controls and motors (ATA27 p.413; estimate)
    local to_sec = {false, false, false}
    local commanded_g = {false, false, false}
    for g = 1, 3 do
        local l = s.le[g]
        local target, rate = {l.pos[1], l.pos[2]}, {0, 0}
        local sec_ok = le_power and not inp.le_sec_fail[g]
        if altn then
            if inp.altn_sel ~= 0 and sec_ok then
                local tg = inp.altn_sel > 0 and 1 or 0
                if inp.altn_sel < 0 and not ib_te_up then tg = l.pos[2] end    -- in after the IB TE (FCOM p.954)
                target = {tg, tg}
                rate = {1 / M.LE_SEC_S, 1 / M.LE_SEC_S}
            end
        elseif control then
            if lever_moved then l.stall = false end
            if not l.stall then
                local tg = le_target(g, l.pos[2])
                if auto_in and g ~= M.LE_OB then tg = 0 end
                target = {tg, tg}
                for w = 1, 2 do
                    if l.mode == M.PRI then
                        if le_power and inp.duct_psi[w] >= M.LE_DUCT_PSI and not inp.le_pri_fail[g] then
                            rate[w] = 1 / M.LE_PRI_S
                        end
                    elseif sec_ok then
                        rate[w] = 1 / M.LE_SEC_S
                    end
                end
            end
        end
        local moved_all, commanded = true, false
        for w = 1, 2 do
            local was = l.pos[w]
            l.pos[w] = toward(l.pos[w], target[w], rate[w] * dt)
            if math.abs(target[w] - l.pos[w]) > 1e-6 then
                commanded = true
                if l.pos[w] == was then moved_all = false end
            end
        end
        if control and not l.stall and commanded and not moved_all then
            l.still_t = l.still_t + dt
            if l.mode == M.PRI and l.still_t >= M.LE_DISAGREE_S then to_sec[g] = true
            elseif l.mode == M.SEC and l.still_t >= M.LE_SEC_STALL_S then l.stall = true end   -- FLAPS DRIVE
        else
            l.still_t = 0
        end
        commanded_g[g] = commanded
    end
    -- electric until the group reaches its command; the inboard and
    -- midspan groups change to electric together and stay so until both
    -- have (FCOM p.953)
    local a_commanded = commanded_g[M.LE_IB] or commanded_g[M.LE_MID]
    for g = 1, 3 do
        local l = s.le[g]
        local still = (g == M.LE_OB) and commanded_g[g] or (g ~= M.LE_OB and a_commanded)
        if l.mode == M.SEC and not still and control then l.mode = M.PRI end
    end
    if to_sec[M.LE_IB] or to_sec[M.LE_MID] then to_sec[M.LE_IB], to_sec[M.LE_MID] = true, true end
    local le_sec = 0
    for g = 1, 3 do
        local l = s.le[g]
        if to_sec[g] then l.mode, l.still_t = M.SEC, 0 end
        if l.mode == M.SEC or l.stall then le_sec = le_sec + 1 end
        out.le[g][1], out.le[g][2] = l.pos[1], l.pos[2]
    end
    local a1, a2 = s.le[M.LE_IB].pos, s.le[M.LE_MID].pos
    out.slat_a = (a1[1] + a1[2] + a2[1] + a2[2]) / 4
    out.slat_b = (s.le[M.LE_OB].pos[1] + s.le[M.LE_OB].pos[2]) / 2

    -- ======== surfaces: the TE panels L OB, L IB, R IB, R OB
    out.te_deg[1], out.te_deg[2] = te2.pos[1], te1.pos[1]
    out.te_deg[3], out.te_deg[4] = te1.pos[2], te2.pos[2]

    -- ======== messages (FCOM p.957; ATA27 p.335, p.384, p.411)
    local te_sec, te_off, le_off, le_in_sec = false, false, false, false
    for g = 1, 2 do
        if s.te[g].mode == M.SEC then te_sec = true end
        if s.te[g].stall or s.te[g].asym then te_off = true end
    end
    for g = 1, 3 do
        if s.le[g].stall then le_off = true end
        if s.le[g].mode == M.SEC and not s.le[g].stall then le_in_sec = true end
    end
    out.flaps_control = altn or fcus == 0
    out.flaps_drive = control and (te_off or le_off)
    -- FLAPS PRIMARY: a group in secondary; not with an LE drive stopped
    out.flaps_primary = control and (te_sec or le_in_sec) and not le_off
    out.st_te_flaps = control and te_off
    out.st_le_single = control and le_sec == 1
    out.st_le_mult = control and le_sec > 1

    -- ======== indication (FCOM p.936-938, p.954-955; ATA27 p.318-322)
    local all_up = true
    for g = 1, 2 do if s.te[g].pos[1] > 0 or s.te[g].pos[2] > 0 then all_up = false end end
    for g = 1, 3 do if s.le[g].pos[1] > 0 or s.le[g].pos[2] > 0 then all_up = false end end
    if all_up then s.up_t = s.up_t + dt else s.up_t = 0 end
    out.show = lever > 0 or not all_up or s.up_t < M.SHOW_S
    local odd = altn or te_sec or te_off or le_sec > 0
    for g = 1, 2 do if math.abs(s.te[g].pos[1] - s.te[g].pos[2]) > 0.5 then odd = true end end
    for g = 1, 3 do if math.abs(s.le[g].pos[1] - s.le[g].pos[2]) > 0.05 then odd = true end end
    out.expanded = odd
    -- normal: the slowest TE group; between UP and 1 the group A flaps
    local slowest, gap = 0, -1
    for g = 1, 2 do
        for w = 1, 2 do
            local d = math.abs(te_target - s.te[g].pos[w])
            if d > gap then slowest, gap = s.te[g].pos[w], d end
        end
    end
    if math.max(te1.pos[1], te1.pos[2], te2.pos[1], te2.pos[2]) <= 0 then
        out.tape = out.slat_a / 6
    else
        out.tape = scale(slowest)
    end
    -- expanded: each TE panel on its own (0 when up)
    local panels = {te2.pos[1], te1.pos[1], te1.pos[2], te2.pos[2]}
    for i = 1, 4 do
        local u = panels[i]
        out.tapes[i] = (u <= 0) and 0 or scale(u)
    end
    -- the lever's mark magenta while any flap is away from the lever's place
    local moving = false
    local lever_deg = M.TE_DEG[lever]
    for g = 1, 2 do
        for w = 1, 2 do if math.abs(s.te[g].pos[w] - lever_deg) > 0.05 then moving = true end end
    end
    for g = 1, 3 do
        local want = ((g == M.LE_OB and lever >= M.GROUP_B_DETENT) or (g ~= M.LE_OB and lever >= M.GROUP_A_DETENT)) and 1 or 0
        for w = 1, 2 do if math.abs(s.le[g].pos[w] - want) > 0.01 then moving = true end end
    end
    out.moving = moving
    return out
end

return M
