-- Run from the repository root with LuaJIT: luajit tests/displays/nd_airports_test.lua
-- The ND's origin and destination airports and their runways (5-2 step 5c,
-- FCOM p.1149): the pure functions of
-- plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua, then the ND
-- module (B747.61.xt.nd.lua) as XTLua runs it (tests/lib/xtlua.lua): the
-- route's ends and runways, the runway to scale with its dashed centrelines
-- on 10 to 40 NM, the airport symbol on 80 NM and more, MAP, MAP CTR and
-- PLAN only, whatever ARPT, the route's waypoints in MAP, MAP CTR and PLAN
-- only (FCOM p.1148). Made-up airports and CIFP lines.
local T = dofile("tests/lib/check.lua")("nd_airports")
local D = dofile("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua")
local xtlua = dofile("tests/lib/xtlua.lua")
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= tol end

-- runway identifiers
T.equal(D.rwy_id("RW25C"), "25C", "RW25C: 25C")
T.equal(D.rwy_id("RW18"), "18", "RW18: 18")
T.equal(D.rwy_id("FR"), nil, "a navaid: no runway")
T.equal(D.rwy_id("RWY"), nil, "RWY: no runway")
T.equal(D.rwy_opposite("RW25C"), "RW07C", "RW25C's other end RW07C")
T.equal(D.rwy_opposite("RW26R"), "RW08L", "RW26R's RW08L")
T.equal(D.rwy_opposite("RW08L"), "RW26R", "RW08L's RW26R")
T.equal(D.rwy_opposite("RW18"), "RW36", "RW18's RW36")
T.equal(D.rwy_opposite("RW36"), "RW18", "RW36's RW18")

-- the route's ends ([2] type, [5] [6] position, [8] identifier)
local function e(t, lat, lon, id) return {0, t, 0, 0, lat, lon, 0, id, 0, false} end
local o, orw, d, drw = D.route_ends({e(1, 35.0, 140.0, "ZZAA"), e(2048, 35.0, 139.99, "RW09"), e(512, 35.3, 140.0, "WPT1"),
    e(512, 35.45, 140.0, "FI36"), e(2048, 35.483, 140.0, "RW36"), e(512, 35.55, 140.0, "MA01"), e(1, 35.5, 140.0, "ZZBB")})
T.check(o == 1 and orw == 2 and d == 7 and drw == 5,
    "X-Plane's route: the origin first, its runway after it, the destination last, its runway before the missed approach")
o, orw, d, drw = D.route_ends({e(1, 35.0, 140.0, "ZZAA")})
T.check(o == 1 and orw == nil and d == nil and drw == nil, "the origin alone")
o, orw, d, drw = D.route_ends({e(2, 35.0, 140.0, "NDB"), e(4, 35.2, 140.0, "VOR"), e(1, 35.5, 140.0, "ZZBB")})
T.check(o == nil and d == 3, "a route from a navaid: the destination only")
o, orw, d, drw = D.route_ends({e(1, 35.0, 140.0, "ZZAA"), e(2048, 35.2, 140.0, "RW09"), e(1, 35.5, 140.0, "ZZBB")})
T.check(orw == nil and drw == nil, "a runway entry 12 NM from both airports: neither's runway")
T.check(select(1, D.route_ends({})) == nil, "no route: nothing")

-- CIFP lines (made up)
local id, lat, lon, disp = D.cifp_rwy("RWY:RW09 ,     ,      ,00100, ,IZZA,3,   ;N35000000,E139592000,0300;")
T.check(id == "RW09" and near(lat, 35.0, 1e-9) and near(lon, 139.988889, 1e-6) and disp == 300,
    "a CIFP runway line: RW09 at 35N 139 59 20E, 300 ft displaced")
id, lat, lon = D.cifp_rwy("RWY:RW04L,     ,      ,00012, ,    , ,   ;S33561234,W118243500,0000;")
T.check(id == "RW04L" and near(lat, -33.936761, 1e-6) and near(lon, -118.409722, 1e-6), "south and west")
T.equal(D.cifp_rwy("APPCH:010,A,I36,ZZB,FI36,ZZ,P,C,E  F, ,   ,TF, , , , , ,      ,    ,    ,     ,     ,  ;"), nil,
    "a procedure line: nothing")

