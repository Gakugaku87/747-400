-- Run from the repository root with LuaJIT: luajit tests/fms/proc_model_test.lua
-- The FMC's terminal procedures (6-1/6-2 step 5d; notes/ATA-34-61-FMC.md
-- §18): plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua
-- on the synthetic CIFP of ZZAA (tests/fms/data/navdb/CIFP/ZZAA.dat): the
-- parts by the route type, the legs with their constraints, the conditional
-- legs' names (FCOM p.1249), the missed approach; and the route model's
-- DEPARTURES and ARRIVALS (FCOM p.1301-1302, p.1401-1405; FMSPG p.79).
local T = dofile("tests/lib/check.lua")("proc_model")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.proc_model.lua")
local R = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.route_model.lua")

local db = N.new(function(name) return io.open("tests/fms/data/navdb/" .. name, "rb") end)
while not N.load(db) do end
local function names(legs)
    local out = {}
    for _, l in ipairs(legs) do out[#out + 1] = l.fix and l.fix.ident or l.name or (l.disc and "DISC") or "?" end
    return table.concat(out, " ")
end

-- the lists
local sids = P.list(N, db, "ZZAA", P.SID)
T.check(#sids == 1 and sids[1] == "ZULU1", "ZZAA's SIDs: ZULU1")
local tr = P.transitions(N, db, "ZZAA", P.SID, "ZULU1")
T.equal(table.concat(tr.rwy, " "), "RW16R RW34L", "its runway transitions")
T.equal(table.concat(tr.trans, " "), "ALPHA", "its enroute transition")
T.equal(table.concat(P.runways(N, db, "ZZAA", P.SID, "ZULU1"), " "), "RW16R RW34L", "the runways it serves")
T.equal(table.concat(P.list(N, db, "ZZAA", P.STAR), " "), "ALPHA1", "the STARs")
T.equal(table.concat(P.transitions(N, db, "ZZAA", P.STAR, "ALPHA1").trans, " "), "DELTA", "ALPHA1's enroute transition")
T.equal(table.concat(P.list(N, db, "ZZAA", P.APPCH), " "), "I16R", "the approaches")
T.equal(P.approach_name("I16R"), "ILS16R", "I16R shown ILS16R (FCOM p.1401)")
T.equal(P.approach_name("R34LY"), "RNV34LY", "an RNAV approach RNV")
T.equal(table.concat(P.transitions(N, db, "ZZAA", P.APPCH, "I16R").trans, " "), "ZZV", "I16R's transition")

-- a SID: the runway transition, the enroute transition, the point they
-- share once
local legs = P.sid_legs(N, db, "ZZAA", "ZULU1", "RW34L", "ALPHA")
T.equal(names(legs), "(600) (INTC) ZZV ALPHA", "ZULU1 from RW34L with ALPHA (FCOM p.1249: (600), (INTC))")
local va, vi, cf, tf = legs[1], legs[2], legs[3], legs[4]
T.check(va.pt == "VA" and va.crs == 337 and va.alt == 600 and va.akind == "A" and va.altterm and not va.fix,
    "a heading 337 to 600 ft: no fix, ends at an altitude")
T.check(vi.pt == "VI" and vi.crs == 45 and vi.turn == "R", "a heading 045 to intercept, turning right")
T.check(cf.pt == "CF" and cf.fix.ident == "ZZV" and cf.crs == 90 and cf.dist == 8 and cf.alt == 3000 and cf.akind == "A"
    and cf.spd == 230 and cf.navaid.ident == "ZZV" and cf.theta == 45 and cf.rho == 10, "a course 090 to ZZV: at or above 3000, 230 kt")
T.check(tf.fix.ident == "ALPHA" and tf.alt == 12000 and tf.akind == "A", "ALPHA at or above FL120")
T.check(cf.via == "ZULU1.ALPHA", "the RTE page's VIA: ZULU1.ALPHA (FCOM p.1297)")
T.equal(names(P.sid_legs(N, db, "ZZAA", "ZULU1", "RW16R")), "ZA001 ZZV", "from RW16R: ZZAA's ZA001, direct ZZV")

-- a STAR: its enroute transition, the common route
legs = P.star_legs(N, db, "ZZAA", "ALPHA1", "DELTA")
T.equal(names(legs), "DELTA ALPHA ZZV", "ALPHA1 from DELTA")
T.check(legs[2].alt == 11000 and legs[2].alt2 == 15000 and legs[2].akind == "AB", "ALPHA: the block FL110 to FL150")
T.check(legs[3].alt == 10000 and legs[3].akind == "B" and legs[3].spd == 250, "ZZV: at or below FL100, 250 kt")

-- an approach: its transition, the final approach, the missed approach
local rwy
legs, rwy = P.approach_legs(N, db, "ZZAA", "I16R", "ZZV")
T.equal(names(legs), "ZZV ZA002 ZA001 RW16R (1000) ZZV ZZV", "ILS16R via ZZV")
T.equal(rwy, "RW16R", "it lands on RW16R")
T.check(legs[3].faf and legs[3].vangle == -3 and legs[3].alt == 3000, "ZA001 the final approach fix: 3.00 degrees, at or above 3000")
T.check(legs[4].map and legs[4].fix.kind == "RWY" and legs[4].alt == 150, "RW16R the missed approach point at 150 ft")
T.check(legs[5].missed and legs[5].pt == "CA" and legs[7].missed and legs[7].pt == "HM", "the missed approach from (1000) on, to the hold at ZZV")
T.check(not legs[4].missed, "not before it")

-- the route's DEPARTURES and ARRIVALS
local st = R.new(N, db)
st.P = P
R.set_origin(st, "ZZAA")
R.set_dest(st, "ZZBB")
local function fix(ident) return N.find(db, ident, 35.5, 140.5)[1] end
R.add_to(st, fix("ALPHA"))
R.add_to(st, fix("DELTA"))
T.equal(R.set_departure(st, "ZULU1", "RW34L", "ALPHA"), nil, "ZULU1 RW34L ALPHA")
T.equal(names(R.legs(R.shown(st))), "(600) (INTC) ZZV ALPHA DELTA", "the route from the SID's ALPHA on (FCOM p.1297)")
T.equal(R.shown(st).runway.ident, "RW34L", "the origin's runway")
T.check(R.shown(st).sid.name == "ZULU1" and R.shown(st).sid.trans == "ALPHA", "the selection kept")
T.equal(R.segments(R.shown(st))[1].via, "ZULU1.ALPHA", "the RTE page's first VIA")
T.equal(R.set_departure(st, "ZULU1", "RW16R", nil), nil, "ZULU1 RW16R, no transition")
T.equal(names(R.legs(R.shown(st))), "ZA001 ZZV DISC ALPHA DELTA",
    "the old SID out, the route's ALPHA it had joined at back; ZZV not in the route: a discontinuity")
T.equal(R.set_departure(st, nil, "RW34L"), nil, "the runway alone")
T.equal(names(R.legs(R.shown(st))), "ALPHA DELTA", "the SID out, its discontinuity with it")
T.equal(R.set_departure(st, "ZULU9", "RW34L"), R.NOT_IN_DATA_BASE, "a SID not in the data")

-- a SID selected again (the transition first, the runway after: found in
-- X-Plane, s88): it joins the route where the first one did
local st2 = R.new(N, db)
st2.P = P
R.set_origin(st2, "ZZAA")
R.set_dest(st2, "ZZBB")
R.add_to(st2, fix("ALPHA"))
R.add_to(st2, fix("DELTA"))
T.equal(R.set_departure(st2, "ZULU1", nil, "ALPHA"), nil, "ZULU1 ALPHA, no runway yet")
T.equal(names(R.legs(R.shown(st2))), "ZZV ALPHA DELTA", "the transition's legs, joined at ALPHA")
T.equal(R.set_departure(st2, "ZULU1", "RW34L", "ALPHA"), nil, "then RW34L")
T.equal(names(R.legs(R.shown(st2))), "(600) (INTC) ZZV ALPHA DELTA", "joined at ALPHA again: no discontinuity")
R.activate(st2)
R.exec(st2)
T.equal(R.set_departure(st2, "ZULU1", "RW16R", "ALPHA"), nil, "on the active route: RW16R")
T.equal(names(R.legs(R.shown(st2))), "ZA001 ZZV ALPHA DELTA", "the modification joined at ALPHA")
R.erase(st2)
T.equal(names(R.legs(R.shown(st2))), "(600) (INTC) ZZV ALPHA DELTA", "ERASE: the active route as it was")
T.equal(R.set_departure(st2, nil, "RW34L"), nil, "the SID out of the modification")
T.equal(names(R.legs(R.shown(st2))), "ALPHA DELTA", "the route's ALPHA back")
T.check(R.shown(st2).legs[1] ~= st2.rte.legs[4].joined, "a copy: the active route's SID keeps its own")

R.set_dest(st, "ZZAA")         -- the synthetic data's procedures are ZZAA's
T.equal(R.set_arrival(st, {name = "ALPHA1", trans = "DELTA"}, nil), nil, "ALPHA1 from DELTA")
T.equal(names(R.legs(R.shown(st))), "ALPHA DELTA ALPHA ZZV", "from the STAR's DELTA on")
T.equal(R.set_arrival(st, nil, {id = "I16R", trans = "ZZV"}), nil, "ILS16R via ZZV")
T.equal(names(R.legs(R.shown(st))), "ALPHA DELTA ALPHA ZZV ZA002 ZA001 RW16R (1000) ZZV ZZV",
    "the approach after the STAR, ZZV once; the STAR selected again joined at DELTA again")
T.equal(R.shown(st).appr.rwy, "RW16R", "the landing runway")
local fms = R.to_fms(R.shown(st), "2610")
T.check(fms:find("DESRWY RW16R") and fms:find("\n28 RW16R DRCT ") and not fms:find("%(1000%)"),
    "X-Plane's flight plan: the landing runway, RW16R by position, no conditional leg")
T.check(select(2, fms:gsub("\n3 ZZV DRCT ", "")) == 1, "the missed approach's ZZV left out (only the STAR's)")
T.equal(R.set_arrival(st, false, nil), nil, "the STAR out")
T.equal(names(R.legs(R.shown(st))), "ALPHA DELTA DISC ZZV ZA002 ZA001 RW16R (1000) ZZV ZZV",
    "the STAR's legs gone, the route's DELTA back; the approach after a discontinuity")
T.equal(R.set_dest(st, "ZZBB"), nil, "a new destination")
T.equal(names(R.legs(R.shown(st))), "ALPHA DELTA", "the arrival procedures deleted (FMSPG p.79), the discontinuity before them too")
T.check(R.shown(st).appr == nil, "and their selections")

T.done()
