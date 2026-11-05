-- Run from the repository root with LuaJIT: luajit tests/fms/paxcargo_keys_test.lua
-- (2026-11-05 review) the sim's PAX/CARGO page (MENU > GROUND HANDLING >
-- PAX/CARGO, the upstream loading page) through the CDU keys in the FMS
-- module as XTLua runs it, and the CDU key's safety net
-- (B744.createfms.lua): a fractional passenger count looped for ever in the
-- round robin (XTLua's thread stuck), "3A" and the like did arithmetic on
-- nil (every module of the plugin stopped). Now INVALID ENTRY; a Lua error
-- in any key's function refuses the key instead of stopping the plugin.
local T = dofile("tests/lib/check.lua")("paxcargo_keys")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462,"std_pax_weight":120.0},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
rt:set("sim/flightmodel/failures/onground_any", 1)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/weight/m_fuel_total", 100000)
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)
local function line(n) return rt:get(string.format("laminar/B747/fms3/Line%02d_L", n)) end
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
local function pax(name)
    return tonumber(rt:get("laminar/B747/fms/data"):match('"' .. name .. '":"%s*(%d*)')) or 0
end
local function pax_total()
    return pax("paxFirstClassA") + pax("paxBusClassB") + pax("paxEconClassC") + pax("paxEconClassD") + pax("paxEconClassE")
end

key("func_key/fix")      -- MENU
key("ls_key/R4")         -- GROUND HANDLING
key("ls_key/R3")         -- PAX/CARGO
T.check(line(1):find("PAX"), "MENU > GROUND HANDLING > PAX/CARGO: " .. line(1))
type_in("30")
key("ls_key/L1")
T.equal(pax_total(), 30, "30 passengers on L1: shared round the five zones")
T.equal(pax("paxFirstClassA"), 6, "six in zone A")
type_in("30.5")
key("ls_key/L1")
T.equal(pad(), "INVALID ENTRY", "30.5 passengers: INVALID ENTRY (before, the round robin looped for ever)")
clear()
T.equal(pax_total(), 30, "the 30 kept")
type_in("3A")
key("ls_key/L1")
T.equal(pad(), "INVALID ENTRY", "3A on L1: INVALID ENTRY (before, arithmetic on nil stopped the plugin)")
clear()
-- the safety net: L2's handler still does arithmetic on tonumber("3A");
-- outside the tests' strict mode the key is refused, the plugin runs on
B747_TEST_STRICT = false
type_in("3A")
key("ls_key/L2")
B747_TEST_STRICT = true
T.equal(pad(), "INVALID ENTRY", "3A on L2: the key's Lua error refused as INVALID ENTRY (before, every module stopped)")
clear()
type_in("12")
key("ls_key/L2")
T.equal(pax("paxBusClassB"), 12, "the next key works: 12 in zone B")
frames(1)
T.check(line(1):find("PAX"), "the FMC still draws its pages")
T.done()
