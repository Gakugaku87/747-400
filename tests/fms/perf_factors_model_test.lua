-- Run from the repository root with LuaJIT: luajit tests/fms/perf_factors_model_test.lua
-- PERF FACTORS (6-1/6-2 step 12c1; notes/ATA-34-61-FMC.md §109; FMSPG
-- p.265-268; ATA34_2 p.678-679, p.681): the values without entries, the
-- entries' forms and ranges, the page's text.
local T = dofile("tests/lib/check.lua")("perf_factors_model")
local F = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_factors_model.lua")

-- without entries: ATA34_2 p.681's airplane, the engine type's derates
local v = F.values(nil, 0)
local t = F.text(v)
T.equal(t.dragff, "+0.0/+0.0", "DRAG/F-F +0.0/+0.0")
T.equal(t.derates, "-8/-20", "PW: TO 1/TO 2 -8/-20 (FCOM p.1314)")
T.equal(t.mnvr, "1.30", "MNVR MARGIN 1.30 (p.681; FCOM p.969: 1.3 g)")
T.equal(t.mincrz, "5", "MIN CRZ TIME 5")
T.equal(t.rc_clb, "300", "R/C CLB 300")
T.equal(t.thrcrz, "CLB/100", "THR/CRZ CLB/100 (FMSPG p.266-268; the user, 2026-11-02)")
T.equal(t.thrred, "FLAPS 5", "THR RED FLAPS 5 (FCOM p.1317's TAKEOFF REF)")
T.equal(t.accel, "1000/1000", "ACCEL HT 1000/1000")
T.equal(F.text(F.values(nil, 1)).derates, "-5/-15", "GE: -5/-15 (the 570's FCOM)")
T.equal(F.text(F.values(nil, 2)).derates, "-8/-20", "RR: the 109's")

-- stored values over the defaults; a stored value of the wrong type ignored
v = F.values({drag = 1.5, ff = -2, to2 = 25, mnvr = 1.25, thr_crz = "CRZ", thr_red = 1500, accel = "x"}, 1)
t = F.text(v)
T.equal(t.dragff, "+1.5/-2.0", "stored DRAG/F-F")
T.equal(t.derates, "-5/-25", "stored TO 2, TO 1 the engine's")
T.equal(t.mnvr, "1.25", "stored MNVR MARGIN")
T.equal(t.thrcrz, "CRZ/100", "stored THR CRZ, R/C CRZ the default")
T.equal(t.thrred, "1500", "stored THR RED 1500")
T.equal(t.accel, "1000/1000", "a string ACCEL HT ignored")

local function ok(field, text, want, label)
    local new, err = F.enter(field, text)
    T.check(new ~= nil, label .. ": taken")
    if not new then return end
    for k, x in pairs(want) do
        if type(x) == "number" then T.near(new[k], x, 1e-9, label .. ": " .. k) else T.equal(new[k], x, label .. ": " .. k) end
    end
    local n = 0
    for _ in pairs(new) do n = n + 1 end
    local m = 0
    for _ in pairs(want) do m = m + 1 end
    T.equal(n, m, label .. ": only those")
end
local function bad(field, text, label)
    local new, err = F.enter(field, text)
    T.check(new == nil and err == "INVALID ENTRY", label .. ": INVALID ENTRY")
end

-- DRAG/F-F: within 9.9; the fuel flow's alone after a slash
ok("dragff", "1.5/-2.0", {drag = 1.5, ff = -2.0}, "1.5/-2.0")
ok("dragff", "+1.5", {drag = 1.5}, "+1.5 (the drag's)")
ok("dragff", "-0.5/", {drag = -0.5}, "-0.5/ (the drag's, slash)")
ok("dragff", "/2", {ff = 2}, "/2 (the fuel flow's)")
ok("dragff", "9.9/-9.9", {drag = 9.9, ff = -9.9}, "9.9/-9.9")
ok("dragff", ".5", {drag = 0.5}, ".5")
bad("dragff", "10/", "10 (above 9.9)")
bad("dragff", "1.25", "1.25 (two decimals)")
bad("dragff", "/", "a slash alone")
bad("dragff", "A", "A")
bad("dragff", "1/2/3", "1/2/3")
T.equal(F.text(F.values({drag = -0.0, ff = 0}, 0)).dragff, "+0.0/+0.0", "-0.0 shown +0.0")

-- TO 1/TO 2: whole % 0 to 30
ok("derates", "10/20", {to1 = 10, to2 = 20}, "10/20")
ok("derates", "-5/-15", {to1 = 5, to2 = 15}, "-5/-15")
ok("derates", "12", {to1 = 12}, "12 (TO 1's)")
ok("derates", "/25", {to2 = 25}, "/25 (TO 2's)")
ok("derates", "0/30", {to1 = 0, to2 = 30}, "0/30")
bad("derates", "31", "31")
bad("derates", "5.5", "5.5")
bad("derates", "/", "a slash alone")
T.equal(F.text(F.values({to1 = 0}, 0)).derates, "0/-20", "0 % shown 0")

-- MNVR MARGIN 1.20 to 1.30
ok("mnvr", "1.25", {mnvr = 1.25}, "1.25")
ok("mnvr", "1.2", {mnvr = 1.20}, "1.2")
ok("mnvr", "1.30", {mnvr = 1.30}, "1.30")
bad("mnvr", "1.31", "1.31")
bad("mnvr", "1.19", "1.19")
bad("mnvr", "1", "1")

-- MIN CRZ TIME 1 to 20; R/C CLB 0 to 500
ok("mincrz", "20", {mincrz = 20}, "MIN CRZ 20")
bad("mincrz", "0", "MIN CRZ 0")
bad("mincrz", "21", "MIN CRZ 21")
ok("rc_clb", "0", {rc_clb = 0}, "R/C CLB 0")
ok("rc_clb", "500", {rc_clb = 500}, "R/C CLB 500")
bad("rc_clb", "501", "R/C CLB 501")
bad("rc_clb", "1000", "R/C CLB 1000 (four digits)")

-- THR/CRZ: each half alone
ok("thrcrz", "CLB/", {thr_crz = "CLB"}, "CLB/")
ok("thrcrz", "CRZ", {thr_crz = "CRZ"}, "CRZ")
ok("thrcrz", "/200", {rc_crz = 200}, "/200")
ok("thrcrz", "CLB/0", {thr_crz = "CLB", rc_crz = 0}, "CLB/0")
bad("thrcrz", "CON/", "CON/")
bad("thrcrz", "/600", "/600")

-- THR RED: 5 or 400 to 9999
ok("thrred", "5", {thr_red = 5}, "5")
ok("thrred", "400", {thr_red = 400}, "400")
ok("thrred", "9999", {thr_red = 9999}, "9999")
bad("thrred", "399", "399")
bad("thrred", "1", "1")
bad("thrred", "10000", "10000")

-- ACCEL HT: the engine-out's and the all-engine's together
ok("accel", "800/1500", {eo_accel = 800, accel = 1500}, "800/1500")
bad("accel", "1500", "1500 alone")
bad("accel", "/1500", "/1500")
bad("accel", "399/1500", "399/1500")
T.equal(F.text(F.values({eo_accel = 800, accel = 1500}, 0)).accel, "800/1500", "the engine-out's inner (FMSPG p.268)")

bad("nothing", "1", "an unknown field")
T.done()
