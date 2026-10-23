-- Run from the repository root with LuaJIT: luajit tests/air/press_model_test.lua
-- The pressurization model (plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.press_model.lua)
-- against FCOM 2.10, 2.30, 2.50, 11.43 and ATA21 21-30: the atmosphere, the
-- modes and schedules (ground, takeoff, climb, cruise, descent, after
-- landing), the landing altitude, the controllers A and B, manual control,
-- the limiter, the relief valves, decompression, and the messages.
local T = dofile("tests/lib/check.lua")("press_model")
local C = dofile("plugins/xtlua_keysystems/scripts/B747.55.xt.air/B747.55.press_model.lua")

local DT = 1 / 30
local SL_PSI_PER_FT = 14.6959 * 5.25588 * 6.87559e-6
-- a flight: the airplane's altitude moves at vs (fpm) in the standard
-- atmosphere; the most cabin climb and descent (sea-level fpm) and ΔP seen
local Flight = {}
Flight.__index = Flight
local function flight(alt, opts)
    local f = setmetatable({s = C.new(), inp = C.inputs(), alt = alt, gs = 0, worst = {climb = 0, descent = 0, dp = 0}}, Flight)
    f.inp.pack_flow = 3
    for k, v in pairs(opts or {}) do f.inp[k] = v end
    return f
end
function Flight:run(seconds, vs, ground)
    vs = vs or 0
    local out
    for _ = 1, math.max(1, math.floor(seconds / DT + 0.5)) do
        self.alt = self.alt + vs * DT / 60
        local inp = self.inp
        inp.alt, inp.vs, inp.gs_kt = self.alt, vs, self.gs
        if ground ~= nil then inp.on_ground = ground end
        inp.agl_ft = inp.on_ground and 0 or math.max(100, self.alt)
        inp.p_amb = C.p_of_ft(self.alt)
        local p0 = self.s.p_cab
        out = C.update(self.s, inp, DT)
        if not inp.on_ground and not self.s.first then
            local slfpm = (out.p_cab - p0) / DT * 60 / SL_PSI_PER_FT   -- + cabin descending
            if -slfpm > self.worst.climb then self.worst.climb = -slfpm end
            if slfpm > self.worst.descent then self.worst.descent = slfpm end
            if out.dp > self.worst.dp then self.worst.dp = out.dp end
        end
    end
    self.out = out
    return out
end
-- climb or descend at vs to alt
function Flight:to(alt, vs)
    local out
    while (vs > 0 and self.alt < alt) or (vs < 0 and self.alt > alt) do out = self:run(1, vs, false) end
    return out
end

-- the standard atmosphere, checked against ATA21 p.425: 0 ft 14.7, 10,000
-- ft 10.11, 30,000 ft 4.36, 45,000 ft 2.14 psia
T.near(C.p_of_ft(0), 14.70, 0.005, "atmosphere: sea level")
T.near(C.p_of_ft(10000), 10.11, 0.005, "atmosphere: 10,000 ft")
T.near(C.p_of_ft(30000), 4.36, 0.005, "atmosphere: 30,000 ft")
T.near(C.p_of_ft(45000), 2.14, 0.005, "atmosphere: 45,000 ft")
T.near(C.ft_of_p(C.p_of_ft(41000)), 41000, 0.5, "atmosphere: the inverse above the tropopause")
T.near(C.ft_of_p(C.p_of_ft(-1000)), -1000, 0.5, "atmosphere: the inverse below sea level")

