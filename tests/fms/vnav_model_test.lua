-- Run from the repository root with LuaJIT: luajit tests/fms/vnav_model_test.lua
-- The FMC's VNAV (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/
-- B747.68.vnav_model.lua; 6-1/6-2 step 9b, notes/ATA-34-61-FMC.md §56):
-- the phases (the climb to CRZ ALT, the cruise, the descent past the T/D
-- with the MCP altitude below, a cruise climb), the sub-modes and the A/T
-- modes asked for (VNAV SPD and THR REF in the climb, VNAV PTH and SPD in
-- the cruise, VNAV PTH and IDLE or SPD in the descent: ATA34_2 p.615-617,
-- FCOM p.645, p.1258), the target speeds (the schedules, the flap placard
-- less 5 kt, the minimum maneuvering speed plus 5 kt, speed intervention),
-- the FMC altitude, the descent path fixed to the ground and its vertical
-- speed (on it, above it, below it), valid.
local T = dofile("tests/lib/check.lua")("vnav_model")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local PM = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.pred_model.lua")
local V = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.vnav_model.lua")

local clb = {cas = 340, mach = 0.84, trans_cas = 250, trans_alt = 10000}
local des = {cas = 290, mach = 0.84, trans_cas = 240, trans_alt = 10000}
-- a descent path from the E/D (1,500 ft at 0 NM) back: a line to 3,000 ft
-- at 10 NM too shallow for idle, idle up to FL350 at 110 NM
local path = {e = {0, 10, 110}, h = {1500, 3000, 35000}, k = {"idle", "spd", "idle"}}
local function inp(t)
    local i = {P = P, sched = PM.schedule, crz = PM.crz_mach, alt = 5000, vs = 0, gs = 300, ground = false,
        active = true, kg = 300000, crz_alt = 35000, mcp_alt = 35000, clb = clb, des = des, crzspd = {mach = 0.85},
        path = path, d_ed = 300}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end

-- the climb: VNAV SPD, THR REF, the climb's speeds, the FMC altitude
local s = V.new()
local o = V.update(s, inp{alt = 5000})
T.equal(o.phase, "CLB", "5,000 ft: the climb")
T.check(o.mode == "SPD" and o.at == V.AT_THR_REF, "VNAV SPD with THR REF (ATA34_2 p.615: speed/thrust)")
T.near(o.cas, 250, 1e-6, "below 10,000 ft: SPD TRANS's 250 kt")
T.equal(o.alt, 35000, "the FMC altitude: CRZ ALT")
o = V.update(s, inp{alt = 5000, clb_alt = 15000})
T.equal(o.alt, 15000, "an AT OR BELOW 15,000 ahead: the FMC altitude (VNAV PTH there)")
o = V.update(s, inp{alt = 20000})
T.near(o.cas, 340, 1e-6, "FL200: ECON's 340 kt")
o = V.update(s, inp{alt = 33000})
T.check(o.mach_mode and math.abs(o.mach - 0.84) < 1e-9, "FL330: M.84 above the crossover")
-- the margins and speed intervention
o = V.update(s, inp{alt = 5000, flaps_placard = 230})
T.near(o.cas, 225, 1e-6, "flaps out, placard 230 kt: 225 kt (5 kt below: FCOM p.1255)")
o = V.update(s, inp{alt = 5000, vmin = 260})
T.near(o.cas, 265, 1e-6, "the minimum maneuvering 260 kt: 265 kt (FCOM p.663)")
o = V.update(s, inp{alt = 5000, spd_int = {cas = 220}})
T.near(o.cas, 220, 1e-6, "speed intervention: the MCP's 220 kt")
o = V.update(s, inp{alt = 30000, spd_int = {mach = 0.8}})
T.check(o.mach_mode and math.abs(o.mach - 0.8) < 1e-9, "speed intervention in Mach: M.80")

-- the cruise: at CRZ ALT, VNAV PTH with SPD, the cruise Mach
o = V.update(s, inp{alt = 34960})
T.equal(o.phase, "CRZ", "within 50 ft of CRZ ALT: the cruise")
T.check(o.mode == "PTH" and o.at == V.AT_SPD and o.alt == 35000, "VNAV PTH at CRZ ALT with SPD (path/speed)")
T.check(o.mach_mode and math.abs(o.mach - 0.85) < 1e-9, "the cruise's M.85")
-- a higher CRZ ALT: the climb again
o = V.update(s, inp{alt = 35000, crz_alt = 39000, mcp_alt = 39000})
T.equal(o.phase, "CLB", "CRZ ALT FL390: climbing again (FCOM p.1257)")
o = V.update(s, inp{alt = 39000, crz_alt = 39000, mcp_alt = 39000})
T.equal(o.phase, "CRZ", "at FL390: the cruise")

