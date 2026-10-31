-- Run from the repository root with LuaJIT: luajit tests/autopilot/at_model_test.lua
-- The A/T's engage logic and modes (plugins/xtlua_keysystems/scripts/
-- B747.70.xt.autopilot/B747.70.at_model.lua; the FMC's step 9f1, docs/
-- overhaul/notes/ATA-34-61-FMC.md §58): TO's THR REF and HOLD at 65 kt
-- until VNAV (FCOM p.667), no push by 50 kt (FCOM p.656), the disconnect
-- switch and AUTOTHROT DISC (FCOM p.657, p.677), the ARM switch, the
-- reversers on the ground without the message (ATA34_2 p.644), VNAV's IDLE
-- to HOLD at the aft stop (ATA34_2 p.666), FLCH and the captures' SPD
-- (ATA34_2 p.654), G/A, the SPD and THR switches (FCOM p.641-642), the
-- interlocks, the flare retard.
local T = dofile("tests/lib/check.lua")("at_model")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")

local function inp(t)
    local i = {arm = true, ok = true, ground = false, cas = 250, ra = 5000, flaps_up = true, reverse = false,
        limit_to = false, limit_ga = false, pitch = nil, retard = false, vnav_at = 0, vnav_level = false,
        lever_idle = false}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
-- a copy of `a` with `b`'s fields over it
local function with(a, b)
    local c = {}
    for k, v in pairs(a) do c[k] = v end
    for k, v in pairs(b) do c[k] = v end
    return c
end

-- the takeoff: TO/GA on the ground under 50 kt, flaps 20, the TO limit:
-- THR REF; 65 kt: HOLD; HOLD after the lift-off until VNAV engages
local s = A.new()
local G = {ground = true, ra = 0, cas = 0, flaps_up = false, limit_to = true, pitch = "TO"}
A.update(s, inp(G))
T.equal(A.fma(s), 0, "on the ground, armed: blank")
A.update(s, inp(with(G, {toga = true})))
T.check(s.engaged and A.fma(s) == A.THR_REF, "TO/GA under 50 kt: THR REF")
A.update(s, inp(with(G, {cas = 64})))
T.equal(A.fma(s), A.THR_REF, "64 kt: THR REF")
A.update(s, inp(with(G, {cas = 66})))
T.equal(A.fma(s), A.HOLD, "65 kt: HOLD (FCOM p.667)")
A.update(s, inp{ground = false, ra = 300, cas = 175, flaps_up = false, limit_to = true, pitch = "TO"})
T.equal(A.fma(s), A.HOLD, "300 ft: HOLD still (the old one went back to THR REF at 50 ft)")
A.update(s, inp{ra = 420, cas = 178, flaps_up = false, limit_to = true, pitch = "VNAV", vnav_at = A.THR_REF})
T.equal(A.fma(s), A.THR_REF, "VNAV engaged at 400 ft: its THR REF")
A.update(s, inp{pitch = "VNAV", vnav_at = A.SPD})
T.equal(A.fma(s), A.SPD, "VNAV's SPD")
A.update(s, inp{pitch = "VNAV", vnav_at = A.THR_REF, vnav_level = true})
T.equal(A.fma(s), A.SPD, "levelled: SPD (FCOM p.645)")

-- no push by 50 kt: the SPD switch does nothing below 400 ft, VNAV
-- engages above it
local s2 = A.new()
A.update(s2, inp(G))
A.update(s2, inp(with(G, {cas = 60})))
A.update(s2, inp(with(G, {cas = 70, toga = true})))
T.check(not s2.engaged, "TO/GA at 70 kt: nothing (FCOM p.656)")
A.update(s2, inp{ra = 300, cas = 180, pitch = "VS", spd = true})
T.check(not s2.engaged, "not pushed by 50 kt: the SPD switch at 300 ft nothing")
A.update(s2, inp{ra = 450, cas = 180, pitch = "VNAV", vnav_at = A.THR_REF})
T.check(s2.engaged and A.fma(s2) == A.THR_REF, "400 ft: VNAV engages it")

