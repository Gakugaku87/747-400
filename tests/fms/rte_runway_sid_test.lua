-- Run from the repository root with LuaJIT: luajit tests/fms/rte_runway_sid_test.lua
-- (2026-11-12 review FMC-4) The RTE page's RUNWAY and DEPARTURES' SID, in
-- the FMS module as XTLua runs it, on the synthetic ZZAA (ZULU1: runway
-- transitions RW16R ZA001 ZZV and RW34L (600) (INTC) ZZV; YANKE1: 16R
-- only). The RTE page's RUNWAY is DEPARTURES' field (FMSPG p.79): a new
-- runway the SID serves puts the SID's legs for it in (before, the old
-- runway's legs stayed; with the SID selected before a runway, none). A
-- SID that does not serve the runway selected: the SID in, the runway out,
-- RUNWAY N/A FOR SID (as ARRIVALS does: FCOM p.1435; estimate; before, the
-- runway stayed, the SID's legs none, no message).
-- rule: estimate).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("rte_runway_sid")
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
local K = "laminar/B747/fms1/"
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
local function legs(st)
    local out = {}
    for _, l in ipairs(R.shown(st).legs) do out[#out + 1] = l.disc and "DISC" or (l.fix and l.fix.ident or l.name or "?") end
    return table.concat(out, " ")
end
local function air()
    rt:set("sim/flightmodel/failures/onground_any", 0)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 0)
    rt:set("sim/cockpit2/gauges/indicators/altitude_ft_pilot", 12000)
    frames(1)
end

local st = ns.B747_fmc_route_num(1)
local function fresh()
    key("func_key/fpln")
    enter("ZZAA", "L1") enter("ZZAA", "R1")
end
-- DEPARTURES' 16R and ZULU1, then the RTE page's 34L
fresh()
R.set_departure(st, "ZULU1", "RW16R", nil)
T.equal(legs(st), "ZA001 ZZV", "ZULU1 from 16R: its runway transition")
key("func_key/fpln")
enter("34L", "L2")
T.equal(R.shown(st).runway and R.shown(st).runway.ident, "RW34L", "the RTE page's RUNWAY 34L")
T.equal(legs(st), "(600) (INTC) ZZV", "ZULU1's legs for 34L (the RTE page's RUNWAY is DEPARTURES' field)")
-- ZULU1 first, no runway; then the RTE page's 34L
R.set_departure(st, nil, nil, nil)
R.edit(st).runway = nil
R.set_departure(st, "ZULU1", nil, nil)
T.equal(legs(st), "", "ZULU1 without a runway: no legs yet")
key("func_key/fpln")
enter("34L", "L2")
T.equal(legs(st), "(600) (INTC) ZZV", "then the RTE page's 34L: ZULU1's legs for it")
-- 34L on DEPARTURES, then YANKE1 (16R only)
R.set_departure(st, nil, nil, nil)
key("func_key/clb") key("ls_key/L1")
key("ls_key/R2")                             -- 34L
T.equal(R.shown(st).runway and R.shown(st).runway.ident, "RW34L", "DEPARTURES' 34L")
key("func_key/clb") key("ls_key/L1")         -- anew: all the options
key("ls_key/L2")                             -- YANKE1
local pad = rt:get("laminar/B747/fms3/Line14_L"):gsub("%s+$", "")
T.equal(R.shown(st).sid and R.shown(st).sid.name, "YANKE1", "YANKE1 selected")
T.equal(R.shown(st).runway, nil, "the runway it does not serve out")
T.equal(pad, "RUNWAY N/A FOR SID", "RUNWAY N/A FOR SID")

T.done()
