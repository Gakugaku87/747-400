-- Run from the repository root with LuaJIT: luajit tests/nav/irs_model_test.lua
-- The IRS model (plugins/xtlua/scripts/B747.34.xt.nav/B747.34.irs_model.lua,
-- 5-1 step 2) without X-Plane: alignment, the position checks, motion, the
-- fast alignment, ATT, the power and the messages. Sources: FCOM p.1216-1217,
-- p.1227-1228, p.1286, p.1429-1430; ATA34_2 p.272-275, p.287, p.342-354.
local T = dofile("tests/lib/check.lua")("irs_model")
local I = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.irs_model.lua")

local LAT, LON = 35.7647, 140.3864              -- RJAA
local s, inp, out
local function fresh()
    s = I.new()
    I.store(s, LAT, LON)
    inp = I.inputs()
    inp.lat, inp.lon = LAT, LON
    out = I.update(s, inp, 0.1)
end
local function run(seconds, dt)
    dt = dt or 1
    for _ = 1, math.floor(seconds / dt + 0.5) do out = I.update(s, inp, dt) end
end
local function msu(v) for i = 1, 3 do inp.msu[i] = v end end
local function enter(lat, lon)
    inp.pos_seq = inp.pos_seq + 1
    inp.pos_lat, inp.pos_lon = lat, lon
    out = I.update(s, inp, 0.1)
end
local function modes() return out.iru[1].mode, out.iru[2].mode, out.iru[3].mode end

-- a full alignment: OFF to NAV on the ground (FCOM p.1227)
fresh()
T.equal(out.iru[1].mode, I.M_OFF, "OFF")
msu(I.NAV)
run(1)
T.equal(out.iru[1].mode, I.M_ALIGN, "OFF to NAV: aligning")
T.check(out.iru[2].align_memo and out.iru[3].align_memo, "IRS ALIGN MODE L, C, R")
T.check(out.set_pos, "SET IRS POS boxes (FCOM p.1286)")
T.near(out.iru[1].time_left, 599, 1, "about ten minutes to go")
run(598)
T.check(not out.enter_pos, "no ENTER IRS POSITION before the ten minutes")
run(5)
T.equal(out.iru[1].mode, I.M_ALIGN, "ten minutes, no position: still aligning")
T.check(out.enter_pos, "ENTER IRS POSITION (ATA34_2 p.348)")
enter(LAT, LON)
T.check(not out.enter_pos, "a good position: the message goes")
run(1)
T.equal(out.iru[1].mode, I.M_NAV, "navigation")
T.check(out.all_nav and not out.set_pos and not out.aligning, "all in NAV: SET IRS POS blank")
T.check(not out.iru[1].align_memo, "no memo")
T.check(out.iru[1].nav_valid and out.iru[1].att_valid and out.iru[1].hdg_valid, "everything valid")

-- the position entered early, against the stored one: 1° (ATA34_2 p.342)
fresh()
msu(I.NAV)
run(10)
enter(LAT + 1.2, LON)
T.check(out.enter_pos, "1.2° from the stored position: ENTER IRS POSITION")
T.check(out.set_pos, "still boxes")
enter(LAT + 0.2, LON)
T.check(not out.enter_pos and not out.set_pos, "within 1°: taken")
run(600)
T.equal(out.iru[2].mode, I.M_NAV, "aligned at ten minutes with the position entered")
fresh()
msu(I.NAV)
run(10)
enter(LAT + 1.2, LON)
enter(LAT + 1.2, LON)
T.check(not out.enter_pos and not out.set_pos, "the same position again: taken")

