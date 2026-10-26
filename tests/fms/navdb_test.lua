-- Run from the repository root with LuaJIT: luajit tests/fms/navdb_test.lua
-- The FMC's navigation database (6-1/6-2 step 4; notes/ATA-34-61-FMC.md
-- §10): plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua on
-- the synthetic files in tests/fms/data/navdb (X-Plane's formats, made-up
-- points: the real data's licence does not let it go into the repository),
-- then, when this PC has them, on the data X-Plane flies with.
local T = dofile("tests/lib/check.lua")("navdb")
local N = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navdb.lua")

local DIR = "tests/fms/data/navdb/"
local function opener(dir, skip)
    return function(name)
        if skip and skip[name] then return nil end
        return io.open(dir .. name, "rb")
    end
end

-- the AIRAC cycles: every 28 days from 2 January 2020 (2001); NN counts the
-- cycles starting in the year
T.equal(N.airac("2001"), N.days(2020, 1, 2), "AIRAC 2001: 2 January 2020")
T.equal(N.airac("2014"), N.days(2020, 12, 31), "AIRAC 2014: 31 December 2020 (14 cycles in 2020)")
T.equal(N.airac("2101"), N.days(2021, 1, 28), "AIRAC 2101: 28 January 2021")
local first, last = N.airac("2610")
T.check(first == N.days(2026, 10, 1) and last == N.days(2026, 10, 28), "AIRAC 2610: 1 to 28 October 2026")
T.equal(N.airac("2613"), N.days(2026, 12, 24), "AIRAC 2613: 24 December 2026")
T.check(N.airac("2614") == nil and N.airac("2600") == nil and N.airac("26") == nil and N.airac(nil) == nil,
    "no cycle 2614 (13 in 2026), 2600 or a malformed one")
local y, m, d = N.civil(N.days(2026, 10, 26))
T.check(y == 2026 and m == 10 and d == 26, "days and dates both ways")
T.near(N.distance(35, 140, 36, 140), 60.04, 0.05, "a degree of latitude: 60 nm")
T.near(N.dms("N35003600"), 35.01, 1e-9, "N35003600: 35.01")
T.near(N.dms("W140001800"), -140.005, 1e-9, "W140001800: -140.005")

-- loading a few bytes a call
local db = N.new(opener(DIR))
local calls = 0
while not N.load(db, 100) do
    calls = calls + 1
    assert(calls < 1000, "never ready")
end
T.check(calls > 20, "read over many calls (" .. calls .. ")")
T.equal(#db.missing, 0, "no file missing")
local cycle, f1, f2 = N.cycle_info(db)
T.check(cycle == "2610" and f1 == N.days(2026, 10, 1) and f2 == N.days(2026, 10, 28), "the data cycle from the header: 2610")

-- the airports
local a = N.airport(db, "ZZAA")
T.check(a and a.kind == N.APT and a.lat == 35 and a.lon == 140 and a.elev == 100, "ZZAA: position and elevation")
T.check(a and a.ta == 14000 and a.tl == 14000, "ZZAA: transition altitude 14,000 ft, level FL140")
local b = N.airport(db, "ZZBB")
T.check(b and b.ta == 6000 and b.tl == nil, "ZZBB: transition altitude 6,000 ft, level by ATC (-1)")
T.equal(N.airport(db, "ZZCC"), nil, "no airport ZZCC")

-- waypoints and navaids
local list = N.find(db, "ALPHA", 35, 140)
T.check(#list == 2 and list[1].region == "ZZ" and list[2].region == "YY" and list[1].kind == N.WPT,
    "ALPHA: two waypoints, the nearer first")
T.near(list[1].dist, N.distance(35, 140, 35.5, 140.5), 1e-9, "ALPHA: the distance from the position")
list = N.find(db, "ZZV", 35, 140)
T.check(#list == 2 and list[1].kind == N.VOR and list[1].region == "ZZ" and list[1].freq == 11500
    and list[1].dme == true and list[1].var == -7 and list[1].name == "ZULU VOR/DME",
    "ZZV: the VOR/DME (frequency, the DME's row, its slaved variation, name)")
T.check(list[2].region == "YY" and list[2].dme == nil, "ZZV in YY: a VOR without DME")
list = N.find(db, "IZA")
local loc = list[1]
T.check(#list == 1 and loc.kind == N.LOC and loc.freq == 10950 and loc.crs_mag == 157
    and math.abs(loc.crs_true - 149.622) < 1e-6 and loc.runway == "16R",
    "IZA: the localizer, courses magnetic 157 and true 149.622, runway 16R")
T.check(loc.gs == 3 and loc.dme == true and loc.terminal == "ZZAA", "IZA: glideslope 3.00 degrees and DME")
list = N.find(db, "ZZD")
T.check(#list == 1 and list[1].kind == N.DME and list[1].freq == 11300, "ZZD: a DME alone")
list = N.find(db, "ZA")
T.check(#list == 1 and list[1].kind == N.NDB and list[1].freq == 350, "ZA: an NDB")
T.equal(#N.find(db, "ZA001"), 0, "ZA001: a terminal waypoint, not found without its airport")
list = N.find(db, "ZA001", 35, 140, {"ZZAA"})
T.check(#list == 1 and list[1].terminal == "ZZAA" and list[1].lat == 35.05, "ZA001 with ZZAA: its terminal waypoint")
list = N.find(db, "ZA001", 36, 141, {"ZZAA", "ZZBB"})
T.check(#list == 2 and list[1].terminal == "ZZBB", "ZA001 with both airports: two, the nearer first")
list = N.find(db, "ZZAA")
T.check(#list == 1 and list[1].kind == N.APT, "ZZAA: the airport")
local p = N.point(db, "ZZV", "ZZ", N.VOR)
T.check(p and p.lat == 35.2 and p.dme, "the point ZZV ZZ VOR")
p = N.point(db, "ZA002", "ZZ", N.WPT, "ZZAA")
T.check(p and p.terminal == "ZZAA" and p.lat == 35.06, "the point ZA002 ZZ: a terminal waypoint of ZZAA")
T.equal(N.point(db, "ALPHA", "XX", N.WPT), nil, "no point ALPHA XX")

-- airways
local function idents(path)
    if not path then return "nil" end
    local t = {}
    for i, q in ipairs(path) do t[i] = q.ident end
    return table.concat(t, " ")
end
T.equal(idents(N.airway_path(db, "Z1", "ALPHA", "DELTA")), "ALPHA BRAVO CHARL DELTA", "Z1 from ALPHA to DELTA")
T.equal(idents(N.airway_path(db, "Z1", "CHARL", "ALPHA")), "CHARL BRAVO ALPHA", "Z1 from CHARL to ALPHA")
T.equal(idents(N.airway_path(db, "Z1", "DELTA", "CHARL")), "nil", "Z1 from DELTA: one-way CHARL to DELTA")
T.equal(idents(N.airway_path(db, "Z1", "ALPHA", "ZZV")), "ALPHA BRAVO ZZV", "Z1 to the VOR ZZV (a branch)")
T.equal(idents(N.airway_path(db, "Z2", "ZZV", "BRAVO")), "ZZV BRAVO", "Z2 shares the segment with Z1")
T.equal(idents(N.airway_path(db, "Z1", "ALPHA", "ECHO")), "nil", "ECHO is not on Z1")
T.equal(N.airway_path(db, "Z9", "ALPHA", "BRAVO"), nil, "no airway Z9")
local segs = N.airway(db, "Z1")
T.check(#segs == 4 and segs[3].dir == "F" and segs[4].to.kind == N.VOR and segs[1].level == 2
    and segs[1].base == 245 and segs[1].top == 460, "Z1's segments: direction, kinds, level, base and top")

-- holds
local h = N.holds(db, "BRAVO", "ZZ")
T.check(#h == 1 and h[1].inbound == 270 and h[1].time == 1.5 and h[1].turn == "L" and h[1].min_alt == 5000
    and h[1].max_alt == 20000 and h[1].speed == 230 and h[1].kind == N.WPT,
    "the hold at BRAVO: 270, 1.5 minutes, left, 5,000 to 20,000 ft, 230 kt")
h = N.holds(db, "ZZV", "ZZ")
T.check(#h == 1 and h[1].time == 0 and h[1].dist == 5 and h[1].turn == "R" and h[1].kind == N.VOR,
    "the hold at ZZV: 5 nm legs, right")
T.equal(#N.holds(db, "CHARL", "ZZ"), 0, "no hold at CHARL")

-- the airport's CIFP
local c = N.cifp(db, "ZZAA")
local r = c and c.runways.RW16R
T.check(r and math.abs(r.lat - 35.01) < 1e-9 and math.abs(r.lon - 140.005) < 1e-9 and r.elev == 100
    and r.loc == "IZA" and r.cat == 3 and r.displaced == 0, "RW16R: threshold, elevation, localizer, category")
r = c and c.runways.RW34L
T.check(r and r.loc == nil and r.cat == nil and r.displaced == 500 and math.abs(r.lat - (34 + 59 / 60)) < 1e-9,
    "RW34L: no localizer, displaced 500 ft")
T.check(c and #c.order.sid == 1 and c.order.sid[1] == "ZULU1" and #c.sid.ZULU1.RW16R == 2 and #c.sid.ZULU1.ALPHA == 1,
    "the SID ZULU1: the runway transition RW16R (2 legs) and the transition ALPHA")
local leg = c and c.sid.ZULU1.RW16R[1]
T.check(leg and leg[1] == "010" and leg[5] == "ZA001" and leg[12] == "CF" and leg[14] == "ZZV" and leg[26] == "14000",
    "the SID's first leg: its fields (sequence, fix, path terminator, navaid, transition altitude)")
T.check(c and c.star.ALPHA1 and c.star.ALPHA1.ALL and c.appch.I16R and c.appch.I16R.ZZV, "the STAR ALPHA1 and the approach I16R")
T.check(N.cifp(db, "ZZBB") == nil and db.cifp.ZZBB == false, "ZZBB: no CIFP (remembered)")
T.check(N.cifp(db, "ZZAA") == c, "the CIFP read once")

-- a file missing: skipped
local db2 = N.new(opener(DIR, {["earth_hold.dat"] = true}))
while not N.load(db2) do end
T.check(#db2.missing == 1 and db2.missing[1] == "earth_hold.dat" and #N.holds(db2, "BRAVO", "ZZ") == 0
    and N.airport(db2, "ZZAA") ~= nil, "earth_hold.dat missing: skipped, the rest read")

-- the data X-Plane flies with, when this PC has them (Custom Data first)
local XP = "../../"
local base
for _, dir in ipairs({XP .. "Custom Data/", XP .. "Resources/default data/"}) do
    local f = io.open(dir .. "earth_nav.dat", "rb")
    if f then f:close(); base = dir; break end
end
if base then
    local real = N.new(opener(base))
    local t0, calls2 = os.clock(), 0
    while not N.load(real, 32768) do calls2 = calls2 + 1 end
    local secs = os.clock() - t0
    T.check(real.ready and #real.missing == 0 and real.n > 10000, "X-Plane's data: read (" .. real.n .. " points)")
    local rjaa = N.airport(real, "RJAA")
    T.check(rjaa and math.abs(rjaa.lat - 35.76) < 0.05 and rjaa.ta == 14000, "X-Plane's data: RJAA, transition altitude 14,000 ft")
    local nre = N.find(real, "NRE", 35.76, 140.38)
    T.check(nre[1] and nre[1].kind == N.VOR and nre[1].dme, "X-Plane's data: NRE, the nearest a VOR/DME")
    local cr = N.cifp(real, "RJAA")
    T.check(cr and cr.runways.RW16R and cr.runways.RW34L and #cr.order.sid > 0, "X-Plane's data: RJAA's runways and SIDs")
    print(string.format("X-Plane's data (%s, cycle %s): %.2f s, %d calls of 32 KB", base, real.cycle or "?", secs, calls2))
end

T.done()
