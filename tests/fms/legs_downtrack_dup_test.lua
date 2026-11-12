-- Run from the repository root with LuaJIT: luajit tests/fms/legs_downtrack_dup_test.lua
-- (2026-11-12 review FMC-9; REVIEW_2026-11-12.md case 10) A waypoint whose
-- identifier the data has twice, entered on the LEGS page's 1L while it is
-- in the active route ahead: FCOM p.1249 (11.31.15): SELECT DESIRED WPT
-- does not display, the downtrack waypoint is used (a DIRECT TO it). Before,
-- SELECT DESIRED WPT came up for every such identifier. The test data has
-- two ALPHAs (tests/fms/data/navdb). A waypoint not in the route still
-- asks (the second ALPHA is not the route's when the route has none).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("legs_downtrack_dup")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
local fms = rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds) for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end end
frames(4)
local db = fms.ns.B747_fmc_navdb
local n = 0
while not db.ready and n < 200000 do rt:frame(1 / 30); n = n + 1 end
local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(i) return rt:get(string.format("%sLine%02d_L", LN, i)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for _ = 1, 30 do rt:command(K .. "key/clear") end
    frames(0.1)
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch))
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local R, ns = fms.ns.B747_route_model, fms.ns
local function legs()
    local out = {}
    for _, l in ipairs(R.shown(ns.B747_fmc_route_num(1)).legs) do out[#out + 1] = l.disc and "DISC" or (l.fix and l.fix.ident or l.name or "?") end
    return table.concat(out, " ")
end

-- ZZAA to ZZBB: DIRECT BRAVO, DIRECT ALPHA (the nearer of two), DIRECT CHARL
key("func_key/fpln")
enter("ZZAA", "L1") enter("ZZBB", "R1")
key("func_key/next_pg")
enter("BRAVO", "R1")
enter("ALPHA", "R2")
T.check(line(1):find("SELECT DESIRED WPT") ~= nil, "ALPHA on RTE, two in the data: SELECT DESIRED WPT (FCOM p.1249)")
key("ls_key/L1")
enter("CHARL", "R3")
T.equal(legs(), "BRAVO ALPHA CHARL", "the route")
local alpha = R.shown(ns.B747_fmc_route_num(1)).legs[2].fix
key("func_key/fpln") key("ls_key/R6") key("key/execute")
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(1)
T.check(ns.B747_fmc_route_num(1).active, "the route active")

-- LEGS 1L ALPHA: the route's ALPHA ahead, no SELECT DESIRED WPT
key("func_key/legs")
enter("ALPHA", "L1")
T.check(not line(1):find("SELECT DESIRED WPT"), "ALPHA in the active route ahead: no SELECT DESIRED WPT (FCOM p.1249): " .. line(1))
T.check(line(1):find("MOD RTE 1 LEGS") ~= nil, "a modification: DIRECT TO ALPHA: " .. line(1))
T.equal(legs(), "ALPHA CHARL", "DIRECT TO ALPHA, BRAVO gone")
local to = R.shown(ns.B747_fmc_route_num(1)).legs[1].fix
T.check(to and to.lat == alpha.lat and to.lon == alpha.lon, "the route's ALPHA")
key("ls_key/L6")             -- ERASE
T.equal(legs(), "BRAVO ALPHA CHARL", "erased")
T.done()
