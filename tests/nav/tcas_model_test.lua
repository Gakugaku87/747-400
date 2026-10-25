-- Run from the repository root with LuaJIT: luajit tests/nav/tcas_model_test.lua
-- The transponder and TCAS model (plugins/xtlua/scripts/B747.34.xt.nav/
-- B747.34.tcas_model.lua, 5-1 step 5) without X-Plane: the 570 panel and
-- X-Plane's transponder mode, failures, the RA inhibits, the ND's symbols,
-- TFC and its automatic display, the voices, the PFD's RA guidance values
-- and the EICAS messages. Sources: FCOM p.1218, p.1231, p.1534-1535,
-- p.1553, p.1560-1570, p.1582-1584, p.1593, p.1600-1601, p.1605; ATA34_2
-- p.18, p.24, p.26.
local T = dofile("tests/lib/check.lua")("tcas_model")
local M = dofile("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.tcas_model.lua")

local s, inp, out
local DT = 0.05
local function run(sec)
    local steps = math.max(1, math.floor((sec or DT) / DT + 0.5))
    for _ = 1, steps do out = M.update(s, inp, DT) end
end
local function fresh()
    s, inp = M.new(), M.inputs()
    inp.on_ground, inp.ra, inp.sel = false, 9700, M.SEL_TA_RA
    inp.n = 3
    for j = 1, 3 do inp.threat[j], inp.ssr[j], inp.dist_nm[j], inp.rel_alt_ft[j] = -1, 3, 20, 0 end
    inp.tas_kt = 320
    run()
end
-- one target
local function target(j, threat, dist, rel, ssr)
    inp.threat[j], inp.dist_nm[j], inp.rel_alt_ft[j], inp.ssr[j] = threat, dist, rel, ssr or 3
end
local function no_band()
    local B = M.NO_BAND
    inp.bands = {-B, -B, -B, -B, -B, -B}
end
local function climb_band()            -- red below 1,500 fpm, green 1,500-2,000 (seen in X-Plane)
    local B = M.NO_BAND
    inp.bands = {-B, 1500, 1500, 2000, 2000, 2000}
end
local function descend_band()          -- red above -1,500 fpm, green -2,000 to -1,500
    local B = M.NO_BAND
    inp.bands = {-2000, -2000, -2000, -1500, -1500, B}
end

-- the transponder (FCOM p.1218, p.1231): X-Plane's mode
fresh()
local modes = {[M.SEL_STBY] = M.XP_STBY, [M.SEL_ALT_OFF] = M.XP_MODE_A, [M.SEL_XPDR] = M.XP_ALT,
    [M.SEL_TA_ONLY] = M.XP_TA_ONLY, [M.SEL_TA_RA] = M.XP_TA_RA}
for sel = 0, 4 do
    inp.sel = sel
    run()
    T.equal(out.xp_mode, modes[sel], "selector " .. sel .. " in the air at 9,700 ft")
end
inp.on_ground, inp.ra = true, 0
inp.sel = M.SEL_XPDR
run()
T.equal(out.xp_mode, M.XP_GND, "XPDR on the ground: no altitude (mode S ground)")
inp.sel = M.SEL_TA_RA
run()
T.equal(out.xp_mode, M.XP_TA_ONLY, "TA/RA on the ground: TA only (RAs below 1,000 ft, p.1593)")
T.check(out.nd[1].ta_only and out.nd[2].ta_only, "the NDs show TA ONLY")
T.check(not out.msg_tcas_off, "no TCAS OFF message")
inp.on_ground, inp.ra = false, 990
run()
T.equal(out.xp_mode, M.XP_TA_ONLY, "990 ft: TA only")
inp.ra = 1010
run()
T.equal(out.xp_mode, M.XP_TA_RA, "1,010 ft: TA/RA")
T.check(not out.nd[1].ta_only, "no TA ONLY")
inp.ra_ncd = true
run()
T.equal(out.xp_mode, M.XP_TA_RA, "above 2,500 ft (no computed data): TA/RA")
inp.ra_ncd = false
inp.gpws_warning = true
run()
T.equal(out.xp_mode, M.XP_TA_ONLY, "GPWS warning: TA only (FCOM p.1582)")
T.check(out.nd[1].ta_only, "TA ONLY on the ND")
inp.gpws_warning, inp.windshear = false, true
run()
T.equal(out.xp_mode, M.XP_TA_ONLY, "windshear: TA only")
inp.windshear = false

