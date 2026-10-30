-- Run from the repository root with LuaJIT: luajit tests/fms/wind_page_test.lua
-- The WIND pages (6-1/6-2 step 8e1; notes/ATA-34-61-FMC.md §51; FCOM
-- p.1363-1366, FMSPG p.121-124) in the FMS module as XTLua runs it
-- (tests/lib/xtlua.lua), on the synthetic CIFP of ZZAA: RTE DATA's 1R to
-- the waypoint's WIND page, its layout (FCOM p.1365's figure), a new
-- altitude at 1L, DIR/SPD at this waypoint (large) and propagated on the
-- next one (small), an ALT/OAT entry and the OATs by the standard lapse
-- rate, four altitudes at most, DELETE, NEXT and PREV PAGE along the
-- route, RTE DATA> back with W> at the waypoint, the modification's legs
-- getting the entries too.
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("wind_page")
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
rt:set("sim/flightmodel/position/latitude", 35)
rt:set("sim/flightmodel/position/longitude", 140)
rt:set("sim/flightmodel/weight/m_total", 250000)
rt:set("sim/flightmodel/weight/m_fuel_total", 40000)
rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 100)
rt:set("sim/cockpit2/temperature/outside_air_temp_degc", 15 - 1.98 * 0.1)
for _, v in ipairs({"V1", "Vr", "V2"}) do rt:set("laminar/B747/airspeed/" .. v, 999) end
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
local function line(n) return rt:get(string.format("%sLine%02d_L", LN, n)) end
local function small(n) return rt:get(string.format("%sLine%02d_S", LN, n)) end
local function key(k) rt:command(K .. k) frames(0.3) end
local function enter(text, lsk)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or ch == "-" and "key/minus" or "alphanum_key/" .. ch
        rt:command(K .. k)
    end
    frames(0.1)
    key("ls_key/" .. lsk)
end
local function pad() return (line(14):gsub("%s+$", "")) end
local function clear() for _ = 1, 30 do rt:command(K .. "key/clear") end frames(0.1) end
local function delete(lsk) clear() rt:command(K .. "key/del") frames(0.1) key("ls_key/" .. lsk) end

-- the route: ZZAA to ZZAA, DIRECT ALPHA, DELTA; ZULU1 from 34L by ALPHA;
-- ALPHA1 by DELTA to the ILS 16R; ACTIVATE and EXEC
key("func_key/fpln")
enter("ZZAA", "L1")
enter("ZZAA", "R1")
key("func_key/next_pg")
enter("ALPHA", "R1")
key("ls_key/L1")
enter("DELTA", "R2")
key("func_key/clb")
key("ls_key/L1")                 -- DEPARTURES
key("ls_key/L1")                 -- ZULU1
key("ls_key/R2")                 -- 34L
key("ls_key/L2")                 -- ALPHA
key("ls_key/L6")                 -- INDEX
key("ls_key/R2")                 -- ARRIVALS
key("ls_key/L1")                 -- ALPHA1
key("ls_key/L2")                 -- DELTA
key("ls_key/R1")                 -- ILS16R
key("func_key/fpln")
key("ls_key/R6")                 -- ACTIVATE
key("key/execute")
frames(1)
local st = fms.ns.B747_fmc_route
T.check(st.active, "the route active")
local W = fms.ns.B747_wind_model
local legs = st.rte.legs
local n = 0
for _, l in ipairs(legs) do if not (l.disc or l.pending) then n = n + 1 end end

