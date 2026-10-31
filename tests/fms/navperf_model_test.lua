-- Run from the repository root with LuaJIT: luajit tests/fms/navperf_model_test.lua
-- The FMC's position updating and navigation performance (plugins/
-- xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navperf_model.lua; 6-1/6-2
-- step 10a, notes/ATA-34-61-FMC.md §86; FCOM p.1240-1245, p.1367-1370,
-- p.1430, p.1435-1436, p.1150; ATA34_2 p.517; FMSPG p.26-27): the source by
-- the priority, the ANP, the RNP's defaults and entries, UNABLE RNP, PURGE,
-- GPS NAV, polar operation.
local T = dofile("tests/lib/check.lua")("navperf_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.navperf_model.lua")

-- the ANP's model (estimates)
T.near(M.anp_dd(50, 50, 90), 0.279, 0.001, "DME-DME 50 nm each, 90 degrees apart: 0.28 nm")
T.near(M.anp_dd(50, 50, 30), 2 * M.anp_dd(50, 50, 90), 1e-9, "at 30 degrees twice that")
T.check(M.anp_dd(150, 150, 90) > M.anp_dd(20, 20, 90), "farther stations: a larger ANP")
T.near(M.anp_vd(25), 0.894, 0.001, "VOR/DME 25 nm away: 0.89 nm")

-- a DME in reach: its range, the radio horizon, not over 45 degrees above
T.check(M.dme_ok(100, 130, 35000, 0), "FL350, 100 nm, range 130: in reach")
T.check(not M.dme_ok(140, 130, 35000, 0), "beyond its range")
T.check(not M.dme_ok(60, 130, 1000, 0), "1,000 ft: 60 nm is beyond the radio horizon (39 nm)")
T.check(not M.dme_ok(4, 130, 35000, 0), "FL350 4 nm away: over 45 degrees above")
T.check(M.dme_ok(6, 130, 35000, 0), "6 nm away: under 45 degrees")

-- the DME-DME pair (FMSPG p.26)
local function st(ident, dist, brg) return {ident = ident, dist = dist, brg = brg} end
local cands = {st("AAA", 20, 0), st("BBB", 25, 10), st("CCC", 200, 90), st("DDD", 30, 60), st("EEE", 40, 175)}
local p = M.dd_pair(cands, 5000)
T.check(p and p.a.ident == "DDD" and p.b.ident == "EEE", "below 12,500 ft: the least ANP (DDD and EEE 115 degrees apart and near; CCC 200 nm away)")
p = M.dd_pair(cands, 30000)
T.check(p and p.a.ident == "AAA" and p.b.ident == "CCC" and p.angle == 90, "above it: the angle nearest 90 (AAA and CCC)")
T.check(M.dd_pair({st("BBB", 25, 20), st("EEE", 40, 170)}, 30000), "150 degrees apart: a pair")
T.equal(M.dd_pair({st("AAA", 20, 0), st("BBB", 25, 20), st("EEE", 40, 175)}, 30000), nil, "20, 155 and 175 degrees apart: no pair")
T.equal(M.dd_pair({st("AAA", 20, 0)}, 30000), nil, "one station: no pair")

-- LOC updating's conditions (FCOM p.1241): a localizer whose course is 160
local loc = {dest_rwy = true, alt_above = 3000, dist = 15, brg_from = 340, crs = 160, track = 165}
T.check(M.loc_ok(loc), "the destination runway's, 3,000 ft above, 15 nm, on the course")
local function with(k, v) local l = {} for a, b in pairs(loc) do l[a] = b end l[k] = v return l end
T.check(not M.loc_ok(with("dest_rwy", false)), "another runway's localizer: no")
T.check(not M.loc_ok(with("alt_above", 6000)), "6,000 ft above: no")
T.check(not M.loc_ok(with("dist", 20)), "20 nm: no")
T.check(M.loc_ok(with("brg_from", 316)), "24 degrees off the course: yes")
T.check(not M.loc_ok(with("brg_from", 310)), "30 degrees off: no")
T.check(not M.loc_ok(with("track", 210)), "a 50 degree intercept: no")
T.check(M.loc_ok(with("track", 120)), "a 40 degree intercept: yes")

-- the RNP's phases (ATA34_2 p.517; estimates)
T.equal(M.phase({ground = true, d_term = 0}), M.TAKEOFF, "on the ground: takeoff")
T.equal(M.phase({ground = false, d_term = 12, navaid_near = true}), M.TERMINAL, "12 nm from the airport: terminal")
T.equal(M.phase({ground = false, d_term = 80, navaid_near = true}), M.DOMESTIC, "80 nm, a navaid near: domestic")
T.equal(M.phase({ground = false, d_term = 800, navaid_near = false}), M.OCEANIC, "no navaid within 200 nm: oceanic/remote")
T.equal(M.phase({ground = false, approach = true, d_term = 8}), M.APPROACH, "on the approach")

