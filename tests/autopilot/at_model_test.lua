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

T.done()