-- RTE DATA (the active LEGS page's 6R), 1R: the first waypoint's WIND page
key("func_key/legs")
key("ls_key/R6")
T.check(line(3):find(" >$"), "RTE DATA: > at 1R without winds: " .. line(3))
key("ls_key/R1")
local name1 = fms.ns.B747_route_model.leg_name(legs[1])
T.check(line(1):find(name1 .. " WINDS", 1, true), "1R: the first waypoint's WIND page: " .. line(1))
T.equal(small(1), string.format("%23s ", "1/" .. n), "page 1 of the route's " .. n .. " waypoints")
T.equal(small(2), " ALT    OAT      DIR/SPD", "its titles (FCOM p.1365)")
T.equal(line(3), "-----" .. string.rep(" ", 19), "1L: dashes for an altitude")
T.equal(line(11), string.format("%23s ", "-----/---`"), "5R: ALT/OAT dashed")
T.equal(small(10), string.rep(" ", 17) .. "ALT/OAT", "its title")
T.equal(small(11):sub(24, 24), "C", "C small")
T.equal(line(12), string.rep("-", 24), "the line above 6")
T.check(line(13):find("RTE DATA>$"), "6R RTE DATA>")

-- FL350 at 1L: at the bottom row, DIR/SPD dashed, the standard day's OAT small
enter("FL350", "L1")
T.equal(pad(), "", "FL350 accepted")
T.equal(line(9), "FL350         ---`/---  ", "4L FL350, 4R dashed: " .. line(9))
T.equal(small(9), "       -54`C          KT", "the standard day's -54 C small, C and KT small: " .. small(9))
T.equal(line(3), "-----" .. string.rep(" ", 19), "1L dashed still")
-- 270/50 at 4R: large here
enter("270/50", "R4")
T.equal(line(9), "FL350         270`/ 50  ", "270/50 large: " .. line(9))
-- the next waypoint: propagated, small
key("func_key/next_pg")
T.equal(small(1), string.format("%23s ", "2/" .. n), "NEXT PAGE: the second waypoint")
T.equal(small(9), "       -54`C  270`/ 50KT", "the wind propagated, small: " .. small(9))
T.equal(line(9), "FL350                   ", "nothing large but the altitude: " .. line(9))
-- ALT/OAT FL300/-40 here: FL350's OAT -50 by the lapse rate, large here
enter("FL300/-40", "R5")
T.equal(line(11), string.format("%23s ", "FL300/-40`"), "5R: the entry: " .. line(11))
T.equal(line(9):sub(8, 11), "-50`", "FL350's OAT from it, large: " .. line(9))
-- PREV PAGE: propagated back to the first waypoint, small
key("func_key/prev_pg")
T.equal(small(9):sub(8, 12), "-50`C", "the first entry back to the first waypoint, small: " .. small(9))
T.equal(line(11), string.format("%23s ", "-----/---`"), "its 5R dashed")
-- an OAT out of the limits (FMSPG p.122): INVALID ENTRY
enter("FL300/-90", "R5")
T.equal(pad(), "INVALID ENTRY", "-90 C: INVALID ENTRY")
clear()

-- four altitudes, the highest first; no fifth; 1L the highest then
enter("FL390", "L1")
enter("FL310", "L1")
enter("FL200", "L1")
T.check(line(3):find("^FL390") and line(5):find("^FL350") and line(7):find("^FL310") and line(9):find("^FL200"),
    "four altitudes, high to low: " .. line(3) .. "|" .. line(5) .. "|" .. line(7) .. "|" .. line(9))
enter("FL100", "L1")
T.equal(pad(), "INVALID ENTRY", "a fifth: INVALID ENTRY (FCOM p.1365)")
clear()
enter("FL100", "L3")
T.equal(pad(), "INVALID ENTRY", "an altitude over another: INVALID ENTRY (delete it first: FMSPG p.122)")
clear()
-- DELETE FL350 (2L): it and its winds go everywhere
delete("L2")
T.equal(#W.alts(st.rte), 3, "FL350 deleted")
T.check(not line(5):find("FL350") and line(3):find("^%-%-%-%-%-"), "1L dashed again, FL350 gone: " .. line(3) .. "|" .. line(5))
T.equal(W.wind(st.rte, 1, 35000), nil, "its wind at the first waypoint gone")
-- FL350 again, 270/50 again; DELETE the wind
enter("FL350", "L1")
local row350
for row = 1, 4 do if line(row * 2 + 1):find("^FL350") then row350 = row end end
enter("270/50", "R" .. row350)
T.check(line(row350 * 2 + 1):find("270`/ 50"), "270/50 at FL350 again")
delete("R" .. row350)
T.check(line(row350 * 2 + 1):find("%-%-%-`/%-%-%-"), "DELETE: none (no other entry): " .. line(row350 * 2 + 1))
enter("270/50", "R" .. row350)
enter("361/50", "R" .. row350)
T.equal(pad(), "INVALID ENTRY", "361 degrees: INVALID ENTRY")
clear()
enter("90/50", "R" .. row350)
T.equal(pad(), "INVALID ENTRY", "a two-digit direction: INVALID ENTRY (FMSPG p.179)")
clear()
enter("090/251", "R" .. row350)
T.equal(pad(), "INVALID ENTRY", "251 kt: INVALID ENTRY")
clear()
T.equal(fms.ns.B747_fms_trans_lvl(), 14000, "the descent's transition level: the destination ZZAA's FL140 (FMSPG p.178)")

-- RTE DATA>: back, W> at the first waypoint
key("ls_key/R6")
T.check(line(1):find("ACT RTE 1 DATA"), "RTE DATA>: " .. line(1))
T.check(line(3):find("W>$"), "W> at the first waypoint (FCOM p.1363): " .. line(3))
T.check(line(5):find(" >$"), "> at the second (its OAT only): " .. line(5))

-- a modification (the route edited on another CDU): the entries on its
-- legs too, kept by EXEC
key("ls_key/R1")                 -- the first waypoint's WIND page again
fms.ns.B747_route_model.edit(st)
T.check(st.mod ~= nil, "a modification")
local i2
for i, l in ipairs(st.mod.legs) do if l.orig == (st.rte.legs[1].orig or st.rte.legs[1]) then i2 = i end end
T.check(i2 and W.wind(st.mod, i2, 35000) == 270, "the modification's copy of the first leg has its wind")
enter("090/20", "R" .. row350)
T.check(i2 and W.wind(st.mod, i2, 35000) == 90, "an entry now: on the modification's leg too")
T.equal(W.wind(st.rte, 1, 35000), 90, "and the active route's")
fms.ns.B747_route_model.exec(st)  -- (EXEC: the key needs a change to light)
T.check(st.mod == nil and W.wind(st.rte, 1, 35000) == 90, "after EXEC the active route has it")
T.equal(#W.alts(st.rte), 4, "and the four altitudes")

T.done()
