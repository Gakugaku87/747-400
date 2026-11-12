-- Run from the repository root with LuaJIT: luajit tests/fms/arr_active_leg_test.lua
-- (2026-11-12 review FMC-2) An arrival changed while it is being flown, in
-- the FMS module as XTLua runs it (tests/lib/xtlua.lua), on the synthetic
-- ZZAA (STAR ALPHA1 via DELTA: DELTA ALPHA ZZV, then the ILS 16R). Before, a
-- new approach (a runway change) on ARRIVALS took out every leg of the
-- procedures and put the whole arrival back from its start: the waypoints
-- passed came back in front, LNAV went off its path (WSSS in X-Plane: the
-- active waypoint 45 NM behind, LNAV to heading hold, 8.8 NM off in 45 s);
-- a new DEST left no leg at all (LNAV invalid). Now the active leg stays and
-- the new arrival goes on from its waypoint (FMSPG p.79 (3.2-19): the legs
-- of the procedure after the active leg are cleared; ARRIVALS by the same
-- rule: estimate).
B747_NAVDB_FOLDER = "tests/fms/data/navdb/"
local T = dofile("tests/lib/check.lua")("arr_active_leg")
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

-- the route ZZAA to ZZAA, DIRECT DELTA, ALPHA1 via DELTA and the ILS 16R, active
local function setup()
    rt:set("sim/flightmodel/failures/onground_any", 1)
    rt:set("laminar/B747/gear/air_ground/pri_gnd", 1)
    frames(1)
    key("func_key/index") enter("100", "L5") enter("350", "R1")
    key("func_key/fpln")
    enter("ZZAA", "L1") enter("ZZAA", "R1")
    key("func_key/next_pg")
    enter("DELTA", "R1")
    local st = ns.B747_fmc_route_num(1)
    R.set_arrival(st, {name = "ALPHA1", trans = "DELTA"}, {id = "I16R"})
    ns.B747_fmc_route_changed()
    key("func_key/fpln") key("ls_key/R6") key("key/execute")
    frames(1)
    return st
end

local st = setup()
local full = legs(st)
T.check(full:match("^DELTA ALPHA ZZV "), "the route: " .. full)
-- in the air on the leg ALPHA to ZZV, 8 nm past ALPHA, LNAV engaged
local fix = {}
for _, l in ipairs(st.rte.legs) do if l.fix and not fix[l.fix.ident] then fix[l.fix.ident] = l.fix end end
local PM = ns.B747_path_model
local c = PM.course(fix.ALPHA, fix.ZZV)
local p = PM.point(fix.ALPHA, c, 8)
rt:set("sim/flightmodel/position/latitude", p.lat)
rt:set("sim/flightmodel/position/longitude", p.lon)
rt:set("sim/flightmodel/position/hpath", c)
rt:set("sim/flightmodel/position/psi", c)
rt:set("sim/flightmodel2/position/groundspeed", 128.6)
rt:set("sim/flightmodel/position/true_airspeed", 128.6)
air()
R.sequence(st, 2) ns.B747_fmc_route_changed()
rt:set("laminar/B747/autopilot/lnav_state", 2)
frames(2)
T.check(legs(st):match("^ZZV "), "DELTA and ALPHA passed: ZZV the active waypoint (" .. legs(st) .. ")")

-- the approach selected again on ARRIVALS (the runway change's selection), EXEC
R.set_arrival(st, nil, {id = "I16R"})
ns.B747_fmc_route_changed()
key("key/execute") frames(2)
local after = legs(st)
T.check(after:match("^ZZV "), "ARRIVALS while flying the STAR: the active waypoint ZZV stays (" .. after .. ")")
T.check(not after:match("DELTA") and not after:match("ALPHA "), "the waypoints passed do not come back (" .. after .. ")")
T.equal(after, full:gsub("^DELTA ALPHA ", ""), "the arrival on from the active waypoint")

-- a new DEST while flying the STAR (a diversion): the active leg stays
R.set_dest(st, ns.B747_route_model and "ZZBB" or "ZZBB")
ns.B747_fmc_route_changed()
key("key/execute") frames(2)
local div = legs(st)
T.check(div:match("^ZZV"), "a new DEST while flying the STAR: the active leg stays (" .. div .. ")")
T.equal(R.shown(st).dest and R.shown(st).dest.ident, "ZZBB", "the new DEST")

T.done()