-- a runway 1 NM east-west (the selected threshold the west one)
local east = 1 / (60 * math.cos(math.rad(35)))
local mlat, mlon, len, brg = D.runway(35.0, 140.0, 0, 35.0, 140.0 + east, 0)
T.check(near(mlat, 35.0, 1e-6) and near(mlon, 140.0 + east / 2, 1e-5) and near(len, 1.0, 1e-3) and near(brg, 270, 0.01),
    "1 NM runway: its middle, length, bearing west to the selected end")
mlat, mlon, len = D.runway(35.0, 140.0, 607.612, 35.0, 140.0 + east, 0)
T.check(near(len, 1.1, 1e-3) and near(mlon, 140.0 + east * 0.45, 1e-5), "the selected end 0.1 NM behind a displaced threshold")
T.equal(D.runway(35.0, 140.0, 0, 35.0, 140.0, 0), nil, "thresholds at one place: nothing")

-- the map's visible part
T.check(D.inside(0, 100, D.EXPANDED) and not D.inside(0, -1, D.EXPANDED), "expanded: ahead, not behind")
T.check(D.inside(340, 100, D.EXPANDED) and not D.inside(-330, 100, D.EXPANDED), "expanded: within the sides 329 left, 348 right")
T.check(not D.inside(0, 466, D.EXPANDED), "expanded: within the range arc")
T.check(D.inside(0, -181, D.CENTRED) and not D.inside(0, 182, D.CENTRED), "MAP CTR: 181.6 pixels round")
T.check(D.inside(0, -326, D.PLAN) and not D.inside(0, 328, D.PLAN), "PLAN: 327 pixels round")
T.check(D.rwy_frame(4) == 0 and D.rwy_frame(100) == 24 and D.rwy_frame(1000) == 39 and D.rwy_frame(0) == 0,
    "the runway image's frames: 4 px the first, 100 px the 25th, at most the 40th")

-- the dashes: a runway 50 px long at 200 px ahead, up the display, 10 NM
local buf = {}
D.dashes(0, 200, 0, 50, 46.5, D.EXPANDED, buf, 0)
local function count(b, from, n) local c = 0 for j = from, from + n - 1 do c = c + b[j] end return c end
T.equal(count(buf, 0, 30), 11, "10 NM: 11 dashes beyond the top end up to the range arc")
T.equal(count(buf, 30, 30), 8, "and 8 beyond the other down to the airplane")
D.dashes(0, 200, 0, 50, 11.625, D.EXPANDED, buf, 60)
T.check(count(buf, 60, 30) == 8 and count(buf, 90, 30) == 8, "40 NM: 14.2 NM is 8 dashes each side")

-- the ND module: the airplane at 35.2N 140E, north; ZZAA 12 NM behind with
-- RW09 selected, ZZBB 18 NM ahead with RW36 selected; the CIFP file's
-- other ends (made up)
local cifp_file = os.tmpname()
local cf = assert(io.open(cifp_file, "w"))
cf:write("APPCH:010,A,I36,ZZB,FI36,ZZ,P,C,E  F, ,   ,TF, , , , , ,      ,    ,    ,     ,     ,  ;\n",
    "RWY:RW09 ,     ,      ,00100, ,    , ,   ;N35000000,E139592000,0000;\n",
    "RWY:RW27 ,     ,      ,00100, ,    , ,   ;N35000000,E140010000,0000;\n",
    "RWY:RW18 ,     ,      ,00100, ,    , ,   ;N35310000,E140000000,0000;\n",
    "RWY:RW36 ,     ,      ,00100, ,IZZB,3,   ;N35290000,E140000000,0000;\n")
cf:close()
local rt = xtlua.new()
local nd = rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
local opened = {}
nd.ns.cifp_open = function(apt)
    opened[#opened + 1] = apt
    return io.open(cifp_file, "r")
end
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.2)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)                   -- MAP
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)                  -- 40 NM
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:callout("flight_start")
local fms = '[[1,1,0,0,35.0,140.0,0,"ZZAA",100,false],[2,2048,0,0,35.0,139.988889,0,"RW09",100,false],'
    .. '[3,512,0,0,35.3,140.0,0,"WPT1",0,true],[4,2048,0,0,35.483333,140.0,0,"RW36",100,false],'
    .. '[5,512,0,0,35.55,140.0,0,"MA01",0,false],[6,1,0,0,35.5,140.0,0,"ZZBB",100,false]]'
