-- Run from the repository root with LuaJIT: luajit tests/fms/wind_model_test.lua
-- The FMC's waypoint winds and temperatures (plugins/xtlua_keysystems/
-- scripts/B747.68.xt.fms/B747.68.wind_model.lua; 6-1/6-2 step 8e1, notes/
-- ATA-34-61-FMC.md §51): FMSPG's example of entry and propagation (p.229,
-- figure 4.6-1: each entry down the route to the next one at its altitude,
-- the first one also back to the start) and of a deleted waypoint (p.231,
-- figure 4.6-2); the passed waypoints' entries going on; the four
-- altitudes; the forecast temperature by the standard lapse rate (FCOM
-- p.1365's figure: FL330 -53 C, FL270 -41 C) and its limits (FMSPG p.122).
local T = dofile("tests/lib/check.lua")("wind_model")
local W = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.wind_model.lua")

-- ORIG, A to J, DEST as legs (the figure's waypoints)
local names = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J"}
local function route()
    local r = {legs = {}, passed = {}}
    for i, n in ipairs(names) do r.legs[i] = {fix = {ident = n}} end
    return r
end
local function idx(r, n)
    for i, l in ipairs(r.legs) do if l.fix.ident == n then return i end end
end
local function wind(r, n, ft)
    local d, k, here = W.wind(r, idx(r, n), ft)
    return d and string.format("%03d/%d", d, k) or "none", here
end

-- the four altitudes: sorted, the highest first; no fifth, no repeat
local r = route()
T.equal(W.add_alt(r, 30000), nil, "FL300")
T.equal(W.add_alt(r, 40000), nil, "FL400")
T.equal(W.add_alt(r, 25000), nil, "FL250")
T.equal(W.add_alt(r, 30000), W.INVALID_ENTRY, "FL300 again: INVALID ENTRY")
T.equal(W.add_alt(r, 35000), nil, "FL350")
T.equal(table.concat(W.alts(r), " "), "40000 35000 30000 25000", "sorted, the highest first")
T.equal(W.add_alt(r, 20000), W.INVALID_ENTRY, "a fifth: INVALID ENTRY (FCOM p.1365)")

-- figure 4.6-1's entries
W.set_wind(r, idx(r, "H"), 40000, 200, 120)
W.set_wind(r, idx(r, "B"), 35000, 180, 110)
W.set_wind(r, idx(r, "E"), 35000, 150, 120)
W.set_wind(r, idx(r, "B"), 30000, 100, 85)
W.set_wind(r, idx(r, "E"), 30000, 80, 90)
W.set_wind(r, idx(r, "G"), 30000, 120, 95)
W.set_wind(r, idx(r, "A"), 25000, 50, 60)
local function row(ft)
    local t = {}
    for _, n in ipairs(names) do t[#t + 1] = (wind(r, n, ft)) end
    return table.concat(t, " ")
end
T.equal(row(40000), string.rep("200/120 ", 9) .. "200/120", "FL400: H's only entry everywhere, back to A and on to J")
T.equal(row(35000), "180/110 180/110 180/110 180/110 150/120 150/120 150/120 150/120 150/120 150/120",
    "FL350: B's back to A and on to D, E's from E on")
T.equal(row(30000), "100/85 100/85 100/85 100/85 080/90 080/90 120/95 120/95 120/95 120/95",
    "FL300: B's to D, E's to F, G's from G on")
T.equal(row(25000), string.rep("050/60 ", 9) .. "050/60", "FL250: A's everywhere")
T.check(select(2, wind(r, "B", 35000)) and not select(2, wind(r, "C", 35000)), "entered at B (large), propagated at C (small)")
T.check(W.entered(r.legs[idx(r, "B")]) and not W.entered(r.legs[idx(r, "C")]), "B has winds entered (RTE DATA's W>), C not")
T.equal(wind(r, "C", 32000), "none", "an altitude not among the four: none")

-- figure 4.6-2: E deleted, B's FL350 wind on to J, B's FL300 to F
table.remove(r.legs, idx(r, "E"))
local function row2(ft)
    local t = {}
    for _, n in ipairs({"A", "B", "C", "D", "F", "G", "H", "I", "J"}) do t[#t + 1] = (wind(r, n, ft)) end
    return table.concat(t, " ")
end
T.equal(row2(35000), string.rep("180/110 ", 8) .. "180/110", "E deleted: FL350 B's everywhere")
T.equal(row2(30000), "100/85 100/85 100/85 100/85 100/85 120/95 120/95 120/95 120/95", "FL300: B's to F, G's from G")

-- passed waypoints' entries go on propagating
r.passed[1] = table.remove(r.legs, 1)
r.passed[2] = table.remove(r.legs, 1)
T.equal((wind(r, "C", 35000)), "180/110", "A and B passed: B's FL350 wind still at C")
T.equal((wind(r, "C", 25000)), "050/60", "and A's FL250 wind")

-- an altitude deleted: its winds everywhere
W.delete_alt(r, 30000)
T.equal(table.concat(W.alts(r), " "), "40000 35000 25000", "FL300 deleted")
T.equal((wind(r, "G", 30000)), "none", "its winds gone (FMSPG p.122)")
-- a wind deleted at one waypoint: the others' propagate there
W.delete_wind(r, idx(r, "G"), 40000)
T.equal((wind(r, "G", 40000)), "200/120", "a wind deleted where none was: unchanged")
W.delete_wind(r, idx(r, "H"), 40000)
T.equal((wind(r, "G", 40000)), "none", "H's FL400 wind deleted: none at FL400")

-- a modification's copy shares the legs' wind tables: an entry makes a new one
local r1 = route()
W.set_wind(r1, 3, 35000, 270, 50)
local copy = {legs = {}, passed = {}}
for i, l in ipairs(r1.legs) do
    local c = {}
    for k, v in pairs(l) do c[k] = v end
    copy.legs[i] = c
end
W.set_wind(r1, 3, 35000, 280, 60)
T.equal((wind(copy, "C", 35000)), "270/50", "the copy keeps its wind")
T.equal((wind(r1, "C", 35000)), "280/60", "the route the new one")

-- temperatures: one entry, the standard lapse rate (FCOM p.1365's figure)
local r2 = route()
T.near(W.oat(r2, 3, 35000), -54.3, 0.05, "no entry: the standard day at FL350")
W.set_oat(r2, 3, 33000, -53)
local c, here = W.oat(r2, 3, 27000)
T.near(c, -41.1, 0.05, "FL330 -53 C: FL270 -41 C (FCOM p.1365)")
T.check(here, "entered at C")
c, here = W.oat(r2, 5, 33000)
T.check(math.abs(c + 53) < 1e-9 and not here, "propagated on to E (small)")
c, here = W.oat(r2, 1, 33000)
T.check(math.abs(c + 53) < 1e-9 and not here, "and back to A")
T.near(W.oat(r2, 3, 40000), -53 + (W.isa(40000) - W.isa(33000)), 1e-9, "above the tropopause: isothermal")
W.delete_oat(r2, 3)
T.near(W.oat(r2, 3, 35000), -54.3, 0.05, "deleted: the standard day")
-- the limits (FMSPG p.122)
T.check(W.oat_valid(0, 55) and not W.oat_valid(0, 56), "sea level: up to 55 C")
T.check(W.oat_valid(45100, -40) and not W.oat_valid(45100, -39), "45,100 ft: up to -40 C")
T.check(W.oat_valid(30000, -80) and not W.oat_valid(30000, -81), "-80 C the lowest")
-- the entry's form (FMSPG p.179)
local d, k = W.parse_wind("090/105")
T.check(d == 90 and k == 105, "090/105")
d, k = W.parse_wind("140/")
T.check(d == 140 and k == nil, "140/: the direction only")
d, k = W.parse_wind("/80")
T.check(d == nil and k == 80, "/80: the speed only")
T.check(W.parse_wind("90/50") == nil and W.parse_wind("361/50") == nil and select(2, W.parse_wind("100/251")) == nil,
    "two digits, 361, 251 kt: not valid")

-- the field the predictions fly in (step 8e3, notes §53)
T.near(W.mix(0), 1, 1e-9, "the measured wind's share: all of it here")
T.near(W.mix(200), 0.5, 1e-9, "half at 200 NM (FMSPG p.233)")
T.near(W.mix(400), 0.2, 1e-9, "a fifth at 400 NM")
T.equal(W.mix(800), 0, "none from 750 NM")
-- two waypoints east of here, 1,000 and 2,000 NM along a track of 090;
-- FL350's winds 270/100 at the first (a tailwind), 090/50 at the second
local rf = {legs = {{fix = {ident = "P1"}}, {fix = {ident = "P2"}}}, passed = {}}
W.add_alt(rf, 35000)
W.set_wind(rf, 1, 35000, 270, 100)
W.set_wind(rf, 2, 35000, 90, 50)
local flegs = {{dist = 1000, p0 = {lat = 0, lon = 0}, p1 = {lat = 0, lon = 16}}, {dist = 1000, p0 = {lat = 0, lon = 16}, p1 = {lat = 0, lon = 33}}}
local function east() return 90 end
local F = W.field{legs = flegs, route = rf, course = east, measured = {dir = 0, kt = 0, isa = 0, h = 35000, phase = "crz"},
    orig_elev = 5000, dest_elev = 0, crz = 35000}
T.near(F.wind(1000, 35000, "crz"), -100, 1e-6, "at the first waypoint: its 100 kt tailwind (no measured share 1,000 NM ahead)")
T.near(F.wind(1500, 35000, "crz"), -25, 1e-6, "halfway: the two in a line (100 east and 50 west: 25 east)")
T.near(F.wind(1000, 40000, "crz"), -100, 1e-6, "above the highest altitude: its wind (FMSPG p.230)")
T.near(F.wind(1000, 17500, "crz"), -50, 1e-6, "below the lowest: down to none at the destination (half of it halfway)")
T.near(F.wind(1000, 20000, "clb"), -100 * 15000 / 30000, 1e-6, "in the climb: down to none at the origin (5,000 ft)")
T.near(F.wind(1000, 0, "crz"), 0, 1e-6, "at the destination's elevation: none")
-- the descent: the DESCENT FORECAST's winds, into the cruise's above them
local Fd = W.field{legs = flegs, route = rf, course = east, measured = {dir = 0, kt = 0, isa = 0, h = 35000, phase = "crz"},
    dest_elev = 0, crz = 35000, des = {{ft = 10000, dir = 90, kt = 40}, {}}}
T.near(Fd.wind(1000, 10000, "des"), 40, 1e-6, "at its altitude: the forecast's 40 kt headwind")
T.near(Fd.wind(1000, 22500, "des"), -30, 1e-6, "halfway up to FL350: halfway to the cruise wind (40 west to 100 east)")
T.near(Fd.wind(1000, 5000, "des"), 20, 1e-6, "below it: down to none at the destination")
local rn = {legs = {{fix = {ident = "P1"}}, {fix = {ident = "P2"}}}, passed = {}}
local Fn = W.field{legs = flegs, route = rn, course = east, measured = {dir = 0, kt = 0, isa = 0, h = 35000, phase = "crz"},
    dest_elev = 0, crz = 35000, des = {{ft = 10000, dir = 90, kt = 40}}}
T.near(Fn.wind(1000, 22500, "des"), 40, 1e-6, "no route winds: the highest forecast's up to the cruise altitude")
-- the measured wind (270/60, a tailwind) mixed in: by the distance in the
-- cruise, by the altitude in the climb (5,000 ft as 200 NM)
local Fm = W.field{legs = flegs, route = rn, course = east, measured = {dir = 270, kt = 60, isa = 10, h = 35000, phase = "crz"},
    dest_elev = 0, crz = 35000}
T.near(Fm.wind(0, 35000, "crz"), -60, 1e-6, "here: the measured wind")
T.near(Fm.wind(200, 35000, "crz"), -30, 1e-6, "200 NM ahead: half of it (no forecast)")
T.near(Fm.wind(400, 35000, "crz"), -12, 1e-6, "400 NM: a fifth")
local Fc = W.field{legs = flegs, route = rn, course = east, measured = {dir = 270, kt = 60, isa = 10, h = 10000, phase = "clb"},
    orig_elev = 0, dest_elev = 0, crz = 35000}
T.near(Fc.wind(1500, 15000, "clb"), -30, 1e-6, "climbing at 10,000 ft: half at 15,000 ft, wherever")
-- the temperature: the waypoints' deviation (FL300 -40 C at the second:
-- +4.4 there and back to the first), the measured one's share near
local rt2 = {legs = {{fix = {ident = "P1"}}, {fix = {ident = "P2"}}}, passed = {}}
W.set_oat(rt2, 2, 30000, -40)
local Ft = W.field{legs = flegs, route = rt2, course = east, measured = {dir = 0, kt = 0, isa = 10, h = 35000, phase = "crz"},
    dest_elev = 0, crz = 35000}
local dev = -40 - W.isa(30000)
T.near(Ft.isa(0, 35000), 10, 1e-6, "here: the measured +10")
T.near(Ft.isa(200, 35000), 0.5 * 10 + 0.5 * dev, 1e-6, "200 NM: half and half")
T.near(Ft.isa(1500, 35000), dev, 1e-6, "far: the forecast's " .. string.format("%+.1f", dev))
local Fs = W.field{legs = flegs, route = rn, course = east, measured = {dir = 0, kt = 0, isa = 10, h = 35000, phase = "crz"},
    dest_elev = 0, crz = 35000}
T.near(Fs.isa(1500, 35000), 0, 1e-6, "no entries: the standard day far ahead (FMSPG p.122)")

T.done()
