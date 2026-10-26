-- Run from the repository root with LuaJIT: luajit tests/fms/lnav_glue_test.lua
-- LNAV in the FMC module (6-1/6-2 step 6c; notes/ATA-34-61-FMC.md §29):
-- plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua as
-- XTLua runs it, on the synthetic navigation data. The AFDS's LNAV state
-- (laminar/B747/autopilot/lnav_state: 1 armed, 2 engaged) in; the FMC's
-- steering out (laminar/B747/fms/lnav/valid, roll, mode, xtk, route), the
-- messages NO ACTIVE ROUTE, NOT ON INTERCEPT HEADING, DISCONTINUITY (FCOM
-- p.1431-1435) on the CDUs, PROGRESS page 2's XTK ERROR (FCOM p.1377).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("lnav_glue")
local xtlua = dofile("tests/lib/xtlua.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.path_model.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["xtlua/fms"] = "string"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local LNAV = "laminar/B747/autopilot/lnav_state"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k, held)
    rt:command(K .. k, held)
    frames(0.3)
end
local function type_in(text)
    for ch in text:gmatch(".") do
        rt:command(K .. (ch == "/" and "key/slash" or "alphanum_key/" .. ch))
    end
    frames(0.1)
end
local function enter(text, lsk) type_in(text) key("ls_key/" .. lsk) end
local function lnav(name) return rt:get("laminar/B747/fms/lnav/" .. name) end
-- the airplane in the air at p, tracking and heading `trk` (true) at 250 kt
local function at(p, trk)
    rt:set("sim/flightmodel/position/latitude", p.lat)
    rt:set("sim/flightmodel/position/longitude", p.lon)
    rt:set("sim/flightmodel/position/hpath", trk)
    rt:set("sim/flightmodel/position/psi", trk)
    rt:set("sim/flightmodel2/position/groundspeed", 128.6)
    rt:set("sim/flightmodel/position/true_airspeed", 128.6)
    frames(0.2)
end

-- the route: ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL, ZZBB
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("Z1", "L2")
enter("CHARL", "R2")
frames(1.2)

-- airborne on the leg to ALPHA, LNAV armed before the activation
-- RW16R's threshold (tests/fms/data/navdb/CIFP/ZZAA.dat)
local RW = {lat = 35.01, lon = 140.005}
local ALPHA, BRAVO = {lat = 35.5, lon = 140.5}, {lat = 36.0, lon = 140.5}
local c1 = P.course(RW, ALPHA)
rt:set("sim/flightmodel/failures/onground_any", 0)
at(P.point(RW, c1, 20), c1)
rt:set(LNAV, 1)
frames(0.3)
T.equal(lnav("route"), 0, "no active route")
T.equal(lnav("valid"), 0, "no steering")
T.equal(pad(), "NO ACTIVE ROUTE", "LNAV armed without an active route: NO ACTIVE ROUTE (FCOM p.1433)")
key("func_key/legs")
key("ls_key/R6")
key("key/execute")
T.equal(lnav("route"), 1, "the active route: the FMC sequences it")
T.equal(lnav("valid"), 1, "on the leg to ALPHA: captured, the steering valid (ATA34_2 p.618)")
T.check(pad() ~= "NO ACTIVE ROUTE", "the message gone: " .. pad())

-- 10 nm left of it, parallel: not captured, NOT ON INTERCEPT HEADING
at(P.point(P.point(RW, c1, 20), c1 - 90, 10), c1)
T.equal(lnav("valid"), 0, "10 nm off, parallel: not captured")
T.equal(pad(), "NOT ON INTERCEPT HEADING", "the advisory (FCOM p.1435)")
at(P.point(P.point(RW, c1, 20), c1 - 90, 10), c1 + 60)
T.check(lnav("valid") == 0 and pad() == "", "turned toward it: no message, not captured yet: " .. pad())

-- engaged, 1 nm right of the leg: a bank to the left, XTK R 1.0
rt:set(LNAV, 2)
at(P.point(P.point(RW, c1, 20), c1 + 90, 1), c1)
T.equal(lnav("mode"), 1, "the path (mode 1)")
T.near(lnav("xtk"), 1.0, 0.02, "the cross-track error: 1 nm right")
T.check(lnav("roll") < -5, "a bank to the left: " .. lnav("roll"))
T.near(rt:get("laminar/B747/autopilot/lnav/xtk_error"), 1.0, 0.02, "the AFDS's XTK error (PROGRESS page 2's before)")
key("func_key/prog")
key("func_key/next_pg")
frames(1.2)
T.equal(line(5), "R 1.0NM            +**FT", "PROGRESS page 2: XTK ERROR R 1.0NM (FCOM p.1377; before always L)")

-- ZZD inserted after ALPHA with a ROUTE DISCONTINUITY after it; past it
-- engaged: the heading held, DISCONTINUITY (FCOM p.1431)
key("func_key/legs")
enter("ZZD", "L2")
key("key/execute")
T.equal(line(5), "ZZD                     ", "ZZD after ALPHA")
-- (ZZD back toward ZZAA: ALPHA a turn of over 135 degrees, flown over)
local ZZD = {lat = 35.3, lon = 140.3}
local c2 = P.course(ALPHA, ZZD)
at(P.point(ALPHA, c1, 1), c1)
T.equal(line(3), "ZZD                     ", "past ALPHA: ALPHA sequenced")
at(P.point(ZZD, c2, 1), c2)
T.check(line(3):find("^%*%*%*%*%*") ~= nil, "past ZZD: ZZD sequenced, the discontinuity first: " .. line(3))
T.equal(lnav("mode"), 3, "the heading held (mode 3)")
T.equal(pad(), "DISCONTINUITY", "DISCONTINUITY on the CDU")

T.done()