-- the IRU's own latitude disagrees: twice and it fails (p.344, p.346)
run(600)
T.equal(out.iru[1].mode, I.M_ALIGN, "1.2° wrong at the end: still aligning")
T.check(out.enter_pos and out.set_pos, "ENTER IRS POSITION, boxes again")
enter(LAT + 1.2, LON)
run(1)
T.equal(out.iru[1].mode, I.M_FAIL, "wrong again: the IRU fails")
T.check(out.iru[1].failed and not out.iru[1].att_valid, "IRS LEFT, nothing valid")
msu(I.OFF)
run(20)
msu(I.NAV)
run(1)
T.equal(out.iru[1].mode, I.M_FAIL, "off 20 s: still failed")
msu(I.OFF)
run(31)
msu(I.NAV)
run(1)
T.equal(out.iru[1].mode, I.M_ALIGN, "off 30 s: a new alignment")

-- excessive motion (ATA34_2 p.350; FCOM p.1227)
fresh()
msu(I.NAV)
enter(LAT, LON)
run(300)
inp.moving = true
run(5)
T.check(out.irs_motion, "IRS MOTION")
T.check(not out.iru[1].align_memo, "the memo goes while it moves")
T.near(out.iru[1].time_left, 600, 1, "the alignment starts again")
inp.moving = false
run(1)
T.check(out.iru[1].align_memo, "stopped: the memo again")
run(20)
T.check(out.irs_motion, "IRS MOTION for 30 s after the motion")
run(11)
T.check(not out.irs_motion, "then gone")
run(560)
T.equal(out.iru[1].mode, I.M_ALIGN, "not yet")
run(10)
T.equal(out.iru[1].mode, I.M_NAV, "about ten minutes after the motion stopped")

-- ALIGN from OFF: aligned, waiting at ALIGN until NAV
fresh()
msu(I.ALIGN)
enter(LAT, LON)
run(610)
T.equal(out.iru[1].mode, I.M_ALIGN, "aligned at ALIGN: stays in align mode")
T.check(out.iru[1].align_memo and not out.set_pos, "the memo, no boxes")
T.equal(out.iru[1].time_left, 0, "no time to go")
msu(I.NAV)
run(1)
T.equal(out.iru[1].mode, I.M_NAV, "NAV: navigation at once")

-- a fast alignment: NAV to ALIGN parked (FCOM p.1227; ATA34_2 p.352)
msu(I.ALIGN)
run(1)
T.equal(out.iru[3].mode, I.M_ALIGN, "NAV to ALIGN: fast alignment")
T.check(out.set_pos and out.iru[3].align_memo, "boxes, IRS ALIGN MODE")
T.near(out.iru[3].time_left, 29, 1, "about 30 s")
enter(LAT + 0.1, LON - 0.1)
T.check(not out.enter_pos and not out.set_pos, "within 1/2° and 1°: taken")
msu(I.NAV)
run(31)
T.equal(out.iru[3].mode, I.M_NAV, "navigation after about 30 s")
msu(I.ALIGN)
run(1)
enter(LAT + 0.8, LON)
T.check(out.enter_pos, "0.8° off: ENTER IRS POSITION")
enter(LAT + 0.8, LON)
T.check(out.cycle_irs and not out.enter_pos, "again: CYCLE IRS OFF-NAV")
msu(I.NAV)
run(31)
T.equal(out.iru[1].mode, I.M_NAV, "the fast alignment ends anyway (the position is optional)")
T.check(not out.cycle_irs, "in NAV: the message goes")

-- out of NAV while taxiing: the alignment is lost
inp.moving = true
msu(I.ALIGN)
run(1)
msu(I.NAV)
run(60)
T.equal(out.iru[1].mode, I.M_ALIGN, "NAV to ALIGN moving: a full alignment")
inp.moving = false
enter(LAT, LON)
run(605)
T.equal(out.iru[1].mode, I.M_NAV, "aligned again after stopping")