-- ======== a flight with FMC data: RJAA (135 ft) to a field at 1,000 ft, FL370
local f = flight(135, {fmc_crz_ft = 37000, fmc_dep_ft = 135, fmc_dest_ft = 1000, from_dep_nm = 0, to_dest_nm = 3000})
local out = f:run(30, 0, true)
T.equal(out.mode, C.GROUND, "ground: ground mode")
T.check(out.valve[1] == 1 and out.valve[2] == 1, "ground: outflow valves fully open (ATA21 p.412)")
T.check(out.dp > 0 and out.dp < 0.05, "ground: the packs' air holds a few hundredths of a psi")
T.equal(out.ldg_ft, 135, "ground: the FMC sends the departure field (FCOM p.1400)")
T.check(not out.ldg_alert, "FMC landing altitude: no LANDING ALT")
T.equal(out.active, 1, "power up: controller A (ATA21 p.426)")
-- takeoff mode above 65 kt: the cabin 50 ft below the field at 500 fpm
f.gs = 80
out = f:run(1, 0, true)
T.equal(out.mode, C.TAKEOFF, "65 kt: takeoff mode (ATA21 p.412)")
out = f:run(15, 0, true)
T.near(out.dp, 50 * SL_PSI_PER_FT, 0.004, "takeoff: the cabin 50 ft below the field")
T.check(out.valve[1] < 1 and out.valve[1] > 0.5, "takeoff: the valves a little closed (ATA21 p.429)")
f.gs = 50
out = f:run(1, 0, true)
T.equal(out.mode, C.GROUND, "below 65 kt again: ground mode")
f.gs = 160
out = f:run(15, 0, true)
-- climb at 2,500 fpm to 10,000 ft, then 2,000 to FL370
out = f:to(10000, 2500)
T.equal(out.mode, C.CLIMB, "airborne: climb mode")
out = f:to(37000, 2000)
T.check(f.worst.climb <= 600.5, "FMC climb: the cabin climbs 600 sea-level fpm at most (ATA21 p.428): " .. f.worst.climb)
T.check(f.worst.dp <= 8.9, "FMC climb: ΔP 8.9 at most: " .. f.worst.dp)
out = f:run(5, 0, false)
T.equal(out.mode, C.CRUISE, "within 100 ft of the FMC cruise altitude: cruise (ATA21 p.431)")
T.near(out.dp, C.CRUISE_DP, 0.03, "cruise: ΔP 8.8 (estimate: FCOM p.585's example)")
T.check(out.cabin_ft > 5400 and out.cabin_ft < 5900, "cruise at FL370: the cabin about 5,600 ft: " .. out.cabin_ft)
T.check(out.cruise_clamp, "cruise above 25,000 ft: the ECS card's cruise clamp (ATA21 p.382)")
T.check(out.valve[1] > 0 and out.valve[1] < 0.15, "cruise: the valves nearly closed")
T.equal(out.ldg_ft, 1000, "after T/C the FMC sends the destination (FCOM p.1400)")
out = f:run(60, 0, false)
local held = out.cabin_ft
out = f:run(600, 0, false)
T.near(out.cabin_ft, held, 25, "cruise: the cabin held within 25 ft (ATA21 p.431)")
T.check(not out.cabin_alert and not out.auto_alert and not out.relief_open, "cruise: no CABIN ALTITUDE, CABIN ALT AUTO, relief")
-- descent: 1,000 ft below the cruise altitude
out = f:to(36100, -2000)
T.equal(out.mode, C.CRUISE, "900 ft down: still cruise")
out = f:to(35900, -2000)
T.equal(out.mode, C.DESCENT, "1,000 ft down: descent (ATA21 p.431)")
T.check(not out.cruise_clamp, "descent: no cruise clamp (ATA21 p.387)")
-- a level-off at 10,000 ft for 3 min: the hold, the clamp, the cabin on
-- toward the landing field
out = f:to(10000, -2200)
local before = out.cabin_ft
out = f:run(130, 0, false)
T.check(out.cruise_clamp, "2 min level in descent: cruise clamp (ATA21 p.387)")
out = f:run(60, 0, false)
T.check(out.cabin_ft < before - 300, "level in descent: the cabin goes on down (ATA21 p.431)")
f.worst.descent = 0
out = f:to(1000, -1200)
T.check(f.worst.descent <= C.DESCENT_FMC_FPM + 0.5, "FMC descent: the cabin's descent within its limit: " .. f.worst.descent)
T.near(out.dp, 50 * SL_PSI_PER_FT, 0.01, "touchdown: the cabin about 50 ft below the field (FCOM p.608)")
f.gs = 140
out = f:run(1, 0, true)
T.equal(out.mode, C.LANDED, "touchdown: after landing mode")
for _ = 1, 40 do f.gs = math.max(10, f.gs - 3.5); out = f:run(1, 0, true) end
T.equal(out.mode, C.LANDED, "on the landing roll: still after landing mode, not takeoff")
out = f:run(21, 0, true)
T.equal(out.mode, C.GROUND, "after a minute, the cabin at the outside: ground mode")
T.check(out.valve[1] == 1 and out.valve[2] == 1, "after landing: valves fully open (ATA21 p.432)")
T.equal(out.active, 2, "NORM: controller B on the next flight (ATA21 p.432)")

