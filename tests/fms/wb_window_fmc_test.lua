-- Run from the repository root with LuaJIT: luajit tests/fms/wb_window_fmc_test.lua
-- (2026-11-05, the user) the sim's windows' side in the FMS module as XTLua
-- runs it (tests/lib/xtlua.lua). The weight and balance window
-- (b747_fms_bridge wb_window.c) shows the CDU's PAX/CARGO load
-- (laminar/B747/wb/load_zones, load_cargo, load_pax_kg, load_freighter)
-- and enters it as that page does (req_field, req_value, req_id): the
-- passengers' total round the zones as the page's L1, a zone, cargo, kg a
-- passenger (SIM CONFIG's); X-Plane's payload and CG shift follow; on the
-- ground only.
local T = dofile("tests/lib/check.lua")("wb_window_fmc")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["laminar/B747/wb/req_id"] = "number", ["laminar/B747/wb/req_field"] = "number",
    ["laminar/B747/wb/req_value"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
-- (the window's three as XTLua reads another plugin's datarefs: X-Plane s259)
local rt = xtlua.new{types = types, lagged = {"laminar/B747/wb/req_id", "laminar/B747/wb/req_field", "laminar/B747/wb/req_value"}}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"std_pax_weight":120.0},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","aircraft_type":"PASSENGER"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("sim/aircraft/weight/acf_m_empty", 178000)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local function req(field, value)
    rt:set("laminar/B747/wb/req_field", field)
    rt:set("laminar/B747/wb/req_value", value)
    rt:set("laminar/B747/wb/req_id", rt:get("laminar/B747/wb/req_id") + 1)
    frames(0.2)
end
local function zone(z) return rt:get("laminar/B747/wb/load_zones", z) end
local function zones() return zone(0) + zone(1) + zone(2) + zone(3) + zone(4) end
local function cargo(c) return rt:get("laminar/B747/wb/load_cargo", c) end
local function payload() return rt:get("sim/flightmodel/weight/m_fixed") end

T.equal(zones(), 0, "no passengers to start with")
T.equal(rt:get("laminar/B747/wb/load_pax_kg"), 120, "kg a passenger: SIM CONFIG's 120")
T.equal(rt:get("laminar/B747/wb/load_freighter"), 0, "a passenger airplane")

-- the passengers' total: round the zones one at a time (the page's L1)
req(0, 350)
T.equal(zones(), 350, "350 passengers in the window: 350 in the zones")
T.equal(zone(0), 23, "zone A full (23)")
T.check(zone(1) == 80 and zone(2) == 77, "B and C full (80, 77): " .. zone(1) .. " " .. zone(2))
T.check(zone(3) == 85 and zone(4) == 85, "the rest shared by D and E: " .. zone(3) .. " " .. zone(4))
T.equal(payload(), 350 * 120, "X-Plane's payload: 350 x 120 kg")
local shift = rt:get("sim/flightmodel/misc/cgz_ref_to_default")
T.check(shift ~= 0, "X-Plane's CG shifted for the load at once (" .. shift .. " m)")

-- the same on the CDU's PAX/CARGO page (one set of values)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
for _, k in ipairs({"func_key/fix", "ls_key/R4", "ls_key/R3"}) do rt:command("laminar/B747/fms1/" .. k) frames(0.2) end
T.check(line(1):find("PAX") ~= nil, "MENU > GROUND HANDLING > PAX/CARGO: " .. line(1))
T.check(line(3):match("^23") ~= nil and line(9):match("^85") ~= nil, "the page shows the window's zones: A " .. line(3) .. ", D " .. line(9))

-- a zone: zone A at most 23 (the page's L1 above 23 is a total)
req(1, 10)
T.equal(zone(0), 10, "zone A 10")
T.equal(zones(), 337, "the others kept")
req(1, 40)
T.equal(zone(0), 23, "40 in zone A: 23, not a total")
req(2, 100)
T.equal(zone(1), 80, "100 in zone B: its 80, as the page")

-- cargo, kg, as the page (FWD at most 26,490)
req(6, 12000.4)
T.equal(cargo(0), 12000, "cargo FWD 12,000 kg")
req(6, 30000)
T.equal(cargo(0), 26490, "30,000 kg: FWD's 26,490")
req(8, 2000)
T.equal(cargo(2), 2000, "cargo BULK 2,000 kg")
T.equal(payload(), 350 * 120 + 26490 + 2000, "the payload with the cargo")

-- kg a passenger: SIM CONFIG's, the payload with it
req(9, 100)
T.equal(rt:get("laminar/B747/wb/load_pax_kg"), 100, "100 kg a passenger")
T.equal(payload(), 350 * 100 + 26490 + 2000, "the payload with 100 kg a passenger")
req(9, 500)
T.equal(rt:get("laminar/B747/wb/load_pax_kg"), 100, "500 kg: refused")

-- in the air: refused
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
req(0, 100)
T.equal(zones(), 350, "in the air: the passengers kept")
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
T.done()
