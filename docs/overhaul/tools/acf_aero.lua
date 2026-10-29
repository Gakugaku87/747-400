-- The custom acf's aerodynamic changes from the comparison with the FCOM and
-- FCTM (PROGRESS.md 5f, notes/AERO.md). Run from the repository root:
--   luajit docs/overhaul/tools/acf_aero.lua <acf in> <acf out> [key=value ...]
-- It prints every change: the values in SET below (or given as
-- <key>=<value> arguments, for trying), each the whole "P <key> <value>"
-- line of the acf (e.g. acf/_flap1_cl, _wing/0/_incidence/0). A key given
-- with a trailing "/*" sets every index of that array (_wing/0/_incidence/*);
-- in SET, a list for an array key sets its indexes from 0 in order.
-- Already changed lines are left alone, so it can run again. The line
-- endings are kept. The shape (span, area, sweep, dihedral, position) is
-- never set here (notes/AERO.md).
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: acf_aero.lua <acf in> <acf out> [key=value ...]")
-- the changes kept
-- the main wing's incidence 1.0 deg lower at every station, the twist kept
-- (2026-10-29: the custom acf flew about 1.0 deg flatter than the FCOM's
-- attitudes, PI.10.38-10.40, clean; notes/AERO.md)
local INC = {
    [0] = {2.0, 2.0, 2.0, 2.0, 1.8, 1.6, 1.4, 1.2, 1.2, 1.2},
    [2] = {1.0, 1.0, 1.0, 1.0, 0.5, 0.3, 0.1, 0.0, -0.2, -0.2},
    [4] = {1.0, 0.9, 0.3, 0.1, 0.0, 0.3, 0.1, 0.0, -0.1, -0.2},
    [6] = {-0.2, -0.3, -0.5, -0.6, -0.7, -0.8, -0.9, -1.0, -1.0, -1.0},
}
-- the trailing edge flaps' last detent 40 -> 50 deg (both flap sets): X-Plane
-- grew their lift in proportion up to half the last detent and no more
-- (20 deg: 20, 25 and 30 gave the same), the FCOM's attitudes want it
-- growing to 30 (notes/AERO.md). The FCU writes the angles itself (the 3D
-- flaps follow laminar/B747/flt_ctrls/flaps), so no look changes
local SET = {
    ["acf/_flap1_dn/6"] = 50,
    ["acf/_flap2_dn/6"] = 50,
}
for w, v in pairs(INC) do
    SET["_wing/" .. w .. "/_incidence"] = v       -- left
    SET["_wing/" .. (w + 1) .. "/_incidence"] = v -- right
end
for i = 3, #arg do
    local k, v = arg[i]:match("^([%w_/%*]+)=([%-%d%.]+)$")
    assert(k, "bad argument " .. arg[i])
    SET[k] = tonumber(v)
end
local function wanted(key)
    if type(SET[key]) == "number" then return SET[key], key end
    local base, i = key:match("^(.*)/(%d+)$")
    if base and SET[base .. "/*"] then return SET[base .. "/*"], base .. "/*" end
    if base and type(SET[base]) == "table" then return SET[base][tonumber(i) + 1], base end
    return nil
end

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local changed, seen = 0, {}
for i, l in ipairs(lines) do
    local pk, pv = l:match("^P (%S+) (%S+)$")
    if pk and not pk:match("/count$") then
        local v, which = wanted(pk)
        if v then
            local new = string.format("%.9f", v)
            if pv ~= new then
                lines[i] = "P " .. pk .. " " .. new
                print(string.format("%s: %s -> %s", pk, pv, new))
                changed = changed + 1
            end
            seen[which] = true
        end
    end
end
for k in pairs(SET) do assert(seen[k], "no line for " .. k) end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print(string.format("%d line(s) changed; written %s", changed, dst))