-- ======== the internal schedules: no FMC data
f = flight(0)
f:run(5, 0, true)
T.equal(f.out.ldg_ft, 2000, "no FMC data: landing altitude 2,000 ft (FCOM p.608)")
T.check(f.out.ldg_alert, "no FMC data: LANDING ALT")
f.gs = 160
f:run(10, 0, true)
f:to(31000, 3000)
T.check(f.worst.climb <= 1000.5, "internal climb: 1,000 fpm at most (ATA21 p.435): " .. f.worst.climb)
out = f:run(44, 0, false)
T.equal(out.mode, C.CLIMB, "internal: level 44 s, still climb")
out = f:run(2, 0, false)
T.equal(out.mode, C.CRUISE, "internal: level 45 s, cruise (ATA21 p.431)")
held = out.cabin_ft
out = f:run(300, 0, false)
T.near(out.cabin_ft, held, 25, "internal cruise: the cabin held")
out = f:to(29900, -1500)
T.equal(out.mode, C.DESCENT, "internal: descent 1,000 ft down")
f.worst.descent = 0
out = f:run(120, -1500, false)
T.check(f.worst.descent <= C.DESCENT_INT_FPM + 0.5 and f.worst.descent > 250, "internal descent: about 300 fpm (ATA21 p.431): " .. f.worst.descent)

-- ======== the landing altitude: MAN from the knob, 50 ft steps, -1,000 to
-- 14,000 ft, from the AUTO value (estimate) (FCOM p.573, p.608)
f = flight(0, {fmc_dest_ft = 1234})
out = f:run(1, 0, true)
T.equal(out.ldg_ft, 1234, "AUTO: the FMC's value (no departure: the destination)")
f.inp.ldg_auto = false
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 1250, "MAN: starts from the AUTO value, on a 50 ft step")
T.check(out.ldg_alert, "MAN: LANDING ALT (FCOM p.620)")
f.inp.ldg_steps = 3
out = f:run(DT, 0, true)
f.inp.ldg_steps = 0
T.equal(out.ldg_ft, 1400, "MAN: three steps up, 150 ft")
f.inp.ldg_steps = 1000
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 14000, "MAN: 14,000 ft at most")
f.inp.ldg_steps = -1000
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, -1000, "MAN: -1,000 ft at least")
f.inp.ldg_steps, f.inp.ldg_auto = 0, true
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 1234, "AUTO again: the FMC's value")

-- the FMC switches to the destination 400 NM out or half way
f = flight(0, {fmc_dep_ft = 100, fmc_dest_ft = 5000, from_dep_nm = 399, to_dest_nm = 900})
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 100, "399 NM out: the departure field")
f.inp.from_dep_nm = 401
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 5000, "401 NM out: the destination (FCOM p.1400)")
f.inp.from_dep_nm, f.inp.to_dest_nm = 200, 150
out = f:run(DT, 0, true)
T.equal(out.ldg_ft, 5000, "past half way: the destination")

