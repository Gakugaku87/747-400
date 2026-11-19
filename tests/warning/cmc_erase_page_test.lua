-- Run from the repository root with LuaJIT: luajit tests/warning/cmc_erase_page_test.lua
-- The CMC's PRESENT LEG FAULTS page (B744.fms.pages.cmc.lua; N19-WARN-03,
-- notes/ATA-31-warning.md §13) alone, with the CDU framework stubbed: the
-- latchable STATUS messages the EIUs show (laminar/B747/CAS/status_nvm), each
-- with ERASE> (LH24 p.65; LH_MAN p.75), four a page; ERASE> counts one more
-- on the message's ERASE counter. Its list of latchable messages is the
-- warning system's (B747.87.xt.warning.lua, the entries with a latch class).
local T = dofile("tests/lib/check.lua")("cmc_erase_page")

local nvm, counts = {}, {}
for i = 0, 255 do nvm[i], counts[i] = 0, 0 end
local env = setmetatable({
    find_dataref = function(name)
        if name == "laminar/B747/CAS/status_nvm" then return nvm end
        if name == "laminar/B747/CAS/status_erase_count" then return counts end
        return 0
    end,
    fmsPages = {},
    fmsFunctions = {},
    fmsFunctionsDefs = {PLFAULTS = {}, CMC = {}, CONFTEST = {}, EMANP = {}, GRDTEST = {}},
    createPage = function(name) return {name = name} end,
}, {__index = _G})
local chunk = assert(loadfile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/activepages/B744.fms.pages.cmc.lua"))
setfenv(chunk, env)
chunk()
local plf = env.fmsPages.PLFAULTS
local defs = env.fmsFunctionsDefs.PLFAULTS
local BLANK = "                        "

-- the page's list against the warning system's table (slot, name, latch)
do
    local want = {}
    local f = assert(io.open("plugins/xtlua/scripts/B747.87.xt.warning/B747.87.xt.warning.lua", "rb"))
    local text = f:read("*a")
    f:close()
    local status = text:match("local B747_CASstatusMsg = (%b{})")
    T.check(status ~= nil, "the warning system's STATUS table found")
    for index, name, latch in (status or ""):gmatch('{DRindex = (%d+), name = "([^"]+)", latch = "([^"]+)"}') do
        want[#want + 1] = index .. " " .. name
        T.check(latch == "NVM" or latch == "NVM-A" or latch == "NVM-G", name .. ": a known class (" .. latch .. ")")
    end
    local have = {}
    for _, m in ipairs(plf.latchable) do have[#have + 1] = m[1] .. " " .. m[2] end
    T.equal(table.concat(have, ","), table.concat(want, ","), "the CMC's latchable messages are the warning system's")
    T.equal(#have, 9, "nine latchable messages")
end

-- nothing latched: the title and <RETURN only (no development pages)
do
    local page, small = plf:getPage(1, 1), plf:getSmallPage(1, 1)
    T.equal(page[1], "  PRESENT LEG FAULTS 1/1", "empty: the title")
    for n = 3, 11, 2 do T.equal(page[n], BLANK, "empty: line " .. n .. " blank") end
    T.equal(small[10], "------------------------", "empty: the line above 5L")
    T.equal(page[13], "<RETURN                 ", "empty: 6L <RETURN")
    T.equal(plf:getNumPages(1), 1, "empty: one page")
    T.check(not page[2]:find("THROTTLE", 1, true) and not page[1]:find("THROTTLE", 1, true),
        "no THROTTLE TESTS (N19-CMC-01's development page)")
end

-- five shown: two pages, four on the first in slot order, ERASE> on each
nvm[8], nvm[26], nvm[27], nvm[28], nvm[95] = 2, 2, 1, 2, 2
do
    T.equal(plf:getNumPages(1), 2, "five: two pages")
    local page, small = plf:getPage(1, 1), plf:getSmallPage(1, 1)
    T.equal(page[1], "  PRESENT LEG FAULTS 1/2", "five: page 1 of 2")
    T.equal(page[3], "HYD OVHT SYS 1    ERASE>", "1L")
    T.equal(page[5], "DRIVE DISC 2      ERASE>", "2L")
    T.equal(page[7], "DRIVE DISC 3      ERASE>", "3L: shown and not latched, ERASE> too (LH_MAN p.75: latchable)")
    T.equal(page[9], "DRIVE DISC 4      ERASE>", "4L")
    T.equal(page[11], BLANK, "5L blank (<ERASE STATUS: no source for it)")
    for k = 1, 4 do T.equal(small[2 * k], "*STATUS:                ", "*STATUS: above " .. k .. "L") end
    page = plf:getPage(2, 1)
    T.equal(page[1], "  PRESENT LEG FAULTS 2/2", "page 2 of 2")
    T.equal(page[3], "BODY GR STRG SYS  ERASE>", "page 2: 1L")
    T.equal(page[5], BLANK, "page 2: 2L blank")
    T.equal(env.fmsFunctionsDefs.PLFAULTS.L6[2], "CMC", "6L: back to the CMC MENU")
end

-- ERASE>: the right keys, one more on the message's counter
do
    for k = 1, 4 do T.equal(defs["R" .. k][1], "cmcerase", k .. "R: ERASE") end
    env.fmsFunctions.cmcerase({pgNo = 1}, 2)
    T.equal(counts[26], 1, "2R on page 1: DRIVE DISC 2's counter 1")
    env.fmsFunctions.cmcerase({pgNo = 2}, 1)
    T.equal(counts[95], 1, "1R on page 2: BODY GR STRG SYS's counter 1")
    -- the counter as read lags (another plugin's dataref): counts on from its own
    counts[26] = 0
    env.fmsFunctions.cmcerase({pgNo = 1}, 2)
    T.equal(counts[26], 2, "a stale read: the counter still goes on (2)")
    env.fmsFunctions.cmcerase({pgNo = 2}, 3)
    T.equal(counts[8] + counts[27] + counts[28], 0, "a key without a message: nothing")
end

T.done()
