-- Run from the repository root with Lua 5.1 or LuaJIT.
-- A takeoff thrust rating changed on THRUST LIM (TO, TO 1, TO 2: fmsFunctions.setDref) once the takeoff speeds are set
-- deletes them with the TAKEOFF REF flaps entry and shows TAKEOFF SPEEDS DELETED, as a GR WT or ZFW entry does: the
-- speeds are worked out again for the new rating when the flaps are entered (TO 2's V1 108 stayed under full thrust's
-- VMCG 121 when TO was selected after it; review 36, the message review 38). Not in the air, not for the rating
-- already selected, and with no speeds set nothing to delete. The production handler runs in XTLua's namespace
-- against mocked datarefs.
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
local first = assert(pages:find("function fmsFunctions.setDref(fmsO,value)", 1, true))
local last = assert(pages:find("function fmsFunctions.setscratchpad(fmsO,value)", first, true))
local _, lines = pages:sub(1, first - 1):gsub("\n", "")
local handler = string.rep("\n", lines)..pages:sub(first, last - 1)

-- The FMC with a takeoff rating (0, 1, 2) selected, takeoff speeds set (V1 121) or not (999, no flaps entered), on the
-- ground or in the air; press(fmc, key) runs THRUST LIM's key and returns its scratchpad message
local function fmc(rating, speeds_set, on_ground)
    local ns = runtime.create_namespace()
    ns.fmsFunctions = {}
    for name, value in pairs({toderate = rating, clbderate = rating, simDR_onground = on_ground and 1 or 0,
            B747DR_airspeed_flapsRef = speeds_set and 20 or 0, B747DR_airspeed_V1 = speeds_set and 121 or 999,
            B747DR_airspeed_Vr = speeds_set and 124 or 999, B747DR_airspeed_V2 = speeds_set and 144 or 999}) do
        ns[name] = value
    end
    setfenv(assert(loadstring(handler, "@"..FMS.."B744.fms.pages.lua")), ns)()
    return ns
end
local function press(ns, key)
    local fmsO = {scratchpad = "", notify = ""}
    local ok, err = pcall(ns.fmsFunctions.setDref, fmsO, key)
    if not ok then return "error: "..tostring(err) end
    return fmsO.notify
end

-- TO 1 selected after the speeds were set for TO
local ns = fmc(0, true, true)
local notify = press(ns, "TO1")
check(ns.toderate == 1 and ns.clbderate == 1 and ns.B747DR_airspeed_flapsRef == 0
    and notify == "TAKEOFF SPEEDS DELETED", string.format("TO 1 after the speeds: rating %s/%s, flaps %s, '%s' "
    .."(1/1, 0, TAKEOFF SPEEDS DELETED)", tostring(ns.toderate), tostring(ns.clbderate),
    tostring(ns.B747DR_airspeed_flapsRef), tostring(notify)))
-- and TO after TO 2
ns = fmc(2, true, true)
notify = press(ns, "TO")
check(ns.toderate == 0 and ns.B747DR_airspeed_flapsRef == 0 and notify == "TAKEOFF SPEEDS DELETED",
    string.format("TO after TO 2 and the speeds: rating %s, flaps %s, '%s' (0, 0, TAKEOFF SPEEDS DELETED)",
    tostring(ns.toderate), tostring(ns.B747DR_airspeed_flapsRef), tostring(notify)))
-- the rating already selected: nothing changes
ns = fmc(1, true, true)
notify = press(ns, "TO1")
check(ns.toderate == 1 and ns.B747DR_airspeed_flapsRef == 20 and notify == "", string.format("TO 1 again: rating "
    .."%s, flaps %s, '%s' (1, 20, no message)", tostring(ns.toderate), tostring(ns.B747DR_airspeed_flapsRef),
    tostring(notify)))
-- in the air: the rating changes, the speeds stay
ns = fmc(0, true, false)
notify = press(ns, "TO2")
check(ns.toderate == 2 and ns.B747DR_airspeed_flapsRef == 20 and notify == "", string.format("TO 2 in the air: "
    .."rating %s, flaps %s, '%s' (2, 20, no message)", tostring(ns.toderate), tostring(ns.B747DR_airspeed_flapsRef),
    tostring(notify)))
-- no speeds set: nothing to delete
ns = fmc(0, false, true)
notify = press(ns, "TO1")
check(ns.toderate == 1 and ns.B747DR_airspeed_flapsRef == 0 and notify == "", string.format("TO 1 before the "
    .."speeds: rating %s, flaps %s, '%s' (1, 0, no message)", tostring(ns.toderate),
    tostring(ns.B747DR_airspeed_flapsRef), tostring(notify)))

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("FMC takeoff rating tests passed: "..checks)
