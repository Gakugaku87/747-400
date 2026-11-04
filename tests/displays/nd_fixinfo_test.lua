-- Run from the repository root with LuaJIT: luajit tests/displays/nd_fixinfo_test.lua
-- FIX INFO's fixes and PRED ETA-ALT's points on the ND (2026-11-04;
-- notes/ATA-34-61-FMC.md §143): the ND module (plugins/xtlua_nd/scripts/
-- B747.61.xt.nd/B747.61.xt.nd.lua) as XTLua runs it (tests/lib/xtlua.lua)
-- draws the FMC's (laminar/B747/fms/fix/*, the texts as character codes):
-- the fix in the reference symbol (icon 12, a small green circle) with its
-- identifier in green, in MAP, MAP CTR and PLAN (FCOM p.1150; FMSPG p.166);
-- the PRED point as a green profile circle (icon 8) with the entered time
-- or altitude, in MAP and MAP CTR (FCOM p.1149, p.1359).
local T = dofile("tests/lib/check.lua")("nd_fixinfo")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)                   -- MAP
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)                  -- 40 NM
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:callout("flight_start")
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end

local F = "laminar/B747/fms/fix/"
local function text(name, base, s)
    for c = 0, 4 do rt:set(F .. name, base + c, string.byte(s, c + 1) or 0) end
end
-- page 1's fix 20 NM ahead, page 2's 60 NM ahead (beyond 40 NM), page 1's
-- PRED point 10 NM ahead
rt:set(F .. "show", 0, 1)
rt:set(F .. "lat", 0, 35.333)
rt:set(F .. "lon", 0, 140.0)
text("ident", 0, "KOUGA")
rt:set(F .. "show", 1, 1)
rt:set(F .. "lat", 1, 36.0)
rt:set(F .. "lon", 1, 140.0)
text("ident", 5, "XAC")
rt:set(F .. "pred_show", 0, 1)
rt:set(F .. "pred_lat", 0, 35.167)
rt:set(F .. "pred_lon", 0, 140.0)
text("pred_text", 0, "2030Z")

local C = "laminar/B747/nd/capt/text/"
local function find(icon, green)
    for n = 0, 59 do
        if rt:get(C .. "show", n) < 0.5 then break end
        if rt:get(C .. "icon", n) == icon and (green == nil or rt:get(C .. "greentext" .. n) == green) then return n end
    end
    return nil
end

run(0.5)
T.check(find(12, "KOUGA") ~= nil, "MAP 40 NM: KOUGA in the reference symbol (icon 12), its identifier green")
T.equal(find(12, "XAC"), nil, "page 2's XAC 60 NM away: not within 40 NM")
T.check(find(8, "2030Z") ~= nil, "the PRED point: the green profile circle (icon 8) with 2030Z")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 3)                  -- 80 NM
run(0.5)
T.check(find(12, "XAC") ~= nil, "80 NM: XAC too")
rt:set(F .. "pred_show", 0, 0)
run(0.5)
T.equal(find(8, "2030Z"), nil, "the PRED point gone (pred_show 0)")
rt:set(F .. "pred_show", 0, 1)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 3)                   -- PLN
rt:set("sim/cockpit2/EFIS/map_mode", 4)
run(0.5)
T.check(find(12, "KOUGA") ~= nil, "PLAN: the fix (FCOM p.1150: MAP, MAP CTR and PLAN)")
T.equal(find(8, "2030Z"), nil, "PLAN: no PRED point (FCOM p.1149: MAP and MAP CTR)")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)                   -- VOR
rt:set("sim/cockpit2/EFIS/map_mode", 0)
run(0.5)
T.equal(find(12), nil, "VOR: none")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set(F .. "show", 0, 0)
run(0.5)
T.equal(find(12, "KOUGA"), nil, "the fix erased (show 0): gone")
T.done()
