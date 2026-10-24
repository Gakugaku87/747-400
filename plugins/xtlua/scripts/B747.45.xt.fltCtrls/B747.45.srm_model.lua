-- 747-400 stabilizer trim / rudder ratio modules (SRM) without X-Plane
-- (4-1 step 2a): the outboard aileron lockout and the upper and lower
-- rudder ratio changers (RRC), with their monitoring and messages. Two
-- SRMs (L, R); one controls each function, the other stands by. Logic and
-- sources: docs/overhaul/notes/ATA-27.md §4.1, §4.8 (FCOM 9.20.7, 9.20.9
-- p.947-949, p.957; ATA27 27-11 p.104-110, 27-21 p.634-648).
--
--   local S = B747_srm_model             -- in XTLua, after dofile
--   local S = dofile(".../B747.45.srm_model.lua")   -- in the tests
--   local s = S.new()
--   local inp = S.inputs()               -- fill it every frame
--   local out = S.update(s, inp, dt)     -- the same table every frame

local M = setmetatable({}, {})
B747_srm_model = M

M.UPR, M.LWR = 1, 2                 -- the rudder ratio changers

-- outboard aileron lockout (ATA27 p.106, p.107 figure): lock with the LE
-- group A in and above 238 kt or M .53; unlock with group A out, or below
-- 232 kt and M .51; in between the last command holds
M.LOCK_KT, M.UNLOCK_KT = 238, 232
M.LOCK_M, M.UNLOCK_M = 0.53, 0.51
M.LOCK_MONITOR_S = 45       -- not at the command 45 s after it: the other SRM; still: AILERON LOCKOUT (p.110)
-- rudder ratio changer (ATA27 p.634-637): the actuator's extension (in)
-- against airspeed, read off the p.637 figure (estimate between the
-- points); 0 in is 32 degrees of rudder, 1.0 in is 5 degrees
M.RRC_KT = {155.5, 170, 195, 245, 310, 355, 420, 450}
M.RRC_IN = {0, 0.2, 0.4, 0.6, 0.8, 0.9, 0.97, 1.0}
M.RUDDER_MAX, M.RUDDER_MIN = 32, 5
M.RRC_FIXED_KT = {329, 209}     -- air data lost: upper at 329 kt, lower at 209 kt (p.640)
M.RRC_MONITOR_KT = 160          -- the servo monitor is inhibited below 160 kt (p.646)
M.RRC_ERROR_IN = 0.01           -- servo error that latches the monitor (p.646)
-- estimates (no values in the sources)
M.LOCK_TRAVEL_S = 2             -- the lockout actuator from unlocked to locked
M.RRC_IN_S = 0.2                -- the RRC actuator's speed, in per second
M.RRC_MONITOR_S = 2             -- how long the servo error lasts before the monitor latches

local function two(v) return {v, v} end