-- the updates
local s = M.new()
local inp = M.inputs()
local out = M.update(s, inp)
T.check(out.anp == nil and out.title == "" and out.nd == "", "no IRU navigating: no FMC position")
inp.irs, inp.gps_l, inp.gps_r = true, true, true
out = M.update(s, inp)
T.check(out.src == M.GPS and out.title == "GPS L" and out.nd == "GPS", "GPS L first (FCOM p.1368: GPS L)")
T.near(out.anp, 0.05, 1e-9, "GPS's ANP 0.05 nm")
T.near(out.rnp, 1.00, 1e-9, "on the ground: the takeoff RNP 1.00")
T.check(not out.rnp_man and out.sta_title == "NAV STA" and out.sta == "", "NAV STA blank without radio computation")
inp.gps_l = false
out = M.update(s, inp)
T.equal(out.title, "GPS R", "GPS L lost: GPS R")

-- in the air, GPS inhibited: DME-DME, the ANP growing to its
inp.ground, inp.d_term, inp.navaid_near = false, 100, true
inp.dd = {a = {ident = "IPDX"}, b = {ident = "SEA"}, angle = 80, anp = 0.30}
out = M.update(s, inp)
T.check(out.src == M.GPS and out.sta_title == "DME-DME" and out.sta == "IPDX SEA", "GPS with DME-DME computed underneath (FCOM p.1244's page)")
T.near(out.rnp, 2.00, 1e-9, "domestic RNP 2.00")
M.gps_nav(s)
inp.dt = 60
out = M.update(s, inp)
T.check(out.src == M.DD and out.title == "RADIO" and out.nd == "DD", "GPS inhibited: RADIO, DD on the ND")
T.near(out.anp, 0.05 + M.IRS_RATE / 60, 1e-9, "the ANP grows from GPS's at the IRS rate (estimate)")
inp.dt = 3600
out = M.update(s, inp)
T.near(out.anp, 0.30, 1e-9, "no worse than DME-DME's")
M.gps_nav(s)
inp.dt = 1
out = M.update(s, inp)
T.check(out.src == M.GPS and out.anp == 0.05, "GPS enabled again: GPS's ANP at once")

-- VOR/DME, LOC and the ND's lines (FCOM p.1150)
M.gps_nav(s)
inp.dd, inp.vd = nil, {ident = "SEA", dist = 10, anp = M.anp_vd(10)}
out = M.update(s, inp)
T.check(out.src == M.VD and out.title == "RADIO" and out.nd == "VD" and out.sta_title == "VOR-DME" and out.sta == "SEA", "VOR/DME: VD, VOR-DME SEA")
inp.loc = true
out = M.update(s, inp)
T.check(out.src == M.LOC_VD and out.title == "LOC-VD" and out.nd == "LOC VD", "LOC and VOR/DME")
inp.vd = nil
inp.dd = {a = {ident = "AAA"}, b = {ident = "BBB"}, angle = 80, anp = 0.2}
out = M.update(s, inp)
T.check(out.src == M.LOC_DD and out.title == "LOC-DD" and out.nd == "LOC DD", "LOC and DME-DME")
inp.dd = nil
out = M.update(s, inp)
T.check(out.src == M.LOC and out.title == "LOC" and out.nd == "LOC", "LOC alone (before GPS in the priority)")
M.gps_nav(s)
out = M.update(s, inp)
T.check(out.src == M.LOC_GPS and out.title == "LOC-GPS R" and out.nd == "LOCGPS", "LOC and GPS: LOC-GPS R, LOCGPS")
inp.loc = false

-- the RNP's entries (FCOM p.1368, p.1436)
T.equal(M.enter_rnp(s, "1.5"), "ok", "1.5: under the default 2.00")
out = M.update(s, inp)
T.check(out.rnp == 1.5 and out.rnp_man, "RNP 1.50 the crew's")
T.equal(M.enter_rnp(s, "3"), "verify", "3: over the default, VERIFY RNP ENTRY")
T.equal(M.enter_rnp(s, ".04"), "verify", "0.04: under the ANP 0.05, VERIFY RNP ENTRY")
out = M.update(s, inp)
T.equal(out.src, M.GPS, "RNP 0.04: GPS's 0.05 under twice it, GPS still")
T.equal(M.enter_rnp(s, ".02"), "verify", "0.02 entered")
out = M.update(s, inp)
T.check(out.src ~= M.GPS and out.src ~= M.LOC_GPS, "RNP 0.02: GPS's ACTUAL over twice the RNP, no GPS updating (FCOM p.1368)")
T.check(out.unable and out.advisory and not out.caution, "UNABLE RNP, an advisory outside the approach")
for _, bad in ipairs({"0", "100", "0.001", "A", "", ".", "1.2.3"}) do
    T.equal(M.enter_rnp(s, bad), "invalid", "not an RNP: '" .. bad .. "'")
