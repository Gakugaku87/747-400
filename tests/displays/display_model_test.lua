-- Run from the repository root with LuaJIT: luajit tests/displays/display_model_test.lua
-- The display units and EIUs model (plugins/xtlua_keysystems/scripts/
-- B747.60.xt.fltInst/B747.60.display_model.lua, 5-2 step 1) without X-Plane:
-- the INBD and LWR selectors, the automatic switching on unit failures, the
-- EIUs and their selectors, standby power, >EIU LEFT. Sources: FCOM p.800,
-- p.804, p.1044-1045, p.1072-1073, p.1199, p.1529.
local T = dofile("tests/lib/check.lua")("display_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.display_model.lua")

local s, inp, out
local function run() out = M.update(s, inp) end
local function fresh() s, inp = M.new(), M.inputs() run() end
local function on(c) return out.power[c] == M.ON end

-- normal (FCOM p.1072)
fresh()
for c = 1, 6 do T.equal(out.pos[c], 0, "normal: display " .. c .. " at its usual place") end
for c = 1, 6 do T.check(on(c), "normal: display " .. c .. " powered") end
T.equal(out.shown_on[M.C_PFD_CAPT], M.U_CAPT_OUT, "Captain's PFD on the outboard unit")
T.equal(out.shown_on[M.C_ND_FO], M.U_FO_IN, "F/O's ND on the inboard unit")
T.equal(out.shown_on[M.C_PRI], M.U_UPPER, "primary EICAS on the upper unit")
T.equal(out.shown_on[M.C_SEC], M.U_LOWER, "secondary EICAS on the lower unit")
T.equal(out.eiu[1], M.EIU_L, "Captain AUTO: L")
T.equal(out.eiu[2], M.EIU_R, "F/O AUTO: R")
T.equal(out.eiu[3], M.EIU_L, "EICAS AUTO: L")

-- automatic switching (FCOM p.1045, p.1072)
fresh()
inp.unit_fail[M.U_CAPT_OUT] = true
inp.unit_fail[M.U_UPPER] = true
run()
T.equal(out.shown_on[M.C_PFD_CAPT], M.U_CAPT_IN, "the Captain's outboard unit fails: the PFD on the inboard one")
T.equal(out.pos[M.C_PFD_CAPT], 1, "capt/pfd_pos 1")
T.check(not on(M.C_ND_CAPT), "the Captain's ND not shown")
T.equal(out.shown_on[M.C_PRI], M.U_LOWER, "the upper unit fails: primary EICAS on the lower one")
T.equal(out.pos[M.C_PRI], 1, "pri_eicas_pos 1")
T.check(not on(M.C_SEC), "the secondary EICAS not shown")
T.equal(out.shown_on[M.C_ND_FO], M.U_FO_IN, "the F/O's side as it was")

-- INBD EICAS with the upper unit failed (FCOM p.1073)
inp.unit_fail[M.U_CAPT_OUT] = false
inp.inbd[1] = M.INBD_EICAS
run()
T.equal(out.shown_on[M.C_SEC], M.U_CAPT_IN, "INBD EICAS: the secondary EICAS on the Captain's inboard unit")
T.equal(out.pos[M.C_SEC], 2, "eicas_pos 2")
T.equal(out.shown_on[M.C_PRI], M.U_LOWER, "the primary on the lower unit")
T.equal(out.shown_on[M.C_PFD_CAPT], M.U_CAPT_OUT, "the PFD on the outboard unit")
inp.lwr[1] = M.LWR_ND
run()
T.equal(out.shown_on[M.C_PRI], M.U_CAPT_IN, "the primary has no other unit: INBD EICAS shows it")
T.equal(out.pos[M.C_PRI], 2, "pri_eicas_pos 2")
T.equal(out.shown_on[M.C_ND_CAPT], M.U_LOWER, "LWR ND: the Captain's ND on the lower unit")
T.check(not on(M.C_SEC), "no unit left for the secondary")

-- LWR ND with the inboard unit failed (FCOM p.1073)
fresh()
inp.unit_fail[M.U_CAPT_IN] = true
inp.lwr[1] = M.LWR_ND
run()
T.equal(out.shown_on[M.C_ND_CAPT], M.U_LOWER, "LWR ND: the Captain's ND on the lower unit")
T.equal(out.pos[M.C_ND_CAPT], 1, "capt/nd_pos 1")
T.equal(out.shown_on[M.C_PRI], M.U_UPPER, "the primary on the upper unit")
T.check(not on(M.C_SEC), "the secondary not shown")

