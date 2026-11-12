-- Run from the repository root with LuaJIT: luajit tests/fms/arr_change_test.lua
-- ARRIVALS: the arrival changed to the other end's runways (2026-11-12;
-- notes/ATA-34-61-FMC.md §166; FCOM p.1403, p.1435) in the FMS module as
-- XTLua runs it (tests/lib/xtlua.lua), on the synthetic ZZSS. As WSSS, each
-- of its STARs is for one end's runways alone (KILO2A: RW02B, the 02L and
-- the 02C; KILO2B: RW20B, the 20C and the 20R) and it has approaches to
-- both ends. The user's flight (FAOR to WSSS, 2026-11-12): with a 20 STAR
-- and a 20 approach in the route neither a 02 STAR nor a 02 approach could
-- be selected (each rejected with ARR N/A FOR RUNWAY for the other).
-- Now the one selected goes in and the other out of the route, with ARR
-- N/A FOR RUNWAY: on an inactive route, on the active route after EXEC
-- (ERASE brings the pair back) and before it, on RTE 2; a pair that goes
-- together stays as it is, without the message.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("arr_change")
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
local function key(k) rt:command(K .. k) frames(0.3) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function enter(text, lsk)
    clear()
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function pad() return (line(14):gsub("%s+$", "")) end
local R = fms.ns.B747_route_model
local function st(n) return fms.ns.B747_fmc_route_num(n) end
local function shown(n) return R.shown(st(n)) end
-- the arrival of a route: "STAR/approach" ("-" for none)
local function arr(r) return (r.star and r.star.name or "-") .. "/" .. (r.appr and r.appr.id or "-") end
local function has_fix(r, ident)
    for _, l in ipairs(r.legs) do if l.fix and l.fix.ident == ident then return true end end
    return false
end
-- ARRIVALS anew (all the options again: FCOM p.1302; FMSPG p.194): the
-- DEP ARR key gives the INDEX with no active route and, in the air, the
-- active route's ARRIVALS (its INDEX at 6L with no modification pending);
-- the INDEX's 2R is RTE 1's ARR, 4R RTE 2's
local function arrivals(n)
    clear()
    key("func_key/clb")
    if line(1):find("ARRIVALS", 1, true) then
        if n ~= 2 then return end
        key("ls_key/L6")
    end
    T.check(line(1):find("DEP/ARR INDEX", 1, true) ~= nil, "the DEP/ARR INDEX: " .. line(1))
    key("ls_key/" .. (n == 2 and "R4" or "R2"))
end
local MSG = "ARR N/A FOR RUNWAY"

-- RTE 1: ZZAA to ZZSS, not active yet
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZSS", "R1")
arrivals(1)
T.check(line(1):find("ZZSS ARRIVALS", 1, true), "ZZSS ARRIVALS: " .. line(1))
T.check(line(3):find("^KILO2A") and line(3):find("RNV02L$"), "1L KILO2A, 1R RNV02L: " .. line(3))
T.check(line(5):find("^KILO2B") and line(5):find("RNV02C$"), "2L KILO2B, 2R RNV02C: " .. line(5))
T.check(line(7):find("RNV20C$") and line(9):find("RNV20R$"), "3R RNV20C, 4R RNV20R")

-- an inactive route: the 20 pair, then the 02 approach
key("ls_key/L2")
key("ls_key/R3")
T.equal(arr(shown(1)), "KILO2B/R20C", "KILO2B and the RNV20C: a pair")
T.equal(pad(), "", "no message for a pair that goes together")
arrivals(1)
key("ls_key/R1")
T.equal(pad(), MSG, "the RNV02L with KILO2B: ARR N/A FOR RUNWAY (FCOM p.1435)")
T.equal(arr(shown(1)), "-/R02L", "the RNV02L selected, KILO2B out of the route (before, rejected)")
T.check(line(3):find("^KILO2A") and line(5):find("^KILO2B") and not line(5):find("<", 1, true),
    "all the STARs show again, none selected: " .. line(5))
clear()
key("ls_key/L1")
T.equal(arr(shown(1)), "KILO2A/R02L", "KILO2A with the RNV02L: the 02 pair")
T.equal(pad(), "", "no message")
T.check(has_fix(shown(1), "ZS02I") and has_fix(shown(1), "RW02L") and not has_fix(shown(1), "ZS20I"),
    "the route's legs the 02 arrival's")
-- another approach of the STAR's runways: the STAR stays
arrivals(1)
key("ls_key/R2")
T.equal(arr(shown(1)), "KILO2A/R02C", "the RNV02C with KILO2A (RW02B: the 02L and the 02C): KILO2A stays")
T.equal(pad(), "", "no message")
-- the STAR first: the approach out
arrivals(1)
key("ls_key/L2")
T.equal(pad(), MSG, "KILO2B with the RNV02C: ARR N/A FOR RUNWAY")
T.equal(arr(shown(1)), "KILO2B/-", "KILO2B selected, the RNV02C out of the route (before, rejected)")
T.check(line(3):find("^KILO2B<SEL>") and line(3):find("RNV02L$") and line(9):find("RNV20R$"),
    "KILO2B <SEL>, all the approaches show again: " .. line(3))