rt:set("xtlua/fms", fms)
nd.ns.decodeFlightPlan()
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
run(0.2)
for _ = 1, 4 do nd.ns.read_cifp() end          -- the after_physics chunks (debug/nd -2 leaves them)
T.check(opened[1] == "ZZAA" and opened[2] == "ZZBB" and opened[3] == nil, "each airport's CIFP file read once")
run(0.5)
local A = "laminar/B747/nd/capt/apt/"
local function get(f, k) return rt:get(A .. f, k) end
T.equal(get("rwy_show", 1), 1, "40 NM: ZZBB's runway 36 to scale (FCOM p.1149)")
T.equal(get("sym", 1), 0, "without the airport symbol")
T.equal(rt:get(A .. "rwy1"), "36", "its identifier 36")
T.check(near(get("rwy_heading", 1), 0, 0.5) and near(get("rwy_distance", 1), 18 * 16, 3),
    "its middle 18 NM ahead (640 units for 40 NM)")
T.check(near(get("thr_heading", 1), 0, 0.5) and near(get("thr_distance", 1), 17 * 16, 3), "the threshold 17 NM ahead")
T.check(near(get("dir", 1), 180, 0.5), "turned to its selected threshold's end, toward the airplane")
T.check(near(get("rwy_len", 1), 2 * 11.625, 0.3) and get("rwy_frame", 1) == 5, "2 NM long: 23 px, the 6th frame")
local dashes = {}
for j = 0, 119 do dashes[j] = rt:get(A .. "dash", j) end
T.check(count(dashes, 60, 30) == 8 and count(dashes, 90, 30) == 8, "its centrelines: 14.2 NM of dashes from both ends")
T.check(count(dashes, 0, 60) == 0, "ZZAA behind the airplane: nothing (expanded MAP)")
T.check(get("rwy_show", 0) == 0 and get("sym", 0) == 0, "nor its runway or symbol")
-- the slots: WPT1 a route waypoint, not the airports' or runways'
local C = "laminar/B747/nd/capt/text/"
local function slot(text)
    for n = 0, 59 do
        if rt:get(C .. "show", n) < 0.5 then return nil end
        for _, c in ipairs({"whitetext", "bluetext", "redtext", "greentext"}) do
            if rt:get(C .. c .. n) == text then return n, c end
        end
    end
    return nil
end
T.check(slot("WPT1") ~= nil, "the active waypoint WPT1 in its slot")
T.check(slot("RW36") == nil and slot("ZZBB") == nil, "RW36 and ZZBB not route waypoints any more (the runway's symbol)")
T.equal(get("thr_show", 1), 1, "the threshold on the map: its identifier")
-- 10 NM: the runway off the map ahead, its centreline's dashes toward the
-- airplane on it
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 0)
run(0.5)
for j = 0, 119 do dashes[j] = rt:get(A .. "dash", j) end
T.check(get("rwy_show", 1) == 1 and get("rwy_frame", 1) == -1 and get("thr_show", 1) == 0,
    "10 NM: ZZBB's runway 17 NM ahead off the map, without its outline and identifier")
local c10 = count(dashes, 60, 30)
T.check(c10 >= 14 and c10 <= 16 and count(dashes, 90, 30) == 0,
    "but the dashes of its centreline toward the airplane within the range arc (" .. c10 .. ")")
