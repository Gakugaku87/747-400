-- Run from the repository root with LuaJIT: luajit tests/fms/tune_model_test.lua
-- The FMC's VOR and ADF tuning (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.tune_model.lua; 6-1/6-2 step 10b, notes/
-- ATA-34-61-FMC.md §87; FCOM p.1303-1304, FMSPG p.206-207, ATA34_2
-- p.605-606): NAV RADIO's VOR, CRS and ADF entries, DELETE, the FMC's
-- choice of stations (P, R, A) around the manual ones.
local T = dofile("tests/lib/check.lua")("tune_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.tune_model.lua")

local SEA = {ident = "SEA", freq = 11680, lat = 47.4, lon = -122.3}
local ELN = {ident = "ELN", freq = 11790, lat = 47.0, lon = -120.4}
local OLM = {ident = "OLM", freq = 11300, lat = 46.9, lon = -122.9}
local function find(id)
    if id == "SEA" then return SEA end
    if id == "ELN" then return ELN end
    if id == "IAWP" then return false end   -- an ILS's or a waypoint's
    return nil
end

-- frequencies and courses
T.equal(M.vor_freq("116.80"), 11680, "116.80")
T.equal(M.vor_freq("116.8"), 11680, "116.8")
T.equal(M.vor_freq("108.05"), 10805, "108.05: a 50 kHz channel")
T.equal(M.vor_freq("108.03"), nil, "108.03: not a channel")
T.equal(M.vor_freq("118.00"), nil, "118.00: above the VORs")
T.equal(M.vor_freq("107.95"), nil, "107.95: below")
T.equal(M.course("184"), 184, "184")
T.equal(M.course("360"), 0, "360 is 0")
T.equal(M.course("361"), nil, "361: not a course")

-- VOR entries (FCOM p.1304)
local s = M.new()
T.equal(M.vor_entry(s, 1, "SEA", find), M.OK, "SEA on VOR L")
T.check(s.vor[1].mode == "M" and s.vor[1].st == SEA and s.vor[1].crs == nil, "VOR L manual SEA, no course (dashes)")
T.equal(M.vor_entry(s, 2, "117.90/184", find), M.OK, "117.90/184 on VOR R")
T.check(s.vor[2].mode == "M" and s.vor[2].st.freq == 11790 and s.vor[2].st.ident == nil and s.vor[2].crs == 184, "VOR R: 117.90, course 184")
T.equal(M.vor_entry(s, 1, "ELN/090", find), M.OK, "ELN/090: an identifier and a course")
T.check(s.vor[1].st == ELN and s.vor[1].crs == 90, "ELN, 090")
T.equal(M.vor_entry(s, 1, "XYZ", find), M.NOT_IN_DB, "XYZ: NOT IN DATA BASE")
T.equal(M.vor_entry(s, 1, "IAWP", find), M.INVALID, "an ILS's or a waypoint's identifier: INVALID ENTRY")
T.equal(M.vor_entry(s, 1, "108.03", find), M.INVALID, "108.03: INVALID ENTRY")
T.equal(M.vor_entry(s, 1, "SEA/400", find), M.INVALID, "a course of 400: INVALID ENTRY")
T.equal(M.vor_entry(s, 1, "/184", find), M.INVALID, "a course alone on the VOR line: INVALID ENTRY")
T.check(s.vor[1].st == ELN, "the bad entries change nothing")
T.equal(M.vor_entry(s, 1, "DELETE", find), M.OK, "DELETE: back to the FMC's tuning")
T.check(s.vor[1].mode == nil and s.vor[1].crs == nil, "no mode yet, the course cleared (FMSPG p.207)")
T.equal(M.vor_entry(s, 1, "DELETE", find), M.INVALID_DELETE, "DELETE again: INVALID DELETE")