clear()
key("ls_key/R4")
T.equal(arr(shown(1)), "KILO2B/R20R", "the RNV20R with KILO2B: the 20 pair")
T.equal(pad(), "", "no message")

-- the active route, after EXEC: the user's flight
key("func_key/fpln")
key("ls_key/R6")
key("key/execute")
T.check(st(1).active and not st(1).mod, "RTE 1 activated and executed")
-- in the air (the DEP ARR key: ARRIVALS)
rt:set("sim/flightmodel/failures/onground_any", 0)
rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
frames(1)
arrivals(1)
T.check(line(5):find("^KILO2B<ACT>") and line(9):find("<ACT>RNV20R$"), "KILO2B and the RNV20R <ACT>: " .. line(5) .. " | " .. line(9))
key("ls_key/R1")
T.equal(pad(), MSG, "active, the RNV02L: ARR N/A FOR RUNWAY")
T.check(st(1).mod and arr(shown(1)) == "-/R02L", "a modification: the RNV02L, KILO2B out (" .. arr(shown(1)) .. ")")
T.equal(arr(st(1).rte), "KILO2B/R20R", "the active route as it was until EXEC")
T.check(line(13):find("^<ERASE"), "ERASE at 6L (FCOM p.1404)")
clear()
key("ls_key/L6")
T.check(not st(1).mod and arr(shown(1)) == "KILO2B/R20R", "ERASE: the pair back")
-- the STAR first, then its approach, EXEC
arrivals(1)
key("ls_key/L1")
T.equal(pad(), MSG, "active, KILO2A: ARR N/A FOR RUNWAY")
T.check(st(1).mod and arr(shown(1)) == "KILO2A/-", "a modification: KILO2A, the RNV20R out (" .. arr(shown(1)) .. ")")
clear()
key("ls_key/R1")
T.equal(arr(shown(1)), "KILO2A/R02L", "the RNV02L: the 02 pair")
T.check(line(3):find("^KILO2A<SEL>") and line(3):find("<SEL>RNV02L$"), "both <SEL>: " .. line(3))
key("key/execute")
T.check(not st(1).mod and arr(st(1).rte) == "KILO2A/R02L", "EXEC: the active route's arrival the 02 pair")
T.check(has_fix(st(1).rte, "RW02L") and not has_fix(st(1).rte, "RW20R"), "its legs to the 02L")

-- before EXEC: a pair selected and not executed, then the other end
arrivals(1)
key("ls_key/R2")
T.check(st(1).mod and arr(shown(1)) == "KILO2A/R02C" and pad() == "", "the RNV02C: a modification, KILO2A stays, no message")
arrivals(1)
key("ls_key/R3")
T.equal(pad(), MSG, "before EXEC, the RNV20C: ARR N/A FOR RUNWAY")
T.equal(arr(shown(1)), "-/R20C", "the RNV20C selected, KILO2A out")
clear()
key("ls_key/L2")
T.equal(arr(shown(1)), "KILO2B/R20C", "KILO2B: the 20 pair")
key("key/execute")
T.check(not st(1).mod and arr(st(1).rte) == "KILO2B/R20C", "EXEC: the 20 pair active")

-- RTE 2 (the INDEX's 4R): the same, RTE 1 as it is
key("func_key/fpln")
key("ls_key/L6")
T.check(line(1):find("RTE 2", 1, true), "RTE 2's page: " .. line(1))
enter("ZZAA", "L1")
enter("ZZSS", "R1")
arrivals(2)
T.check(line(1):find("ZZSS ARRIVALS", 1, true), "RTE 2's ZZSS ARRIVALS")
key("ls_key/L1")
key("ls_key/R1")
T.equal(arr(shown(2)), "KILO2A/R02L", "RTE 2: the 02 pair")
arrivals(2)
key("ls_key/R4")
T.equal(pad(), MSG, "RTE 2, the RNV20R: ARR N/A FOR RUNWAY")
T.equal(arr(shown(2)), "-/R20R", "the RNV20R selected, KILO2A out")
clear()
key("ls_key/L2")
T.equal(arr(shown(2)), "KILO2B/R20R", "RTE 2: the 20 pair")
arrivals(2)
key("ls_key/L1")
T.equal(pad(), MSG, "RTE 2, KILO2A: ARR N/A FOR RUNWAY")
T.equal(arr(shown(2)), "KILO2A/-", "KILO2A selected, the RNV20R out")
T.equal(arr(st(1).rte), "KILO2B/R20C", "RTE 1's arrival as it was")
T.done()
