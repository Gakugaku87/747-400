-- The clocks (5-2 step 6a, GAP DSP-33). Logic and sources:
-- docs/overhaul/notes/ATA-31.md §35.
--  - Power: the time base on the main hot battery bus; the displays, the
--    digital output and the sweep second hand's stepping motor need the
--    APU battery bus too. Without the APU battery bus the time and date go
--    blank and the clock runs on; without the main hot battery bus it
--    stops and must be set again (ATA31 p.64, p.74; FCOM p.1075).
--  - Power applied again (the main hot battery bus): no computed data, both
--    LCDs holding zeros (00:00) and the sweep hand at 60, until the UTC is
--    set, advanced a digit with the SET selector past HLD Y (ATA31 p.66,
--    p.77, p.80).
--  - The upper LCD: UTC, 00:00 to 23:59; DATE: the day and month, then the
--    year, a second each, without the colon; DATE again: UTC (ATA31 p.66;
--    FCOM p.1058).
--  - SET: RUN; HLD Y: the time stands, its seconds zeroed (the date shown:
--    the years advance); MS M: the minutes (the months) advance one a
--    second; HS D: the hours (the days) (ATA31 p.66-67; FCOM p.1059).
--  - ET: RUN accumulates from the last hold or reset, HLD holds, RESET
--    (spring-loaded to HLD) zeroes it; 00:00 to 99:59 (hours, minutes),
--    blank while zero (ATA31 p.67-68; FCOM p.1058).
--  - CHR (the clock's switch and the glareshield's, in parallel): start,
--    hold, reset; the minutes on the lower LCD's two right digits, the
--    seconds on the sweep hand, 00:00 to 99:59; it replaces the ET display
--    from the start to the reset, the ET running on behind it (ATA31 p.68,
--    p.70; FCOM p.1058).
-- Estimates: the clock's UTC is X-Plane's plus an offset that HLD and the
-- slews change; a slew steps once a second from a second after the
-- selector gets there and carries into no other field (59 minutes to 00,
-- 23 hours to 00, the month's last day to 1, a day past the new month's
-- end to its last, the year 99 to 00); the time stands while MS or HS is
-- selected with the time shown, and runs while the date is shown; with no
-- computed data the date is 1 January 2000, the ET and the chronograph do
-- not run and DATE and CHR do nothing; ET and CHR stop at 99:59; the sweep
-- hand stands without the APU battery bus.
-- Pure functions: the clock glue (B747.60.xt.fltInst03.lua) runs them.
--   local CM = B747_clock_model             -- in XTLua, after dofile
--   local CM = dofile(".../B747.60.clock_model.lua")  -- in the tests
local M = setmetatable({}, {})
B747_clock_model = M

-- the SET selector (clock_set_sel_pos): RUN, HLD Y, MS M, HS D; the ET
-- selector (clock_et_sel_pos): HLD, RUN, RESET
M.SET_RUN, M.SET_HLD, M.SET_MS, M.SET_HS = 0, 1, 2, 3
M.ET_HLD, M.ET_RUN, M.ET_RESET = 0, 1, 2
-- the chronograph: reset, running, held
M.CHR_RESET, M.CHR_RUN, M.CHR_HOLD = 0, 1, 2
M.ET_MAX = 99 * 3600 + 59 * 60 + 59
M.CHR_MAX = 99 * 60 + 59
M.SLEW_S, M.DATE_S = 1, 1
M.DAY = 86400
-- no computed data after a main hot battery loss: 00:00, 1 January 2000
M.RESET_YEAR = 2000

local floor = math.floor

-- days since 1 January 1970 of a date of the Gregorian calendar, and back
-- (H. Hinnant's days_from_civil and civil_from_days)
function M.days(y, m, d)
    if m <= 2 then y = y - 1 end
    local era = floor(y / 400)
    local yoe = y - era * 400
    local doy = floor((153 * ((m + 9) % 12) + 2) / 5) + d - 1
    local doe = yoe * 365 + floor(yoe / 4) - floor(yoe / 100) + doy
    return era * 146097 + doe - 719468
end

function M.civil(z)
    z = z + 719468
    local era = floor(z / 146097)
    local doe = z - era * 146097
    local yoe = floor((doe - floor(doe / 1460) + floor(doe / 36524) - floor(doe / 146096)) / 365)
    local doy = doe - (365 * yoe + floor(yoe / 4) - floor(yoe / 100))
    local mp = floor((5 * doy + 2) / 153)
    local d = doy - floor((153 * mp + 2) / 5) + 1
    local m = mp < 10 and mp + 3 or mp - 9
    local y = yoe + era * 400
    if m <= 2 then y = y + 1 end
    return y, m, d
end

function M.month_days(y, m)
    if m == 12 then return 31 end
    return M.days(y, m + 1, 1) - M.days(y, m, 1)
end

-- X-Plane's UTC in seconds since 1970 (its date has no year: the glue's)
function M.utc(y, m, d, sec)
    return M.days(y, m, d) * M.DAY + sec
end