-- 80 NM: the airport symbol and the line along the runway
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 3)
run(0.5)
T.check(get("sym", 1) == 1 and get("rwy_show", 1) == 0, "80 NM: ZZBB's airport symbol, not the runway")
T.check(get("line", 1) == 1 and near(get("dir", 1), 180, 0.5), "its line along runway 36 toward the selected threshold's end")
T.check(rt:get(A .. "id1") == "ZZBB" and rt:get(A .. "rwy1") == "36", "ZZBB and 36 under it")
T.check(near(get("heading", 1), 0, 0.5) and near(get("distance", 1), 18 * 8, 2), "at the airport 18 NM ahead (80 NM)")
for j = 0, 119 do dashes[j] = rt:get(A .. "dash", j) end
T.equal(count(dashes, 0, 120), 0, "no dashes")
-- ARPT: the other airports in blue, ZZBB still its own symbol
rt:set("laminar/B747/nd/data/capt/apt", 1)
rt:set("xtlua/navaids", '[[1,1,0,0,35.5,140.0,0,"ZZBB"],[2,1,0,0,35.4,140.1,0,"ZZCC"]]')
nd.ns.decodeNAVAIDS()
run(0.5)
local n, c = slot("ZZCC")
T.check(n ~= nil and c == "bluetext", "ARPT: ZZCC in blue")
T.equal(slot("ZZBB"), nil, "but not the destination: its own symbol")
rt:set("laminar/B747/nd/data/capt/apt", 0)
run(0.5)
T.equal(get("sym", 1), 1, "the destination whatever ARPT (FCOM p.1149)")
-- MAP CTR, 40 NM: the origin's runway 12 NM behind within the circle
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)
rt:set("laminar/B747/nd/map_center/capt", 1)
run(0.5)
T.check(get("rwy_show", 0) == 1 and rt:get(A .. "rwy0") == "09", "MAP CTR: ZZAA's runway 09 behind")
T.check(near(math.abs(get("rwy_heading", 0)), 180, 1) and near(get("dir", 0), -90, 1),
    "its middle behind, turned to the west threshold's end")
T.check(get("rwy_show", 1) == 1 and get("rwy_frame", 1) == -1 and get("thr_show", 1) == 0,
    "ZZBB 18 NM ahead beyond the centred circle: only its centreline's dashes within it")
-- PLAN: north up, both
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 3)
rt:set("sim/cockpit2/EFIS/map_mode", 4)
run(0.5)
T.check(get("rwy_show", 0) == 1 and get("rwy_show", 1) == 1, "PLAN: both runways")
T.check(slot("WPT1") ~= nil, "and the route's waypoints")
-- VOR: none, not the route's waypoints either
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)
rt:set("laminar/B747/nd/map_center/capt", 0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)                              -- as the mode selector sets it in VOR
run(0.5)
T.check(get("rwy_show", 0) == 0 and get("rwy_show", 1) == 0 and get("sym", 0) == 0 and get("sym", 1) == 0,
    "VOR: no airports (MAP, MAP CTR and PLAN only)")
T.equal(slot("WPT1"), nil, "nor route waypoints (FCOM p.1148: before, X-Plane's MAP mode drew them)")
-- the F/O's side: its own mode and range
rt:set("laminar/B747/pfd/fo/irs", 1)
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 2)
rt:set("laminar/B747/nd/range/fo/sel_dial_pos", 4)                    -- 160 NM
run(0.5)
T.check(rt:get("laminar/B747/nd/fo/apt/sym", 1) == 1 and rt:get("laminar/B747/nd/fo/apt/rwy_show", 1) == 0,
    "the F/O's ND in MAP at 160 NM: ZZBB's symbol while the Captain's is in VOR")
-- no CIFP file: on 40 NM the airport symbol with the runway's identifier
local rt2 = xtlua.new()
local nd2 = rt2:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
nd2.ns.cifp_open = function() return nil end
rt2:set("laminar/B747/debug/nd", -2)
rt2:set("sim/flightmodel/position/latitude", 35.2)
rt2:set("sim/flightmodel/position/longitude", 140.0)
rt2:set("sim/cockpit2/EFIS/map_mode", 2)
rt2:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)
rt2:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)
rt2:set("laminar/B747/pfd/capt/irs", 1)
rt2:callout("flight_start")
rt2:set("xtlua/fms", fms)
nd2.ns.decodeFlightPlan()
for _ = 1, 3 do nd2.ns.read_cifp() end
for _ = 1, 15 do rt2:frame(1 / 30) end
T.check(rt2:get(A .. "sym", 1) == 1 and rt2:get(A .. "rwy_show", 1) == 0 and rt2:get(A .. "line", 1) == 0,
    "no CIFP file: 40 NM the airport symbol, no runway, no line (estimate)")
T.equal(rt2:get(A .. "rwy1"), "36", "the runway's identifier under it")
os.remove(cifp_file)

T.done()
