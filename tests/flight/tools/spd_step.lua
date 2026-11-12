-- A speed change in VNAV SPD or FLCH SPD in a flight-test recording
-- (2026-11-12; docs/overhaul/notes/ATA-22.md §62): what the airplane did
-- with its flight path while the speed went to a new target, for the speed
-- law's near-level path (B747.70.afds_pitch_model.lua's SPD_LEVEL_FPM).
--   luajit tests/flight/tools/spd_step.lua <session.csv> [least change, kt (10)]
-- A change is a step of the speed law's target of at least that much within
-- a second, or the mode beginning that far off its target, with the pitch
-- FMA VNAV SPD (4) or FLCH SPD (8); the target before a step is taken from
-- the same stretch of the mode only. The target is the recorder's
-- pitch_target (v12: the speed law's own, protected), else tgt (X-Plane's
-- speed dial: the FMC's or the MCP's speed). The way: VNAV SPD's by the
-- FMC's phase (the climb up, else down; without that column to the MCP
-- altitude), FLCH's to the MCP altitude; not known, no check. For each
-- change, from it until the IAS is within 5 kt of the target, the next
-- change, the mode's end or the recording's:
--   the vertical speed's least and most (vs_i, the flight model's; the
--   VSI's vs without it), the altitude lost under the highest and gained
--   over the lowest so far, the seconds to within 5 kt and 1 kt, the IAS's
--   furthest past the target in the 60 s after;
--   against the way (faster in a climb, slower in a descent) the check of
--   notes/ATA-22.md §62, on the vertical speed and the altitude alone: the
--   vertical speed not more than 50 fpm past level flight (near level's
--   100 fpm, less 150 fpm for its capture and the air: an estimate) and no
--   more than 20 ft lost in a climb, gained in a descent. A change that
--   begins past that (FLCH up pushed in a descent) is checked from where
--   the vertical speed is back within it; never back, not checked.
-- Exit status 1 when a change against the way fails the check.
--   local S = dofile("tests/flight/tools/spd_step.lua")   -- in the tests:
--   S.analyse(rows, least) with rows of {t, alt, ias, vs, tgt, fma, ...}
local M = {}

-- the check's margins: fpm past level flight, ft against the way
M.PAST_FPM, M.PAST_FT = 50, 20
M.FMA = {[4] = "VNAV SPD", [8] = "FLCH SPD"}