-- the transponders' failures; the TCAS needs the selected one
inp.xpdr_fail[1] = true
run()
T.equal(out.xp_mode, M.XP_OFF, "L selected and failed: no transponder")
T.check(out.xpdr_msg[1] and not out.xpdr_msg[2], ">TRANSPONDER L")
T.check(out.failed and out.msg_tcas_system, "the TCAS has lost its transponder: >TCAS SYSTEM (estimate)")
inp.xpdr_r = true
run()
T.equal(out.xp_mode, M.XP_TA_RA, "R selected: TA/RA")
T.check(not out.failed and out.xpdr_msg[1], "TCAS works, >TRANSPONDER L stays")
inp.xpdr_power[2] = false
run()
T.check(out.xpdr_msg[2] and out.xp_mode == M.XP_OFF, "R without power: >TRANSPONDER R, no transponder (estimate)")
T.check(out.panel_on, "the panel's code display on the AC standby bus (ATA34_1 p.584)")
inp.xpdr_power[1] = false
run()
T.check(not out.panel_on, "neither bus: the code display is dark")
inp.xpdr_power[1] = true
inp.xpdr_fail[1], inp.xpdr_power[2], inp.xpdr_r = false, true, false
run()
T.check(not out.failed and not out.xpdr_msg[1] and not out.xpdr_msg[2], "both back")

-- the TCAS's failures
inp.power = false
run()
T.check(out.failed and out.msg_tcas_system and not out.operating, "no power: failed")
T.equal(out.xp_mode, M.XP_ALT, "the transponder alone (mode C/S)")
inp.power, inp.fail = true, true
run()
T.check(out.failed, "laminar/B747/tcas/fail")
inp.fail, inp.ra_valid = false, false
run()
T.check(out.failed, "no radio altimeter: failed (estimate)")
inp.ra_valid = true
run()
T.check(out.operating and not out.msg_tcas_system, "working")

-- EICAS (FCOM p.1605, p.1593, p.1601)
inp.sel = M.SEL_XPDR
run()
T.check(out.msg_tcas_off, ">TCAS OFF: TA, TA/RA not selected")
T.equal(out.xp_mode, M.XP_ALT, "XPDR in the air: mode C/S")
inp.ra = 390
run()
T.check(not out.msg_tcas_off, "below 400 ft: no >TCAS OFF")
inp.ra, inp.on_ground = 0, true
run()
T.check(not out.msg_tcas_off, "on the ground: no >TCAS OFF")
inp.ra, inp.on_ground, inp.sel = 9700, false, M.SEL_TA_RA
inp.pfd_ok[1] = false
run()
T.check(out.msg_ra[1] and not out.msg_ra[2], ">TCAS RA CAPTAIN")
T.check(out.ra_mode, "the F/O's PFD can show RAs: TA/RA")
inp.pfd_ok[2] = false
run()
T.check(out.msg_ra[1] and out.msg_ra[2], "both PFDs: >TCAS RA CAPTAIN and F/O")
T.check(not out.operating, "TA/RA with no PFD for RAs: not working (ATA34_2 p.18)")
T.equal(out.xp_mode, M.XP_ALT, "the transponder alone")
T.check(not out.msg_tcas_system, "the NDs can still show traffic: no >TCAS SYSTEM")
inp.sel = M.SEL_TA_ONLY
run()
T.check(out.operating and out.xp_mode == M.XP_TA_ONLY, "TA ONLY keeps the TCAS working")
inp.nd_ok = {false, false}
run()
T.check(out.msg_tcas_system, "no PFD, no ND: >TCAS SYSTEM (FCOM p.1570)")
inp.pfd_ok, inp.nd_ok, inp.sel = {true, true}, {true, true}, M.SEL_TA_RA
run()

