-- Run from the repository root with LuaJIT: luajit tests/displays/stat_paging_test.lua
-- (2026-11-13; the 2026-11-12 review DSP-4, 案 12) The STAT switch's pages
-- (B747.60.xt.fltInst02.lua): each push the next page, the last page's push
-- closes it (FCOM p.1047, p.1530). The page count and the page are written
-- (the count) and held within it (the page) by the alert glue in the other
-- XTLua plugin (B747.87.xt.alerts.lua), read as XTLua reads another
-- plugin's dataref: the value fetched at the read before (tests/lib/
-- xtlua.lua's lagged). Before, the switch read them only when pushed: once
-- the messages filled two pages, STAT closed instead of turning to page 2.
local T = dofile("tests/lib/check.lua")("stat_paging")
local xtlua = dofile("tests/lib/xtlua.lua")
local NUM, PAGE, SYN = "laminar/B747/STAT/num_msg_pages", "laminar/B747/STAT/msg_page", "laminar/B747/dsp/synoptic_display"

local rt = xtlua.new({lagged = {NUM, PAGE}})
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
for _, b in ipairs({"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:callout("flight_start")
local function frames(n) for _ = 1, n do rt:frame(1 / 30) end end
frames(30)
-- the alert glue's part: the page count, the page held within it
local pages = 1
local function alerts()
    rt:set(NUM, pages)
    if rt:get(PAGE) > pages then rt:set(PAGE, pages) end
end
local function push()
    rt:command("laminar/B747/dsp/stat_switch", 0.2)
    frames(1) alerts() frames(5) alerts()
    return rt:get(SYN), rt:get(PAGE)
end
rt:set(SYN, 0) frames(2) alerts()
local syn, page = push()
T.equal(syn, 2, "one page: STAT opens STATUS")
syn = push()
T.equal(syn, 0, "  STAT again: closes")
pages = 2 alerts() frames(30)
syn, page = push()
T.equal(syn, 2, "two pages: STAT opens STATUS")
T.equal(page, 1, "  page 1")
syn, page = push()
T.equal(syn, 2, "  STAT again: still STATUS (before: closed)")
T.equal(page, 2, "  page 2")
syn = push()
T.equal(syn, 0, "  STAT on the last page: closes")
T.done()
