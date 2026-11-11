-- Run from the repository root with LuaJIT: luajit tests/autopilot/vnav_mode_model_test.lua
-- VNAV's engagement and sub-modes (6-1/6-2 step 9i; notes/ATA-34-61-FMC.md
-- §150): plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/
-- B747.70.vnav_mode_model.lua. The engage on FMC DATA VALID above 400 ft
-- (ATA34_2 p.621, ATA22 p.341, FCOM p.645), PERF/VNAV UNAVAILABLE (FCOM
-- p.645, p.1433), following the FMC's VNAV SPD and VNAV PTH, the levels:
-- the FMC altitude captured (VNAV PTH: ATA22 p.280), the MCP altitude
-- captured or here as the profile would leave it (VNAV ALT: ATA22 p.280,
-- ATA34_2 p.624, FMSPG p.34 (2-22), the T/D among them), the MCP altitude behind
-- the FMC's way (VNAV ALT at the altitude then: FCOM p.665, FMSPG p.226 (4-15),
-- p.4-16; on approach 300 ft above goes on: FCOM p.1261), a climb
-- constraint below (VNAV PTH: FMSPG p.128 (3.3-19)), the FMC's data lost (VNAV
-- PTH: estimate); VNAV ALT's end by the push or the path (FCOM p.645,
-- p.665). (A second patch of step 9i) VNAV ALT on approach ended with the
-- MCP altitude 300 ft or more above (FCOM p.1261); an MCP altitude behind
-- the way within AT_MCP_FT held where the airplane is, not gone back to
-- (FMSPG p.226-227: estimate); in the descent on a level part of the path
-- the MCP altitude captured from above (FMSPG p.227); the descent's FMC
-- altitude a floor above the airplane (VNAV PTH) or the FMC's AT OR BELOW
-- target under it (VNAV SPD on: the FMC's des_target). A first patch
-- failed these.
local T = dofile("tests/lib/check.lua")("vnav_mode_model")
local V = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.vnav_mode_model.lua")

-- the climb: VNAV SPD to FL350 with THR REF at 12,000 ft, the MCP at
-- 20,000 ft
local function inp(t)
    local i = {engaged = true, valid = true, phase = 1, mode = 1, fmc_alt = 35000, vs = 0, at = 5,
        path_dev = 0, td_hold = false, on_app = false, mcp = 20000, alt = 12000, pushes = 0,
        cap_mcp = false, cap_fmc = false}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end

-- the engage and the message
T.check(V.can_engage(true, true, false, 401), "FMC DATA VALID: valid, the master FMC, in the air above 400 ft")
T.check(not V.can_engage(true, true, false, 399), "399 ft: not yet (FCOM p.645)")
T.check(not V.can_engage(true, true, true, 500), "on the ground: not")
T.check(not V.can_engage(false, true, false, 5000), "the FMC's VNAV not valid: not")
T.check(not V.can_engage(true, false, false, 5000), "the master FMC failed: not")
T.check(V.unavailable(false, false, 1), "the performance data not entered: PERF/VNAV UNAVAILABLE (FCOM p.1433)")
T.check(V.unavailable(true, false, 3), "the descent without its path: PERF/VNAV UNAVAILABLE (FCOM p.645)")
T.check(not V.unavailable(true, false, 1), "the climb, data entered (an arm on the ground, waiting): none")
T.check(not V.unavailable(true, true, 3), "the descent with its path: none")

-- following the FMC: the climb's VNAV SPD on the speed law, its THR REF
local s = V.new()
local o = V.update(s, inp())
T.check(o.fma == V.FMA.SPD and o.law == "FLCH" and o.at == 5 and not o.level, "the climb: VNAV SPD, the speed law, THR REF")
-- the MCP altitude captured first: VNAV ALT there, the A/T on speed
o = V.update(s, inp({alt = 19400, cap_mcp = true}))
T.check(o.fma == V.FMA.ALT and o.law == "ALT" and o.law_alt == 20000, "the MCP altitude captured: VNAV ALT at 20,000 (ATA22 p.280)")
T.check(o.at == V.AT_SPD and o.level and o.kind == "mcp", "the A/T SPD (FCOM p.645)")
o = V.update(s, inp({alt = 20000}))
T.equal(o.fma, V.FMA.ALT, "level there: VNAV ALT")
-- a push without a new MCP altitude: VNAV ALT still; a new MCP altitude
-- without a push: still; reset and pushed: VNAV SPD (FCOM p.645, p.1256)
o = V.update(s, inp({alt = 20000, pushes = 1}))
T.equal(o.fma, V.FMA.ALT, "pushed with the MCP at the airplane: VNAV ALT still")
o = V.update(s, inp({alt = 20000, pushes = 1, mcp = 24000}))
T.equal(o.fma, V.FMA.ALT, "the MCP reset to 24,000 ft, no push: VNAV ALT still")
o = V.update(s, inp({alt = 20000, pushes = 2, mcp = 24000}))
T.check(o.fma == V.FMA.SPD and o.law == "FLCH" and not o.level, "pushed: VNAV SPD again")
-- the FMC altitude (a constraint) before the MCP's: VNAV PTH, held until it
-- moves on
o = V.update(s, inp({alt = 21800, pushes = 2, mcp = 24000, fmc_alt = 22000, cap_fmc = true}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 22000 and o.kind == "fmc", "the FMC altitude captured: VNAV PTH at 22,000")
o = V.update(s, inp({alt = 22000, pushes = 2, mcp = 24000, fmc_alt = 22000}))
T.equal(o.fma, V.FMA.PTH, "held at it")
o = V.update(s, inp({alt = 22300, pushes = 2, mcp = 24000, fmc_alt = 22000}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 22000, "300 ft over it: still VNAV PTH, back to 22,000")
o = V.update(s, inp({alt = 22000, pushes = 2, mcp = 24000, fmc_alt = 35000}))
T.equal(o.fma, V.FMA.SPD, "the FMC's next altitude: VNAV SPD")
-- both captured at once: the same altitude VNAV PTH (FCOM p.1256: VNAV ALT
-- is for an MCP altitude not in the FMC); else the nearer first
o = V.update(s, inp({alt = 23800, pushes = 2, mcp = 24000, fmc_alt = 24000, cap_fmc = true, cap_mcp = true}))
T.check(o.fma == V.FMA.PTH and o.kind == "fmc", "the FMC and MCP altitudes the same: VNAV PTH")
local s2 = V.new()
o = V.update(s2, inp({alt = 23700, mcp = 24000, fmc_alt = 23900, cap_fmc = true, cap_mcp = true}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 23900, "the FMC altitude nearer: VNAV PTH at it")
local s3 = V.new()
o = V.update(s3, inp({alt = 23700, mcp = 23900, fmc_alt = 24000, cap_fmc = true, cap_mcp = true}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 23900, "the MCP altitude nearer: VNAV ALT at it")
-- the MCP altitude only: captured, but the FMC's the same and not yet
-- captured: VNAV PTH
local s3b = V.new()
o = V.update(s3b, inp({alt = 23700, mcp = 24000, fmc_alt = 24030, cap_mcp = true}))
T.check(o.fma == V.FMA.PTH and o.kind == "fmc" and o.law_alt == 24030, "the MCP's capture at the FMC altitude: VNAV PTH")

-- the engage with the MCP altitude at the airplane's, the FMC climbing:
-- VNAV ALT there at once (FMSPG p.34 (2-22)); 30 ft over it held there, no
-- descent in the climb (FMSPG p.226 (4-15): estimate; a first patch of step
-- 9i went down to it), 10 ft over it the MCP altitude (within CAP_NEAR_FT)
local s4 = V.new()
o = V.update(s4, inp({alt = 20030}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp" and o.law_alt == 20030,
    "engaged 30 ft over the MCP altitude, the FMC climbing: VNAV ALT where it is (" .. o.law_alt .. ")")
local s4b = V.new()
o = V.update(s4b, inp({alt = 20010}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 20000, "10 ft over it: VNAV ALT at the MCP altitude")
-- the descent: the MCP altitude set 80 ft above the airplane: VNAV ALT where
-- it is, no climb in the descent (FMSPG p.227 (4-16); a first patch of step
-- 9i climbed the 80 ft)
local s4c = V.new()
o = V.update(s4c, inp({phase = 3, mode = 2, vs = -2000, at = 2, fmc_alt = 6000, alt = 12000, mcp = 12080}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp" and o.law_alt == 12000,
    "the descent, the MCP 80 ft above: VNAV ALT at 12,000 (" .. o.law_alt .. ")")
-- the MCP set below the airplane in the climb: VNAV ALT at the altitude
-- then (FCOM p.665; FMSPG p.226 (4-15): no descent in the climb), once the
-- MCP altitude is settled (the glue's: a second patch of step 9i; not
-- settled, the knob's passing value, no level)
local s5 = V.new()
V.update(s5, inp({alt = 15000}))
o = V.update(s5, inp({alt = 15000, mcp = 10000, settled = false}))
T.check(not o.level and o.fma == V.FMA.SPD, "the MCP below, not settled: VNAV SPD still")
o = V.update(s5, inp({alt = 15000, mcp = 10000}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 15000 and o.kind == "hold", "the MCP set below in the climb: VNAV ALT at 15,000")
o = V.update(s5, inp({alt = 15020, mcp = 25000}))
T.equal(o.fma, V.FMA.ALT, "set above, no push: VNAV ALT still at its altitude")
T.equal(o.law_alt, 15000, "the altitude then")
o = V.update(s5, inp({alt = 15020, mcp = 25000, pushes = 1}))
T.equal(o.fma, V.FMA.SPD, "pushed: VNAV SPD")
-- a climb constraint below the airplane (entered, or its waypoint still
-- ahead): VNAV PTH at the altitude then until the FMC altitude moves on
-- (FMSPG p.128 (3.3-19))
local s6 = V.new()
V.update(s6, inp({alt = 15000}))
o = V.update(s6, inp({alt = 15000, fmc_alt = 13000}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 15000 and o.kind == "far" and o.at == V.AT_SPD,
    "a climb constraint 2,000 ft below: VNAV PTH at 15,000, the A/T SPD")
o = V.update(s6, inp({alt = 15000, fmc_alt = 13000}))
T.equal(o.kind, "far", "held")
o = V.update(s6, inp({alt = 15000, fmc_alt = 35000}))
T.equal(o.fma, V.FMA.SPD, "its waypoint passed, the next above: VNAV SPD")
local s6b = V.new()
o = V.update(s6b, inp({alt = 15000, fmc_alt = 14950}))
T.equal(o.fma, V.FMA.SPD, "50 ft below (within FAR_FT): no level")
-- not engaged: no level, the FMC's sub-mode
o = V.update(s6, inp({alt = 15000, fmc_alt = 13000, engaged = false}))
T.check(not o.level and o.fma == V.FMA.SPD, "not engaged: no level")

-- the cruise: VNAV PTH at CRZ ALT on the ALT law; the MCP moved, no
-- conflict (the FMC holds its altitude)
local c = V.new()
local function crz(t)
    local i = inp({phase = 2, mode = 2, fmc_alt = 35000, alt = 35000, mcp = 35000, at = 3})
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
o = V.update(c, crz())
T.check(o.fma == V.FMA.PTH and o.law == "ALT" and o.law_alt == 35000 and not o.level, "the cruise: VNAV PTH at CRZ ALT")
o = V.update(c, crz({mcp = 31000}))
T.check(o.fma == V.FMA.PTH and not o.level, "the MCP set below, not pushed: VNAV PTH still (the FMC holds CRZ ALT)")
-- past the T/D held by the MCP altitude (the FMC's td_hold): VNAV ALT at
-- it (FMSPG p.34 (2-22); ATA22 p.280: the FMC's would leave the MCP altitude)
o = V.update(c, crz({td_hold = true}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 35000 and o.kind == "mcp" and o.at == V.AT_SPD, "past the T/D, the MCP at CRZ ALT: VNAV ALT")
o = V.update(c, crz({td_hold = true, pushes = 1}))
T.equal(o.fma, V.FMA.ALT, "pushed without the MCP reset: VNAV ALT")
-- the MCP reset below: the FMC's descent (phase 3), its path below the
-- airplane: VNAV ALT until pushed (above the path)
local function des(t)
    local i = inp({phase = 3, mode = 2, fmc_alt = 10000, alt = 35000, mcp = 10000, at = 2, vs = -2500, path_dev = 400})
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
o = V.update(c, des({pushes = 1}))
T.equal(o.fma, V.FMA.ALT, "the MCP reset below, the FMC descending 400 ft under: VNAV ALT, the push wanted")
o = V.update(c, des({pushes = 2}))
T.check(o.fma == V.FMA.PTH and o.law == "VS" and o.law_vs == -2500 and o.at == 2, "pushed: VNAV PTH on the path, IDLE")
-- (with the MCP above CRZ ALT past the T/D: VNAV ALT at the altitude then)
local c2 = V.new()
o = V.update(c2, crz({td_hold = true, mcp = 39000}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 35000 and o.kind == "hold", "past the T/D with the MCP above: VNAV ALT at 35,000")
-- an FMC level altitude held there "fmc" ends at the T/D's hold
local c3 = V.new()
V.update(c3, crz({phase = 1, mode = 1, at = 5, alt = 34900, cap_fmc = true, cap_mcp = true}))
o = V.update(c3, crz())
T.check(o.kind == "fmc" and o.fma == V.FMA.PTH, "CRZ ALT captured at the T/C: VNAV PTH")
o = V.update(c3, crz({td_hold = true}))
T.check(o.kind == "mcp" and o.fma == V.FMA.ALT, "then the T/D held by the MCP: VNAV ALT")
-- VNAV ALT becomes the FMC's VNAV PTH when the FMC holds its altitude
-- (estimate): the climb's VNAV ALT at 20,000 ft, CRZ ALT 20,000 entered
local c4 = V.new()
V.update(c4, inp({alt = 19500, cap_mcp = true}))
o = V.update(c4, crz({alt = 20000, mcp = 20000, fmc_alt = 20000}))
T.check(o.fma == V.FMA.PTH and not o.level, "CRZ ALT the MCP altitude: VNAV PTH (the FMC's level)")

-- the cruise descent (FCOM p.1268-1269: VNAV PTH at 1,250 fpm): the V/S law,
-- the new CRZ ALT captured: VNAV PTH there; the MCP first: VNAV ALT
local cd = V.new()
o = V.update(cd, crz({vs = -1250, fmc_alt = 31000, mcp = 31000}))
T.check(o.fma == V.FMA.PTH and o.law == "VS" and o.law_vs == -1250, "the cruise descent: VNAV PTH on the V/S law")
o = V.update(cd, crz({vs = -1250, fmc_alt = 31000, mcp = 31000, alt = 31400, cap_fmc = true, cap_mcp = true}))
T.check(o.kind == "fmc" and o.law_alt == 31000, "the new CRZ ALT (the MCP's too) captured: VNAV PTH")
local cd2 = V.new()
o = V.update(cd2, crz({vs = -1250, fmc_alt = 31000, mcp = 33000, alt = 33400, cap_mcp = true}))
T.check(o.kind == "mcp" and o.fma == V.FMA.ALT and o.law_alt == 33000, "the MCP's 33,000 first: VNAV ALT")
-- the driftdown (VNAV SPD with THR, FCOM p.1268's condition 2): the MCP at
-- the airplane's: VNAV ALT
local dd = V.new()
o = V.update(dd, crz({mode = 1, at = 4, vs = -300, fmc_alt = 30000}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 35000, "ENG OUT executed with the MCP at the airplane: VNAV ALT (FCOM p.1268)")

-- the descent on its path: VNAV PTH on the V/S law; the MCP altitude
-- captured: VNAV ALT (the path goes on through the FMC's constraint, the
-- same altitude too: LF2); level segments of the path no conflict
local d = V.new()
o = V.update(d, des({alt = 20000, path_dev = 0}))
T.check(o.fma == V.FMA.PTH and o.law == "VS" and o.at == 2, "the descent: VNAV PTH, the path's V/S, IDLE")
o = V.update(d, des({alt = 10400, path_dev = 0, cap_mcp = true, cap_fmc = true}))
T.check(o.fma == V.FMA.ALT and o.law_alt == 10000, "the MCP altitude (the constraint's too) captured: VNAV ALT")
local d2 = V.new()
o = V.update(d2, des({alt = 20000, mcp = 25000, vs = -50}))
T.check(o.fma == V.FMA.PTH and not o.level, "the path level (50 fpm), the MCP above: no conflict")
-- the MCP set above in the descent: VNAV ALT at the altitude then (FCOM
-- p.665; FMSPG p.227 (4-16)); on approach 300 ft or more above goes on (FCOM
-- p.1261), less levels
o = V.update(d2, des({alt = 20000, mcp = 25000}))
T.check(o.fma == V.FMA.ALT and o.kind == "hold" and o.law_alt == 20000, "the MCP above in the descent: VNAV ALT at 20,000")
local d3 = V.new()
o = V.update(d3, des({alt = 2000, mcp = 3000, on_app = true}))
T.check(o.fma == V.FMA.PTH and not o.level, "on approach, the MCP 1,000 ft above: the descent goes on (FCOM p.1261)")
o = V.update(d3, des({alt = 2000, mcp = 2300, on_app = true}))
T.check(o.fma == V.FMA.PTH and not o.level, "300 ft above: on")
o = V.update(d3, des({alt = 2000, mcp = 2200, on_app = true}))
T.check(o.fma == V.FMA.ALT and o.kind == "hold", "200 ft above: VNAV ALT")
-- (a second patch of step 9i) then set 350 ft above, no push: on down in
-- VNAV PTH (FCOM p.1261: VNAV continues to command a descent; a first patch
-- held VNAV ALT until the push)
o = V.update(d3, des({alt = 2000, mcp = 2350, on_app = true}))
T.check(o.fma == V.FMA.PTH and not o.level and o.law == "VS", "then 350 ft above on approach: VNAV PTH, the descent on")
-- VNAV ALT at the MCP altitude on approach (captured), the missed approach
-- altitude set 2,000 ft above: on down, no push (FCOM p.1261)
local d4 = V.new()
V.update(d4, des({alt = 3020, mcp = 3000, on_app = true, cap_mcp = true}))
o = V.update(d4, des({alt = 3000, mcp = 3000, on_app = true}))
T.equal(o.fma, V.FMA.ALT, "on approach, VNAV ALT at the MCP's 3,000 ft")
o = V.update(d4, des({alt = 3000, mcp = 5000, on_app = true}))
T.check(o.fma == V.FMA.PTH and not o.level, "the missed approach's 5,000 ft set: VNAV PTH, the descent on")
-- (a second patch) a level part of the path (the FMC's V/S 50 fpm down),
-- the airplane still descending onto the MCP altitude: captured, VNAV ALT
-- at it (FMSPG p.227 (4-16); a first patch captured nothing there); an MCP
-- altitude above not climbed to
local d5 = V.new()
o = V.update(d5, des({alt = 10150, mcp = 10000, vs = -50, cap_mcp = true}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp" and o.law_alt == 10000,
    "the path level, the MCP's 10,000 ft captured from above: VNAV ALT")
local d6 = V.new()
o = V.update(d6, des({alt = 10000, mcp = 10060, vs = -50, cap_mcp = true}))
T.check(not o.level and o.fma == V.FMA.PTH, "the path level, the MCP 60 ft above: not climbed to")
-- VNAV ALT under the path: the MCP reset lower, on when the path comes down
-- to the airplane without the push (FCOM p.645, p.665); reset back, judged
-- anew; reset above the path: the push wanted
local v = V.new()
V.update(v, des({alt = 10400, path_dev = -300, cap_mcp = true}))
o = V.update(v, des({alt = 10000, path_dev = -300}))
T.equal(o.fma, V.FMA.ALT, "VNAV ALT at 10,000 ft, 300 ft under the path")
o = V.update(v, des({alt = 10000, path_dev = -300, mcp = 5000}))
T.equal(o.fma, V.FMA.ALT, "the MCP reset to 5,000 ft under the path: VNAV ALT")
o = V.update(v, des({alt = 10000, path_dev = -20, mcp = 5000}))
T.equal(o.fma, V.FMA.ALT, "the path 20 ft above: still")
o = V.update(v, des({alt = 10000, path_dev = 5, mcp = 5000}))
T.equal(o.fma, V.FMA.PTH, "the path down to it: VNAV PTH without the push")
local v2 = V.new()
V.update(v2, des({alt = 10400, path_dev = -300, cap_mcp = true}))
V.update(v2, des({alt = 10000, path_dev = -300, mcp = 5000}))
V.update(v2, des({alt = 10000, path_dev = -300, mcp = 10000}))
V.update(v2, des({alt = 10000, path_dev = 300}))
o = V.update(v2, des({alt = 10000, path_dev = 300, mcp = 5000}))
o = V.update(v2, des({alt = 10000, path_dev = 320, mcp = 5000}))
T.equal(o.fma, V.FMA.ALT, "reset back and lower again above the path: VNAV ALT, the push wanted")
o = V.update(v2, des({alt = 10000, path_dev = 320, mcp = 5000, pushes = 1}))
T.equal(o.fma, V.FMA.PTH, "pushed: VNAV PTH")

-- the early descent (VNAV SPD with THR) and speed intervention (VNAV SPD
-- with IDLE): the speed law, the FMC altitude captured: VNAV PTH
local e = V.new()
o = V.update(e, des({mode = 1, at = 4, vs = -1250, alt = 30000, fmc_alt = 24000}))
T.check(o.fma == V.FMA.SPD and o.law == "FLCH" and o.at == 4, "the early descent: VNAV SPD, THR")
o = V.update(e, des({mode = 1, at = 4, vs = -1250, alt = 24300, fmc_alt = 24000, cap_fmc = true}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 24000, "its constraint captured: VNAV PTH")
-- a descent's FMC altitude above the airplane, a floor (an AT OR ABOVE 10,000
-- ft ahead): VNAV PTH where it is (FMSPG p.227 (4-16): below the
-- constraint, the FMC levels; no climb in the descent). (A second patch of
-- step 9i) an AT OR BELOW 10,000 ft ahead with the path 8,500 ft at its
-- point: the FMC's altitude the lower, 8,500 ft (B747.68.vnav_model.lua's
-- des_target; FMSPG p.227), VNAV SPD on down at 9,000 ft (FCOM p.643: until
-- the airplane intercepts an altitude constraint); a first patch gave the
-- AFDS its 10,000 ft and it levelled in VNAV PTH
local FV = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vnav_model.lua")
local e2 = V.new()
o = V.update(e2, des({mode = 1, at = 2, alt = 9000, fmc_alt = 10000, mcp = 3000}))
T.check(o.kind == "far" and o.law_alt == 9000, "VNAV SPD under an AT OR ABOVE 10,000 ft (the FMC's floor) in the descent: level at 9,000")
local path = {e = {0, 30}, h = {3000, 12000}, k = {"idle", "idle"}}
local fb = FV.des_target({des_alt = 10000, des_kind = "B", des_e = 18.333, path = path})
T.near(fb, 8500, 1, "the FMC's altitude for an AT OR BELOW 10,000 over the path's 8,500 ft: 8,500")
local e3 = V.new()
o = V.update(e3, des({mode = 1, at = 2, alt = 9000, fmc_alt = fb, mcp = 3000}))
T.check(not o.level and o.fma == V.FMA.SPD and o.law == "FLCH",
    "VNAV SPD with that AT OR BELOW ahead at 9,000 ft: on down (" .. tostring(o.kind) .. ")")

-- the FMC's data lost while engaged: VNAV PTH at the altitude then, the
-- A/T SPD; a level holds on; valid again: the FMC's guidance
local iv = V.new()
V.update(iv, des({alt = 15000}))
o = V.update(iv, des({alt = 15000, valid = false}))
T.check(o.fma == V.FMA.PTH and o.kind == "invalid" and o.law_alt == 15000 and o.at == V.AT_SPD,
    "not valid: VNAV PTH at 15,000, the A/T SPD")
o = V.update(iv, des({alt = 14980, valid = false}))
T.equal(o.law_alt, 15000, "held at the altitude then")
o = V.update(iv, des({alt = 14980}))
T.check(o.fma == V.FMA.PTH and o.law == "VS" and not o.level, "valid again: the path")
local iv2 = V.new()
V.update(iv2, inp({alt = 19500, cap_mcp = true}))
o = V.update(iv2, inp({alt = 20000, valid = false}))
T.check(o.kind == "mcp" and o.fma == V.FMA.ALT, "VNAV ALT holds on while the data is lost")

-- the missed approach's climb (FCOM p.1264): VNAV SPD, at the missed
-- approach altitude (the MCP's and the FMC's) VNAV PTH
local m = V.new()
o = V.update(m, inp({alt = 1500, mcp = 3000, fmc_alt = 3000}))
T.equal(o.fma, V.FMA.SPD, "the missed approach: VNAV SPD")
o = V.update(m, inp({alt = 2700, mcp = 3000, fmc_alt = 3000, cap_mcp = true, cap_fmc = true}))
T.check(o.fma == V.FMA.PTH and o.law_alt == 3000, "at its altitude: VNAV PTH (FCOM p.1264's 7)")

-- (2026-11-11 review) FCTM p.187's VNAV approach: the path level at the
-- FAF's 2,000 ft constraint (the FMC altitude), the MCP set to it, the DA
-- (600 ft) set before the FAF. The FMC holds 2,000 itself there: the MCP
-- altitude the FMC's, VNAV PTH (FCOM p.1256: VNAV ALT is for an MCP altitude
-- not in the FMC); the FAF passed, on down the path whether the airplane was
-- 4 ft under or over it. Before, VNAV ALT, and from over the path it wanted
-- the push: level past the FAF
local function faf(dev, t)
    local i = inp({phase = 3, mode = 2, fmc_alt = 2000, vs = -40, at = 3, path_dev = dev, on_app = true,
        mcp = 2000, alt = 2000 + dev, cap_mcp = true, settled = true})
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
for _, dev in ipairs({-4, 4}) do
    local a = V.new()
    o = V.update(a, faf(dev))
    T.check(o.fma == V.FMA.PTH and o.kind == "fmc" and o.law_alt == 2000,
        string.format("%+d ft: the MCP's 2,000 ft captured on the path level at the FAF's: VNAV PTH (%d %s)", dev, o.fma, tostring(o.kind)))
    V.update(a, faf(dev, {mcp = 1900, cap_mcp = false, settled = false}))
    o = V.update(a, faf(dev, {mcp = 600, cap_mcp = false}))
    T.check(o.fma == V.FMA.PTH and o.law_alt == 2000, string.format("%+d ft: the DA set: VNAV PTH held at 2,000 ft", dev))
    o = V.update(a, faf(dev, {mcp = 600, cap_mcp = false, vs = -800, path_dev = 60, fmc_alt = 600}))
    T.check(o.fma == V.FMA.PTH and o.law == "VS" and o.law_vs == -800,
        string.format("%+d ft: the FAF passed: on down the path (%s %d)", dev, tostring(o.law), o.law_vs))
end
-- captured on the way down (the path still descending: VNAV ALT, LF2), the
-- path level at it then: the FMC's, VNAV PTH, and on down past the FAF
local f2 = V.new()
o = V.update(f2, faf(0, {alt = 2200, vs = -800, path_dev = 0}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp", "captured with the path still descending: VNAV ALT (LF2)")
o = V.update(f2, faf(4))
T.check(o.fma == V.FMA.PTH and o.kind == "fmc", "the path level at the FAF's 2,000 ft: VNAV PTH")
V.update(f2, faf(4, {mcp = 600, cap_mcp = false}))
o = V.update(f2, faf(4, {mcp = 600, cap_mcp = false, vs = -800, path_dev = 60, fmc_alt = 600}))
T.check(o.fma == V.FMA.PTH and o.law == "VS", "then the DA and the FAF: on down without the push")
-- the MCP left at 2,000 past the FAF: the path on down, VNAV ALT there
local f3 = V.new()
V.update(f3, faf(4))
o = V.update(f3, faf(4, {vs = -800, path_dev = 60, fmc_alt = 600, alt = 2000}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp" and o.law_alt == 2000, "the MCP left at 2,000 past the FAF: VNAV ALT there")
-- the path level at 5,000 ft, the FMC altitude the next constraint's 3,000
-- ft: the MCP's 5,000 not the FMC's, VNAV ALT
local f4 = V.new()
o = V.update(f4, faf(0, {alt = 5010, mcp = 5000, fmc_alt = 3000, path_dev = 10}))
T.check(o.fma == V.FMA.ALT and o.kind == "mcp", "the path level at an altitude not the FMC's: VNAV ALT")

T.done()