-- the ND symbols
fresh()
target(1, 0, 10, 1500)
target(2, 1, 4, -800)
target(3, 0, 12, 3000)
run()
T.equal(out.sym[1], M.SYM_OTHER, "other traffic")
T.equal(out.sym[2], M.SYM_PROX, "proximate")
T.equal(out.sym[3], M.SYM_NONE, "3,000 ft above: outside the window (2,700 ft)")
target(3, 1, 5, 0, 2)
run()
T.equal(out.sym[3], M.SYM_PROX, "no altitude (mode A) within 6 nm: proximate (FCOM p.1562)")
target(3, 0, 8, 5000, 2)
run()
T.equal(out.sym[3], M.SYM_OTHER, "no altitude beyond 6 nm: other, no window")
target(3, 0, 8, 0, 1)
run()
T.equal(out.sym[3], M.SYM_NONE, "a transponder in standby: not seen")
target(3, -1, 8, 0)
run()
T.equal(out.sym[3], M.SYM_NONE, "not tracked by X-Plane")
inp.sel = M.SEL_STBY
run()
T.equal(out.sym[1], M.SYM_NONE, "STBY: nothing shown")
inp.sel = M.SEL_XPDR
run()
T.equal(out.sym[2], M.SYM_NONE, "XPDR: nothing shown (X-Plane's TCAS still runs)")
inp.sel = M.SEL_TA_RA
run()

-- a TA: TRAFFIC, TRAFFIC once, the ND's TRAFFIC, TFC automatic
fresh()
target(1, 0, 8, -400)
run()
T.check(not out.nd[1].tfc and not out.nd[2].tfc, "TFC off at the start")
target(1, 2, 6, -400)
inp.adv, inp.msg = 1, 14
run()
T.equal(out.sym[1], M.SYM_TA, "TA: amber circle")
T.equal(out.voice, M.V_TRAFFIC, "TRAFFIC, TRAFFIC (FCOM p.1561)")
T.equal(out.nd[1].traffic, 1, "amber TRAFFIC")
T.check(out.nd[1].tfc and out.nd[2].tfc and out.nd[1].show, "TFC on both NDs automatically (FCOM p.1584)")
run(0.6)
T.equal(out.voice, M.V_NONE, "the voice code returns to 0")
run(3)
T.equal(out.voice, M.V_NONE, "once")
-- an RA: climb, the intruder below
target(1, 4, 3.5, -420)
inp.adv, inp.msg = 2, M.XM_CLIMB_CROSS
climb_band()
run()
T.equal(out.sym[1], M.SYM_RA, "RA: red square")
T.equal(out.voice, M.V_CLIMB, "CLIMB, CLIMB: the intruder is below, not crossing (estimate: X-Plane says crossing)")
T.equal(out.nd[1].traffic, 2, "red TRAFFIC")
T.check(out.pfd_ra, "RA guidance on the PFDs")
T.equal(out.vs_lo, 1500, "red below 1,500 fpm")
T.check(out.vs_hi == nil, "no red above")
local TAS_FPM = 320 * 6076.12 / 60
T.near(out.pitch_lo, math.deg(math.asin(1500 / TAS_FPM)), 0.01,
    "the pitch region's edge from the airplane symbol: level, the path of 1,500 fpm at 320 kt")
T.check(out.vs_red, "the vertical speed pointer is red: level is in the red region (FCOM p.1537)")
inp.own_vs = 1800
run()
T.near(out.pitch_lo, math.deg(math.asin(1500 / TAS_FPM) - math.asin(1800 / TAS_FPM)), 0.01,
    "climbing at 1,800 fpm: the edge is below the airplane symbol")
T.check(out.pitch_lo < 0, "below")
T.check(not out.vs_red, "the vertical speed pointer is white: 1,800 fpm avoids the traffic")
inp.own_vs = 0
run(1)
T.equal(out.voice, M.V_NONE, "no repeat while the RA stays")
inp.msg = M.XM_INC_CLIMB
run()
T.equal(out.voice, M.V_INC_CLIMB, "INCREASE CLIMB")
run(1)
inp.adv, inp.msg = 0, M.XM_INC_CLIMB
no_band()
target(1, 1, 0.5, -900)
run()
T.equal(out.voice, M.V_NONE, "the advisory ends before X-Plane's message changes")
T.check(not out.pfd_ra, "no RA guidance")
inp.msg = M.XM_CLEAR
run()
T.equal(out.voice, M.V_CLEAR, "CLEAR OF CONFLICT")
T.equal(out.sym[1], M.SYM_PROX, "back to proximate")
T.check(out.nd[1].tfc, "TFC stays (FCOM p.1584)")

-- the other RA voices and CROSSING
local function ra(msg, rel, own_vs)
    fresh()
    target(1, 4, 3, rel)
    inp.own_vs = own_vs or 0
    inp.adv, inp.msg = 2, msg
    run()
    return out.voice