-- ======== controllers: DC bus 1 lost for 2 s hands over to B; both lost:
-- CABIN ALT AUTO; power back on both: A (ATA21 p.426, p.436-437; FCOM p.619)
f = flight(0)
f:run(1, 0, true)
f.inp.dc[1] = false
out = f:run(1.9, 0, true)
T.equal(out.active, 1, "DC bus 1 off under 2 s: A still")
out = f:run(0.3, 0, true)
T.equal(out.active, 2, "DC bus 1 off 2 s: B takes over")
T.check(out.cpc_alert[1] and not out.auto_alert, "B in control: STATUS CABIN ALT AUTO A, no caution")
f.inp.dc[2] = false
out = f:run(2.5, 0, true)
T.equal(out.active, 0, "both off: no controller")
T.check(out.auto_alert and out.outflow_alert[1] and out.outflow_alert[2], "both off: CABIN ALT AUTO, OUTFLOW VLV L and R")
f.inp.dc[1], f.inp.dc[2] = true, true
out = f:run(0.1, 0, true)
T.equal(out.active, 1, "power back: A")
f.inp.auto_select = 2
out = f:run(0.1, 0, true)
T.equal(out.active, 2, "AUTO SELECT B: B")

-- ======== manual: MAN L moves the left valve on its DC motor, the right one
-- stays automatic; both MAN: CABIN ALT AUTO (FCOM p.574, p.608, p.619)
f = flight(0)
f:run(1, 0, true)
f.inp.man[1], f.inp.man_cmd = true, -1
out = f:run(4, 0, true)
T.near(out.valve[1], 1 - 4 / C.MAN_TRAVEL_S, 0.01, "CLOSE held 4 s: the left valve closes at its DC motor's speed")
T.equal(out.valve[2], 1, "MAN L on the ground: the right valve stays open")
f = flight(35000)
f:run(5, 0, false)
local auto_pos = f.out.valve[2]
f.inp.man[1] = true
out = f:run(1, 0, false)
T.check(out.outflow_alert[1] and not out.outflow_alert[2], "MAN L: OUTFLOW VLV L")
T.check(not out.auto_alert, "MAN L only: no CABIN ALT AUTO")
f.inp.man_cmd = 1
out = f:run(0.3, 0, false)
f.inp.man_cmd = 0
out = f:run(20, 0, false)
T.check(out.valve[2] < auto_pos, "the left valve opened a little: the right valve closes to keep the cabin")
T.check(math.abs(out.rate_fpm) < 50, "the right valve holds the cabin")
f.inp.apu_hot_bat = false
f.inp.man_cmd = -1
local was = out.valve[1]
out = f:run(3, 0, false)
T.equal(out.valve[1], was, "without the APU hot battery bus the manual valve stays")
f.inp.apu_hot_bat = true
out = f:run(3, 0, false)
T.check(out.valve[1] < was, "CLOSE held: the left valve closes")
f.inp.man_cmd = 0
f.inp.man[2] = true
out = f:run(1, 0, false)
T.check(out.auto_alert, "both MAN: CABIN ALT AUTO (FCOM p.619)")
T.check(not out.cpc_alert[1] and not out.cpc_alert[2], "both MAN: no STATUS CABIN ALT AUTO A/B (ATA21 p.454)")

-- ======== the relief valves: 9.25 psi; the most ΔP stays under FCOM's 9.4
-- (ATA21 p.462; FCOM p.79): both valves closed by hand at FL410
f = flight(41000, {pack_flow = 3.0})
f:run(2, 0, false)
f.inp.man[1], f.inp.man[2], f.inp.man_cmd = true, true, -1
out = f:run(60, 0, false)
T.check(out.relief_open, "valves closed by hand: the relief valves open")
T.check(out.dp > 9.25 and out.dp < 9.4, "relief: ΔP between 9.25 and FCOM's 9.4: " .. out.dp)
T.check(out.relief_alert, "relief open, three packs selected: PRESS RELIEF (FCOM p.620)")
f.inp.packs_selected = 2
out = f:run(DT, 0, false)
T.check(not out.relief_alert, "a pack selected off: no PRESS RELIEF")

