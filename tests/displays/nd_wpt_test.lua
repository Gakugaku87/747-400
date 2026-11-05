-- Run from the repository root with LuaJIT: luajit tests/displays/nd_wpt_test.lua
-- (2026-11-05 review) WPT's waypoints (FCOM p.1040, p.1148: the navigation
-- database's waypoints off the route, cyan, in MAP and MAP CTR at 10, 20
-- and 40 NM): earth_fix.dat read once into 1-degree cells
-- (plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua: fix_line,
-- fix_add, fixes_near), then the ND module (B747.61.xt.nd.lua) as XTLua
-- runs it (tests/lib/xtlua.lua), its file readers on (debug/nd -1). Before:
-- a missing file stopped every module of the plugin, the default data's
-- file only, read again for ever 26 lines a frame (the list minutes
-- behind), longitudes west of 100W without their sign.
local T = dofile("tests/lib/check.lua")("nd_wpt")
local D = dofile("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua")
local xtlua = dofile("tests/lib/xtlua.lua")

-- earth_fix.dat lines (X-Plane's 1200 format: position, identifier,
-- airport or ENRT, region, type, name)
local lat, lon, id = D.fix_line(" 37.618888889 -122.375000000  ALCOE ENRT K2 4530263 ALCOE")
T.check(id == "ALCOE" and math.abs(lat - 37.618889) < 1e-6 and math.abs(lon + 122.375) < 1e-6,
    "a waypoint west of 100W: its longitude negative (before, the sign was cut off)")
lat, lon, id = D.fix_line(" 50.000000000    8.000000000  ABC ENRT ED 2105423 ABC")
T.equal(id, "ABC", "a 3-letter identifier whole (before, ABC EN)")
T.equal(D.fix_line(" 33.492513889    9.217400000  07EBA ENRT DT 2118994 EBA357107"), nil, "an identifier with a digit: left out, as before")
T.equal(D.fix_line("I"), nil, "the header's first line: nothing")
T.equal(D.fix_line("1200 Version - data cycle 2610, build 20260927, metadata FixXP1200."), nil, "the version line: nothing")
T.equal(D.fix_line(""), nil, "a blank line: nothing")
T.equal(D.fix_line("99"), nil, "the end: nothing")

