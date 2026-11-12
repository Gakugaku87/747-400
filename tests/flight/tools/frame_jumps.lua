-- The long frames of a flight-test recording (session.csv) and the values
-- that moved by a step within one frame (2026-11-12; docs/overhaul/
-- TESTING.md §4.2). On 2026-11-12, on the user's PC, the frame right after
-- X-Plane had stood still for some tens of seconds moved the F/D's pitch
-- command and the stabilizer trim at once, four times (-0.82 g and 1,400 ft
-- lost at the worst: PROGRESS.md); they were found by hand, from the
-- recording's frame_rate at X-Plane's floor of 19.9 a second and the steps
-- of pitch_cmd and trim in that frame.
--   luajit tests/flight/tools/frame_jumps.lua <session.csv> [options]
--     -f <fps>     a frame at or under this rate is a long one (20.5).
--                  X-Plane does not let the flight model's step grow past
--                  about 1/19.9 s: a frame that took longer shows 19.9 and
--                  the sim's time moves 0.05 s, however long it took
--     -g <seconds> with the recorder's wall column (v13: real seconds since
--                  the recording began), a frame longer than this in real
--                  time is a long one as well (0.25), and its length shown
--     -j <col>:<step>[,<col>:<step>...]
--                  the columns watched and the least change within one
--                  frame that counts as a step (the default below)
--     -w <seconds> what the airplane did after a long frame with a step,
--                  over so many seconds (30)
--     -n <rows>    the most steps listed away from the long frames (40)
-- A long frame's steps are those of its own row and of the row after it
-- (what a module computed over the long frame reaches X-Plane a frame
-- later). Long frames in a row are one stretch.
--   local J = dofile("tests/flight/tools/frame_jumps.lua")   -- in the tests:
--   J.analyse(rows, opts) -> {long = {...}, steps = {...}} with rows of
--   {t = , frame_rate = , <column> = ...}
local M = {}

-- the least change within one frame that is a step: the AFDS's pitch
-- command and the F/D bar (degrees; the laws move them some 3 deg/s at the
-- most: 0.15 deg a frame at 20 a second), the stabilizer trim (X-Plane's
-- -1..1; the stabilizer runs about 0.01 a second), the pitch and roll
-- commands to the controls (-1..1), the AFDS's roll command (degrees), the
-- A/T's lever command (0..1)
M.STEPS = {
    {"pitch_cmd", 0.5}, {"fd", 1.0}, {"trim", 0.01}, {"elevator_ratio", 0.2},
    {"roll_cmd", 2.0}, {"roll_ratio", 0.2}, {"at_cmd", 0.05},
}
M.FPS, M.WALL, M.AFTER, M.MOST = 20.5, 0.25, 30, 40

