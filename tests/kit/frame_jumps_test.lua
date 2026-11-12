-- Run from the repository root with LuaJIT: luajit tests/kit/frame_jumps_test.lua
-- The long frames and the one-frame steps of a flight-test recording
-- (tests/flight/tools/frame_jumps.lua, 2026-11-12; docs/overhaul/TESTING.md
-- §4.2) on recordings made here (no X-Plane): a frame at X-Plane's floor of
-- 19.9 a second with the pitch command and the trim stepping in it and in
-- the frame after (the user's PC, 2026-11-12: PROGRESS.md), what the
-- airplane did after it, long frames in a row as one stretch, a long frame
-- by the recorder's wall column alone, steps away from any long frame, the
-- watched columns and their least step, a recording without the columns,
-- and the file's reading and the report.
local T = dofile("tests/lib/check.lua")("frame_jumps")
local J = dofile("tests/flight/tools/frame_jumps.lua")

-- 60 frames a second for `secs`; at(t, n) may change the row
local function build(secs, at)
    local rows = {}
    local t, n = 0, 0
    local alt = 20000
    while t <= secs + 1e-9 do
        n = n + 1
        local r = {t = t, frame_rate = 60, pitch_cmd = 2.5, fd = 2.5, trim = -0.2, elevator_ratio = 0.01, roll_cmd = 0,
            roll_ratio = 0, at_cmd = 0.5, gload = 1, vs_i = 0, alt = alt, ias = 300, fma = 9, fma_roll = 2, fma_at = 3,
            servos_on = 1, wall = t}
        if at then at(r, n) end
        alt = alt + (r.vs_i or 0) / 60 * (1 / 60)
        r.alt = r.alt_set or alt
        rows[#rows + 1] = r
        t = t + (r.dt or 1 / 60)
    end
    return rows
end

-- nothing happens: no long frame, no step
local res = J.analyse(build(20))
T.equal(#res.long, 0, "a steady recording: no long frame")
T.equal(#res.steps, 0, "a steady recording: no step")
T.check(res.has_wall and res.has_fps, "the wall and frame_rate columns seen")

-- the user's PC, 2026-11-12: X-Plane stands still, then one frame at the
-- floor (19.9 a second, the sim's time 0.05 s on) in which the pitch
-- command moves 2.5 deg; the trim follows in the frame after; then the
-- airplane pitches over (-0.82 g, 1,400 ft lost over the next half minute)
local hit                 -- the row of the long frame
local function upset(r, n)
    if math.abs(r.t - 10) < 1e-6 and not hit then
        hit = n
        r.frame_rate, r.dt = 19.9, 1 / 19.9
        r.wall = r.t + 31.4            -- 31.4 s of real time in this frame
        r.pitch_cmd = 0
    elseif hit then
        r.wall = r.t + 31.4
        r.pitch_cmd = 0
        if n >= hit + 1 then r.trim = -0.26 end
        local s = r.t - 10
        if s < 12 then
            r.gload = 1 - 1.82 * math.exp(-((s - 2) ^ 2) / 2)
            r.vs_i = -7000 * math.exp(-((s - 9) ^ 2) / 40)
        elseif s < 30 then
            r.vs_i = -7000 * math.exp(-((s - 9) ^ 2) / 40)
            r.gload = 1 + 0.4 * math.exp(-((s - 14) ^ 2) / 8)
        end
    end
end
local rows = build(60, upset)
res = J.analyse(rows)
T.equal(#res.long, 1, "one long frame")
local s = res.long[1]
T.near(s.t, 10, 1e-6, "its time")
T.equal(s.frames, 1, "one frame")
T.near(s.fps, 19.9, 1e-9, "at the floor")
T.near(s.real or 0, 31.4 + 1 / 60, 1e-6, "its real length from the wall column")
T.equal(#s.steps, 2, "two steps with it: the pitch command in it, the trim in the frame after")
T.equal(s.steps[1].col, "pitch_cmd", "the pitch command's step")
T.near(s.steps[1].to - s.steps[1].from, -2.5, 1e-9, "by 2.5 deg down")
T.equal(s.steps[2].col, "trim", "the trim's step")
T.near(s.steps[2].to - s.steps[2].from, -0.06, 1e-9, "by 0.06")
T.near(s.steps[2].t - s.steps[1].t, 1 / 19.9, 1e-6, "the trim's a frame later")
T.near(s.after.g_lo, -0.82, 0.01, "the least load factor of the 30 s after")
T.near(s.after.vs_lo, -7000, 5, "the least vertical speed")
T.check(s.after.lost > 1200 and s.after.lost < 1700, "the altitude lost (" .. string.format("%.0f", s.after.lost) .. " ft)")
T.near(s.after.gained, 0, 1e-6, "none gained")
T.equal(s.fma, 9, "the pitch FMA at the long frame")
T.equal(#res.steps, 2, "no other step in the recording")
-- a shorter look after it
res = J.analyse(rows, {after = 3})
T.check(res.long[1].after.lost < 200, "3 s after: the dive only begun (" .. string.format("%.0f", res.long[1].after.lost) .. " ft)")
-- the report names them
local text = table.concat(J.lines(J.analyse(rows)), "\n")
T.check(text:find("long frames: 1 stretch", 1, true), "the report: one stretch")
T.check(text:find("31.42 s of real time", 1, true), "the report: the real length")
T.check(text:find("pitch_cmd", 1, true) and text:find("(-2.5)", 1, true), "the report: the pitch command's step")
T.check(text:find("load factor -0.82", 1, true), "the report: the load factor")
T.check(text:find("steps away from the long frames: 0", 1, true), "the report: no step elsewhere")

-- without the wall column: the long frame by the frame rate alone, its
-- real length not known
hit = nil
local nowall = build(60, function(r, n) upset(r, n); r.wall = nil end)
res = J.analyse(nowall)
T.equal(#res.long, 1, "no wall column: the long frame by its frame rate")
T.check(res.long[1].real == nil and not res.has_wall, "its real length not known")
T.check(table.concat(J.lines(res), "\n"):find("no wall column", 1, true), "the report says so")

-- by the wall column alone: a frame of 0.4 s of real time whose frame
-- rate (X-Plane's smoothed value) still reads 30
hit = nil
rows = build(20, function(r, n)
    if n > 300 then r.wall = r.t + 0.4 end
    if n == 301 then r.frame_rate = 30; r.fd = 4.0 end
    if n > 301 then r.fd = 4.0 end
end)
res = J.analyse(rows)
T.equal(#res.long, 1, "a frame long in real time alone")
T.near(res.long[1].real, 0.4 + 1 / 60, 1e-6, "its real length")
T.equal(#res.long[1].steps, 1, "the F/D bar's step with it")
T.equal(#J.analyse(rows, {wall = 0.5}).long, 0, "under the real time asked: not long")
T.equal(#J.analyse(rows, {fps = 30}).long, 1, "at the frame rate asked: long by it")

-- long frames in a row are one stretch; apart, two
rows = build(20, function(r, n)
    if (n >= 100 and n <= 104) or n == 300 then r.frame_rate = 19.9 end
end)
res = J.analyse(rows)
T.equal(#res.long, 2, "five frames in a row and one apart: two stretches")
T.equal(res.long[1].frames, 5, "the first: five frames")
T.check(res.long[1].t1 > res.long[1].t, "its end after its beginning")
T.equal(res.long[2].frames, 1, "the second: one")
T.equal(#res.long[1].steps, 0, "no step with them")

-- steps away from a long frame: a mode change that steps the pitch command
rows = build(20, function(r, n)
    if n >= 600 then r.fma = 5; r.pitch_cmd = 4.0 end
    if n >= 900 then r.roll_cmd = 12 end
end)
res = J.analyse(rows)
T.equal(#res.long, 0, "no long frame")
T.equal(#res.steps, 2, "two steps")
T.check(res.steps[1].col == "pitch_cmd" and not res.steps[1].long and res.steps[1].fma == 5 and res.steps[1].fma_was == 9,
    "the pitch command's with the mode change")
T.equal(res.steps[2].col, "roll_cmd", "the roll command's")
text = table.concat(J.lines(res), "\n")
T.check(text:find("steps away from the long frames: 2", 1, true) and text:find("pitch FMA 9 -> 5", 1, true),
    "the report: the steps and the mode change")
T.check(table.concat(J.lines(res, 1), "\n"):find("(the first 1)", 1, true), "the report: no more than asked")

-- the watched columns and their least step
rows = build(10, function(r, n)
    if n >= 300 then r.pitch_cmd = 2.9; r.elevator_ratio = 0.3 end
end)
T.equal(#J.analyse(rows).steps, 1, "0.4 deg of pitch command is no step, 0.29 of elevator is")
T.equal(J.analyse(rows).steps[1].col, "elevator_ratio", "the elevator's")
res = J.analyse(rows, {steps = {{"pitch_cmd", 0.3}}})
T.check(#res.steps == 1 and res.steps[1].col == "pitch_cmd", "the least step asked: the pitch command's alone")
T.equal(#J.analyse(rows, {steps = {{"nothing", 1}}}).steps, 0, "a column the recording does not have: no step")

-- a recording without the frame rate, the wall or the watched columns
rows = {}
for n = 0, 100 do rows[#rows + 1] = {t = n / 20, alt = 1000, ias = 250} end
res = J.analyse(rows)
T.check(#res.long == 0 and #res.steps == 0 and not res.has_fps and not res.has_wall, "an old recording: nothing found, nothing known")
T.check(table.concat(J.lines(res), "\n"):find("no frame_rate column", 1, true), "the report says so")
T.equal(#J.analyse({}).long, 0, "an empty recording")

-- a file read (CRLF, an empty field)
local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
local path = dir .. "/b747_frame_jumps_test_" .. tostring(os.time()) .. ".csv"
local f = assert(io.open(path, "wb"))
f:write("t,alt,frame_rate,pitch_cmd,trim,wall\r\n0,1000,60,2,-0.2,0\r\n0.0167,1000,60,2,-0.2,0.0167\r\n"
    .. "0.0669,1000,19.9,,-0.2,12.5\r\n0.0836,1000,60,0.5,-0.25,12.5167\r\n")
f:close()
rows = J.read(path)
os.remove(path)
T.equal(#rows, 4, "the file's rows")
T.check(rows[3].pitch_cmd == nil and rows[3].frame_rate == 19.9 and rows[4].wall == 12.5167, "its fields by name, an empty one nil")
res = J.analyse(rows)
T.equal(#res.long, 1, "its long frame")
T.near(res.long[1].real, 12.4833, 1e-4, "its real length")
T.check(#res.long[1].steps == 1 and res.long[1].steps[1].col == "trim", "the trim's step in the frame after (the pitch command empty in between: none)")

T.done()