-- CRS (FCOM p.1304: blank when autotuned, a manual VOR's dashes or course)
T.equal(M.crs_entry(s, 1, "184"), M.INVALID, "CRS with the FMC tuning: INVALID ENTRY")
T.equal(M.crs_entry(s, 2, "DELETE"), M.OK, "VOR R's course DELETE: dashes")
T.check(s.vor[2].mode == "M" and s.vor[2].crs == nil, "manual still, no course")
T.equal(M.crs_entry(s, 2, "DELETE"), M.INVALID_DELETE, "DELETE on dashes: INVALID DELETE")
T.equal(M.crs_entry(s, 2, "45"), M.OK, "45")
T.equal(s.vor[2].crs, 45, "course 045")
T.equal(M.crs_entry(s, 2, "ABC"), M.INVALID, "ABC: INVALID ENTRY")

-- ADF (FCOM p.1304; FMSPG p.207)
T.equal(M.adf_entry(s, 1, "1304.5B", 350), M.OK, "1304.5B: BFO")
T.check(s.adf[1].khz == 1304.5 and s.adf[1].mode == "BFO", "1304.5, BFO")
T.equal(M.adf_entry(s, 1, "A", 1304), M.OK, "A alone: ANT")
T.equal(s.adf[1].mode, "ANT", "ANT")
T.equal(M.adf_entry(s, 1, "DELETE", 1304), M.OK, "DELETE: ADF again")
T.equal(s.adf[1].mode, "ADF", "ADF")
T.equal(M.adf_entry(s, 1, "DELETE", 1304), M.INVALID_DELETE, "DELETE in ADF: not allowed")
T.equal(M.adf_entry(s, 2, "350", 0), M.OK, "350 on ADF R")
T.check(s.adf[2].khz == 350 and s.adf[2].mode == "ADF", "350, ADF")
for _, bad in ipairs({"100", "2000", "350.", "35", "350C", "B"}) do
    T.equal(M.adf_entry(s, 2, bad, bad == "B" and 0 or 350), M.INVALID, "not an ADF entry: " .. bad)
end

-- the FMC's stations (estimates): VOR L the first, VOR R the next
local s2 = M.new()
local c = M.candidates({{st = SEA}}, ELN, OLM, {SEA, OLM})
T.equal(#c, 3, "SEA once: P, R ELN, R OLM")
T.check(c[1].mode == "P" and c[2].mode == "R" and c[2].st == ELN and c[3].st == OLM, "the order: P, the downpath R, the previous R")
M.choose(s2, c)
T.check(s2.vor[1].mode == "P" and s2.vor[1].st == SEA, "VOR L: P SEA")
T.check(s2.vor[2].mode == "R" and s2.vor[2].st == ELN, "VOR R: R ELN")
M.choose(s2, M.candidates({}, nil, nil, {OLM, SEA}))
T.check(s2.vor[1].mode == "A" and s2.vor[1].st == OLM and s2.vor[2].mode == "A" and s2.vor[2].st == SEA, "no route: A OLM and SEA")
M.vor_entry(s2, 1, "SEA", find)
M.choose(s2, M.candidates({}, nil, nil, {SEA, OLM}))
T.check(s2.vor[1].mode == "M" and s2.vor[2].mode == "A" and s2.vor[2].st == OLM, "VOR L manual SEA: VOR R A OLM, not SEA again")
M.choose(s2, {})
T.check(s2.vor[2].mode == "A" and s2.vor[2].st == OLM, "no station: VOR R keeps its own")
T.equal(M.freq_text(11680), "116.80", "116.80")
T.equal(M.adf_text(1304.5), "1304.5", "1304.5")

-- (step 10c) the ILS (FCOM p.1304-1307)
T.equal(M.ils_freq("110.90"), 11090, "110.90")
T.equal(M.ils_freq("109.5"), 10950, "109.5")
T.equal(M.ils_freq("110.80"), nil, "110.80: an even tenth (a VOR's)")
T.equal(M.ils_freq("112.10"), nil, "112.10: above the ILSs")
T.equal(M.ils_freq("108.05"), nil, "108.05: a VOR's")
local s3 = M.new()
local IZA = {ident = "IZA", freq = 10950, crs = 157, lat = 35, lon = 140}
local o = M.ils_update(s3, {})
T.check(o.mode == "PARK" and o.tune == nil, "no destination ILS: PARK")
o = M.ils_update(s3, {ils = IZA, standby = true})
T.check(o.mode == "STBY" and o.st == IZA and o.tune == nil, "within 200 nm of the T/D and past halfway: shown, PARK")
o = M.ils_update(s3, {ils = IZA, auto = true, after_takeoff = true})
T.equal(o.mode, "STBY", "ten minutes after takeoff: no autotuning")
o = M.ils_update(s3, {ils = IZA, auto = true})
T.check(o.mode == "A" and o.tune == IZA and not o.freq_err and not o.crs_err, "A: tuned")
local OTHER = {ident = "IZB", freq = 11030, crs = 337, lat = 36, lon = 141}
o = M.ils_update(s3, {ils = OTHER, auto = true, inhibit = true})
T.check(o.mode == "A" and o.tune == IZA and o.held_change, "the FCCs' ILS TUNE INHIBIT: held, the destination's new ILS noted")
T.equal(M.ils_entry(s3, "110.30/120", o.st, true), M.ILS_INHIBITED, "an entry under it: ILS TUNE INHIBITED - MCP (FCOM p.1432)")
o = M.ils_update(s3, {ils = IZA, auto = true})
T.check(not o.held_change, "no change without the inhibit")
T.equal(M.ils_entry(s3, "110.30/120", o.st, false), M.OK, "110.30/120")
o = M.ils_update(s3, {ils = IZA, auto = true})
T.check(o.mode == "M" and o.tune.freq == 11030 and o.freq_err and not o.crs_err, "M on another ILS: RW/ILS FREQ ERROR")
T.equal(M.ils_entry(s3, "DELETE", o.st, false), M.OK, "DELETE")
o = M.ils_update(s3, {ils = IZA, auto = true})
T.equal(o.mode, "A", "back to the FMC's: A")
T.equal(M.ils_entry(s3, "/150", o.st, false), M.OK, "/150 with 109.50 shown")
o = M.ils_update(s3, {ils = IZA, auto = true})
T.check(o.mode == "M" and o.tune.freq == 10950 and o.tune.crs == 150 and o.crs_err and not o.freq_err, "M 109.50/150: RW/ILS CRS ERROR")
T.equal(M.ils_entry(s3, "110.90", o.st, false), M.INVALID, "a frequency without its course: INVALID ENTRY")
T.equal(M.ils_entry(s3, "110.80/130", o.st, false), M.INVALID, "an even tenth: INVALID ENTRY")
M.ils_entry(s3, "DELETE", o.st, false)
T.equal(M.ils_entry(s3, "DELETE", nil, false), M.INVALID_DELETE, "DELETE without M: INVALID DELETE")
local s4 = M.new()
T.equal(M.ils_entry(s4, "/130", nil, false), M.INVALID, "/130 with none shown: INVALID ENTRY")
o = M.ils_update(s4, {ils = IZA, standby = true})
T.equal(M.ils_select(s4, o.st, false), M.OK, "the standby line's select")
o = M.ils_update(s4, {ils = IZA, standby = true})
T.check(o.mode == "M" and o.tune.freq == 10950 and o.tune.crs == 157, "manually tuned (FCOM p.1306)")
T.equal(M.ils_text(IZA), "109.50/157", "109.50/157")
T.done()
