-- Run from the repository root with LuaJIT: luajit tests/displays/nd_orientation_test.lua
-- The ND map module's orientation (plugins/xtlua_nd/scripts/B747.61.xt.nd/
-- B747.61.xt.nd.lua, 5-2 step 5a) as XTLua runs it (tests/lib/xtlua.lua):
-- each ND's top (laminar/B747/nd/up/capt|fo) from its own mode selector and
-- its own side's heading and track (FCOM p.1109-1110, 109: MAP track up,
-- VOR and APP heading up, PLN north up). Before, both NDs used the
-- Captain's heading and track and X-Plane's map mode, which made VOR track
-- up. Step 5d: the heading and track in the heading reference, from the
-- display glue (laminar/B747/pfd/capt|fo/hdg_deg, trk_deg: magnetic, or
-- true with TRU).
local T = dofile("tests/lib/check.lua")("nd_orientation")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -3)     -- stop before the navigation data files (none here)
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local P = "laminar/B747/pfd/"
local ND = "laminar/B747/nd/"
rt:set(P .. "capt/hdg_deg", 100)
rt:set(P .. "capt/trk_deg", 106)
rt:set(P .. "fo/hdg_deg", 101)
rt:set(P .. "fo/trk_deg", 107)
rt:set(ND .. "mode/capt/sel_dial_pos", 2)                          -- MAP
rt:set(ND .. "mode/fo/sel_dial_pos", 1)                            -- VOR
rt:callout("flight_start")
frames(0.2)
T.equal(rt:get(ND .. "up/capt"), 106, "the Captain's MAP: the pilot track up")
T.equal(rt:get(ND .. "up/fo"), 101, "the F/O's VOR: the copilot heading up (before: the Captain's track)")
rt:set(ND .. "mode/capt/sel_dial_pos", 0)                          -- APP
rt:set(ND .. "mode/fo/sel_dial_pos", 2)                            -- MAP
frames(0.1)
T.equal(rt:get(ND .. "up/capt"), 100, "APP: heading up")
T.equal(rt:get(ND .. "up/fo"), 107, "the F/O's MAP: the copilot track")
rt:set(ND .. "mode/capt/sel_dial_pos", 3)                          -- PLN
frames(0.1)
T.equal(rt:get(ND .. "up/capt"), 0, "PLN: north up")
rt:set(ND .. "mode/capt/sel_dial_pos", 2)                          -- MAP
rt:set(P .. "capt/trk_deg", 110)                                   -- TRU: the track true
frames(0.1)
T.equal(rt:get(ND .. "up/capt"), 110, "MAP in TRU: the true track up (step 5d)")

T.done()
