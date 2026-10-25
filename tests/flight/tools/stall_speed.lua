-- The 1 g stall speed in a flight-test recording (tests/flight/measure/
-- stall_*.json), for comparing the custom acf's flight model with the FCTM:
--   luajit tests/flight/tools/stall_speed.lua <session.csv> [alpha mark, deg]
-- n / IAS^2 is proportional to the lift coefficient at low Mach; its largest
-- value (smoothed over 1 s) is CL max, and the 1 g stall speed there is
-- IAS / sqrt(n). Also printed: where the AOA first reaches the mark (default
-- 15 deg, the acf's stall warning AOA), and the FCTM's stall and stick shaker
-- speeds for the weight (10,000 ft, idle thrust, forward CG: FCTM p.261-262
-- (7.13-7.14), digitized in notes/FCTM.md section 1.14). A maximum at the end
-- of the recording means the airplane had not stalled yet.
local path, alpha_mark = arg[1], tonumber(arg[2] or "15")
assert(path, "usage: stall_speed.lua <session.csv> [alpha mark]")

-- FCTM: weight (t) -> {shaker, stall} kt, flaps UP, 10, 20 and 30 (gear down)
local W = {200, 220, 240, 260, 280, 300, 320, 340, 360, 380, 400}
local FCTM = {
    [0] = {{163.5, 146.1}, {172.2, 153.7}, {180.8, 161.1}, {189.2, 168.6}, {197.3, 176.7}, {204.7, 183.5},
           {212.3, 190.2}, {219.7, 196.9}, {227.0, 203.7}, {234.0, 210.4}, {240.6, 216.2}},
    [10] = {{123.8, 117.4}, {129.8, 123.2}, {135.8, 128.8}, {141.8, 134.6}, {148.4, 140.7}, {153.6, 145.7},
            {158.9, 150.8}, {164.1, 155.7}, {169.4, 160.7}, {174.6, 165.6}, {178.8, 169.8}},
    [20] = {{118.3, 113.6}, {123.9, 119.1}, {129.6, 124.7}, {135.1, 130.3}, {141.3, 136.3}, {146.3, 141.2},
            {151.3, 146.1}, {156.2, 150.8}, {160.9, 155.7}, {166.0, 160.6}, {170.1, 164.7}},
    [30] = {{110.7, 105.2}, {115.6, 109.9}, {120.5, 114.8}, {125.4, 119.6}, {130.3, 124.4}, {135.1, 129.3},
            {140.1, 134.2}, {145.0, 138.9}, {149.9, 143.8}, {154.8, 148.5}, {159.6, 153.3}},
}
local function fctm(flap_deg, t)
    local rows = FCTM[flap_deg]
    if not rows then return nil end
    local i = 1
    while i < #W - 1 and W[i + 1] < t do i = i + 1 end
    local f = (t - W[i]) / (W[i + 1] - W[i])
    return rows[i][1] + (rows[i + 1][1] - rows[i][1]) * f, rows[i][2] + (rows[i + 1][2] - rows[i][2]) * f
end

local f = assert(io.open(path, "rb"))
local col, n = {}, 0
for name in f:read("*l"):gmatch("[^,]+") do n = n + 1; col[name] = n end
for _, c in ipairs({"t", "ias", "gload", "alpha", "alt", "vs", "weight", "flap"}) do
    assert(col[c], "no column " .. c)
end
local rows = {}
for line in f:lines() do
    local v = {}
    for x in line:gmatch("[^,]+") do v[#v + 1] = tonumber(x) or 0 end
    if #v >= col.gload then rows[#rows + 1] = v end
end
f:close()
assert(#rows > 30, "too few rows")

-- n swings with the A/P's pitch control, so average n and IAS^2 over HALF
-- seconds each side (by time: the recording runs at the frame rate). Only
-- the flight above 1,000 ft RA counts (a descent that never stalls ends on
-- the water).
local HALF = 1.0
local cut = #rows
for r = 1, #rows do
    if rows[r][col.ra] and rows[r][col.ra] < 1000 then cut = r - 1; break end
end
local best, besti, marked = -1, nil, nil
local a, b, sn, sv = 1, 0, 0, 0
for r = 1, cut do
    local t = rows[r][col.t]
    while b < cut and rows[b + 1][col.t] <= t + HALF do
        b = b + 1; sn = sn + rows[b][col.gload]; sv = sv + rows[b][col.ias] ^ 2
    end
    while rows[a][col.t] < t - HALF do
        sn = sn - rows[a][col.gload]; sv = sv - rows[a][col.ias] ^ 2; a = a + 1
    end
    local s = sn / sv
    if s > best and rows[r][col.ias] > 60 then best, besti = s, r end
    if not marked and rows[r][col.alpha] >= alpha_mark then marked = r end
end
local v = rows[besti]
local tons = v[col.weight] / 1000
local lever = v[col.flap]
local flap_deg = lever < 0.01 and 0 or math.abs(lever - 0.5) < 0.01 and 10 or math.abs(lever - 0.6667) < 0.01 and 20
    or lever > 0.99 and 30 or nil
print(string.format("%d rows, %.1f s; weight %.0f kg; flap lever %.3f", #rows, rows[#rows][col.t] - rows[1][col.t],
    v[col.weight], lever))
print(string.format("CL max at t %.1f s: IAS %.1f kt, n %.3f, alpha %.1f deg, %.0f ft, %.0f fpm%s", v[col.t], v[col.ias],
    v[col.gload], v[col.alpha], v[col.alt], v[col.vs],
    v[col.t] > rows[cut][col.t] - HALF - 0.5 and "  (the end of the recording: not stalled yet)" or ""))
print(string.format("1 g stall speed: %.1f kt (n and IAS^2 averaged over %.0f s)", 1 / math.sqrt(best), 2 * HALF))
if col.elevator_ratio then
    print(string.format("elevator at CL max: %.2f (1 is full nose up: there, the elevator limits the AOA, not the stall)",
        v[col.elevator_ratio]))
end
if cut < #rows then print(string.format("cut at t %.1f s (below 1,000 ft RA)", rows[cut + 1][col.t])) end
if marked then
    local m = rows[marked]
    print(string.format("alpha %.0f deg first at t %.1f s: IAS %.1f kt, n %.3f (1 g: %.1f kt)", alpha_mark, m[col.t],
        m[col.ias], m[col.gload], m[col.ias] / math.sqrt(m[col.gload])))
end
local ss, st = fctm(flap_deg, tons)
if ss then
    print(string.format("FCTM (flaps %d, 10,000 ft, idle, forward CG) at %.1f t: stall %.1f kt, stick shaker %.1f kt",
        flap_deg, tons, st, ss))
end
