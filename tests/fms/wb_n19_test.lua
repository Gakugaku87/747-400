-- Run from the repository root with LuaJIT: luajit tests/fms/wb_n19_test.lua
-- The FMC's weight and balance after the 2026-11-19 sources (GAP_ANALYSIS.md
-- §7 N19-WB-03..05; notes/ATA-34-61-FMC.md §175) in the FMS module as XTLua
-- runs it (tests/lib/xtlua.lua):
--  - TAKEOFF REF's CG (FCOM p.1320): the 109's and 570's dashes until the
--    crew enters one (before: the FMC's CG small at a GR WT or ZFW), a
--    crew's CG kept with its trim for a new weight (before: overwritten);
--    the 405's (a freighter) the FMC's WBS CG small with a caret, large when
--    line selected, back to it on DELETE;
--  - the lower holds' arms (NTSB_WBM p.32: FWD 725.5, AFT 1702.0, BULK
--    2014.6 B.A.);
--  - the main deck's zones A and E at most the BCF's 7,838 and 2,041 kg
--    (NTSB_WBM p.23): the page's entries, FULL, the round robin, the
--    weight window's zone entry.
local T = dofile("tests/lib/check.lua")("wb_n19")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["laminar/B747/options/cdu_sim_values"] = "number", ["laminar/B747/freighter"] = "number",
    ["laminar/B747/wb/req_id"] = "number", ["laminar/B747/wb/req_field"] = "number",
    ["laminar/B747/wb/req_value"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
types["laminar/B747/engines/ref_thr_limit_mode"] = "string"
types["laminar/B747/fms/thrlim/eicas"] = "string"
local rt = xtlua.new{types = types, lagged = {"laminar/B747/wb/req_id", "laminar/B747/wb/req_field", "laminar/B747/wb/req_value"}}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
local function simconfig(kind)
    rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"std_pax_weight":84.0},'
        .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","aircraft_type":"' .. kind .. '"}}')
    rt:set("laminar/B747/newsimconfig", 1)
end
simconfig("PASSENGER")
rt:set("laminar/B747/freighter", 0)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/aircraft/weight/acf_m_empty", 180000)
for i = 0, 7 do rt:set("sim/flightmodel/weight/m_fuel", i, 0) end
rt:set("sim/flightmodel/weight/m_fuel", 0, 50000)
rt:set("sim/flightmodel/weight/m_fuel_total", 50000)
rt:set("sim/weather/temperature_ambient_c", 15)
rt:set("laminar/B747/irs/mode", 0, 2)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local ns = fms.ns
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function small(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_S", n)) end
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.2) end
local function type_in(text)
    for ch in text:gmatch(".") do rt:command("laminar/B747/fms1/" .. (ch == "." and "key/period" or "alphanum_key/" .. ch)) end
    frames(0.1)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function zfw(t)
    key("func_key/index")
    key("ls_key/L6")
    key("ls_key/L3")                       -- PERF
    type_in(t)
    key("ls_key/L3")
    clear()
end
local function takeoff()
    key("func_key/index")
    key("ls_key/L6")
    key("ls_key/L5")                       -- TAKEOFF
end
local function delete_cg()
    clear()
    rt:command("laminar/B747/fms1/key/del")
    frames(0.1)
    key("ls_key/R4")
end
local function trim_text() return small(9):match("(%d+%.%d)") end

-- (N19-WB-03) the 109 (P&W, a passenger airplane): dashes after ZFW
zfw("220")
T.check(line(1):find("PERF INIT") ~= nil, "PERF INIT: " .. line(1))
takeoff()
T.check(line(1):find("TAKEOFF REF") ~= nil, "TAKEOFF REF: " .. line(1))
T.check(ns.B747_fms_wbs_cg() ~= nil, "the FMC made its CG at the ZFW entry: " .. tostring(ns.B747_fms_wbs_cg()))
T.check(small(9):find("%-%-%%") ~= nil and not line(9):find("%d%%"), "the 109: CG dashes (FCOM p.1320), not the FMC's: "
    .. small(9) .. "|" .. line(9))
T.equal(trim_text(), nil, "no trim before a CG")
-- a crew's CG, then a new ZFW: the CG kept, its trim for the new weight
type_in("22")
key("ls_key/R4")
T.check(line(9):find("22%%$") ~= nil, "CG 22 large: " .. line(9))
local trim22 = trim_text()
T.check(trim22 ~= nil, "its trim: " .. tostring(trim22))
-- 100 t in the main tanks (the CG about 22 %)
rt:set("sim/flightmodel/weight/m_fuel", 0, 0)
for i, kg in ipairs({20000, 30000, 30000, 20000}) do rt:set("sim/flightmodel/weight/m_fuel", i, kg) end
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
frames(0.2)
zfw("180")
takeoff()
T.check(line(9):find("22%%$") ~= nil, "a new ZFW: the crew's CG 22 kept (before: the FMC's): " .. line(9))
T.equal(ns.fmsModules["data"].cg_mac, "22", "the CG's data 22")
local gw = 180000 + 100000
local trimNew = trim_text()
ns.calc_stab_trim(gw, 22)
T.equal(trimNew, string.format("%3.1f", ns.wb.stab_trim), "its trim for the sim's 280 t (was " .. tostring(trim22) .. ")")
T.check(trimNew ~= trim22, "the trim changed with the weight")
delete_cg()
T.check(small(9):find("%-%-%%") ~= nil and trim_text() == nil, "DELETE on the 109: dashes, no trim: " .. small(9))

