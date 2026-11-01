-- Run from the repository root with LuaJIT: luajit tests/fms/atc_uplink_model_test.lua
-- The ATC uplinks (6-1/6-2 step 12f; notes/ATA-34-61-FMC.md §114; FCOM
-- p.752-754, p.758-765; FMSPG p.286-291): the response an uplink allows,
-- its status, its pages, the ATC key's page.
local T = dofile("tests/lib/check.lua")("atc_uplink_model")
local U = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_uplink_model.lua")

-- the responses (an estimate from the words)
T.equal(U.response("CLIMB TO AND MAINTAIN FL350"), "WU", "CLIMB TO: WILCO/UNABLE")
T.equal(U.response("PROCEED DIRECT TO SEA"), "WU", "PROCEED DIRECT: WU")
T.equal(U.response("CONTACT TOKYO CONTROL 124.1"), "WU", "CONTACT: WU")
T.equal(U.response("CAN YOU ACCEPT FL370 AT 1500Z"), "AN", "CAN YOU: AFFIRM/NEGATIVE")
T.equal(U.response("EXPECT FL390 AT 1600Z"), "R", "EXPECT: ROGER")
T.equal(U.response("REPORT REACHING FL350"), "R", "REPORT: ROGER")
T.equal(U.response("UNABLE"), "NE", "ATC's UNABLE: no response")
T.equal(U.response("LOGON ACCEPTED"), "NE", "LOGON ACCEPTED: no response")
T.equal(U.response("REQUEST DEFERRED"), "NE", "REQUEST DEFERRED: none")
T.equal(U.response("TURBULENCE REPORTED AHEAD"), "R", "free text: ROGER")
T.equal(U.accept_word("WU"), "WILCO", "ACCEPT: WILCO")
T.equal(U.accept_word("AN"), "AFFIRM", "AFFIRM")
T.equal(U.accept_word("R"), "ROGER", "ROGER")
T.equal(U.reject_word("WU"), "UNABLE", "REJECT: UNABLE")
T.equal(U.reject_word("AN"), "NEGATIVE", "NEGATIVE")
T.equal(U.reject_word("R"), nil, "ROGER only: no REJECT")
T.equal(U.accept_word("NE"), nil, "no response: no ACCEPT")

-- the status (FCOM p.753)
local u = {read = false, resp = "WU"}
T.equal(U.status(u), "NEW", "NEW until reviewed")
T.check(U.pending(u), "NEW: pending")
u.read = true
T.equal(U.status(u), "OPEN", "reviewed, a response due: OPEN")
T.check(U.awaiting(u), "awaiting a response")
u.sent = "STANDBY"
T.equal(U.status(u), "OPEN", "STANDBY sent: OPEN still")
u.acked = "ACCEPT"
T.equal(U.status(u), "ACCEPTED", "acknowledged positive: ACCEPTED")
T.check(not U.pending(u), "not pending")
T.check(not U.awaiting(u), "no response due")
T.equal(U.status({read = true, resp = "WU", acked = "REJECT"}), "REJECTED", "REJECTED")
T.equal(U.status({read = true, resp = "NE"}), "OLD", "no response: OLD")
T.equal(U.status({read = false, resp = "WU", aborted = true}), "ABORTED", "ABORTED")

-- the text's lines and pages
local w = U.wrap("CLIMB TO AND MAINTAIN FL350 EXPECT HIGHER IN TEN MINUTES", 24)
T.equal(w[1], "CLIMB TO AND MAINTAIN", "wrapped at spaces")
T.equal(w[2], "FL350 EXPECT HIGHER IN", "the second line")
T.equal(w[3], "TEN MINUTES", "the third")
T.equal(U.wrap("ABCDEFGHIJKLMNOPQRSTUVWXYZ", 24)[2], "YZ", "a long word cut")
local four = {"A", "B", "C", "D"}
T.equal(U.pages(four), 1, "four lines: one page")
local line, text, more = U.page_lines(four, 1)
T.check(line == 4 and #text == 4 and not more, "one page: line 4 on, four lines")
local nine = {"1", "2", "3", "4", "5", "6", "7", "8", "9"}
T.equal(U.pages(nine), 2, "nine lines: two pages")
line, text, more = U.page_lines(nine, 1)
T.check(line == 4 and #text == 8 and more, "page 1: eight lines, continued")
line, text, more = U.page_lines(nine, 2)
T.check(line == 2 and text[1] == "9" and not more, "the last page: from line 2")
local many = {}
for k = 1, 24 do many[k] = tostring(k) end
T.equal(U.pages(many), 3, "24 lines: 8 + 10 + 6, three pages")
many[25] = "25"
T.equal(U.pages(many), 4, "25 lines: four pages")
many[25] = nil
line, text, more = U.page_lines(many, 2)
T.check(line == 2 and text[1] == "9" and #text == 10 and more, "a middle page: ten lines, continued")
line, text = U.page_lines(many, 3)
T.equal(text[1], "19", "the last: from 19")

-- the ATC key (FCOM p.752, p.758; FMSPG p.286, p.288)
T.equal(U.route(false, {}), "LOGON", "no ATC COMM: LOGON/STATUS")
T.equal(U.route(true, {}), "INDEX", "nothing pending: ATC INDEX")
T.equal(U.route(true, {{read = true, resp = "NE"}, {read = false, resp = "WU"}}), 2, "one new: its page")
T.equal(U.route(true, {{read = true, resp = "WU"}}), 1, "one pending (OPEN): its page")
T.equal(U.route(true, {{read = false, resp = "WU"}, {read = false, resp = "R"}}), "LOG", "two new: ATC LOG")
T.equal(U.route(true, {{read = true, resp = "WU"}, {read = true, resp = "AN"}}), "LOG", "none new, two pending: ATC LOG")
T.equal(U.route(true, {{read = true, resp = "WU"}, {read = false, resp = "R"}}), 2, "one new and another pending: the new one (estimate)")
T.equal(U.route(true, {{read = true, resp = "WU", acked = "ACCEPT"}}), "INDEX", "answered: ATC INDEX")
T.done()
