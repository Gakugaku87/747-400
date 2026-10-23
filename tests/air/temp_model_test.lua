-- Run from the repository root with LuaJIT: luajit tests/air/temp_model_test.lua
-- The temperature model (plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.temp_model.lua)
-- against FCOM 2.10-2.50 and ATA21 21-40 and 21-60: the selectors, the pack
-- outlet by the coolest zone and its limits, trim air, the backup without
-- trim air, the duct overheats and ZONE RST, a ZTC failure, the comfort
-- correction, the aft cargo heat and the forward cargo heaters. The heat
-- balance's numbers are estimates: the checks hold to what the sources say
-- and to a sensible cabin (at its target in half an hour).
local T = dofile("tests/lib/check.lua")("temp_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.temp_model.lua")

local DT = 0.5
local function run(s, inp, seconds)
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do out = M.update(s, inp, DT) end
    return out
end
local function f(c) return c * 9 / 5 + 32 end
-- three packs at high flow from the APU, the upper fans, the centre duct
-- at 30 psi, on the ground, outside at skin_c
local function packs(inp, skin_c)
    inp.skin_c = skin_c
    inp.packs_operating, inp.pack_kg_s, inp.fans, inp.centre_psi = 3, 3.6, 2, 30
end
local function max_error(out)
    local e = 0
    for z = 1, M.NZ do e = math.max(e, math.abs(out.zone_c[z] - out.target_c[z])) end
    return e
end
local function msgs(out)
    return (out.trim_air_off and "TRIM AIR OFF " or "") .. (out.temp_zone and "TEMP ZONE " or "")
        .. (out.sys_fault and "SYS FAULT" or "")
end

-- the selectors: 65-85°F across C to W (FCOM p.554)
do
    local s, inp = M.new(), M.inputs()
    inp.pass_sel, inp.fd_sel = 0, 1
    local out = run(s, inp, 1)
    T.near(f(out.master_c), 65, 0.01, "PASS TEMP at C: MASTER 65°F")
    T.near(f(out.target_c[3]), 65, 0.01, "PASS TEMP at C: zone A's target 65°F")
    T.near(f(out.target_c[M.FD]), 85, 0.01, "FLT DECK TEMP at W: the flight deck's target 85°F")
    inp.pass_sel = 0.5
    out = run(s, inp, 1)
    T.near(f(out.target_c[7]), 75, 0.01, "PASS TEMP in the middle: 75°F")
end

-- a new flight: parked at the outside air; with an engine running at the
-- targets (estimate)
do
    local s, inp = M.new(), M.inputs()
    inp.skin_c = 8
    local out = run(s, inp, DT)
    T.near(out.zone_c[4], 8, 0.1, "parked start: the cabin at the outside temperature")
    T.check(out.backup and not out.target_shown, "no pack: no target shown (FCOM p.577)")
    T.equal(msgs(out), "", "no pack, TRIM AIR on: no message, no light (FCOM p.555, p.621)")
    s, inp = M.new(), M.inputs()
    packs(inp, 8)
    inp.engines = 4
    out = run(s, inp, DT)
    T.near(out.zone_c[4], out.target_c[4], 0.01, "engines running start: the cabin at its target")
end

-- XTLua's first reads of the other modules' datarefs are 0: the start
-- values follow the inputs for the first 3 s, then the heat balance runs
-- (the forward cargo with the equipment cooling exhaust)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, -56)
    inp.on_ground, inp.engines, inp.agl_ft, inp.ac, inp.ee_exhaust = false, 4, 35000, false, false
    local cold = run(s, inp, DT).cargo_c[1]
    inp.ac, inp.ee_exhaust = true, true
    local out = run(s, inp, 2)
    T.check(out.cargo_c[1] > cold + 10, "the exhaust read within 3 s: the forward cargo starts warm")
    out = run(s, inp, 2)
    local warm = out.cargo_c[1]
    inp.ee_exhaust = false
    out = run(s, inp, 1)
    T.check(math.abs(out.cargo_c[1] - warm) < 0.1, "after 3 s: no new start, the cargo cools slowly")
end