-- the disconnect switch: off with AUTOTHROT DISC; again: the message off
local s3 = A.new()
A.update(s3, inp{pitch = "VS", spd = true})
T.check(s3.engaged and A.fma(s3) == A.SPD and not s3.disc, "SPD in V/S")
A.update(s3, inp{pitch = "VS", disc = true})
T.check(not s3.engaged and s3.disc and A.fma(s3) == 0, "a disconnect push: off, AUTOTHROT DISC (FCOM p.657)")
A.update(s3, inp{pitch = "VS"})
T.check(s3.disc, "the message stays")
A.update(s3, inp{pitch = "VS", disc = true})
T.check(not s3.disc and not s3.engaged, "a second push: the message off, still off")
A.update(s3, inp{pitch = "VS", disc = true})
T.check(not s3.disc, "a push with nothing to reset: nothing")
-- the next engage resets it too
A.update(s3, inp{pitch = "VS", spd = true})
A.update(s3, inp{pitch = "VS", arm = false})
T.check(not s3.engaged and s3.disc, "the ARM switch off: off, AUTOTHROT DISC")
A.update(s3, inp{pitch = "VS", spd = true, arm = false})
T.check(not s3.engaged, "the SPD switch with the ARM switch off: nothing")
A.update(s3, inp{pitch = "FLCH"})
T.check(s3.engaged and A.fma(s3) == A.THR and not s3.disc,
    "FLCH engaging with the ARM switch back on: THR (step 9f2), the message reset")

-- the ARM switch put on while in VNAV: engaged (FCOM p.641)
local s4 = A.new()
A.update(s4, inp{pitch = "VNAV", vnav_at = A.SPD, arm = false})
T.check(not s4.engaged, "VNAV, the ARM switch off: blank")
A.update(s4, inp{pitch = "VNAV", vnav_at = A.SPD, arm = true})
T.check(s4.engaged and A.fma(s4) == A.SPD, "the ARM switch on in VNAV: engaged, SPD")
-- VNAV's IDLE: HOLD once the levers are at the aft stop; the FMC's SPD
A.update(s4, inp{pitch = "VNAV", vnav_at = A.IDLE})
T.equal(A.fma(s4), A.IDLE, "VNAV's IDLE")
A.update(s4, inp{pitch = "VNAV", vnav_at = A.IDLE, lever_idle = true})
T.equal(A.fma(s4), A.HOLD, "at the aft stop: HOLD (ATA34_2 p.666)")
A.update(s4, inp{pitch = "VNAV", vnav_at = A.IDLE, lever_idle = false})
T.equal(A.fma(s4), A.HOLD, "HOLD kept (the levers free)")
A.update(s4, inp{pitch = "VNAV", vnav_at = A.SPD})
T.equal(A.fma(s4), A.SPD, "the FMC's SPD")
-- from VNAV to V/S: SPD (ATA34_2 p.654)
A.update(s4, inp{pitch = "VNAV", vnav_at = A.THR_REF})
A.update(s4, inp{pitch = "VS"})
T.equal(A.fma(s4), A.SPD, "VNAV to V/S: SPD")

-- FLCH, the capture: SPD; G/A's level-off: unchanged (FCOM p.673)
local s5 = A.new()
A.update(s5, inp{pitch = "FLCH"})
T.equal(A.fma(s5), A.THR, "FLCH: THR (step 9f2)")
A.update(s5, inp{pitch = "ALT"})
T.equal(A.fma(s5), A.SPD, "its capture: SPD")
A.update(s5, inp{pitch = "GA", flaps_up = false, toga = true, ra = 800})
T.equal(A.fma(s5), A.THR, "G/A, flaps out: THR (2,000 fpm: ATA34_2 p.674)")
A.update(s5, inp{pitch = "ALT", flaps_up = false, ra = 3000})
T.equal(A.fma(s5), A.THR, "G/A's level-off: THR still (FCOM p.673)")
A.update(s5, inp{pitch = "ALT", spd = true, ra = 3000})
T.equal(A.fma(s5), A.SPD, "then the SPD switch: SPD")
-- G/A with the flaps up and no G/S: nothing
local s6 = A.new()
A.update(s6, inp{pitch = "ALT", toga = true})
T.check(not s6.engaged, "TO/GA, flaps up, no G/S: nothing (ATA34_2 p.674)")
A.update(s6, inp{pitch = "GS", toga = true})
T.check(s6.engaged and A.fma(s6) == A.THR, "in G/S: G/A's THR")

