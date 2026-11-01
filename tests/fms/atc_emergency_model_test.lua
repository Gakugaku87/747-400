-- Run from the repository root with LuaJIT: luajit tests/fms/atc_emergency_model_test.lua
-- ATC emergency reports (6-1/6-2 step 12g4; notes/ATA-34-61-FMC.md §121;
-- FCOM p.728-733; FMSPG p.345-356): MAYDAY with DESCENDING TO and the
-- POSITION REPORT, PAN, the one or the other, DIVERT TO (the destination
-- with the route, or a position), OFFSET, DESCEND TO, SOB and the fuel,
-- CANCEL EMERGENCY, five elements at most, VERIFY EMERGENCY's rows (FCOM
-- p.731), the text sent.
local T = dofile("tests/lib/check.lua")("atc_emergency_model")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_request_model.lua")
local E = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_emergency_model.lua")

local c = {dest = "KSEA", route = "RJAA XAC ATMUG KSEA", mcp = "14000", mcp_ft = 14000, alt_ft = 33000,
    alt = "FL330", ppos = "N4730.0W12210.0", now = "1630Z", endurance = "04+25"}
local e = E.new()
T.equal(E.select(e, "mayday", c), nil, "MAYDAY")
T.equal(E.select(e, "pan", c), nil, "PAN after MAYDAY: nothing (FMSPG p.350)")
T.check(not e.pan, "not selected")
local texts = {}
for _, x in ipairs(E.elements(e, c)) do texts[#texts + 1] = x.text end
T.equal(table.concat(texts, "|"), "MAYDAY MAYDAY MAYDAY|POSITION REPORT N4730.0W12210.0 FL330 AT 1630Z|DESCENDING TO 14000FT",
    "MAYDAY, the POSITION REPORT, DESCENDING TO the MCP's (above it: FMSPG p.347-349)")
E.enter(e, "sob", "395", c)
local rows = E.verify_rows(e, c, true)
T.equal(rows[1].head .. "=" .. rows[1].data, "=MAYDAY MAYDAY MAYDAY", "line 1: MAYDAY (FCOM p.731)")
T.equal(rows[2].head .. "=" .. rows[2].data, "/DESCENDING TO=14000FT", "/DESCENDING TO 14000FT")
T.equal(rows[3].head .. "=" .. rows[3].data, "/=04+25", "/ 04+25")
T.equal(rows[4].head .. "=" .. rows[4].data, "OF FUEL REMAINING AND=395", "OF FUEL REMAINING AND 395")
T.equal(rows[5].head, "SOULS ON BOARD", "SOULS ON BOARD")
T.equal(rows[6].head .. rows[6].data, "/FREE TEXT<", "the free text on page 2 (FCOM p.732)")
T.equal(E.delete(e, "mayday"), nil, "DELETE MAYDAY")
T.equal(#E.elements(e, c), 1, "MAYDAY, its POSITION REPORT and DESCENDING TO gone (FMSPG p.348)")
T.equal(E.select(e, "pan", c), nil, "PAN now")
T.equal(E.elements(e, c)[1].text, "PAN PAN PAN", "PAN PAN PAN")
T.check(not E.elements(e, c)[2].text:find("DESCENDING", 1, true), "PAN: no DESCENDING TO by itself")
-- DIVERT TO (FMSPG p.348)
e = E.new()
E.select(e, "divert", c)
T.equal(E.text(e, c), "DIVERTING TO KSEA VIA ROUTE CLEARANCE RJAA XAC ATMUG KSEA", "the destination: with the route")
E.delete(e, "divert")
E.set_divert(e, "KPDX", c)
T.equal(E.text(e, c), "DIVERTING TO KPDX VIA ROUTE CLEARANCE", "another position: no route data")
-- OFFSET, DESCEND TO entered
T.equal(E.enter(e, "offset", "R20", c), nil, "OFFSET")
T.equal(E.enter(e, "descend", "FL250", c), nil, "DESCEND TO entered")
texts = {}
for _, x in ipairs(E.elements(e, c)) do texts[#texts + 1] = x.text end
T.equal(table.concat(texts, "|"), "DESCENDING TO FL250|DIVERTING TO KPDX VIA ROUTE CLEARANCE|OFFSETTING R20NM", "the elements")
T.equal(E.enter(e, "offset", "R100", c), E.INVALID, "an offset of 100: invalid")
T.equal(E.enter(e, "descend", "FL250/FL270", c), E.INVALID, "no block")
-- the fuel: hh+mm once SOB is in (FMSPG p.350)
T.equal(E.enter(e, "fuel", "03+00", c), E.INVALID, "no fuel entry before SOB")
E.enter(e, "sob", "400", c)
T.equal(E.enter(e, "fuel", "03+15", c), nil, "fuel remaining entered")
T.check(E.text(e, c):find("03+15 OF FUEL REMAINING AND 400 SOULS ON BOARD", 1, true), "the entered fuel")
-- five elements (FMSPG p.345)
E.select(e, "pan", c)
T.equal(#E.elements(e, c), 5, "PAN, DESCENDING, DIVERTING, OFFSETTING, the souls: five (the page's most)")
T.equal(E.select(e, "mayday", c), nil, "MAYDAY with PAN: nothing")
E.delete(e, "pan")
T.equal(E.select(e, "mayday", c), nil, "MAYDAY instead")
local shown = 0
for _, el in ipairs(E.elements(e, c)) do if not el.hidden then shown = shown + 1 end end
T.equal(shown, 5, "five shown, the POSITION REPORT not counted (estimate)")
-- CANCEL EMERGENCY (FMSPG p.349)
local x = E.new()
T.equal(E.select(x, "cancel", c, false), nil, "not in the emergency mode: nothing")
T.check(not x.cancel, "not selected")
T.equal(E.select(x, "cancel", c, true), nil, "in the emergency mode: CANCEL EMERGENCY")
T.equal(E.text(x, c), "CANCEL EMERGENCY", "CANCEL EMERGENCY")
T.check(E.any(x), "selected: ERASE EMERGENCY")
E.erase(x)
T.check(not E.any(x), "ERASE EMERGENCY")
T.done()
