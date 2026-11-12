-- Run from the repository root with LuaJIT: luajit tests/fms/appr_no_rwy_test.lua
-- (2026-11-12 review FMC-1) An approach with no runway waypoint (a localizer
-- approach whose MAP is before the threshold), in the FMS module as XTLua
-- runs it, on tests/fms/data/navdb_map (the synthetic nav data with ZZAA's
-- L16R: IF ZA002, FAF ZA001, MAP ZA003 400 ft, then the missed approach to
-- ZZV and its hold at 4,000 ft or above). Before, the approach had no
-- runway (nil): the E/D was the missed approach's last constraint (RJAA
-- LOC16R: BINKS 6000A, the T/D 49 NM late), the STAR's runway transition
-- was left out and the ILS not autotuned. Now the runway from the
-- approach's name and the E/D at the MAP (FCOM p.1258: a VOR approach's
-- E/D is its MAP; the others without a runway waypoint the same: estimate).
B747_NAVDB_FOLDER = "tests/fms/data/navdb_map/"
local T = dofile("tests/lib/check.lua")("appr_no_rwy")
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
-- the route ZZAA to ZZAA, DIRECT DELTA, ALPHA1 via DELTA and the L16R, active
key("func_key/index") enter("100", "L5") enter("350", "R1")
key("func_key/fpln")
enter("ZZAA", "L1") enter("ZZAA", "R1")
key("func_key/next_pg")
enter("DELTA", "R1")
local st = ns.B747_fmc_route_num(1)
R.set_arrival(st, {name = "ALPHA1", trans = "DELTA"}, {id = "L16R"})
ns.B747_fmc_route_changed()
key("func_key/fpln") key("ls_key/R6") key("key/execute")
frames(1)
local r = R.shown(st)
T.check(legs(st):match("ZA002 ZA001 ZA003 "), "the route: " .. legs(st))
T.equal(r.appr and r.appr.rwy, "RW16R", "the localizer approach's runway from its name (L16R)")
local s = ns.B747_fms_pred_input(35000)
local edl = s and s.ed and r.legs[s.ed]
T.equal(edl and edl.fix and edl.fix.ident, "ZA003", "the E/D at the MAP ZA003, not in the missed approach")
T.equal(edl and edl.alt, 400, "the E/D's altitude the MAP's 400 ft")

T.done()
