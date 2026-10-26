-- Run from the repository root with LuaJIT: luajit tests/fms/route_bridge_test.lua
-- The FMC's flight plan through the FMS bridge plugin (6-1/6-2 step 5e;
-- notes/ATA-34-61-FMC.md §23; plugins/b747_fms_bridge): with the plugin
-- there (laminar/B747/fms/xp/bridge 1), the FMC writes the plan to
-- laminar/B747/fms/xp/plan, in flight with a first line "CURRENT n" (the
-- active row: the plugin makes it current right after the load, on
-- X-Plane's thread), and the current waypoint to laminar/B747/fms/xp/current;
-- never XTLua's xtlua/loadtoFMS or xtlua/currentFMSID (they call X-Plane's
-- FMS from XTLua's own thread). The test plays X-Plane and the plugin.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("route_bridge")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string", ["xtlua/fms"] = "string",
    ["laminar/B747/fms/xp/plan"] = "string", ["laminar/B747/fms/xp/current"] = "number",
    ["laminar/B747/fms/xp/bridge"] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:set("laminar/B747/fms/xp/bridge", 1)
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
local XCUR = "laminar/B747/fms/xp/current"
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
local function loaded() frames(1.2) end
local function bridged() return rt:get("laminar/B747/fms/xp/plan") or "" end
-- the plan the plugin loads (its CURRENT line left out)
local function plan() return (bridged():gsub("^CURRENT %d+\n", "")) end
local function rows()
    local out = {}
    for ident in plan():gmatch("\n%d+ (%S+) ") do out[#out + 1] = ident end
    return table.concat(out, " ")
end
-- X-Plane after the plugin's load: xtlua/fms with entry `active` current
local function xplane(active)
    local out, k = {}, 0
    for t, ident, alt, lat, lon in plan():gmatch("\n(%d+) (%S+) %S+ (%S+) (%S+) (%S+)") do
        k = k + 1
        out[k] = string.format('[0,%d,0,0,%s,%s,"%s","%s",%s,%s]', t == "1" and 1 or 2048, lat, lon, ident, ident,
            alt, tostring(k == active))
    end
    rt:set("xtlua/fms", "[" .. table.concat(out, ",") .. "]")
    rt:set(XCUR, active)
    frames(0.2)
end

-- the route on the ground: the plan through the plugin, no CURRENT line
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZBB", "R1")
enter("16R", "L2")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("Z1", "L2")
enter("CHARL", "R2")
loaded()
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO CHARL ZZBB", "the plan to the plugin")
T.check(bridged():find("^I\n1100 Version\n"), "on the ground: no CURRENT line")
T.equal(rt:get("xtlua/loadtoFMS") or "", "", "not XTLua's loadtoFMS")
xplane(1)

-- airborne: the activation through the plugin's current waypoint
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set(CUR, 2)
key("func_key/legs")
key("ls_key/R6")
key("key/execute")
T.check(line(1):find("ACT RTE 1 LEGS"), "ACT RTE 1 LEGS: " .. line(1))
T.equal(rt:get(XCUR), 3, "the plugin's current waypoint: ALPHA, the third")
T.equal(rt:get(CUR), 3, "the AFDS's: ALPHA")
xplane(3)
frames(0.5)

-- a modification's EXEC: the plan with CURRENT, the plugin sets it after the load
rt:set(CUR, 4)
xplane(4)
frames(0.3)
T.equal(line(3), "BRAVO                   ", "the AFDS on BRAVO: ALPHA passed")
key("key/del")
key("ls_key/L2")
key("key/execute")
loaded()
T.check(bridged():find("^CURRENT 4\nI\n"), "CURRENT 4 (BRAVO) before the plan: " .. bridged():sub(1, 12))
T.equal(rows(), "ZZAA RW16R ALPHA BRAVO ZZBB", "CHARL deleted")
xplane(4)
frames(0.5)

-- DIRECT TO: DTOPOS and the target current
enter("ZZD", "L1")
rt:set("sim/flightmodel/position/latitude", 35.4)
rt:set("sim/flightmodel/position/longitude", 140.35)
key("key/execute")
loaded()
T.check(bridged():find("^CURRENT 5\n"), "CURRENT 5 (ZZD)")
T.equal(rows(), "ZZAA RW16R ALPHA DTOPOS ZZD BRAVO ZZBB", "the direct-to's start DTOPOS")
xplane(5)
T.equal(rt:get(CUR), 5, "the AFDS's: ZZD, once X-Plane shows the plan")
T.equal(rt:get("xtlua/currentFMSID") or "", "", "never XTLua's currentFMSID")

T.done()
