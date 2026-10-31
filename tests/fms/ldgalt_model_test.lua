-- Run from the repository root with LuaJIT: luajit tests/fms/ldgalt_model_test.lua
-- The FMC's landing altitude for the cabin pressure controllers (6-1/6-2
-- step 11b; notes/ATA-34-61-FMC.md §91; FCOM p.1400, p.993; ATA34_2
-- p.477): the departure runway's or the origin's before the switch point,
-- the switch at 400 NM, halfway, two minutes before the T/D in the cruise
-- and in the descent, then the approach runway's or the destination's;
-- kept once switched; none without the airport.
local T = dofile("tests/lib/check.lua")("ldgalt_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.ldgalt_model.lua")

local function inp(t)
    local i = {origin_ft = 135, dest_ft = 17, from_nm = 10, to_nm = 290, phase = "CLB", gs_kt = 250, air = true}
    for k, v in pairs(t or {}) do if v == "none" then i[k] = nil else i[k] = v end end
    return i
end

-- before the switch point: the departure's
local s = M.new()
T.equal(M.update(s, inp({air = false, from_nm = 0})), 135, "on the ground: the origin's elevation (FCOM p.993)")
T.equal(M.update(s, inp({air = false, from_nm = 0, dep_rwy_ft = 139})), 139, "with a departure runway: its threshold's")
T.equal(M.update(s, inp({dep_rwy_ft = 139})), 139, "after the takeoff: still the departure's (a return)")
T.check(not s.switched, "not switched yet")
T.equal(M.update(s, inp({origin_ft = "none"})), nil, "no origin: none (LANDING ALT)")

-- 400 NM from the origin (FCOM p.1400)
s = M.new()
T.equal(M.update(s, inp({from_nm = 399, to_nm = 1500})), 135, "399 NM out: the departure's")
T.equal(M.update(s, inp({from_nm = 401, to_nm = 1500})), 17, "401 NM out: the destination's")
T.equal(M.update(s, inp({from_nm = 401, to_nm = 1500, appr_rwy_ft = 12})), 12, "an approach selected: its runway's threshold")
T.equal(M.update(s, inp({from_nm = 10, to_nm = 1500})), 17, "kept once switched (back near the origin)")

-- halfway
s = M.new()
T.equal(M.update(s, inp({from_nm = 140, to_nm = 150})), 135, "short of halfway: the departure's")
T.equal(M.update(s, inp({from_nm = 150, to_nm = 140})), 17, "past halfway: the destination's")

-- the cruise within two minutes of the T/D, the descent
s = M.new()
T.equal(M.update(s, inp({phase = "CRZ", td_nm = 20, gs_kt = 480})), 135, "the cruise, 2.5 min to the T/D: the departure's")
T.equal(M.update(s, inp({phase = "CRZ", td_nm = 15, gs_kt = 480})), 17, "1.9 min to the T/D: the destination's")
s = M.new()
T.equal(M.update(s, inp({phase = "CLB", td_nm = 5, gs_kt = 480})), 135, "the climb near the T/D: not past the T/C")
T.equal(M.update(s, inp({phase = "CRZ", td_nm = -3, gs_kt = 480})), 17, "the cruise past the T/D: the destination's")
s = M.new()
T.equal(M.update(s, inp({phase = "CRZ", td_nm = 10, gs_kt = 50})), 135, "no time to the T/D under 100 kt")
T.equal(M.update(s, inp({phase = "DES"})), 17, "the descent: the destination's")
s = M.new()
T.equal(M.update(s, inp({phase = "DES", air = false})), 135, "on the ground nothing switches")

-- after the switch without a destination: none
s = M.new()
T.equal(M.update(s, inp({phase = "DES", dest_ft = "none"})), nil, "switched, no destination: none (LANDING ALT)")
T.done()
