-- Run from the repository root with LuaJIT: luajit tests/displays/pfd_model_test.lua
-- The PFD sources model (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/
-- B747.60.pfd_model.lua, 5-2 step 4a) without X-Plane: what each pilot's PFD
-- shows from the IRS and the air data, and the ATT, HDG and VERT flags
-- (FCOM p.996-999, p.1228; ATA31 p.15-17).
local T = dofile("tests/lib/check.lua")("pfd_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.pfd_model.lua")

local s, inp, out
local function run() out = M.update(s, inp) end
s, inp = M.new(), M.inputs()
run()
local c, f = out[M.CAPT], out[M.FO]
T.check(c.att and c.hdg and c.trk and c.vsi and not c.vert, "all IRUs in NAV: everything shown, no flags")
T.equal(c.hdg_iru, M.L, "the Captain's heading through FMC L: IRU L")
T.equal(f.hdg_iru, M.R, "the F/O's through FMC R: IRU R")

-- IRU L in ATT: attitude and a heading set, no navigation
inp.nav_valid[M.L] = false
run()
T.check(c.att, "IRU L in ATT: the attitude shown")
T.equal(c.hdg_iru, M.C, "the heading through the FMC from the next IRU in NAV, C (FCOM p.1228)")
T.check(c.trk, "the track through the FMC")
T.check(c.vert and not c.vsi, "no inertial vertical speed in ATT: the VERT flag (estimate)")
-- the NAV source on a CDU: the IRS-selected IRU
inp.fmc[M.CAPT] = 0
run()
T.equal(c.hdg_iru, M.L, "NAV on a CDU: the selected IRU L (ATT with a heading set)")
T.check(not c.trk, "no track from an IRU in ATT")
inp.hdg_valid[M.L] = false
run()
T.check(not c.hdg and c.hdg_iru == 0, "no heading set in ATT: the HDG flag")
inp.att_valid[M.L] = false
run()
T.check(not c.att, "IRU L's attitude not valid (the first 30 s in ATT): the ATT flag")
-- the IRS selector on C
inp.irs[M.CAPT] = M.C
run()
T.check(c.att and c.hdg and c.trk and c.vsi and not c.vert, "IRS selector C: everything from IRU C")
T.equal(c.hdg_iru, M.C, "the heading from IRU C")
-- all three IRUs lost (an FMC selected): no heading anywhere
inp.att_valid = {false, false, false}
inp.hdg_valid = {false, false, false}
inp.nav_valid = {false, false, false}
inp.fmc[M.CAPT] = 1
run()
T.check(not c.att and not c.hdg and not c.trk and c.vert, "all IRUs lost: ATT, HDG and VERT flags")
T.check(not f.att and not f.hdg and f.vert, "the F/O's too")
-- the air data invalid: the vertical speed removed without a flag (ATA31 p.16)
s, inp = M.new(), M.inputs()
inp.air_data[M.CAPT] = false
run()
c, f = out[M.CAPT], out[M.FO]
T.check(not c.vsi and not c.vert, "the Captain's air data invalid: no vertical speed, no VERT flag")
T.check(f.vsi, "the F/O's unaffected")

-- the barometric setting's amber box (step 4b, FCOM p.995)
local A = function(std, alt, mcp) return M.baro_alert(std, alt, mcp, 18000, 18000) end
T.check(not A(false, 18200, 35000), "QNH, climbing to FL350: not yet at 18,200 ft")
T.check(A(false, 18400, 35000), "QNH, 18,400 ft (300 ft above the transition altitude): boxed amber")
T.check(not A(true, 18400, 35000), "STD set: cleared")
T.check(not A(false, 18400, 17000), "QNH above it but the MCP altitude below it (descending): no box")
T.check(not A(true, 17800, 11000), "STD, descending to 11,000 ft: not yet at 17,800 ft")
T.check(A(true, 17600, 11000), "STD, 17,600 ft (300 ft below the transition level): boxed amber")
T.check(not A(false, 17600, 11000), "QNH set: cleared")
T.check(not A(true, 17600, 19000), "STD below it with the MCP altitude above it (climbing): no box")
T.check(not M.baro_alert(true, 14800, 9000, 14000, 15000), "TA 14,000 ft, TL FL150: STD at 14,800 ft (less than 300 ft below FL150): no box")
T.check(M.baro_alert(true, 14600, 9000, 14000, 15000), "STD at 14,600 ft (more than 300 ft below FL150): boxed amber")
T.check(M.baro_alert(false, 14400, 35000, 14000, 15000), "QNH climbing through 14,400 ft (300 ft above the TA, below the TL): boxed amber")

T.done()
