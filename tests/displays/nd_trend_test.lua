-- Run from the repository root with LuaJIT: luajit tests/displays/nd_trend_test.lua
-- The ND's position trend vector (5-2 step 5e, FCOM p.1147): the ND model
-- (plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.nd_model.lua:
-- the 30 s segments at the ground speed, the turn of the bank angle, the
-- segments by range, MAP only, along the track on the display: the
-- model's 405 heading up MAP, which no airplane uses, turns it by the
-- drift), then the display glue in the flight instruments module as XTLua
-- runs it (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("nd_trend")
local NM = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.nd_model.lua")
local xtlua = dofile("tests/lib/xtlua.lua")
local function near(a, b, tol) return type(a) == "number" and math.abs(a - b) <= tol end

local o = {tv_show = {}, tv_x = {}, tv_y = {}, tv_rot = {}, tv_frame = {}}
local function shown()
    local n = 0
    for k = 1, NM.TV_N do if o.tv_show[k] then n = n + 1 end end
    return n
end
-- straight at 240 kt, 40 NM: a segment is 3,704 m (23.3 px), a dash 70 %
-- of it in 3 pieces of 864 m (5.4 px)
NM.trend(o, true, 240, 0, 40)
T.equal(shown(), 9, "40 NM: three segments of three pieces")
local px_m = 465 / (40 * 1852)
T.check(near(o.tv_x[1], 0, 1e-9) and near(o.tv_y[1], 432 * px_m, 0.01) and near(o.tv_rot[1], 0, 1e-9),
    "straight: the first piece up the track from the airplane")
T.equal(o.tv_frame[1], 3, "5.4 px: the 4th frame (1.5 px a step)")
T.check(near(o.tv_y[4] - o.tv_y[1], 3704 * px_m, 0.01), "the next segment 30 s later (3,704 m)")
T.check(near(o.tv_y[2] - o.tv_y[1], 864 * px_m, 0.01) and near(o.tv_y[4] - o.tv_y[3], (3704 - 2 * 864) * px_m, 0.02),
    "pieces end to end, the dash's 30 % gap before the next segment")
NM.trend(o, true, 240, 0, 20)
T.check(shown() == 6 and not o.tv_show[7], "20 NM: two segments (FCOM p.1147)")
NM.trend(o, true, 240, 0, 10)
T.check(shown() == 3 and not o.tv_show[4], "10 NM: one segment")
-- a right turn at 25 degrees and 250 kt: a radius of 3,617 m, 61 degrees a
-- segment
NM.trend(o, true, 250, 25, 40)
local gs = 250 * 1852 / 3600
local r = gs * gs / (9.80665 * math.tan(math.rad(25)))
-- the third piece's middle: between its ends, 2 and 3 steps along the arc
local step = gs * 30 * 0.7 / 3
local x = (r * (1 - math.cos(2 * step / r)) + r * (1 - math.cos(3 * step / r))) / 2
local y = (r * math.sin(2 * step / r) + r * math.sin(3 * step / r)) / 2
T.check(o.tv_x[3] > 0 and near(o.tv_x[3], x * px_m, 0.05) and near(o.tv_y[3], y * px_m, 0.05),
    "right bank: the pieces curve right along the turn (radius gs^2 / g tan bank)")
T.check(o.tv_rot[3] > 25 and o.tv_rot[3] < 45 and o.tv_rot[7] > 90, "turned along it: 35 degrees by the first dash's end, past 90 by the third")
NM.trend(o, true, 250, -25, 40)
T.check(o.tv_x[3] < 0 and o.tv_rot[3] < 0, "left bank: to the left")
NM.trend(o, false, 250, 0, 40)
T.equal(shown(), 0, "not in MAP or no track: none")
NM.trend(o, true, 0, 0, 40)
T.equal(shown(), 0, "standing still: none")
-- a heading up MAP (the model's 405): from the airplane symbol along the
-- track, here 6 degrees right of the top
NM.trend(o, true, 240, 0, 40, 6)
local y1 = 432 * px_m
T.check(near(o.tv_x[1], y1 * math.sin(math.rad(6)), 0.01) and near(o.tv_y[1], y1 * math.cos(math.rad(6)), 0.01)
    and near(o.tv_rot[1], 6, 1e-9), "turned by the drift: the first piece 6 degrees right")

-- the ND model: MAP and MAP CTR only, with the track
local s = NM.new()
local inp = NM.inputs()
inp.gs_kt = 240
for p = NM.CAPT, NM.FO do inp.side[p].mode = NM.MAP end
inp.side[NM.FO].mode = NM.VOR
local out = NM.update(s, inp, 0.1)
local function n_of(side) local n = 0 for k = 1, NM.TV_N do if side.tv_show[k] then n = n + 1 end end return n end
T.check(n_of(out[NM.CAPT]) == 9 and n_of(out[NM.FO]) == 0, "the Captain's MAP: shown; the F/O's VOR: none")
-- MAP CTR: the selected range the compass rose, half the expanded scale
-- (2026-10-28)
local y_exp = out[NM.CAPT].tv_y[4]
inp.side[NM.CAPT].center = true
out = NM.update(s, inp, 0.1)
T.check(n_of(out[NM.CAPT]) == 9 and near(out[NM.CAPT].tv_y[4], y_exp / 2, 1e-6), "MAP CTR: shown at half the scale")
inp.side[NM.CAPT].center = false
inp.side[NM.CAPT].trk_valid = false
out = NM.update(s, inp, 0.1)
T.equal(n_of(out[NM.CAPT]), 0, "no track (TRK flag): none")
-- the model's 405 (heading up) turns it by the drift, the 109 and the 570
-- (track up) not
inp.side[NM.CAPT].trk_valid = true
inp.side[NM.CAPT].hdg, inp.side[NM.CAPT].trk = 100, 106
inp.track_map = false
out = NM.update(s, inp, 0.1)
T.check(near(out[NM.CAPT].tv_rot[1], 6, 1e-9) and out[NM.CAPT].tv_x[1] > 0,
    "the 405's MAP: along the track, 6 degrees right of the heading up")
inp.track_map = true
out = NM.update(s, inp, 0.1)
T.check(near(out[NM.CAPT].tv_rot[1], 0, 1e-9) and near(out[NM.CAPT].tv_x[1], 0, 1e-9),
    "the 109's and the 570's MAP (track up): straight up")

-- the display glue
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
for k = 0, 2 do                                                    -- the IRUs aligned (the PFD model's track)
    rt:set("laminar/B747/irs/att_valid", k, 1)
    rt:set("laminar/B747/irs/hdg_valid", k, 1)
    rt:set("laminar/B747/irs/nav_valid", k, 1)
end
rt:set("sim/flightmodel2/position/groundspeed", 128.6)             -- 250 kt
rt:set("sim/cockpit2/gauges/indicators/roll_AHARS_deg_pilot", 25)
rt:callout("flight_start")
rt:set("laminar/B747/nd/mode/capt/sel_dial_pos", 2)                -- MAP (after the load's settings)
rt:set("laminar/B747/nd/range/capt/sel_dial_pos", 2)               -- 40 NM
rt:set("laminar/B747/nd/mode/fo/sel_dial_pos", 1)                  -- VOR
for _ = 1, 15 do rt:frame(1 / 30) end
local C = "laminar/B747/nd/capt/"
local n = 0
for k = 0, 8 do n = n + rt:get(C .. "tv_show", k) end
T.equal(n, 9, "the glue: the Captain's ND at 40 NM, 9 pieces")
T.check(rt:get(C .. "tv_x", 2) > 0 and rt:get(C .. "tv_rot", 2) > 25, "curving right with the Captain's 25 degrees of bank")
n = 0
for k = 0, 8 do n = n + rt:get("laminar/B747/nd/fo/tv_show", k) end
T.equal(n, 0, "the F/O's ND in VOR: none")

T.done()
