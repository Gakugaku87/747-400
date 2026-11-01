-- Run from the repository root with LuaJIT: luajit tests/fms/fmc_link_model_test.lua
-- The two FMCs and the CDUs' connection to them (6-1/6-2 step 11d1;
-- notes/ATA-34-61-FMC.md §98; FCOM p.1275, p.1422, p.1429, p.1434; ATA34_2
-- p.456, p.629): an FMC's failure or power loss drops the CDUs connected
-- to it (TIMEOUT - RESELECT), in flight the master FMC's every CDU; <FMC
-- connects again (on the ground to an operative FMC, in flight to the
-- master while it works); the NAV source selector turned to an operative
-- FMC connects; a CDU without power reconnects by itself; SINGLE FMC
-- OPERATION while one works; FMC LEFT, RIGHT after the delay.
local T = dofile("tests/lib/check.lua")("fmc_link_model")
local M = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.fmc_link_model.lua")
local L, R = M.L, M.R

local function inp(t)
    local i = {power = {true, true}, fail = {false, false}, src = {fmsL = L, fmsR = R},
        cdu_power = {fmsL = true, fmsC = true, fmsR = true}, master = L, ground = true}
    for k, v in pairs(t or {}) do i[k] = v end
    return i
end
local function lost(out)
    local t = {}
    for _, cdu in ipairs(M.CDUS) do if out.lost[cdu] then t[#t + 1] = cdu end end
    return table.concat(t, ",")
end
local function links(s)
    return string.format("%s,%s,%s", s.link.fmsL or "-", s.link.fmsC or "-", s.link.fmsR or "-")
end

-- normal: the left and centre CDUs on the left FMC, the right on the right
local s = M.new()
local i = inp()
local out = M.update(s, i, 0.1)
T.equal(links(s), "1,1,2", "normal: left and centre CDUs on the left FMC, right on the right (ATA34_2 p.456)")
T.equal(lost(out), "", "normal: nothing lost")
T.check(out.ok[L] and out.ok[R], "normal: both FMCs work")
T.check(not out.single, "normal: no SINGLE FMC OPERATION")
T.check(M.linked(s, "fmsL") and M.linked(s, "fmsR"), "normal: the CDUs connected")

-- on the ground the left FMC fails: its CDUs lost, the right one stays
i.fail[L] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsL,fmsC", "left FMC fails: the left and centre CDUs lose it (FCOM p.1275)")
T.equal(links(s), "-,-,2", "left FMC fails: the right CDU stays on the right FMC")
T.check(not out.ok[L] and out.ok[R], "left FMC fails: fmc_ok L 0, R 1")
T.check(out.single, "left FMC fails: SINGLE FMC OPERATION (FCOM p.1434)")
T.check(not out.eicas[L], "left FMC fails: no FMC LEFT yet (the delay: FCOM p.1275)")
out = M.update(s, i, 0.1)
T.equal(lost(out), "", "lost once: the next frame nothing")
for _ = 1, 47 do out = M.update(s, i, 0.1) end
T.check(not out.eicas[L], "4.9 s: no FMC LEFT")
out = M.update(s, i, 0.1)
out = M.update(s, i, 0.1)
T.check(out.eicas[L] and not out.eicas[R], "5.1 s: FMC LEFT on the EICAS (p.1429)")
T.equal(M.available(s, "fmsL", i), R, "the ground: <FMC offers the right FMC")
T.check(not M.linked(s, "fmsL"), "not connected before <FMC")

-- <FMC on the ground: to the operative FMC
T.equal(M.connect(s, "fmsL", i), R, "<FMC on the left CDU: the right FMC")
T.equal(M.connect(s, "fmsC", i), R, "<FMC on the centre CDU: the right FMC")
out = M.update(s, i, 0.1)
T.equal(links(s), "2,2,2", "all three on the right FMC")
T.equal(lost(out), "", "connected: nothing lost")
T.equal(M.connect(s, "fmsL", i), R, "<FMC connected: stays")

-- the left FMC back: the CDUs stay where they are, the messages go
i.fail[L] = false
out = M.update(s, i, 0.1)
T.equal(links(s), "2,2,2", "left FMC back: the CDUs stay on the right FMC")
T.check(not out.single and not out.eicas[L], "left FMC back: no SINGLE FMC OPERATION, no FMC LEFT")

-- the Captain's NAV source selector turned: that FMC (FCOM p.1422)
i.src.fmsL = nil      -- CDU L
out = M.update(s, i, 0.1)
T.equal(links(s), "1,2,2", "Captain's selector at CDU L: the left CDU on its own FMC (estimate)")
i.src.fmsL = R
out = M.update(s, i, 0.1)
T.equal(links(s), "2,2,2", "Captain's selector at FMC R: the left CDU on the right FMC")
i.src.fmsL = L
out = M.update(s, i, 0.1)
T.equal(links(s), "1,2,2", "Captain's selector at FMC L: the left CDU on the left FMC")

-- a failed FMC's selector turned to it: not connected
s = M.new()
i = inp()
M.update(s, i, 0.1)
i.fail[R] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsR", "right FMC fails: the right CDU lost")
i.src.fmsR = L
out = M.update(s, i, 0.1)
T.equal(links(s), "1,1,1", "F/O's selector at FMC L: the right CDU on the left FMC (FCOM p.1422)")
i.src.fmsL = R
out = M.update(s, i, 0.1)
T.equal(s.link.fmsL, L, "Captain's selector at the failed FMC R: stays on the left FMC")

-- in flight: the FMC not selected on the FMC master selector fails
s = M.new()
i = inp({ground = false})
M.update(s, i, 0.1)
i.fail[R] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsR", "in flight the right (not master) FMC fails: the right CDU only (FCOM p.1275)")
T.equal(links(s), "1,1,-", "in flight: the left and centre CDUs stay")
T.equal(M.available(s, "fmsR", i), L, "in flight: <FMC offers the master")
T.equal(M.connect(s, "fmsR", i), L, "in flight <FMC: the master (left) FMC")

-- in flight: the master FMC fails: every CDU (FCOM p.1275)
s = M.new()
i = inp({ground = false})
M.update(s, i, 0.1)
i.fail[L] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsL,fmsC,fmsR", "in flight the master FMC fails: TIMEOUT - RESELECT on every CDU")
T.equal(links(s), "-,-,-", "in flight the master fails: no CDU connected")
T.equal(M.available(s, "fmsR", i), nil, "the selector at the failed FMC: no <FMC")
T.equal(M.connect(s, "fmsR", i), nil, "<FMC with the selector at the failed FMC: nothing")
i.master = R
out = M.update(s, i, 0.1)
T.equal(lost(out), "", "the FMC master selector to R: nothing lost")
T.equal(M.available(s, "fmsL", i), R, "the selector at R: <FMC offers it")
T.equal(M.connect(s, "fmsL", i), R, "<FMC: the right FMC")
T.equal(M.connect(s, "fmsR", i), R, "<FMC on the right CDU: the right FMC")
out = M.update(s, i, 0.1)
T.equal(links(s), "2,-,2", "after <FMC: the left and right CDUs on the right FMC")
T.check(out.single, "in flight: SINGLE FMC OPERATION")

-- both fail: nothing to connect to, no SINGLE FMC OPERATION
s = M.new()
i = inp()
M.update(s, i, 0.1)
i.fail[L], i.fail[R] = true, true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsL,fmsC,fmsR", "both fail: every CDU lost")
T.check(not out.single, "both fail: no SINGLE FMC OPERATION")
T.equal(M.available(s, "fmsL", i), nil, "both fail: no <FMC (FCOM p.1275)")
T.equal(M.connect(s, "fmsC", i), nil, "both fail: <FMC connects nothing")

-- power: the right bus lost with the right CDU (both on the F/O's
-- transfer bus): no TIMEOUT - RESELECT, back by itself with the power
s = M.new()
i = inp()
M.update(s, i, 0.1)
i.power[R] = false
i.cdu_power.fmsR, i.cdu_power.fmsC = false, false
out = M.update(s, i, 0.1)
T.equal(lost(out), "", "F/O's transfer bus lost with the CDUs: nothing shown (estimate)")
T.equal(links(s), "1,1,-", "unpowered: the centre CDU's link kept (its FMC works), the right CDU's gone")
T.check(not out.ok[R], "unpowered right FMC: fmc_ok 0")
i.power[R] = true
i.cdu_power.fmsR, i.cdu_power.fmsC = true, true
out = M.update(s, i, 0.1)
T.equal(lost(out), "", "power back: nothing lost")
T.equal(links(s), "1,1,2", "power back: the right CDU on its FMC again by itself")
i.fail[R] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsR", "after power-up a failure shows again")

-- power-up with its FMC failed: no message, waits; <FMC connects and stays
s = M.new()
i = inp()
i.cdu_power.fmsL = false
i.fail[L] = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "fmsC", "the left CDU unpowered while its FMC fails: nothing on it (the centre CDU's shows)")
i.cdu_power.fmsL = true
out = M.update(s, i, 0.1)
T.equal(lost(out), "", "its power back: no TIMEOUT - RESELECT")
T.check(not M.linked(s, "fmsL"), "its power back, its FMC failed: not connected")
T.equal(M.connect(s, "fmsL", i), R, "<FMC: the right FMC")
out = M.update(s, i, 0.1)
T.equal(s.link.fmsL, R, "connected: kept on the right FMC")
i.fail[L] = false
out = M.update(s, i, 0.1)
T.equal(s.link.fmsL, R, "its FMC back: stays on the right FMC")

-- the centre CDU's FMC: the right one while the left fails (estimate)
s = M.new()
i = inp()
i.fail[L] = true
i.cdu_power.fmsC = false
M.update(s, i, 0.1)
i.cdu_power.fmsC = true
M.update(s, i, 0.1)
T.equal(s.link.fmsC, R, "the centre CDU's power-up with the left FMC failed: the right FMC")

T.done()
