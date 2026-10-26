-- Run from the repository root with LuaJIT: luajit tests/fms/takeoff_speeds_test.lua
-- The takeoff speeds (6-1/6-2 step 3b-1; FCOM p.1318-1320): the flight
-- instruments compute them (airspeed/V1_ref, Vr_ref, V2_ref) from the
-- TAKEOFF REF flaps, the FMC's gross weight and an aligned IRU; TAKEOFF
-- REF shows them small with REF and the caret until selected or entered,
-- then large, and sends the selected ones to the PFD (airspeed/V1, Vr,
-- V2); a new flap setting, a GR WT or ZFW entry, and after the third
-- engine start a computed speed changing by more than 1 kt delete them
-- (TAKEOFF SPEEDS DELETED). Both modules as XTLua runs them
-- (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("takeoff_speeds")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:set("laminar/B747/irs/mode", 0, 2)                  -- an IRU aligned (NAV)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
local function small(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_S", n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command("laminar/B747/fms1/" .. k) frames(0.2) end
local function type_in(text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command("laminar/B747/fms1/" .. k)
    end
    frames(0.1)
end
local function clear() for _ = 1, 30 do rt:command("laminar/B747/fms1/key/clear") end frames(0.1) end
local function A(n) return rt:get("laminar/B747/airspeed/" .. n) end

-- PERF INIT's ZFW: the FMC's gross weight 320 t
key("func_key/index")
type_in("220")
key("ls_key/L3")
-- TAKEOFF REF
key("ls_key/L6")                                       -- INIT/REF INDEX
key("ls_key/L5")                                       -- TAKEOFF
T.check(line(1):find("TAKEOFF REF"), "TAKEOFF REF: " .. line(1))
T.check(line(3):find("%*%*") and line(3):find("%-%-%-$"), "no flaps: boxes, V1 dashes: " .. line(3))
T.equal(A("V1_ref"), 999, "no flaps: no computed V1")
T.equal(A("V1"), 999, "nothing on the PFD (NO V SPD)")
type_in("10")
key("ls_key/L1")
local v1r, vrr, v2r = A("V1_ref"), A("Vr_ref"), A("V2_ref")
T.check(v1r > 100 and v1r < 200 and vrr >= v1r and v2r > vrr, string.format("flaps 10, 320 t: computed %d/%d/%d", v1r, vrr, v2r))
T.check(small(3):find(string.format("%3d>$", v1r)) and small(2):find("REF V1$"), "V1 small with REF and the caret: " .. small(3) .. "|" .. small(2))
T.equal(A("V1"), 999, "not selected: still NO V SPD (before: straight to the PFD)")
key("ls_key/R1")
key("ls_key/R2")
key("ls_key/R3")
T.check(line(3):find(string.format("%3d$", v1r)) and small(2):find(" V1$") and not small(2):find("REF"), "V1 selected: large, no REF: " .. line(3))
T.check(A("V1") == v1r and A("Vr") == vrr and A("V2") == v2r, "the selected speeds on the PFD")
-- a new flap setting deletes them
type_in("20")
key("ls_key/L1")
T.equal(pad(), "TAKEOFF SPEEDS DELETED", "flaps 20 after the selection: TAKEOFF SPEEDS DELETED (FCOM p.1319)")
T.equal(A("V1"), 999, "the PFD's V1 deleted")
T.check(A("V1_ref") ~= v1r or A("V2_ref") ~= v2r, "flaps 20's computed speeds")
clear()
-- a crew entry; out of range; DELETE
type_in("150")
key("ls_key/R1")
T.check(line(3):find("150$") and A("V1") == 150, "V1 150 entered: large, on the PFD")
type_in("99")
key("ls_key/R1")
T.equal(pad(), "INVALID ENTRY", "V1 99: INVALID ENTRY (100 to 300)")
clear()
key("key/del")
key("ls_key/R1")
T.check(A("V1") == 999 and small(3):find(">$"), "DELETE: the computed V1 again, small")
-- a ZFW entry deletes them, the flaps stay
key("ls_key/R1")
key("ls_key/R2")
key("ls_key/R3")
T.check(A("V1") < 999, "selected again")
key("func_key/index")                                 -- PERF INIT
type_in("210")
key("ls_key/L3")
T.equal(pad(), "TAKEOFF SPEEDS DELETED", "ZFW after the selection: TAKEOFF SPEEDS DELETED (FCOM p.1310)")
T.check(A("V1") == 999 and A("flapsRef") == 20, "the speeds gone, the flaps stay (before: the flaps reset)")
clear()
-- after the third engine start, a computed speed changing by more than 1 kt
key("ls_key/L6")
key("ls_key/L5")
key("ls_key/R1")
key("ls_key/R2")
key("ls_key/R3")
for i = 0, 2 do rt:set("sim/flightmodel/engine/ENGN_running", i, 1) end
frames(0.5)
T.check(A("V1") < 999, "three engines running, nothing changed: the speeds stay")
rt:set("sim/flightmodel/weight/m_fuel_total", 60000)   -- 40 t less: the speeds change
frames(0.5)
T.equal(pad(), "TAKEOFF SPEEDS DELETED", "the computed speeds changed by more than 1 kt: deleted (FCOM p.1320)")
T.equal(A("V1"), 999, "and off the PFD")
clear()
-- no aligned IRU: no computed speeds
rt:set("laminar/B747/irs/mode", 0, 0)
frames(0.5)
T.equal(A("V1_ref"), 999, "no IRU aligned: dashes (FCOM p.1319)")

T.done()
