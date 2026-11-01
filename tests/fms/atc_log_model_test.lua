-- Run from the repository root with LuaJIT: luajit tests/fms/atc_log_model_test.lua
-- The ATC LOG (6-1/6-2 step 12g1; notes/ATA-34-61-FMC.md §115; FCOM
-- p.752-754; FMSPG p.357-362): newest first, five a page, the data line and
-- the header, the non-pending entries ERASE LOG takes.
local T = dofile("tests/lib/check.lua")("atc_log_model")
local G = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_log_model.lua")

local es = {
    {seq = 1, up = true, time = "1619", text = "PRESENT POSITION N4517.2 W12233.1", status = "OLD", pending = false},
    {seq = 3, up = false, time = "1630", text = "REQUEST FL350", status = "SENT", pending = false},
    {seq = 2, up = true, time = "1625", text = "CLIMB TO AND MAINTAIN FL310", status = "OPEN", pending = true},
    {seq = 4, up = true, time = "1658", text = "EXPECT HIGHER", status = "NEW", pending = true, deleted = true},
}
local list = G.sorted(es)
T.equal(#list, 3, "a deleted entry left out")
T.equal(list[1].seq, 3, "newest first (FMSPG p.357)")
T.equal(list[3].seq, 1, "oldest last")
T.equal(G.line(list[1]), "REQUEST FL350          >", "21 characters or fewer: whole, then the caret")
T.equal(G.line(list[3]), "PRESENT POSITION N4..  >", "longer: 19 and two periods (FCOM p.753)")
T.equal(G.header(list[2]), " 1625Z" .. string.rep(" ", 14) .. "OPEN", "the header: the time and the status")
T.equal(#G.header(list[2]), 24, "the header: a CDU line's 24")
T.check(G.erasable(list), "non-pending entries: ERASE LOG")
T.check(not G.erasable({list[2]}), "only a pending one: no ERASE LOG")
T.equal(G.pages(list), 1, "three entries: one page")
local many = {}
for k = 1, 11 do many[k] = {seq = k, text = "M" .. k, status = "OLD", pending = false} end
local sm = G.sorted(many)
T.equal(G.pages(sm), 3, "eleven: three pages of five")
T.equal(G.page(sm, 2)[1].seq, 6, "page 2 from the sixth newest")
T.equal(#G.page(sm, 3), 1, "the last page's one")
T.done()