-- the SPD and THR switches' conditions
local s7 = A.new()
A.update(s7, inp{pitch = "FLCH", arm = false})
A.update(s7, inp{pitch = "FLCH", arm = false, spd = true})
T.check(not s7.engaged, "the ARM switch off: nothing")
A.update(s7, inp{pitch = "FLCH"})
A.update(s7, inp{pitch = "FLCH", spd = true})
T.equal(A.fma(s7), A.THR, "SPD in FLCH: nothing (FCOM p.642)")
A.update(s7, inp{pitch = "ALT"})
A.update(s7, inp{pitch = "ALT", thr = true})
T.equal(A.fma(s7), A.THR_REF, "THR in ALT: THR REF (ATA34_2 p.672)")
A.update(s7, inp{pitch = "ALT", spd = true, ra = 300})
T.equal(A.fma(s7), A.THR_REF, "SPD at 300 ft: nothing")
A.update(s7, inp{pitch = "ALT", spd = true, limit_to = true})
T.equal(A.fma(s7), A.THR_REF, "SPD on the TO limit: nothing")
A.update(s7, inp{pitch = "ALT", spd = true})
A.update(s7, inp{pitch = "ALT", thr = true, limit_ga = true})
T.equal(A.fma(s7), A.SPD, "THR on the GA limit: nothing")

-- the interlocks lost: off with the message; the flare retard: IDLE; the
-- reversers on the ground: off without it
local s8 = A.new()
A.update(s8, inp{pitch = "VS", spd = true})
A.update(s8, inp{pitch = "VS", ok = false})
T.check(not s8.engaged and s8.disc, "the interlocks lost: off, AUTOTHROT DISC")
local s9 = A.new()
A.update(s9, inp{pitch = "GS", spd = true, ra = 1000})
A.update(s9, inp{pitch = "FLARE", retard = true, ra = 20, cas = 140})
T.equal(A.fma(s9), A.IDLE, "the flare retard: IDLE (ATA34_2 p.648)")
A.update(s9, inp{pitch = "FLARE", retard = true, ground = true, ra = 0, cas = 130})
T.equal(A.fma(s9), A.IDLE, "on the ground: IDLE still")
A.update(s9, inp{pitch = "FLARE", retard = true, ground = true, ra = 0, cas = 120, reverse = true})
T.check(not s9.engaged and not s9.disc, "the reversers on the ground: off without AUTOTHROT DISC (ATA34_2 p.644)")

-- TO/GA after the lift-off on the TO limit: THR REF kept (not HOLD)
local s10 = A.new()
A.update(s10, inp{ra = 600, cas = 180, flaps_up = false, limit_to = true, pitch = "TO", toga = true})
A.update(s10, inp{ra = 700, cas = 182, flaps_up = false, limit_to = true, pitch = "TO"})
T.equal(A.fma(s10), A.THR_REF, "pushed after takeoff: THR REF, no HOLD")

-- the servo (step 9f2; ATA34_2 p.646-648): the laws' lever rates
-- integrated within 10 degrees a second (0.2 of the lever), 5 in the flare
local function sv(t)
    local i = {dt = 1, ias = 250, accel = 0, target = 250, v_max = 365, v_min = 200, vs = 0, alt = 10000,
        mcp_alt = 10000, thrust = 1.2, thrust_ref = 1.5, n1 = false, lever = 0.5}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
