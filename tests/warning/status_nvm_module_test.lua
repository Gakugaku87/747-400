-- Run from the repository root with LuaJIT: luajit tests/warning/status_nvm_module_test.lua
-- The EIUs' latched STATUS messages (N19-WARN-03; notes/ATA-31-warning.md
-- §13) in the crew alerting module as XTLua runs it (tests/lib/xtlua.lua),
-- with the CMC's PRESENT LEG FAULTS page (B744.fms.pages.cmc.lua, the FMS
-- plugin's) on the same datarefs: DRIVE DISC 2 (NVM, LH24 p.64) stays on the
-- STATUS page after the IDG's reset and through the EIUs' power loss; HYD
-- OVHT SYS 1 (NVM-A, ATA29_32 p.100) latches in the air only; the CMC's
-- ERASE> takes a latched one off (LH24 p.64-65); a new X-Plane flight
-- empties the memory; not latchable messages go with their condition as
-- before. The ERASE counter is read lagged, as from another plugin.
local T = dofile("tests/lib/check.lua")("status_nvm_module")
local xtlua = dofile("tests/lib/xtlua.lua")

local rt = xtlua.new{lagged = {"laminar/B747/CAS/status_erase_count"}}
rt:load("plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.warning.lua")
rt:set("sim/operation/prefs/startup_running", 0)
rt:callout("flight_start")

