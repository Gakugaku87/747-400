-- Run from the repository root with LuaJIT: luajit tests/fuel/fuel_auto_model_test.lua
-- The sim's option "Auto fuel management" (2026-11-09 the user;
-- B747.28.fuel_auto_model.lua, notes/ATA-28.md §13): the Climb and Cruise
-- Procedure's fuel switches at the fuel messages (FCOM p.133-136), in the
-- air with the flap lever UP, a message held 5 s, a switch a second; the
-- pilot's switches left alone; the STAB pumps' second try after 5 minutes
-- (p.135). Each push here flips its switch two frames later, as the
-- manipulators' command and animation do.
local T = dofile("tests/lib/check.lua")("fuel_auto_model")
local A = dofile("plugins/xtlua/scripts/B747.25.xt.fuel/B747.28.fuel_auto_model.lua")

local DT = 0.1
-- a world: the switches as after the before start procedure (main and
-- override pumps ON, CTR ON, STAB OFF, crossfeeds ON), the messages from
-- w.msgs(w) each frame
local function world(msgs)
    local w = {s = A.new(), t = 0, on = true, air = true, flaps_up = true, jett = false, stab_kg = 0,
        sw = {ctr_l = true, ctr_r = true, stab_l = false, stab_r = false, oj2_fwd = true, oj3_fwd = true,
            oj2_aft = true, oj3_aft = true, x1 = true, x4 = true},
        cas = {}, msgs = msgs or function() end, pushes = {}, flips = {}, drop = 0, dt = DT}
    return w