end
T.equal(ra(M.XM_CLIMB, 300), M.V_CLIMB_CROSS, "climb with the intruder above: CLIMB, CROSSING CLIMB (estimate)")
T.equal(ra(M.XM_DESC_CROSS, 480), M.V_DESCEND, "descend with the intruder above: DESCEND, DESCEND")
T.equal(ra(M.XM_DESCEND, -300), M.V_DESC_CROSS, "descend with the intruder below: DESCEND, CROSSING DESCEND")
T.equal(ra(M.XM_CLIMB_NOW, 200), M.V_CLIMB_NOW, "CLIMB, CLIMB NOW")
T.equal(ra(M.XM_DESC_NOW, -200), M.V_DESC_NOW, "DESCEND, DESCEND NOW")
T.equal(ra(M.XM_INC_DESC, 300), M.V_INC_DESC, "INCREASE DESCENT")
T.equal(ra(M.XM_MONITOR, 480), M.V_MONITOR, "MONITOR VERTICAL SPEED")
T.equal(ra(M.XM_MAINTAIN, -500, 1500), M.V_MAINTAIN, "maintain a climb away from traffic below")
T.equal(ra(M.XM_MAINTAIN, 500, 1500), M.V_MAINTAIN_CROSS, "maintain a climb through traffic above: CROSSING")
T.equal(ra(M.XM_LEVEL_OFF, 480), M.V_ADJUST, "LEVEL OFF (7.1) is ADJUST VERTICAL SPEED, ADJUST (7.0)")

-- the upper regions: a descend RA while climbing
fresh()
target(1, 4, 3, 480)
inp.own_vs = 500
inp.adv, inp.msg = 2, M.XM_DESCEND
descend_band()
run()
T.check(out.vs_lo == nil and out.vs_hi == -1500, "red above -1,500 fpm only")
T.near(out.pitch_hi, math.deg(math.asin(-1500 / (320 * 6076.12 / 60)) - math.asin(500 / (320 * 6076.12 / 60))), 0.01,
    "the upper region's edge from the airplane symbol")
T.check(out.pitch_hi < 0 and out.vs_red, "the airplane symbol and the vertical speed are in the red regions")
inp.own_vs = -1700
run()
T.check(out.pitch_hi > 0 and not out.vs_red, "descending at 1,700 fpm: below the region, the pointer white")
inp.adv = 0
no_band()
run()
T.check(not out.pfd_ra and not out.vs_red and out.pitch_hi == nil, "the RA ends: no guidance")

-- the inhibits by height (FCOM p.1593, p.1600-1601)
fresh()
inp.ra = 1050
target(1, 4, 2, 300)
inp.adv, inp.msg = 2, M.XM_DESCEND
descend_band()
run()
T.equal(out.sym[1], M.SYM_TA, "DESCEND below 1,100 ft: shown as a TA (estimate)")
T.equal(out.voice, M.V_TRAFFIC, "its voice is the TA's")
T.check(not out.pfd_ra, "no RA guidance")
fresh()
inp.ra = 1400
target(1, 4, 2, 300)
inp.adv, inp.msg = 2, M.XM_INC_DESC
run()
T.check(out.sym[1] == M.SYM_TA and not out.pfd_ra, "INCREASE DESCENT below 1,500 ft: a TA")
fresh()
inp.ra = 1400
target(1, 4, 2, 300)
inp.adv, inp.msg = 2, M.XM_DESCEND
run()
T.check(out.sym[1] == M.SYM_RA and out.voice == M.V_DESCEND, "DESCEND at 1,400 ft: an RA")
fresh()
inp.ra = 450
target(1, 2, 2, 300)
inp.adv, inp.msg = 1, 14
run()
T.equal(out.sym[1], M.SYM_TA, "a TA at 450 ft")
T.equal(out.voice, M.V_NONE, "no TA voice below 500 ft")
T.check(out.nd[1].tfc, "TFC still comes on")

-- windshear and the GPWS voices
fresh()
inp.windshear = true
target(1, 2, 5, 300)
inp.adv, inp.msg = 1, 14
run()
T.equal(out.voice, M.V_NONE, "windshear: no TCAS voice (FCOM p.1582)")
T.check(not out.nd[1].tfc, "windshear: no automatic TFC (FCOM p.1583)")
fresh()
inp.gpws_voice = true
target(1, 2, 5, 300)
inp.adv, inp.msg = 1, 14
run()
T.equal(out.voice, M.V_NONE, "a GPWS voice sounding: no TCAS voice (estimate)")

