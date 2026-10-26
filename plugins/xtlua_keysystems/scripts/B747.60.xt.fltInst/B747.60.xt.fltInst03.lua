-- The clocks (5-2 step 6a, GAP DSP-33; notes/ATA-31.md §35): each clock's
-- switches (CHR, with the glareshield's CHR switch in parallel; DATE; the
-- ET and SET selectors), the main hot and APU battery buses and X-Plane's
-- UTC go to the clock model (B747.60.clock_model.lua); the LCDs' power,
-- the clock's own UTC and date, the ET and the chronograph come back for
-- the panel (new: fltInst/<side>/clock_on, clock_utc_hours,
-- clock_utc_minutes, clock_day, clock_month, clock_et_show), the sweep
-- second hand (clock_chr_seconds) for the 3D cockpit. The ET selector's
-- commands follow its face (RUN, HLD, RESET): up turns towards RUN, down
-- from HLD to RESET, which springs back to HLD. The F/O's clock likewise
-- (fltInst04, the old copy for it, folded in here). The 3D's two CHR
-- buttons of a side run one command, so both move.
-- dofile'd from B747.60.xt.fltInst.lua; fltInst02's after_physics runs
-- B747_clocks(), its flight_start B747_clocks_flight_start().

dofile("B747.60.clock_model.lua")
local CM = B747_clock_model

simDR_clock_zulu_sec            = find_dataref("sim/time/zulu_time_sec")
simDR_clock_zulu_day            = find_dataref("sim/cockpit2/clock_timer/zulu_day")
simDR_clock_zulu_month          = find_dataref("sim/cockpit2/clock_timer/zulu_month")
simDR_clock_flight_time         = find_dataref("sim/time/total_flight_time_sec")
B747DR_clock_hot_bat_main       = find_dataref("laminar/B747/electrical/bus/hot_bat_main")
B747DR_clock_bat_apu            = find_dataref("laminar/B747/electrical/bus/bat_apu")

-- each clock's datarefs (XTLua namespaces: only the fields bound here)
clockCapt = {}
clockFO = {}
local function bind(t, side, glareshield)
    local p = "laminar/B747/fltInst/" .. side .. "/clock_"
    t.chr_sw = find_dataref(p .. "chr_sw_pos")
    t.date_sw = find_dataref(p .. "date_sw_pos")
    t.et_sel = find_dataref(p .. "et_sel_pos")
    t.set_sel = find_dataref(p .. "set_sel_pos")
    t.utc_display = find_dataref(p .. "utc_display")
    t.date_mode = find_dataref(p .. "date_display_mode")
    t.et_chr = find_dataref(p .. "et_chr_display")
    t.et_seconds = find_dataref(p .. "et_seconds")
    t.et_minutes = find_dataref(p .. "et_minutes")
    t.et_hours = find_dataref(p .. "et_hours")
    t.chr_seconds = find_dataref(p .. "chr_seconds")
    t.chr_minutes = find_dataref(p .. "chr_minutes")
    t.year = find_dataref(p .. "year")
    t.on = find_dataref(p .. "on")
    t.utc_hours = find_dataref(p .. "utc_hours")
    t.utc_minutes = find_dataref(p .. "utc_minutes")
    t.day = find_dataref(p .. "day")
    t.month = find_dataref(p .. "month")
    t.et_show = find_dataref(p .. "et_show")
    t.glare_sw = find_dataref("laminar/B747/glareshiled/" .. glareshield .. "/chrono_switch_pos")
end
bind(clockCapt, "capt", "captain")
bind(clockFO, "fo", "fo")

local clocks = {CM.new(), CM.new()}

-- A command run once (a knob's click, X-Plane's CommandOnce, the Web API
-- without a duration) reaches XTLua as a begin whose end comes first or not
-- at all (s74: the buttons stayed in), so the push buttons and the ET
-- selector's RESET come back on their own RELEASE_S after the last begin or
-- hold, at once after an end that comes later.
local RELEASE_S = 0.2
local now = 0
local release = {{}, {}}

local function hold(i, key, phase)
    release[i][key] = phase < 2 and now + RELEASE_S or now
end

local function chr_switch(t, i)
    return function(phase, duration)
        if phase == 0 then
            t.chr_sw, t.glare_sw = 1, 1
            CM.chr_push(clocks[i])
        end
        hold(i, "chr", phase)
    end
end

