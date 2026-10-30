-- Run from the repository root with LuaJIT:
--   luajit tests/tools/align_sim.lua [crosswind_kt] [engine_out_rudder] [start_ft] [multi_ft] [y_m]
-- Flies runway align (6-3 step 4d: the roll model's LOC law and its
-- rudder, B747.70.afds_roll_model.lua, and the A/P's inner roll loop as in
-- B747.19.xt.afds_control.lua) on the model of X-Plane's 747 at 150 kt
-- with flaps 30 (tests/tools/lat_model_150kt.lua, fitted to
-- s115_rudder_steps: docs/overhaul/notes/ATA-22.md §29), down a 3 degree
-- glide path to 5 ft: a crosswind from the right (kt, default 20; from the
-- left minus) and an engine out as the rudder it takes (default 0; a left
-- engine out takes right rudder, plus: a yaw moment alone, as much as that
-- rudder's), from start_ft (default 1,500), runway align from multi_ft
-- (the multi-channel engage, default 1,500; above it LOC alone: an engine
-- out before the approach), y_m metres right of the centreline at the start
-- (default 0). Prints the crab, sideslip, bank, rudder, aileron and the
-- distance off the centreline on the way down.
-- (ROLL_MODEL in the environment: another copy of the roll model; GAINS:
-- the roll model's constants to try, "EO_K=0.03,ALIGN_K=0.06")
local R = dofile(os.getenv("ROLL_MODEL") or "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.afds_roll_model.lua")
for k, v in (os.getenv("GAINS") or ""):gmatch("([%w_]+)=([-%d%.]+)") do R[k] = tonumber(v) end
local XW = tonumber(arg[1] or "20")
local EO = tonumber(arg[2] or "0")
local H0 = tonumber(arg[3] or "1500")
local HM = tonumber(arg[4] or "1500")
local Y0 = tonumber(arg[5] or "0")
local A = dofile("tests/tools/lat_model_150kt.lua")

local KT = 1852 / 3600
local DT = 1 / 60
local COURSE = 337
local V = 152 * KT                  -- TAS, m/s
local W = XW * KT                   -- the wind from the right, m/s
-- the inner roll loop (afds_control) at 150 kt: g = (250 / 150)^2
local G = (250 / 150) ^ 2
local KP, KI, KR, KY, HOLD, SETTLE = 0.05, 0.02, 0.04, 0.01, 1, 2

-- the state: beta (X-Plane's), p, r, bank, heading (magnetic), y (m right
-- of the centreline), height (ft); the aileron servo
local x = {b = 0, p = 0, r = 0, phi = 0, hdg = COURSE + math.deg(math.asin(W / V)), y = Y0, h = H0}
local srv, I, lastc, hist, acc, still, cr = 0, 0, nil, {}, 0, 0, 0
local s = R.new()
local inp = R.inputs()
local function track(x)
    local hp = math.rad(x.hdg - x.b - COURSE)
    local vy, vx = V * math.sin(hp) - W, V * math.cos(hp)
    return COURSE + math.deg(math.atan2(vy, vx)), vy, math.sqrt(vx * vx + vy * vy)
end
local t, next_print, cmd = 0, H0, 0
local worst = {bank_down = 0, y = 0}
while x.h > 5 do
    local trk, vy, gs = track(x)
    acc = acc + DT
    if acc >= 1 / 30 - 1e-9 then
        local dt = acc; acc = 0
        inp.mode, inp.active, inp.ground = "LOC", true, false
        inp.bank, inp.hdg, inp.hdg_mag, inp.trk_mag, inp.course = x.phi, x.hdg % 360, x.hdg % 360, trk % 360, COURSE
        inp.loc_dots = -math.deg(math.atan(x.y / R.loc_distance(x.h))) / R.LOC_DOT_DEG
        inp.loc_valid, inp.hdg_valid = true, true
        inp.gs, inp.ra, inp.tas, inp.ias, inp.flaps_up = gs / KT, x.h, V / KT, 150, false
        inp.rwy_align = x.h <= HM
        cmd = R.update(s, inp, dt)
        -- the inner roll loop
        local e = cmd - x.phi
        -- the command's rate smoothed over 0.3 s (afds_control)
        cr = cr + ((lastc and (cmd - lastc) / dt or 0) - cr) * math.min(1, dt / 0.3)
        lastc = cmd
        if math.abs(cr) > HOLD then still = 0 else still = still + dt end
        if still >= SETTLE then I = math.max(-1, math.min(1, I + KI * e * dt)) end
        local out = math.max(-1, math.min(1, KP * e + I + KR * (cr - x.p) - KY * x.r))
        local spd = math.max(3, math.min(5, 3 + (math.abs(e) - 0.1) * 2 / 9.9))
        local step = 2 / spd * dt
        if math.abs(out - srv) <= step then srv = out else srv = srv + (out > srv and step or -step) end
    end
    hist[#hist + 1] = srv
    local da = hist[math.max(1, #hist - math.floor(A.lag / DT))]
    local dr = s.rudder or 0
    local db = A.bb * x.b + A.bp * x.p + A.br * x.r + A.bphi * x.phi + A.bd * dr
    local dp = A.lb * x.b + A.lp * x.p + A.lr * x.r + A.la * da + A.ld * dr
    local drr = A.nb * x.b + A.np * x.p + A.nr * x.r + A.na * da + A.nd * (dr - EO)
    x.b, x.p, x.r = x.b + db * DT, x.p + dp * DT, x.r + drr * DT
    x.phi = x.phi + x.p * DT
    x.hdg = x.hdg + x.r * DT
    x.y = x.y + vy * DT
    x.h = x.h - gs * math.tan(math.rad(3)) / 0.3048 * DT
    t = t + DT
    -- the downwind wing (left, minus) low; the distance off
    worst.bank_down = math.min(worst.bank_down, x.phi)
    worst.y = math.max(worst.y, math.abs(x.y))
    if x.h <= next_print then
        print(("%5.0f ft  t %5.1f  crab %6.2f  beta %6.2f  bank %6.2f  rudder %6.3f  aileron %6.3f  y %6.2f m  stage %d"):format(
            x.h, t, ((x.hdg - COURSE + 180) % 360) - 180, x.b, x.phi, s.rudder or 0, srv, x.y, s.al_stage or 0))
        next_print = next_print - (x.h > 600 and 100 or 50)
    end
end
print(("down to 5 ft: the bank's most to the downwind (left) side %.2f, the most off the centreline %.2f m"):format(
    worst.bank_down, worst.y))
