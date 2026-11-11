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
-- speed (on it, above it, below it), valid; step 9c: the takeoff's target
-- speed (V2 + 10 to V2 + 25 until the acceleration height or the flaps'
-- retraction: FCOM p.1255).
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
o = V.update(s2, inp{alt = 35000})
T.check(not o.td_hold, "(step 9i) before the T/D: no td_hold")
o = V.update(s2, inp{alt = 35000, d_ed = 109})
T.equal(o.phase, "CRZ", "past the T/D, the MCP at FL350: still the cruise")
T.check(o.td_hold, "(step 9i) and td_hold: the descent would begin, held by the MCP (the AFDS's VNAV ALT: FMSPG p.34 (2-22))")
-- (step 9d1) above CRZ ALT (an air start's climb) past the T/D with the
-- MCP at CRZ ALT and below the airplane: the cruise still (the MCP below
-- CRZ ALT starts the descent; before, below the airplane: s143 went into
-- the descent 250 ft above the MCP)
local s2b = V.new()
V.update(s2b, inp{alt = 30000, crz_alt = 30000})
o = V.update(s2b, inp{alt = 31250, crz_alt = 30000, mcp_alt = 31000, d_ed = 90})
T.equal(o.phase, "CRZ", "past the T/D 1,250 ft above CRZ ALT FL300, the MCP at FL310: the cruise")
o = V.update(s2b, inp{alt = 31250, crz_alt = 30000, mcp_alt = 29000, d_ed = 90})
T.equal(o.phase, "DES", "the MCP at FL290 below CRZ ALT: the descent")
-- the MCP altitude below: the descent on the path
o = V.update(s2, inp{alt = 35000, mcp_alt = 10000, d_ed = 110, gs = 480})
T.equal(o.phase, "DES", "past the T/D with the MCP below: the descent")
T.check(not o.td_hold, "no td_hold in the descent")
T.check(o.mode == "PTH" and o.at == V.AT_IDLE, "VNAV PTH with IDLE (path/idle: ATA34_2 p.616)")
local g = (35000 - 3000) / 100
-- (2026-11-09) at its top the T/D's corner rounded over the time the line's
-- 2,560 fpm takes at TD_ACC_FPMS (0.035 g: 37.9 s, 5.05 NM at 480 kt;
-- PATH_LEAD_S 6 s, 0.8 NM): the mean 320 ft/NM x 5.05 / 8 = 202 ft under
-- the corner, the slope 0.8 NM ahead (5.05 / 2 + 0.8) NM of the line's over
-- 5.05 NM and K_PATH for the 202 ft above it. Before, the corner's 35,000
-- ft and the line's 2,560 fpm at once
local ltd = 480 * math.min(math.max(g * 480 / 60 / V.TD_ACC_FPMS, V.PATH_BLEND_S), V.TD_BLEND_MAX_S) / 3600
T.near(ltd, 5.05, 0.01, string.format("the T/D's rounding over %.2f NM", ltd))
T.near(o.path_alt, 35000 - g * ltd / 8, 1, string.format("on the path at its top, rounded: %.0f ft under the corner", g * ltd / 8))
T.near(o.vs, -g * (ltd / 2 + 0.8) / ltd * 480 / 60 - V.K_PATH * g * ltd / 8, 1,
    string.format("the vertical speed from the rounded path ahead: %.0f fpm", o.vs))
-- (2026-11-09) the descent begun where that rounding begins: ltd / 2 and the
-- lead (3.33 NM) before the corner, there being no level deceleration; with
-- one longer than that, at its start as before
local s2t = V.new()
V.update(s2t, inp{alt = 35000, mcp_alt = 10000, d_ed = 120, gs = 480})
o = V.update(s2t, inp{alt = 35000, mcp_alt = 10000, d_ed = 113.5, gs = 480})
T.equal(o.phase, "CRZ", "3.5 NM before the corner: the cruise still")
o = V.update(s2t, inp{alt = 35000, mcp_alt = 10000, d_ed = 113.2, gs = 480})
T.equal(o.phase, "DES", "3.2 NM before it: the descent (the rounding begins 3.33 NM before)")
T.near(o.path_dev, 0, 1e-6, "at CRZ ALT on the rounded path")
T.check(o.vs < 0 and o.vs > -300, string.format("the vertical speed's gentle start: %.0f fpm", o.vs))
local pathTD = {e = path.e, h = path.h, k = path.k, td_decel = 5}
local s2d = V.new()
V.update(s2d, inp{alt = 35000, mcp_alt = 10000, d_ed = 120, gs = 480, path = pathTD})
o = V.update(s2d, inp{alt = 35000, mcp_alt = 10000, d_ed = 115.2, gs = 480, path = pathTD})
T.equal(o.phase, "CRZ", "a level deceleration of 5 NM: 115.2 NM, the cruise still")
o = V.update(s2d, inp{alt = 35000, mcp_alt = 10000, d_ed = 114.9, gs = 480, path = pathTD})
T.equal(o.phase, "DES", "at its start (115 NM): the descent, level first (FCOM p.1264)")
T.near(o.vs, 0, 1e-6, "level there (the rounding's start still ahead)")
-- 5 NM down the line, away from its breaks, the path's own
o = V.update(V.new(), inp{alt = 3000 + g * 95 + 100, mcp_alt = 10000, d_ed = 105, gs = 480})
T.equal(o.phase, "DES", "5 NM down the line: the descent")
T.near(o.path_alt, 3000 + g * 95, 1, "on the line the path's own altitude")
T.near(o.vs, -g * 480 / 60 - V.K_PATH * 100, 1, string.format("the path's vertical speed: %.0f fpm (%.0f ft/NM at 480 kt) and K_PATH for 100 ft above", o.vs, g))
local ph = 3000 + g * 50
o = V.update(s2, inp{alt = ph + 200, mcp_alt = 10000, d_ed = 60, gs = 400})
T.near(o.path_dev, 200, 1e-6, string.format("200 ft above the path (%.0f ft)", ph))
T.near(o.vs, -g * 400 / 60 - V.K_PATH * 200, 1, "above it: steeper by K_PATH a foot")
o = V.update(s2, inp{alt = ph - 500, mcp_alt = 10000, d_ed = 60, gs = 400})
T.near(o.vs, -g * 400 / 60 + V.K_PATH * 500, 1, "500 ft below the path: shallower, to meet it")
T.equal(o.at, V.AT_SPD, "and the A/T on speed")
-- (2026-11-09) the A/T's SPD from 200 ft under the path until back within
-- 50 ft (estimates; before, none: IDLE and SPD three times in 1 s at 200
-- ft under it, s273's first run)
for _, c in ipairs({{150, V.AT_SPD, "150 ft below, from 500: SPD still"}, {190, V.AT_SPD, "190: SPD (before, IDLE)"},
    {40, V.AT_IDLE, "40 ft below: back within 50, IDLE"}, {150, V.AT_IDLE, "150 below again: IDLE (not 200 under since)"},
    {210, V.AT_SPD, "210 below: SPD"}, {190, V.AT_SPD, "190: SPD still"}, {40, V.AT_IDLE, "40: IDLE"}}) do
    o = V.update(s2, inp{alt = ph - c[1], mcp_alt = 10000, d_ed = 60, gs = 400})
    T.equal(o.at, c[2], c[3])
end
o = V.update(s2, inp{alt = ph - 2500, mcp_alt = 10000, d_ed = 60, gs = 400})
T.equal(o.vs, 0, "2,500 ft below: level until the path comes down (never up)")
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

-- the takeoff (step 9c; FCOM p.1255): from the ground until VNAV engages
-- the target follows the airspeed between V2 + 10 and V2 + 25, then stays
-- until the acceleration height or the flaps' retraction; then the
-- climb's (the flap placard less 5 kt, SPD TRANS's 250 kt)
local s5 = V.new()
local to = {v2 = 160, accel_alt = 1000, flaps = 0.5}
o = V.update(s5, inp{alt = 0, ground = true, ias = 0, takeoff = to})
T.near(o.cas, 170, 1e-6, "on the ground, stopped: V2 + 10")
o = V.update(s5, inp{alt = 0, ground = true, ias = 178, takeoff = to})
T.near(o.cas, 178, 1e-6, "rotating at 178 kt: the airspeed")
o = V.update(s5, inp{alt = 300, ias = 195, takeoff = to})
T.near(o.cas, 185, 1e-6, "in the air at 195 kt before VNAV: V2 + 25 at most")
o = V.update(s5, inp{alt = 390, ias = 181, takeoff = to})
T.near(o.cas, 181, 1e-6, "at 181 kt: 181 kt")
o = V.update(s5, inp{alt = 420, ias = 183, takeoff = to, engaged = true})
T.near(o.cas, 181, 1e-6, "VNAV engaged: the target then kept")
T.equal(o.mode, "SPD", "VNAV SPD")
o = V.update(s5, inp{alt = 800, ias = 175, takeoff = to, engaged = true, flaps_placard = 250})
T.near(o.cas, 181, 1e-6, "below the acceleration height: still 181 kt")
o = V.update(s5, inp{alt = 1000, ias = 180, takeoff = to, engaged = true, flaps_placard = 230})
T.near(o.cas, 225, 1e-6, "at the acceleration height: the placard less 5 kt")
o = V.update(s5, inp{alt = 900, ias = 190, takeoff = to, engaged = true, flaps_placard = 230})
T.near(o.cas, 225, 1e-6, "below it again: still the climb's (the takeoff is over)")
-- the flaps' retraction before the acceleration height ends it too
local s6 = V.new()
V.update(s6, inp{alt = 0, ground = true, ias = 150, takeoff = to})
V.update(s6, inp{alt = 500, ias = 175, takeoff = to, engaged = true})
o = V.update(s6, inp{alt = 600, ias = 176, takeoff = {v2 = 160, accel_alt = 1000, flaps = 0.33}, engaged = true,
    flaps_placard = 260})
T.near(o.cas, 250, 1e-6, "the flaps retracting at 600 ft: the climb's 250 kt (the placard less 5, 255, above it)")
-- no V2 (999 on TAKEOFF REF: the glue's nil): the climb's from the start
local s7 = V.new()
V.update(s7, inp{alt = 0, ground = true, ias = 0, takeoff = {accel_alt = 1000, flaps = 0.5}})
o = V.update(s7, inp{alt = 500, ias = 170, takeoff = {accel_alt = 1000, flaps = 0.5}, engaged = true})
T.near(o.cas, 250, 1e-6, "no V2: the climb's 250 kt")
-- an air start (never on the ground): the climb's
o = V.update(V.new(), inp{alt = 500, ias = 170, takeoff = to, engaged = true})
T.near(o.cas, 250, 1e-6, "an air start: the climb's 250 kt")

-- (the A/T's step 9f2) the descent more than 15 kt slow: the A/T's SPD
-- until within 5 kt; below the speed transition 10 kt (FCOM p.1259-1260)
local s8 = V.new()
V.update(s8, inp{alt = 30000, crz_alt = 30000})
o = V.update(s8, inp{alt = 30000, crz_alt = 30000, mcp_alt = 10000, d_ed = 90, gs = 450, ias = 280})
T.check(o.phase == "DES" and o.at == V.AT_IDLE, string.format("the descent at %.0f kt for %.0f: IDLE", 280, o.cas))
local tgt = o.cas
o = V.update(s8, inp{alt = 30000, crz_alt = 30000, mcp_alt = 10000, d_ed = 90, gs = 450, ias = tgt - 16})
T.equal(o.at, V.AT_SPD, "16 kt slow: SPD")
o = V.update(s8, inp{alt = 30000, crz_alt = 30000, mcp_alt = 10000, d_ed = 90, gs = 450, ias = tgt - 8})
T.equal(o.at, V.AT_SPD, "8 kt slow: SPD still")
o = V.update(s8, inp{alt = 30000, crz_alt = 30000, mcp_alt = 10000, d_ed = 90, gs = 450, ias = tgt - 4})
T.equal(o.at, V.AT_IDLE, "4 kt slow: IDLE again")
o = V.update(s8, inp{alt = 8000, crz_alt = 30000, mcp_alt = 3000, d_ed = 30, gs = 300, ias = 240 - 11})
T.equal(o.at, V.AT_SPD, "below 10,000 ft, 11 kt slow of 240: SPD")

-- (step 9d1) where the path first reaches an altitude (RESET MCP ALT's
-- T/D at CRZ ALT): 35,000 ft at its top, 110 NM; 3,000 ft at 10 NM;
-- 19,000 ft half way up the idle line; above its top none
T.near(V.path_e_at(path, 35000), 110, 1e-6, "35,000 ft: 110 NM (the top)")
T.near(V.path_e_at(path, 3000), 10, 1e-6, "3,000 ft: 10 NM")
T.near(V.path_e_at(path, 19000), 60, 1e-6, "19,000 ft: 60 NM")
T.equal(V.path_e_at(path, 36000), nil, "above the top: none")

-- (step 9d2a) the descent from the T/D (FCOM p.1389), where the path
-- reaches CRZ ALT (this path tops there; the predictions' goes on up:
-- below): before it, the MCP altitude set below, the cruise still
local s9 = V.new()
V.update(s9, inp{alt = 35000})
o = V.update(s9, inp{alt = 35000, mcp_alt = 10000, d_ed = 150})
T.equal(o.phase, "CRZ", "40 NM before the T/D, the MCP below: the cruise")
T.check(o.mode == "PTH" and o.at == V.AT_SPD, "VNAV PTH with SPD until the T/D")
o = V.update(s9, inp{alt = 35000, mcp_alt = 10000, d_ed = 110})
T.equal(o.phase, "DES", "at the T/D: the descent")

-- DES NOW (step 9d2a; FCOM p.1260, p.1393; FMSPG p.3.5-5): the descent
-- phase before the T/D, VNAV SPD at the descent's speeds and about 1,250
-- fpm by the A/T's THR (speed/thrust: ATA34_2 p.615), until the path comes
-- down to the airplane: VNAV PTH with IDLE
local s10 = V.new()
V.update(s10, inp{alt = 35000})
T.check(V.des_now(s10), "DES NOW in the cruise")
o = V.update(s10, inp{alt = 35000, mcp_alt = 10000, d_ed = 160, gs = 480, ias = 270})
T.equal(o.phase, "DES", "the descent phase at once (FCOM p.1393)")
T.check(o.mode == "SPD" and o.at == V.AT_THR, "VNAV SPD with THR")
T.near(o.vs, -V.EARLY_VS, 1e-6, "1,250 fpm down for the A/T")
T.check(o.mach_mode and math.abs(o.mach - 0.84) < 1e-9, "the descent's M.84 (the active descent schedule)")
T.equal(o.alt, nil, "the FMC altitude: the descent's next constraint (none here)")
o = V.update(s10, inp{alt = 30000, mcp_alt = 10000, d_ed = 120, gs = 480, ias = 250})
T.check(o.mode == "SPD" and o.at == V.AT_THR, "5,000 ft below the path, 40 kt slow: VNAV SPD, THR still (no slow rule)")
T.near(o.path_dev, -5000, 1e-6, "the path's deviation for the ND")
o = V.update(s10, inp{alt = 29000, mcp_alt = 10000, d_ed = 100, gs = 470})
T.equal(o.mode, "SPD", "at 100 NM the path 2,800 ft above: VNAV SPD")
o = V.update(s10, inp{alt = 28700, mcp_alt = 10000, d_ed = 90, gs = 450})
T.check(o.mode == "PTH" and o.at == V.AT_IDLE, "the path come down to the airplane: VNAV PTH with IDLE (FCOM p.665)")
T.check(not V.des_now(s10), "DES NOW in the descent: nothing")
-- DES NOW in the climb (no T/C yet): the descent too
local s11 = V.new()
V.update(s11, inp{alt = 20000})
T.check(V.des_now(s11), "DES NOW in the climb")
o = V.update(s11, inp{alt = 20000, mcp_alt = 10000, d_ed = 200})
T.check(o.phase == "DES" and o.mode == "SPD", "the early descent")
-- on the ground or without an active route: none (the climb's phase)
o = V.update(s11, inp{alt = 0, ground = true})
T.equal(o.phase, "CLB", "on the ground: the climb, the early descent over")
o = V.update(s11, inp{alt = 20000, mcp_alt = 10000, d_ed = 200})
T.equal(o.mode, "SPD", "in the air again: the climb's VNAV SPD")
T.equal(o.at, V.AT_THR_REF, "with THR REF")

-- a lower CRZ ALT in the cruise (the selector's push more than 50 NM
-- before the T/D: the glue's): the cruise descent (FCOM p.1257, p.1261):
-- the cruise phase at the cruise's speed (economy cruise), about 1,250 fpm
-- down with the A/T keeping the speed (step 9h4c: FCOM p.1268's condition
-- 3, p.1269; before, VNAV SPD with THR), level at the new CRZ ALT; the CRZ
-- page's CRZ DES (p.1347)
local s12 = V.new()
V.update(s12, inp{alt = 35000})
o = V.update(s12, inp{alt = 35000, crz_alt = 31000, mcp_alt = 31000, d_ed = 300})
T.check(o.phase == "CRZ" and o.crz_chg == "DES", "CRZ ALT FL310: the cruise descent (CRZ DES)")
T.check(o.mode == "PTH" and o.at == V.AT_SPD and o.alt == 31000, "VNAV PTH with SPD to FL310 (step 9h4c)")
T.near(o.vs, -V.EARLY_VS, 1e-6, "1,250 fpm down")
T.check(o.mach_mode and math.abs(o.mach - 0.85) < 1e-9, "the cruise's M.85")
o = V.update(s12, inp{alt = 31040, crz_alt = 31000, mcp_alt = 31000, d_ed = 280})
T.check(o.phase == "CRZ" and o.crz_chg == nil, "within 50 ft of FL310: the cruise")
T.check(o.mode == "PTH" and o.at == V.AT_SPD, "VNAV PTH with SPD")
-- a higher one: the cruise climb (FCOM p.1257: CRZ CLB), VNAV SPD with THR
-- REF at the cruise's speed (the climb's phase for the thrust limit:
-- estimate until step 9g)
o = V.update(s12, inp{alt = 31000, crz_alt = 35000, mcp_alt = 35000, d_ed = 260})
T.check(o.phase == "CLB" and o.crz_chg == "CLB", "CRZ ALT FL350: the cruise climb (CRZ CLB)")
T.check(o.mode == "SPD" and o.at == V.AT_THR_REF and o.alt == 35000, "VNAV SPD with THR REF to FL350")
T.check(o.mach_mode and math.abs(o.mach - 0.85) < 1e-9, "the cruise's M.85 (not the climb's)")
o = V.update(s12, inp{alt = 34960, crz_alt = 35000, mcp_alt = 35000, d_ed = 240})
T.check(o.phase == "CRZ" and o.crz_chg == nil, "at FL350: the cruise")
-- the climb from the takeoff: no CRZ CLB
local s13 = V.new()
o = V.update(s13, inp{alt = 20000})
T.equal(o.crz_chg, nil, "the climb after takeoff: not a cruise climb")

-- DES NOW past the T/D above the path (the path descending here): the
-- path at once, VNAV PTH
local s14 = V.new()
V.update(s14, inp{alt = 35000})
V.des_now(s14)
o = V.update(s14, inp{alt = 35000, mcp_alt = 10000, d_ed = 100, gs = 480})
T.check(o.phase == "DES" and o.mode == "PTH", "DES NOW past the T/D, 3,200 ft above the path: VNAV PTH at once")
-- the airplane above CRZ ALT alone (an air start's climb over it: s144),
-- CRZ ALT not set lower: the cruise in VNAV PTH to it, no CRZ DES
local s15 = V.new()
o = V.update(s15, inp{alt = 31300, crz_alt = 30000, mcp_alt = 30000, d_ed = 300})
T.check(o.phase == "CRZ" and o.crz_chg == nil and o.mode == "PTH",
    "1,300 ft above CRZ ALT FL300 from the start: the cruise, VNAV PTH (no CRZ DES)")
o = V.update(s15, inp{alt = 31300, crz_alt = 28000, mcp_alt = 28000, d_ed = 300})
T.equal(o.crz_chg, "DES", "CRZ ALT then set to FL280: the cruise descent")
-- the predictions' path goes on above CRZ ALT up to the ceiling: the
-- planned path level at CRZ ALT before the T/D (where the path reaches
-- it). Before it the cruise with the MCP below, at it the descent; DES
-- NOW's early descent meets the path below CRZ ALT after the T/D (s144
-- kept 13,000 ft under the path above CRZ ALT and never met it)
local path2 = {e = {0, 10, 110, 200}, h = {1500, 3000, 35000, 45000}, k = {"idle", "spd", "idle", "idle"}}
local s16 = V.new()
V.update(s16, inp{alt = 35000, path = path2})
o = V.update(s16, inp{alt = 35000, mcp_alt = 10000, path = path2, d_ed = 150})
T.equal(o.phase, "CRZ", "the path 4,400 ft over CRZ ALT 40 NM before the T/D, the MCP below: the cruise")
o = V.update(s16, inp{alt = 35000, mcp_alt = 10000, path = path2, d_ed = 110})
T.equal(o.phase, "DES", "at the T/D: the descent")
local s17 = V.new()
V.update(s17, inp{alt = 35000, path = path2})
V.des_now(s17)
o = V.update(s17, inp{alt = 33000, mcp_alt = 10000, path = path2, d_ed = 130})
T.near(o.path_dev, -2000, 1e-6, "the early descent 20 NM before the T/D: 2,000 ft under CRZ ALT (the planned path)")
o = V.update(s17, inp{alt = 32000, mcp_alt = 10000, path = path2, d_ed = 105})
T.equal(o.mode, "SPD", "past the T/D, the path 1,400 ft above: VNAV SPD")
o = V.update(s17, inp{alt = 31900, mcp_alt = 10000, path = path2, d_ed = 100})
T.equal(o.mode, "PTH", "the path met (31,800 ft): VNAV PTH")

-- (step 9d3) speed intervention in the descent (FCOM p.643): VNAV SPD at
-- the MCP speed, the A/T at IDLE, down to the next constraint (the AFDS
-- levels there in VNAV PTH); the path's deviation still out (the ND); the
-- window shut, VNAV PTH on the path again. The early descent's THR stays
local s18 = V.new()
o = V.update(s18, inp{alt = 35000, mcp_alt = 10000, d_ed = 110, gs = 480})
T.check(o.phase == "DES" and o.mode == "PTH", "the descent on the path: VNAV PTH")
o = V.update(s18, inp{alt = 34000, mcp_alt = 10000, d_ed = 105, gs = 480, des_alt = 15000, spd_int = {cas = 270}})
T.check(o.mode == "SPD" and o.at == V.AT_IDLE, "speed intervention: VNAV SPD with IDLE (FCOM p.643)")
T.near(o.cas, 270, 1e-6, "at the MCP's 270 kt")
T.equal(o.alt, 15000, "down to the next constraint (the AFDS levels there in VNAV PTH)")
T.check(o.vs == nil and o.path_dev ~= nil, "no path V/S; the deviation still out")
o = V.update(s18, inp{alt = 34000, mcp_alt = 10000, d_ed = 105, gs = 480, des_alt = 15000, spd_int = {mach = 0.82}})
T.check(o.mode == "SPD" and o.mach_mode and math.abs(o.mach - 0.82) < 1e-9, "the MCP in Mach: M.82")
o = V.update(s18, inp{alt = 25000, mcp_alt = 10000, d_ed = 60, gs = 400, des_alt = 15000, spd_int = {cas = 270}, ias = 230})
T.equal(o.at, V.AT_IDLE, "40 kt slow of the MCP speed: IDLE still (the elevator on the speed)")
o = V.update(s18, inp{alt = 34000, mcp_alt = 10000, d_ed = 105, gs = 480, des_alt = 15000})
T.check(o.mode == "PTH" and o.at == V.AT_IDLE and o.vs ~= nil, "the window shut: VNAV PTH on the path again")
local s19 = V.new()
V.update(s19, inp{alt = 35000})
V.des_now(s19)
o = V.update(s19, inp{alt = 35000, mcp_alt = 10000, d_ed = 150, spd_int = {cas = 280}})
T.check(o.mode == "SPD" and o.at == V.AT_THR and o.vs == -V.EARLY_VS, "the early descent in speed intervention: THR to the rate still")
T.near(o.cas, 280, 1e-6, "at the MCP's 280 kt")

-- (step 9e1) the descent's speed on the path (FCOM p.1259-1260). Above the
-- speed transition: DRAG REQUIRED over VMO/MMO less 16 kt (349 at FL240),
-- the path held up to 354; past it the path given up (the less steep), 150
-- ft above the speed reversion, VNAV SPD at 349 with IDLE and DRAG REQUIRED
-- until the path is met (FMSPG p.3.5-17)
local s20 = V.new()
local gr = (35000 - 3000) / 100
local rate480 = -gr * 480 / 60
local p75 = 3000 + gr * (75 - 10)
V.update(s20, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 480})
o = V.update(s20, inp{alt = p75, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 345})
T.check(o.phase == "DES" and o.mode == "PTH" and o.msg == nil, "345 kt on the path: VNAV PTH, no message")
o = V.update(s20, inp{alt = p75, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 351})
T.equal(o.msg, "DRAG", "351 kt, over VMO/MMO less 16 (349): DRAG REQUIRED (FCOM p.1259)")
T.near(o.vs, rate480, 1, "the path held at 351 (up to 354)")
o = V.update(s20, inp{alt = p75 + 50, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 358})
T.check(o.mode == "PTH" and math.abs(o.vs - (rate480 + V.SPD_VS * 4)) < 1,
    string.format("358 kt, 4 over the most, 50 ft above: VNAV PTH less steep by SPD_VS a kt (%.0f)", o.vs))
o = V.update(s20, inp{alt = p75 + 200, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 358})
T.check(o.mode == "SPD" and o.at == V.AT_IDLE and math.abs(o.cas - 349) < 0.5 and o.msg == "DRAG",
    string.format("200 ft above at 358: the speed reversion, VNAV SPD at %.1f with IDLE, DRAG REQUIRED", o.cas))
o = V.update(s20, inp{alt = p75 + 100, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 350})
T.equal(o.mode, "SPD", "100 ft above: VNAV SPD still, until the path")
o = V.update(s20, inp{alt = p75 - 10, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 340})
T.check(o.mode == "PTH" and math.abs(o.cas - 290) < 1e-6 and o.msg == nil, "the path met at 340 kt: VNAV PTH at the schedule's 290, no message")
-- below the transition (the target 240): DRAG REQUIRED over 250, the most
-- the transition speed plus 5 (255); the reversion at the SPD TRANS's 240
local s21 = V.new()
local p30 = 3000 + gr * (30 - 10)
V.update(s21, inp{alt = 35000, mcp_alt = 1000, d_ed = 110, gs = 480})
o = V.update(s21, inp{alt = p30, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 245})
T.check(o.mode == "PTH" and o.msg == nil and math.abs(o.cas - 240) < 1e-6, "9,400 ft at 245 for 240: no message")
o = V.update(s21, inp{alt = p30, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 251})
T.equal(o.msg, "DRAG", "251, over the target plus 10: DRAG REQUIRED (FCOM p.1260)")
o = V.update(s21, inp{alt = p30 + 200, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 258})
T.check(o.mode == "SPD" and math.abs(o.cas - 240) < 1e-6, "258, over 255, 200 ft above: VNAV SPD at 240 (the transition's less 10)")
-- (2026-11-05 review 4) SPD TRANS deleted (FCOM p.1392: ECON or the
-- selected speed then): no transition, the schedule's 290 below 10,000 ft
-- with above's band and reversion (before: the reversion at 240 still)
local desNoTrans = {cas = 290, mach = 0.84}
local s21b = V.new()
V.update(s21b, inp{alt = 35000, mcp_alt = 1000, d_ed = 110, gs = 480, des = desNoTrans})
o = V.update(s21b, inp{alt = p30, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 295, des = desNoTrans})
T.check(o.mode == "PTH" and o.msg == nil and math.abs(o.cas - 290) < 1e-6, "SPD TRANS deleted, 9,400 ft at 295 for 290: no message")
o = V.update(s21b, inp{alt = p30 + 200, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 362, des = desNoTrans})
T.check(o.mode == "SPD" and o.cas > 300,
    string.format("SPD TRANS deleted, 362 kt 200 ft above: the reversion at VMO less 16 (%.0f; before 240)", o.cas or 0))
-- slow under the minimum maneuvering speed (the A/T off: the A/T's SPD
-- did not catch it): the steeper by SPD_VS a kt, 150 ft below the
-- reversion at 5 kt over the higher of the best holding speed and the
-- minimum maneuvering, THRUST REQUIRED; the path met from below: PTH
local s22 = V.new()
V.update(s22, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 480})
o = V.update(s22, inp{alt = p75 - 50, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 215, vmin = 220, hold_cas = 230})
T.check(o.mode == "PTH" and math.abs(o.vs - (rate480 - V.SPD_VS * 5)) < 1 and o.at == V.AT_SPD,
    string.format("215 kt, 5 under the minimum maneuvering, 50 ft below: the steeper (%.0f), the A/T on speed", o.vs))
o = V.update(s22, inp{alt = p75 - 200, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 215, vmin = 220, hold_cas = 230})
T.check(o.mode == "SPD" and math.abs(o.cas - 235) < 1e-6 and o.msg == "THRUST",
    "200 ft below: the speed reversion at 235 (the best holding 230 plus 5), THRUST REQUIRED")
o = V.update(s22, inp{alt = p75 + 5, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 236, vmin = 220, hold_cas = 230})
T.equal(o.mode, "PTH", "the path met from below: VNAV PTH")
-- the reversion gone with the descent (the early descent, speed
-- intervention, another phase)
V.update(s20, inp{alt = p75 + 200, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 358})
T.equal(s20.rev, "fast", "reverted again")
o = V.update(s20, inp{alt = p75 + 200, mcp_alt = 3000, d_ed = 75, gs = 480, ias = 358, spd_int = {cas = 300}})
T.check(s20.rev == nil and o.msg == nil, "speed intervention: the reversion and DRAG REQUIRED gone")

-- (step 9e2) on approach (the glue's on_app: FCOM p.1261): speed
-- intervention keeps VNAV PTH with the A/T on the set speed (p.643); the
-- flaps out, the path held up to the flap placard less 5, past it 150 ft
-- above VNAV SPD at the target; END OF DES (the E/D passed: p.1391) level
-- with the A/T on speed, VNAV valid without a path
local s23 = V.new()
local p8 = 1500 + (3000 - 1500) * 8 / 10   -- the shallow line at 8 NM: 2,700 ft
V.update(s23, inp{alt = 35000, mcp_alt = 1000, d_ed = 110, gs = 480})
o = V.update(s23, inp{alt = p8, mcp_alt = 1000, d_ed = 8, gs = 160, ias = 170, on_app = true, spd_int = {cas = 170}})
T.check(o.mode == "PTH" and o.at == V.AT_SPD and math.abs(o.cas - 170) < 1e-6,
    "on approach in speed intervention: VNAV PTH, the A/T on the set 170 kt (not VNAV SPD)")
o = V.update(s23, inp{alt = p8, mcp_alt = 1000, d_ed = 8, gs = 160, ias = 170, spd_int = {cas = 170}})
T.equal(o.mode, "SPD", "not on approach: VNAV SPD (step 9d3)")
o = V.update(s23, inp{alt = p8 + 100, mcp_alt = 1000, d_ed = 8, gs = 160, ias = 198, on_app = true, flaps_placard = 200})
T.equal(o.mode, "PTH", "on approach at 198 under the flap placard 200, 100 ft above: VNAV PTH")
o = V.update(s23, inp{alt = p8 + 200, mcp_alt = 1000, d_ed = 8, gs = 160, ias = 198, on_app = true, flaps_placard = 200})
T.check(o.mode == "SPD" and math.abs(o.cas - 195) < 1e-6,
    string.format("within 5 kt of the placard, 200 ft above: VNAV SPD at the target %.0f (FCOM p.1262)", o.cas))
local s24 = V.new()
V.update(s24, inp{alt = 35000, mcp_alt = 1000, d_ed = 110, gs = 480})
o = V.update(s24, inp{alt = 120, mcp_alt = 3000, path = nil, d_ed = nil, gs = 140, ias = 145, end_des = true})
T.check(o.phase == "DES" and o.end_des and o.valid, "the E/D passed: END OF DES, VNAV valid without a path")
T.check(o.mode == "PTH" and o.at == V.AT_SPD and (o.vs == nil or o.vs == 0), "level with the A/T on speed")

-- (step 9e3) the missed approach (FCOM p.1262, p.1264): from END OF DES
-- the climb phase, VNAV SPD with THR REF to the new CRZ ALT (the missed
-- approach's 3,000 ft), VNAV PTH at it; in the cruise after it the most
-- restrictive of the speed transition (the descent's 240 below 10,000 ft),
-- the best holding speed and ECON cruise, not under the minimum
-- maneuvering speed plus 5; speed intervention the MCP's; without the
-- glue's missed (a new CRZ ALT) ECON cruise
V.missed(s24)
local ma = {alt = 1500, crz_alt = 3000, mcp_alt = 3000, path = nil, d_ed = nil, gs = 150, ias = 160}
local function ma_inp(t)
    local i = inp(ma)
    for k, v in pairs(t) do i[k] = v end
    return i
end
o = V.update(s24, ma_inp{flaps_placard = 230})
T.check(o.phase == "CLB" and o.mode == "SPD" and o.at == V.AT_THR_REF and o.alt == 3000 and o.valid and not o.end_des,
    "the missed approach: the climb, VNAV SPD with THR REF to CRZ ALT 3,000, valid, END OF DES over")
T.near(o.cas, 225, 1e-6, "the climb's target within the flap placard 230 less 5")
o = V.update(s24, ma_inp{alt = 2960, ias = 220, missed = true, hold_cas = 228})
T.check(o.phase == "CRZ" and o.mode == "PTH" and o.at == V.AT_SPD and o.alt == 3000,
    "at 3,000 ft: the cruise, VNAV PTH (p.1264) with the A/T on speed")
T.check(math.abs(o.cas - 228) < 1e-6 and not o.mach_mode, "the best holding 228 kt (under the transition's 240 and ECON cruise)")
o = V.update(s24, ma_inp{alt = 2960, ias = 220, missed = true, hold_cas = 255})
T.near(o.cas, 240, 1e-6, "the best holding 255 kt: the speed transition's 240 below 10,000 ft")
o = V.update(s24, ma_inp{alt = 2960, ias = 220, missed = true, hold_cas = 220, vmin = 230})
T.near(o.cas, 235, 1e-6, "the best holding 220 under the minimum maneuvering 230: 235")
o = V.update(s24, ma_inp{alt = 2960, ias = 220, missed = true, hold_cas = 228, spd_int = {cas = 250}})
T.near(o.cas, 250, 1e-6, "speed intervention: the MCP's 250 kt")
o = V.update(s24, ma_inp{alt = 2960, ias = 220, hold_cas = 228})
T.check(o.mach_mode and math.abs(o.mach - 0.85) < 1e-9, "not after a missed approach: ECON cruise's M.85")
local s26 = V.new()
V.update(s26, inp{alt = 12000, crz_alt = 12000, mcp_alt = 12000})
o = V.update(s26, inp{alt = 12000, crz_alt = 12000, mcp_alt = 12000, path = nil, d_ed = nil, missed = true, hold_cas = 255})
T.check(o.phase == "CRZ" and math.abs(o.cas - 255) < 1e-6, "above the transition's 10,000 ft: the best holding 255 kt")
-- (step 9h3b) an engine failure sensed in the takeoff (FCOM p.1265-1266):
-- V2 + 10 until the E/O acceleration height or the flaps' retraction, then
-- VREF + 100 within the flap placard less 5 kt (the title LIM SPD while
-- the placard limits it: FCOM p.1265's note; FMSPG p.3.3-3), VREF + 100 on
-- (its title VREF + 100) until ENG OUT (step 9h4)
local s9 = V.new()
local toe = {v2 = 160, accel_alt = 1000, eo_accel_alt = 800, flaps = 0.5}
V.update(s9, inp{alt = 0, ground = true, ias = 150, takeoff = toe})
V.update(s9, inp{alt = 300, ias = 182, takeoff = toe})
o = V.update(s9, inp{alt = 450, ias = 182, takeoff = toe, engaged = true})
T.near(o.cas, 182, 1e-6, "all engines: the airspeed at the engage (V2 + 22)")
o = V.update(s9, inp{alt = 500, ias = 182, takeoff = toe, engaged = true, eo = 1, vref = 150})
T.near(o.cas, 170, 1e-6, "an engine failure sensed: V2 + 10 (FCOM p.1266)")
T.equal(o.title, nil, "no title of its own")
o = V.update(s9, inp{alt = 790, ias = 172, takeoff = toe, engaged = true, eo = 1, vref = 150, flaps_placard = 235})
T.near(o.cas, 170, 1e-6, "below the E/O acceleration height: V2 + 10")
o = V.update(s9, inp{alt = 800, ias = 172, takeoff = toe, engaged = true, eo = 1, vref = 150, flaps_placard = 235})
T.near(o.cas, 230, 1e-6, "at the E/O acceleration height: VREF + 100 (250) within the flap placard less 5 (230)")
T.equal(o.title, "LIM SPD", "limited by the flap placard: LIM SPD")
o = V.update(s9, inp{alt = 1500, ias = 232, takeoff = toe, engaged = true, eo = 1, vref = 150})
T.near(o.cas, 250, 1e-6, "the flaps up: VREF + 100")
T.equal(o.title, "VREF + 100", "the title VREF + 100 (FCOM p.1265)")
o = V.update(s9, inp{alt = 12000, ias = 250, takeoff = toe, engaged = true, eo = 1, vref = 150})
T.near(o.cas, 250, 1e-6, "above the speed transition: still VREF + 100")
o = V.update(s9, inp{alt = 12500, ias = 250, takeoff = toe, engaged = true, eo = 0, vref = 150})
T.near(o.cas, 250, 1e-6, "the engine running again: VREF + 100 kept (ENG OUT and ALL ENG are the crew's)")
-- the flaps' retraction before the E/O acceleration height ends V2 + 10
local s10 = V.new()
V.update(s10, inp{alt = 0, ground = true, ias = 150, takeoff = toe})
V.update(s10, inp{alt = 450, ias = 175, takeoff = toe, engaged = true, eo = 1, vref = 150})
o = V.update(s10, inp{alt = 600, ias = 175, takeoff = {v2 = 160, accel_alt = 1000, eo_accel_alt = 800, flaps = 0.33},
    engaged = true, eo = 1, vref = 150, flaps_placard = 260})
T.near(o.cas, 250, 1e-6, "the flaps retracting before it: VREF + 100 (250, under the placard less 5)")
-- a failure after the takeoff's acceleration: the climb's schedule on
local s11 = V.new()
V.update(s11, inp{alt = 0, ground = true, ias = 150, takeoff = toe})
V.update(s11, inp{alt = 450, ias = 175, takeoff = toe, engaged = true})
V.update(s11, inp{alt = 1000, ias = 200, takeoff = toe, engaged = true, flaps_placard = 230})
o = V.update(s11, inp{alt = 3000, ias = 240, takeoff = toe, engaged = true, eo = 1, vref = 150})
T.near(o.cas, 250, 1e-6, "a failure after the acceleration: the climb's 250 kt")
T.equal(o.title, nil, "no VREF + 100")
-- (all engines) the flap placard limiting: LIM SPD
o = V.update(V.new(), inp{alt = 3000, ias = 220, flaps_placard = 230})
T.equal(o.title, "LIM SPD", "the climb's 250 kt limited by the flap placard less 5: LIM SPD")
o = V.update(V.new(), inp{alt = 3000, ias = 220})
T.equal(o.title, nil, "the flaps up: none")
-- the E/O acceleration height above the all-engine one: a failure sensed
-- between them still the engine-out takeoff's (FCOM p.1266's condition:
-- below the E/O acceleration height); above both the climb's
local s12 = V.new()
local toh = {v2 = 160, accel_alt = 1000, eo_accel_alt = 1500, flaps = 0.5}
V.update(s12, inp{alt = 0, ground = true, ias = 150, takeoff = toh})
V.update(s12, inp{alt = 450, ias = 178, takeoff = toh, engaged = true})
o = V.update(s12, inp{alt = 1100, ias = 179, takeoff = toh, engaged = true, flaps_placard = 230})
T.near(o.cas, 225, 1e-6, "all engines past the acceleration height: the placard less 5")
o = V.update(s12, inp{alt = 1200, ias = 180, takeoff = toh, engaged = true, eo = 1, vref = 150, flaps_placard = 230})
T.near(o.cas, 170, 1e-6, "a failure sensed at 1,200 ft, under the E/O acceleration height (1,500 ft): V2 + 10")
o = V.update(s12, inp{alt = 1500, ias = 175, takeoff = toh, engaged = true, eo = 1, vref = 150, flaps_placard = 230})
T.near(o.cas, 225, 1e-6, "at the E/O acceleration height: VREF + 100 within the placard less 5")
T.equal(o.title, "LIM SPD", "LIM SPD")
local s13 = V.new()
V.update(s13, inp{alt = 0, ground = true, ias = 150, takeoff = toh})
V.update(s13, inp{alt = 1600, ias = 200, takeoff = toh, engaged = true})
o = V.update(s13, inp{alt = 1700, ias = 210, takeoff = toh, engaged = true, eo = 1, vref = 150})
T.near(o.cas, 250, 1e-6, "a failure above both: the climb's 250 kt")

-- (step 9h4b) the engine-out driftdown (FCOM p.1268; FCTM p.4.11; FMSPG
-- p.3.4-2): ENG OUT executed at FL350 (CRZ ALT lowered to the E/O MAX
-- FL320): VNAV SPD, the A/T's THR at 300 fpm down at least, the cruise
-- speed (E/O LRC) at CRZ ALT as a Mach; to CRZ ALT
local eoLrc = {fn = function(h, kg) return (P.eo_lrc(P.tables(0), 1, kg, h)) end}
local s14 = V.new()
V.update(s14, inp{alt = 35000, crzspd = eoLrc})
o = V.update(s14, inp{alt = 35000, crz_alt = 32000, mcp_alt = 32000, crzspd = eoLrc, eo_max = 32000})
T.check(o.phase == "CRZ" and o.crz_chg == "DES" and o.dd, "CRZ ALT FL320 under the airplane, ENG OUT active over its MAX: the driftdown")
T.check(o.mode == "SPD" and o.at == V.AT_THR and o.alt == 32000, "VNAV SPD with THR to FL320")
T.near(o.vs, -V.EO_DD_VS, 1e-6, "300 fpm down at least (FCOM p.1268)")
local m320 = P.eo_lrc(P.tables(0), 1, 300000, 32000)
T.check(o.mach_mode and math.abs(o.mach - m320) < 1e-9, string.format("E/O LRC at CRZ ALT: M%.3f (the CRZ page's LRC SPD)", m320))
o = V.update(s14, inp{alt = 33000, crz_alt = 32000, mcp_alt = 32000, crzspd = eoLrc, eo_max = 32300})
T.check(o.dd and math.abs(o.mach - m320) < 1e-9, "33,000 ft, MAX grown to 32,300 ft: the driftdown still, the same Mach")
o = V.update(s14, inp{alt = 32040, crz_alt = 32000, mcp_alt = 32000, crzspd = eoLrc, eo_max = 32300})
T.check(o.crz_chg == nil and not o.dd and o.mode == "PTH" and o.at == V.AT_SPD, "within 50 ft of CRZ ALT: the cruise (E/O LRC CRZ)")
-- the clearance under the maximum (the selector's push, CRZ ALT FL300:
-- FCOM p.1268's condition 2): the driftdown down to the maximum at its
-- start, then the cruise descent's law (E/O CRZ DES: estimate)
local s15 = V.new()
V.update(s15, inp{alt = 35000, crzspd = eoLrc})
o = V.update(s15, inp{alt = 35000, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 32000})
T.check(o.dd and o.alt == 30000, "CRZ ALT FL300: the driftdown toward it")
o = V.update(s15, inp{alt = 31980, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 32000})
T.check(o.dd, "20 ft under the maximum at its start: the driftdown still")
o = V.update(s15, inp{alt = 31900, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 32000})
T.check(not o.dd and o.crz_chg == "DES", "100 ft under it: the cruise descent")
T.check(o.mode == "PTH" and o.at == V.AT_SPD, "VNAV PTH with SPD, E/O LRC (FCOM p.1269's subsequent cruise descent)")
T.near(o.vs, -V.EARLY_VS, 1e-6, "1,250 fpm down")
o = V.update(s15, inp{alt = 31900, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 31750})
T.check(not o.dd, "the maximum 150 ft under the airplane (within EO_DD_ABOVE): not back into it")
o = V.update(s15, inp{alt = 31900, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 30100})
T.check(o.dd, "engine anti-ice on, the maximum 1,800 ft lower: over it again, the driftdown (FMSPG p.3.4-2)")
-- condition 3: the cruise descent first, ENG OUT executed in it over the
-- maximum: the driftdown from there; under the maximum + 200: none
local s16 = V.new()
V.update(s16, inp{alt = 35000})
o = V.update(s16, inp{alt = 35000, crz_alt = 30000, mcp_alt = 30000})
T.check(o.crz_chg == "DES" and not o.dd and o.vs == -V.EARLY_VS, "all engines: the cruise descent")
o = V.update(s16, inp{alt = 34000, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 32000})
T.check(o.dd and o.vs == -V.EO_DD_VS, "ENG OUT executed at 34,000 ft: the driftdown")
local s17 = V.new()
V.update(s17, inp{alt = 32150})
o = V.update(s17, inp{alt = 32150, crz_alt = 30000, mcp_alt = 30000, crzspd = eoLrc, eo_max = 32000})
T.check(o.crz_chg == "DES" and not o.dd, "150 ft over the maximum (within EO_DD_ABOVE): the cruise descent")
-- not without ENG OUT active, nor level
o = V.update(V.new(), inp{alt = 35000, crz_alt = 35000, crzspd = eoLrc, eo_max = 32000})
T.check(not o.dd and o.mode == "PTH", "level at CRZ ALT over the maximum (CRZ ALT not lowered): no driftdown")

-- (step 11c2b) CHECK ALT TGT (FCOM p.1431): VNAV engaged at 12,000 ft in the
-- climb, the MCP altitude below (10,000), the FMC's above (CRZ ALT): level
-- there in VNAV PTH, the A/T on speed; the MCP altitude reset above: the
-- climb again; below again while engaged: not (at the engagement only)
local s18 = V.new()
o = V.update(s18, inp{alt = 12000, mcp_alt = 10000})
T.check(not o.check_alt, "not engaged: no CHECK ALT TGT")
o = V.update(s18, inp{alt = 12000, mcp_alt = 10000, engaged = true})
T.check(o.check_alt and o.mode == "PTH" and o.alt == 12000 and o.vs == nil and o.at == V.AT_SPD,
    "engaged between them: level, CHECK ALT TGT")
o = V.update(s18, inp{alt = 12030, mcp_alt = 10000, engaged = true})
T.check(o.check_alt and o.alt == 12000, "held at the engagement's altitude")
o = V.update(s18, inp{alt = 12030, mcp_alt = 20000, engaged = true})
T.check(not o.check_alt and o.mode == "SPD" and o.alt == 35000, "the MCP altitude reset above: the climb again")
o = V.update(s18, inp{alt = 12030, mcp_alt = 10000, engaged = true})
T.check(not o.check_alt, "below again while engaged: not CHECK ALT TGT")
o = V.update(V.new(), inp{alt = 12000, mcp_alt = 20000, engaged = true})
T.check(not o.check_alt and o.mode == "SPD", "engaged with both above: the climb")
o = V.update(V.new(), inp{alt = 12000, mcp_alt = 11950, engaged = true})
T.check(not o.check_alt, "the MCP altitude within the band: not between")

-- (step LF1; notes/LINE_FLIGHTS.md §1) FCOM p.1264: the T/D's level
-- deceleration and the deceleration before 10,000 ft. A path from the E/D
-- (1,500 ft) to 10,000 ft at 40 NM, the deceleration to 240 kt from 10,700
-- ft at 47 NM (100 ft a NM: 500 fpm at 300 kt), idle to FL350 at 147 NM,
-- 6 NM of level deceleration before it
do
    local pathL = {e = {0, 40, 47, 147}, h = {1500, 10000, 10700, 35000}, k = {"idle", "idle", "decel", "idle"},
        c = {0, 0, 240, 0}, td_decel = 6}
    T.near(V.td_e(pathL, 35000), 153, 1e-9, "the T/D: the path's top and the level deceleration")
    local sA = V.new()
    V.update(sA, inp{alt = 35000, path = pathL})
    o = V.update(sA, inp{alt = 35000, mcp_alt = 10000, path = pathL, d_ed = 154, gs = 480})
    T.equal(o.phase, "CRZ", "154 NM to go: the cruise")
    o = V.update(sA, inp{alt = 35000, mcp_alt = 10000, path = pathL, d_ed = 152, gs = 480})
    T.equal(o.phase, "DES", "152 NM: the descent, its level deceleration (before, at 147 NM)")
    T.check(o.mode == "PTH" and o.at == V.AT_IDLE and o.vs == 0, "VNAV PTH level at FL350 with IDLE (FCOM p.1264's 2)")
    o = V.update(sA, inp{alt = 10350, mcp_alt = 3000, path = pathL, d_ed = 43.5, gs = 300})
    T.equal(o.cas, 240, "on the deceleration before 10,000 ft: its 240 kt the target (p.1264's 4; before, 290 to 10,000 ft)")
    T.check(o.mode == "PTH" and o.at == V.AT_IDLE, "VNAV PTH with IDLE")
    T.near(o.vs, -500, 1, "500 fpm down on it")
    o = V.update(sA, inp{alt = 20000, mcp_alt = 3000, path = pathL, d_ed = 90, gs = 400})
    T.equal(o.cas, 290, "above it: the descent's 290 kt")
end

-- (2026-11-05) the climb's target constraint (V.clb_target): kept through
-- a level-off's overshoot while its waypoint is ahead (FCOM p.1255: VNAV
-- PTH remains within the constraints; s253: the GE 104 ft over FL090B short
-- of OR390 took FL110 as the target and climbed on to the MCP's 15,000 ft)
do
    local OR390, OR414 = {ident = "OR390"}, {ident = "OR414"}
    local passed = {}
    local function was(p) return passed[p] == true end
    -- (step 9i) the SID's (keep: a climb constraint, V.clb_keep)
    local list = {{a = 9000, p = OR390, keep = true}, {a = 11000, p = OR414, keep = true}}
    T.equal(V.clb_target(list, 7000, 35000, was), 9000, "7,000 ft: FL090 at OR390")
    T.equal(V.clb_target(list, 9104, 35000, was), 9000, "104 ft over it, OR390 ahead: still FL090 (before: FL110)")
    T.equal(V.clb_target(list, 9290, 35000, was), 9000, "290 ft over: still FL090")
    -- (step 9i) a climb constraint at any altitude until its waypoint (FMSPG
    -- p.128 (3.3-19): a climb constraint below the airplane, VNAV levels until
    -- the waypoint; the AFDS's "far" level, B747.70.vnav_mode_model.lua)
    T.equal(V.clb_target(list, 9500, 35000, was), 9000, "500 ft over, OR390 ahead: still FL090 (before: taken as missed, FL110)")
    T.equal(V.clb_target(list, 15000, 35000, was), 9000, "6,000 ft over, OR390 ahead: still FL090")
    passed[OR390] = true
    T.equal(V.clb_target(list, 9000, 35000, was), 11000, "OR390 passed: FL110")
    T.equal(V.clb_target({{a = 9000}, {a = 11000}}, 9104, 35000, was), 11000, "no waypoint: 100 ft over, the next (as before)")
    T.equal(V.clb_target(list, 9000, 10000, was), nil, "FL110 not under CRZ ALT 10,000: none")
    T.equal(V.clb_target({}, 9000, 35000, was), nil, "no constraint: none")
    -- (step 9i, a second patch) not a climb constraint (an arrival's in the
    -- predictions' climb by the half of the way, a short route): kept only
    -- through CLB_HOLD_FT under the airplane, then the next (as on 11-05; a
    -- first patch kept it at any altitude: the climb stopped under the
    -- arrival's AT OR BELOW until its waypoint, in the descent)
    local STARX = {ident = "STARX"}
    local arr = {{a = 12000, p = STARX, keep = false}}
    T.equal(V.clb_target(arr, 11000, 35000, was), 12000, "an arrival's 12000B above the airplane: its cap (as before)")
    T.equal(V.clb_target(arr, 12200, 35000, was), 12000, "200 ft over: kept (the level-off)")
    T.equal(V.clb_target(arr, 25000, 35000, was), nil, "13,000 ft over it, its waypoint ahead: not the target, CRZ ALT")
    -- which constraints are the climb's (V.clb_keep): the SID's; an enroute
    -- leg's (the crew's: FMSPG p.114, p.128) before the T/C; not an
    -- arrival's nor an approach's (FCOM p.1258), nor after the T/C or in
    -- the cruise (FCOM p.1258: a descent one)
    T.check(V.clb_keep("SID", 40, nil), "the SID's: a climb constraint")
    T.check(V.clb_keep(nil, 40, 120), "an enroute leg's before the T/C at 120 NM: a climb constraint")
    T.check(not V.clb_keep(nil, 150, 120), "after the T/C: not")
    T.check(not V.clb_keep(nil, 40, nil), "no T/C (the cruise): not")
    T.check(not V.clb_keep("STAR", 40, 120), "an arrival's: not")
    T.check(not V.clb_keep("APPR", 10, 120), "an approach's: not")
end

-- (step 9i, a second patch) the descent's FMC altitude (V.des_target): an
-- AT OR BELOW the lower of it and the path at its point (FMSPG p.227
-- (4-16)); an AT OR ABOVE, an AT, a window's lower as they are. In the
-- descent's speed intervention with the AT OR BELOW 24,000 ft ahead, the
-- path 19,000 ft at its point and the airplane at 20,000 ft: the FMC
-- altitude 19,000 ft, under the airplane (a first patch gave 24,000 ft
-- above it: the AFDS levelled under it in VNAV PTH, "far")
do
    local p = {e = {0, 100}, h = {0, 30000}, k = {"idle", "idle"}}
    T.near(V.des_target({des_alt = 24000, des_kind = "B", des_e = 63.333, path = p}), 19000, 1, "an AT OR BELOW 24,000 over the path's 19,000: 19,000")
    T.equal(V.des_target({des_alt = 15000, des_kind = "B", des_e = 63.333, path = p}), 15000, "an AT OR BELOW 15,000 under the path's 19,000: 15,000")
    T.equal(V.des_target({des_alt = 24000, des_kind = "A", des_e = 63.333, path = p}), 24000, "an AT OR ABOVE: its altitude")
    T.equal(V.des_target({des_alt = 24000, des_kind = "AT", des_e = 63.333, path = p}), 24000, "an AT: its altitude")
    T.equal(V.des_target({des_alt = 24000, des_kind = "B"}), 24000, "an AT OR BELOW without the path: its altitude")
    T.equal(V.des_target({}), nil, "none")
    local sB = V.new()
    V.update(sB, inp{alt = 20000, mcp_alt = 10000, path = p, d_ed = 66.667, gs = 400})
    local o2 = V.update(sB, inp{alt = 20000, mcp_alt = 10000, path = p, d_ed = 66.667, gs = 400,
        spd_int = {cas = 300}, des_alt = 24000, des_kind = "B", des_e = 63.333})
    T.check(o2.phase == "DES" and o2.mode == "SPD", "the descent's speed intervention: VNAV SPD (" .. o2.phase .. ", " .. o2.mode .. ")")
    T.near(o2.alt, 19000, 1, "its FMC altitude the AT OR BELOW's path: 19,000 ft (before: 24,000)")
    o2 = V.update(sB, inp{alt = 20000, mcp_alt = 10000, path = p, d_ed = 66.667, gs = 400,
        des_alt = 24000, des_kind = "B", des_e = 63.333})
    T.near(o2.alt, 19000, 1, "on the path (VNAV PTH): 19,000 ft too")
end

-- (2026-11-08, step 9i's review, finding 3) the climb's legs ahead
-- (V.clb_last, the rule of V.clb_keep), the predictions' and VNAV's: the
-- SID's; in the climb the enroute legs to the T/C (or before predictions
-- half the way); never an arrival's or an approach's leg nor one after it;
-- in the cruise and the descent the SID's only. Before, without a SID the
-- legs before half the way in any phase (the descent's constraints there
-- left out of its path)
do
    local L6 = {{proc = "SID"}, {proc = "SID"}, {}, {}, {proc = "STAR"}, {proc = "APPR"}}
    local X6 = {5, 12, 40, 90, 120, 140}
    T.equal(V.clb_last(L6, X6, "clb", 60, 70), 3, "the climb: the SID's and the enroute legs to the T/C at 60 NM")
    T.equal(V.clb_last(L6, X6, "clb", 100, 70), 4, "the T/C at 100 NM: the next enroute leg too")
    T.equal(V.clb_last(L6, X6, "clb", 200, 70), 4, "the T/C past the arrival's legs: none of them")
    T.equal(V.clb_last(L6, X6, "clb", nil, 70), 3, "no predictions yet: the enroute legs within half the way (70 NM)")
    T.equal(V.clb_last(L6, X6, "crz", 60, 70), 2, "the cruise: the SID's only")
    T.equal(V.clb_last(L6, X6, "des", 60, 70), 2, "the descent: the SID's only")
    local L4 = {{}, {}, {proc = "STAR"}, {}}
    local X4 = {20, 60, 80, 100}
    T.equal(V.clb_last(L4, X4, "des", nil, 50), 0,
        "no SID, the descent: none (before: those within half the way, an arrival's constraint there not the descent's)")
    T.equal(V.clb_last(L4, X4, "crz", 90, 50), 0, "no SID, the cruise: none")
    T.equal(V.clb_last(L4, X4, "clb", 90, 50), 2, "no SID, the climb: the enroute legs to the T/C, none past the arrival's first leg")
    T.equal(V.clb_last({}, {}, "clb", 10, 5), 0, "no legs: none")
    -- the predictions with it: in the descent at 20,000 ft an AT 15,000
    -- 20 NM ahead of an arrival is the path's (before, within half the way
    -- the climb's: the path and the prediction there 20,000 ft)
    local legsD = {{name = "D1", dist = 20, con = {kind = "AT", a = 15000}, proc = "STAR"},
        {name = "D2", dist = 40, con = nil, proc = "STAR"},
        {name = "RW", dist = 15, con = {kind = "AT", a = 500}, proc = "APPR"}}
    local cl = V.clb_last(legsD, {20, 60, 75}, "des", nil, 37.5)
    T.equal(cl, 0, "the arrival's legs in the descent: not the climb's")
    local sD = {P = P, t = P.tables(0), isa = 0, gw = 250000, fuel = 30000, alt = 20000, cas = 290, phase = "des",
        crz = 35000, clb = clb, des = des, crzspd = {mach = 0.85}, legs = legsD, ed = 3, clb_last = cl}
    local rD = PM.predict(sD)
    T.check(rD.pts[1] and math.abs(rD.pts[1].h - 15000) < 600,
        string.format("the AT 15,000 20 NM ahead on the path: %s ft there", tostring(rD.pts[1] and math.floor(rD.pts[1].h))))
end

-- (FMC-08, 2026-11-09) the waypoints' speed constraints (FCOM p.1332: at
-- or below; p.1329, p.1393: the slower of the constraint's and the
-- performance speed). The climb's ahead (clb_spd), not under VREF + 100
-- (FCOM p.1326): the target and the title's XXXKT (FMSPG p.3.3-3)
do
    local sC = V.new()
    o = V.update(sC, inp{alt = 5000, clb_spd = 230, vref = 120})
    T.near(o.cas, 230, 1e-6, "(FMC-08) the climb with 230 kt at a waypoint ahead, VREF 120: 230 (FCOM p.1329)")
    T.equal(o.spd_kt, 230, "the title's 230KT")
    o = V.update(sC, inp{alt = 5000, clb_spd = 230, vref = 150})
    T.near(o.cas, 250, 1e-6, "VREF 150: not under VREF + 100 (250), the transition's 250")
    T.equal(o.spd_kt, nil, "(the constraint not setting it: no title of it)")
    o = V.update(sC, inp{alt = 20000, clb_spd = 280, vref = 150})
    T.near(o.cas, 280, 1e-6, "FL200 with 280 ahead: 280 (ECON's 340 the faster)")
    T.check(not o.mach_mode, "(a CAS)")
    o = V.update(sC, inp{alt = 20000, clb_spd = 280, vref = 150, spd_int = {cas = 300}})
    T.near(o.cas, 300, 1e-6, "speed intervention: the MCP's 300")
    T.equal(o.spd_kt, nil, "(no title of the constraint)")
    o = V.update(sC, inp{alt = 5000, clb_spd = 230, vref = 120, flaps_placard = 220})
    T.check(math.abs(o.cas - 215) < 1e-6 and o.title == "LIM SPD" and o.spd_kt == nil,
        "the flap placard less 5 under it: 215, LIM SPD (not the constraint's title)")
    o = V.update(sC, inp{alt = 5000, des_spd = 200, vref = 120})
    T.near(o.cas, 250, 1e-6, "the descent's passed constraint not the climb's")
end

-- the descent's passed (des_spd: at and after the waypoint, FMSPG p.3.5-3)
-- on the path at 19,000 ft (ECON's 290): 250 and its title; below the first
-- speed constraint now (FCOM p.1259-1260): the A/T's SPD 11 kt slow (10
-- under it; 15 above: IDLE without it), DRAG REQUIRED over the target plus
-- 10, the path held to the target plus 15 (the transition's plus 5 below
-- its altitude only), past it 200 ft above the speed reversion at the
-- target (the constraint's: an estimate, FCOM names the transition's for
-- the first speed constraint at it)
do
    local p60 = 3000 + gr * (60 - 10)
    local function des_inp(t)
        local b = {alt = p60, mcp_alt = 3000, d_ed = 60, gs = 450}
        for k, v in pairs(t) do b[k] = v end
        return inp(b)
    end
    local sD = V.new()
    V.update(sD, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 450})
    o = V.update(sD, des_inp{ias = 250, des_spd = 250})
    T.check(o.phase == "DES" and o.mode == "PTH" and math.abs(o.cas - 250) < 1e-6 and not o.mach_mode,
        string.format("(FMC-08) the descent, 250 kt passed: the target %.1f (ECON's 290 the faster)", o.cas))
    T.equal(o.spd_kt, 250, "the DES page's 250KT (FCOM p.1391)")
    T.equal(o.at, V.AT_IDLE, "on the idle path at it: IDLE")
    o = V.update(sD, des_inp{ias = 239, des_spd = 250})
    T.equal(o.at, V.AT_SPD, "11 kt slow: the A/T's SPD (10 kt below the first speed constraint)")
    o = V.update(sD, des_inp{ias = 248, des_spd = 250})
    T.equal(o.at, V.AT_IDLE, "back within 5 kt: IDLE")
    local sD2 = V.new()
    V.update(sD2, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 450})
    o = V.update(sD2, des_inp{ias = 279})
    T.equal(o.at, V.AT_IDLE, "(without it 11 kt slow of 290: IDLE, 15 kt above the first speed constraint)")
    o = V.update(sD, des_inp{ias = 261, des_spd = 250})
    T.equal(o.msg, "DRAG", "261, over the target plus 10: DRAG REQUIRED")
    T.check(o.mode == "PTH" and math.abs(o.vs - (-gr * 450 / 60)) < 1, "the path held at 261 (to 265)")
    o = V.update(sD2, des_inp{ias = 300})
    T.equal(o.msg, nil, "(without it 300 kt: no message, VMO/MMO less 16 above)")
    o = V.update(sD, des_inp{alt = p60 + 200, ias = 268, des_spd = 250})
    T.check(o.mode == "SPD" and math.abs(o.cas - 250) < 1e-6 and o.msg == "DRAG",
        string.format("268, over 265, 200 ft above: the speed reversion at %.0f (the constraint's), DRAG REQUIRED", o.cas))
    -- (2026-11-09's review) below the transition's altitude with 210 passed:
    -- the reversion at 210, not the transition's 240 (before, 240: over
    -- the constraint)
    local p30 = 3000 + gr * (30 - 10)
    local sG = V.new()
    V.update(sG, inp{alt = 35000, mcp_alt = 1000, d_ed = 110, gs = 480})
    o = V.update(sG, inp{alt = p30 + 300, mcp_alt = 1000, d_ed = 30, gs = 300, ias = 240, des_spd = 210})
    T.check(o.mode == "SPD" and math.abs(o.cas - 210) < 1e-6,
        string.format("9,700 ft, 210 passed, 300 ft above at 240: the reversion at %.0f (210, not 240)", o.cas))
    -- SPD TRANS deleted with 250 passed: below the first speed constraint
    -- all the same (DRAG REQUIRED at the target plus 10; before the A/T's
    -- 10 kt alone)
    local sH = V.new()
    V.update(sH, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 450, des = {cas = 290, mach = 0.84}})
    o = V.update(sH, des_inp{ias = 261, des_spd = 250, des = {cas = 290, mach = 0.84}})
    T.check(math.abs(o.cas - 250) < 1e-6 and o.msg == "DRAG",
        string.format("SPD TRANS deleted, 250 passed, 261 kt: DRAG REQUIRED (the target %.0f plus 10)", o.cas))
    -- the path's deceleration to a waypoint's speed constraint (the
    -- predictions': a "decel" segment with its target): its speed the
    -- target and the title's (FCOM p.1392: SEL SPD transitioning into a
    -- waypoint speed constraint's segment)
    local pathD = {e = {0, 40, 47, 147}, h = {1500, 25000, 25125, 35000}, k = {"idle", "idle", "decel", "idle"},
        c = {0, 0, 280, 0}}
    local sE = V.new()
    V.update(sE, inp{alt = 35000, mcp_alt = 3000, d_ed = 150, gs = 450, path = pathD})
    o = V.update(sE, inp{alt = 25060, mcp_alt = 3000, d_ed = 44, gs = 450, ias = 288, path = pathD})
    T.check(o.phase == "DES" and math.abs(o.cas - 280) < 1e-6 and o.spd_kt == 280,
        string.format("on the deceleration to a waypoint's 280: the target %.0f, the title's %s", o.cas, tostring(o.spd_kt)))
    -- not under the minimum maneuvering speed plus 5 (before, a
    -- deceleration's speed under it too): a waypoint's 210 clean with the
    -- minimum 225: 230, LIM SPD
    local pathL = {e = {0, 20, 24, 124}, h = {1500, 7500, 7900, 35000}, k = {"idle", "idle", "decel", "idle"},
        c = {0, 0, 210, 0}}
    local sF = V.new()
    V.update(sF, inp{alt = 35000, mcp_alt = 3000, d_ed = 130, gs = 450, path = pathL})
    o = V.update(sF, inp{alt = 7700, mcp_alt = 3000, d_ed = 22, gs = 260, ias = 240, path = pathL, vmin = 225})
    T.check(math.abs(o.cas - 230) < 1e-6 and o.title == "LIM SPD" and o.spd_kt == nil,
        string.format("a deceleration to 210 with the minimum maneuvering 225: the target %.0f, %s", o.cas, tostring(o.title)))
    o = V.update(sF, inp{alt = 7700, mcp_alt = 3000, d_ed = 22, gs = 260, ias = 240, path = pathL, vmin = 190})
    T.check(math.abs(o.cas - 210) < 1e-6 and o.title == nil and o.spd_kt == 210,
        string.format("the minimum 190 (flaps 5): 210, its title's (%.0f)", o.cas))
    -- (2026-11-11 review) the flaps' placard limiting the schedule above the
    -- deceleration's 210 (230 less 5): the deceleration's 210 the target, its
    -- title's (before, LIM SPD from the placard stayed)
    o = V.update(sF, inp{alt = 7700, mcp_alt = 3000, d_ed = 22, gs = 260, ias = 224, path = pathL, vmin = 170,
        flaps_placard = 230})
    T.check(math.abs(o.cas - 210) < 1e-6 and o.title == nil and o.spd_kt == 210,
        string.format("the placard 230 above it: 210, its title's (%.0f, %s, %s)", o.cas, tostring(o.title), tostring(o.spd_kt)))
    -- (2026-11-09, s273) on a deceleration past a waypoint's constraint
    -- (below the first speed constraint) the limits around the path's
    -- planned speed there: 280 passed, the deceleration toward 250 planned
    -- 278 here, the airplane at 282: on the path, no message, no
    -- reversion (before, the target 250 plus 15 = 265: the path given up,
    -- 813 ft above it and VNAV SPD)
    local pathS = {e = {0, 20, 35, 135}, h = {1500, 13000, 17500, 37000}, k = {"idle", "idle", "decel", "spd"},
        c = {0, 0, 250, 0}, s = {250, 250, 280, 280}}
    local sS = V.new()
    V.update(sS, inp{alt = 37000, mcp_alt = 3000, d_ed = 140, gs = 400, path = pathS})
    local hS = 13000 + (17500 - 13000) * (33 - 20) / 15
    o = V.update(sS, inp{alt = hS, mcp_alt = 3000, d_ed = 33, gs = 360, ias = 282, path = pathS, des_spd = 280})
    T.check(o.mode == "PTH" and math.abs(o.cas - 250) < 1e-6 and o.msg == nil and math.abs(o.path_dev) < 1,
        string.format("(s273) the deceleration toward 250 planned 276 here, 282 kt: on the path, the target %.0f, no message (%s)", o.cas, tostring(o.msg)))
    T.near(o.vs, -(17500 - 13000) / 15 * 360 / 60, 1, "the path's own vertical speed (not given up)")
    -- a speed reversion past a waypoint's constraint not over a lower one
    -- passed after it (before, 250 kept past BAYST's 240)
    local p60r = 3000 + gr * (60 - 10)
    local sR = V.new()
    V.update(sR, inp{alt = 35000, mcp_alt = 3000, d_ed = 110, gs = 450})
    o = V.update(sR, inp{alt = p60r + 200, mcp_alt = 3000, d_ed = 60, gs = 450, ias = 268, des_spd = 250})
    T.check(o.mode == "SPD" and math.abs(o.cas - 250) < 1e-6, "the reversion at 250")
    o = V.update(sR, inp{alt = p60r + 200, mcp_alt = 3000, d_ed = 60, gs = 450, ias = 255, des_spd = 240})
    T.check(o.mode == "SPD" and math.abs(o.cas - 240) < 1e-6, string.format("240 passed in it: the reversion at %.0f", o.cas))
end

-- (2026-11-09) the path rounded at its breaks (path_blend: PATH_BLEND_S,
-- PATH_LEAD_S; estimates). s273's third run: from the idle descent's 2,700
-- fpm (337.5 ft/NM at 480 kt) into the 500 fpm deceleration (62.5 ft/NM) at
-- 27,500 ft, 386 ft under the path
do
    local pB = {e = {0, 30, 70}, h = {27500 - 62.5 * 30, 27500, 27500 + 337.5 * 40}, k = {"decel", "decel", "idle"}}
    -- a line: its own (the mean of a line is the line)
    local h, gB = V.path_blend(pB, 50, 4, 0.8)
    T.near(h, 27500 + 337.5 * 20, 1e-6, "on a line, 2 NM from any break: the path's own altitude")
    T.near(gB, 337.5, 1e-6, "and gradient")
    -- at the break: the mean over 4 NM 275 ft/NM x 4 / 8 = 137.5 ft over it
    h = V.path_blend(pB, 30, 4, 0.8)
    T.near(h, 27500 + 137.5, 1e-6, "at the break the rounded path 137.5 ft over it (the change 275 ft/NM over 4 NM, / 8)")
    -- the gradient 0.8 NM ahead: [27.2, 31.2] holds 1.2 NM of the steep and
    -- 2.8 of the shallow line
    local _, gA = V.path_blend(pB, 30, 4, 0.8)
    T.near(gA, (337.5 * 1.2 + 62.5 * 2.8) / 4, 1e-6, "its slope taken 0.8 NM ahead: 1.2 NM steep and 2.8 NM shallow")
    -- the change starts lead + l / 2 before the break and ends l / 2 - lead past it
    _, gA = V.path_blend(pB, 32.81, 4, 0.8)
    T.near(gA, 337.5, 1e-6, "2.81 NM before it (more than 0.8 + 2): the steep line's still")
    _, gA = V.path_blend(pB, 28.79, 4, 0.8)
    T.near(gA, 62.5, 1e-6, "1.21 NM past it (more than 2 - 0.8): the shallow line's")
    -- past the E/D the first segment's slope on (no level there)
    h, gA = V.path_blend(pB, 0.5, 4, 0.8)
    T.near(h, 27500 - 62.5 * 29.5, 1e-6, "0.5 NM before the E/D: the line's own (its slope on past the E/D)")
    T.near(gA, 62.5, 1e-6, "and its gradient")
    -- at most the cap (CRZ ALT): the T/D's corner rounded under it (the
    -- line meets 37,000 ft 28.15 NM back from the break), level over it
    local ec = 30 + (37000 - 27500) / 337.5
    h = V.path_blend(pB, ec, 4, 0, 37000)
    T.near(h, 37000 - 337.5 * 4 / 8, 1e-6, "the cap's corner (the T/D's): 168.75 ft under it")
    h, gA = V.path_blend(pB, 68, 4, 0, 37000)
    T.check(h == 37000 and gA == 0, "over the cap: level at it")
    -- no window: the path's own (capped)
    h, gA = V.path_blend(pB, 30.5, 0, 0)
    T.check(math.abs(h - (27500 + 337.5 * 0.5)) < 1e-6 and math.abs(gA - 337.5) < 1e-6, "no window: the path's own")
    h, gA = V.path_blend(pB, 69, 0, 0, 37000)
    T.check(h == 37000 and gA == 0, "no window, over the cap: the cap, level")
    T.check(V.path_blend(nil, 10, 4, 0.8) == nil, "no path: nil")

    -- the law on it: the vertical speed starts to shallow before the break
    local sB = V.new()
    V.update(sB, inp{alt = 37000, crz_alt = 37000, mcp_alt = 10000, d_ed = 59, gs = 480, path = pB})
    local function at(e, above)
        return V.update(sB, inp{alt = 27500 + (e - 30) * (e > 30 and 337.5 or 62.5) + above, crz_alt = 37000,
            mcp_alt = 10000, d_ed = e, gs = 480, path = pB})
    end
    o = at(34, 0)
    T.near(o.vs, -2700, 1, "4 NM before the break: the idle line's 2,700 fpm")
    T.near(o.path_dev, 0, 1e-6, "on it")
    o = at(30, 137.5)
    T.near(o.path_dev, 0, 1e-6, "at the break, 137.5 ft over it: on the rounded path")
    T.near(o.vs, -(337.5 * 1.2 + 62.5 * 2.8) / 4 * 8, 1, string.format("the vertical speed half way down already: %.0f fpm", o.vs))
    o = at(25, 0)
    T.near(o.vs, -500, 1, "5 NM past it: the deceleration's 500 fpm")
end
T.done()
