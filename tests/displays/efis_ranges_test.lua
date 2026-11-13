-- Run from the repository root with LuaJIT: luajit tests/displays/efis_ranges_test.lua
-- (2026-11-13; the 2026-11-12 review DSP-7, 案 12) The EFIS control panel's
-- settings within the ranges of FCOM p.1064 (10.10.102: BARO minimums -1001
-- to 15000 ft, RAD -20 to 999 ft, the barometric setting 22.00 to 32.00
-- inHg): the knobs (B747.60.xt.fltInst02.lua) stop there. Before, MDA -101 to
-- 10,000 ft, DH -1 to 1,000 (the display gone at 1,000), 26.00 to 34.00 inHg.
-- The CDU's EFIS CONTROL entries: tests/displays/cdu_efis_test.lua.
local T = dofile("tests/lib/check.lua")("efis_ranges")
local xtlua = dofile("tests/lib/xtlua.lua")
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
local function frames(n) for _ = 1, n do rt:frame(1 / 30) end end
frames(10)
local EF = "laminar/B747/efis/"
local function push(cmd) rt:command(EF .. cmd, 0.2) frames(3) end

-- the minimums: BARO (MDA) and RADIO (DH)
rt:set(EF .. "min_ref_alt/capt/sel_dial_pos", 1)
rt:set(EF .. "baro_ref/capt", 14999)
push("ref_alt/capt/set_dial_up")
push("ref_alt/capt/set_dial_up")
T.equal(rt:get(EF .. "baro_ref/capt"), 15000, "MDA up from 14,999 ft: 15,000 and no more (before 10,000)")
rt:set(EF .. "baro_ref/capt", -1000)
push("ref_alt/capt/set_dial_dn")
push("ref_alt/capt/set_dial_dn")
T.equal(rt:get(EF .. "baro_ref/capt"), -1001, "MDA down from -1,000 ft: -1,001 and no less (before -101)")
rt:set(EF .. "min_ref_alt/capt/sel_dial_pos", 0)
rt:set("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot", 998)
push("ref_alt/capt/set_dial_up")
push("ref_alt/capt/set_dial_up")
T.equal(rt:get("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot"), 999, "DH up from 998 ft: 999 and no more (before 1,000)")
rt:set("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot", -19)
push("ref_alt/capt/set_dial_dn")
push("ref_alt/capt/set_dial_dn")
T.equal(rt:get("sim/cockpit2/gauges/actuators/radio_altimeter_bug_ft_pilot"), -20, "DH down from -19 ft: -20 and no less (before -1)")

-- the barometric setting
rt:set(EF .. "baro_std/capt/switch_pos", 0)
rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot", 31.99)
push("baro_set/capt/sel_dial_up")
push("baro_set/capt/sel_dial_up")
T.near(rt:get("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot"), 32.00, 1e-6, "BARO up from 31.99: 32.00 and no more (before 34.00)")
rt:set("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot", 22.01)
push("baro_set/capt/sel_dial_dn")
push("baro_set/capt/sel_dial_dn")
T.near(rt:get("sim/cockpit2/gauges/actuators/barometer_setting_in_hg_pilot"), 22.00, 1e-6, "BARO down from 22.01: 22.00 and no less (before 26.00)")
T.done()
