-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The FMC deletes the takeoff speeds with the TAKEOFF REF flaps entry and shows TAKEOFF SPEEDS DELETED when the
-- takeoff thrust rating changes on THRUST LIM (TO, TO 1, TO 2: fmsFunctions.setDref) or a GR WT or ZFW entry is made
-- (fmsFunctions.setdata) on the ground once the speeds are set: entered again they are worked out for the new rating
-- or weight (TO 2's V1 108 stayed under full thrust's VMCG 121 when TO was selected after it; reviews 36 and 38). Not
-- in the air, not for the rating already selected, and not without speeds set: before the flaps entry, and after a
-- landing, where the instruments leave V1 at 998 (no speeds in the air) and VR and V2 at 999 (review 39). The
-- production handlers run in XTLua's namespace against mocked datarefs.
local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua_keysystems/init.lua")), runtime)()
local pages = read(FMS.."B744.fms.pages.lua")
-- the handlers from setdata to setDref's end, at their own line numbers
local first = assert(pages:find("function fmsFunctions.setdata(fmsO,value)", 1, true))
local last = assert(pages:find("function fmsFunctions.setscratchpad(fmsO,value)", first, true))
local _, lines = pages:sub(1, first - 1):gsub("\n", "")
local handlers = string.rep("\n", lines)..pages:sub(first, last - 1)

-- The FMC with a takeoff rating (0, 1, 2) and the instruments' speeds: "set" (121/124/144 with flaps 20 entered),
-- "none" (999 on the ground before the flaps entry) or "landed" (V1 998, VR and V2 999, no flaps entry), on the ground
-- or in the air, at 233.4 t with 18.6 t of fuel
local SPEEDS = {set = {121, 124, 144, 20}, none = {999, 999, 999, 0}, landed = {998, 999, 999, 0}}
local function fmc(rating, speeds, on_ground)
    local ns = runtime.create_namespace()
    ns.fmsFunctions = {}
    local s = SPEEDS[speeds]
    for name, value in pairs({toderate = rating, clbderate = rating, simDR_onground = on_ground and 1 or 0,
            B747DR_airspeed_V1 = s[1], B747DR_airspeed_Vr = s[2], B747DR_airspeed_V2 = s[3],
            B747DR_airspeed_flapsRef = s[4], simDR_GRWT = 233400, simDR_fuel = 18600,
            setFMSData = function() end, calc_CGMAC = function() end}) do
        ns[name] = value
    end
    setfenv(assert(loadstring(handlers, "@"..FMS.."B744.fms.pages.lua")), ns)()
    return ns
end
-- a THRUST LIM key (setDref) or an entry with an empty scratchpad (setdata: GR WT and ZFW take the current weights);
-- the scratchpad message
local function press(ns, handler, key)
    local fmsO = {scratchpad = "", notify = ""}
    local ok, err = pcall(ns.fmsFunctions[handler], fmsO, key)
    if not ok then return "error: "..tostring(err) end
    return fmsO.notify
end
local function deleted(ns, notify)
    return ns.B747DR_airspeed_flapsRef == 0 and notify == "TAKEOFF SPEEDS DELETED"
end
local function kept(ns, notify, flaps)
    return ns.B747DR_airspeed_flapsRef == flaps and notify == ""
end
local function state(ns, notify)
    return string.format("rating %s, flaps %s, '%s'", tostring(ns.toderate), tostring(ns.B747DR_airspeed_flapsRef),
        tostring(notify))
end

-- THRUST LIM: TO 1 after the speeds were set for TO, and TO after TO 2
local ns = fmc(0, "set", true)
local notify = press(ns, "setDref", "TO1")
check(ns.toderate == 1 and ns.clbderate == 1 and deleted(ns, notify), "TO 1 after the speeds: "..state(ns, notify)
    .." (1, 0, TAKEOFF SPEEDS DELETED)")
ns = fmc(2, "set", true)
notify = press(ns, "setDref", "TO")
check(ns.toderate == 0 and deleted(ns, notify), "TO after TO 2 and the speeds: "..state(ns, notify)
    .." (0, 0, TAKEOFF SPEEDS DELETED)")
-- the rating already selected, the air, no speeds yet, and after a landing: nothing deleted
ns = fmc(1, "set", true)
notify = press(ns, "setDref", "TO1")
check(ns.toderate == 1 and kept(ns, notify, 20), "TO 1 again: "..state(ns, notify).." (1, 20, no message)")
ns = fmc(0, "set", false)
notify = press(ns, "setDref", "TO2")
check(ns.toderate == 2 and kept(ns, notify, 20), "TO 2 in the air: "..state(ns, notify).." (2, 20, no message)")
ns = fmc(0, "none", true)
notify = press(ns, "setDref", "TO1")
check(ns.toderate == 1 and kept(ns, notify, 0), "TO 1 before the speeds: "..state(ns, notify)
    .." (1, 0, no message)")
ns = fmc(0, "landed", true)
notify = press(ns, "setDref", "TO1")
check(ns.toderate == 1 and kept(ns, notify, 0), "TO 1 after a landing: "..state(ns, notify)
    .." (1, 0, no message)")

-- GR WT and ZFW: with the speeds set they go; before them or after a landing nothing to delete
for _, entry in ipairs({"grwt", "zfw"}) do
    ns = fmc(0, "set", true)
    notify = press(ns, "setdata", entry)
    check(deleted(ns, notify), entry.." after the speeds: "..state(ns, notify).." (0, TAKEOFF SPEEDS DELETED)")
    ns = fmc(0, "none", true)
    notify = press(ns, "setdata", entry)
    check(kept(ns, notify, 0), entry.." before the speeds: "..state(ns, notify).." (0, no message)")
    ns = fmc(0, "landed", true)
    notify = press(ns, "setdata", entry)
    check(kept(ns, notify, 0), entry.." after a landing: "..state(ns, notify).." (0, no message)")
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("FMC takeoff speeds deleted tests passed: "..checks)