function M.inputs()
    return {
        vc = {0, 0}, mach = {0, 0},     -- the left and right air data (each SRM's primary)
        air_valid = two(true),
        le_a_in = true,                 -- the FCU: LE group A (inboard and midspan) retracted
        le_valid = true,                -- the FCUs' flap data (all three failed: false)
        on_ground = true,
        autoland = false,               -- the SRM in autoland: the RRCs at full authority
        srm_fail = two(false),          -- SRM L, R
        lockout_stuck = false,          -- the lockout actuator does not move
        rrc_stuck = two(false),         -- the upper, lower RRC actuators do not move
    }
end

function M.new()
    local s = {
        locked = false,                 -- the lockout command
        lock_pos = 0,                   -- the actuator: 0 unlocked .. 1 locked
        lock_srm = 1,                   -- the SRM controlling the lockout
        lock_off_t = 0,                 -- time the actuator has been away from the command
        lock_tried = false,             -- the other SRM has had its go
        lock_fault = false,             -- AILERON LOCKOUT (latched)
        rrc_in = two(0),                -- the actuators' extension
        rrc_err_t = two(0),
        rrc_fault = two(false),         -- RUD RATIO (latched)
        first = true,
    }
    s.out = {
        lockout = 1,                    -- the outboard ailerons' authority: 1 unlocked .. 0 locked
        rudder_ratio = two(1),          -- the rudders' authority through the RRCs (1 = 32 degrees)
        rudder_max = two(M.RUDDER_MAX),
        aileron_lockout = false,        -- advisory AILERON LOCKOUT (and STATUS)
        rud_ratio_sngl = false, rud_ratio_dual = false,     -- advisories RUD RATIO SNGL, DUAL
        st_rudder_ratio = false,        -- STATUS RUDDER RATIO
    }
    return s
end

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

-- the RRC's extension at an airspeed (p.637 figure)
local function rrc_in(kt)
    local K, I = M.RRC_KT, M.RRC_IN
    if kt <= K[1] then return 0 end
    for i = 2, #K do
        if kt <= K[i] then return I[i - 1] + (kt - K[i - 1]) / (K[i] - K[i - 1]) * (I[i] - I[i - 1]) end
    end
    return I[#I]
end
M.rrc_in = rrc_in
local function rudder_max(x) return M.RUDDER_MAX - (M.RUDDER_MAX - M.RUDDER_MIN) * x end

-- the SRM that has a function: the first working one from `pref`
local function working(inp, pref)
    if not inp.srm_fail[pref] then return pref end
    if not inp.srm_fail[3 - pref] then return 3 - pref end
    return nil
end

-- an SRM's air data: its own side's first, the other side's next (p.104,
-- p.640); nil when both are lost
local function air_data(inp, srm)
    if inp.air_valid[srm] then return inp.vc[srm], inp.mach[srm] end
    if inp.air_valid[3 - srm] then return inp.vc[3 - srm], inp.mach[3 - srm] end
    return nil
end

function M.update(s, inp, dt)
    local out = s.out

    -- ======== outboard aileron lockout
    local srm = working(inp, s.lock_srm)
    if srm and srm ~= s.lock_srm then s.lock_srm, s.lock_off_t = srm, 0 end
    local vc, mach
    if srm then vc, mach = air_data(inp, srm) end
    if vc then
        -- the FCUs' flap data lost: by speed and Mach only (p.108)
        local a_in = inp.le_a_in or not inp.le_valid
        if a_in and (vc > M.LOCK_KT or mach > M.LOCK_M) then s.locked = true
        elseif (not a_in) or (vc < M.UNLOCK_KT and mach < M.UNLOCK_M) then s.locked = false end
    elseif not inp.on_ground then
        s.locked = false            -- no lockout function in the air: unlocked (p.108)
    end
    local want = s.locked and 1 or 0
    if s.first then s.lock_pos = want end
    if not inp.lockout_stuck then s.lock_pos = toward(s.lock_pos, want, dt / M.LOCK_TRAVEL_S) end
    -- monitoring: not at the command 45 s after it, the other SRM takes it;
    -- the same there, AILERON LOCKOUT (p.110)
    if srm and s.lock_pos ~= want then
        s.lock_off_t = s.lock_off_t + dt
        if s.lock_off_t >= M.LOCK_MONITOR_S then
            local other = working(inp, 3 - s.lock_srm)
            if other and other ~= s.lock_srm and not s.lock_tried then
                s.lock_srm, s.lock_off_t, s.lock_tried = other, 0, true
            else
                s.lock_fault = true
            end
        end
    else
        s.lock_off_t = 0
        if s.lock_pos == want then s.lock_tried = false end
    end
    out.lockout = 1 - s.lock_pos
    out.aileron_lockout = s.lock_fault

    -- ======== rudder ratio changers: one SRM controls both (p.636)
    local rsrm = working(inp, 1)
    local rvc = rsrm and air_data(inp, rsrm)
    local sngl = 0
    for r = 1, 2 do
        local target = s.rrc_in[r]          -- no control: the actuator stays (FCOM p.949)
        if rsrm then
            if inp.autoland then
                target = 0                  -- autoland: full authority (p.636)
            elseif rvc then
                target = rrc_in(rvc)
            else
                target = rrc_in(M.RRC_FIXED_KT[r])
            end
        end
        if s.first then s.rrc_in[r] = target end
        local was = s.rrc_in[r]
        if not inp.rrc_stuck[r] then s.rrc_in[r] = toward(s.rrc_in[r], target, M.RRC_IN_S * dt) end
        -- servo monitor (p.646): the actuator away from its command; quiet
        -- below 160 kt (without air data it watches: estimate)
        if rsrm and math.abs(target - s.rrc_in[r]) > M.RRC_ERROR_IN and s.rrc_in[r] == was
            and (rvc == nil or rvc >= M.RRC_MONITOR_KT) then
            s.rrc_err_t[r] = s.rrc_err_t[r] + dt
            if s.rrc_err_t[r] >= M.RRC_MONITOR_S then s.rrc_fault[r] = true end
        else
            s.rrc_err_t[r] = 0
        end
        if s.rrc_fault[r] or not rsrm then sngl = sngl + 1 end
        local mx = rudder_max(s.rrc_in[r])
        out.rudder_max[r] = mx
        out.rudder_ratio[r] = mx / M.RUDDER_MAX
    end
    out.rud_ratio_dual = sngl == 2
    out.rud_ratio_sngl = sngl == 1
    out.st_rudder_ratio = sngl > 0

    s.first = false
    return out
end

return M