-- a hot day: the packs pull the cabin down at their 35°F limit, then hold
-- the targets; the zone that needs the coolest air sets the pack outlet,
-- trim air warms the others (FCOM p.591; ATA21 p.38, p.362)
do
    local s, inp = M.new(), M.inputs()
    inp.skin_c = 35
    run(s, inp, 600)
    packs(inp, 35)
    local out = run(s, inp, 150)
    T.near(out.pack_c, M.PACK_MIN_C, 0.05, "hot cabin: the pack outlet at 35°F (ATA21 p.38)")
    T.check(out.target_shown and not out.backup, "packs and trim air: targets shown")
    out = run(s, inp, 40 * 60)
    T.check(max_error(out) < 0.3, "40 min: every zone at its target")
    T.check(out.pack_c > M.PACK_MIN_C and out.pack_c < out.target_c[3], "holding: the pack outlet between 35°F and the cabin")
    local coolest = 1
    for z = 2, M.NZ do if out.trim[z] < out.trim[coolest] then coolest = z end end
    T.check(out.trim[coolest] < 0.005, "the zone that needs the coolest air: its trim valve closed")
    local most = 1
    for z = 2, M.NZ do if out.trim[z] > out.trim[most] then most = z end end
    T.equal(M.ZONES[most], "A", "zone A, the least heat for its air (estimate), takes the most trim air")
    T.check(out.trim[most] * M.TRIM_K > 1, "zone A's trim air: over 1°C")
    T.equal(msgs(out), "", "normal: no message")
    T.check(out.settled, "at the target: settled (the pack model's clamp)")
    -- the flight deck on its own selector
    inp.fd_sel = 0
    out = run(s, inp, 30 * 60)
    T.near(out.zone_c[M.FD], M.SEL_MIN_C, 0.3, "FLT DECK TEMP at C: the flight deck at 65°F")
    T.near(out.zone_c[4], out.target_c[4], 0.3, "and the cabin still at its target")
end

-- a cold day: the pack outlet at most 135°F; above 25,000 ft its least is
-- 28°F (ATA21 p.38, p.90)
do
    local s, inp = M.new(), M.inputs()
    inp.skin_c = -20
    run(s, inp, 60)
    packs(inp, -20)
    local out = run(s, inp, 150)
    T.near(out.pack_c, M.PACK_MAX_C, 0.05, "cold cabin: the pack outlet at 135°F")
    out = run(s, inp, 45 * 60)
    T.check(max_error(out) < 0.3, "cold day, 45 min: every zone at its target")
    s, inp = M.new(), M.inputs()
    packs(inp, 50)
    inp.on_ground, inp.engines, inp.agl_ft, inp.alt_ft = false, 4, 30000, 30000
    out = run(s, inp, 60)
    T.check(out.pack_c < M.PACK_MIN_C - 2 and out.pack_c >= M.PACK_MIN_HIGH_C - 0.01,
        "above 25,000 ft, much heat: the outlet below 35°F, not below 28°F")
end

-- TRIM AIR off: the master trim air valve closed, the backup holds the
-- passenger zones' mean at the PASS TEMP setting; >TRIM AIR OFF, SYS FAULT,
-- no targets; with all packs off no >TRIM AIR OFF (FCOM p.555, p.577,
-- p.592, p.621; ATA21 p.350, p.368)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 10)
    inp.engines = 4
    run(s, inp, 60)
    inp.trim_air = false
    local out = run(s, inp, 1)
    T.check(out.backup and not out.trim_valve, "TRIM AIR off: the valve closed, backup")
    T.check(out.trim_air_off and out.sys_fault and not out.temp_zone, "TRIM AIR off: >TRIM AIR OFF and SYS FAULT, no TEMP ZONE")
    T.check(not out.target_shown, "backup: no targets (FCOM p.577)")
    T.near(out.trim[3], M.BACKUP_VALVE, 1e-9, "backup: the zone valves at 10% (ATA21 p.368)")
    inp.pass_sel = 0.8
    out = run(s, inp, 40 * 60)
    local mean, n = 0, 0
    for z = 2, M.NZ do mean, n = mean + out.zone_c[z] * M.SHARE[z], n + M.SHARE[z] end
    T.near(mean / n, out.master_c, 0.3, "backup: the passenger zones' mean at PASS TEMP (FCOM p.592)")
    T.check(math.abs(out.zone_c[3] - out.master_c) > 0.05, "backup: no trim, the zones differ")
    inp.packs_operating, inp.pack_kg_s = 0, 0
    out = run(s, inp, 1)
    T.check(not out.trim_air_off and out.sys_fault, "all packs off: no >TRIM AIR OFF; SYS FAULT with the switch off")
