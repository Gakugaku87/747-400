-- Run from the repository root with LuaJIT: luajit tests/nav/compare_module_test.lua
-- The instrument comparisons in the navigation sensors module (B747.34.xt.nav,
-- 5-2 step 2) as XTLua runs it (tests/lib/xtlua.lua): >ATTITUDE and >HEADING
-- from what the PFDs show (X-Plane's pilot and copilot AHRS) in the IRS glue,
-- >SNGL SOURCE RA in the radio altimeter glue (FCOM p.1197-1198).
local T = dofile("tests/lib/check.lua")("compare_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local I = "sim/cockpit2/gauges/indicators/"
local ADV, CAU = "laminar/B747/CAS/advisory_status", "laminar/B747/CAS/caution_status"
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
for _, b in ipairs({"stby_main", "xfr_capt", "xfr_fo", "hot_bat_apu", "gnd_svc"}) do
    rt:set("laminar/B747/electrical/bus/" .. b, 1)
end
for i = 0, 2 do rt:set("laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", i, 2) end
rt:set("laminar/B747/flt_inst/irs_src/capt/sel_dial_pos", 0)
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)
rt:set("laminar/B747/flt_inst/eiu_src/capt/sel_dial_pos", 1)      -- AUTO
rt:set("laminar/B747/flt_inst/eiu_src/fo/sel_dial_pos", 2)        -- AUTO
rt:set("laminar/B747/gear/air_ground/pri_air", 1)
for _, s in ipairs({"pilot", "copilot"}) do
    rt:set(I .. "pitch_AHARS_deg_" .. s, 2)
    rt:set(I .. "roll_AHARS_deg_" .. s, -5)
    rt:set(I .. "heading_AHARS_deg_mag_" .. s, 358)
    rt:set(I .. "radio_altimeter_height_ft_" .. s, 1500)
end
rt:callout("flight_start")
rt:command("laminar/B747/irs/align_now")
frames(4)
T.equal(rt:get("laminar/B747/irs/att_valid", 0), 1, "the IRUs aligned")
T.equal(rt:get(CAU, 3), 0, "the PFDs agree: no >ATTITUDE")
T.equal(rt:get(ADV, 185), 0, "no >HEADING")
T.equal(rt:get(ADV, 266), 0, "each PFD on its own radio altimeter: no >SNGL SOURCE RA")

-- >ATTITUDE: 3 deg (FCOM p.1197)
rt:set(I .. "pitch_AHARS_deg_copilot", 4.9)
frames(0.2)
T.equal(rt:get(CAU, 3), 0, "2.9 deg: no >ATTITUDE")
rt:set(I .. "pitch_AHARS_deg_copilot", 5.1)
frames(0.2)
T.equal(rt:get(CAU, 3), 1, "3.1 deg of pitch: >ATTITUDE")
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 0)
frames(0.2)
T.equal(rt:get(CAU, 3), 0, "both on IRU L: one attitude, no >ATTITUDE")
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)
rt:set(I .. "pitch_AHARS_deg_copilot", 2)
rt:set(I .. "roll_AHARS_deg_copilot", -1.5)
frames(0.2)
T.equal(rt:get(CAU, 3), 1, "3.5 deg of roll: >ATTITUDE")
rt:set(I .. "roll_AHARS_deg_copilot", -5)
frames(0.2)
T.equal(rt:get(CAU, 3), 0, "agree again")

-- >HEADING: 4 deg, across north (FCOM p.1198)
rt:set(I .. "heading_AHARS_deg_mag_copilot", 1.5)
frames(0.2)
T.equal(rt:get(ADV, 185), 0, "358 and 1.5: 3.5 deg, no >HEADING")
rt:set(I .. "heading_AHARS_deg_mag_copilot", 2.5)
frames(0.2)
T.equal(rt:get(ADV, 185), 1, "358 and 2.5: 4.5 deg, >HEADING")
rt:set(I .. "heading_AHARS_deg_mag_copilot", 358)
frames(0.2)
T.equal(rt:get(ADV, 185), 0, "agree again")

-- >SNGL SOURCE RA: the F/O's radio altimeter fails, both PFDs take another (FCOM p.1197)
rt:set("laminar/B747/ra/fail", 2, 1)                               -- RA R
rt:set("laminar/B747/ra/fail", 1, 1)                               -- RA C
frames(0.5)
T.equal(rt:get(ADV, 266), 1, "R and C failed: both PFDs on RA L, >SNGL SOURCE RA")
rt:set("laminar/B747/ra/fail", 2, 0)
rt:set("laminar/B747/ra/fail", 1, 0)
frames(0.5)
T.equal(rt:get(ADV, 266), 0, "apart again")

T.done()