-- the negative relief doors: 0.2-0.4 psi, full at 1 psi (ATA21 p.472):
-- valves closed by hand, packs off, a fast descent
f = flight(20000, {pack_flow = 0})
f:run(1, 0, false)
f.inp.man[1], f.inp.man[2], f.inp.man_cmd = true, true, -1
f:run(25, 0, false)
f.inp.depres_slow = true
f:run(600, 0, false)
f.inp.depres_slow = false
out = f:to(2000, -6000)
T.check(out.neg_relief_open, "cabin above the airplane: negative relief open")
T.check(out.dp < -0.3 and out.dp > -1.0, "negative relief: ΔP held under 1 psi: " .. out.dp)

-- ======== the limiter: above 11,000 ft until 10,250 (ATA21 p.406, p.442);
-- X-Plane's fast decompression; CABIN ALTITUDE above 10,000 ft (FCOM p.619);
-- the other controller takes over once (ATA21 p.436)
f = flight(37000)
f:run(5, 0, false)
f.inp.depres_fast = true
out = f:run(3, 0, false)
T.check(out.rate_fpm > 2000, "fast decompression: the cabin climbs fast: " .. out.rate_fpm)
out = f:run(20, 0, false)
T.check(out.cabin_alert, "cabin above 10,000 ft: CABIN ALTITUDE")
T.check(out.limiter, "cabin above 11,000 ft: the limiter")
T.check(out.valve[1] == 0 and out.valve[2] == 0, "limiter: the valves closed")
T.equal(out.active, 2, "2,000 fpm with the airplane level: B takes over")
T.check(out.cpc_alert[1] and not out.cpc_alert[2], "one take-over: STATUS CABIN ALT AUTO A only")
f.inp.depres_fast = false
out = f:to(9000, -6000)
out = f:run(600, 0, false)
T.check(not out.limiter, "cabin back below 10,250 ft: limiter off")
T.check(not out.cabin_alert, "cabin back below 10,000 ft: no CABIN ALTITUDE")

-- ======== a new flight: XTLua's first reads are 0 (no air data, air/ground
-- AIR) and the air/ground can come late; the first 3 s follow the height
-- above the ground, so no takeoff or landing is seen
do
    local s, inp = C.new(), C.inputs()
    inp.p_amb, inp.on_ground, inp.agl_ft, inp.pack_flow = 0, false, 0, 0
    for _ = 1, 5 do C.update(s, inp, DT) end
    inp.p_amb, inp.alt = C.p_of_ft(0), 0
    for _ = 1, 60 do C.update(s, inp, DT) end
    local o = C.update(s, inp, DT)
    T.equal(o.mode, C.GROUND, "new flight, air/ground late: ground from the height above the ground")
    inp.on_ground = true
    for _ = 1, 90 do o = C.update(s, inp, DT) end
    T.equal(o.mode, C.GROUND, "new flight, air/ground late: ground mode, no after-landing mode")
    T.equal(o.active, 1, "new flight, air/ground late: controller A, no change-over")
    T.check(math.abs(o.cabin_ft) < 5, "new flight: the cabin at the field")
end

-- ======== a flight started in the air: the cabin as in cruise (estimate)
f = flight(35000)
out = f:run(1, 0, false)
T.equal(out.mode, C.CRUISE, "air start: cruise")
T.check(out.dp > 8.5 and out.dp <= C.CRUISE_DP + 0.01, "air start: ΔP of the schedule: " .. out.dp)
T.check(out.cruise_clamp, "air start above 25,000 ft: cruise clamp")
T.check(math.abs(out.rate_fpm) < 50, "air start: the cabin steady")
-- X-Plane's air start can drop the airplane thousands of feet before it
-- settles (41,700 to 35,000 ft, measured 2026-10-24): the cabin follows
-- until it does, so the drop is no descent (estimate)
f = flight(41700)
f:run(1, 0, false)
f:to(35000, -15000)
out = f:run(3, 0, false)
T.equal(out.mode, C.CRUISE, "air start with a drop: cruise at the altitude it settled at")
T.near(out.dp, C.CRUISE_DP, 0.03, "air start with a drop: the schedule's ΔP")
out = f:run(60, 0, false)
T.equal(out.mode, C.CRUISE, "air start with a drop: still cruise a minute later")

T.done()