-- (N19-WB-03) the 405 (a freighter): the FMC's CG from the WBS inputs
rt:set("laminar/B747/freighter", 1)
frames(0.2)
zfw("180")
takeoff()
local w = ns.B747_fms_wbs_cg()
T.check(w ~= nil and small(9):find(string.format("%d%%%%>", w)) ~= nil and not line(9):find("%d%%"),
    "the 405: its WBS CG " .. tostring(w) .. " small with a caret (FCOM p.1320): " .. small(9))
T.check(trim_text() ~= nil, "its trim small: " .. small(9))
key("ls_key/R4")
T.check(line(9):find(string.format("%d%%%%$", w)) ~= nil, "line selected: the CG large: " .. line(9))
type_in("25")
key("ls_key/R4")
T.check(line(9):find("25%%$") ~= nil, "a pilot's 25 large: " .. line(9))
delete_cg()
T.check(small(9):find(string.format("%d%%%%>", w)) ~= nil and not line(9):find("%d%%"),
    "DELETE: back to the WBS CG small: " .. small(9))
rt:set("laminar/B747/freighter", 0)
frames(0.2)
T.check(small(9):find("%-%-%%") ~= nil, "the 109 again: dashes: " .. small(9))
delete_cg()

-- (N19-WB-04) the lower holds' arms (B.A. less the nose's 90 in)
T.equal(ns.wb.fwd_lower_cargo_distance, 635.5, "FWD: B.A. 725.5 (before 740)")
T.equal(ns.wb.aft_lower_cargo_distance, 1612.0, "AFT: B.A. 1702.0 (before 1765)")
T.equal(ns.wb.bulk_lower_cargo_distance, 1924.6, "BULK: B.A. 2014.6 (before 2025)")
local function entry(value, text)
    local o = {id = "fmsL", scratchpad = text, notify = ""}
    ns.fmsFunctions.setdata(o, value)
    return o
end
for i = 0, 7 do rt:set("sim/flightmodel/weight/m_fuel", i, 0) end
rt:set("sim/flightmodel/weight/m_fuel_total", 0)
frames(0.2)
entry("cargoFwd", "10000")
ns.calc_CGMAC()
T.near(ns.wb.cg_mac, ns.B747_fms_mac_pct((180000 * 1243.32 + 10000 * 635.5) / 190000), 1e-6,
    "10 t in FWD with the empty airplane: the CG with FWD's arm")
entry("cargoFwd", "0")

-- (N19-WB-05) the freighter's zones A and E
simconfig("FREIGHTER")
rt:set("laminar/B747/freighter", 1)
frames(0.5)
local function zone(name) return tonumber(ns.fmsModules["data"][name]) end
entry("freightZoneE", "3000")
T.equal(zone("freightZoneE"), 2041, "zone E 3,000 kg: its 2,041 (before 3,000, up to 3,763)")
entry("freightZoneE", "1P")
T.equal(zone("freightZoneE"), 2041, "a pallet (3,763 kg) in zone E: 2,041")
entry("freightZoneA", "7000")
T.equal(zone("freightZoneA"), 7000, "zone A 7,000 kg")
entry("freightZoneA", "3P")
T.equal(zone("freightZoneA"), 7526, "three pallets in zone A: two, 7,526 kg (before three, 11,289)")
entry("freightZoneA", "F")
T.check(zone("freightZoneA") == 7838 and zone("freightZoneB") == 30104 and zone("freightZoneC") == 22578
    and zone("freightZoneD") == 45156 and zone("freightZoneE") == 2041, "FULL: A 7,838, E 2,041, B-D as before")
entry("freightZoneA", "120000")
local tot = zone("freightZoneA") + zone("freightZoneB") + zone("freightZoneC") + zone("freightZoneD") + zone("freightZoneE")
T.check(tot == 107717 and zone("freightZoneA") == 7838 and zone("freightZoneE") == 2041,
    "120,000 kg round the zones: their 107,717 kg together (before 112,890), no endless loop: " .. tot)
entry("freightZoneA", "9000")
T.equal(zone("freightZoneA"), 1800, "9,000 kg on zone A (over its limit): round the zones, 1,800 each")
local sp = ns.B747_fms_freight_spread(500)
T.check(sp[1] == 100 and sp[5] == 100, "500 kg round the five: 100 each")
-- the weight window's zone A: at most its limit, not round the zones
local function req(field, value)
    rt:set("laminar/B747/wb/req_field", field)
    rt:set("laminar/B747/wb/req_value", value)
    rt:set("laminar/B747/wb/req_id", rt:get("laminar/B747/wb/req_id") + 1)
    frames(0.3)
end
entry("freightZoneB", "5000")
req(1, 12000)
T.equal(zone("freightZoneA"), 7838, "the window's 12,000 kg in zone A: 7,838 (before, round the zones)")
T.equal(zone("freightZoneB"), 5000, "zone B kept")
req(5, 2500)
T.equal(zone("freightZoneE"), 2041, "the window's 2,500 kg in zone E: 2,041")
T.done()
