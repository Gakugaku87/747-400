-- Run from the repository root with LuaJIT: luajit tests/fms/route_model_test.lua
-- The FMC's route (6-1/6-2 step 5a; notes/ATA-34-61-FMC.md §18):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua
-- on the synthetic navigation data in tests/fms/data/navdb (airway Z1
-- ALPHA-BRAVO-CHARL-DELTA, CHARL to DELTA one way, BRAVO-ZZV shared with
-- Z2): ORIGIN, DEST and RUNWAY (FCOM p.1288-1289), the RTE pages' DIRECT
-- and airway segments, the airways' intersection, ROUTE FULL (FCOM
-- p.1296-1298, p.1435; FMSPG p.82-83), ACTIVATE, MOD, EXEC and ERASE (FCOM
-- p.1238, p.1290), X-Plane's flight plan file.
local T = dofile("tests/lib/check.lua")("route_model")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local function fix(ident) return N.find(db, ident, 35.5, 140.5)[1] end
local function segs(st)
    local out = {}
    for _, s in ipairs(R.segments(R.shown(st))) do
        out[#out + 1] = s.disc and "DISC" or (s.via .. " " .. (s.to or "[]"))
    end
    return table.concat(out, ", ")
end
local function idents(st)
    local out = {}
    for _, l in ipairs(R.legs(R.shown(st))) do out[#out + 1] = l.fix and l.fix.ident or (l.pending and "[]" or "DISC") end
    return table.concat(out, " ")
end

-- RTE page 1
local st = R.new(N, db)
T.equal(R.status(st), "", "a new route: inactive (no ACT, no MOD)")
T.check(not R.exec_lit(st), "no EXEC")
T.equal(R.set_origin(st, "ZZXX"), R.NOT_IN_DATA_BASE, "ORIGIN not in the database (FCOM p.1288)")
T.equal(R.set_origin(st, "ZZAA"), nil, "ORIGIN ZZAA")
T.equal(R.shown(st).origin.ident, "ZZAA", "the origin")
T.equal(R.set_runway(st, "XX"), R.INVALID_ENTRY, "RUNWAY XX: not a runway")
T.equal(R.set_runway(st, "99"), R.NOT_IN_DATA_BASE, "RUNWAY 99: not ZZAA's (FCOM p.1289)")
T.equal(R.set_runway(st, "16R"), nil, "RUNWAY 16R")
T.equal(R.shown(st).runway.ident, "RW16R", "RW16R")
T.equal(R.set_runway(st, "RW34L"), nil, "RW34L")
T.equal(R.set_dest(st, "ZZBB"), nil, "DEST ZZBB")
T.equal(R.shown(st).dest.ident, "ZZBB", "the destination")

-- the RTE pages' segments
T.equal(R.add_via(st, "Z1"), R.INVALID_ENTRY, "an airway first, no TO before it: INVALID ENTRY (the airway intercept is not made: estimate)")
T.equal(R.add_to(st, fix("ALPHA")), nil, "TO ALPHA on the dashes")
T.equal(segs(st), "DIRECT ALPHA", "DIRECT ALPHA (FCOM p.1297: dashes change to DIRECT)")
T.equal(R.add_via(st, "Z9"), R.NOT_IN_DATA_BASE, "airway Z9: NOT IN DATA BASE (FMSPG p.83)")
T.equal(R.add_via(st, "Z1"), nil, "VIA Z1")
T.equal(segs(st), "DIRECT ALPHA, Z1 []", "Z1 with boxes for its TO")
T.equal(R.add_to(st, fix("ZZD")), R.INVALID_ENTRY, "TO ZZD: not on Z1 (FMSPG p.83)")
T.equal(R.add_to(st, fix("CHARL")), nil, "TO CHARL")
T.equal(segs(st), "DIRECT ALPHA, Z1 CHARL", "Z1 to CHARL")
T.equal(idents(st), "ALPHA BRAVO CHARL", "the legs: Z1's points from ALPHA (FMSPG p.83: the LEGS pages show them)")
T.equal(R.add_via(st, "Z2"), R.INVALID_ENTRY, "Z2 does not contain CHARL: INVALID ENTRY (FCOM p.1297)")

-- two airways without a TO: their intersection (FCOM p.1297)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
T.equal(R.add_via(st, "Z2"), nil, "VIA Z1 then VIA Z2")
T.equal(segs(st), "DIRECT ALPHA, Z1 BRAVO, Z2 []", "Z1's TO: where it meets Z2 (BRAVO)")
T.check(R.legs(R.shown(st))[2].intc, "the FMC's intersection waypoint")
T.equal(R.add_to(st, fix("ZZV")), nil, "Z2 to ZZV")
T.equal(idents(st), "ALPHA BRAVO ZZV", "the legs")

-- a one-way segment: not against its way
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("DELTA"))
T.equal(R.add_via(st, "Z1"), nil, "Z1 contains DELTA")
T.equal(R.add_to(st, fix("CHARL")), R.INVALID_ENTRY, "DELTA to CHARL against Z1's one way: INVALID ENTRY")

-- ROUTE FULL (120 waypoints; here 3)
R.MAX_WPTS = 3
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.add_to(st, fix("ALPHA"))
R.add_via(st, "Z1")
T.equal(R.add_to(st, fix("DELTA")), R.ROUTE_FULL, "ALPHA to DELTA on Z1: 4 waypoints, ROUTE FULL (FCOM p.1435)")
T.equal(idents(st), "ALPHA []", "the route as it was")
T.equal(R.add_to(st, fix("CHARL")), nil, "to CHARL: 3")
T.equal(R.add_to(st, fix("DELTA")), R.ROUTE_FULL, "a fourth: ROUTE FULL")
R.MAX_WPTS = 120

-- ACTIVATE, EXEC, MOD, ERASE
st = R.new(N, db)
T.equal(R.activate(st), R.INVALID_ENTRY, "ACTIVATE without an origin and a destination")
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ALPHA"))
T.check(not R.exec_lit(st), "inactive route changes: no EXEC (FCOM p.1290)")
T.equal(R.activate(st), nil, "ACTIVATE")
T.check(R.exec_lit(st), "EXEC lit")
T.equal(R.status(st), "", "not active until EXEC")
T.check(R.exec(st), "EXEC")
T.equal(R.status(st), "ACT", "ACT RTE 1")
T.check(not R.exec_lit(st), "EXEC out")
T.equal(R.add_to(st, fix("BRAVO")), nil, "a change on the active route")
T.equal(R.status(st), "MOD", "MOD RTE 1 (FCOM p.1238)")
T.check(R.exec_lit(st), "EXEC lit")
T.equal(idents(st), "ALPHA BRAVO", "the pages show the modification")
T.equal(#st.rte.legs, 1, "the active route as it was")
R.erase(st)
T.equal(R.status(st), "ACT", "ERASE: the active route back")
T.equal(idents(st), "ALPHA", "without the change")
R.add_to(st, fix("CHARL"))
T.check(R.exec(st), "EXEC the change")
T.equal(idents(st), "ALPHA CHARL", "the active route changed")
T.check(not R.exec(st), "nothing more to execute")
T.equal(R.set_origin(st, "ZZBB"), nil, "a new origin")
T.equal(R.status(st), "MOD", "on the active route: a modification")
T.equal(idents(st), "", "the route erased (FCOM p.1288)")
T.equal(R.shown(st).dest, nil, "with the destination")

-- SELECT DESIRED WPT: the candidates nearest first, the airports' terminal
-- waypoints with them
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
local c = R.candidates(st, "ZA001", 36, 141)
T.check(#c == 2 and c[1].terminal == "ZZBB" and c[2].terminal == "ZZAA", "ZA001: ZZBB's then ZZAA's (FCOM p.1335)")
c = R.candidates(st, "ALPHA", 35, 140)
T.check(#c == 2 and c[1].region == "ZZ" and c[2].region == "YY", "ALPHA: the near one first")

-- X-Plane's flight plan file for its FMS (xtlua/loadtoFMS)
st = R.new(N, db)
R.set_origin(st, "ZZAA")
R.set_runway(st, "16R")
R.set_dest(st, "ZZBB")
R.add_to(st, fix("ZZV"))
R.add_via(st, "Z2")
R.add_to(st, fix("BRAVO"))
local fms = R.to_fms(R.shown(st), "2610")
T.check(fms:find("^I\n1100 Version\nCYCLE 2610\nADEP ZZAA\nDEPRWY RW16R\nADES ZZBB\nNUMENR 4\n"), "the header: " .. fms:sub(1, 80))
T.check(fms:find("\n1 ZZAA ADEP 100%.000000 35%.000000 140%.000000\n", 1, false), "the origin as an airport")
T.check(fms:find("\n3 ZZV DRCT 0%.000000 35%.200000 140%.200000\n"), "a VOR, DIRECT")
T.check(fms:find("\n11 BRAVO Z2 0%.000000 36%.000000 140%.500000\n"), "a fix on Z2")
T.check(fms:find("\n1 ZZBB ADES 50%.000000 36%.000000 141%.000000\n$"), "the destination last")

T.done()