function M.new()
    return {alive = nil, offset = 0, held = nil, ncd = false,
        date = false, date_t = 0, slew_pos = M.SET_RUN, slew_t = 0,
        et = 0, chr = 0, chr_mode = M.CHR_RESET, hand = 0,
        out = {on = false, hours = 0, minutes = 0, utc_display = 0, date_mode = 0,
            day = 1, month = 1, year = 0, et_show = false, et_hours = 0, et_minutes = 0,
            et_seconds = 0, et_chr = 0, chr_minutes = 0, chr_seconds = 0}}
end

-- the CHR switch (either of the two): start, hold, reset
function M.chr_push(s)
    if not s.alive or s.ncd then return end
    if s.chr_mode == M.CHR_RESET then
        s.chr_mode = M.CHR_RUN
    elseif s.chr_mode == M.CHR_RUN then
        s.chr_mode = M.CHR_HOLD
    else
        s.chr_mode, s.chr = M.CHR_RESET, 0
    end
end

-- the DATE switch: the date, then the time again
function M.date_push(s)
    if not s.alive or s.ncd then return end
    s.date, s.date_t = not s.date, 0
end

-- the ET selector to RESET (back at HLD before the next frame)
function M.et_reset(s)
    if s.alive then s.et = 0 end
end

-- a slew's step: the held time's minutes or hours (the UTC set: computed
-- data again), or the date's day, month or year, each field on its own
local function slew(s, pos, utc)
    if not s.date then
        local tod = s.held % M.DAY
        if pos == M.SET_MS then
            s.held = s.held + (floor(tod / 60) % 60 == 59 and -59 * 60 or 60)
        elseif pos == M.SET_HS then
            s.held = s.held + (floor(tod / 3600) == 23 and -23 * 3600 or 3600)
        end
        s.ncd = false
        return
    end
    local z = floor((utc + s.offset) / M.DAY)
    local y, m, d = M.civil(z)
    if pos == M.SET_HS then
        d = d % M.month_days(y, m) + 1
    elseif pos == M.SET_MS then
        m = m % 12 + 1
        d = math.min(d, M.month_days(y, m))
    else
        y = M.RESET_YEAR + (y - M.RESET_YEAR + 1) % 100
        d = math.min(d, M.month_days(y, m))
    end
    s.offset = s.offset + (M.days(y, m, d) - z) * M.DAY
end

-- inp: utc (X-Plane's, M.utc), hot (the main hot battery bus), apu (the
-- APU battery bus), set, et_sel (the selectors); dt: the seconds since the
-- last update
function M.update(s, inp, dt)
    dt = dt or 0
    local o = s.out
    if not inp.hot then
        if s.alive then s.alive = false end
        o.on = false
        return o
    end
    if s.alive == false then
        -- power again: no computed data, the time standing at 00:00
        s.held, s.ncd, s.date, s.date_t = M.days(M.RESET_YEAR, 1, 1) * M.DAY, true, false, 0
        s.et, s.chr, s.chr_mode, s.hand = 0, 0, M.CHR_RESET, 0
    end
    s.alive = true
    local set = inp.set
    -- the time stands at HLD, MS or HS with the time shown, its seconds
    -- zeroed, and with no computed data; at RUN it runs on from there
    if s.ncd or (not s.date and set ~= M.SET_RUN) then
        if not s.held then
            local t = inp.utc + s.offset
            s.held = t - t % 60
        end
    elseif s.held then
        s.offset, s.held = s.held - inp.utc, nil
    end
    if set ~= s.slew_pos then s.slew_pos, s.slew_t = set, 0 end
    if set == M.SET_MS or set == M.SET_HS or (set == M.SET_HLD and s.date) then
        s.slew_t = s.slew_t + dt
        while s.slew_t >= M.SLEW_S do
            s.slew_t = s.slew_t - M.SLEW_S
            slew(s, set, inp.utc)
        end
    else
        s.slew_t = 0
    end
    local t = s.held or (inp.utc + s.offset)
    local z = floor(t / M.DAY)
    local tod = t - z * M.DAY
    o.hours, o.minutes = floor(tod / 3600), floor(tod % 3600 / 60)
    local y, m, d = M.civil(z)
    o.year, o.month, o.day = y % 100, m, d
    if inp.et_sel == M.ET_RESET then
        s.et = 0
    elseif inp.et_sel == M.ET_RUN and not s.ncd then
        s.et = math.min(M.ET_MAX, s.et + dt)
    end
    if s.chr_mode == M.CHR_RUN then s.chr = math.min(M.CHR_MAX, s.chr + dt) end
    if s.date then s.date_t = s.date_t + dt end
    o.on = inp.apu and true or false
    o.utc_display = s.date and 1 or 0
    -- the date: the day and month, then the year, a second each
    o.date_mode = (s.date and floor(s.date_t / M.DATE_S) % 2 == 1) and 1 or 0
    o.et_chr = s.chr_mode == M.CHR_RESET and 0 or 1
    o.et_show = o.et_chr == 0 and (s.et > 0 or s.ncd)
    o.et_seconds = s.et
    o.et_hours, o.et_minutes = floor(s.et / 3600), floor(s.et % 3600 / 60)
    o.chr_minutes = floor(s.chr / 60)
    -- the sweep hand: the chronograph's seconds; it stands without the APU
    -- battery bus
    if inp.apu then s.hand = s.chr % 60 end
    o.chr_seconds = s.hand
    return o
end

return M
