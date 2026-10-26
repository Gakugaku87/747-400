-- Run from the repository root with LuaJIT: luajit tests/fms/route_sync_test.lua
-- The active waypoint and X-Plane's flight plan in flight (6-1/6-2 step
-- 5e; notes/ATA-34-61-FMC.md §22): the FMC module
-- (plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua) on the
-- synthetic navigation data. X-Plane starts a new flight plan at its first
-- waypoint: after the activation in flight, a modification's EXEC and a
-- DIRECT TO, the FMC makes X-Plane's current waypoint (xtlua/currentFMSID,
-- from 1) and the AFDS's (fmscurrentIndex) the active one; as LNAV
-- sequences the route (step 6c: the airplane past a waypoint; before, the
-- AFDS's best track), the legs before it are passed (FMSPG p.119: they
-- leave the LEGS pages; FCOM p.1331), the flight plan stays the same and
-- X-Plane's current waypoint and the AFDS's follow. The test plays
-- X-Plane: xtlua/fms from the rows the FMC loaded, [10] the current
-- waypoint (XTLua's xpmtdatarefs.cpp).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("route_sync")
local xtlua = dofile("tests/lib/xtlua.lua")

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
local CUR = "laminar/B747/autopilot/ap_monitor/fmscurrentIndex"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
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
-- the plan the FMC loaded last (raw: a new one goes to X-Plane once the
-- route has stayed the same a second)
local function xpfms() return rt:get("xtlua/loadtoFMS") or "" end
local function loaded() frames(1.2) end
-- xtlua/currentFMSID: a string dataref XTLua reads as a number from 1
local function xpcur() return tonumber(rt:get("xtlua/currentFMSID")) or 0 end
-- X-Plane with the plan the FMC loaded last, its current waypoint `active`
-- (from 1): xtlua/fms as XTLua makes it ([2] the type, [5] [6] the
-- position, [8] the identifier, [10] the current waypoint)
local function xplane(active)
    local out, k = {}, 0
    for t, ident, alt, lat, lon in xpfms():gmatch("\n(%d+) (%S+) %S+ (%S+) (%S+) (%S+)") do
        k = k + 1
        out[k] = string.format('[0,%d,0,0,%s,%s,"%s","%s",%s,%s]', t == "1" and 1 or 2048, lat, lon, ident, ident,
            alt, tostring(k == active))
    end
    rt:set("xtlua/fms", "[" .. table.concat(out, ",") .. "]")
    frames(0.2)
    return k
end
local function rows()
    local out = {}
    for ident in xpfms():gmatch("\n%d+ (%S+) ") do out[#out + 1] = ident end
    return table.concat(out, " ")
end

-- the route on the RTE pages: ZZAA RW16R, DIRECT ALPHA, Z1 to CHARL
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("Z1", "L2")
enter("CHARL", "R2")
T.equal(rows(), "", "nothing in X-Plane's plan while the route keeps changing (a plan a second after the last change)")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO CHARL ZZBB", "X-Plane's flight plan")
xplane(1)

-- airborne: the activation makes ALPHA X-Plane's current waypoint and the
-- AFDS's; right after a load (a constraint at ALPHA) not before xtlua/fms
-- shows the new plan (a write before X-Plane takes it is lost)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("sim/flightmodel/position/latitude", 35.3)
rt:set("sim/flightmodel/position/longitude", 140.3)
rt:set(CUR, 2)
key("func_key/legs")
enter("5000", "R1")
frames(1.05)
T.check(xpfms():find("\n11 ALPHA DRCT 5000%.000000 "), "ALPHA's 5000 loaded")
key("ls_key/R6")
key("key/execute")
T.check(line(1):find("ACT RTE 1 LEGS"), "ACT RTE 1 LEGS: " .. line(1))
T.equal(xpcur(), 0, "the activation right after the load: xtlua/fms not showing the new plan yet, nothing written")
xplane(1)
T.equal(xpcur(), 3, "X-Plane's current waypoint: ALPHA, the third (from 1)")
T.equal(rt:get(CUR), 3, "the AFDS's: ALPHA")
-- X-Plane does not take it: written once more after two seconds, no more
rt:set("xtlua/currentFMSID", "")
frames(1)
T.equal(xpcur(), 0, "not every frame")
frames(1.2)
T.equal(xpcur(), 3, "once more after two seconds")
rt:set("xtlua/currentFMSID", "")
frames(3)
T.equal(xpcur(), 0, "twice at most (XTLua calls X-Plane's FMS from its own thread)")
xplane(3)
frames(0.5)
T.equal(xpcur(), 0, "once X-Plane has it, written no more")

-- past ALPHA's turn on the way to BRAVO, north at 250 kt: LNAV sequences
-- ALPHA (step 6c), X-Plane's current waypoint and the AFDS's follow
rt:set("sim/flightmodel/position/latitude", 35.5333)
rt:set("sim/flightmodel/position/longitude", 140.5)
rt:set("sim/flightmodel/position/hpath", 0)
rt:set("sim/flightmodel/position/psi", 0)
rt:set("sim/flightmodel2/position/groundspeed", 128.6)
rt:set("sim/flightmodel/position/true_airspeed", 128.6)
frames(0.3)
T.equal(line(3), "BRAVO                   ", "BRAVO the active waypoint, the first line (FCOM p.1331; FMSPG p.119)")
T.equal(line(5), "CHARL                   ", "then CHARL")
T.equal(xpcur(), 4, "X-Plane's current waypoint: BRAVO, the fourth")
T.equal(rt:get(CUR), 4, "and the AFDS's")
xplane(4)
rt:set("xtlua/currentFMSID", "")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO CHARL ZZBB", "X-Plane's flight plan the same")
T.equal(xpcur(), 0, "nothing written once X-Plane shows it")

-- a modification: CHARL deleted; after the EXEC X-Plane starts the new
-- plan at ZZAA, the FMC makes BRAVO current again
key("key/del")
key("ls_key/L2")
T.check(line(1):find("MOD RTE 1 LEGS"), "MOD RTE 1 LEGS: " .. line(1))
key("key/execute")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO ZZBB", "the new plan")
T.equal(xpcur(), 0, "not before X-Plane has it")
xplane(1)
T.equal(xpcur(), 4, "BRAVO X-Plane's current waypoint again")
T.equal(rt:get(CUR), 4, "and the AFDS's")
xplane(4)
rt:set("xtlua/currentFMSID", "")
frames(0.5)

-- a modification with as many rows and BRAVO in the same row (DELTA after
-- BRAVO, then CHARL in its place): xtlua/fms still shows the old plan,
-- BRAVO current, until X-Plane has the new one at ZZAA
enter("DELTA", "L2")
key("key/execute")
loaded()
xplane(4)
rt:set("xtlua/currentFMSID", "")
frames(0.5)
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO DELTA ZZBB", "DELTA after BRAVO")
key("key/del")
key("ls_key/L2")
enter("CHARL", "L2")
key("key/execute")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO CHARL ZZBB", "CHARL in DELTA's place: as many rows")
T.equal(xpcur(), 0, "the old plan in xtlua/fms (BRAVO current): nothing yet")
xplane(1)
T.equal(xpcur(), 4, "the new plan from ZZAA: BRAVO current again")
xplane(4)
rt:set("xtlua/currentFMSID", "")
frames(0.5)

-- DIRECT TO ZZD (not in the route): from the airplane's position at EXEC
enter("ZZD", "L1")
T.check(line(1):find("MOD RTE 1 LEGS"), "DIRECT TO ZZD: MOD RTE 1 LEGS: " .. line(1))
rt:set("sim/flightmodel/position/latitude", 35.4)
rt:set("sim/flightmodel/position/longitude", 140.35)
key("key/execute")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA DTOPOS ZZD BRAVO CHARL ZZBB",
    "ALPHA passed, the direct-to's start DTOPOS, ZZD (the discontinuity after it not in X-Plane's plan)")
T.check(xpfms():find("\n28 DTOPOS DRCT 0%.000000 35%.400000 140%.350000\n"), "DTOPOS where the airplane was at EXEC (estimate)")
xplane(1)
T.equal(xpcur(), 5, "ZZD X-Plane's current waypoint")
T.equal(rt:get(CUR), 5, "and the AFDS's (its best track takes the leg from DTOPOS)")
T.equal(line(3), "ZZD                     ", "ZZD the active waypoint")

-- on the ground nothing sequences, past ZZD too
rt:set("sim/flightmodel/failures/onground_any", 1)
xplane(5)
rt:set("sim/flightmodel/position/latitude", 35.32)
rt:set("sim/flightmodel/position/longitude", 140.32)
frames(0.3)
T.equal(line(3), "ZZD                     ", "on the ground: no sequencing")

T.done()
