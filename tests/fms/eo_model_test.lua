-- Run from the repository root with LuaJIT: luajit tests/fms/eo_model_test.lua
-- The FMC's engine-out mode (plugins/xtlua_keysystems/scripts/
-- B747.68.xt.fms/B747.68.eo_model.lua; 6-1/6-2 step 9h4a, notes/
-- ATA-34-61-FMC.md §81): ENG OUT> a modification with the engine-out data,
-- EXEC active, ALL ENG> back (FCOM p.1266, p.1341-1342, p.1350-1353;
-- FMSPG p.3.3-6, p.3.4-5); the engines the data are for (one if none
-- sensed, two at most, a second failure while active).
local T = dofile("tests/lib/check.lua")("eo_model")
local E = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.eo_model.lua")

local s = E.new()
T.check(not E.shown(s) and not s.active and s.mod == nil, "all engines: no engine-out data")
T.check(not E.all_eng(s), "ALL ENG> with all engines: nothing")
T.check(E.eng_out(s, 0), "ENG OUT> with all engines running: a modification")
T.check(s.mod == "ENG OUT" and E.shown(s) and not s.active, "the modification shows the engine-out data, not active")
T.equal(E.engines(s), 1, "all running: the data for one engine out (FMSPG p.3.3-6)")
T.check(E.erase(s) and s.mod == nil and not E.shown(s), "ERASE: dropped")
E.eng_out(s, 1)
s.crz = "EO"
local kept = s.crz
local done, kind = E.exec(s)
T.check(done and kind == "ENG OUT" and s.active and s.mod == nil, "EXEC: active")
T.check(E.shown(s), "active: the engine-out data")
T.equal(s.crz, kept, "a speed chosen on the MOD page: kept by EXEC")
T.check(E.all_eng(s) and E.exec(s) and E.eng_out(s, 1), "ALL ENG, EXEC, and ENG OUT> again")
T.equal(s.crz, "LRC", "a new ENG OUT modification: the cruise's speed E/O LRC (FCOM p.1350)")
T.equal(s.clb, nil, "the climb's the E/O climb speed")
E.exec(s)
T.check(not E.eng_out(s, 1), "ENG OUT> while active: nothing")
E.update(s, 2)
T.equal(s.n, 2, "a second engine failing: the data for two (FCOM p.1350: 2E/O)")
E.update(s, 3)
T.equal(s.n, 2, "three: still two (the tables)")
T.check(E.all_eng(s) and s.mod == "ALL ENG" and not E.shown(s), "ALL ENG>: a modification back, all-engine data")
T.check(E.eng_out(s, 2) and s.mod == nil and E.shown(s), "ENG OUT> on it: the modification dropped, engine out again")
E.all_eng(s)
done, kind = E.exec(s)
T.check(done and kind == "ALL ENG" and not s.active and not E.shown(s), "EXEC: all engines")
T.check(not E.exec(s), "EXEC with nothing: nothing")
-- ALL ENG> on an ENG OUT modification not executed: dropped
E.eng_out(s, 0)
T.check(E.all_eng(s) and s.mod == nil and not s.active, "ALL ENG> on the ENG OUT modification: dropped")
-- the modification's count follows the sensed engines
E.eng_out(s, 1)
E.update(s, 2)
T.equal(E.engines(s), 2, "the modification: two once two are sensed")
T.done()