-- the rows of a session.csv: every column a number by its name
function M.read(path)
    local f = assert(io.open(path, "rb"))
    local names = {}
    for name in f:read("*l"):gsub("\r", ""):gmatch("[^,]+") do names[#names + 1] = name end
    local rows = {}
    for line in f:lines() do
        local r, k = {}, 0
        for field in (line:gsub("\r", "") .. ","):gmatch("([^,]*),") do
            k = k + 1
            if names[k] then r[names[k]] = tonumber(field) end
        end
        if r.t then rows[#rows + 1] = r end
    end
    f:close()
    return rows
end

-- opts: {fps, wall, steps = {{col, step}...}, after}
function M.analyse(rows, opts)
    opts = opts or {}
    local fps = opts.fps or M.FPS
    local wall_long = opts.wall or M.WALL
    local watch = opts.steps or M.STEPS
    local after = opts.after or M.AFTER
    local long, steps = {}, {}
    local is_long = {}
    -- the long frames, those in a row as one stretch
    local cur = nil
    for i, r in ipairs(rows) do
        local p = rows[i - 1]
        local real = (p and r.wall and p.wall) and (r.wall - p.wall) or nil
        local slow = r.frame_rate ~= nil and r.frame_rate > 0 and r.frame_rate <= fps
        local stood = real ~= nil and real > wall_long
        if slow or stood then
            is_long[i] = true
            if cur and cur.last == i - 1 then
                cur.last, cur.frames = i, cur.frames + 1
                cur.t1 = r.t
                if real then cur.real = (cur.real or 0) + real end
                if r.frame_rate and (not cur.fps or r.frame_rate < cur.fps) then cur.fps = r.frame_rate end
            else
                cur = {first = i, last = i, frames = 1, t = r.t, t1 = r.t, real = real, fps = r.frame_rate,
                    sim = p and (r.t - p.t) or nil, steps = {}}
                long[#long + 1] = cur
            end
        end
    end
    -- the steps: a watched column's change from the row before
    local at_long = {}      -- row -> the stretch it belongs to (its rows and the one after)
    for _, s in ipairs(long) do
        for i = s.first, s.last + 1 do at_long[i] = s end
    end
    for i = 2, #rows do
        local r, p = rows[i], rows[i - 1]
        for _, w in ipairs(watch) do
            local a, b = p[w[1]], r[w[1]]
            if a and b and math.abs(b - a) >= w[2] then
                local st = {i = i, t = r.t, col = w[1], from = a, to = b, long = at_long[i] ~= nil,
                    fma = r.fma, fma_was = p.fma, fps = r.frame_rate}
                steps[#steps + 1] = st
                if at_long[i] then at_long[i].steps[#at_long[i].steps + 1] = st end
            end
        end
    end
    -- what the airplane did after a long frame
    for _, s in ipairs(long) do
        local r0 = rows[s.first]
        local a = {g_lo = r0.gload, g_hi = r0.gload, vs_lo = r0.vs_i or r0.vs, vs_hi = r0.vs_i or r0.vs,
            alt_lo = r0.alt, alt_hi = r0.alt, alt0 = r0.alt}
        local i = s.first
        while rows[i] and rows[i].t <= r0.t + after do
            local r = rows[i]
            local vs = r.vs_i or r.vs
            if r.gload then
                if not a.g_lo or r.gload < a.g_lo then a.g_lo = r.gload end
                if not a.g_hi or r.gload > a.g_hi then a.g_hi = r.gload end
            end
            if vs then
                if not a.vs_lo or vs < a.vs_lo then a.vs_lo = vs end
                if not a.vs_hi or vs > a.vs_hi then a.vs_hi = vs end
            end
            if r.alt then
                if not a.alt_lo or r.alt < a.alt_lo then a.alt_lo = r.alt end
                if not a.alt_hi or r.alt > a.alt_hi then a.alt_hi = r.alt end
            end
            i = i + 1
        end
        if a.alt0 then a.lost, a.gained = a.alt0 - a.alt_lo, a.alt_hi - a.alt0 end
        s.after = a
        s.fma, s.fma_roll, s.fma_at, s.alt, s.ias = r0.fma, r0.fma_roll, r0.fma_at, r0.alt, r0.ias
        s.servos = r0.servos_on
    end
    return {long = long, steps = steps, rows = #rows, watch = watch, fps = fps, wall = wall_long, after = after,
        has_wall = rows[1] ~= nil and rows[1].wall ~= nil, has_fps = rows[1] ~= nil and rows[1].frame_rate ~= nil}
end

local function num(v, f) return v and string.format(f or "%.2f", v) or "-" end

-- the report's lines
function M.lines(res, most)
    most = most or M.MOST
    local out = {}
    local function add(...) out[#out + 1] = string.format(...) end
    local w = {}
    for _, c in ipairs(res.watch) do w[#w + 1] = c[1] .. " " .. c[2] end
    add("%d rows; a long frame: %s%s; a step within one frame: %s", res.rows,
        res.has_fps and string.format("frame_rate at or under %.1f", res.fps) or "no frame_rate column",
        res.has_wall and string.format(" or over %.2f s of real time", res.wall) or " (no wall column: its real length is not known)",
        table.concat(w, ", "))
    add("")
    add("long frames: %d stretch(es)", #res.long)
    for n, s in ipairs(res.long) do
        add("  %d  t %.2f%s: %d frame(s), least %s fps%s; pitch FMA %s roll %s A/T %s, A/P %s, %s ft, %s kt", n, s.t,
            s.frames > 1 and string.format("..%.2f", s.t1) or "", s.frames, num(s.fps, "%.1f"),
            s.real and string.format(", %.2f s of real time", s.real) or "",
            num(s.fma, "%d"), num(s.fma_roll, "%d"), num(s.fma_at, "%d"), num(s.servos, "%d"),
            num(s.alt, "%.0f"), num(s.ias, "%.1f"))
        if #s.steps == 0 then
            add("       no step of a watched column")
        else
            for _, st in ipairs(s.steps) do
                add("       %-14s %s -> %s (%+.4g) at t %.2f%s", st.col, num(st.from, "%.4g"), num(st.to, "%.4g"),
                    st.to - st.from, st.t, st.fma ~= st.fma_was and string.format(", pitch FMA %s -> %s", num(st.fma_was, "%d"), num(st.fma, "%d")) or "")
            end
            local a = s.after
            add("       the %d s after: load factor %s..%s g, vertical speed %s..%s fpm, altitude %s ft lost, %s ft gained",
                res.after, num(a.g_lo), num(a.g_hi), num(a.vs_lo, "%.0f"), num(a.vs_hi, "%.0f"),
                num(a.lost, "%.0f"), num(a.gained, "%.0f"))
        end
    end
    add("")
    local away = {}
    for _, st in ipairs(res.steps) do if not st.long then away[#away + 1] = st end end
    add("steps away from the long frames: %d%s", #away, #away > most and string.format(" (the first %d)", most) or "")
    for n, st in ipairs(away) do
        if n > most then break end
        add("  t %.2f  %-14s %s -> %s (%+.4g), %s fps%s", st.t, st.col, num(st.from, "%.4g"), num(st.to, "%.4g"),
            st.to - st.from, num(st.fps, "%.1f"),
            st.fma ~= st.fma_was and string.format(", pitch FMA %s -> %s", num(st.fma_was, "%d"), num(st.fma, "%d")) or "")
    end
    return out
end

if arg and arg[0] and arg[0]:match("frame_jumps%.lua$") then
    local path
    local opts = {}
    local most
    local i = 1
    while arg[i] do
        local a = arg[i]
        local function value()
            i = i + 1
            local v = arg[i]
            assert(v, "a value after " .. a)
            return v
        end
        if a == "-f" then
            opts.fps = assert(tonumber((value())), "-f <fps>")
        elseif a == "-g" then
            opts.wall = assert(tonumber((value())), "-g <seconds>")
        elseif a == "-w" then
            opts.after = assert(tonumber((value())), "-w <seconds>")
        elseif a == "-n" then
            most = assert(tonumber((value())), "-n <rows>")
        elseif a == "-j" then
            opts.steps = {}
            for col, step in value():gmatch("([^,:]+):([^,]+)") do
                opts.steps[#opts.steps + 1] = {col, assert(tonumber(step), "-j <col>:<step>")}
            end
            assert(#opts.steps > 0, "-j <col>:<step>[,<col>:<step>...]")
        elseif not path then
            path = a
        else
            error("what is " .. a .. "?", 0)
        end
        i = i + 1
    end
    if not path then
        io.stderr:write("usage: luajit tests/flight/tools/frame_jumps.lua <session.csv> [-f fps] [-g seconds]"
            .. " [-j col:step,...] [-w seconds] [-n rows]\n")
        os.exit(2)
    end
    local res = M.analyse(M.read(path), opts)
    print(table.concat(M.lines(res, most), "\n"))
end

return M