-- selections without a failure: the usual unit left blank (estimate)
fresh()
inp.inbd[1] = M.INBD_PFD
run()
T.equal(out.shown_on[M.C_PFD_CAPT], M.U_CAPT_IN, "INBD PFD: the PFD on the inboard unit")
T.check(not on(M.C_ND_CAPT), "the Captain's ND not shown")
T.equal(out.shown_on[M.C_SEC], M.U_LOWER, "the secondary stays on the lower unit")
inp.inbd[1] = M.INBD_NORM
inp.lwr[2] = M.LWR_PRI
run()
T.equal(out.shown_on[M.C_PRI], M.U_LOWER, "the F/O's LWR EICAS PRI: the primary on the lower unit")
T.check(not on(M.C_SEC), "the secondary not shown")
inp.lwr[1] = M.LWR_ND
run()
T.equal(out.shown_on[M.C_PRI], M.U_LOWER, "LWR EICAS PRI before LWR ND (estimate)")
T.equal(out.shown_on[M.C_ND_CAPT], M.U_CAPT_IN, "the Captain's ND stays inboard")
fresh()
inp.inbd[2] = M.INBD_EICAS
run()
T.equal(out.shown_on[M.C_SEC], M.U_FO_IN, "the F/O's INBD EICAS: the secondary on the F/O's inboard unit")
T.equal(out.pos[M.C_SEC], 1, "eicas_pos 1")
T.check(not on(M.C_ND_FO), "the F/O's ND not shown")
inp.inbd[1] = M.INBD_EICAS
run()
T.equal(out.shown_on[M.C_SEC], M.U_CAPT_IN, "both INBD EICAS: the Captain's unit")
T.check(not on(M.C_ND_FO) and not on(M.C_ND_CAPT), "no NDs")

-- unit power: no APU standby bus, no Captain's PFD and ND (FCOM p.800)
fresh()
inp.unit_power[M.U_CAPT_OUT], inp.unit_power[M.U_CAPT_IN] = false, false
run()
T.check(not on(M.C_PFD_CAPT) and not on(M.C_ND_CAPT), "the Captain's units unpowered: PFD and ND off")
T.check(on(M.C_PFD_FO) and on(M.C_PRI), "the rest on")

-- the EIUs (FCOM p.1044, p.1529)
fresh()
inp.eiu_fail[M.EIU_L] = true
run()
T.equal(out.eiu[1], M.EIU_C, "Captain AUTO without L: C")
T.equal(out.eiu[3], M.EIU_C, "EICAS AUTO without L: C")
T.check(on(M.C_PFD_CAPT), "the Captain's PFD on (EIU C)")
T.equal(out.msg_eiu_left, true, ">EIU LEFT on the ground")
inp.on_ground = false
run()
T.equal(out.msg_eiu_left, false, ">EIU LEFT inhibited in flight (FCOM p.1199)")
inp.eiu_sel[1] = M.EIU_L
run()
T.equal(out.eiu[1], 0, "the Captain's selector at L, L failed: no switching")
T.check(not on(M.C_PFD_CAPT) and not on(M.C_ND_CAPT), "the Captain's PFD and ND off")
T.check(on(M.C_PFD_FO), "the F/O's on")
inp.eiu_sel[1] = M.SEL_AUTO
inp.eiu_fail[M.EIU_R] = true
run()
T.equal(out.eiu[2], M.EIU_C, "F/O AUTO without R: C")
inp.eiu_fail[M.EIU_C] = true
run()
T.equal(out.eiu[2], 0, "no EIU for the F/O")
T.check(not on(M.C_PFD_FO) and not on(M.C_ND_FO), "the F/O's PFD and ND off")
T.check(not on(M.C_PRI) and not on(M.C_SEC), "no EIU for EICAS: EICAS off")
fresh()
inp.eiu_sel[3] = M.EIU_C
inp.eiu_power[M.EIU_C] = false
run()
T.equal(out.eiu[3], 0, "EICAS at C, C unpowered: no switching")
T.check(not on(M.C_PRI), "EICAS off")

-- standby power: a failed left EIU takes all the displays (FCOM p.1529)
fresh()
inp.standby_power = true
run()
T.check(on(M.C_PFD_CAPT), "standby power, the left EIU working: displays on")
inp.eiu_fail[M.EIU_L] = true
run()
for c = 1, 6 do T.check(not on(c), "standby power, left EIU failed: display " .. c .. " off") end

-- the source selections both pilots share (FCOM p.1197; step 2)
fresh()
T.equal(out.msg_source_sel_eiu or out.msg_source_sel_fd or out.msg_source_sel_nav, false,
    "normal selections: no >SOURCE SEL")
inp.eiu_sel[2] = M.EIU_L
run()
T.equal(out.msg_source_sel_eiu, true, "both on EIU L: >SOURCE SEL EIU")
inp.eiu_sel[2] = M.SEL_AUTO
inp.fd[2] = 1
run()
T.equal(out.msg_source_sel_eiu, false, "EIUs apart again")
T.equal(out.msg_source_sel_fd, true, "both on FCC L: >SOURCE SEL F/D")
inp.fd[2] = 3
inp.fmc[1] = 2
run()
T.equal(out.msg_source_sel_nav, true, "both on FMC R: >SOURCE SEL NAV")
inp.fmc[1], inp.fmc[2] = 0, 0
run()
T.equal(out.msg_source_sel_nav, false, "both on CDUs: not on an FMC")

-- the EFIS and EICAS control panels (FCOM p.1198-1199)
fresh()
inp.efis_fail[1] = true
run()
T.equal(out.msg_efis_control[1], true, "left EFIS control panel failed: >EFIS CONTROL L")
T.equal(out.msg_efis_control[2], false, "not R")
inp.efis_power[2] = false
run()
T.equal(out.msg_efis_control[2], true, "right panel unpowered: >EFIS CONTROL R")
inp.dsp_fail = true
run()
T.equal(out.msg_efis_eicas_cp, true, "both EFIS panels and the display select panel: >EFIS/EICAS C/P")
T.equal(out.msg_efis_control[1] or out.msg_efis_control[2], false, "standing for the two (estimate)")

T.done()
