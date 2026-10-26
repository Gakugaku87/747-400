-- Run from the repository root with LuaJIT: luajit tests/fms/cdu_model_test.lua
-- The CDUs' scratchpads, keys and messages and the data entry forms (6-1/
-- 6-2 step 2; FCOM p.1212-1213, p.1269-1270, p.1429-1430; FMSPG p.39-43):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.cdu_model.lua.
local T = dofile("tests/lib/check.lua")("cdu_model")
local C = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.cdu_model.lua")

local fmc = C.fmc_new()
local left, right = C.new(), C.new()
local function keys(cdu, s)
    for k in s:gmatch("%S+") do C.key(cdu, fmc, k, 0) end
end

-- typing, CLR, the length
keys(left, "F L 3 5 0")
T.equal(left.sp, "FL350", "typed in from the left")
T.equal(right.sp, "", "the other CDU's scratchpad its own")
C.key(left, fmc, "CLR", 0)
T.equal(left.sp, "FL35", "CLR: the last character")
C.key(left, fmc, "CLR", 1, 0.5)
T.equal(left.sp, "FL35", "CLR held half a second: no more")
C.key(left, fmc, "CLR", 1, 1.0)
T.equal(left.sp, "", "CLR held a second: the whole scratchpad")
for _ = 1, 30 do C.key(left, fmc, "9", 0) end
T.equal(#left.sp, 24, "24 characters at most")
C.key(left, fmc, "CLR", 0)
C.key(left, fmc, "CLR", 1, 1.2)
T.equal(left.sp, "", "cleared")
keys(left, "1 2 . 5 / SP A")
T.equal(left.sp, "12.5/ A", "the point, the slash and SP")
C.key(left, fmc, "CLR", 0)
C.key(left, fmc, "CLR", 1, 1.5)
C.key(left, fmc, "CLR", 2)
T.equal(left.sp, "", "CLR pushed and held: cleared")

-- +/-
keys(left, "1 2")
C.key(left, fmc, "+/-", 0)
T.equal(left.sp, "12-", "+/- the first push: -")
C.key(left, fmc, "+/-", 0)
T.equal(left.sp, "12+", "again: +")
C.key(left, fmc, "+/-", 0)
T.equal(left.sp, "12-", "and again: -")
C.key(left, fmc, "3", 0)
C.key(left, fmc, "+/-", 0)
T.equal(left.sp, "12-3-", "after another key: a new -")
C.key(left, fmc, "CLR", 1, 1.0)

-- DEL
C.key(left, fmc, "DEL", 0)
T.equal(left.sp, "DELETE", "DEL in an empty scratchpad: DELETE")
C.key(left, fmc, "A", 0)
T.equal(left.sp, "DELETE", "no typing onto DELETE")
C.key(left, fmc, "CLR", 0)
T.equal(left.sp, "", "CLR takes DELETE back")
keys(left, "A B")
C.key(left, fmc, "DEL", 0)
T.equal(left.sp, "AB", "DEL with data: nothing")
local e, del = C.entry(left)
T.check(e == "AB" and not del, "the entry: the scratchpad")
C.accept(left)
T.equal(left.sp, "", "accepted: the scratchpad empties")
C.key(left, fmc, "DEL", 0)
e, del = C.entry(left)
T.check(e == "DELETE" and del, "the entry: DELETE")
C.accept(left)
T.check(C.entry(left) == nil, "an empty scratchpad: no entry")
T.check(not C.copy(left, "****") and not C.copy(left, "---/---") and left.sp == "", "boxes and dashes not copied")
T.check(C.copy(left, "FL350") and left.sp == "FL350", "a value copied into the empty scratchpad")
T.check(not C.copy(left, "250"), "no copy onto data")
C.key(left, fmc, "CLR", 1, 1.0)

-- the keys of the page
T.check(not C.key(left, fmc, "L1", 0) and not C.key(left, fmc, "EXEC", 0) and not C.key(left, fmc, "NEXT", 0),
    "line select, EXEC and NEXT: the page's")
T.check(C.key(left, fmc, "A", 2) and left.sp == "", "a key's release: nothing")

-- entry messages: this CDU's only, before the FMC's
keys(left, "X Y")
C.error(left, C.INVALID_ENTRY)
T.equal(C.line(left, fmc), "INVALID ENTRY", "the entry message over the scratchpad")
T.equal(C.line(right, fmc), "", "not on the other CDU")
T.check(C.msg_light(left, fmc) and not C.msg_light(right, fmc), "MSG on the CDU with the message")
C.key(left, fmc, "Z", 0)
T.equal(left.sp, "XY", "no typing while a message shows")
C.key(left, fmc, "CLR", 0)
T.equal(C.line(left, fmc), "XY", "CLR: the message goes, the scratchpad back")
C.key(left, fmc, "CLR", 1, 1.0)

-- the FMC's messages: on every CDU, a CLR on any clears them from all
C.fmc_set(fmc, "RESET MCP ALT", true, true)
T.check(C.line(left, fmc) == "RESET MCP ALT" and C.line(right, fmc) == "RESET MCP ALT", "an FMC alert on both CDUs")
T.check(C.fmc_alert(fmc), ">FMC MESSAGE with an alert")
C.fmc_post(fmc, "TAKEOFF SPEEDS DELETED", false)
T.equal(C.line(left, fmc), "RESET MCP ALT", "alerts before advisories")
C.key(right, fmc, "CLR", 0)
T.check(C.line(left, fmc) == "TAKEOFF SPEEDS DELETED" and C.line(right, fmc) == "TAKEOFF SPEEDS DELETED",
    "CLR on the right CDU: the alert gone from both, the advisory next")
T.check(not C.fmc_alert(fmc), "no >FMC MESSAGE once the alert is cleared")
C.fmc_set(fmc, "RESET MCP ALT", true, true)
T.equal(C.line(left, fmc), "TAKEOFF SPEEDS DELETED", "the condition still on: not again")
C.key(left, fmc, "CLR", 0)
T.equal(C.line(left, fmc), "", "the advisory cleared")
C.fmc_set(fmc, "RESET MCP ALT", false, true)
C.fmc_set(fmc, "RESET MCP ALT", true, true)
T.equal(C.line(left, fmc), "RESET MCP ALT", "the condition again: the message again")
C.fmc_set(fmc, "RESET MCP ALT", false, true)
T.equal(C.line(left, fmc), "", "the condition cleared: the message gone")
C.fmc_set(fmc, "UNABLE NEXT ALT", true, true)
C.error(right, C.INVALID_DELETE)
T.check(C.line(right, fmc) == "INVALID DELETE" and C.line(left, fmc) == "UNABLE NEXT ALT", "the entry message first on its CDU")
C.key(right, fmc, "CLR", 0)
T.equal(C.line(right, fmc), "UNABLE NEXT ALT", "then the FMC's")
C.fmc_set(fmc, "UNABLE NEXT ALT", false, true)

-- altitudes (FCOM p.1269-1270)
local alts = {["008"] = 800, FL008 = 800, ["015"] = 1500, ["115"] = 11500, FL250 = 25000, ["0050"] = 50,
    ["0835"] = 840, ["9994"] = 9990, ["00835"] = 840, ["09995"] = 10000, ["25000"] = 25000, ["-0500"] = -500, ["-010"] = -1000}
for s, ft in pairs(alts) do T.equal(C.parse_alt(s), ft, "altitude " .. s) end
for _, s in ipairs({"9995", "35", "FL35", "350000", "-1010", "-FL010", "ABC", ""}) do
    T.equal(C.parse_alt(s), nil, "not an altitude: " .. s)
end
T.equal(C.format_alt(800, 10000), "800", "800 ft below the transition altitude")
T.equal(C.format_alt(11500, 10000), "FL115", "11,500 ft above it: FL115")
T.equal(C.format_alt(8500, 4000), "FL085", "8,500 ft above 4,000: FL085")
T.equal(C.format_alt(10000, 4000), "FL100", "9,995 ft rounded: FL100")
T.equal(C.format_alt(18000, 18000), "18000", "at the transition altitude: feet")

-- speeds and pairs
local cas, mach = C.parse_speed("250")
T.check(cas == 250 and mach == nil, "CAS 250")
cas, mach = C.parse_speed(".84")
T.check(cas == nil and mach == 0.84, "Mach .84")
T.check(select(2, C.parse_speed(".8")) == 0.8 and select(2, C.parse_speed("0.845")) == 0.845, "Mach .8 and 0.845")
T.check(C.parse_speed("25") == nil and select(2, C.parse_speed(".8456")) == nil, "not speeds: 25, .8456")
local a, b = C.pair("240/8000", "L")
T.check(a == "240" and b == "8000", "a pair at a left key: outboard first")
a, b = C.pair("240/8000", "R")
T.check(a == "8000" and b == "240", "at a right key: outboard last")
a, b = C.pair("240", "L")
T.check(a == "240" and b == "", "the outboard value alone, no slash needed")
a, b = C.pair("/8000", "L")
T.check(a == "" and b == "8000", "the inboard value with its slash")
a, b = C.pair("240/", "L")
T.check(a == "240" and b == "", "the outboard value with a trailing slash")
T.check(C.pair("1/2/3", "L") == nil and C.pair("", "L") == nil, "not pairs")

-- weights and whole numbers
T.check(C.parse_weight("330") == 330 and C.parse_weight("330.5") == 330.5 and C.parse_weight("330.55") == nil
    and C.parse_weight("3300") == nil, "weights XXX and XXX.X")
T.check(C.parse_int("120", 0, 9999) == 120 and C.parse_int("10000", 0, 9999) == nil and C.parse_int("1.5") == nil,
    "whole numbers in a range")

T.done()
