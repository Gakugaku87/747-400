-- A speed change in VNAV SPD or FLCH SPD in a flight-test recording
-- (2026-11-12; docs/overhaul/notes/ATA-22.md §62): what the airplane did
-- with its flight path while the speed went to a new target, for the speed
-- law's near-level path (B747.70.afds_pitch_model.lua's SPD_LEVEL_FPM).
--   luajit tests/flight/tools/spd_step.lua <session.csv> [least change, kt (10)]
-- A change is a step of the speed law's target of at least that much within
-- a second, or the mode beginning that far off its target, with the pitch
-- FMA VNAV SPD (4) or FLCH SPD (8). The target is the recorder's
-- pitch_target (v12: the speed law's own, protected), else tgt (X-Plane's
-- speed dial: the FMC's or the MCP's speed). The way: VNAV SPD's by the
-- FMC's phase (the climb up, else down), FLCH's to the MCP altitude. For
-- each change, from it until the IAS is within 5 kt of the target (or the
-- mode ends):
--   the vertical speed's least and most (vs_i, the flight model's; the
--   VSI's vs without it), the altitude lost under the highest and gained
--   over the lowest so far, the seconds to within 5 kt and 1 kt, the IAS's
--   furthest past the target in the 60 s after;
--   against the way (faster in a climb, slower in a descent) the check of
--   notes/ATA-22.md §62: the vertical speed not more than 50 fpm past level
--   flight (near level's 100 fpm, less 150 fpm for its capture and the air:
--   an estimate) and no more than 20 ft lost in a climb, gained in a
--   descent.
-- Exit status 1 when a change against the way fails the check.
local path, least = arg[1], tonumber(arg[2] or "10")
assert(path, "usage: spd_step.lua <session.csv> [least change, kt]")

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
        weight = get("weight"), mcp = get("mcp_alt"), phase = get("fvn_phase"), cmd = get("pitch_cmd")}
    local pt = get("pitch_target")
    r.tgt = (pt and pt > 0) and pt or get("tgt")
    if r.t and r.alt and r.ias and r.vs and r.tgt then rows[#rows + 1] = r end
end
f:close()
assert(#rows > 1, "no rows in " .. path)

local FMA = {[4] = "VNAV SPD", [8] = "FLCH SPD"}
local function way_of(r)
    if r.fma == 4 then return (r.phase == 1) and 1 or -1 end
    if r.mcp and r.mcp ~= r.alt then return r.mcp > r.alt and 1 or -1 end
    return 0
end
local function num(v) return (("%.0f"):format(v):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^(-?),", "%1")) end

-- the check's margins: fpm past level flight, ft against the way
local PAST_FPM, PAST_FT = 50, 20
local failed, found = false, 0
local j = 1            -- the row a second before
local i = 2
while i <= #rows do
    local r, p = rows[i], rows[i - 1]
    while rows[j + 1] and rows[j + 1].t <= r.t - 1 do j = j + 1 end
    local from
    if FMA[r.fma] then
        if not FMA[p.fma] and math.abs(r.tgt - r.ias) >= least then
            from = r.ias                      -- the mode begins off its target
        elseif FMA[p.fma] and r.tgt ~= p.tgt and math.abs(r.tgt - rows[j].tgt) >= least then
            from = rows[j].tgt                -- a step of the target
        end
    end
    if not from then
        i = i + 1
    else
        found = found + 1
        local up = r.tgt > r.ias
        local way = way_of(r)
        local against = (way > 0 and up) or (way < 0 and not up)
        local lo, hi, top, bot, lost, gained = r.vs, r.vs, r.alt, r.alt, 0, 0
        local t5, t1, past = nil, nil, nil
        local k = i
        while k <= #rows do
            local x = rows[k]
            if not FMA[x.fma] then break end                                          -- the mode ends
            if k > i and math.abs(x.tgt - rows[k - 1].tgt) >= least then break end   -- the next step
            if not t5 then
                lo, hi = math.min(lo, x.vs), math.max(hi, x.vs)
                top, bot = math.max(top, x.alt), math.min(bot, x.alt)
                lost, gained = math.max(lost, top - x.alt), math.max(gained, x.alt - bot)
                if math.abs(x.ias - x.tgt) <= 5 then t5 = x.t - r.t end
            end
            if not t1 and math.abs(x.ias - x.tgt) <= 1 then t1 = x.t - r.t end
            if t5 then
                -- the furthest past the target in the 60 s after
                if x.t - r.t > t5 + 60 then break end
                past = math.max(past or 0, (x.ias - x.tgt) * (up and 1 or -1))
            end
            k = k + 1
        end
        print(("change %d at t %.1f s: %s, %s ft, %s, target %.0f to %.0f kt at %.1f kt, the way %s%s"):format(
            found, r.t, FMA[r.fma], num(r.alt), r.weight and ("%.1f t"):format(r.weight / 1000) or "weight ?",
            from, r.tgt, r.ias, way > 0 and "up" or (way < 0 and "down" or "none"), against and " (against it)" or ""))
        print(("  V/S at the change %+.0f fpm; until within 5 kt (%s): %+.0f to %+.0f fpm, %.0f ft lost, %.0f ft gained"):format(
            r.vs, t5 and ("%.1f s"):format(t5) or "not reached", lo, hi, lost, gained))
        print(("  within 1 kt after %s; furthest past the target in the next 60 s %s"):format(
            t1 and ("%.1f s"):format(t1) or "not reached", past and ("%+.1f kt"):format(past) or "-"))
        if against then
            local ok
            if way > 0 then ok = lo >= -PAST_FPM and lost <= PAST_FT else ok = hi <= PAST_FPM and gained <= PAST_FT end
            if not t5 then ok = false end
            print(("  near level kept (%s): %s"):format(
                (way > 0 and "not under -%d fpm, no more than %d ft lost" or "not over +%d fpm, no more than %d ft gained"):format(PAST_FPM, PAST_FT),
                ok and "PASS" or (t5 and "FAIL" or "FAIL (the speed not reached)")))
            if not ok then failed = true end
        end
        i = math.max(i + 1, k)
    end
end
if found == 0 then print(("no speed change of %g kt or more in VNAV SPD or FLCH SPD"):format(least)) end
os.exit(failed and 1 or 0)
