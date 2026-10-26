-- Run from the repository root with LuaJIT: luajit tests/displays/eicas_format_test.lua
-- The EICAS formats (5-2 step 6b, GAP DSP-24, ENG-22; FCOM p.839-840,
-- p.852-857, p.872-875): the EICAS format model (plugins/xtlua_keysystems/
-- scripts/B747.60.xt.fltInst/B747.60.eicas_format_model.lua: ENG at the
-- first power, the partial format, the compact format, the exceedance cue),
-- then the display glue in the flight instruments module as XTLua runs it
-- (tests/lib/xtlua.lua).
local T = dofile("tests/lib/check.lua")("eicas_format")
local FM = dofile("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.eicas_format_model.lua")
local xtlua = dofile("tests/lib/xtlua.lua")

local function rows(t) return string.format("%d%d%d%d", t[1] and 1 or 0, t[2] and 1 or 0, t[3] and 1 or 0, t[4] and 1 or 0) end
local inp = {synoptic = FM.SYN_NONE, exceed_n2 = false, exceed_oil = false, exceed_vib = false,
    pri_shown = false, sec_shown = false}

-- ENG when the displays first get power (FCOM p.872)
local s = FM.new()
local o = FM.update(s, inp)
T.check(not o.select_eng, "no power: nothing")
inp.pri_shown, inp.sec_shown = true, true
o = FM.update(s, inp)
T.check(o.select_eng and o.sec and rows(o.sec_rows) == "1111", "power: ENG comes up, every row")
o = FM.update(s, inp)
T.check(not o.select_eng and not o.sec, "then the selection is the switches' again")
s = FM.new()
o = FM.update(s, inp)
T.check(not o.select_eng, "powered at the load: no selection")

-- the ENG switch: every row on secondary EICAS
inp.synoptic = FM.SYN_ENG
o = FM.update(s, inp)
T.check(o.sec and rows(o.sec_rows) == "1111" and o.compact == FM.COMPACT_OFF and not o.cue,
    "ENG: N2, FF, oil and VIB on secondary EICAS")
inp.synoptic = FM.SYN_NONE
o = FM.update(s, inp)
T.check(not o.sec and rows(o.sec_rows) == "0000", "nothing selected, nothing exceeding: none")

-- the partial format and the cue (FCOM p.839-840, p.852-854)
inp.exceed_oil = true
o = FM.update(s, inp)
T.check(o.sec and rows(o.sec_rows) == "0010" and o.cue and o.compact == FM.COMPACT_OFF,
    "oil exceeding, not selected: the oil rows alone, the cue")
inp.exceed_n2 = true
o = FM.update(s, inp)
T.equal(rows(o.sec_rows), "1010", "N2 too: N2 and oil")
inp.exceed_n2, inp.exceed_oil, inp.exceed_vib = false, false, true
o = FM.update(s, inp)
T.equal(rows(o.sec_rows), "0001", "the vibration at the high band: VIB")
inp.synoptic = FM.SYN_ENG
o = FM.update(s, inp)
T.check(o.sec and rows(o.sec_rows) == "1111" and o.cue, "ENG in the partial format: every row, the cue stays")
inp.synoptic = FM.SYN_NONE
o = FM.update(s, inp)
T.equal(rows(o.sec_rows), "0001", "ENG again: the partial rows")

-- another display selected: the partial rows in compact format on primary
inp.synoptic = 4                                                   -- FUEL
o = FM.update(s, inp)
T.check(not o.sec and o.compact == FM.COMPACT_PARTIAL and rows(o.cmp_rows) == "0001" and o.cue,
    "FUEL selected: the partial rows go to primary EICAS in compact format (FCOM p.875)")
inp.exceed_vib = false
o = FM.update(s, inp)
T.check(o.compact == FM.COMPACT_OFF and not o.cue and rows(o.cmp_rows) == "0000",
    "back in the normal range: the compact rows and the cue go")

