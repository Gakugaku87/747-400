-- Run from the repository root with LuaJIT: luajit tests/fms/cg_xplane_payload_test.lua
-- X-Plane's CG for the FMC's load (2026-11-24, the 2026-11-23 review's
-- PERF-1) in the FMS module as XTLua runs it (tests/lib/xtlua.lua).
-- X-Plane 12 keeps the payload at the acf's payload stations and adds the
-- fuel at the acf's tanks itself: its CG offset is
--   (the stations' moment + the tanks' moment) / the total mass
-- (measured on the ground in X-Plane, 2026-11-24: notes/ATA-34-61-FMC.md
-- §180). The FMC's zones go onto the stations so that this is the FMC's
-- own CG (calc_CGMAC's). Before, the whole airplane's shift with the fuel
-- in it went to cgz_ref_to_default and X-Plane counted the fuel twice (340
-- t with 74 t of fuel: X-Plane 23.0 % MAC, the FMC 27.4).
local T = dofile("tests/lib/check.lua")("cg_xplane_payload")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["laminar/B747/options/cdu_sim_values"] = "number", ["laminar/B747/freighter"] = "number",
    ["laminar/B747/wb/req_id"] = "number", ["laminar/B747/wb/req_field"] = "number",
    ["laminar/B747/wb/req_value"] = "number"}
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"std_pax_weight":100.0},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","aircraft_type":"PASSENGER"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("laminar/B747/freighter", 0)
rt:set("sim/flightmodel/failures/onground_any", 1)
local OEW = 183523.44                       -- the custom acf's acf_m_empty, kg
rt:set("sim/aircraft/weight/acf_m_empty", OEW)
for i = 0, 7 do rt:set("sim/flightmodel/weight/m_fuel", i, 0) end
-- the custom acf's payload stations (acf/_fixed_ref, _fixed_max): m aft of
-- the reference CG, lb; and its tanks (acf_tank_Z, m)
local ST_Z = {-18.83936, -5.64152, 5.575121, 17.76712, -13.71872, -15.02936, 13.28656, -31.58, -31.58}
local ST_MAX = {19000, 20000, 24000, 31000, 6000, 50100, 44700, 0, 0}
local TANK_Z = {-5.98, 3.56, -2.623999, -2.623999, 3.56, 8.958399, 8.958399, 29.6848}
local function stations(on)
    for i = 0, 8 do
        rt:set("sim/aircraft/weight/acf_stations_ref_z", i, on and ST_Z[i + 1] or 0)
        rt:set("sim/aircraft/weight/acf_m_station_max", i, on and ST_MAX[i + 1] or 0)
        rt:set("sim/flightmodel/weight/m_stations", i, 0)
    end
end
stations(true)
rt:callout("flight_start")
for _ = 1, 120 do rt:frame(1 / 30) end
local ns = fms.ns

local PAX = {"paxFirstClassA", "paxBusClassB", "paxEconClassC", "paxEconClassD", "paxEconClassE"}
local CARGO = {"cargoFwd", "cargoAft", "cargoBulk"}
local function load(pax, cargo, fuel)
    for z = 1, 5 do ns.setFMSData(PAX[z], string.format("%d", pax[z] or 0)) end
    for c = 1, 3 do ns.setFMSData(CARGO[c], string.format("%d", cargo[c] or 0)) end
    for i = 0, 7 do rt:set("sim/flightmodel/weight/m_fuel", i, fuel[i + 1] or 0) end
    rt:frame(1 / 30)
    ns.calc_pax_cargo()                 -- the page's load: m_fixed, inflight_update_CG
    ns.calc_CGMAC()                     -- the FMC's CG (the same sum)
    rt:frame(1 / 30)
end
local function station(i) return rt:get("sim/flightmodel/weight/m_stations", i) end
-- X-Plane's CG (% MAC) for what the stations and the tanks hold
local function xp_cg(fuel)
    local m, mom = OEW, 0
    for i = 0, 8 do m, mom = m + station(i), mom + station(i) * ST_Z[i + 1] end
    for i = 1, 8 do m, mom = m + (fuel[i] or 0), mom + (fuel[i] or 0) * TANK_Z[i] end
    return ns.B747_fms_mac_pct(1243.32 + mom / m / 0.0254), m