local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
local STATUS = "laminar/B747/CAS/status_status"
local NVM = "laminar/B747/CAS/status_nvm"
local PSEU_AIR = "laminar/B747/gear/air_ground/pri_air"
local DRIVE_DISC_2, HYD_OVHT_1, HYDIM_1, BODY_GR = 26, 8, 16, 95
-- the STATUS page's lines (page 1)
local function status_lines()
    local t = {}
    for slot = 0, 10 do
        local s = rt:get(string.format("laminar/B747/CAS/gen_status_msg_%03d", slot))
        if s ~= " " and s ~= "" then t[#t + 1] = s end
    end
    return table.concat(t, ",")
end
local function eius(on)
    rt:set("laminar/B747/electrical/bus/stby_main", on and 1 or 0)
    rt:set("laminar/B747/electrical/bus/xfr_fo", on and 1 or 0)
end

-- the CMC page, its datarefs those of this runtime (the test side's reads
-- are not lagged: the FMS reads the warning system's array every frame)
local function proxy(name)
    return setmetatable({}, {__index = function(_, i) return rt:get(name, i) end,
        __newindex = function(_, i, v) rt:set(name, i, v) end})
end
local cmc = setmetatable({
    find_dataref = proxy,
    fmsPages = {},
    fmsFunctions = {},
    fmsFunctionsDefs = {},
    createPage = function(name) return {name = name} end,
}, {__index = _G})
cmc.fmsFunctionsDefs.PLFAULTS = {}
cmc.fmsFunctionsDefs.CMC = {}
cmc.fmsFunctionsDefs.CONFTEST = {}
cmc.fmsFunctionsDefs.EMANP = {}
cmc.fmsFunctionsDefs.GRDTEST = {}
local chunk = assert(loadfile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/activepages/B744.fms.pages.cmc.lua"))
setfenv(chunk, cmc)
chunk()
local plf = cmc.fmsPages.PLFAULTS
local function erase_key(k) cmc.fmsFunctions.cmcerase({pgNo = 1}, k) end

-- the EIUs start 4 s after their power comes (on the ground)
eius(true)
frames(5)

-- DRIVE DISC 2: the IDG disconnected, then reset on the ground (LH24 p.64)
rt:set(STATUS, DRIVE_DISC_2, 1)
frames(0.5)
T.equal(status_lines(), "DRIVE DISC 2", "DRIVE DISC 2 on the STATUS page")
T.equal(rt:get(NVM, DRIVE_DISC_2), 2, "DRIVE DISC 2 latched (status_nvm 2)")
rt:set(STATUS, DRIVE_DISC_2, 0)
frames(0.5)
T.equal(status_lines(), "DRIVE DISC 2", "DRIVE DISC 2 stays after the IDG's reset (LH24 p.64)")
T.equal(rt:get(NVM, DRIVE_DISC_2), 2, "DRIVE DISC 2 still latched")

-- a not latchable message goes with its condition, as before
rt:set(STATUS, HYDIM_1, 1)
frames(0.5)
T.equal(status_lines(), "HYDIM 1,DRIVE DISC 2", "HYDIM 1 on top, the newest")
T.equal(rt:get(NVM, HYDIM_1), 0, "HYDIM 1: not latchable, not for the CMC")
rt:set(STATUS, HYDIM_1, 0)
frames(0.5)
T.equal(status_lines(), "DRIVE DISC 2", "HYDIM 1 gone with its condition")

-- HYD OVHT SYS 1 on the ground: shown, not latched; gone with its condition
rt:set(STATUS, HYD_OVHT_1, 1)
frames(0.5)
T.equal(rt:get(NVM, HYD_OVHT_1), 1, "HYD OVHT SYS 1 on the ground: shown, not latched (NVM-A)")
rt:set(STATUS, HYD_OVHT_1, 0)
frames(0.5)
T.equal(status_lines(), "DRIVE DISC 2", "HYD OVHT SYS 1 on the ground: gone with its condition")

-- in the air: latched (ATA29_32 p.100), stays after the landing
rt:set(PSEU_AIR, 1)
frames(0.5)
rt:set(STATUS, HYD_OVHT_1, 1)
frames(0.5)
rt:set(STATUS, HYD_OVHT_1, 0)
rt:set(PSEU_AIR, 0)
frames(0.5)
T.equal(status_lines(), "HYD OVHT SYS 1,DRIVE DISC 2", "HYD OVHT SYS 1 latched in the air, on top")
T.equal(rt:get(NVM, HYD_OVHT_1), 2, "HYD OVHT SYS 1 latched (status_nvm 2)")

-- the EIUs' power loss: the page blank, the CMC told nothing; back with
-- their power, the latched ones in their order (LH_MAN p.52: NVM)
eius(false)
frames(1)
T.equal(status_lines(), "", "EIUs off: the STATUS page blank")
T.equal(rt:get(NVM, DRIVE_DISC_2), 0, "EIUs off: status_nvm 0")
eius(true)
frames(5)
T.equal(status_lines(), "HYD OVHT SYS 1,DRIVE DISC 2", "EIUs back: the latched messages back, in their order")

-- the CMC's PRESENT LEG FAULTS: the latched ones with ERASE> (LH24 p.65)
local page, small = plf:getPage(1, 1), plf:getSmallPage(1, 1)
T.equal(page[1], "  PRESENT LEG FAULTS 1/1", "CMC: the title")
T.equal(small[2], "*STATUS:                ", "CMC: *STATUS: above the first")
T.equal(page[3], "HYD OVHT SYS 1    ERASE>", "CMC: 1L HYD OVHT SYS 1 with ERASE>")
T.equal(page[5], "DRIVE DISC 2      ERASE>", "CMC: 2L DRIVE DISC 2 with ERASE>")
T.equal(page[13], "<RETURN                 ", "CMC: 6L <RETURN")

-- ERASE> next to DRIVE DISC 2: off the EIUs' memory and the STATUS page
erase_key(2)
T.equal(rt:get("laminar/B747/CAS/status_erase_count", DRIVE_DISC_2), 1, "CMC: ERASE counted for DRIVE DISC 2")
frames(0.5)
T.equal(status_lines(), "HYD OVHT SYS 1", "ERASE: DRIVE DISC 2 off the STATUS page (LH24 p.64)")
T.equal(rt:get(NVM, DRIVE_DISC_2), 0, "ERASE: DRIVE DISC 2 not latched")
page = plf:getPage(1, 1)
T.equal(page[3], "HYD OVHT SYS 1    ERASE>", "CMC: HYD OVHT SYS 1 left")
T.equal(page[5], "                        ", "CMC: DRIVE DISC 2 gone from the page")

-- ERASE with the condition still there (the IDG not reset, LH24 p.64): gone
-- until it goes and comes again
rt:set(STATUS, DRIVE_DISC_2, 1)
frames(0.5)
T.equal(rt:get(NVM, DRIVE_DISC_2), 2, "a new DRIVE DISC 2: latched")
page = plf:getPage(1, 1)
local key
for k = 1, 4 do if page[1 + 2 * k]:find("DRIVE DISC 2", 1, true) then key = k end end
erase_key(key or 1)
frames(0.5)
T.check(not status_lines():find("DRIVE DISC 2", 1, true), "ERASE with the IDG not reset: off the STATUS page")
rt:set(STATUS, DRIVE_DISC_2, 0)
frames(0.5)
rt:set(STATUS, DRIVE_DISC_2, 1)
frames(0.5)
T.check(status_lines():find("DRIVE DISC 2", 1, true) ~= nil, "DRIVE DISC 2 again: back")

-- pushes while the EIUs do not run do nothing
eius(false)
frames(1)
erase_key(1)        -- the page lists nothing now: no counter moves
cmc.fmsFunctions.cmcerase({pgNo = 1}, 1)
rt:set("laminar/B747/CAS/status_erase_count", HYD_OVHT_1, rt:get("laminar/B747/CAS/status_erase_count", HYD_OVHT_1) + 1)
frames(0.5)
eius(true)
frames(5)
T.check(status_lines():find("HYD OVHT SYS 1", 1, true) ~= nil, "an ERASE while the EIUs are off: nothing erased")

-- BODY GR STRG SYS (NVM, ATA29_32 p.626)
rt:set(STATUS, BODY_GR, 1)
frames(0.5)
rt:set(STATUS, BODY_GR, 0)
frames(0.5)
T.check(status_lines():find("BODY GR STRG SYS", 1, true) ~= nil, "BODY GR STRG SYS stays (NVM)")

-- a new X-Plane flight: the memory empty (estimate)
rt:set(STATUS, DRIVE_DISC_2, 0)
rt:callout("flight_start")
frames(5)
T.equal(status_lines(), "", "a new flight: no latched STATUS message")
T.equal(rt:get(NVM, HYD_OVHT_1), 0, "a new flight: status_nvm 0")

T.done()