-- the rows of a session.csv: {t, alt, ias, vs, tgt, fma, weight, mcp, phase}
function M.read(path)
    local f = assert(io.open(path, "rb"))
    local col, n = {}, 0
    for name in f:read("*l"):gsub("\r", ""):gmatch("[^,]+") do n = n + 1; col[name] = n end
    for _, c in ipairs({"t", "alt", "ias", "vs", "tgt", "fma"}) do assert(col[c], "no column " .. c) end
    local rows = {}
    for line in f:lines() do
        local v, k = {}, 0
        for field in (line:gsub("\r", "") .. ","):gmatch("([^,]*),") do k = k + 1; v[k] = tonumber(field) end
        local function get(name) return col[name] and v[col[name]] or nil end
        local r = {t = get("t"), alt = get("alt"), ias = get("ias"), fma = get("fma"), vs = get("vs_i") or get("vs"),
            weight = get("weight"), mcp = get("mcp_alt"), phase = get("fvn_phase")}
        local pt = get("pitch_target")
        r.tgt = (pt and pt > 0) and pt or get("tgt")
        if r.t and r.alt and r.ias and r.vs and r.tgt then rows[#rows + 1] = r end
    end
    f:close()
    return rows
end

-- the way at a row: 1 up, -1 down, 0 not known
local function way_of(r)
    if r.fma == 4 and r.phase then return (r.phase == 1) and 1 or -1 end
    if r.mcp and r.mcp ~= r.alt then return r.mcp > r.alt and 1 or -1 end
    return 0
end

-- the changes of the rows: each {t, fma, alt, weight, from, to, ias, way,
-- against, vs0, lo, hi, lost, gained, t5, t1, past, ended ("within",
-- "change", "mode" or "end"), ok (against the way only: the check; nil
-- where the vertical speed never came within the margin)}
function M.analyse(rows, least)
    least = least or 10
    local out = {}
    local j = 1            -- the row a second before
    local start = nil      -- the first row of this stretch of the mode
    local i = 1
    while i <= #rows do
        local r, p = rows[i], rows[i - 1]
        local on = M.FMA[r.fma] ~= nil
        if on and not (p and p.fma == r.fma) then start = i end
        if not on then start = nil end
        while rows[j + 1] and rows[j + 1].t <= r.t - 1 do j = j + 1 end
        local from
        if on then
            if start == i then
                if math.abs(r.tgt - r.ias) >= least then from = r.ias end   -- the mode begins off its target
            else
                local b = rows[math.max(j, start)]
                if r.tgt ~= p.tgt and math.abs(r.tgt - b.tgt) >= least then from = b.tgt end   -- a step of the target
            end
        end
        if not from then
            i = i + 1
        else
            local up = r.tgt > r.ias
            local way = way_of(r)
            local c = {t = r.t, fma = r.fma, alt = r.alt, weight = r.weight, from = from, to = r.tgt, ias = r.ias,
                way = way, against = (way > 0 and up) or (way < 0 and not up), vs0 = r.vs,
                lo = r.vs, hi = r.vs, lost = 0, gained = 0, ended = "end"}
            local top, bot = r.alt, r.alt
            -- the check: the vertical speed turned to the way's sign (w: up
            -- positive), from where it is within the margin
            local sgn = way >= 0 and 1 or -1
            local armed, bad, ref, against_ft = false, false, r.alt, 0
            local k = i
            while k <= #rows do
                local x = rows[k]
                if x.fma ~= r.fma then
                    if not c.t5 then c.ended = "mode" end
                    break
                end
                if k > i and math.abs(x.tgt - rows[k - 1].tgt) >= least then
                    if not c.t5 then c.ended = "change" end
                    break
                end
                if not c.t5 then
                    c.lo, c.hi = math.min(c.lo, x.vs), math.max(c.hi, x.vs)
                    top, bot = math.max(top, x.alt), math.min(bot, x.alt)
                    c.lost, c.gained = math.max(c.lost, top - x.alt), math.max(c.gained, x.alt - bot)
                    local w = x.vs * sgn
                    if not armed then
                        if w >= -M.PAST_FPM then armed, ref = true, x.alt end
                    else
                        if w < -M.PAST_FPM then bad = true end
                        -- the altitude against the way since the best so far
                        if (x.alt - ref) * sgn > 0 then ref = x.alt end
                        against_ft = math.max(against_ft, (ref - x.alt) * sgn)
                    end
                    if math.abs(x.ias - x.tgt) <= 5 then c.t5, c.ended = x.t - r.t, "within" end
                end
                if not c.t1 and math.abs(x.ias - x.tgt) <= 1 then c.t1 = x.t - r.t end
                if c.t5 then
                    -- the furthest past the target in the 60 s after
                    if x.t - r.t > c.t5 + 60 then break end
                    c.past = math.max(c.past or 0, (x.ias - x.tgt) * (up and 1 or -1))
                end
                k = k + 1
            end
            if c.against and armed then c.ok = (not bad) and against_ft <= M.PAST_FT end
            out[#out + 1] = c
            i = math.max(i + 1, k)
        end
    end
    return out
end

local function num(v) return (("%.0f"):format(v):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1")) end
local ENDED = {change = "the next change", mode = "the mode's end", ["end"] = "the recording's end"}

-- the report's lines of a change
function M.lines(n, c)
    local l = {}
    l[1] = ("change %d at t %.1f s: %s, %s ft, %s, target %.0f to %.0f kt at %.1f kt, the way %s%s"):format(
        n, c.t, M.FMA[c.fma], num(c.alt), c.weight and ("%.1f t"):format(c.weight / 1000) or "weight ?",
        c.from, c.to, c.ias, c.way > 0 and "up" or (c.way < 0 and "down" or "not known"), c.against and " (against it)" or "")
    l[2] = ("  V/S at the change %+.0f fpm; until %s: %+.0f to %+.0f fpm, %.0f ft lost, %.0f ft gained"):format(
        c.vs0, c.t5 and ("within 5 kt (%.1f s)"):format(c.t5) or ENDED[c.ended], c.lo, c.hi, c.lost, c.gained)
    l[3] = ("  within 1 kt after %s; furthest past the target in the next 60 s %s"):format(
        c.t1 and ("%.1f s"):format(c.t1) or "not reached", c.past and ("%+.1f kt"):format(c.past) or "-")
    if c.against and c.ok == nil then
        l[4] = "  the change began past near level and the vertical speed never came back within it: no check"
    elseif c.against then
        l[4] = ("  near level kept (%s): %s"):format(
            (c.way > 0 and "not under -%d fpm, no more than %d ft lost" or "not over +%d fpm, no more than %d ft gained"):format(M.PAST_FPM, M.PAST_FT),
            c.ok and "PASS" or "FAIL")
    elseif c.way == 0 then
        l[4] = "  the way not known (no FMC phase or MCP altitude in the recording): no check"
    end
    return l
end

-- run from the command line (not when a test reads this file)
if arg and arg[0] and arg[0]:match("spd_step%.lua$") then
    local path, least = arg[1], tonumber(arg[2] or "10")
    assert(path, "usage: spd_step.lua <session.csv> [least change, kt]")
    local rows = M.read(path)
    assert(#rows > 1, "no rows in " .. path)
    local failed = false
    local changes = M.analyse(rows, least)
    for n, c in ipairs(changes) do
        for _, line in ipairs(M.lines(n, c)) do print(line) end
        if c.against and c.ok == false then failed = true end
    end
    if #changes == 0 then print(("no speed change of %g kt or more in VNAV SPD or FLCH SPD"):format(least)) end
    os.exit(failed and 1 or 0)
end

return M
