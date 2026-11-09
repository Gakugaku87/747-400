-- Run from the repository root with LuaJIT: luajit tests/fms/simconfig_fuel_mgmt_test.lua
-- SIM CONFIG's FUEL MGMT (page 1's 3L; 2026-11-09): the sim's option "Auto
-- fuel management" (Plugins > 747-400, the FMS bridge's laminar/B747/
-- options/auto_fuel_mgmt; the fuel module does it, notes/ATA-28.md §13)
-- shown, and turned over through the bridge's command, which keeps it (the
-- bridge is not here: the test plays it). Before, the livery's
-- simconfig.dat auto_fuel_mgmt.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("simconfig_fuel_mgmt")
local xtlua = dofile("tests/lib/xtlua.lua")

local OPT = "laminar/B747/options/auto_fuel_mgmt"
local TOGGLE = "laminar/B747/options/auto_fuel_mgmt_toggle"
local types = {["xtlua/loadtoFMS"] = "string", [OPT] = "number"}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types, lagged = {OPT}}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
local CFG = "laminar/B747/simconfig"
rt:set(CFG, '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"irs_align_time":600,'
    .. '"std_pax_weight":120,"auto_fuel_mgmt":"NO","baro_indicator":"IN","baro_sync":"NO",'
    .. '"capt_inbd":"NORM","capt_lwr":"NORM","fo_inbd":"NORM","fo_lwr":"NORM"},'
    .. '"PLANE":{"thrust_ref":"EPR","engines":"PW4056","model":"747-400"},'
    .. '"FMC":{"INIT":{"active":"","op_program":"TEST","drag_ff":"+0.0/-0.0"}}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/weight/m_total", 300000)
rt:set("sim/flightmodel/weight/m_fuel_total", 80000)
rt:set("sim/cockpit2/electrical/bus_volts", 0, 28)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
-- the bridge's command: the option turned over (and kept, in X-Plane)
local seen, toggles = 0, 0
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do
        rt:frame(1 / 30)
        while seen < #rt.command_log do
            seen = seen + 1
            local c = rt.command_log[seen]
            if c.name == TOGGLE and c.phase == "once" then
                toggles = toggles + 1
                rt:set(OPT, 1 - rt:get(OPT))
            end
        end
    end
end
frames(4)
local K, D = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", D, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", D, n)) end
local function pad() return (line(14):gsub("%s+$", "")) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function type_in(text)
    for ch in text:gmatch(".") do rt:command(K .. "alphanum_key/" .. ch) end
    frames(0.3)
end

key("ls_key/L1")
key("func_key/fix")
key("ls_key/R6")
T.check(line(1):find("SIM CONFIG", 1, true) ~= nil, "MENU's R6: SIM CONFIG")
local function fuel() return line(7):sub(1, 5) end
T.equal(fuel(), " NO  ", "3L: NO (the option off)")
T.check(small(7):find("/YES", 1, true) ~= nil, "and /YES in small: " .. small(7))
T.check(small(6):find("FUEL MGMT", 1, true) ~= nil, "its label: " .. small(6))

-- the key alone: the bridge's command, the option on
key("ls_key/L3")
frames(0.3)
T.equal(toggles, 1, "3L: the bridge's toggle command")
T.equal(fuel(), " YES ", "3L: YES")
T.check(small(7):find("/NO", 1, true) ~= nil, "and /NO in small")
T.equal(pad(), "", "the scratchpad empty")
T.equal(rt:get(CFG):find('"auto_fuel_mgmt":"NO"', 1, true) ~= nil, true, "the livery's simconfig not changed")

-- YES with the option on: nothing; NO: off
type_in("YES")
key("ls_key/L3")
T.equal(toggles, 1, "YES with the option on: no command")
T.equal(pad(), "", "the scratchpad cleared")
type_in("NO")
key("ls_key/L3")
frames(0.3)
T.equal(toggles, 2, "NO: the command")
T.equal(fuel(), " NO  ", "3L: NO")
-- the option changed from the menu: shown
rt:set(OPT, 1)
frames(0.3)
T.equal(fuel(), " YES ", "the menu's change shown")
-- anything else: INVALID ENTRY, nothing sent
type_in("X")
key("ls_key/L3")
T.equal(pad(), "INVALID ENTRY", "X: INVALID ENTRY")
T.equal(toggles, 2, "and no command")

T.done()
