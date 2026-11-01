-- Run from the repository root with LuaJIT: luajit tests/fms/doors_page_test.lua
-- The FMC's DOORS page (a sim page; 7-3, notes/ATA-52.md §11): the plug
-- doors (entry L1, upper deck L) open on the ground only (FCOM p.529,
-- p.534); closing and the flight deck door any time. The page alone, with
-- the CDU framework's globals stubbed.
local T = dofile("tests/lib/check.lua")("doors_page")

local doors = {[0] = 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
local modes = {}
for i = 0, 11 do modes[i] = 0 end
local env = setmetatable({
    registerFMCCommand = function() end,
    find_dataref = function(name)
        if name == "sim/cockpit2/switches/door_open" then return doors end
        if name == "laminar/B747/door/mode" then return modes end
        return 0
    end,
    fmsPages = {},
    createPage = function(name) return {name = name} end,
    fmsFunctionsDefs = {DOORS = {}},
}, {__index = _G})
local chunk = assert(loadfile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/activepages/B744.fms.pages.doors.lua"))
setfenv(chunk, env)
chunk()
local page = env.fmsPages["DOORS"]
local defs = env.fmsFunctionsDefs["DOORS"]

local function show(ground)
    env.B747DR_doors_pseu_gnd = ground and 1 or 0
    return page:getPage(1, 1)
end
local function cmd(key) return defs[key] and defs[key][2] end

-- on the ground, all closed: every door opens
local lines = show(true)
T.check(lines[3]:find("^<OPEN") ~= nil, "ground: FWD L <OPEN")
T.equal(cmd("L1"), "sim/flight_controls/door_open_2", "ground: L1 opens FWD L (X-Plane door 2)")
T.equal(cmd("L2"), "sim/flight_controls/door_open_1", "ground: L2 opens Upper L (X-Plane door 1)")
T.equal(cmd("L3"), "sim/flight_controls/door_open_10", "ground: L3 opens the flight deck door")

-- in the air: the plug doors stay shut, the flight deck door opens
lines = show(false)
T.check(lines[3]:find("GROUND ONLY", 1, true) ~= nil, "air: FWD L reads OPEN ON GROUND ONLY")
T.check(lines[5]:find("GROUND ONLY", 1, true) ~= nil, "air: Upper L reads OPEN ON GROUND ONLY")
T.check(cmd("L1") == nil and cmd("L2") == nil, "air: no command opens FWD L or Upper L (before, they opened)")
T.equal(cmd("L3"), "sim/flight_controls/door_open_10", "air: the flight deck door opens")

-- in the air with FWD L open (opened on the ground): it closes
doors[1] = 1
lines = show(false)
T.check(lines[3]:find("^<CLOSE") ~= nil, "air, FWD L open: <CLOSE")
T.equal(cmd("L1"), "sim/flight_controls/door_close_2", "air, FWD L open: L1 closes it")
doors[1] = 0

-- the entry and upper deck doors' modes, all at once on L4 (the 3D has no
-- doors' levers): ARM and DISARM (FCOM p.473); the status in the small font
local function small() return page:getSmallPage(1, 1) end
lines = show(true)
T.check(lines[9]:find("^<ARM") ~= nil, "all MANUAL: L4 <ARM")
T.equal(cmd("L4"), "laminar/B747/door/mode_auto_all", "all MANUAL: L4 arms them all")
T.check(small()[9]:find("(DISARMED)", 1, true) ~= nil, "all MANUAL: (DISARMED)")
for i = 0, 11 do modes[i] = 1 end
lines = show(true)
T.check(lines[9]:find("^<DISARM") ~= nil, "all AUTOMATIC: L4 <DISARM")
T.equal(cmd("L4"), "laminar/B747/door/mode_manual_all", "all AUTOMATIC: L4 disarms them all")
T.check(small()[9]:find("(ARMED)", 1, true) ~= nil, "all AUTOMATIC: (ARMED)")
modes[3] = 0
lines = show(true)
T.check(lines[9]:find("^<ARM ") ~= nil and small()[9]:find("(MIXED)", 1, true) ~= nil, "mixed: (MIXED), L4 <ARM")
T.done()
