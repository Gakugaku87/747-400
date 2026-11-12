-- Run from the repository root with LuaJIT: luajit tests/kit/csv_slice_test.lua
-- The cut of a flight-test recording (tests/flight/tools/csv_slice.lua,
-- 2026-11-12; docs/overhaul/TESTING.md §4.2) on a recording made here (no
-- file, no X-Plane): the time range, the columns and their order, one row
-- every so often (counted from the first row kept, a long frame not
-- shifting the rest), the decimals, the cut made to fit a size, a mark's
-- time from the events, and the command line on a file.
local T = dofile("tests/lib/check.lua")("csv_slice")
local S = dofile("tests/flight/tools/csv_slice.lua")

-- a recording at 20 frames a second for 60 s, with no row for 2.3 s after
-- the one at 30 s (a long frame); CRLF as FlyWithLua writes on Windows
local lines = {"t,alt,ias,vs,fma,pitch_cmd,sim_t\r"}
local t = 0
while t <= 60 + 1e-9 do
    lines[#lines + 1] = string.format("%.4f,%.4f,%d,%.4f,%d,%.4f,%.4f\r", t, 10000 + 25 * t, 250, 1500.6, 4,
        2 + t / 100, 1000 + t)
    t = t + (math.abs(t - 30) < 1e-6 and 2.3 or 0.05)
