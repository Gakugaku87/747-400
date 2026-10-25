-- Run from the repository root with LuaJIT: luajit tests/displays/nd_symbols_test.lua
-- The ND's map symbols (5-2 step 5c): STA's high altitude navaids
-- (plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua: nav_line,
-- nav_near), then the ND module (B747.61.xt.nd.lua) as XTLua runs it
-- (tests/lib/xtlua.lua): STA, WPT and ARPT in MAP and MAP CTR only, the
-- tuned VORs always in green, the navaids on the longer ranges, EXCESS DATA
-- (FCOM p.1040, p.1111, p.1145).
local T = dofile("tests/lib/check.lua")("nd_symbols")
local D = dofile("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.nd_data.lua")
local xtlua = dofile("tests/lib/xtlua.lua")

-- earth_nav.dat lines (X-Plane's format: type, position, elevation,
-- frequency, reception range, variation, identifier, ...)
local id, lat, lon = D.nav_line(" 3  49.790972222    8.542361111      344    11750   130      2.000  FKS ENRT ED FRANKENSTEIN VOR/DME")
T.check(id == "FKS" and math.abs(lat - 49.790972) < 1e-6 and math.abs(lon - 8.542361) < 1e-6, "a VOR of 130 NM: high altitude")
T.equal(D.nav_line(" 3  50.250463889    8.162525000     1336    11335    40      2.000  TAU ENRT ED TAUNUS VOR/DME"), nil, "40 NM: low altitude")
T.equal(D.nav_line(" 2  50.065700000    8.683500000      400      297    50      0.000  FR ENRT ED FRANKFURT NDB"), nil, "an NDB of 50 NM: low altitude")
T.equal(D.nav_line("12  49.790972222    8.542361111      344    11750   130      0.000  FKS ENRT ED FRANKENSTEIN VOR/DME"), nil, "a DME line: not counted")
T.equal(D.nav_line("1200 Version - data cycle 2610"), nil, "the header: nothing")
T.check(D.nav_near({49.79, 8.54}, 49.791, 8.542), "the same identifier nearby: found")
T.check(not D.nav_near({49.79, 8.54}, 49.95, 8.54), "another one 0.16 degree away: not")
T.check(not D.nav_near(nil, 49.79, 8.54), "an identifier never seen: not")

-- the ND module (newIcons every 0.2 s; the navigation data files are not
-- read: debug/nd -2): navaids north of the airplane at 35N 140E
local rt = xtlua.new()
local nd = rt:load("plugins/xtlua_nd/scripts/B747.61.xt.nd/B747.61.xt.nd.lua")
rt:set("laminar/B747/debug/nd", -2)
rt:set("sim/flightmodel/position/latitude", 35.0)
rt:set("sim/flightmodel/position/longitude", 140.0)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)                   -- MAP
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)                  -- 40 NM
rt:set("laminar/B747/pfd/capt/irs", 1)
rt:set("sim/cockpit2/radios/indicators/nav3_nav_id", "AAA")           -- VOR L tuned to AAA
rt:callout("flight_start")
local function navaids(list)
    rt:set("xtlua/navaids", list)
    nd.ns.decodeNAVAIDS()
end
-- [2] type (1 airport, 2 NDB, 4 VOR), [5] latitude, [6] longitude, [8] identifier
navaids('[[1,4,11750,0,35.15,140.0,0,"AAA"],[2,2,300,0,35.2,140.05,0,"BBB"],'
    .. '[3,1,0,0,35.3,139.95,0,"CCCC"],[4,4,11300,0,35.25,140.02,0,"DDD"]]')
local function run(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
local C = "laminar/B747/nd/capt/text/"
-- the slot showing an identifier: its index, or nil
local function slot(text)
    for n = 0, 59 do
        if rt:get(C .. "show", n) < 0.5 then return nil end
        for _, c in ipairs({"whitetext", "bluetext", "redtext", "greentext"}) do
            if rt:get(C .. c .. n) == text then return n, c end
        end
    end
    return nil
end
run(0.5)
local n, c = slot("AAA")
T.check(n ~= nil and c == "greentext", "STA off: the tuned VOR AAA in green (FCOM p.1145: before, only with STA)")
T.equal(rt:get(C .. "icon", n), 10, "with the tuned VOR's symbol")
T.equal(slot("BBB"), nil, "STA off: no NDB")
T.equal(slot("DDD"), nil, "nor the untuned VOR")
T.equal(slot("CCCC"), nil, "ARPT off: no airport")
rt:set("laminar/B747/nd/data/capt/vor_ndb", 1)
rt:set("laminar/B747/nd/data/capt/apt", 1)
run(0.5)
n, c = slot("BBB")
T.check(n ~= nil and c == "bluetext", "STA at 40 NM: the NDB in blue")
n, c = slot("DDD")
T.check(n ~= nil and c == "bluetext" and rt:get(C .. "icon", n) == 11, "and the untuned VOR")
T.check(slot("CCCC") ~= nil, "ARPT: the airport")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 3)                  -- 80 NM
run(0.5)
T.equal(slot("BBB"), nil, "80 NM: no low altitude NDB (FCOM p.1040: high altitude navaids only)")
T.equal(slot("DDD"), nil, "nor a VOR not known as high altitude")
T.check(slot("AAA") ~= nil, "the tuned VOR still")
T.check(slot("CCCC") ~= nil, "airports on all ranges")
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 1)                   -- VOR
rt:set("sim/cockpit2/EFIS/map_mode", 0)
run(0.5)
T.equal(slot("AAA"), nil, "VOR mode: no map symbols, not even the tuned VOR (MAP and MAP CTR only; before, every mode)")
T.equal(slot("CCCC"), nil, "nor airports")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)
rt:set("sim/cockpit2/EFIS/map_mode", 2)
-- 70 NDBs within 40 NM: more than the 60 slots
local many = {}
for k = 1, 70 do
    many[#many + 1] = string.format('[%d,2,300,0,%.4f,%.4f,0,"N%02d"]', k, 35.05 + (k % 10) * 0.05, 139.9 + math.floor(k / 10) * 0.03, k)
end
navaids("[" .. table.concat(many, ",") .. "]")
run(0.5)
T.equal(rt:get("laminar/B747/nd/capt/excess_data"), 1, "70 NDBs with STA: EXCESS DATA (FCOM p.1111)")
rt:set("laminar/B747/nd/data/capt/vor_ndb", 0)
run(0.5)
T.equal(rt:get("laminar/B747/nd/capt/excess_data"), 0, "STA deselected: cleared")
T.equal(rt:get("laminar/B747/nd/fo/excess_data"), 0, "the F/O's ND (no IRU): none")

T.done()
