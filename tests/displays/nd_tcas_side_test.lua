-- Run from the repository root with LuaJIT: luajit tests/displays/nd_tcas_side_test.lua
-- The ND module's traffic symbols (plugins/xtlua_nd/scripts/B747.61.xt.nd/
-- B747.61.xt.nd.lua, tcasSide) as XTLua runs it (tests/lib/xtlua.lua): each
-- ND's traffic bearing from its own side's track (MAP) or heading (VOR,
-- APP), as its other symbols (nd_bearing; FCOM p.1109-1110). Review
-- 2026-11-05: the F/O's ND took the Captain's track in MAP and the
-- airplane's true heading in VOR and APP.
local T = dofile("tests/lib/check.lua")("nd_tcas_side")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -3)     -- stop before the navigation data files (none here)
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local I = "sim/cockpit2/gauges/indicators/"
local ND = "laminar/B747/nd/"
local TG = "sim/cockpit2/tcas/targets/position/"
rt:set("sim/version/xplane_internal_version", 120100)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/flightmodel/position/psi", 90)                -- true heading
rt:set("sim/cockpit/gyros/psi_ind_ahars_pilot_degm", 90)  -- no variation
rt:set(I .. "ground_track_mag_pilot", 92)
rt:set(I .. "heading_AHARS_deg_mag_pilot", 90)
rt:set(I .. "ground_track_mag_copilot", 100)              -- the F/O's own sources
rt:set(I .. "heading_AHARS_deg_mag_copilot", 95)
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:set(ND .. "capt/tcas_show", 1)
rt:set(ND .. "fo/tcas_show", 1)
rt:set(ND .. "mode/capt/sel_dial_pos", 2)                 -- MAP
rt:set(ND .. "mode/fo/sel_dial_pos", 2)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("sim/cockpit2/EFIS/map_mode_copilot", 2)
rt:set(ND .. "range/capt/sel_dial_pos", 2)                -- 40 NM
rt:set(ND .. "range/fo/sel_dial_pos", 2)
-- one traffic 10 NM due east (true 090), at the airplane's level
rt:set("laminar/B747/tcas/sym", 1, 3)                     -- a TA
rt:set(TG .. "lat", 1, 35.0)
rt:set(TG .. "lon", 1, 140.0 + 10 / (60 * math.cos(math.rad(35.0))))
rt:set(TG .. "ele", 0, 10000)
rt:set(TG .. "ele", 1, 10000)
rt:callout("flight_start")
frames(0.2)
local c = rt:get(ND .. "capt/tcas/heading", 0)
local f = rt:get(ND .. "fo/tcas/heading", 0)
T.equal(rt:get(ND .. "capt/tcas/show", 0), 1, "the Captain's ND: the traffic drawn")
T.equal(rt:get(ND .. "fo/tcas/show", 0), 1, "the F/O's ND: the traffic drawn")
T.near(c, -2, 0.3, "the Captain's MAP: 090 against the pilot track 092 (" .. c .. ")")
T.near(f, -10, 0.3, "the F/O's MAP: against the copilot track 100 (before: the Captain's, -2) (" .. f .. ")")
rt:set(ND .. "mode/capt/sel_dial_pos", 1)                 -- VOR
rt:set(ND .. "mode/fo/sel_dial_pos", 0)                   -- APP
rt:set("sim/cockpit2/EFIS/map_mode", 1)
rt:set("sim/cockpit2/EFIS/map_mode_copilot", 0)
frames(0.1)
c = rt:get(ND .. "capt/tcas/heading", 0)
f = rt:get(ND .. "fo/tcas/heading", 0)
T.near(c, 0, 0.3, "the Captain's VOR: against the pilot heading 090 (" .. c .. ")")
T.near(f, -5, 0.3, "the F/O's APP: against the copilot heading 095 (before: the true heading, 0) (" .. f .. ")")
T.done()