end
-- run for seconds: flips due, messages, the model; a push flips its switch
-- two frames later (w.drop: that many pushes lost)
local function run(w, seconds)
    for _ = 1, math.floor(seconds / DT + 0.5) do
        w.t = w.t + w.dt
        for i = #w.flips, 1, -1 do
            local f = w.flips[i]
            f.n = f.n - 1
            if f.n <= 0 then
                w.sw[f.id] = not w.sw[f.id]
                table.remove(w.flips, i)
            end
        end
        for k in pairs(w.cas) do w.cas[k] = nil end
        w.msgs(w)
        local id = A.update(w.s, {on = w.on, air = w.air, flaps_up = w.flaps_up, jett = w.jett, cas = w.cas,
            stab_kg = w.stab_kg, sw = w.sw, dt = w.dt})
        if id then
            w.pushes[#w.pushes + 1] = {id = id, t = w.t}
            if w.drop > 0 then w.drop = w.drop - 1 else w.flips[#w.flips + 1] = {id = id, n = 2} end
        end
    end
end
local function ids(w, from)
    local out = {}
    for i = from or 1, #w.pushes do out[#out + 1] = w.pushes[i].id end
    return table.concat(out, ",")
end

-- FUEL LOW CTR (the message: a CTR switch ON with the CWT low): both OFF,
-- after the message's 5 s, a second apart (FCOM p.134)
local function low_ctr(w)
    w.cas.low_ctr_l = w.sw.ctr_l and w.ctr_low
    w.cas.low_ctr_r = w.sw.ctr_r and w.ctr_low
end
local w = world(low_ctr)
w.ctr_low = true
run(w, 4.9)
T.equal(#w.pushes, 0, "FUEL LOW CTR shown 4.9 s: nothing yet (held 5 s)")
run(w, 0.2)
T.equal(ids(w), "ctr_l", "at 5 s: CTR L")
T.near(w.pushes[1].t, 5.0, 0.11, "pushed at 5 s")
run(w, 5)
T.equal(ids(w), "ctr_l,ctr_r", "then CTR R")
T.near(w.pushes[2].t - w.pushes[1].t, 1.0, 0.11, "a second later")
T.check(not w.sw.ctr_l and not w.sw.ctr_r, "both CTR pumps OFF")
run(w, 30)
T.equal(#w.pushes, 2, "the message gone with the switches: nothing more")

-- a message shorter than 5 s: nothing
w = world(low_ctr)
w.ctr_low = true
run(w, 4.8)
w.ctr_low = false
run(w, 0.5)
w.ctr_low = true
run(w, 4.8)
T.equal(#w.pushes, 0, "4.8 s, gone, 4.8 s again: nothing (the 5 s start again)")

-- not done
local function none(set, what)
    local x = world(low_ctr)
    x.ctr_low = true
    set(x)
    run(x, 20)
    T.equal(#x.pushes, 0, what)
end
none(function(x) x.on = false end, "the option off: nothing")
none(function(x) x.air = false end, "on the ground: nothing (the ground's steps are the crew's)")
none(function(x) x.flaps_up = false end, "the flap lever not UP: nothing (after the After Takeoff Checklist: p.132-133)")
none(function(x) x.jett = true end, "the jettison selector at A or B: nothing")
none(function(x) x.dt = 0 end, "paused (no X-Plane time): nothing")

-- FUEL OVD CTR (CTR switch OFF, 1,800 kg or more in cruise): both ON
w = world(function(x)
    x.cas.ovd_ctr_l = not x.sw.ctr_l
    x.cas.ovd_ctr_r = not x.sw.ctr_r
end)
w.sw.ctr_l, w.sw.ctr_r = false, false
run(w, 10)
T.equal(ids(w), "ctr_l,ctr_r", "FUEL OVD CTR: CTR L, then R")
T.check(w.sw.ctr_l and w.sw.ctr_r, "both CTR pumps ON (FCOM p.134)")

-- FUEL TANK/ENG (main 2 <= main 1 or 3 <= 4, crossfeed 1 or 4 open):
-- override 2 and 3 FWD and AFT, then crossfeed 1 and 4, OFF (p.134)
local function tank_eng(x) x.cas.tank_eng = x.tank_eng and (x.sw.x1 or x.sw.x4) end
w = world(tank_eng)
w.tank_eng = true
run(w, 15)
T.equal(ids(w), "oj2_fwd,oj3_fwd,oj2_aft,oj3_aft,x1,x4", "FUEL TANK/ENG: overrides 2 and 3, then crossfeeds 1 and 4")
for i = 2, #w.pushes do
    T.check(w.pushes[i].t - w.pushes[i - 1].t >= 1 - 1e-6, "a second between pushes " .. (i - 1) .. " and " .. i)
end
T.check(not (w.sw.oj2_fwd or w.sw.oj3_fwd or w.sw.oj2_aft or w.sw.oj3_aft or w.sw.x1 or w.sw.x4), "all six OFF")
-- the pilot opens crossfeed 1 (balancing, FCOM SP.12.1): left to the pilot
w.sw.x1 = true
run(w, 30)
T.equal(#w.pushes, 6, "the pilot's crossfeed 1 ON with FUEL TANK/ENG shown: left alone")
T.check(w.s.pilot.x1, "crossfeed 1 the pilot's")
-- landed, then the next flight: managed again
w.air = false
run(w, 2)
T.check(not w.s.pilot.x1, "on the ground: the pilot's switches forgotten")
w.air = true
run(w, 10)
T.equal(ids(w, 7), "x1", "the next flight: crossfeed 1 OFF again")
-- the option off and on again forgets the pilot's switches too
w.sw.x4 = true
run(w, 10)
T.equal(#w.pushes, 7, "the pilot's crossfeed 4: left alone")
w.on = false
run(w, 1)
w.on = true
run(w, 10)
T.equal(ids(w, 8), "x4", "the option off and on: crossfeed 4 OFF")
-- a switch moved with the option off is not the pilot's
w.on = false
w.sw.x1 = true
run(w, 1)
w.on = true
run(w, 10)
T.equal(ids(w, 9), "x1", "crossfeed 1 moved with the option off: managed once it is on")

-- a push not taken: pushed again after 3 s
w = world(low_ctr)
w.ctr_low = true
w.drop = 1
run(w, 12)
T.equal(ids(w), "ctr_l,ctr_l,ctr_r", "a lost push: CTR L again")
T.near(w.pushes[2].t - w.pushes[1].t, 3, 0.11, "3 s after")
T.check(not w.sw.ctr_l and not w.sw.ctr_r, "both OFF in the end")

-- the STAB pumps (109): FUEL PMP STB (switch OFF, 500 kg or more in cruise):
-- both ON; FUEL PRES STB (pressure low while the logic runs them) with 900
-- kg or less: both OFF (p.135)
local function stab(x)
    x.cas.pmp_stab_l = not x.sw.stab_l and x.stab_kg >= 500
    x.cas.pmp_stab_r = not x.sw.stab_r and x.stab_kg >= 500
    x.cas.pres_stab_l = x.sw.stab_l and (x.stab_kg <= 0 or x.fail_l)
    x.cas.pres_stab_r = x.sw.stab_r and x.stab_kg <= 0
end
w = world(stab)
w.stab_kg = 3000
run(w, 10)
T.equal(ids(w), "stab_l,stab_r", "FUEL PMP STB: STAB L, then R")
w.stab_kg = 0
run(w, 10)
T.equal(ids(w, 3), "stab_l,stab_r", "the tank empty, FUEL PRES STB: both OFF")
T.check(not w.sw.stab_l and not w.sw.stab_r, "both STAB pumps OFF")
run(w, 400)
T.equal(#w.pushes, 4, "5 minutes later with the tank empty: no second try")

-- FUEL PRES STB with more than 900 kg (a pump failed): the crew's
w = world(stab)
w.sw.stab_l, w.sw.stab_r = true, true
w.stab_kg, w.fail_l = 3000, true
run(w, 30)
T.equal(#w.pushes, 0, "FUEL PRES STB L with 3,000 kg: nothing (a non-normal)")
-- 900 kg or less: both OFF; FUEL PMP STB (700 kg, switches OFF) does not
-- turn them on again; after about 5 minutes with fuel still shown, both ON
-- once more, OFF at the first FUEL PRES STB, no third time
w.stab_kg = 700
run(w, 10)
T.equal(ids(w), "stab_l,stab_r", "FUEL PRES STB L with 700 kg: both OFF")
local off_t = w.pushes[1].t
run(w, 290 - (w.t - off_t))
T.equal(#w.pushes, 2, "FUEL PMP STB with the pumps OFF after FUEL PRES STB: not ON again before the 5 minutes")
-- (the second try's ON at 300 s and its 5 s; FUEL PRES STB L again at once)
run(w, 17)
T.equal(ids(w, 3), "stab_l,stab_r", "about 5 minutes later, fuel still shown: both ON again")
T.check(w.pushes[3].t - off_t >= A.RETRY_S, "after 300 s")
run(w, 10)
T.equal(ids(w, 5), "stab_l,stab_r", "the first FUEL PRES STB: both OFF")
run(w, 700)
T.equal(#w.pushes, 6, "no third try")
T.check(not w.sw.stab_l and not w.sw.stab_r, "both OFF in the end")

-- the CTR pumps from the climb's FUEL LOW CTR (3,200 kg) to the cruise's
-- FUEL OVD CTR (1,800 kg or more): OFF, then ON, and then left as they are
w = world(function(x)
    x.cas.low_ctr_l = x.sw.ctr_l and x.climb
    x.cas.low_ctr_r = x.sw.ctr_r and x.climb
    x.cas.ovd_ctr_l = not x.sw.ctr_l and not x.climb
    x.cas.ovd_ctr_r = not x.sw.ctr_r and not x.climb
end)
w.climb = true
run(w, 5.5)
T.equal(ids(w), "ctr_l", "the climb's FUEL LOW CTR: CTR L OFF")
w.climb = false
run(w, 30)
T.check(w.sw.ctr_l and w.sw.ctr_r, "the cruise's FUEL OVD CTR: both ON in the end")
local n = #w.pushes
run(w, 30)
T.equal(#w.pushes, n, "then nothing more")

T.done()