local function date_switch(t, i)
    return function(phase, duration)
        if phase == 0 then
            t.date_sw = 1
            CM.date_push(clocks[i])
        end
        hold(i, "date", phase)
    end
end

local function et_up(t)
    return function(phase, duration)
        if phase == 0 then
            local pos = t.et_sel
            if pos == CM.ET_HLD then
                t.et_sel = CM.ET_RUN
            elseif pos == CM.ET_RESET then
                t.et_sel = CM.ET_HLD
            end
        end
    end
end

-- RESET springs back to HLD
local function et_down(t, i)
    return function(phase, duration)
        if phase == 0 then
            local pos = t.et_sel
            if pos == CM.ET_RUN then
                t.et_sel = CM.ET_HLD
            elseif pos == CM.ET_HLD then
                t.et_sel = CM.ET_RESET
                CM.et_reset(clocks[i])
                hold(i, "et", phase)
            end
        elseif release[i].et then
            hold(i, "et", phase)
        end
    end
end

local function set_turn(t, step)
    return function(phase, duration)
        if phase == 0 then
            t.set_sel = math.max(CM.SET_RUN, math.min(CM.SET_HS, t.set_sel + step))
        end
    end
end

for i, side in ipairs({{"capt", "Captain", clockCapt}, {"fo", "First Officer", clockFO}}) do
    local p, who, t = "laminar/B747/fltInst/" .. side[1] .. "/", side[2], side[3]
    deferred_command(p .. "clock_chrono_switch", who .. " Clock Chronograph Switch", chr_switch(t, i))
    deferred_command(p .. "clock_date_switch", who .. " Clock Date Switch", date_switch(t, i))
    deferred_command(p .. "clock_et_sel_up", who .. " Clock ET Selector Up", et_up(t))
    deferred_command(p .. "clock_et_sel_down", who .. " Clock ET Selector Down", et_down(t, i))
    deferred_command(p .. "clock_set_sel_up", who .. " Clock SET Selector Up", set_turn(t, 1))
    deferred_command(p .. "clock_set_sel_down", who .. " Clock SET Selector Down", set_turn(t, -1))
end

local inp = {utc = 0, hot = false, apu = false, set = CM.SET_RUN, et_sel = CM.ET_HLD}
local year, last_month, last_time

local function clock(t, s, r, dt)
    if r.chr and now >= r.chr then t.chr_sw, t.glare_sw, r.chr = 0, 0, nil end
    if r.date and now >= r.date then t.date_sw, r.date = 0, nil end
    if r.et and now >= r.et then t.et_sel, r.et = CM.ET_HLD, nil end
    inp.set, inp.et_sel = t.set_sel, t.et_sel
    local o = CM.update(s, inp, dt)
    t.on = o.on and 1 or 0
    t.utc_hours, t.utc_minutes = o.hours, o.minutes
    t.day, t.month, t.year = o.day, o.month, o.year
    t.utc_display, t.date_mode = o.utc_display, o.date_mode
    t.et_chr, t.et_show = o.et_chr, o.et_show and 1 or 0
    t.et_seconds, t.et_hours, t.et_minutes = o.et_seconds, o.et_hours, o.et_minutes
    t.chr_minutes, t.chr_seconds = o.chr_minutes, o.chr_seconds
end

function B747_clocks()
    local month, day = simDR_clock_zulu_month, simDR_clock_zulu_day
    if month < 1 or month > 12 or day < 1 then return end
    -- X-Plane's date has no year: the computer's, the next one after
    -- X-Plane's December
    if not year then year = tonumber(os.date("!%Y")) end
    if last_month == 12 and month == 1 then year = year + 1 end
    last_month = month
    -- ET and CHR in the simulator's time, like X-Plane's UTC (a new flight
    -- or a stop of the simulator's clock counts nothing)
    local ft = simDR_clock_flight_time
    local dt = last_time and ft - last_time or 0
    last_time = ft
    if dt < 0 or dt > 5 then dt = 0 end
    now = now + dt
    inp.utc = CM.utc(year, month, day, simDR_clock_zulu_sec)
    inp.hot = B747DR_clock_hot_bat_main > 0.5
    inp.apu = B747DR_clock_bat_apu > 0.5
    clock(clockCapt, clocks[1], release[1], dt)
    clock(clockFO, clocks[2], release[2], dt)
end

-- a new flight: the clocks on X-Plane's UTC, the ET and chronograph at zero
function B747_clocks_flight_start()
    clocks[1], clocks[2] = CM.new(), CM.new()
    last_time = nil
end
