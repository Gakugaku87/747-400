-- Run from the repository root with LuaJIT: luajit tests/displays/nd_line_view_test.lua
-- Each ND's map for the route line the FMS bridge plugin draws (6-1/6-2
-- step 6d2; notes/ATA-34-61-FMC.md §132): the ND map module (plugins/
-- xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua) as XTLua runs it
-- (tests/lib/xtlua.lua), laminar/B747/nd/line/view: the view (none without
-- the side's IRS, in APP and VOR; MAP, MAP CTR, PLAN: FCOM p.1147), the
-- map's centre, the true direction up as the route's symbols' bearings
-- (nd_bearing), the pixels per NM (465 for the selected range, MAP CTR's
-- half).
local T = dofile("tests/lib/check.lua")("nd_line_view")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)     -- the symbols, not the navigation data files (none here)
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local ND = "laminar/B747/nd/"
local function view(k) return rt:get(ND .. "line/view[" .. k .. "]") end
rt:set("sim/flightmodel/position/latitude", 34.6)
rt:set("sim/flightmodel/position/longitude", 134.5)
rt:set("sim/flightmodel/position/psi", 93)                          -- true heading
rt:set("sim/cockpit/gyros/psi_ind_ahars_pilot_degm", 100)          -- magnetic: 7 west
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_pilot", 106)
rt:set("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_pilot", 100)
rt:set("sim/cockpit2/gauges/indicators/ground_track_mag_copilot", 106)
rt:set("sim/cockpit2/gauges/indicators/heading_AHARS_deg_mag_copilot", 100)
rt:set("sim/flightmodel/position/magnetic_variation", -7)
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:set(ND .. "mode/capt/sel_dial_pos", 2)                          -- MAP
rt:set(ND .. "mode/fo/sel_dial_pos", 2)
rt:set(ND .. "range/capt/sel_dial_pos", 1)                         -- 20 NM
rt:set(ND .. "range/fo/sel_dial_pos", 2)                           -- 40 NM
rt:set(ND .. "map_center/fo", 1)                                   -- MAP CTR
rt:callout("flight_start")
frames(0.5)
T.equal(view(0), 1, "the Captain's MAP: expanded")
T.near(view(1), 34.6, 1e-6, "its centre the airplane")
T.near(view(2), 134.5, 1e-6, "its longitude")
T.near(view(3), 99, 1e-6, "up the true track (106 magnetic, 7 west)")
T.near(view(4), 465 / 20, 1e-6, "20 NM: 465 pixels")
T.equal(view(5), 2, "the F/O's MAP CTR")
T.near(view(9), 232.5 / 40, 1e-6, "40 NM: the rose's 232.5 pixels")
rt:set(ND .. "mode/capt/sel_dial_pos", 3)                          -- PLN
frames(0.5)
T.equal(view(0), 3, "PLAN")
T.near(view(3), 0, 1e-6, "PLAN: true north up (FCOM p.1110; before, magnetic as X-Plane's PLN map)")
rt:set(ND .. "mode/capt/sel_dial_pos", 1)                          -- VOR
rt:set(ND .. "mode/fo/sel_dial_pos", 0)                            -- APP
frames(0.5)
T.equal(view(0), 0, "VOR: no route line")
T.equal(view(5), 0, "APP: none")
rt:set(ND .. "mode/capt/sel_dial_pos", 2)
rt:set("laminar/B747/pfd/capt/irs", 0)
frames(0.5)
T.equal(view(0), 0, "no IRS: none (as the symbols)")
T.done()