end
local function sum() local s = 0 for i = 0, 8 do s = s + station(i) end return s end

-- no payload: nothing written, whatever the fuel (before: about -0.2 m asked)
local FUEL86 = {0, 13400, 29840, 29840, 13400, 0, 0, 0}
load({}, {}, FUEL86)
T.equal(sum(), 0, "no payload in the zones: the stations untouched")
T.equal(rt:get("sim/flightmodel/misc/cgz_ref_to_default"), 0, "and no shift asked of X-Plane (before, the fuel's)")
-- X-Plane's own payload stays while the FMC's zones are empty (a test's
-- flight, X-Plane's Weight & Balance screen)
rt:set("sim/flightmodel/weight/m_stations", 2, 5000)
ns.inflight_update_CG()
rt:frame(1 / 30)
T.equal(station(2), 5000, "X-Plane's own payload with empty zones: left where it is")
rt:set("sim/flightmodel/weight/m_stations", 2, 0)

-- a full cabin, 15 t of cargo, 74 t of fuel
local PAXFULL, CARGO15 = {23, 80, 77, 104, 132}, {7073, 6125, 1802}
local FUEL74 = {0, 13400, 21600, 21600, 13400, 2000, 2000, 0}
load(PAXFULL, CARGO15, FUEL74)
local P = 416 * 100 + 15000
T.near(sum(), P, 0.01, "416 passengers and 15 t of cargo: " .. P .. " kg on the stations")
T.near(rt:get("sim/flightmodel/weight/m_fixed"), P, 0.01, "the page's total (m_fixed) the same")
local neg = false
for i = 0, 8 do if station(i) < 0 then neg = true end end
T.check(not neg, "no station under 0")
T.check(station(7) == 0 and station(8) == 0, "the stations without a maximum: none")
local x, m = xp_cg(FUEL74)
T.near(x, ns.wb.cg_mac, 0.05, string.format("X-Plane's CG %.2f %% MAC is the FMC's %.2f (%.1f t)", x, ns.wb.cg_mac, m / 1000))
T.equal(rt:get("sim/flightmodel/misc/cgz_ref_to_default"), 0, "nothing written to cgz_ref_to_default (X-Plane derives it)")
-- the fuel does not move the stations: X-Plane adds the tanks itself
local before = {}
for i = 0, 8 do before[i] = station(i) end
-- X-Plane spreads the stations its own way (a write to m_fixed, or to
-- cgz_ref_to_default: the first station's load to the last), or a station's
-- write did not reach it: every frame's keep puts each station back
rt:set("sim/flightmodel/weight/m_stations", 0, before[0] - 1000)
rt:set("sim/flightmodel/weight/m_stations", 3, before[3] + 1000)
ns.B747_fms_xp_payload_keep()
T.near(station(0), before[0], 1e-6, "the stations moved: the frame's keep puts the zones back")
T.near(station(3), before[3], 1e-6, "the last station too")
rt:set("sim/flightmodel/weight/m_stations", 5, 0)
ns.inflight_update_CG()             -- the 60 s timer's
T.near(station(5), before[5], 1e-6, "and the 60 s write")
local FUEL163 = {51921, 13499, 38075, 38075, 13499, 3981, 3981, 0}
load(PAXFULL, CARGO15, FUEL163)
local same = true
for i = 0, 8 do if math.abs(station(i) - before[i]) > 1e-6 then same = false end end
T.check(same, "163 t of fuel: the stations as with 74 t")
x = xp_cg(FUEL163)
T.near(x, ns.wb.cg_mac, 0.05, string.format("full tanks: X-Plane's %.2f %% MAC, the FMC's %.2f (before 7.8 and 14.7)", x, ns.wb.cg_mac))
-- the stabilizer tank's 10 t
local FUEL173 = {51921, 13499, 38075, 38075, 13499, 3981, 3981, 10038}
load(PAXFULL, CARGO15, FUEL173)
local x2 = xp_cg(FUEL173)
T.near(x2, ns.wb.cg_mac, 0.05, string.format("with the stabilizer tank: %.2f and %.2f", x2, ns.wb.cg_mac))

-- an aft load (zone E, the aft and bulk holds): still the FMC's CG
load({0, 0, 0, 0, 132}, {0, 22938, 6749}, FUEL74)
x = xp_cg(FUEL74)
T.near(x, ns.wb.cg_mac, 0.05, string.format("an aft load: X-Plane's %.2f %% MAC, the FMC's %.2f", x, ns.wb.cg_mac))
T.near(sum(), 13200 + 22938 + 6749, 0.01, "its weight kept")
-- zone A alone is ahead of the first station: all of it there (the moment's
-- rest cannot be made: 2.3 t, 5.5 m)
load({23, 0, 0, 0, 0}, {}, FUEL74)
T.near(station(0), 2300, 0.01, "zone A alone (ahead of the first station): all on the first station")
T.near(sum(), 2300, 0.01, "and nowhere else")
x = xp_cg(FUEL74)
T.check(x > ns.wb.cg_mac and x - ns.wb.cg_mac < 1.0, string.format("X-Plane's CG %.2f %% MAC a little aft of the FMC's %.2f", x, ns.wb.cg_mac))
-- with load on the last station too, the rest is made by moving load from
-- the last to the first
load({23, 0, 0, 0, 100}, {}, FUEL74)
x = xp_cg(FUEL74)
T.near(x, ns.wb.cg_mac, 0.05, string.format("zones A and E: X-Plane's %.2f %% MAC, the FMC's %.2f", x, ns.wb.cg_mac))
T.near(sum(), 12300, 0.01, "their weight kept")

-- a new flight: its payload is X-Plane's (the flight's own, X-Plane's
-- Weight & Balance screen) until the page loads the airplane again, though
-- the zones still hold the load
load(PAXFULL, CARGO15, FUEL74)
rt:callout("flight_start")
for _ = 1, 30 do rt:frame(1 / 30) end
for i = 0, 6 do rt:set("sim/flightmodel/weight/m_stations", i, 1000 + i) end
ns.inflight_update_CG()
ns.B747_fms_xp_payload_keep()
T.equal(station(0), 1000, "after a new flight's start: X-Plane's stations left (station 0)")
T.equal(station(6), 1006, "station 6 too")
load(PAXFULL, CARGO15, FUEL74)
T.near(sum(), P, 0.01, "the page loads the airplane again: the zones on the stations")

-- the load taken off again: the page's total 0 (X-Plane empties its
-- stations with m_fixed), the stations X-Plane's again
load({}, {}, FUEL74)
T.equal(rt:get("sim/flightmodel/weight/m_fixed"), 0, "the load taken off: m_fixed 0")
for i = 0, 6 do rt:set("sim/flightmodel/weight/m_stations", i, 500) end
ns.B747_fms_xp_payload_keep()
ns.inflight_update_CG()
T.equal(station(3), 500, "the zones empty: X-Plane's stations left")
for i = 0, 6 do rt:set("sim/flightmodel/weight/m_stations", i, 0) end

-- an acf without payload stations: the payload's shift to cgz_ref_to_default
stations(false)
load(PAXFULL, CARGO15, FUEL163)
local mom = 0
do
    local w = {2300, 8000, 7700, 10400, 13200, 7073, 6125, 1802}
    local a = {ns.wb.passenger_zoneA_distance, ns.wb.passenger_zoneB_distance, ns.wb.passenger_zoneC_distance,
        ns.wb.passenger_zoneD_distance, ns.wb.passenger_zoneE_distance, ns.wb.fwd_lower_cargo_distance,
        ns.wb.aft_lower_cargo_distance, ns.wb.bulk_lower_cargo_distance}
    for i = 1, 8 do mom = mom + w[i] * (a[i] - 1243.32) * 0.0254 end
end
T.near(rt:get("sim/flightmodel/misc/cgz_ref_to_default"), mom / (OEW + P), 1e-6,
    string.format("no stations: the payload's moment over (OEW + payload) to cgz_ref_to_default (%.4f m), the fuel not in it", mom / (OEW + P)))
T.done()
