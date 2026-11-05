-- Run from the repository root with LuaJIT: luajit tests/static/cas_tables_test.lua
-- (2026-11-05 review 3) the EICAS message tables: the init script's
-- (plugins/xtlua/init/scripts/B747.87.warning/B747.87.warning.lua: it sizes
-- the CAS arrays) and the xt script's (B747.87.xt.warning.lua: its names are
-- the ones shown) have the same slots and names, and no slot twice in a
-- table. Before, memo 41 was both ACARS CALL and ACARS VOICE, PRINTER
-- MESSAGE was at 28 and 42, and the init table had IRS ALIGN MODE L and C
-- the other way round.
local T = dofile("tests/lib/check.lua")("cas_tables")
local src = dofile("tests/lib/source.lua")

local INIT = "plugins/xtlua/init/scripts/B747.87.warning/B747.87.warning.lua"
local XT = "plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.warning.lua"

-- a table's {index, name} pairs in order
local function table_of(text, name)
    local body = text:match("\n" .. name .. "%s*=%s*(%b{})")
    local list = {}
    if not body then return nil end
    for idx, msg in body:gmatch('DRindex%s*=%s*(%d+)%s*,%s*name%s*=%s*"([^"]*)"') do
        list[#list + 1] = {tonumber(idx), msg}
    end
    return list
end

local init_text, xt_text = src.read(INIT), src.read(XT)
for _, name in ipairs({"B747_CASwarningMsg", "B747_CAScautionMsg", "B747_CASadvisoryMsg", "B747_CASmemoMsg"}) do
    local a, b = table_of(init_text, name), table_of(xt_text, name)
    T.check(a ~= nil and b ~= nil and #a > 0, name .. ": in both scripts")
    if a and b then
        T.equal(#a, #b, name .. ": as many slots in both")
        local differ = {}
        for k = 1, math.min(#a, #b) do
            if a[k][1] ~= b[k][1] or a[k][2] ~= b[k][2] then
                differ[#differ + 1] = string.format("%d %s / %d %s", a[k][1], a[k][2], b[k][1], b[k][2])
            end
        end
        T.check(#differ == 0, name .. ": the same slots and names" .. (#differ > 0 and (" (" .. table.concat(differ, "; ") .. ")") or ""))
        local seen, twice = {}, {}
        for _, e in ipairs(b) do
            if seen[e[1]] then twice[#twice + 1] = e[1] .. " " .. seen[e[1]] .. " / " .. e[2] end
            seen[e[1]] = e[2]
        end
        T.check(#twice == 0, name .. ": no slot twice" .. (#twice > 0 and (" (" .. table.concat(twice, "; ") .. ")") or ""))
    end
end
T.done()