-- a TA during an RA has no voice
fresh()
target(1, 4, 3, -420)
inp.adv, inp.msg = 2, M.XM_CLIMB
run()
target(2, 2, 6, 800)
run()
T.equal(out.sym[2], M.SYM_TA, "a second intruder becomes a TA")
T.equal(out.voice, M.V_CLIMB, "the RA's voice is not cut")
run(1)
T.equal(out.voice, M.V_NONE, "and no TRAFFIC during the RA")

-- TFC: the switch and the automatic display (FCOM p.1534, p.1584)
fresh()
inp.tfc_pushes[1] = 1
run()
T.check(out.nd[1].tfc and not out.nd[2].tfc, "Captain's TFC pushed: on")
inp.tfc_pushes[1] = 2
run()
T.check(not out.nd[1].tfc, "pushed again: off")
inp.tfc_pushes[2] = 1
run()
target(1, 2, 6, 300)
inp.adv, inp.msg = 1, 14
run()
T.check(out.nd[2].tfc and not out.nd[1].tfc, "TFC shown on the F/O's ND: the Captain's stays off")
fresh()
inp.nd_traffic_mode[2] = false
target(1, 2, 6, 300)
inp.adv, inp.msg = 1, 14
run()
T.check(out.nd[1].tfc and not out.nd[2].tfc, "the F/O's ND in PLN: only the Captain's comes on")
inp.nd_traffic_mode[2] = true
run()
T.check(out.nd[2].tfc, "armed: on when the F/O's ND comes to MAP")
fresh()
inp.tfc_pushes[1] = 1
inp.nd_traffic_mode[1] = false
run()
target(1, 2, 6, 300)
inp.adv, inp.msg = 1, 14
run()
T.check(out.nd[2].tfc, "TFC selected on a Captain's ND in PLN is not shown: the F/O's comes on")

-- the ND messages
fresh()
inp.tfc_pushes[1] = 1
run()
inp.sel = M.SEL_XPDR
run()
T.check(out.nd[1].off and not out.nd[1].tfc, "TFC with XPDR: TCAS OFF, no TFC")
inp.sel, inp.fail = M.SEL_TA_RA, true
run()
T.check(out.nd[1].fail and not out.nd[1].off and not out.nd[1].tfc, "failed: TCAS FAIL")
T.check(not out.nd[2].fail, "not on the ND without TFC")
inp.sel = M.SEL_STBY
run()
T.check(out.nd[1].fail and not out.nd[1].off, "failed in STBY: TCAS FAIL, not TCAS OFF (FCOM p.1153)")
inp.sel = M.SEL_TA_RA
inp.fail = false
inp.tfc_pushes[1] = 2
run()
inp.fail = true
run()
T.check(not out.nd[1].fail, "TFC pushed off: no TCAS FAIL (FCOM p.1042)")
inp.fail = false
inp.tfc_pushes[1] = 3
inp.nd_range_nm[1] = 10
target(1, 2, 12, 300)
inp.adv, inp.msg = 1, 14
run()
T.equal(out.nd[1].offscale, 1, "a TA beyond 10 nm: amber OFFSCALE")
target(2, 4, 11, -300)
inp.adv, inp.msg = 2, M.XM_CLIMB
run()
T.equal(out.nd[1].offscale, 2, "an RA beyond: red OFFSCALE")
inp.nd_traffic_mode[1] = false
run()
T.equal(out.nd[1].offscale, 0, "no traffic shown in PLN: no OFFSCALE")
T.equal(out.nd[1].traffic, 2, "TRAFFIC in all modes")

-- the nearest 30, TAs and RAs first
fresh()
inp.n = 40
for j = 1, 40 do target(j, 0, j, 0) end
target(40, 2, 40, 300)
run()
local shown = 0
for j = 1, 40 do if out.sym[j] ~= M.SYM_NONE then shown = shown + 1 end end
T.equal(shown, 30, "30 shown")
T.equal(out.sym[40], M.SYM_TA, "the far TA is one of them")
T.equal(out.sym[29], M.SYM_OTHER, "the 29th nearest is shown")
T.equal(out.sym[30], M.SYM_NONE, "the 30th nearest gives way to the TA")
inp.n = 3
run()
T.check(out.sym[40] == nil, "the slots beyond n are cleared")

T.done()
