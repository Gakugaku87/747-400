-- Run from the repository root with LuaJIT: luajit tests/displays/clock_test.lua
-- The clocks (5-2 step 6a, GAP DSP-33; ATA31 p.64-74, FCOM p.1057-1059,
-- p.1075): the clock model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.clock_model.lua: the date, UTC on X-Plane's,
-- SET's hold and slews, DATE, ET, CHR, the power), then the clock glue in
-- the flight instruments module as XTLua runs it (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("clock")
local CM = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.clock_model.lua")
local xtlua = dofile("tests/lib/xtlua.lua")

-- the calendar
T.equal(CM.days(1970, 1, 1), 0, "1 January 1970: day 0")
T.equal(CM.days(2000, 1, 1), 10957, "1 January 2000: day 10,957")
local ok = true
for z = CM.days(1999, 12, 1), CM.days(2101, 3, 1), 13 do
    local y, m, d = CM.civil(z)
    if CM.days(y, m, d) ~= z or d < 1 or d > CM.month_days(y, m) then ok = false end
end
T.check(ok, "days and dates both ways, 1999 to 2101")
T.check(CM.month_days(2024, 2) == 29 and CM.month_days(2026, 2) == 28 and CM.month_days(2100, 2) == 28
    and CM.month_days(2026, 12) == 31 and CM.month_days(2026, 4) == 30, "the months' lengths (leap years)")

-- a clock on X-Plane's UTC: 26 October 2026, 12:34:56
local utc0 = CM.utc(2026, 10, 26, 12 * 3600 + 34 * 60 + 56)
local inp = {utc = utc0, hot = true, apu = true, set = CM.SET_RUN, et_sel = CM.ET_HLD}
local s = CM.new()
local o
local function run(seconds, step)
    step = step or 0.5
    for _ = 1, math.floor(seconds / step + 0.5) do
        inp.utc = inp.utc + step
        o = CM.update(s, inp, step)
    end
end
o = CM.update(s, inp, 0)
T.check(o.on and o.hours == 12 and o.minutes == 34 and o.day == 26 and o.month == 10 and o.year == 26,
    "powered: X-Plane's UTC and date (12:34, 26 10 26)")
T.check(o.utc_display == 0 and not o.et_show and o.et_chr == 0, "UTC shown, the ET blank at zero")
run(4)
T.equal(o.minutes, 35, "runs with X-Plane's UTC")

-- DATE: the day and month, then the year, a second each
CM.date_push(s)
run(0.5)
T.check(o.utc_display == 1 and o.date_mode == 0, "DATE: the day and month first")
run(1)
T.equal(o.date_mode, 1, "then the year")
run(1)
T.equal(o.date_mode, 0, "then the day and month again")
CM.date_push(s)
run(0.5)
T.equal(o.utc_display, 0, "DATE again: the time")

-- SET: HLD stands with the seconds zeroed, RUN runs on from there
inp.utc = utc0
s = CM.new()
o = CM.update(s, inp, 0)
inp.set = CM.SET_HLD
run(120)
T.check(o.hours == 12 and o.minutes == 34, "HLD: the time stands (12:34 two minutes on)")
inp.set = CM.SET_RUN
run(59.5)
T.equal(o.minutes, 34, "RUN: from 12:34:00")
run(1)
T.equal(o.minutes, 35, "a minute later 12:35")
-- the slews: one a second, from a second after the selector gets there
inp.set = CM.SET_MS
run(0.5)
T.equal(o.minutes, 35, "MS: nothing in the first second (the time stands)")
run(3)
T.equal(o.minutes, 38, "MS: three minutes in three seconds")
inp.set = CM.SET_HS
run(2)
T.check(o.hours == 14 and o.minutes == 38, "HS: two hours in two seconds")
inp.set = CM.SET_MS
run(22)
T.check(o.hours == 14 and o.minutes == 0, "minutes 59 to 00 without the hour (estimate)")
inp.set = CM.SET_HS
run(10)
T.check(o.hours == 0 and o.day == 26, "hours 23 to 00 without the day (estimate)")
inp.set = CM.SET_HLD
run(5)
T.check(o.hours == 0 and o.minutes == 0, "back at HLD: stands")
inp.set = CM.SET_RUN
run(61)
T.equal(o.minutes, 1, "RUN again")

-- the date's slews (the date shown): HS D days, MS M months, HLD Y years
inp.utc = CM.utc(2026, 10, 30, 6 * 3600)
s = CM.new()
o = CM.update(s, inp, 0)
CM.date_push(s)
inp.set = CM.SET_HS
run(1)
T.equal(o.day, 31, "D: a day a second")
run(1)
T.check(o.day == 1 and o.month == 10, "the month's last day to 1, the month kept (estimate)")
inp.set = CM.SET_MS
run(3)
T.check(o.month == 1 and o.year == 26, "M: months, 12 to 1 with the year kept")
inp.set = CM.SET_HLD
run(2)
T.check(o.year == 28 and o.month == 1, "Y: a year a second")
T.check(o.hours == 6 and o.minutes == 0, "the time runs while the date is shown")
inp.set = CM.SET_RUN
inp.utc = CM.utc(2026, 1, 31, 0)
s = CM.new()
o = CM.update(s, inp, 0)
CM.date_push(s)
inp.set = CM.SET_MS
run(1)
T.check(o.month == 2 and o.day == 28, "31 January to February: its last day (estimate)")
inp.set = CM.SET_RUN
inp.utc = CM.utc(2099, 6, 1, 0)
s = CM.new()
o = CM.update(s, inp, 0)
CM.date_push(s)
inp.set = CM.SET_HLD
run(1)
T.check(o.year == 0 and o.month == 6, "the year 99 to 00")
inp.set = CM.SET_RUN

-- ET: RUN, HLD, RESET; blank while zero; 99:59 at most
inp.utc = utc0
s = CM.new()
inp.et_sel = CM.ET_RUN
run(90)
T.check(o.et_show and o.et_hours == 0 and o.et_minutes == 1 and o.et_seconds == 90, "ET RUN: 00:01 after 90 s")
inp.et_sel = CM.ET_HLD
run(60)
T.equal(o.et_minutes, 1, "HLD: holds")
inp.et_sel = CM.ET_RUN
run(30)
T.equal(o.et_minutes, 2, "RUN: on from the hold")
inp.et_sel = CM.ET_RESET
run(0.5)
T.check(o.et_seconds == 0 and not o.et_show, "RESET: zero and blank")
inp.et_sel = CM.ET_HLD
inp.et_sel = CM.ET_RUN
run(10)
CM.et_reset(s)
inp.et_sel = CM.ET_HLD
run(0.5)
T.check(o.et_seconds == 0 and not o.et_show, "RESET's spring-back within a frame: zero")
s.et = CM.ET_MAX - 30
inp.et_sel = CM.ET_RUN
run(60)
T.check(o.et_hours == 99 and o.et_minutes == 59 and o.et_seconds == CM.ET_MAX, "the ET stops at 99:59")
inp.et_sel = CM.ET_HLD

-- CHR: start, hold, reset; over the ET, the ET running on behind it
s = CM.new()
o = CM.update(s, inp, 0)
inp.et_sel = CM.ET_RUN
run(30)
CM.chr_push(s)
run(75)
T.check(o.et_chr == 1 and not o.et_show, "CHR: replaces the ET")
T.check(o.chr_minutes == 1 and math.abs(o.chr_seconds - 15) < 1e-9, "1 minute on the LCD, 15 s on the sweep hand")
CM.chr_push(s)
run(10)
T.check(o.chr_minutes == 1 and math.abs(o.chr_seconds - 15) < 1e-9 and o.et_chr == 1, "the second push holds it, still shown")
CM.chr_push(s)
run(0.5)
T.check(o.et_chr == 0 and o.chr_minutes == 0 and o.chr_seconds == 0, "the third resets it, the hand at 60")
T.check(o.et_show and o.et_minutes == 1 and math.abs(o.et_seconds - 115.5) < 1e-9, "the ET ran on behind it (1 minute 55 s)")
inp.et_sel = CM.ET_HLD
CM.chr_push(s)
s.chr = CM.CHR_MAX - 10
run(30)
T.check(o.chr_minutes == 99 and math.abs(o.chr_seconds - 59) < 1e-9, "the chronograph stops at 99:59")

-- the power: the APU battery bus for the displays and the hand, the main
-- hot battery bus for everything
inp.utc = utc0
s = CM.new()
o = CM.update(s, inp, 0)
CM.chr_push(s)
run(10)
inp.apu = false
run(30)
T.check(not o.on and math.abs(o.chr_seconds - 10) < 1e-9, "no APU battery bus: blank, the hand stands")
inp.apu = true
run(0.5)
T.check(o.on and o.minutes == 35 and math.abs(o.chr_seconds - 40.5) < 1e-9, "back: the clock and the chronograph ran on")
inp.hot = false
run(5)
T.check(not o.on, "no main hot battery bus: everything stops")
CM.date_push(s)
CM.chr_push(s)
inp.hot = true
run(0.5)
T.check(o.on and o.hours == 0 and o.minutes == 0 and o.day == 1 and o.month == 1 and o.year == 0,
    "power again: 00:00, 1 1 00, to be set again (estimate: the date)")
T.check(o.et_show and o.et_hours == 0 and o.et_minutes == 0 and o.et_chr == 0 and o.chr_seconds == 0,
    "all zeros, the sweep hand at 60")
T.check(o.utc_display == 0, "switches without power do nothing")
inp.et_sel = CM.ET_RUN
run(60)
CM.date_push(s)
CM.chr_push(s)
run(0.5)
T.check(o.hours == 0 and o.minutes == 0 and o.et_show and o.et_seconds == 0 and o.utc_display == 0 and o.et_chr == 0,
    "no computed data: zeros held, the ET not running, DATE and CHR nothing (ATA31 p.80)")
inp.et_sel = CM.ET_HLD
inp.set = CM.SET_HLD
run(5)
T.check(o.minutes == 0 and o.et_show, "HLD Y: still zeros")
inp.set = CM.SET_MS
run(1.5)
T.check(o.minutes == 1 and not o.et_show, "the UTC advanced a digit: set, the ET blank again")
inp.set = CM.SET_RUN
run(61)
T.equal(o.minutes, 2, "RUN: the clock runs")
s = CM.new()
inp.hot = false
o = CM.update(s, inp, 0.1)
inp.hot = true
o = CM.update(s, inp, 0.1)
T.check(o.hours == 12, "not powered at the load: taken as set, no reset")

-- the glue
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:set("laminar/B747/electrical/bus/hot_bat_main", 1)
rt:set("laminar/B747/electrical/bus/bat_apu", 1)
local zulu0 = 12 * 3600 + 34 * 60 + 56
rt:set("sim/cockpit2/clock_timer/zulu_day", 26)
rt:set("sim/cockpit2/clock_timer/zulu_month", 10)
rt:set("sim/time/zulu_time_sec", zulu0)
local ft = 100
rt:set("sim/time/total_flight_time_sec", ft)
rt:callout("flight_start")
local function step(seconds)
    for _ = 1, math.floor(seconds * 2 + 0.5) do
        ft = ft + 0.5
        rt:set("sim/time/total_flight_time_sec", ft)
        rt:set("sim/time/zulu_time_sec", zulu0 + ft - 100)
        rt:frame(0.5)
    end
end
step(1)
local C, F = "laminar/B747/fltInst/capt/clock_", "laminar/B747/fltInst/fo/clock_"
T.check(rt:get(C .. "on") == 1 and rt:get(C .. "utc_hours") == 12 and rt:get(C .. "utc_minutes") == 34
    and rt:get(C .. "day") == 26 and rt:get(C .. "month") == 10, "the glue: the Captain's clock on X-Plane's UTC")
T.equal(rt:get(C .. "year"), tonumber(os.date("!%Y")) % 100, "the year: the computer's")
T.check(rt:get(F .. "on") == 1 and rt:get(F .. "utc_minutes") == 34, "the F/O's too")
rt:command("laminar/B747/fltInst/capt/clock_chrono_switch")
step(1)
T.check(rt:get(C .. "et_chr_display") == 1 and rt:get(C .. "chr_sw_pos") == 0
    and rt:get("laminar/B747/glareshiled/captain/chrono_switch_pos") == 0, "CHR: started, the buttons back out")
T.check(rt:get(C .. "chr_seconds") > 0.9 and rt:get(F .. "et_chr_display") == 0, "the sweep hand turns; the F/O's clock apart")
rt:command("laminar/B747/fltInst/capt/clock_et_sel_up")
T.equal(rt:get(C .. "et_sel_pos"), 1, "ET up from HLD: RUN")
rt:command("laminar/B747/fltInst/capt/clock_chrono_switch")
rt:command("laminar/B747/fltInst/capt/clock_chrono_switch")
step(61)
T.check(rt:get(C .. "et_show") == 1 and rt:get(C .. "et_minutes") == 1 and rt:get(C .. "et_chr_display") == 0,
    "CHR reset: the ET (00:01) shown")
rt:command("laminar/B747/fltInst/capt/clock_et_sel_down")
T.equal(rt:get(C .. "et_sel_pos"), 0, "ET down from RUN: HLD")
rt:command("laminar/B747/fltInst/capt/clock_et_sel_down")
step(0.5)
T.check(rt:get(C .. "et_sel_pos") == 0 and rt:get(C .. "et_show") == 0 and rt:get(C .. "et_seconds") == 0,
    "ET down from HLD: RESET, zero and blank, back at HLD")
rt:command("laminar/B747/fltInst/capt/clock_set_sel_up")
step(0.5)
local held = rt:get(C .. "utc_minutes")
step(120)
T.check(rt:get(C .. "set_sel_pos") == 1 and rt:get(C .. "utc_minutes") == held
    and rt:get(F .. "utc_minutes") == (held + 2) % 60, "SET to HLD: the Captain's time stands, the F/O's runs")
rt:command("laminar/B747/fltInst/capt/clock_set_sel_down")
rt:command("laminar/B747/fltInst/capt/clock_set_sel_down")
T.equal(rt:get(C .. "set_sel_pos"), 0, "SET down: RUN, no further")
rt:command("laminar/B747/fltInst/fo/clock_date_switch")
step(0.5)
T.check(rt:get(F .. "utc_display") == 1 and rt:get(F .. "date_display_mode") == 0 and rt:get(F .. "date_sw_pos") == 0,
    "the F/O's DATE: the day and month")
-- XTLua runs a command given once as its end, then its begin (X-Plane, s74)
local h = rt.commands["laminar/B747/fltInst/fo/clock_date_switch"].handler
h(2, 0)
h(0, 0)
step(0.1)
T.equal(rt:get(F .. "date_sw_pos"), 1, "the end before the begin: the DATE button in a moment")
step(0.5)
T.check(rt:get(F .. "date_sw_pos") == 0 and rt:get(F .. "utc_display") == 0, "then back out (DATE: the time again)")
h = rt.commands["laminar/B747/fltInst/fo/clock_et_sel_down"].handler
h(2, 0)
h(0, 0)
step(0.5)
T.equal(rt:get(F .. "et_sel_pos"), 0, "the ET selector's RESET likewise back at HLD")
rt:set("laminar/B747/electrical/bus/bat_apu", 0)
step(0.5)
T.check(rt:get(C .. "on") == 0 and rt:get(F .. "on") == 0, "no APU battery bus: both blank")
rt:set("laminar/B747/electrical/bus/bat_apu", 1)
rt:callout("flight_start")
step(0.5)
T.check(rt:get(C .. "utc_minutes") == math.floor((zulu0 + ft - 100) % 3600 / 60) and rt:get(F .. "utc_display") == 0,
    "a new flight: on X-Plane's UTC again")

T.done()
