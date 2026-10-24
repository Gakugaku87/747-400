-- 747-400 brake temperature monitoring (BTMS) without X-Plane (4-2 step 5):
-- each brake's heat sink heated by the energy it absorbs and cooled towards
-- the outside air, the thermocouples following it, the indication 0-9 and
-- BRAKE TEMP. Logic and sources: docs/overhaul/notes/ATA-32.md §4.10 (FCOM
-- p.1521, PI.12.8 p.282, PI.18.8 p.320; ATA29_32 32-46 p.426-436).
--
--   local B = B747_btms_model              -- in XTLua, after dofile
--   local B = dofile(".../B747.10.btms_model.lua")   -- in the tests
--   local s = B.new(oat)                 -- every brake at the outside air
--   local inp = B.inputs()               -- fill it every frame
--   local out = B.update(s, inp, dt)     -- the same table every frame
--
-- Brakes 1-16 as the wheels they are on (ATA29_32 p.371): 1-4 left wing
-- gear, 5-8 left body, 9-12 right body, 13-16 right wing.

local M = setmetatable({}, {})
B747_btms_model = M

M.BRAKES = 16
M.LEVEL_C = 482 / 5         -- the indication 0-9 in proportion to the temperature, 5 at 482 °C
                            -- (ATA29_32 p.428): a level every 96.4 °C (estimate: from 0 °C)
M.ADVISORY_LEVEL = 5        -- BRAKE TEMP at 5 or more (FCOM p.1521; ATA29_32 p.428)
-- estimates (no values in the sources), fitted to FCOM PI.12.8's brake
-- cooling schedule: a heat sink's capacity, from the brake energy and the
-- BTMS indication 10-15 min after the stop (16 million ft-lb: 2, 22: 3,
-- 31: 4, 34-45: 5-6; not in proportion: fitted to 31 at 4 and the caution
-- zone's 34 at 5, so 20 and 27 read one level high); its cooling, from the cooling times (on the ground
-- about 90 min, gear down in flight about 10 min); the thermocouples'
-- lag behind the heat sink (the indication used 10 to 15 minutes after the
-- stop)
M.HEAT_J_PER_C = 87000
M.COOL_S = 90 * 60
M.COOL_AIR_S = 10 * 60
M.SENSOR_S = 180

local function sixteen(v)
    local t = {}
    for i = 1, M.BRAKES do t[i] = v end
    return t
end

function M.inputs()
    return {
        heat_j = sixteen(0),        -- the energy each brake absorbed this frame, J
        oat = 15,                   -- the outside air, °C
        airflow = false,            -- the gear down in flight (cooled by the airflow)
        fail = false,               -- the BTMU failed
    }
end

function M.new(oat)
    local t = oat or 15
    local s = {sink = sixteen(t), sensor = sixteen(t)}
    s.out = {temp = sixteen(t), level = sixteen(0), brake_temp = false, sys = false}
    return s
end

function M.level(temp_c)
    local n = math.floor(temp_c / M.LEVEL_C)
    if n < 0 then return 0 elseif n > 9 then return 9 end
    return n
end

function M.update(s, inp, dt)
    local out = s.out
    local cool = inp.airflow and M.COOL_AIR_S or M.COOL_S
    local hot = false
    for i = 1, M.BRAKES do
        local t = s.sink[i] + inp.heat_j[i] / M.HEAT_J_PER_C
        t = t + (inp.oat - t) * math.min(1, dt / cool)
        s.sink[i] = t
        s.sensor[i] = s.sensor[i] + (t - s.sensor[i]) * math.min(1, dt / M.SENSOR_S)
        out.temp[i] = s.sensor[i]
        out.level[i] = M.level(s.sensor[i])
        if out.level[i] >= M.ADVISORY_LEVEL then hot = true end
    end
    -- BRAKE TEMP; with the BTMU failed, no indication and BRAKE TEMP SYS
    -- (ATA29_32 p.428)
    out.brake_temp = hot and not inp.fail
    out.sys = inp.fail
    return out
end

return M