end
local function fields(line)
    local out = {}
    for f in (line .. ","):gmatch("([^,]*),") do out[#out + 1] = f end
    return out
end
local function times(out)
    local ts = {}
    for i = 2, #out do ts[#ts + 1] = tonumber(fields(out[i])[1]) end
    return ts
end

-- all of it: every row, every column, no carriage return
local out = S.slice(lines, {})
T.equal(#out, #lines, "all the rows without options")
T.equal(out[1], "t,alt,ias,vs,fma,pitch_cmd,sim_t", "the header without its carriage return")
T.equal(out[2], "0.0000,10000.0000,250,1500.6000,4,2.0000,1000.0000", "a row as recorded")

-- the time range, either end open
out = S.slice(lines, {t0 = 10, t1 = 12})
local ts = times(out)
T.near(ts[1], 10, 1e-6, "the range's first row")
T.near(ts[#ts], 12, 1e-6, "the range's last row (t1 itself in)")
T.equal(#ts, 41, "the rows of 10 to 12 s at 20 a second")
out = S.slice(lines, {t0 = 59})
T.near(times(out)[1], 59, 1e-6, "from t0 to the end")
T.near(times(out)[#out - 1], 60, 0.051, "to the recording's last row")
out = S.slice(lines, {t1 = 1})
T.equal(#out - 1, 21, "from the start to t1")
T.equal(#S.slice(lines, {t0 = 100}), 1, "a range past the recording: the header alone")

-- the columns, in the order asked, t first
out = S.slice(lines, {cols = {"pitch_cmd", "alt"}, t0 = 5, t1 = 5})
T.equal(out[1], "t,pitch_cmd,alt", "t put first")
T.equal(out[2], "5.0000,2.0500,10125.0000", "the columns' values in that order")
out = S.slice(lines, {cols = {"t", "ias", "t"}, t0 = 5, t1 = 5})
T.equal(out[1], "t,ias", "t named: once")
local ok, err = pcall(S.slice, lines, {cols = {"vs_i"}})
T.check(not ok and tostring(err):find("no column vs_i", 1, true) and tostring(err):find("pitch_cmd", 1, true),
    "a column the recording does not have: an error with its columns (" .. tostring(err) .. ")")

-- one row every 0.5 s: from the first row kept; the long frame at 30 s
-- (rows at 30.0 and 32.3) does not shift the rows after it
out = S.slice(lines, {every = 0.5, t0 = 28, t1 = 34, cols = {"alt"}})
ts = times(out)
local want = {28, 28.5, 29, 29.5, 30, 32.3, 32.5, 33, 33.5, 34}
T.equal(#ts, #want, "the rows every 0.5 s across the long frame: " .. table.concat(ts, " "))
for i, w in ipairs(want) do T.near(ts[i] or -1, w, 0.026, "row " .. i .. " every 0.5 s") end
out = S.slice(lines, {every = 10})
T.equal(#out - 1, 7, "every 10 s: 0, 10 ... 60")
out = S.slice(lines, {every = 0.01, t1 = 1})
T.equal(#out - 1, 21, "a step shorter than the frames: every row")

-- the decimals
out = S.slice(lines, {digits = 1, t0 = 5.09, t1 = 5.11})
T.equal(out[2], "5.1,10127.5,250,1500.6,4,2.1,1005.1", "one decimal, whole numbers as they are")
out = S.slice(lines, {digits = 0, t0 = 5, t1 = 5, cols = {"alt", "vs"}})
T.equal(out[2], "5,10125,1501", "no decimals: rounded")
out = S.slice(lines, {digits = 2, t0 = 20, t1 = 20, cols = {"pitch_cmd"}})
T.equal(out[2], "20,2.2", "the trailing zeros dropped")
local odd = {"t,x", "1,", "2,abc", "3,-0.00001"}
out = S.slice(odd, {digits = 2})
T.equal(out[2] .. "|" .. out[3] .. "|" .. out[4], "1,|2,abc|3,0", "an empty field, a text and a rounded -0")

-- made to fit a size: the step doubled from 0.1 s until it does
local function size(o)
    local b = 0
    for _, l in ipairs(o) do b = b + #l + 1 end
    return b
end
local full = S.slice(lines, {cols = {"alt", "vs"}})
local every
out, every = S.slice(lines, {cols = {"alt", "vs"}, max_bytes = 4000})
T.check(size(full) > 4000 and size(out) <= 4000, "the cut fits 4,000 bytes (" .. size(out) .. ", all of it " .. size(full) .. ")")
T.near(every or 0, 0.8, 1e-9, "the step that fits: 0.1 s doubled three times")
T.near(times(out)[1], 0, 1e-6, "its first row still the first")
out, every = S.slice(lines, {cols = {"alt"}, every = 0.5, max_bytes = 100000})
T.near(every or 0, 0.5, 1e-9, "a cut that fits already: the step asked")
out, every = S.slice(lines, {cols = {"alt"}, every = 3, max_bytes = 230})
T.near(every or 0, 6, 1e-9, "the step asked doubled until it fits (" .. size(out) .. " bytes)")
T.equal(#out - 1, 11, "its rows: 0, 6 ... 60")
ok, err = pcall(S.slice, lines, {max_bytes = 20})
T.check(not ok and tostring(err):find("does not fit", 1, true), "a size no row fits: an error (" .. tostring(err) .. ")")

-- a mark's time from the events
local events = {"sim_t,t,state,from,to", "1000,0,start,,747-400_custom.acf", "1012.5,12.5,mark,,", "1020,20,fma,5,4",
    "1047.3,47.3,mark,,\r", "1060,60,stop,,"}
T.near(S.mark_time(events, 1), 12.5, 1e-9, "the first mark")
T.near(S.mark_time(events, 2), 47.3, 1e-9, "the second mark (a carriage return at its end)")
ok, err = pcall(S.mark_time, events, 3)
T.check(not ok and tostring(err):find("2 mark(s), not 3", 1, true), "a mark the events do not have: " .. tostring(err))

-- the command line on files: around the second mark, to a file
local dir = os.getenv("TEMP") or os.getenv("TMPDIR") or "/tmp"
local base = dir .. "/b747_csv_slice_test_" .. tostring(os.time())
local sep = package.config:sub(1, 1)
os.execute((sep == "\\" and 'mkdir "' or 'mkdir -p "') .. (sep == "\\" and base:gsub("/", "\\") or base) .. '"')
local function write(name, ls)
    local f = assert(io.open(base .. "/" .. name, "wb"))
    f:write(table.concat(ls, "\n"), "\n")
    f:close()
end
write("session.csv", lines)
write("events.csv", events)
local luajit = arg and arg[-1] or "luajit"
local cmd = string.format('"%s" tests/flight/tools/csv_slice.lua "%s/session.csv" -k 2,1,2 -c alt,fma -e 0.5 -d 1 -o "%s/cut.csv"',
    luajit, base, base)
if sep == "\\" then cmd = '"' .. cmd .. ' 2>nul"' else cmd = cmd .. " 2>/dev/null" end
local code = os.execute(cmd)
T.check(code == 0 or code == true, "the command line runs (" .. tostring(code) .. ")")
local cutf = io.open(base .. "/cut.csv", "rb")
T.check(cutf ~= nil, "the cut written to the file")
if cutf then
    local got = {}
    for l in cutf:lines() do got[#got + 1] = l end
    cutf:close()
    T.equal(got[1], "t,alt,fma", "the file's header")
    T.equal(#got - 1, 7, "46.3 to 49.3 s every 0.5 s")
    T.equal(got[2], "46.3,11157.5,4", "its first row, one decimal")
end
-- a column not there: exit status 1
cmd = string.format('"%s" tests/flight/tools/csv_slice.lua "%s/session.csv" -c nothing', luajit, base)
if sep == "\\" then cmd = '"' .. cmd .. ' >nul 2>nul"' else cmd = cmd .. " >/dev/null 2>&1" end
code = os.execute(cmd)
T.check(code ~= 0 and code ~= true, "a column not there: a failing exit status (" .. tostring(code) .. ")")
for _, name in ipairs({"session.csv", "events.csv", "cut.csv"}) do os.remove(base .. "/" .. name) end
os.remove(base)

T.done()