-- ATT (FCOM p.1216, p.1227-1228; ATA34_2 p.354)
inp.mag_hdg = 85
inp.msu[2] = I.ATT
run(1)
T.equal(out.iru[2].mode, I.M_ATT, "ATT")
T.check(out.iru[2].align_memo and not out.iru[2].att_valid, "30 s in align mode")
T.check(out.set_hdg, "SET HDG dashes")
run(30)
T.check(out.iru[2].att_valid and not out.iru[2].align_memo, "then attitude")
T.check(not out.iru[2].nav_valid and not out.iru[2].hdg_valid, "no position, no heading until SET HDG")
inp.hdg_seq, inp.hdg = inp.hdg_seq + 1, 90
run(1)
T.check(out.iru[2].hdg_valid, "SET HDG: heading valid")
T.near(out.iru[2].hdg, 90, 1e-6, "the entered heading")
inp.mag_hdg = 95
run(1)
T.near(out.iru[2].hdg, 100, 1e-6, "and it follows the turns")
inp.msu[2] = I.NAV
run(5)
T.equal(out.iru[2].mode, I.M_ATT, "latched in ATT until OFF")
inp.msu[2] = I.OFF
run(1)
T.equal(out.iru[2].mode, I.M_OFF, "OFF")
inp.msu[2] = I.NAV
enter(LAT, LON)
run(605)
T.equal(out.iru[2].mode, I.M_NAV, "aligned again")

-- in flight: power lost, the navigation mode gone for the flight (FCOM p.1227-1228)
inp.ground = false
inp.ac[1], inp.hot_bat = false, false
run(1)
T.equal(out.iru[1].mode, I.M_OFF, "both AC and DC lost: alignment lost")
T.equal(out.iru[2].mode, I.M_NAV, "the others on")
inp.ac[1], inp.hot_bat = true, true
run(900)
T.equal(out.iru[1].mode, I.M_ALIGN, "power back in flight: no alignment")
T.check(not out.iru[1].att_valid, "nothing valid")
inp.msu[1] = I.ATT
run(31)
T.check(out.iru[1].att_valid, "ATT gives attitude in flight")
inp.ground = true
inp.msu[1] = I.OFF
run(1)
inp.msu[1] = I.NAV
enter(LAT, LON)
run(605)
T.equal(out.iru[1].mode, I.M_NAV, "on the ground: aligned again")

-- the power (FCOM p.1217, p.1228, p.1429; ATA34_2 p.272-275, p.287)
inp.ac[1] = false
inp.gsb = false
run(5)
T.check(out.iru[1].on_dc and out.iru[1].ac_fail, "AC lost: on DC, >IRS AC LEFT")
T.equal(out.iru[1].mode, I.M_NAV, "still navigating")
T.check(not out.on_bat, "ON BAT after 10 s")
run(6)
T.check(out.on_bat, "ON BAT: on DC on the ground, no ground service bus")
inp.gsb = true
run(1)
T.check(not out.on_bat, "not with the ground service bus")
inp.ac[1] = true
inp.hot_bat = false
run(1)
T.check(out.iru[3].dc_fail and not out.iru[3].on_dc, ">IRS DC: the backup lost")
inp.hot_bat = true
inp.ac[2], inp.ac[1], inp.dc3 = false, false, false
run(299)
T.equal(out.iru[2].mode, I.M_NAV, "the center IRU on DC")
run(2)
T.equal(out.iru[2].mode, I.M_OFF, "without DC bus 3: off after five minutes")
T.check(out.iru[2].dc_fail, ">IRS DC CENTER")
T.equal(out.iru[1].mode, I.M_NAV, "the left IRU stays on DC")

-- a quick start, X-Plane's IRU failure
fresh()
msu(I.NAV)
run(1)
I.align_now(s, inp)
run(1)
T.check(out.all_nav and not out.set_pos, "a quick start: all in NAV")
inp.fail[3] = true
run(1)
T.equal(out.iru[3].mode, I.M_FAIL, "X-Plane's failure: IRS RIGHT")
inp.fail[3] = false
run(1)
T.equal(out.iru[3].mode, I.M_ALIGN, "repaired on the ground: a new alignment")
T.done()
