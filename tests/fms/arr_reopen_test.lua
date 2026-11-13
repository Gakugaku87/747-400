-- Run from the repository root with LuaJIT: luajit tests/fms/arr_reopen_test.lua
-- (2026-11-13; finding 8 of the 2026-11-12 review) ARRIVALS opened again
-- on an inactive route after a STAR's selection: all the options again, the
-- selection's <SEL> by it (FCOM p.1302: leaving the page and returning
-- displays all options and <SEL> or <ACT> prompts). s299's second run
-- opened it again and waited for SULP1D<SEL> at the top of page 1; the
-- page showed the whole list from AKSE1A there, as it should, SULP1D on
-- page 9. In the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the
-- synthetic CIFP of ZZAA (two STARs, ALPHA1 and BRAVO1).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("arr_reopen")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {["xtlua/loadtoFMS"] = "string"}
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
rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
for _, b in ipairs({"xfr_capt", "xfr_fo", "stby_apu"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end -- the FMCs' power
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

local K, LN = "laminar/B747/fms1/", "laminar/B747/fms3/"
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do rt:command(K .. "alphanum_key/" .. ch) end
    frames(0.1)
    key("ls_key/" .. lsk)
end

-- RTE 1 ZZAA to ZZAA, DIRECT ALPHA, DIRECT DELTA, not activated
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")                 -- SELECT DESIRED WPT: the nearer ALPHA
enter("DELTA", "R2")
key("func_key/clb")
T.check(line(1):find("DEP/ARR INDEX"), "no active route: the DEP ARR key's INDEX: " .. line(1))
key("ls_key/R2")
T.check(line(1):find("ZZAA ARRIVALS"), "ZZAA ARRIVALS: " .. line(1))
T.equal(line(3), "ALPHA1            ILS16R", "the STARs: ALPHA1")
T.equal(line(5), "BRAVO1                  ", "and BRAVO1")
key("ls_key/L1")
T.equal(line(3), "ALPHA1<SEL>       ILS16R", "ALPHA1: <SEL>")
T.check(not line(5):find("BRAVO1"), "the other STAR no longer shows: " .. line(5))
-- away to LEGS and back by DEP ARR, the INDEX, ARR>
key("func_key/legs")
T.check(line(1):find("RTE 1 LEGS"), "LEGS: " .. line(1))
key("func_key/clb")
key("ls_key/R2")
T.check(line(1):find("ZZAA ARRIVALS"), "ARRIVALS again: " .. line(1))
T.equal(line(3), "ALPHA1<SEL>       ILS16R", "returning: ALPHA1 with its <SEL> (FCOM p.1302)")
T.equal(line(5), "BRAVO1                  ", "and all the options again: BRAVO1")
T.done()