end
T.equal(M.enter_rnp(s, "DELETE"), "ok", "DELETE: the default")
out = M.update(s, inp)
T.check(out.rnp == 2.00 and not out.rnp_man and out.src == M.GPS, "the default 2.00 again, GPS again")
T.equal(M.enter_rnp(s, "DELETE"), "invalid", "DELETE of the default: INVALID DELETE")

-- VERIFY RNP (FCOM p.1435): the default changes under a larger entry
M.enter_rnp(s, "2.0")
out = M.update(s, inp)
T.check(not out.verify, "2.00 entered in the domestic phase")
inp.d_term = 25
out = M.update(s, inp)
T.check(out.verify and out.phase == M.TERMINAL, "terminal (1.00) under the entry 2.00: VERIFY RNP")
M.enter_rnp(s, "1")
out = M.update(s, inp)
T.check(not out.verify, "1.00 entered: corrected")

-- IRS only in the air: the ANP grows; UNABLE RNP, the caution on the approach
M.enter_rnp(s, "DELETE")
M.gps_nav(s)
inp.gps_r, inp.d_term = false, 100
inp.dt = 1
out = M.update(s, inp)
T.check(out.src == M.IRS and out.title == "INERTIAL" and out.nd == "", "IRS only: INERTIAL, no update line on the ND")
local a1 = out.anp
inp.dt = 3600
out = M.update(s, inp)
T.near(out.anp, a1 + M.IRS_RATE, 1e-9, "an hour later: 1.67 nm more")
T.check(not out.unable, "under the RNP 2.00")
out = M.update(s, inp)
T.check(out.unable and out.advisory and not out.caution, "two hours: 3.38 nm, UNABLE RNP (advisory)")
inp.approach, inp.dt = true, 1
out = M.update(s, inp)
T.check(out.unable and out.caution and not out.advisory and out.rnp == 0.5, "on the approach (RNP 0.50): the caution")
inp.approach = false
inp.ground, inp.dt = true, 3600
local a0 = out.anp
out = M.update(s, inp)
T.near(out.anp, a0, 1e-9, "on the ground the ANP does not grow")
inp.ground = false

-- PURGE (FCOM p.1368)
local s2 = M.new()
local i2 = M.inputs()
i2.irs, i2.gps_l, i2.ground, i2.navaid_near, i2.d_term = true, true, false, true, 100
i2.dt = 3600
M.update(s2, i2)
out = M.update(s2, i2)
T.near(out.irs_anp, M.ANP_ALIGN + M.IRS_RATE, 1e-9, "the IRS's own ANP an hour after it started")
T.near(out.anp, 0.05, 1e-9, "the FMC's GPS")
M.purge(s2)
T.check(s2.purge, "PURGE: CONFIRM showing")
M.confirm(s2)
i2.dt = 1
i2.dd = {a = {ident = "AAA"}, b = {ident = "BBB"}, angle = 80, anp = 0.2}
out = M.update(s2, i2)
T.check(out.src == M.IRS and out.anp > 1.7 and out.sta == "AAA BBB", "CONFIRM: the mixed IRS position's ANP, radio computed still")
i2.dt = 10
out = M.update(s2, i2)
T.check(out.src == M.GPS and out.anp == 0.05, "10 s later GPS updating again (estimate)")
M.purge(s2)
M.purge_cancel(s2)
T.check(not s2.purge, "leaving the page: PURGE again")

-- polar operation (FCOM p.1241-1242)
i2.dt, i2.lat = 1, 84.5
out = M.update(s2, i2)
T.check(out.polar and out.split_event and out.sta_title == "NAV STA" and out.src == M.GPS, "84.5N: polar, SPLIT IRS OPERATION, no radio, GPS on")
out = M.update(s2, i2)
T.check(not out.split_event, "the event once")
i2.lat = 88.6
out = M.update(s2, i2)
T.equal(out.src, M.IRS, "88.6N: no GPS updating")
i2.dt = 3 * 3600
out = M.update(s2, i2)
T.check(out.anp > 2 and not out.unable, "UNABLE RNP inhibited in the polar region")
i2.dt, i2.lat = 1, 88.2
out = M.update(s2, i2)
T.equal(out.src, M.IRS, "88.2N: not yet")
i2.lat = 87.9
out = M.update(s2, i2)
T.equal(out.src, M.GPS, "87.9N: GPS again")
i2.lat = 83.6
out = M.update(s2, i2)
T.check(out.polar, "83.6N: polar still")
i2.lat = 83.4
out = M.update(s2, i2)
T.check(not out.polar and out.sta == "AAA BBB", "83.4N: normal, radio again")

-- the CDU's numbers
T.equal(M.text(2), "2.00", "2.00")
T.equal(M.text(12), "12.00", "12.00")
T.equal(M.text(0.05), "0.05", "0.05")
T.equal(M.text(nil), "", "none: blank")
T.done()
