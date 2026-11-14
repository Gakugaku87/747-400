-- The A/T's SPD (or another mode's servo) closed on an airplane in level
-- flight with the real models, for the tests (2026-11-13; from the
-- 2026-11-12 review's lib_cruise.lua, its A/T reviewer's; docs/overhaul/
-- TESTING.md §3):
--   B747.70.at_model.lua (update, servo with the gust complement's inputs
--     and B5's: the Mach and the weight),
--   B747.42.eec_model.lua (update: the command from the lever; thrust_control
--     on a stand-in engine: two lags and a dead time by the pressure ratio,
--     X-Plane's engines measured open-loop: notes/ATA-70-80.md §14),
--   B747.42.ref_thrust_model.lua (the FMC's reference), B747.42.epr_model.lua
--     (the thrust of an EPR), B747.68.perf_db.lua (the drag's polar, the ISA).
-- P&W only (the EPR model gives the thrust). Level flight: the altitude held
-- exactly, m dV/dt = F - D. o.time_accel: X-Plane's time N times the
-- frames' (XTLua's dt real time). Run from the repository root:
--   local C = dofile("tests/lib/cruise_sim.lua")
--   local m = C.run{alt = 37000, weight = 307000, ias0 = 278, seconds = 300,
--                   target = function(t, m) return 278 end, cb = function(m) end}
--   C.gain{alt =, weight =, mach =, lever =}   -- kt/s of IAS a unit of lever
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/"
dofile(EEC .. "B747.42.epr_model.lua")
local E = dofile(EEC .. "B747.42.eec_model.lua")
local R = dofile(EEC .. "B747.42.ref_thrust_model.lua")
local A = dofile("plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/B747.70.at_model.lua")
local P = B747_epr_model
local D = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.perf_db.lua")
local KT, G = 1852 / 3600, 9.80665
local M = {A = A, E = E, R = R, P = P, D = D}

local function tat_c(alt, isa_dev, mach)
    local _, t = D.atmos(alt, isa_dev)
    return t * (1 + 0.2 * mach * mach) - 273.15
end
M.tat_c = tat_c

-- the stand-in engine at a pressure ratio: the lags of the open-loop test
-- (11,000 ft 2.93 and 1.25 s, FL250 3.21 and 1.75, FL390 5.75 and 2.09; dead
-- time 0.09 to 0.21 s), between them by delta
local PL = {{0.6614, 2.93, 1.25, 0.09}, {0.3707, 3.21, 1.75, 0.09}, {0.1940, 5.75, 2.09, 0.21}}
local function lags(delta)
    if delta >= PL[1][1] then return PL[1][2], PL[1][3], PL[1][4] end
    for i = 2, #PL do
        if delta >= PL[i][1] then
            local f = (delta - PL[i][1]) / (PL[i - 1][1] - PL[i][1])
            return PL[i][2] + f * (PL[i - 1][2] - PL[i][2]), PL[i][3] + f * (PL[i - 1][3] - PL[i][3]), PL[i][4] + f * (PL[i - 1][4] - PL[i][4])
        end
    end
    local s = math.sqrt(PL[#PL][1] / delta)
    return PL[#PL][2] * s, PL[#PL][3] * s, PL[#PL][4]
end

-- o: alt, weight (kg), isa (0), ias0 or mach0, target fn(t, m) -> kt (IAS) ,
-- inop (0), mode (the thrust limit: "CLB", the air starts' in X-Plane and,
-- with VNAV, the cruise's by default: PERF FACTORS' THR/CRZ CLB, notes/
-- ATA-34-61-FMC.md §129. Until 2026-11-14 "CRZ", the same values then; CRZ
-- is the FPPM's maximum cruise EPR since, §169), dt (0.05 real),
-- time_accel (1), seconds,
-- wind fn(t) (kt of headwind change: the air's speed added to the TAS), cb(m)
function M.run(o)
    local alt, w, isa = o.alt, o.weight, o.isa or 0
    local t = D.tables(0)
    local p = D.atmos(alt)
    local delta = p / 101325
    local dt_real = o.dt or 0.05
    local N = o.time_accel or 1
    local dt = dt_real * N                    -- X-Plane's time a frame
    local eng = 4 - (o.inop or 0)
    local mach = o.mach0 or D.cas_to_mach(o.ias0, alt)
    local _, temp = D.atmos(alt, isa)
    local a_snd = math.sqrt(1.4 * 287.053 * temp)
    local vg = mach * a_snd                   -- the airplane's speed along the path (m/s), still air
    local wind0 = o.wind and o.wind(0) or 0
    local tau1, tau2, dead = lags(delta)
    local m = {t = 0, alt = alt, weight = w, delta = delta}
    local as = A.new()
    local upd = {arm = true, ok = true, ground = false, cas = 250, ra = 30000, flaps_up = true, reverse = false,
        limit_to = false, limit_ga = false, limit_ref = true, pitch = o.pitch or "ALT", vnav_at = A.SPD,
        vnav_level = true, lever_idle = false, spd = true}
    local es, inp = E.new(), E.inputs()
    inp.type, inp.air = "PW", true
    local lever, epr, th, x1, x2, buf
    local last_ias, accel, last_vg = nil, 0, vg
    local function drag(mach_now)
        local d
        if (o.inop or 0) > 0 then d = D.eo_drag(t, o.inop, w, alt, mach_now) else d = D.drag(t, w, alt, mach_now) end
        return d * (o.drag_k or 1)
    end
    local nsteps = math.floor(o.seconds / dt + 0.5)
    for n = 1, nsteps do
        local tt = n * dt
        local wind = o.wind and (o.wind(tt) - wind0) or 0
        local v = vg + wind * KT              -- the true airspeed (m/s)
        local mach_now = v / a_snd
        local ias = D.mach_to_cas(mach_now, alt)
        local tas_kt = v / KT
        local tat = tat_c(alt, isa, mach_now)
        local idle = P.idle_command(mach_now)
        inp.alt, inp.kias, inp.tat = alt, ias, tat
        local ref = R.reference({type = "PW", mode = o.mode or "CLB", alt = alt, tat = tat, mach = mach_now, kias = ias,
            packs_on = 3, wai = false, nai = false})
        if not lever then
            -- trimmed: the EPR of the drag, the levers there
            for k = 1, 4 do inp.idle[k] = idle; inp.lever[k] = 1 end
            local out0 = E.update(es, inp, dt_real)
            local f_eng = drag(mach_now) / eng / 1000
            epr = P.epr(f_eng, delta, mach_now)
            local idl = math.min(idle, out0.max[1])
            local x = math.max(0, math.min(1, (epr - idl) / (out0.max[1] - idl)))
            lever = (E.TLA_FLAT_IDLE + x * (out0.tla_full - E.TLA_FLAT_IDLE)) / E.TLA_STOP
            if o.lever0 then lever = o.lever0 end
            th, x1, x2, buf = 0.6, 0, 0, {}
            for i = 1, math.max(1, math.floor(dead / dt + 0.5)) do buf[i] = th end
            m.y0, m.th0 = epr, th
            m.slope = 3.67 * (0.1940 / delta) ^ 1.0     -- EPR a unit of throttle (the tests' K by delta: 0.81, 1.65, 3.67)
            if delta > 0.3707 then m.slope = 1.65 + (0.81 - 1.65) * (delta - 0.3707) / (0.6614 - 0.3707) end
            if delta > 0.6614 then m.slope = 0.81 end
        end
        for k = 1, 4 do inp.idle[k] = idle; inp.lever[k] = lever; inp.actual[k] = epr end
        local out = E.update(es, inp, dt_real)
        local cmd = out.command[1]
        -- the glue: the IAS's rate over half a second (the frames' dt)
        if last_ias then accel = accel + ((ias - last_ias) / dt_real - accel) * math.min(1, dt_real / 0.5) end
        last_ias = ias
        local target = o.target(tt, m)
        upd.cas = ias
        upd.pitch = o.pitch or "ALT"
        A.update(as, upd)
        upd.spd = nil
        local si = {dt = dt_real, ias = ias, accel = accel, target = target, v_max = o.v_max or 365, v_min = o.v_min or 0,
            flaps_up = true, vs = 0, ivs = 0, alt = alt, mcp_alt = alt, thrust = cmd, thrust_ref = ref,
            thrust_max = out.max[1], n1 = false, lever = lever,
            tas = tas_kt, accel_in = (vg - last_vg) / dt / KT, time_accel = N > 1}
        si.mach, si.weight = mach_now, w
        if o.no_inertial then si.tas, si.accel_in = nil, nil end
        last_vg = vg
        A.servo(as, si)
        -- the glue's lever follower: 0.2 a second of the frames' time
        local step = 0.2 * dt_real
        if as.servo then
            if math.abs(as.cmd - lever) <= step then lever = as.cmd
            else lever = lever + (as.cmd > lever and step or -step) end
        end
        -- the EEC's thrust control (the frames' dt) on the engine (X-Plane's time)
        if o.simple_engine then
            epr = epr + (out.target[1] - epr) * math.min(1, dt / o.simple_engine)
        else
            local ud = table.remove(buf, 1)
            buf[#buf + 1] = th
            -- the engine not under its idle: the EPR of the idle thrust (2 kN an engine: estimate)
            local floor = P.epr(o.idle_kn or 2, delta, mach_now) - m.y0
            x1 = x1 + math.min(1, dt / tau1) * (math.max(floor, m.slope * (ud - m.th0)) - x1)
            x2 = x2 + math.min(1, dt / tau2) * (x1 - x2)
            epr = m.y0 + x2
            th = E.thrust_control(es, "PW", 1, out.target[1], epr, th, idle, dt_real, m.slope, delta)
        end
        local f = eng * P.thrust(epr, delta, mach_now) * 1000
        local d = drag(mach_now)
        vg = vg + (f - d) / w * dt
        m.t, m.ias, m.mach, m.tas, m.lever, m.cmd, m.epr, m.ref, m.max, m.th = tt, ias, mach_now, tas_kt, lever, cmd, epr, ref, out.max[1], th
        m.target, m.f, m.drag, m.fma, m.at_cmd, m.accel = target, f, d, A.fma(as), as.cmd, accel
        if o.cb then o.cb(m) end
    end
    return m
end

-- the acceleration (kt/s of IAS) a unit of lever gives there, by a difference
function M.gain(o)
    local alt, w, isa = o.alt, o.weight, o.isa or 0
    local delta = D.atmos(alt) / 101325
    local mach = o.mach or D.cas_to_mach(o.ias, alt)
    local ias = D.mach_to_cas(mach, alt)
    local tas = D.tas(mach, alt, isa)
    local idle = P.idle_command(mach)
    local inp = E.inputs()
    inp.type, inp.air, inp.alt, inp.kias, inp.tat = "PW", true, alt, ias, tat_c(alt, isa, mach)
    local function f_at(lever)
        for k = 1, 4 do inp.idle[k] = idle; inp.lever[k] = lever end
        local out = E.update(E.new(), inp, 0.05)
        return (4 - (o.inop or 0)) * P.thrust(out.command[1], delta, mach) * 1000
    end
    local l0 = o.lever or 0.5
    local df = (f_at(l0 + 0.02) - f_at(l0 - 0.02)) / 0.04
    return df / w / KT * (ias / tas)
end

return M