end

-- the centre duct isolated: no trim air, backup, SYS FAULT (valve closed
-- with pack air flowing), no message (FCOM p.555, p.591)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 10)
    run(s, inp, 60)
    inp.centre_psi = 0
    local out = run(s, inp, 1)
    T.check(out.backup and not out.trim_valve, "centre duct isolated: no trim air, backup")
    T.equal(msgs(out), "SYS FAULT", "centre duct isolated: SYS FAULT only")
end

-- a zone trim valve failed open: its duct over 185°F for 10 s closes the
-- master valve, latched: TEMP ZONE, >TRIM AIR OFF, SYS FAULT, backup; ZONE
-- RST reopens it once the overheat is gone (FCOM p.555, p.620; ATA21
-- p.348, p.360)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 10)
    inp.engines = 4
    run(s, inp, 30 * 60)
    inp.zone_valve_open[4] = true
    local out, waited = nil, 0
    repeat out, waited = run(s, inp, DT), waited + DT until out.duct_c[4] > M.OVHT_C or waited > 120
    T.check(out.duct_c[4] > M.OVHT_C, "zone B's valve open: its duct over 185°F")
    out = run(s, inp, 9)
    T.check(not out.backup and not out.temp_zone, "over 185°F for 9 s: not yet")
    waited = 0
    repeat out, waited = run(s, inp, DT), waited + DT until out.backup or waited > 5
    T.check(waited <= 1.5 and not out.trim_valve, "over 185°F for 10 s: the master valve closed")
    T.equal(msgs(out), "TRIM AIR OFF TEMP ZONE SYS FAULT", "duct overheat: TEMP ZONE, >TRIM AIR OFF, SYS FAULT")
    T.check(out.duct_c[4] > M.OVHT_C, "the moment it closes: the duct still over 185°F")
    inp.zone_rst = true
    out = run(s, inp, DT)
    inp.zone_rst = false
    T.check(out.backup, "ZONE RST with the duct still over 185°F: stays closed")
    out = run(s, inp, 60)
    T.check(out.backup and out.duct_c[4] < M.OVHT_C, "latched: closed after the duct cooled")
    inp.zone_valve_open[4] = false
    inp.zone_rst = true
    out = run(s, inp, DT)
    inp.zone_rst = false
    out = run(s, inp, 2)
    T.check(not out.backup and out.trim_valve, "ZONE RST with the overheat gone: the master valve open again")
    T.equal(msgs(out), "", "reset: no message")
end

-- a critical ZTC failure: backup at the last PASS TEMP setting, TEMP ZONE,
-- STATUS ZONE TEMP after 70 s; ZONE RST once the fault is gone (FCOM
-- p.555, p.592, p.620; ATA21 p.350, p.368)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 10)
    inp.engines = 4
    inp.pass_sel = 0.3
    run(s, inp, 30 * 60)
    inp.ztc_failed = true
    local out = run(s, inp, 1)
    T.check(out.backup and out.temp_zone and out.trim_air_off, "ZTC failed: backup, TEMP ZONE, >TRIM AIR OFF")
    T.check(not out.zone_temp, "ZTC failed 1 s: no STATUS ZONE TEMP yet")
    inp.pass_sel = 0.9
    out = run(s, inp, 40 * 60)
    T.check(out.zone_temp, "ZTC failed 70 s: STATUS ZONE TEMP (ATA21 p.350)")
    local mean, n = 0, 0
    for z = 2, M.NZ do mean, n = mean + out.zone_c[z] * M.SHARE[z], n + M.SHARE[z] end
    T.near(mean / n, M.SEL_MIN_C + 0.3 * (M.SEL_MAX_C - M.SEL_MIN_C), 0.3,
        "ZTC failed: the cabin at the last setting, not the new one (FCOM p.592)")
    inp.ztc_failed = false
    out = run(s, inp, 1)
    T.check(out.temp_zone, "the failure gone: TEMP ZONE until ZONE RST")
    inp.zone_rst = true
    run(s, inp, DT)
    inp.zone_rst = false
    out = run(s, inp, 1)
    T.check(not out.backup and not out.temp_zone and not out.zone_temp, "ZONE RST: automatic control again")