-- one display unit for EICAS: compact format on primary (FCOM p.874-875)
inp.sec_shown = false
inp.synoptic = FM.SYN_ENG
o = FM.update(s, inp)
T.check(not o.sec and o.compact == FM.COMPACT_FULL and rows(o.cmp_rows) == "1111",
    "one display, ENG: every row in compact format")
inp.synoptic = FM.SYN_NONE
o = FM.update(s, inp)
T.equal(o.compact, FM.COMPACT_OFF, "ENG again: the normal format")
inp.exceed_n2 = true
o = FM.update(s, inp)
T.check(o.compact == FM.COMPACT_PARTIAL and rows(o.cmp_rows) == "1000" and o.cue,
    "one display, N2 exceeding: the partial rows in compact format")
inp.exceed_n2 = false

-- the glue
local rt = xtlua.new()
rt:load("plugins/xtlua_keysystems/scripts/B747.60.xt.fltInst/B747.60.xt.fltInst.lua")
rt:callout("flight_start")
local BUSES = {"stby_apu", "stby_main", "xfr_capt", "xfr_fo", "any_ac"}
rt:set("laminar/B747/dsp/synoptic_display", 0)
rt:frame(0.1)
for _, b in ipairs(BUSES) do rt:set("laminar/B747/electrical/bus/" .. b, 1) end
rt:frame(0.1)
T.equal(rt:get("laminar/B747/dsp/synoptic_display"), 1, "the glue: power on, ENG selected")
local E = "laminar/B747/eicas/"
local function grows(name)
    local t = {}
    for r = 0, 3 do t[#t + 1] = string.format("%d", rt:get(E .. name, r)) end
    return table.concat(t)
end
T.check(rt:get(E .. "sec_eng") == 1 and grows("sec_rows") == "1111", "every secondary engine row")
rt:command("laminar/B747/dsp/eng_switch")
rt:frame(0.1)
T.check(rt:get("laminar/B747/dsp/synoptic_display") == 0 and rt:get(E .. "sec_eng") == 0, "ENG: off")
rt:set("laminar/B747/engines/sec_exceed", 1, 1)                    -- the oil
rt:frame(0.1)
T.check(rt:get(E .. "sec_eng") == 1 and grows("sec_rows") == "0010", "an oil exceedance: the oil rows alone")
T.check(rt:get(E .. "exceed_cue") == 1 and rt:get(E .. "exceed_cue_text") == "VVVVVV", "the cue: VVVVVV")
rt:command("laminar/B747/dsp/eng_switch")
rt:frame(0.1)
T.equal(grows("sec_rows"), "1111", "ENG: every row")
rt:command("laminar/B747/dsp/eng_switch")
rt:frame(0.1)
T.equal(grows("sec_rows"), "0010", "ENG again: the partial rows")
rt:command("laminar/B747/dsp/fuel_switch")
rt:frame(0.1)
T.check(rt:get(E .. "sec_eng") == 0 and rt:get(E .. "compact") == FM.COMPACT_PARTIAL and grows("cmp_rows") == "0010",
    "FUEL: the oil rows in compact format on primary EICAS")
rt:command("laminar/B747/dsp/fuel_switch")
rt:set("laminar/B747/displays/fail", 3, 1)                         -- the lower display unit
rt:frame(0.1)
T.check(rt:get(E .. "compact") == FM.COMPACT_PARTIAL and rt:get(E .. "sec_eng") == 0,
    "the lower unit failed: the partial rows in compact format")
rt:set("laminar/B747/engines/sec_exceed", 1, 0)
rt:frame(0.1)
T.check(rt:get(E .. "compact") == FM.COMPACT_OFF and rt:get(E .. "exceed_cue") == 0, "normal again: none")
rt:command("laminar/B747/dsp/eng_switch")
rt:frame(0.1)
T.check(rt:get(E .. "compact") == FM.COMPACT_FULL and grows("cmp_rows") == "1111", "one display, ENG: compact format")

T.done()
