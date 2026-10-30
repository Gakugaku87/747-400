-- Run from the repository root with LuaJIT: luajit tests/displays/nd_profile_test.lua
-- The ND's altitude profile points (6-1/6-2 step 8d3; notes/
-- ATA-34-61-FMC.md §50): the ND module (plugins/xtlua_nd/scripts/
-- B747.61.xt.nd/B747.61.xt.nd.lua) as XTLua runs it (tests/lib/xtlua.lua)
-- draws the FMC's points (laminar/B747/fms/profile/*: the trajectory
-- predictions') as green circles: T/C, S/C, T/D, E/D with their
-- identifiers, the deceleration points without (FCOM p.1149), in MAP and
-- MAP CTR only, within the selected range.
local T = dofile("tests/lib/check.lua")("nd_profile")
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

-- the FMC's points: north of the airplane (ahead, track up at 000) but the
-- S/C south (behind) and the E/D 90 NM away
local PR = "laminar/B747/fms/profile/"
local function point(k, kind, lat, lon)
    rt:set(PR .. "kind", k, kind)
    rt:set(PR .. "lat", k, lat)
    rt:set(PR .. "lon", k, lon)
end
point(0, 1, 35.2, 140.0)      -- T/C, 12 NM
point(1, 3, 35.5, 140.0)      -- T/D, 30 NM
point(2, 5, 35.55, 140.0)     -- a deceleration, 33 NM
point(3, 5, 35.6, 140.05)     -- another
point(4, 4, 36.5, 140.0)      -- E/D, 90 NM
point(5, 2, 34.8, 140.0)      -- S/C, behind

local C = "laminar/B747/nd/capt/text/"
local function shown()
    local list = {}
    for n = 0, 59 do
        if rt:get(C .. "show", n) < 0.5 then break end
        list[#list + 1] = {icon = rt:get(C .. "icon", n), green = rt:get(C .. "greentext" .. n),
            white = rt:get(C .. "whitetext" .. n)}
    end
    return list
end
local function find(text)
    for _, s in ipairs(shown()) do if s.icon == 8 and s.green == text then return s end end
    return nil
end
local function decels()
    local n = 0
    for _, s in ipairs(shown()) do if s.icon == 8 and s.green == " " then n = n + 1 end end
    return n
end

run(0.5)
T.check(find("T/C") ~= nil, "MAP 40 NM: T/C, the green circle (icon 8) and its identifier in green")
T.check(find("T/D") ~= nil, "T/D")
T.equal(decels(), 2, "the two deceleration points, without identifiers")
T.equal(find("E/D"), nil, "E/D 90 NM away: not within 40 NM")
T.equal(find("S/C"), nil, "S/C behind the airplane: not on the expanded map")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 4)                  -- 160 NM
run(0.5)
T.check(find("E/D") ~= nil, "160 NM: E/D")
rt:set(PR .. "kind", 0, 0)
run(0.5)
T.equal(find("T/C"), nil, "a point gone (kind 0): not shown")
T.check(find("T/D") ~= nil, "the others still")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 3)                   -- PLN
rt:set("sim/cockpit2/EFIS/map_mode", 4)
run(0.5)
T.check(find("T/D") == nil and find("E/D") == nil and decels() == 0, "PLAN: none (FCOM p.1149: MAP and MAP CTR)")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)                   -- VOR
rt:set("sim/cockpit2/EFIS/map_mode", 0)
run(0.5)
T.check(find("T/D") == nil and find("E/D") == nil and decels() == 0, "VOR: none")
T.done()
