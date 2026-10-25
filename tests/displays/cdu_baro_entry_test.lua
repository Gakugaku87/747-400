-- Run from the repository root with LuaJIT: luajit tests/displays/cdu_baro_entry_test.lua
-- The CDU's EFIS CONTROL page BARO SET entry (plugins/xtlua_keysystems/
-- scripts/B747.68.xt.fms/B744.fms.baro.lua, 5-2 step 4b) without X-Plane:
-- S or STD, I or H for the units, 22.00 to 32.00 or 2200 to 3200 in inches
-- of mercury, 745 to 1084 in hectopascals (FCOM p.1064 (10.10.102)).
local T = dofile("tests/lib/check.lua")("cdu_baro_entry")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B744.fms.baro.lua")
local E = B744_cdu_baro_entry

T.equal(E("S"), "std", "S: STD")
T.equal(E("STD"), "std", "STD: STD")
local k, v, h = E("I")
T.check(k == "units" and h == false, "I: inches of mercury")
k, v, h = E("H")
T.check(k == "units" and h == true, "H: hectopascals")
k, v, h = E("29.92")
T.check(k == "set" and math.abs(v - 29.92) < 1e-9 and h == false, "29.92: inches")
k, v, h = E("2992")
T.check(k == "set" and math.abs(v - 29.92) < 1e-9 and h == false, "2992: 29.92 inches")
k, v, h = E("1013")
T.check(k == "set" and math.abs(v - 1013 / 33.863892) < 1e-9 and h == true, "1013: hectopascals")
k, v, h = E("745")
T.check(k == "set" and h == true, "745: the lowest hectopascals")
k, v, h = E("1084")
T.check(k == "set" and h == true, "1084: the highest hectopascals")
k, v, h = E("30")
T.check(k == "set" and v == 30 and h == false, "30: 30.00 inches")
T.equal(E("32.01"), nil, "32.01: invalid")
T.equal(E("21.99"), nil, "21.99: invalid")
T.equal(E("1085"), nil, "1085: invalid")
T.equal(E("744"), nil, "744: invalid")
T.equal(E("3201"), nil, "3201: invalid")
T.equal(E("1013.2"), nil, "1013.2: invalid (a decimal point only for inches)")
T.equal(E("ABC"), nil, "letters: invalid")
T.equal(E(""), nil, "empty: invalid")

T.done()