local s11 = A.new()
A.update(s11, inp{pitch = "VS", spd = true})
A.servo(s11, sv{lever = 0.5})
T.check(s11.servo and math.abs(s11.cmd - 0.5) < 1e-9, "SPD on target: the servo excited, the command where the levers are")
A.servo(s11, sv{ias = 240})
local up = s11.cmd - 0.5
T.near(up, A.K_SPD * 10, 1e-9, "10 kt slow: up at K_SPD a kt")
A.servo(s11, sv{ias = 260})
T.near(s11.cmd - (0.5 + up), -A.K_SPD * 10 * A.SPD_DOWN, 1e-9, "10 kt fast: down at half (FCTM p.43)")
local c0 = s11.cmd
A.servo(s11, sv{ias = 100})
T.near(s11.cmd - c0, A.SERVO_RATE, 1e-9, "150 kt slow: at most 10 degrees a second")
c0 = s11.cmd
A.servo(s11, sv{ias = 240, thrust = 1.6})
T.check(s11.cmd < c0, "slow but above the thrust limit: down (the limit kept)")
c0 = s11.cmd
A.servo(s11, sv{ias = 362, target = 400})
T.check(s11.cmd < c0, "a target over Vmax: Vmax less 5 (360 kt): at 362 kt down (FCOM p.675)")
-- THR REF: to the reference thrust, the limit speed (ATA34_2 p.672)
local s12 = A.new()
A.update(s12, inp{pitch = "ALT", thr = true})
A.servo(s12, sv{thrust = 1.3, thrust_ref = 1.5})
T.near(s12.cmd - 0.5, A.K_EPR * 0.2, 1e-9, "THR REF 0.2 EPR below: up at K_EPR")
c0 = s12.cmd
A.servo(s12, sv{thrust = 1.3, thrust_ref = 1.5, ias = 362})
T.check(s12.cmd < c0, "at the limit speed: down")
-- THR: FLCH's V/S (125 s to the MCP altitude), climbing not less
local s13 = A.new()
A.update(s13, inp{pitch = "FLCH"})
A.servo(s13, sv{mcp_alt = 15000, vs = 1000})
local want = 5000 / 125 * 60
T.near(s13.cmd - 0.5, A.K_VS * (want - 1000), 1e-9, string.format("FLCH 5,000 ft up: %.0f fpm wanted, up", want))
c0 = s13.cmd
A.servo(s13, sv{mcp_alt = 15000, vs = 4000, lever = c0})
T.near(s13.cmd, c0, 1e-9, "climbing faster than wanted: not less (ATA34_2 p.646)")
-- descending: less, the aft stop: HOLD (p.670)
local s14 = A.new()
A.update(s14, inp{pitch = "FLCH"})
A.servo(s14, sv{mcp_alt = 5000, vs = 0, lever = 0.1})
T.check(s14.cmd < 0.1, "FLCH 5,000 ft down: less")
for _ = 1, 3 do A.servo(s14, sv{mcp_alt = 5000, vs = 0, lever = s14.cmd}) end
T.check(s14.cmd <= 0 or A.fma(s14) == A.HOLD, "to the aft stop")
A.servo(s14, sv{mcp_alt = 5000, vs = 0, lever = 0})
T.equal(A.fma(s14), A.HOLD, "at the aft stop with less asked: HOLD (FLCH IDLE: ATA34_2 p.654)")
T.check(not s14.servo, "the servo off")
-- the hand 8 degrees off the command in FLCH: HOLD (p.648)
local s15 = A.new()
A.update(s15, inp{pitch = "FLCH"})
A.servo(s15, sv{mcp_alt = 15000, vs = 2400, lever = 0.6})
A.servo(s15, sv{mcp_alt = 15000, vs = 2400, lever = 0.6 + A.OVERRIDE + 0.01})
T.equal(A.fma(s15), A.HOLD, "FLCH, the levers 8 degrees off: HOLD")
-- G/A's THR: 2,000 fpm
local s16 = A.new()
A.update(s16, inp{pitch = "GA", flaps_up = false, toga = true, ra = 800})
A.servo(s16, sv{vs = 1000})
T.near(s16.cmd - 0.5, A.K_VS * 1000, 1e-9, "G/A at 1,000 fpm: up for 2,000")
A.update(s16, inp{pitch = "GA", flaps_up = false, toga = true, ra = 900})
T.equal(A.fma(s16), A.THR_REF, "a second push: THR REF")
-- IDLE: to the stop at 10 degrees a second, the flare's at 5
local s17 = A.new()
A.update(s17, inp{pitch = "VNAV", vnav_at = A.IDLE})
A.servo(s17, sv{lever = 0.5})
T.near(s17.cmd, 0.5 - A.SERVO_RATE, 1e-9, "VNAV's IDLE: back at 10 degrees a second")
local s18 = A.new()
A.update(s18, inp{pitch = "GS", spd = true, ra = 1000})
A.update(s18, inp{pitch = "FLARE", retard = true, ra = 20})
A.servo(s18, sv{lever = 0.4})
T.near(s18.cmd, 0.4 - A.FLARE_RATE, 1e-9, "the flare retard: back at 5 degrees a second (ATA34_2 p.648)")
-- HOLD and off: the servo off, the command with the levers
A.update(s18, inp{pitch = "FLARE", disc = true, ra = 10})
A.servo(s18, sv{lever = 0.33})
T.check(not s18.servo and math.abs(s18.cmd - 0.33) < 1e-9, "off: the servo off, the command with the levers")

