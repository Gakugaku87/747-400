-- 747-400 FMC PERF FACTORS without X-Plane (6-1/6-2 step 12c1;
-- docs/overhaul/notes/ATA-34-61-FMC.md §109): the maintenance page's
-- performance factors, their entries and their text (FMSPG p.265-268;
-- ATA34_2 p.678-679):
--   DRAG/F-F      drag and fuel flow corrections, % (within 9.9 either
--                 way; the fuel flow's alone after a slash, the drag's
--                 slash optional);
--   TO 1/TO 2     the takeoff derates, whole % from 0 to 30 (FCOM p.1272:
--                 one percent increments; TO 2 alone after a slash);
--   MNVR MARGIN   1.20 to 1.30 (the buffet's, g);
--   MIN CRZ TIME  1 to 20 minutes;
--   R/C CLB       0 to 500 fpm;
--   THR/CRZ       CLB or CRZ at the cruise, and R/C CRZ 0 to 500 fpm,
--                 each half alone;
--   THR RED       5 (FLAPS 5) or 400 to 9999 ft;
--   ACCEL HT      the engine-out (the inner field) and the all-engine
--                 heights, 400 to 9999 ft, both together.
-- Without an entry the values of the airplane on ATA34_2 p.681's figure
-- (MNVR MARGIN 1.30, R/C CLB 300, THR RED FLAPS 5, ACCEL HT 1000/1000,
-- MIN CRZ TIME 5): the FCOM's airplane agrees where it shows them (TAKEOFF
-- REF's FLAPS 5 and 1000 FT, p.1317-1318; 1.3 g, p.969, p.973; 100 fpm,
-- p.1350). FMSPG p.266-268's are an FMC without entries (1.20, 100,
-- CLB/100, 1500, 1500/1500, 1). THR/CRZ CLB/100, FMSPG's, not p.681's
-- CRZ/100 (the user, 2026-11-02: no source gives the maximum cruise
-- thrust, the CRZ limit's estimate is the maximum climb table's; the
-- cruise's reference CLB or CRZ as set by maintenance, FMSPG p.33). The
-- derates the FCOM's operator's (p.1314: -8/-20 %; the 570 -5/-15 %).
--
--   local F = B747_perf_factors_model
--   local v = F.values(stored, engine_type)    -- stored: the simconfig's FMC.PERF or nil
--   local new, err = F.enter(field, text)      -- the changed values, or nil and the message
--   local t = F.text(v)                        -- the page's fields

local M = setmetatable({}, {})
B747_perf_factors_model = M

M.DEFAULTS = {drag = 0, ff = 0, mnvr = 1.30, mincrz = 5, rc_clb = 300, thr_crz = "CLB", rc_crz = 100,
    thr_red = 5, accel = 1000, eo_accel = 1000}
-- TO 1 and TO 2 by laminar/B747/engines/type (0 PW, 1 GE, 2 RR)
M.DERATES = {[0] = {8, 20}, [1] = {5, 15}, [2] = {8, 20}}
M.INVALID = "INVALID ENTRY"

-- the values: the stored ones over the defaults
function M.values(stored, engine_type)
    local v = {}
    for k, d in pairs(M.DEFAULTS) do v[k] = d end
    local der = M.DERATES[engine_type] or M.DERATES[0]
    v.to1, v.to2 = der[1], der[2]
    if type(stored) == "table" then
        for k in pairs(v) do
            local s = stored[k]
            if s ~= nil and type(s) == type(v[k]) then v[k] = s end
        end
    end
    return v
end

-- a correction factor: a sign, up to one digit before and one after the
-- point, within 9.9
local function factor(s)
    local sign, num = string.match(s, "^([+-]?)(%d?%.?%d?)$")
    if not num or not string.find(num, "%d") or num == "." then return nil end
    local v = tonumber(num)
    if not v or v > 9.9 then return nil end
    if sign == "-" then v = -v end
    if v == 0 then v = 0 end
    return v
end
-- a derate: whole %, 0 to 30, a minus sign optional (shown)
local function derate(s)
    local num = string.match(s, "^%-?(%d%d?)$")
    local v = tonumber(num)
    if not v or v > 30 then return nil end
    return v
end
-- a whole number of up to n digits within lo and hi
local function whole(s, n, lo, hi)
    if not string.match(s, "^%d+$") or #s > n then return nil end
    local v = tonumber(s)
    if v < lo or v > hi then return nil end
    return v
end
-- a height: three or four digits, 400 to 9999
local function height(s)
    if #s < 3 then return nil end
    return whole(s, 4, 400, 9999)
end

local ENTER = {}
function ENTER.dragff(s)
    local a, b = string.match(s, "^([^/]*)/([^/]*)$")
    if not a then a, b = s, "" end
    if a == "" and b == "" then return nil end
    local new = {}
    if a ~= "" then
        new.drag = factor(a)
        if new.drag == nil then return nil end
    end
    if b ~= "" then
        new.ff = factor(b)
        if new.ff == nil then return nil end
    end
    return new
end
function ENTER.derates(s)
    if #s > 9 then return nil end
    local a, b = string.match(s, "^([^/]*)/([^/]*)$")
    if not a then a, b = s, "" end
    if a == "" and b == "" then return nil end
    local new = {}
    if a ~= "" then
        new.to1 = derate(a)
        if new.to1 == nil then return nil end
    end
    if b ~= "" then
        new.to2 = derate(b)
        if new.to2 == nil then return nil end
    end
    return new
end
function ENTER.mnvr(s)
    if not string.match(s, "^%d?%.%d%d?$") then return nil end
    local v = tonumber(s)
    if not v or v < 1.195 or v > 1.305 then return nil end
    return {mnvr = math.floor(v * 100 + 0.5) / 100}
end
function ENTER.mincrz(s)
    local v = whole(s, 2, 1, 20)
    return v and {mincrz = v}
end
function ENTER.rc_clb(s)
    local v = whole(s, 3, 0, 500)
    return v and {rc_clb = v}
end
function ENTER.thrcrz(s)
    local a, b = string.match(s, "^([^/]*)/([^/]*)$")
    if not a then a, b = s, "" end
    if a == "" and b == "" then return nil end
    local new = {}
    if a ~= "" then
        if a ~= "CLB" and a ~= "CRZ" then return nil end
        new.thr_crz = a
    end
    if b ~= "" then
        new.rc_crz = whole(b, 3, 0, 500)
        if new.rc_crz == nil then return nil end
    end
    return new
end
function ENTER.thrred(s)
    if s == "5" then return {thr_red = 5} end
    local v = height(s)
    return v and {thr_red = v}
end
function ENTER.accel(s)
    local a, b = string.match(s, "^(%d+)/(%d+)$")
    if not a then return nil end
    local eo, all = height(a), height(b)
    if not eo or not all then return nil end
    return {eo_accel = eo, accel = all}
end

-- an entry into a field ("dragff", "derates", "mnvr", "mincrz", "rc_clb",
-- "thrcrz", "thrred", "accel"): the changed values, or nil and INVALID
-- ENTRY
function M.enter(field, text)
    local f = ENTER[field]
    local new = f and f(text or "")
    if not new then return nil, M.INVALID end
    return new
end

local function signed(v)
    if v == 0 then v = 0 end
    return string.format("%+.1f", v)
end
local function minus(v) return v == 0 and "0" or ("-" .. v) end
-- the fields' text (FMSPG p.265: "+0.0/+0.0", "-5/-15", "1.20", "1",
-- "100", "CLB/100", "1500" or FLAPS 5, "1500/1500")
function M.text(v)
    return {
        dragff = signed(v.drag) .. "/" .. signed(v.ff),
        derates = minus(v.to1) .. "/" .. minus(v.to2),
        mnvr = string.format("%.2f", v.mnvr),
        mincrz = string.format("%d", v.mincrz),
        rc_clb = string.format("%d", v.rc_clb),
        thrcrz = v.thr_crz .. "/" .. string.format("%d", v.rc_crz),
        thrred = v.thr_red == 5 and "FLAPS 5" or string.format("%d", v.thr_red),
        accel = string.format("%d/%d", v.eo_accel, v.accel),
    }
end

return M
