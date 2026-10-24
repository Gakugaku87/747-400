-- Run from the repository root with LuaJIT: luajit tests/nav/irs_module_test.lua
-- The IRS glue (B747.34.xt.irs.lua, 5-1 step 2) in the navigation sensors
-- module (B747.34.xt.nav) as XTLua runs it (tests/lib/xtlua.lua): the mode
-- selectors, the buses, the PSEU, X-Plane's position and failures, the FMC's
-- entries and the IRS source selectors in; the IRU modes (iru/status),
-- laminar/B747/irs/..., the PFDs' IRS validity, the EICAS messages, the FMC's
-- messages and ON BAT out. The model is tested in irs_model_test.lua; this
-- checks the wiring.
local T = dofile("tests/lib/check.lua")("irs_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new()
rt:load("plugins/xtlua/scripts/B747.34.xt.nav/B747.34.xt.nav.lua")
local function frames(seconds, dt)
    dt = dt or 1 / 30
    for _ = 1, math.floor(seconds / dt + 0.5) do rt:frame(dt) end
end
local MSU, STATUS = "laminar/B747/flt_mgmt/iru/mode_sel_dial_pos", "laminar/B747/flt_mgmt/iru/status"
local IRS = "laminar/B747/irs/"
local MEMO, ADV = "laminar/B747/CAS/memo_status", "laminar/B747/CAS/advisory_status"
local FMC = "laminar/B747/fms/notification"
local LAT, LON = 35.7647, 140.3864
for i = 0, 3 do
    rt:set("laminar/B747/electrical/bus/ac", i, 1)
    rt:set("laminar/B747/electrical/bus/dc", i, 1)
end
rt:set("laminar/B747/electrical/bus/hot_bat_apu", 1)
rt:set("laminar/B747/electrical/bus/gnd_svc", 1)
rt:set("laminar/B747/electrical/bus/stby_main", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", LAT)
rt:set("sim/flightmodel/position/longitude", LON)
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)
rt:callout("flight_start")
frames(4)
T.equal(rt:get(STATUS, 0), 0, "cold: off")

-- a full alignment
for i = 0, 2 do rt:set(MSU, i, 2) end
frames(1)
T.equal(rt:get(STATUS, 0), 4, "OFF to NAV: aligning (status 4)")
T.equal(rt:get(IRS .. "mode", 1), 1, "the module's mode: align")
T.equal(rt:get(MEMO, 14), 1, "IRS ALIGN MODE L")
T.equal(rt:get(MEMO, 16), 1, "IRS ALIGN MODE R")
T.equal(rt:get(IRS .. "set_pos"), 1, "SET IRS POS boxes")
T.equal(rt:get(IRS .. "aligning"), 1, "aligning")
T.near(rt:get(IRS .. "time_left", 1), 599, 2, "about ten minutes to go")
T.equal(rt:get("laminar/B747/pfd/capt/irs"), 0, "the PFD's ATT and HDG flags")
rt:set(IRS .. "pos_entry_lat", LAT + 2)
rt:set(IRS .. "pos_entry_lon", LON)
rt:set(IRS .. "pos_entry_seq", 1)
frames(0.2)
T.equal(rt:get(FMC, 12), 1, "2° from where the IRUs were: ENTER IRS POSITION")
rt:set(IRS .. "pos_entry_lat", LAT)
rt:set(IRS .. "pos_entry_seq", 2)
frames(0.2)
T.equal(rt:get(FMC, 12), 0, "a good one: the message goes")
T.equal(rt:get(IRS .. "set_pos"), 0, "no boxes")
frames(600, 0.5)
T.equal(rt:get(STATUS, 0), 2, "ten minutes: NAV (status 2)")
T.equal(rt:get(IRS .. "nav_valid", 2), 1, "IRU R navigating")
T.near(rt:get(IRS .. "lat", 0), LAT, 0.0011, "its position (a small error)")
T.equal(rt:get(IRS .. "aligning"), 0, "none aligning")
T.equal(rt:get(MEMO, 14), 0, "no memo")
T.equal(rt:get("laminar/B747/pfd/capt/irs"), 1, "the captain's PFD: attitude and heading")
T.equal(rt:get("laminar/B747/pfd/fo/irs"), 1, "the first officer's")
T.equal(rt:get(ADV, 270), 0, "no >SOURCE SEL IRS")
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 0)
frames(0.2)
T.equal(rt:get(ADV, 270), 1, "both on L: >SOURCE SEL IRS")
rt:set("laminar/B747/flt_inst/irs_src/fo/sel_dial_pos", 2)