-- (the FMC's step 9d2a) VNAV's THR in the early and the cruise descent
-- (FCOM p.1260; FMSPG p.3.5-5): the levers to the FMC's V/S, HOLD on
-- reaching it at the target speed (the throttles dormant: the crew sets
-- the rate), kept while the FMC asks THR; the path met, the FMC's IDLE:
-- IDLE
local s19 = A.new()
A.update(s19, inp{pitch = "VNAV", vnav_at = A.SPD})
A.update(s19, inp{pitch = "VNAV", vnav_at = A.THR})
T.equal(A.fma(s19), A.THR, "VNAV's THR")
A.servo(s19, sv{vs = 0, vnav_vs = -1250, mcp_alt = 31000, lever = 0.6})
T.near(s19.cmd - 0.6, A.K_VS_VNAV * -1250, 1e-9, "level, the FMC's 1,250 fpm down: less at K_VS_VNAV (not FLCH's V/S to the MCP)")
A.servo(s19, sv{vs = -1100, vnav_vs = -1250, lever = s19.cmd})
T.equal(A.fma(s19), A.THR, "1,100 fpm down: THR still")
A.servo(s19, sv{vs = -1160, vnav_vs = -1250, lever = s19.cmd})
T.equal(A.fma(s19), A.THR, "1,160 fpm down, within VS_REACHED at the target speed: THR until REACH_S")
for _ = 2, A.REACH_S do A.servo(s19, sv{vs = -1160, vnav_vs = -1250, lever = s19.cmd}) end
T.equal(A.fma(s19), A.HOLD, "REACH_S within VS_REACHED at the target speed: HOLD (FMSPG p.3.5-5)")
T.check(not s19.servo, "the servo off: the levers the crew's")
A.update(s19, inp{pitch = "VNAV", vnav_at = A.THR})
A.servo(s19, sv{vs = -1500, vnav_vs = -1250, lever = 0.3})
T.equal(A.fma(s19), A.HOLD, "the FMC still asking THR: HOLD kept")
A.update(s19, inp{pitch = "VNAV", vnav_at = A.IDLE})
T.equal(A.fma(s19), A.IDLE, "the path met, the FMC's IDLE: IDLE")
-- the aft stop and the hand: HOLD too
local s20 = A.new()
A.update(s20, inp{pitch = "VNAV", vnav_at = A.THR})
A.servo(s20, sv{vs = -200, vnav_vs = -1250, lever = 0})
T.equal(A.fma(s20), A.HOLD, "THR at the aft stop with less asked: HOLD")
local s21 = A.new()
A.update(s21, inp{pitch = "VNAV", vnav_at = A.THR})
A.servo(s21, sv{vs = -200, vnav_vs = -1250, lever = 0.6})
A.servo(s21, sv{vs = -200, vnav_vs = -1250, lever = 0.6 + A.OVERRIDE + 0.01})
T.equal(A.fma(s21), A.HOLD, "THR, the levers 8 degrees off: HOLD")
-- levelled (VNAV ALT, PTH): SPD, the HOLDs' latches gone with it (the
-- descent on after a level-off: IDLE again; before, HOLD at once)
local s22 = A.new()
A.update(s22, inp{pitch = "VNAV", vnav_at = A.IDLE, lever_idle = true})
T.equal(A.fma(s22), A.HOLD, "IDLE at the aft stop: HOLD")
A.update(s22, inp{pitch = "VNAV", vnav_at = A.IDLE, vnav_level = true})
T.equal(A.fma(s22), A.SPD, "levelled at the MCP altitude: SPD")
A.update(s22, inp{pitch = "VNAV", vnav_at = A.IDLE})
T.equal(A.fma(s22), A.IDLE, "the descent on: IDLE again")
A.servo(s19, sv{vs = -1500, vnav_vs = -1250, lever = 0.3})
A.update(s19, inp{pitch = "VNAV", vnav_at = A.THR})
T.equal(A.fma(s19), A.THR, "THR asked again after IDLE: THR (the latch gone)")