-- past the T/D with the MCP altitude still at the cruise's: the cruise
-- (VNAV keeps the altitude: FCOM p.665's RESET MCP ALT)
local s2 = V.new()
V.update(s2, inp{alt = 35000})
o = V.update(s2, inp{alt = 35000, d_ed = 109})
T.equal(o.phase, "CRZ", "past the T/D, the MCP at FL350: still the cruise")
-- the MCP altitude below: the descent on the path
o = V.update(s2, inp{alt = 35000, mcp_alt = 10000, d_ed = 110, gs = 480})
T.equal(o.phase, "DES", "past the T/D with the MCP below: the descent")
T.check(o.mode == "PTH" and o.at == V.AT_IDLE, "VNAV PTH with IDLE (path/idle: ATA34_2 p.616)")
local g = (35000 - 3000) / 100
T.near(o.path_alt, 35000, 1, "on the path at its top")
T.near(o.vs, -g * 480 / 60, 1, string.format("the path's vertical speed: %.0f fpm (%.0f ft/NM at 480 kt)", o.vs, g))
local ph = 3000 + g * 50
o = V.update(s2, inp{alt = ph + 200, mcp_alt = 10000, d_ed = 60, gs = 400})
T.near(o.path_dev, 200, 1e-6, string.format("200 ft above the path (%.0f ft)", ph))
T.near(o.vs, -g * 400 / 60 - V.K_PATH * 200, 1, "above it: steeper by K_PATH a foot")
o = V.update(s2, inp{alt = ph - 500, mcp_alt = 10000, d_ed = 60, gs = 400})
T.near(o.vs, -g * 400 / 60 + V.K_PATH * 500, 1, "500 ft below the path: shallower, to meet it")
T.equal(o.at, V.AT_SPD, "and the A/T on speed")
o = V.update(s2, inp{alt = ph - 1000, mcp_alt = 10000, d_ed = 60, gs = 400})
T.equal(o.vs, 0, "1,000 ft below: level until the path comes down (never up)")
o = V.update(s2, inp{alt = ph + 2000, mcp_alt = 10000, d_ed = 60, gs = 400})
T.near(o.vs, -g * 400 / 60 - V.VS_STEEPER, 1, "2,000 ft above: at most VS_STEEPER steeper")
-- the shallow line before the E/D: SPD (FCOM p.1258)
o = V.update(s2, inp{alt = 2250, mcp_alt = 1000, d_ed = 5, gs = 180})
T.equal(o.at, V.AT_SPD, "the line too shallow for idle: the A/T's SPD")
T.near(o.path_alt, 2250, 1, "on it")
T.near(o.cas, 240, 1e-6, "below 10,000 ft: the descent's 240 kt (the transition's less 10: FCOM p.1258)")

-- valid
T.check(V.update(V.new(), inp{}).valid, "an active route, CRZ ALT, the weight: valid")
T.check(not V.update(V.new(), inp{crz_alt = false}).valid, "no CRZ ALT: not (PERF/VNAV UNAVAILABLE)")
T.check(not V.update(V.new(), inp{kg = false}).valid, "no gross weight: not")
local s3 = V.new()
V.update(s3, inp{alt = 35000})
V.update(s3, inp{alt = 35000, mcp_alt = 10000, d_ed = 100})
o = V.update(s3, inp{alt = 30000, mcp_alt = 10000, path = false, d_ed = false})
T.check(o.phase == "DES" and not o.valid, "the descent without a path: not valid")

-- a short flight: the climb meets the path (no T/C), the MCP below
local s4 = V.new()
o = V.update(s4, inp{alt = 20000, d_ed = 60, mcp_alt = 35000})
T.equal(o.phase, "CLB", "climbing into the path, the MCP above: the climb")
o = V.update(s4, inp{alt = 19200, d_ed = 60, mcp_alt = 5000})
T.equal(o.phase, "DES", "at the path with the MCP below: the descent")

-- the path's lookup
local h1, g1, k1 = V.path_at(path, 5)
T.check(math.abs(h1 - 2250) < 1e-6 and math.abs(g1 - 150) < 1e-6 and k1 == "spd", "5 NM: 2,250 ft, 150 ft/NM, the shallow line")
T.equal((V.path_at(path, 200)), 35000, "beyond the top: its altitude")
T.equal((V.path_at(path, -1)), 1500, "past the E/D: the E/D's")

T.done()
