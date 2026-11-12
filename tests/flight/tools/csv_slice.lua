-- A cut of a flight-test recording (session.csv): a time range, some of the
-- columns, one row every so often (2026-11-12; docs/overhaul/TESTING.md
-- §4.2). For handing a stretch of a recording to another session or into a
-- report: on 2026-11-12 the stretches around the speed law's target steps
-- went from the user's PC to the cloud session cut by hand, every 0.5 s and
-- a few columns, to fit a 64 KiB message.
--   luajit tests/flight/tools/csv_slice.lua <session.csv> [options]
--     -t <t0>,<t1>      the rows from t0 to t1 (the t column: seconds from the
--                       recording's start); either may be left empty
--     -a <t>[,<before>[,<after>]]
--                       the rows around a time: from before (30) seconds ahead
--                       of it to after (60) seconds past it
--     -k <n>[,<before>[,<after>]]
--                       the same around the n-th mark of the events.csv beside
--                       the recording (the scenario's "mark" steps, from 1)
--     -c <col>,<col>... the columns, in this order (t first if not named);
--                       all of them without -c
--     -e <seconds>      one row every so many seconds: the first row, then the
--                       first at or past each step from it
--     -d <digits>       numbers with at most so many decimals (as recorded
--                       without -d: four)
--     -m <bytes>        no more than so many bytes: the rows thinned further
--                       (the -e step doubled from 0.1 s, or from the one
--                       given) until the cut fits; what was done to stderr
--     -o <file>         into a file (the standard output without -o)
--   A column the recording does not have is an error (its columns listed).
--   local S = dofile("tests/flight/tools/csv_slice.lua")   -- in the tests:
--   S.slice(lines, opts) -> the cut's lines, opts {t0, t1, cols, every,
--   digits, max_bytes}; S.mark_time(event lines, n) -> the n-th mark's t
local M = {}

local function split(line)
    local out, k = {}, 0
    for field in (line:gsub("\r", "") .. ","):gmatch("([^,]*),") do k = k + 1; out[k] = field end
    return out
end

-- a number with at most `digits` decimals, its trailing zeros dropped; a
-- field that is no number as it is
local function round(field, digits)
    local v = tonumber(field)
    if not v then return field end
    local s = string.format("%." .. digits .. "f", v)
    if s:find(".", 1, true) then s = s:gsub("0+$", ""):gsub("%.$", "") end
    if s == "-0" then s = "0" end
    return s
end

-- the cut of the lines (the header first) once, with the step `every`
local function cut(lines, opts, every)
    local names = split(lines[1])
    local col = {}
    for i, name in ipairs(names) do col[name] = col[name] or i end
    assert(col.t, "no column t in the recording")
    local pick = {}
    if opts.cols and #opts.cols > 0 then
        local seen = {}
        if opts.cols[1] ~= "t" then pick[1] = col.t; seen.t = true end
        for _, name in ipairs(opts.cols) do
            if not col[name] then
                error("no column " .. name .. " in the recording (it has: " .. table.concat(names, " ") .. ")", 0)
            end
            if not seen[name] then pick[#pick + 1] = col[name]; seen[name] = true end
        end
    else
        for i = 1, #names do pick[i] = i end
    end
    local head = {}
    for i, c in ipairs(pick) do head[i] = names[c] end
    local out = {table.concat(head, ",")}
    local next_t = nil
    for n = 2, #lines do
        local f = split(lines[n])
        local t = tonumber(f[col.t])
        if t and (not opts.t0 or t >= opts.t0) and (not opts.t1 or t <= opts.t1) then
            if not every or not next_t or t >= next_t - 1e-9 then
                if every then
                    -- the steps counted from the first row kept: a long frame
                    -- does not shift the ones after it
                    next_t = (next_t or t) + every
                    while next_t <= t + 1e-9 do next_t = next_t + every end
                end
                local row = {}
                for i, c in ipairs(pick) do
                    local v = f[c] or ""
                    row[i] = opts.digits and round(v, opts.digits) or v
                end
                out[#out + 1] = table.concat(row, ",")
            end
        end
    end
    return out
end

local function bytes(out)
    local n = 0
    for _, l in ipairs(out) do n = n + #l + 1 end
    return n
end

-- the cut; with max_bytes its step widened until it fits. Returns the
-- lines and the step used (nil: every row)
function M.slice(lines, opts)
    opts = opts or {}
    assert(lines[1], "an empty recording")
    local every = opts.every
    local out = cut(lines, opts, every)
    if opts.max_bytes then
        local tries = 0
        while bytes(out) > opts.max_bytes do
            every = every and every * 2 or 0.1
            tries = tries + 1
            assert(tries <= 40, "the cut does not fit " .. opts.max_bytes .. " bytes: fewer columns or a shorter range")
            out = cut(lines, opts, every)
            if #out <= 2 then
                assert(bytes(out) <= opts.max_bytes, "the cut does not fit " .. opts.max_bytes .. " bytes: fewer columns")
            end
        end
    end
    return out, every
end

-- the t (seconds from the recording's start) of the n-th mark of an
-- events.csv (sim_t,t,state,from,to)
function M.mark_time(lines, n)
    local k = 0
    for i = 2, #lines do
        local f = split(lines[i])
        if f[3] == "mark" then
            k = k + 1
            if k == n then return tonumber(f[2]) end
        end
    end
    error("the recording's events have " .. k .. " mark(s), not " .. n, 0)
end

function M.read_lines(path)
    local f = assert(io.open(path, "rb"))
    local lines = {}
    for line in f:lines() do lines[#lines + 1] = line end
    f:close()
    return lines
end

if arg and arg[0] and arg[0]:match("csv_slice%.lua$") then
    local path
    local opts = {}
    local around, mark
    local out_path
    local i = 1
    local function numbers(s)
        local list = {}
        for part in (s .. ","):gmatch("([^,]*),") do list[#list + 1] = tonumber(part) or false end
        return list
    end
    while arg[i] do
        local a = arg[i]
        local function value()
            i = i + 1
            local v = arg[i]
            assert(v, "a value after " .. a)
            return v
        end
        if a == "-t" then
            local r = numbers(value())
            opts.t0, opts.t1 = r[1] or nil, r[2] or nil
        elseif a == "-a" then
            around = numbers(value())
            assert(around[1], "-a <t>[,<before>[,<after>]]")
        elseif a == "-k" then
            mark = numbers(value())
            assert(mark[1], "-k <n>[,<before>[,<after>]]")
        elseif a == "-c" then
            opts.cols = {}
            for name in value():gmatch("[^,]+") do opts.cols[#opts.cols + 1] = name end
        elseif a == "-e" then
            opts.every = assert(tonumber(value()), "-e <seconds>")
        elseif a == "-d" then
            opts.digits = assert(tonumber(value()), "-d <digits>")
        elseif a == "-m" then
            opts.max_bytes = assert(tonumber(value()), "-m <bytes>")
        elseif a == "-o" then
            out_path = value()
        elseif not path then
            path = a
        else
            error("what is " .. a .. "?", 0)
        end
        i = i + 1
    end
    if not path then
        io.stderr:write("usage: luajit tests/flight/tools/csv_slice.lua <session.csv> [-t t0,t1] [-a t[,before[,after]]]"
            .. " [-k mark[,before[,after]]] [-c col,col...] [-e seconds] [-d digits] [-m bytes] [-o file]\n")
        os.exit(2)
    end
    if mark then
        local events = path:gsub("[^/\\]*$", "") .. "events.csv"
        around = {M.mark_time(M.read_lines(events), mark[1]), mark[2], mark[3]}
    end
    if around then
        opts.t0 = around[1] - (around[2] or 30)
        opts.t1 = around[1] + (around[3] or 60)
    end
    local ok, out, every = pcall(M.slice, M.read_lines(path), opts)
    if not ok then
        io.stderr:write(tostring(out) .. "\n")
        os.exit(1)
    end
    local f = out_path and assert(io.open(out_path, "wb")) or io.stdout
    f:write(table.concat(out, "\n"), "\n")
    if out_path then f:close() end
    io.stderr:write(string.format("%d rows, %d bytes%s%s\n", #out - 1, bytes(out),
        every and string.format(", one row every %g s", every) or "",
        (opts.t0 or opts.t1) and string.format(", t %s..%s", opts.t0 and string.format("%.1f", opts.t0) or "",
            opts.t1 and string.format("%.1f", opts.t1) or "") or ""))
end

return M
