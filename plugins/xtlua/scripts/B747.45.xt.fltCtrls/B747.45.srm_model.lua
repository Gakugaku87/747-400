-- 747-400 stabilizer trim / rudder ratio modules (SRM) without X-Plane:
-- the outboard aileron lockout and the upper and lower rudder ratio
-- changers (RRC), with their monitoring and messages (4-1 step 2a); the
-- stabilizer trim (step 2b): the control wheel and alternate switches, the
-- autopilots' autotrim, the two hydraulic trim control modules (STCM) with
-- their shutoff valves, cutout switches and automatic cutout, the limits,
-- rates and column cutout, and the messages. Two SRMs (L, R); one controls
-- each function, the other stands by. Logic and sources:
-- docs/overhaul/notes/ATA-27.md §4.1, §4.5, §4.8 (FCOM 9.20.4-9.20.9
-- p.944-949, p.957-958; ATA27 27-11 p.104-110, 27-41 p.450-490, p.520,
-- 27-21 p.634-648; ATA22 22-22 p.116-152).
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

-- stabilizer trim. The position in trim units 0-15, which are degrees: 0
-- units is 3 degrees leading edge up, 15 units 12 degrees down (ATA22
-- p.132), so the sources' rates in degrees per second are units per second
M.STAB_MIN, M.STAB_MAX = 0, 15
-- the two STCMs by hydraulic system: k = 1 is system 2's (right), k = 2
-- system 3's (left) (ATA27 p.462; FCOM p.946); in autotrim SRM R drives
-- system 2's, SRM L system 3's (ATA22 p.116-118)
M.STCM_SYS = {2, 3}
M.SRM_STCM = {2, 1}             -- the STCM each SRM (L, R) drives
M.CUTOUT, M.AUTO, M.ON = -1, 0, 1   -- the STAB TRIM cutout switches 2, 3 (guarded at AUTO)
-- rate (ATA27 p.452; ATA22 p.165): both modules 0.5 units/s at or below
-- 220 kt, 0.2 from 230 kt; one module half that; no rate control: slow
M.RATE_FAST, M.RATE_SLOW = 0.5, 0.2
M.RATE_FAST_KT, M.RATE_SLOW_KT = 220, 230
-- limits (ATA27 p.483, p.490, p.520; ATA22 p.131): electric nose down 1.8,
-- 0.8 with the gear down or the LE flaps out (or in speed trim); nose up
-- 11.6, 13.5 in full-rate autotrim; the alternate trim 0.25 to 14.75
M.LIM_ND, M.LIM_ND_EXT = 1.8, 0.8
M.LIM_NU, M.LIM_NU_FRAT = 11.6, 13.5
M.ALTN_ND, M.ALTN_NU = 0.25, 14.75
-- speed trim (step 2c; ATA27 p.486; ATA22 p.155-159): one SRM, half rate,
-- 20 s after liftoff, at or below 220 kt, out of manual, alternate and
-- autotrim; it moves the stabilizer nose up as the speed rises, 2.55 units
-- from 120 to 220 kt (the p.159 control law), from the speed and position
-- it synchronized to when it engaged. The two air data sources more than
-- 10 kt apart: not valid (p.155)
M.SPEED_TRIM_KT = {120, 220}
M.SPEED_TRIM_UNITS = 2.55
M.SPEED_TRIM_AIR_S = 20
M.ADC_COMPARE_KT = 10
M.AUTOTRIM_DELAY_S = 3.5        -- an FCC command held this long before the SRM trims (ATA27 p.488)
M.AUTO_OPEN_S = 5               -- a cutout switch at AUTO this long opens its valve (ATA27 p.450)
M.UNSCHD_HOLD_S = 30            -- STAB TRIM UNSCHD after the stabilizer stops (ATA27 p.458)
-- estimates (no values in the sources)
M.STCM_MIN_PSI = 1000           -- the pressure that releases a module's brake
M.UNSCHD_UNITS = 0.1            -- uncommanded movement the unscheduled trim monitor detects
M.DEAD_TRIM_S = 2               -- an autotrim command with the stabilizer still: dead trim (ATA22 p.148)
M.SPEED_TRIM_START = 0.05       -- speed trim drives once the stabilizer is this far from its command
-- the column cutout: 4.5 degrees of the column (ATA27 p.476) as a part of
-- its travel (6.55 in forward, 6.63 in aft: p.536; the column's length is
-- not in the sources)
M.COLUMN_CUTOUT = 0.35

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
        -- stabilizer trim
        trim_capt = 0, trim_fo = 0,     -- the control wheel switch pairs: -1 nose down, 0, 1 nose up
        altn = 0,                       -- the ALTERNATE STAB TRIM switches
        cutout = two(M.AUTO),           -- the cutout switches 2, 3
        hyd_psi = two(0),               -- hydraulic systems 2, 3
        stcm_fail = two(false),         -- a module does not drive (its brake stays on)
        runaway = two(0),               -- a module drives by itself: -1 nose down, 1 nose up
        column = 0,                     -- the control column: -1 forward .. 1 aft
        ap_l = false, ap_c = false, ap_r = false,   -- the autopilots in CMD
        autotrim_cmd = 0,               -- the FCCs' trim command: -1, 0, 1
        frat_req = false,               -- the FCC's full-rate autotrim (LAND 2 below 120 ft)
        gear_down = false,
        le_up = true,                   -- all leading edge flaps retracted
        srm_pwr = two(true),            -- an SRM's stabilizer functions powered
        manual_pwr = true,              -- the wheel switches' power (DC 3)
        altn_pwr = true,                -- the alternate switches' power (battery bus)
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
        -- stabilizer trim
        stab = 7.5,                     -- units
        mov_open = two(true),           -- the STCMs' shutoff valves (normally open)
        auto_closed = two(false),       -- closed by the automatic cutout
        sw_prev = two(M.AUTO), sw_t = two(0),   -- the cutout switches, time at the position
        adv_latch = two(false),         -- >STAB TRIM 2, 3 latched
        hyd_low = two(false),
        rate_fast = true,
        at_srm = nil,                   -- the SRM in autotrim
        at_dir = 0, at_t = 0,           -- the FCCs' command and how long it has held
        autoseq = false,                -- the autotrim path has been transferred once
        dead_t = 0,
        unsched = 0,                    -- uncommanded movement so far
        unschd_on = false, unschd_t = 0,
        st_stab_trim = false, st_unschd = false, st_auto_trim = false,
        disc_sent = false,
        air_t = 0,                      -- time in the air
        sp_srm = nil,                   -- the SRM selected for speed trim
        sp_on = false,                  -- speed trim engaged
        sp_stab, sp_vc = 0, 0,          -- the position and speed it synchronized to
        sp_dir = 0,                     -- driving: -1, 0, 1
    }
    s.out = {
        lockout = 1,                    -- the outboard ailerons' authority: 1 unlocked .. 0 locked
        rudder_ratio = two(1),          -- the rudders' authority through the RRCs (1 = 32 degrees)
        rudder_max = two(M.RUDDER_MAX),
        aileron_lockout = false,        -- advisory AILERON LOCKOUT (and STATUS)
        rud_ratio_sngl = false, rud_ratio_dual = false,     -- advisories RUD RATIO SNGL, DUAL
        st_rudder_ratio = false,        -- STATUS RUDDER RATIO
        -- stabilizer trim
        stab_units = 7.5,
        stab_rate = 0,                  -- units per second (+ nose up)
        mov_open = two(true),
        stab_trim = two(false),         -- advisories >STAB TRIM 2, 3
        st_stab_trim = false,           -- STATUS STAB TRIM
        unschd = false,                 -- caution STAB TRIM UNSCHD
        st_unschd = false,              -- STATUS STAB TRIM UNSCHD
        st_auto_trim = false,           -- STATUS STAB AUTO TRIM
        speed_trim = false,             -- speed trim engaged
        st_speed_trim = false,          -- STATUS STAB SPEED TRIM
        ap_disengage = false,           -- this frame: disengage the single autopilot
    }
    return s
