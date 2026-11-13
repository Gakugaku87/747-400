-- Run from the repository root with LuaJIT: luajit tests/displays/nd_alt_arc_test.lua
-- (2026-11-13; the 2026-11-12 review DSP-1, 案 12) The ND's altitude range
-- arc (plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua's
-- compute_and_show_alt_range_arc): where the MCP altitude is reached at the
-- present vertical speed and ground speed (FCOM p.1148), each side on its
-- own VSI and altimeter, in any pitch mode, only closing on the MCP
-- altitude. Before: VNAV PTH and V/S took the MCP's V/S window (nothing
-- writes it while VNAV flies: no arc with the window 0, 62.5 NM for 25 NM
-- with -800 left in it), V/S away from the MCP altitude put the arc behind
-- the airplane's symbol, and the F/O's side took the captain's instruments.
local T = dofile("tests/lib/check.lua")("nd_alt_arc")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)     -- MAP
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:callout("flight_start")
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end

local RANGES = {10, 20, 40, 80, 160, 320, 640}
-- o: mode, alt, mcp, vvi (the captain's), dial, gs, range (the dial's
-- position), hold, alt_fo, vvi_fo (the F/O's; default the captain's)
local function arc(o)
    rt:set("laminar/B747/autopilot/FMA/active_pitch_mode", o.mode)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", o.alt)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_copilot", o.alt_fo or o.alt)
    rt:set("laminar/B747/autopilot/altitude_dial_ft", o.mcp)
    rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_pilot", o.vvi)
    rt:set("sim/cockpit2/gauges/indicators/vvi_fpm_copilot", o.vvi_fo or o.vvi)
    rt:set("sim/cockpit2/autopilot/vvi_dial_fpm", o.dial or 0)
    rt:set("sim/flightmodel2/position/groundspeed", o.gs * 1852 / 3600)
    rt:set("laminar/B747/nd/range/capt/sel_dial_pos", o.range)
    rt:set("laminar/B747/nd/range/fo/sel_dial_pos", o.range)
    rt:set("laminar/B747/autopilot/altitude_hold_status", o.hold or 0)
    run(0.5)
    local per_nm = 640 / RANGES[o.range + 1]
    local function side(s)
        local d = rt:get("laminar/B747/nd/toc/distance/" .. s)
        return rt:get("laminar/B747/nd/toc/" .. s .. "_active"), d / per_nm
    end
    local ac, dc = side("capt")
    local af, df = side("fo")
    return ac, dc, af, df
end

-- FLCH from 20,000 to 10,000 ft at -2,000 fpm, 300 kt over the ground: 25 NM
local a, d = arc{mode = 8, alt = 20000, mcp = 10000, vvi = -2000, gs = 300, range = 3}
T.equal(a, 1, "FLCH down at -2,000 fpm: the arc")
T.near(d, 25, 0.1, "  at 25 NM (10,000 ft at 2,000 fpm, 300 kt)")
-- VNAV PTH: the V/S window 0 (never used) or a value left in it
a, d = arc{mode = 6, alt = 20000, mcp = 10000, vvi = -2000, dial = 0, gs = 300, range = 3}
T.equal(a, 1, "VNAV PTH, the V/S window 0: the arc (before none)")
T.near(d, 25, 0.1, "  at 25 NM")
a, d = arc{mode = 6, alt = 20000, mcp = 10000, vvi = -2000, dial = -800, gs = 300, range = 3}
T.near(d, 25, 0.1, "VNAV PTH, -800 left in the window: 25 NM (before 62.5)")
a, d = arc{mode = 6, alt = 11500, mcp = 10000, vvi = -2000, dial = 1500, gs = 300, range = 3}
T.near(d, 3.75, 0.05, "VNAV PTH, +1,500 left in the window, 1,500 ft to go: 3.75 NM ahead (before 5 NM behind)")
-- V/S away from the MCP altitude (a non-precision approach with the missed
-- approach altitude set): no arc
a = arc{mode = 7, alt = 4700, mcp = 5000, vvi = -700, dial = -700, gs = 140, range = 0}
T.equal(a, 0, "V/S -700 with the MCP 300 ft above: no arc (before 1 NM behind the airplane)")
a, d = arc{mode = 7, alt = 5000, mcp = 2000, vvi = -700, dial = -700, gs = 140, range = 1}
T.equal(a, 1, "V/S -700 down to the MCP altitude 3,000 ft below: the arc")
T.near(d, 10, 0.05, "  at 10 NM (140 kt, 4.3 minutes)")
-- each side its own instruments
local ac, dc, af, df = arc{mode = 8, alt = 20000, mcp = 10000, vvi = -2000, vvi_fo = -1000, gs = 300, range = 4}
T.near(dc, 25, 0.1, "the captain's VSI -2,000 fpm: 25 NM on the captain's ND")
T.near(df, 50, 0.1, "the F/O's VSI -1,000 fpm: 50 NM on the F/O's (before the captain's 25)")
-- slower than 500 fpm, ALT HOLD, outside the range
a = arc{mode = 8, alt = 20000, mcp = 10000, vvi = -300, gs = 300, range = 3}
T.equal(a, 0, "under 500 fpm: none (as before)")
a = arc{mode = 9, alt = 20000, mcp = 10000, vvi = -2000, gs = 300, range = 3, hold = 2}
T.equal(a, 0, "ALT HOLD: none")
a = arc{mode = 8, alt = 20000, mcp = 10000, vvi = -2000, gs = 300, range = 1}
T.equal(a, 0, "25 NM on the 20 NM range: none")
T.done()