-- the cells: a box round a position, across 180 degrees, at 70N
local g = D.fix_grid()
D.fix_add(g, 0.0, 179.9, "EAST")
D.fix_add(g, 0.0, -179.8, "WEST")
D.fix_add(g, 70.0, 21.5, "NORTH")
D.fix_add(g, 70.0, 23.5, "FAR")
local function near(la, lo, r)
    local found = {}
    D.fixes_near(g, la, lo, r, function(i) found[#found + 1] = i end)
    table.sort(found)
    return table.concat(found, " ")
end
T.equal(near(0.0, -179.95, 40), "EAST WEST", "across 180 degrees: both sides")
T.equal(near(0.0, 179.95, 40), "EAST WEST", "and from the east side")
T.equal(near(70.0, 20.0, 40), "NORTH", "at 70N: 1.5 degrees east (31 NM) in, 3.5 degrees (72 NM) out")
T.equal(near(10.0, 10.0, 40), "", "nothing near: none")

-- the box (also the ND's navaids, 2026-11-05 review): no point within the
-- range left out, at the equator, at 60N and near the pole
local function dest(lat, lon, brg, nm)
    local p1, l1, b, d = math.rad(lat), math.rad(lon), math.rad(brg), nm / 3440
    local p2 = math.asin(math.sin(p1) * math.cos(d) + math.cos(p1) * math.sin(d) * math.cos(b))
    local l2 = l1 + math.atan2(math.sin(b) * math.sin(d) * math.cos(p1), math.cos(d) - math.sin(p1) * math.sin(p2))
    return math.deg(p2), (math.deg(l2) + 540) % 360 - 180
end
local missed = 0
for _, c in ipairs({{0, 10, 40}, {60, 10, 40}, {60, 179.5, 640}, {80, 0, 640}, {-45, -170, 160}}) do
    local dlat, dlon = D.box(c[1], c[3])
    for brg = 0, 355, 5 do
        local la, lo = dest(c[1], c[2], brg, c[3] * 0.999)
        if not D.in_box(la, lo, c[1], c[2], dlat, dlon) then missed = missed + 1 end
    end
end
T.equal(missed, 0, "every point just inside the range in its box (equator, 60N, across 180, 80N, 45S)")
local dlat, dlon = D.box(0, 60)
T.check(math.abs(dlat - 1) < 1e-9 and dlon > 1 and dlon < 1.01, "60 NM at the equator: 1 degree each way")
T.check(not D.in_box(1.2, 10, 0, 10, dlat, dlon) and not D.in_box(0, 11.2, 0, 10, dlat, dlon), "72 NM north or east: out")

-- the ND module with a small earth_fix.dat round 35N 140E
local fixfile = (os.getenv("TEMP") or os.getenv("TMP") or ".") .. "/b747_nd_wpt_test_fix.dat"
local f = assert(io.open(fixfile, "w"))
f:write("I\n1200 Version - data cycle 2610, build 20260927, metadata FixXP1200.\n\n",
    " 35.100000000  140.050000000  ALPHA ENRT RJ 2105423 ALPHA\n",
    " 35.200000000  139.900000000  BRAVO ENRT RJ 2105423 BRAVO\n",
    " 35.050000000  140.020000000  CF34L RJTT RJ 2105423 CF34L\n",
    " 35.900000000  140.000000000  FARAW ENRT RJ 2105423 FARAW\n",
    "99\n")
f:close()

local function nd_runtime(open)
    local rt = xtlua.new()
    local nd = rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
    if open then nd.ns.fix_open = open end
    rt:set("laminar/B747/debug/nd", -1)                               -- the file readers on
    rt:set("sim/flightmodel/position/latitude", 35.0)
    rt:set("sim/flightmodel/position/longitude", 140.0)
    rt:set("sim/cockpit2/EFIS/map_mode", 2)
    rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)               -- MAP
    rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)              -- 40 NM
    rt:set("laminar/B747/pfd/capt/irs", 1)
    rt:callout("flight_start")
    return rt, nd
end
local function run(rt, seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local C = "laminar/B747/nd/capt/text/"
local function slot(rt, text)
    for n = 0, 59 do
        if rt:get(C .. "show", n) < 0.5 then return nil end
        for _, c in ipairs({"whitetext", "bluetext", "redtext", "greentext"}) do
            if rt:get(C .. c .. n) == text then return n, c end
        end
    end
    return nil
end

-- no earth_fix.dat at all (the tests' folder has neither Custom Data nor
-- Resources): the ND runs on (before, a Lua error: every module stopped)
local rt0 = nd_runtime(nil)
rt0:set("laminar/B747/nd/data/capt/wpt", 1)
local ok, err = pcall(run, rt0, 1)
T.check(ok, "no earth_fix.dat: no Lua error (" .. tostring(err) .. ")")
T.equal(rt0:get(C .. "show", 0), 0, "and no WPT symbols")

local rt, nd = nd_runtime(function() return io.open(fixfile, "r") end)
run(rt, 1)
T.equal(slot(rt, "ALPHA"), nil, "WPT off: no waypoints")
rt:set("laminar/B747/nd/data/capt/wpt", 1)
run(rt, 0.5)
local n, c = slot(rt, "ALPHA")
T.check(n ~= nil and c == "bluetext" and rt:get(C .. "icon", n) == 13, "WPT at 40 NM: ALPHA, 6 NM away, in cyan with the waypoint symbol")
T.check(slot(rt, "BRAVO") ~= nil, "and BRAVO")
T.equal(slot(rt, "CF34L"), nil, "not the terminal point with a digit")
T.equal(slot(rt, "FARAW"), nil, "nor FARAW, 54 NM away")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 3)                  -- 80 NM
run(rt, 0.5)
T.equal(slot(rt, "ALPHA"), nil, "80 NM: no waypoints (FCOM p.1040: 10, 20 and 40 NM)")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)
rt:set("sim/flightmodel/position/latitude", 35.8)
run(rt, 0.5)
T.check(slot(rt, "FARAW") ~= nil, "the airplane 48 NM north: FARAW within 0.5 s (before, after the next minutes-long pass)")
T.equal(slot(rt, "ALPHA"), nil, "and ALPHA, now 42 NM behind, gone")
os.remove(fixfile)
T.done()