end

-- put the stabilizer where X-Plane has it (the flight's start, a trim
-- axis, a test): not a movement the monitor sees, and speed trim
-- synchronizes to it again
function M.stab_set(s, units)
    if units < M.STAB_MIN then units = M.STAB_MIN elseif units > M.STAB_MAX then units = M.STAB_MAX end
    if units ~= s.stab then s.sp_on, s.sp_dir = false, 0 end
    s.stab = units
    s.out.stab_units = units
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

local function sign(x)
    if x > 0 then return 1 elseif x < 0 then return -1 end
    return 0
end

-- the captain's and F/O's switch pairs: either, or both the same way;
-- held opposite, no trim (FCOM p.944)
local function wheel(a, b)
    if a == 0 then return b end
    if b == 0 or b == a then return a end
    return 0
end

local function stab_update(s, inp, dt, out)
    local sv = {not inp.srm_fail[1] and inp.srm_pwr[1], not inp.srm_fail[2] and inp.srm_pwr[2]}

    -- the cutout switches and the STCMs' shutoff valves (ATA27 p.450; FCOM
    -- p.945): CUTOUT closes; ON opens and overrides the automatic cutout;
    -- AUTO for 5 s opens, unless the automatic cutout has closed the valve
    -- (then only after ON or CUTOUT). The system's pressure back after low,
    -- the auto open command and ON clear >STAB TRIM (p.456)
    for k = 1, 2 do
        local sw = inp.cutout[k]
        if sw ~= s.sw_prev[k] then s.sw_t[k] = 0 end
        s.sw_prev[k] = sw
        if sw == M.CUTOUT then
            s.mov_open[k], s.auto_closed[k] = false, false
        elseif sw == M.ON then
            s.mov_open[k], s.auto_closed[k], s.adv_latch[k] = true, false, false
        else
            s.sw_t[k] = s.sw_t[k] + dt
            if s.sw_t[k] >= M.AUTO_OPEN_S and not s.auto_closed[k] and not s.mov_open[k] then
                s.mov_open[k], s.adv_latch[k] = true, false
            end
        end
        local low = inp.hyd_psi[k] < M.STCM_MIN_PSI
        if s.hyd_low[k] and not low then s.adv_latch[k] = false end
        s.hyd_low[k] = low
    end

    -- the rate solenoids: one SRM, from its air data (ATA27 p.452)
    local rs = (sv[1] and 1) or (sv[2] and 2)
    local vc = rs and air_data(inp, rs)
    if not vc then s.rate_fast = false
    elseif vc <= M.RATE_FAST_KT then s.rate_fast = true
    elseif vc >= M.RATE_SLOW_KT then s.rate_fast = false end
    local half = (s.rate_fast and M.RATE_FAST or M.RATE_SLOW) / 2     -- one module

    -- the switches; the wheel switches against the alternate: no trim (FCOM p.944)
    local m = inp.manual_pwr and wheel(inp.trim_capt, inp.trim_fo) or 0
    local a = inp.altn_pwr and inp.altn or 0
    if m ~= 0 and a ~= 0 and m ~= a then m, a = 0, 0 end
    -- the autopilots (FCOM p.945; ATA22 p.139, p.142): two or more inhibit
    -- the wheel switches; they disengage a single one
    local aps = (inp.ap_l and 1 or 0) + (inp.ap_c and 1 or 0) + (inp.ap_r and 1 or 0)
    if aps >= 2 then m = 0 end
    out.ap_disengage = false
    if m ~= 0 and aps == 1 then
        if not s.disc_sent then out.ap_disengage, s.disc_sent = true, true end
    else
        s.disc_sent = false
    end
    local manual = m ~= 0

    -- autotrim (ATA27 p.488; ATA22 p.142-152): an engaged FCC's SRM (L FCC:
    -- SRM L, R: R, C: either) trims at half rate through its own module once
    -- the command has held 3.5 s (no delay in autoland); full-rate autotrim
    -- through both SRMs without the delay. Dead trim moves the path to the
    -- other SRM once; all autopilots off resets that
    if aps == 0 then s.at_srm, s.autoseq, s.st_auto_trim = nil, false, false end
    local function reaches(i)
        return sv[i] and (inp.ap_c or (i == 1 and inp.ap_l) or (i == 2 and inp.ap_r))
    end
    if s.at_srm and not reaches(s.at_srm) then s.at_srm = nil end
    if aps > 0 and not s.at_srm then
        if reaches(1) then s.at_srm = 1 elseif reaches(2) then s.at_srm = 2 end
    end
    local frat = inp.frat_req and aps > 0 and sv[1] and sv[2]
    local acmd = ((s.at_srm or frat) and not manual) and inp.autotrim_cmd or 0
    if acmd ~= 0 and acmd == s.at_dir then s.at_t = s.at_t + dt else s.at_t = 0 end
    s.at_dir = acmd
    local at_go = acmd ~= 0 and (frat or inp.autoland or s.at_t >= M.AUTOTRIM_DELAY_S)

    -- speed trim (ATA22 p.155-159; ATA27 p.486). An SRM may have it with its
    -- own side's air data, or the other side's when the other SRM is not
    -- valid; the sides more than 10 kt apart: neither. The selected SRM
    -- keeps it while it can, then the other takes it. Manual or alternate
    -- trim, autotrim, the column cutout switches (the column past them
    -- either way) and the ground disengage it; it synchronizes again when it
    -- engages
    if inp.on_ground then s.air_t = 0 else s.air_t = s.air_t + dt end
    local compare_ok = not (inp.air_valid[1] and inp.air_valid[2]) or math.abs(inp.vc[1] - inp.vc[2]) <= M.ADC_COMPARE_KT
    local function sp_vc(i)
        if not sv[i] or not compare_ok then return nil end
        if inp.air_valid[i] then return inp.vc[i] end
        if inp.air_valid[3 - i] and not sv[3 - i] then return inp.vc[3 - i] end
        return nil
    end
    if not (s.sp_srm and sp_vc(s.sp_srm)) then s.sp_srm = (sp_vc(1) and 1) or (sp_vc(2) and 2) or nil end
    local spv = s.sp_srm and sp_vc(s.sp_srm)
    if spv and not inp.on_ground and s.air_t >= M.SPEED_TRIM_AIR_S and not manual and a == 0
            and not (s.at_srm or frat) and spv <= M.SPEED_TRIM_KT[2] and math.abs(inp.column) < M.COLUMN_CUTOUT then
        if not s.sp_on then s.sp_on, s.sp_stab, s.sp_vc, s.sp_dir = true, s.stab, spv, 0 end
        local function gain(v)      -- the p.159 control law: units nose up
            local lo, hi = M.SPEED_TRIM_KT[1], M.SPEED_TRIM_KT[2]
            if v <= lo then return 0 elseif v >= hi then return M.SPEED_TRIM_UNITS end
            return M.SPEED_TRIM_UNITS * (v - lo) / (hi - lo)
        end
        local err = s.sp_stab + gain(spv) - gain(s.sp_vc) - s.stab
        if s.sp_dir ~= 0 then
            if err * s.sp_dir <= 0 then s.sp_dir = 0 end
        elseif math.abs(err) > M.SPEED_TRIM_START then
            s.sp_dir = sign(err)
        end
    else
        s.sp_on, s.sp_dir = false, 0
    end

    -- the commands to the modules, within the mode's limits; the column
    -- against an electric command cuts it out (ATA27 p.476, p.483)
    local nd = (inp.gear_down or not inp.le_up or s.sp_on) and M.LIM_ND_EXT or M.LIM_ND
    local nu = frat and M.LIM_NU_FRAT or M.LIM_NU
    local function free(dir, lo, hi)
        return (dir > 0 and s.stab < hi) or (dir < 0 and s.stab > lo)
    end
    local function cut(dir)
        return (dir < 0 and inp.column >= M.COLUMN_CUTOUT) or (dir > 0 and inp.column <= -M.COLUMN_CUTOUT)
    end
    local cmd, lo, hi = {0, 0}, M.STAB_MIN, M.STAB_MAX
    local want = 0                  -- a valid command's direction (the unscheduled trim monitor)
    if a ~= 0 then
        -- ALTN: straight to both modules' alternate coils, its own limit
        -- switches, no column cutout; over the autopilots (p.490; FCOM p.945)
        lo, hi, want = M.ALTN_ND, M.ALTN_NU, a
        if free(a, lo, hi) then cmd[1], cmd[2] = a, a end
    elseif manual then
        lo, hi, want = nd, nu, m
        if free(m, lo, hi) and not cut(m) then cmd[1], cmd[2] = m, m end
    elseif at_go then
        lo, hi, want = nd, nu, acmd
        if free(acmd, lo, hi) and not cut(acmd) then
            if frat then cmd[1], cmd[2] = acmd, acmd else cmd[M.SRM_STCM[s.at_srm]] = acmd end
        end
    elseif s.sp_dir ~= 0 then
        lo, hi, want = nd, nu, s.sp_dir      -- speed trim: the selected SRM's module, half rate
        if free(s.sp_dir, lo, hi) and not cut(s.sp_dir) then cmd[M.SRM_STCM[s.sp_srm]] = s.sp_dir end
    end

    -- the modules: a brake released (valve open, pressure, a command or a
    -- runaway) drives at half the rate; the outputs sum (FCOM p.944; ATA27 p.470)
    local rate, released, runaway = 0, {false, false}, false
    for k = 1, 2 do
        local d = cmd[k]
        if inp.runaway[k] ~= 0 then d, runaway = inp.runaway[k], true end
        released[k] = d ~= 0 and s.mov_open[k] and inp.hyd_psi[k] >= M.STCM_MIN_PSI and not inp.stcm_fail[k]
        if released[k] then rate = rate + d * half end
    end
    local prev = s.stab
    local x = prev + rate * dt
    if not runaway then             -- the limit switches stop a commanded move at the limit
        if rate > 0 and x > hi and prev <= hi then x = hi elseif rate < 0 and x < lo and prev >= lo then x = lo end
    end
    if x < M.STAB_MIN then x = M.STAB_MIN elseif x > M.STAB_MAX then x = M.STAB_MAX end
    s.stab = x
    local mv = x - prev
    local moving = math.abs(mv) > 1e-9

    -- >STAB TRIM 2, 3 (ATA27 p.455-456; FCOM p.958): half rate on a valid
    -- manual command (one module's brake released, the other's not) latches
    -- the other's; full rate on a manual command clears both
    if manual and cmd[1] ~= 0 then
        if released[1] and released[2] then
            s.adv_latch[1], s.adv_latch[2] = false, false
        elseif released[1] ~= released[2] then
            s.adv_latch[released[1] and 2 or 1] = true
        end
    end

    -- the unscheduled trim monitor (ATA27 p.450, p.458): out of manual and
    -- alternate trim, the stabilizer moving without a valid command or away
    -- from it. Each module whose brake is released and whose switch is at
    -- AUTO is cut out (>STAB TRIM); none: STAB TRIM UNSCHD until 30 s after
    -- the stabilizer stops, its STATUS latched. The alternate switches moving
    -- the stabilizer with an autopilot engaged: STAB TRIM UNSCHD (FCOM p.958)
    local uncommanded = moving and not manual and a == 0 and sign(mv) ~= want
    if uncommanded then s.unsched = s.unsched + math.abs(mv) else s.unsched = 0 end
    if s.unsched >= M.UNSCHD_UNITS then
        local shut = false
        for k = 1, 2 do
            if released[k] and inp.cutout[k] == M.AUTO and s.mov_open[k] then
                s.mov_open[k], s.auto_closed[k], s.adv_latch[k], shut = false, true, true, true
            end
        end
        if shut then s.unsched = 0 else s.unschd_on = true end
    end
    local altn_ap = moving and a ~= 0 and aps > 0
    if altn_ap then s.unschd_on = true end
    if s.unschd_on then
        s.st_unschd = true
        if (uncommanded and s.unsched >= M.UNSCHD_UNITS) or altn_ap then
            s.unschd_t = M.UNSCHD_HOLD_S
        else
            s.unschd_t = s.unschd_t - dt
            if s.unschd_t <= 0 then s.unschd_on, s.unschd_t = false, 0 end
        end
    end

    -- dead trim (ATA22 p.148, p.152): autotrim driving a module and the
    -- stabilizer still: STAB AUTO TRIM (ATA27 p.523), and the path moves to
    -- the other SRM once
    if at_go and not frat and (cmd[1] ~= 0 or cmd[2] ~= 0) and not moving then
        s.dead_t = s.dead_t + dt
        if s.dead_t >= M.DEAD_TRIM_S then
            s.dead_t, s.st_auto_trim = 0, true
            local other = 3 - s.at_srm
            if not s.autoseq and reaches(other) then s.at_srm, s.autoseq = other, true end
        end
    else
        s.dead_t = 0
    end

    for k = 1, 2 do
        out.stab_trim[k] = s.adv_latch[k] or not s.mov_open[k]
        out.mov_open[k] = s.mov_open[k]
        if s.adv_latch[k] then s.st_stab_trim = true end
    end
    out.st_stab_trim = s.st_stab_trim or out.stab_trim[1] or out.stab_trim[2]
    out.unschd, out.st_unschd = s.unschd_on, s.st_unschd
    out.st_auto_trim = s.st_auto_trim
    out.speed_trim = s.sp_on
    out.st_speed_trim = not sp_vc(1) and not sp_vc(2)     -- lost in both SRMs (ATA27 p.486, p.523)
    out.stab_units = s.stab
    out.stab_rate = dt > 0 and mv / dt or 0
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

    -- ======== stabilizer trim
    stab_update(s, inp, dt, out)

    s.first = false
    return out
end

return M