-- X-Plane's long-range navigation failure of the pilot's side: IRU L
rt:set("sim/operation/failures/rel_lrn1", 6)
frames(0.2)
T.equal(rt:get(STATUS, 0), 5, "failed (status 5)")
T.equal(rt:get(ADV, 232), 1, "IRS LEFT")
T.equal(rt:get("laminar/B747/pfd/capt/irs"), 0, "the captain's PFD on IRU L: flags")
rt:set("sim/operation/failures/rel_lrn1", 0)
frames(0.2)
T.equal(rt:get(STATUS, 0), 4, "repaired on the ground: a new alignment")

-- the power: AC 3 (IRU L) lost, the ground service bus off: ON BAT
rt:set("laminar/B747/electrical/bus/ac", 2, 0)
rt:set("laminar/B747/electrical/bus/gnd_svc", 0)
frames(5)
T.equal(rt:get(ADV, 226), 1, ">IRS AC LEFT")
T.equal(rt:get(IRS .. "on_bat"), 0, "ON BAT after 10 s")
frames(6)
T.equal(rt:get(IRS .. "on_bat"), 1, "ON BAT")
rt:set("laminar/B747/electrical/bus/ac", 2, 1)
rt:set("laminar/B747/electrical/bus/gnd_svc", 1)
frames(0.2)
T.equal(rt:get(IRS .. "on_bat"), 0, "AC back: no ON BAT")

-- ATT and SET HDG
rt:set("sim/flightmodel/position/mag_psi", 120)
rt:set(MSU, 1, 3)
frames(1)
T.equal(rt:get(STATUS, 1), 3, "ATT (status 3)")
T.equal(rt:get(IRS .. "set_hdg_shown"), 1, "SET HDG dashes")
frames(31)
T.equal(rt:get(IRS .. "att_valid", 1), 1, "attitude after 30 s")
T.equal(rt:get(IRS .. "hdg_valid", 1), 0, "no heading yet")
rt:set(IRS .. "set_hdg", 130)
rt:set(IRS .. "set_hdg_seq", 1)
frames(0.2)
T.equal(rt:get(IRS .. "hdg_valid", 1), 1, "SET HDG: heading")
T.near(rt:get(IRS .. "hdg", 1), 130, 1e-3, "the entered heading")

-- a quick start (laminar/B747/irs/align_now) with the selectors turned in the same frame
rt:set(MSU, 0, 0)
rt:set(MSU, 1, 0)
frames(1)
rt:set(MSU, 0, 2)
rt:set(MSU, 1, 2)
rt:command("laminar/B747/irs/align_now")
frames(0.2)
T.equal(rt:get(STATUS, 0), 2, "the quick start: L in NAV")
T.equal(rt:get(STATUS, 1), 2, "C in NAV")

-- the GPS (B747.34.xt.gps.lua): powered from the start, so working
T.equal(rt:get("laminar/B747/gps/valid", 0), 1, "GPS L navigating")
T.equal(rt:get("laminar/B747/gps/valid", 1), 1, "GPS R navigating")
rt:set("sim/operation/failures/rel_gps2", 6)
frames(0.2)
T.equal(rt:get("laminar/B747/gps/valid", 1), 0, "X-Plane's GPS 2 failure: R invalid")
T.equal(rt:get(ADV, 184), 1, ">GPS RIGHT")
rt:set("laminar/B747/electrical/bus/stby_main", 0)
frames(0.2)
T.equal(rt:get(ADV, 182), 1, "the AC standby bus lost too: >GPS")
T.equal(rt:get(ADV, 184), 0, "not >GPS RIGHT")
T.done()