end

-- no AC power: the ZTC off, backup, no TEMP ZONE (estimate)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 10)
    run(s, inp, 60)
    inp.ac = false
    local out = run(s, inp, 1)
    T.check(out.backup and not out.temp_zone, "no AC: backup, no TEMP ZONE")
end

-- comfort correction: +2°F an hour for two hours in the cruise clamp above
-- 25,000 ft, at most 85°F; out within 5 min of the descent detect and not
-- again in the flight; reset on the ground; PASS TEMP turned cancels it
-- (ATA21 p.382-384; FCOM p.591)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, -25)
    inp.on_ground, inp.engines, inp.agl_ft, inp.alt_ft = false, 4, 35000, 35000
    local out = run(s, inp, 600)
    T.near(out.target_c[3], out.master_c, 1e-6, "no cruise clamp: no correction")
    inp.cruise_clamp = true
    out = run(s, inp, 3600)
    T.near(f(out.target_c[3]) - f(out.master_c), 2, 0.01, "an hour in the clamp: +2°F")
    T.near(out.target_c[M.FD], M.SEL_MIN_C + 0.5 * (M.SEL_MAX_C - M.SEL_MIN_C), 1e-6, "the flight deck: no correction")
    out = run(s, inp, 2 * 3600)
    T.near(f(out.target_c[3]) - f(out.master_c), 4, 0.01, "three hours: +4°F at most")
    inp.alt_ft = 24000
    out = run(s, inp, 60)
    T.near(f(out.target_c[3]) - f(out.master_c), 4, 0.01, "below 25,000 ft: kept")
    inp.descent, inp.cruise_clamp = true, false
    out = run(s, inp, 150)
    T.near(f(out.target_c[3]) - f(out.master_c), 2, 0.05, "descent detect, 2.5 min: half out")
    out = run(s, inp, 151)
    T.near(out.target_c[3], out.master_c, 1e-6, "descent detect, 5 min: out")
    inp.descent, inp.cruise_clamp, inp.alt_ft = false, true, 35000
    out = run(s, inp, 1800)
    T.near(out.target_c[3], out.master_c, 1e-6, "a clamp after the descent detect: no correction")
    inp.on_ground, inp.cruise_clamp = true, false
    run(s, inp, 1)
    inp.on_ground, inp.cruise_clamp = false, true
    inp.pass_sel = 0.95
    out = run(s, inp, 3 * 3600)
    T.near(out.target_c[3], M.SEL_MAX_C, 1e-6, "next flight, PASS TEMP at 84°F: the correction stops at 85°F")
    s, inp = M.new(), M.inputs()
    packs(inp, -25)
    inp.on_ground, inp.engines, inp.agl_ft, inp.alt_ft, inp.cruise_clamp = false, 4, 35000, 35000, true
    run(s, inp, 1800)
    inp.pass_sel = 0.55
    out = run(s, inp, DT)
    T.near(out.target_c[3], out.master_c, 1e-6, "PASS TEMP turned: the correction cancelled (estimate)")
    out = run(s, inp, 1800)
    T.near(out.target_c[3], out.master_c, 1e-6, "and not again in the flight")
end

-- the cabin off its target holds the pack model's clamp
do
    local s, inp = M.new(), M.inputs()
    packs(inp, 30)
    inp.skin_c, inp.engines = 30, 4
    local out = run(s, inp, 5)
    T.check(out.settled, "started at the target: settled")
    inp.pass_sel = 0
    out = run(s, inp, 60)
    T.check(not out.settled, "the cabin 5°C off its target: not settled")
