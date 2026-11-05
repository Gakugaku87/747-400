-- Run from the repository root with LuaJIT: luajit tests/fms/fms_setdata_test.lua
-- (2026-11-05 review) the FMC's data store (fmsModules:setData and
-- setFMSData, B747.68.xt.fms.lua) as XTLua runs it, its data an XTLua
-- namespace: a name the data lacks is refused (before, reading it
-- overflowed the namespace's stack: a Lua error that stops every module of
-- the plugin), a value longer than its field is cut to the field (before,
-- to 3 characters), fields shorter than 3 still take 3 as before
local T = dofile("tests/lib/check.lua")("fms_setdata")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new{}
local m = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"std_pax_weight":120.0},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:callout("flight_start")
local ns = m.ns
local data = ns.fmsModules["data"]
local vals = rawget(data, "values")
T.check(vals ~= nil, "the FMS data is a namespace (its values table)")

T.check(pcall(ns.setFMSData, "noSuchField", "ABC"), "a name the data lacks: no Lua error (before, the plugin stopped)")
T.equal(vals.noSuchField, nil, "... and nothing added")
T.check(pcall(ns.setFMSData, "noSuchField", ""), "clearing a name the data lacks: no Lua error")
T.check(pcall(ns.setFMSData, "fltno", nil), "no value: no Lua error")
T.equal(vals.fltno, string.rep("-", 8), "... the field kept")

ns.setFMSData("fltno", "ABC1234567")
T.equal(vals.fltno, "ABC12345", "10 characters into the 8-wide FLT NO: cut to 8 (before, ABC and 5 spaces)")
ns.setFMSData("fltno", "XY12")
T.equal(vals.fltno, "XY12    ", "a shorter value: padded to the field, as before")
ns.setFMSData("fltno", "")
T.equal(vals.fltno, string.rep("-", 8), "cleared: its default, as before")
ns.setFMSData("acarsREQSPEED", "250")
T.equal(vals.acarsREQSPEED, "250 ", "the 2-wide ACARS speed still takes 3 characters and grows, as before")

-- a field added at run time, without a default, cleared: emptied, not
-- removed (before, nil: the next read of it stopped the plugin)
data.runtimeField = "XYZ"
ns.setFMSData("runtimeField", "")
T.equal(vals.runtimeField, "", "a field without a default cleared: empty")
T.check(pcall(function() return data.runtimeField end), "... and reading it again: no Lua error")
T.done()
