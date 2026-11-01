-- Run from the repository root with LuaJIT: luajit tests/fms/atc_posrep_model_test.lua
-- POS REPORT (6-1/6-2 step 12g3b; notes/ATA-34-61-FMC.md §119; FCOM
-- p.766-768; FMSPG p.340-343): the entries over the FMC's values, DELETE
-- and leaving the page, the page's strings, the ATC report's text with
-- DEVIATING and CLIMBING/DESCENDING TO, the company report's with the fuel.
local T = dofile("tests/lib/check.lua")("atc_posrep_model")
dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_request_model.lua")
local P = dofile("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.atc_posrep_model.lua")

local d = {last = "4730N110W", ata = "1436Z", alt = "FL330", to = "GRF", eta = "1555Z", nxt = "46N120W",
    dest_eta = "1730Z", spd = ".80", temp_c = -52, wind_dir = 290, wind_kt = 70, fuel_k = 91.5}
local p = P.new()
local v = P.values(p, d)
local s = P.display(v)
T.equal(s.temp .. "|" .. s.wind .. "|" .. s.fuel, "-52`C|290`/ 70KT|91.5", "TEMP, WIND, FUEL as FCOM p.766")
T.equal(s.spd, ".80", "SPD")
T.equal(P.enter(p, "eta", "1600"), nil, "ETA entered")
T.equal(P.enter(p, "eta", "2460"), P.INVALID, "not a time")
T.equal(P.enter(p, "spd", "290"), nil, "SPD an IAS (FCOM p.767)")
T.equal(P.enter(p, "to", "SEA"), nil, "TO a position")
v = P.values(p, d)
s = P.display(v)
T.equal(s.to .. "|" .. s.eta .. "|" .. s.spd, "SEA|1600Z|290KT", "the entries over the FMC's (FCOM p.767)")
T.equal(P.atc_text(v), "POSITION REPORT LAST 4730N110W AT 1436Z ALT FL330 SPD 290KT TO SEA AT 1600Z NEXT 46N120W "
    .. "DEST ETA 1730Z TEMP -52C WIND 290/070KT", "the ATC report: the entries, no fuel (FMSPG p.342)")
T.equal(P.company_text(d), "POSITION REPORT LAST 4730N110W AT 1436Z ALT FL330 SPD .80 TO GRF AT 1555Z NEXT 46N120W "
    .. "DEST ETA 1730Z TEMP -52C WIND 290/070KT FUEL 91.5", "the company report: the FMC's and the fuel (FCOM p.768)")
T.equal(P.atc_text(v, {offset = -10, alt_ft = 33000, mcp_ft = 35000, mcp_text = "FL350"}):match("DEVIATING.*$"),
    "DEVIATING L10NM OF ROUTE CLIMBING TO FL350", "an offset, the MCP above: DEVIATING, CLIMBING TO (FMSPG p.343)")
T.equal(P.atc_text(v, {alt_ft = 33000, mcp_ft = 31000, mcp_text = "FL310"}):match("DESCENDING.*$"),
    "DESCENDING TO FL310", "the MCP below: DESCENDING TO")
T.check(not P.atc_text(v, {alt_ft = 33000, mcp_ft = 33100, mcp_text = "FL331"}):find("CLIMBING", 1, true),
    "within 150 ft: neither")
T.equal(P.enter(p, "eta", "DELETE"), nil, "DELETE")
T.equal(P.values(p, d).eta, "1555Z", "back to the FMC's (FCOM p.768)")
T.equal(P.enter(p, "eta", "DELETE"), "INVALID DELETE", "nothing to delete")
P.leave(p)
T.equal(P.values(p, d).spd, ".80", "the page left: SPD the FMC's (FCOM p.767)")
T.equal(P.values(p, d).to, "SEA", "the others kept")
local e = P.display(P.values(P.new(), {}))
T.equal(e.last .. e.temp .. e.wind .. e.fuel, "", "nothing known: blank")
T.equal(P.atc_text({}), "POSITION REPORT", "nothing known: the words alone")
T.done()