-- at the V/S but 30 kt slow: THR (the HOLD at the target speed; s144's
-- levers held 50 kt slow flew level at the target); a new FMC phase: the
-- HOLD's latch gone, THR again (the early descent after a cruise descent:
-- FCOM p.1260)
local s23 = A.new()
A.update(s23, inp{pitch = "VNAV", vnav_at = A.THR})
for _ = 1, 8 do A.servo(s23, sv{vs = -1250, vnav_vs = -1250, ias = 220, target = 250, lever = 0.3}) end
T.equal(A.fma(s23), A.THR, "at 1,250 fpm 30 kt slow: THR still")
local s24 = A.new()
A.update(s24, inp{pitch = "VNAV", vnav_at = A.THR, vnav_phase = 2})
for _ = 1, A.REACH_S do A.servo(s24, sv{vs = -1250, vnav_vs = -1250, lever = 0.3}) end
T.equal(A.fma(s24), A.HOLD, "the cruise descent's THR at the rate: HOLD")
A.update(s24, inp{pitch = "VNAV", vnav_at = A.THR, vnav_phase = 2})
T.equal(A.fma(s24), A.HOLD, "the same phase: HOLD kept")
A.update(s24, inp{pitch = "VNAV", vnav_at = A.THR, vnav_phase = 3})
T.equal(A.fma(s24), A.THR, "the early descent (the FMC's descent phase): THR again")
-- the inertial V/S (ivs) for VNAV's THR when given: the VSI at the rate but
-- the airplane at 200 fpm: THR still (s144: the VSI's lag held the levers)
local s25 = A.new()
A.update(s25, inp{pitch = "VNAV", vnav_at = A.THR})
for _ = 1, 10 do A.servo(s25, sv{vs = -1250, ivs = -200, vnav_vs = -1250, lever = 0.3}) end
T.equal(A.fma(s25), A.THR, "the VSI at 1,250 fpm, the inertial V/S at 200: THR still")
-- the V/S passing the rate (s144, s145: the pitch levelling a dive at the
-- target speed, the levers at the cruise's thrust): THR, the time from
-- naught each time it comes back; out of THR the time gone
local s26 = A.new()
A.update(s26, inp{pitch = "VNAV", vnav_at = A.THR})
for _, v in ipairs{-2800, -2000, -1300, -1200, -600, 0} do
    A.servo(s26, sv{vs = v, vnav_vs = -1250, lever = s26.cmd > 0 and s26.cmd or 0.2})
end
T.equal(A.fma(s26), A.THR, "the V/S through the rate in 2 s: THR still")
T.near(s26.reach_t, 0, 1e-9, "out of the band: the time naught")
for _ = 1, A.REACH_S - 1 do A.servo(s26, sv{vs = -1250, vnav_vs = -1250, lever = s26.cmd}) end
A.servo(s26, sv{vs = -1250, vnav_vs = -1250, ias = 240, lever = s26.cmd})
for _ = 1, A.REACH_S - 1 do A.servo(s26, sv{vs = -1250, vnav_vs = -1250, lever = s26.cmd}) end
T.equal(A.fma(s26), A.THR, "the speed 10 kt off in between: the time from naught, THR still")
A.servo(s26, sv{vs = -1250, vnav_vs = -1250, lever = s26.cmd})
T.equal(A.fma(s26), A.HOLD, "then REACH_S at the rate: HOLD")
T.near(s26.reach_t, 0, 1e-9, "HOLD: the time naught")
local s27 = A.new()
A.update(s27, inp{pitch = "VNAV", vnav_at = A.THR})
for _ = 1, A.REACH_S - 1 do A.servo(s27, sv{vs = -1250, vnav_vs = -1250, lever = 0.3}) end
A.update(s27, inp{pitch = "VNAV", vnav_at = A.SPD})
A.servo(s27, sv{lever = 0.3})
T.near(s27.reach_t, 0, 1e-9, "SPD between: the time naught")
A.update(s27, inp{pitch = "VNAV", vnav_at = A.THR})
A.servo(s27, sv{vs = -1250, vnav_vs = -1250, lever = 0.3})
T.equal(A.fma(s27), A.THR, "THR again at the rate: THR (the time from naught)")
-- the energy's rate (evs) when given: the levers by it, the V/S as the
-- speed would give it at the target (s146: +1,500 fpm slowing 12 kt to the
-- descent's speed, the energy's -100: before, on the V/S, the levers on to
-- the aft stop); HOLD with both at the rate
local s28 = A.new()
A.update(s28, inp{pitch = "VNAV", vnav_at = A.THR})
A.servo(s28, sv{vs = 1500, ivs = 1500, evs = -100, vnav_vs = -1250, lever = 0.2})
T.near(s28.cmd - 0.2, A.K_VS_VNAV * (-1250 + 100), 1e-9, "climbing 1,500 fpm as it slows, the energy's -100: less by the energy's error")
for _ = 1, 10 do A.servo(s28, sv{vs = -1250, ivs = -1250, evs = -1600, vnav_vs = -1250, lever = s28.cmd}) end
T.equal(A.fma(s28), A.THR, "the V/S at the rate, the energy's 350 fpm off (slowing): THR still")
for _ = 1, A.REACH_S do A.servo(s28, sv{vs = -1250, ivs = -1250, evs = -1250, vnav_vs = -1250, lever = s28.cmd}) end
T.equal(A.fma(s28), A.HOLD, "both at the rate for REACH_S: HOLD")
-- the energy's rate at the target speed (target_vs): at a held IAS the V/S
-- itself (on the TAS's change 260 fpm steeper at a held 294 kt going down:
-- s146, no HOLD); the IAS falling 0.5 kt/s at 300 kt and 240 m/s TAS, the
-- V/S less V^2 d(ln IAS)/dt / g once the second's filter has it; the
-- measure's change (IAS to Mach) without a jump
local s29 = A.new()
local function tv(n, ivs, x, rate, mach)
    local v
    for _ = 1, n do
        x = x * math.exp(rate / 30)
        v = A.target_vs(s29, ivs, 240, x, mach, 1 / 30)
    end
    return v
end
T.near(tv(30, -960, 294, 0, false), -960, 1e-9, "a held IAS: the V/S itself")
local v1 = tv(300, 1500, 300, -0.5 / 300, false)
local want1 = 1500 + A.EVS_K * 240 * 240 * (-0.5 / 300)
T.near(v1, want1, 20, string.format("climbing 1,500 fpm, the IAS falling 0.5 kt/s: %.0f fpm (%.0f)", v1, want1))
T.near(A.target_vs(s29, 1500, 240, 0.78, true, 1 / 30), v1, 1e-6, "to the Mach: that frame the rate kept (no jump)")

T.done()
