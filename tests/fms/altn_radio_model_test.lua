-- Run from the repository root with LuaJIT: luajit tests/fms/altn_radio_model_test.lua
-- A CDU's ALTN NAV RADIO (6-1/6-2 step 11e3; notes/ATA-34-61-FMC.md §104;
-- FCOM p.1427-1428; FMSPG p.252-254): the copy of the FMC's tuning; VOR
-- (a frequency, frequency/course; DELETE dashes), CRS (a course,
-- frequency/course, /course; DELETE), ADF (a frequency, with A or B, A or B
-- alone; DELETE dashes), ILS (a frequency with the runway's course or the
-- last or 000, frequency/course, /course; DELETE PARK), PRESELECT.
local T = dofile("tests/lib/check.lua")("altn_radio_model")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.tune_model.lua")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.altn_radio_model.lua")

local s = M.new()
M.copy(s, {vor_freq = 11680, vor_crs = nil, adf_khz = 362, adf_mode = "ANT", ils_freq = 11080, ils_crs = 37})
T.check(s.vor.freq == 11680 and s.vor.crs == nil, "the copy: VOR 116.80 (FMSPG p.252)")
T.check(s.adf.khz == 362 and s.adf.mode == "ANT", "ADF 362 ANT")
T.check(s.ils.freq == 11080 and s.ils.crs == 37, "ILS 110.80/037 (FCOM p.1428: autotuned, copied)")

-- VOR
T.equal(M.vor(s, "114.50/270"), nil, "VOR 114.50/270")
T.check(s.vor.freq == 11450 and s.vor.crs == 270, "frequency and course")
T.equal(M.vor(s, "113.9"), nil, "VOR 113.9")
T.check(s.vor.freq == 11390 and s.vor.crs == 270, "the course kept")
T.equal(M.vor(s, "118.00"), M.INVALID, "out of the band: INVALID ENTRY")
T.equal(M.vor(s, "/090"), M.INVALID, "a course alone on the VOR line: INVALID ENTRY (estimate)")
T.equal(M.vor(s, "XYZ"), M.INVALID, "an identifier: INVALID ENTRY (no navigation database)")
-- CRS
T.equal(M.crs(s, "110"), nil, "CRS 110: a course (not 110.00)")
T.check(s.vor.crs == 110 and s.vor.freq == 11390, "the course only")
T.equal(M.crs(s, "112.30/045"), nil, "CRS frequency/course")
T.check(s.vor.freq == 11230 and s.vor.crs == 45, "both")
T.equal(M.crs(s, "/180"), nil, "CRS /180")
T.equal(s.vor.crs, 180, "180")
T.equal(M.crs(s, "112.30"), M.INVALID, "a frequency alone on CRS: INVALID ENTRY")
T.equal(M.crs(s, "DELETE"), nil, "CRS DELETE")
T.equal(s.vor.crs, nil, "the course cleared (FMSPG p.253)")
T.equal(M.crs(s, "DELETE"), M.INVALID_DELETE, "nothing to delete")
T.equal(M.vor(s, "DELETE"), nil, "VOR DELETE")
T.equal(s.vor.freq, nil, "dashes (FMSPG p.253)")
-- ADF
T.equal(M.adf(s, "1304.5B"), nil, "ADF 1304.5B")
T.check(s.adf.khz == 1304.5 and s.adf.mode == "BFO", "BFO")
T.equal(M.adf(s, "A"), nil, "A alone")
T.equal(s.adf.mode, "ANT", "ANT")
T.equal(M.adf(s, "415"), nil, "415")
T.check(s.adf.khz == 415 and s.adf.mode == "ADF", "ADF")
T.equal(M.adf(s, "1800"), M.INVALID, "out of the band")
T.equal(M.adf(s, "DELETE"), nil, "ADF DELETE")
T.equal(s.adf.khz, nil, "dashes (FMSPG p.253)")
T.equal(M.adf(s, "B"), M.INVALID, "B alone without a frequency: INVALID ENTRY")
-- ILS
T.equal(M.ils(s, "109.50", 157), nil, "ILS 109.50 with a runway's course")
T.check(s.ils.freq == 10950 and s.ils.crs == 157, "its course the runway's (FCOM p.1428)")
T.equal(M.ils(s, "110.30", nil), nil, "ILS 110.30 without a runway")
T.equal(s.ils.crs, 157, "the last course")
T.equal(M.ils(s, "/335", nil), nil, "/335")
T.equal(s.ils.crs, 335, "the course")
T.equal(M.ils(s, "111.10/090", nil), nil, "111.10/090")
T.check(s.ils.freq == 11110 and s.ils.crs == 90, "both")
T.equal(M.ils(s, "110.20", nil), M.INVALID, "an even tenth: not an ILS frequency")
T.equal(M.ils(s, "DELETE", nil), nil, "ILS DELETE")
T.equal(s.ils.freq, nil, "PARK (FCOM p.1428)")
T.equal(M.ils(s, "/090", nil), M.INVALID, "a course with PARK: INVALID ENTRY")
local s2 = M.new()
T.equal(M.ils(s2, "108.90", nil), nil, "a first ILS without a runway")
T.equal(s2.ils.crs, 0, "000 (FCOM p.1428)")
-- PRESELECT
T.equal(M.preselect(s, 1, "110.90/128"), nil, "PRESELECT 6L 110.90/128 (FMSPG p.254)")
T.equal(s.pre[1], "110.90/128", "kept")
T.equal(M.preselect(s, 2, "1304.5A"), nil, "an ADF entry on 6R")
T.equal(M.preselect(s, 2, "270"), nil, "a course")
T.equal(M.preselect(s, 2, "XYZ"), M.INVALID, "not an entry of any line: INVALID ENTRY")
T.equal(s.pre[2], "270", "the last valid one kept")
T.equal(M.preselect(s, 1, "DELETE"), nil, "DELETE (estimate)")
T.equal(s.pre[1], nil, "cleared")

T.done()
