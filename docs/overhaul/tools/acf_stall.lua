-- The custom acf's stall changes, so that the X-Plane flight model stalls at
-- the FCTM's stall speeds (FCTM p.261-262, notes/FCTM.md section 1.14).
-- Run from the repository root:
--   luajit docs/overhaul/tools/acf_stall.lua <acf in> <acf out> [key=value ...]
-- It prints every change:
--   - the main wing (wings 0-7): "Boeing Root/Mid/Tip (high subsonic).afl"
--     become B744_root/mid/tip_custom.afl, the airfoils with the earlier
--     stall that make_airfoils.lua writes (the stock files stay for the stock
--     acf);
--   - the values in SET below (or given as acf/<key>=<value> arguments, for
--     trying): the leading edge devices' stall angle increase.
-- Already changed lines are left alone, so it can run again. The line
-- endings are kept.
local src, dst = arg[1], arg[2]
assert(src and dst, "usage: acf_stall.lua <acf in> <acf out> [key=value ...]")
local MAP = {
    ["Boeing Root (high subsonic).afl"] = "B744_root_custom.afl",
    ["Boeing Mid (high subsonic).afl"] = "B744_mid_custom.afl",
    ["Boeing Tip (high subsonic).afl"] = "B744_tip_custom.afl",
}
-- the slats' increase of the stall angle of attack, deg (stock 8 and 6)
local SET = {
    ["acf/_slat1_inc"] = 4.8,
    ["acf/_slat2_inc"] = 3.6,
}
for i = 3, #arg do
    local k, v = arg[i]:match("^([%w_/]+)=([%-%d%.]+)$")
    assert(k, "bad argument " .. arg[i])
    SET[k] = tonumber(v)
end

local f = assert(io.open(src, "rb"))
local text = f:read("*a")
f:close()
local nl = text:find("\r\n", 1, true) and "\r\n" or "\n"
local lines = {}
for l in (text:gsub("\r\n", "\n") .. "\n"):gmatch("(.-)\n") do lines[#lines + 1] = l end
if lines[#lines] == "" then lines[#lines] = nil end

local changed, already, seen = 0, 0, {}
for i, l in ipairs(lines) do
    local key, wing, name = l:match("^(P _wing/(%d+)/_afl_file_%d) (.+)$")
    wing = tonumber(wing)
    if key and wing <= 7 then
        if MAP[name] then
            lines[i] = key .. " " .. MAP[name]
            print(string.format("%s: %s -> %s", key, name, MAP[name]))
            changed = changed + 1
        else
            for _, v in pairs(MAP) do if name == v then already = already + 1 end end
        end
    end
    local pk, pv = l:match("^P (%S+) (%S+)$")
    if pk and SET[pk] then
        local new = string.format("%.9f", SET[pk])
        if pv ~= new then
            lines[i] = "P " .. pk .. " " .. new
            print(string.format("%s: %s -> %s", pk, pv, new))
        end
        seen[pk] = true
    end
end
assert(changed + already == 24, "expected 24 airfoil references on wings 0-7, found " .. changed + already)
for k in pairs(SET) do assert(seen[k], "no line for " .. k) end

local o = assert(io.open(dst, "wb"))
o:write(table.concat(lines, nl), nl)
o:close()
print(string.format("airfoils changed %d, already pointed %d; written %s", changed, already, dst))