end

-- aft cargo heat: with AFT CARGO HT and an engine running, the control
-- valve holds the selected temperature; off, AFT fire ARM or no engine: no
-- heat; above 90°F the valves close, the TEMP light (in the air) and TEMP
-- CARGO HEAT (FCOM p.557, p.602, p.620; ATA21 p.234-252)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, -30)
    inp.on_ground, inp.engines, inp.agl_ft, inp.alt_ft, inp.cruise_clamp = false, 4, 35000, 35000, true
    inp.pack_kg_s, inp.fans = 2.4, 4
    local out = run(s, inp, 3 * 3600)
    local cold = out.cargo_c[2]
    T.check(cold < M.AFT_SEL_C, "aft cargo without heat in cruise: below 40°F")
    inp.aft_heat = true
    out = run(s, inp, 3600)
    local lo, hi = 99, -99
    for _ = 1, 120 do
        out = run(s, inp, 60)
        lo, hi = math.min(lo, out.cargo_c[2]), math.max(hi, out.cargo_c[2])
    end
    T.check(lo > M.AFT_SEL_C - 1.5 and hi < M.AFT_SEL_C + 1.5, "AFT CARGO HT: the aft cargo held near 40°F (estimate: the setting)")
    inp.aft_fire_arm = true
    out = run(s, inp, 3600)
    T.check(not out.aft_heat and out.cargo_c[2] < M.AFT_SEL_C - 1, "AFT fire ARM: no heat (ATA21 p.240-242)")
    inp.aft_fire_arm, inp.engines = false, 0
    out = run(s, inp, 60)
    T.check(not out.aft_heat, "no engine running: no heat (ATA21 p.242)")
    -- a hot cargo: above 90°F
    s, inp = M.new(), M.inputs()
    packs(inp, 50)
    inp.engines, inp.aft_heat = 4, true
    out = run(s, inp, 6 * 3600)
    T.check(out.cargo_c[2] > M.CARGO_OVHT_C, "a very hot day: the aft cargo above 90°F")
    T.check(out.cargo_heat_alert and not out.aft_temp_light, "on the ground: TEMP CARGO HEAT, the TEMP light inhibited (ATA21 p.244, p.252)")
    T.check(not out.aft_heat, "above 90°F: the valves closed")
    inp.on_ground = false
    out = run(s, inp, 1)
    T.check(out.aft_temp_light, "in the air: the TEMP light")
    inp.aft_heat = false
    out = run(s, inp, 1)
    T.check(not out.cargo_heat_alert and out.aft_temp_light, "AFT CARGO HT off: no TEMP CARGO HEAT, the light stays")
end

-- forward cargo: the equipment cooling exhaust warms it; the heaters run
-- below 40°F until 50°F with the exhaust valve open and two engines above
-- 50% (FCOM p.602; ATA21 p.254-256)
do
    local s, inp = M.new(), M.inputs()
    packs(inp, -40)
    inp.on_ground, inp.engines, inp.engines_n2, inp.agl_ft = false, 4, 4, 35000
    local out = run(s, inp, 4 * 3600)
    T.check(out.cargo_c[1] < M.FWD_ON_C and not out.fwd_heaters, "no exhaust: the forward cargo cold, no heaters")
    inp.ee_exhaust = true
    out = run(s, inp, 1)
    T.check(out.fwd_heaters, "exhaust valve open, two engines: heaters on below 40°F")
    out = run(s, inp, 4 * 3600)
    T.check(out.cargo_c[1] > M.FWD_OFF_C and not out.fwd_heaters, "warmed past 50°F: heaters off")
    s, inp = M.new(), M.inputs()
    packs(inp, -40)
    inp.on_ground, inp.engines, inp.engines_n2, inp.agl_ft, inp.ee_exhaust = false, 4, 1, 35000, true
    out = run(s, inp, 600)
    T.check(not out.fwd_heaters, "one engine above 50%: no heaters")
end

T.done()
