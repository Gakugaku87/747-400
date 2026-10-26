-- Run from the repository root with LuaJIT: luajit tests/fms/cdu_framework_test.lua
-- The CDU framework (6-1/6-2 step 2; notes/ATA-34-61-CDU.md §3.1, §3.2,
-- §4.1) in the FMS module (B747.68.xt.fms) as XTLua runs it
-- (tests/lib/xtlua.lua): the scratchpad's keys (CLR, CLR held, DEL, +/-,
-- FCOM p.1212-1213), the CDU's own entry messages and the FMC's on every
-- CDU, cleared from all by one CLR, a condition's not again while it holds
-- (FCOM p.1430; FMSPG p.39), >FMC MESSAGE for the alerts (FCOM p.1429), an
-- event's flag cleared once posted, the CDU's power (no keys, MENU when it
-- comes: FMSPG p.53), NEXT on the last page to the first (FMSPG p.42), the
-- custom pages at once (CDU-23).
local T = dofile("tests/lib/check.lua")("cdu_framework")
local xtlua = dofile("tests/lib/xtlua.lua")

local types = {}
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do types["sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n] = "string" end
end
local rt = xtlua.new{types = types}
rt:load("plugins/xtlua_keysystems/scripts/B747.68.xt.fms/B747.68.xt.fms.lua")
rt:set("laminar/B747/simconfig", '{"SIM":{"weight_display_units":"KGS","kgs_to_lbs":2.20462},"PLANE":{"thrust_ref":"EPR","engines":"PW4056"}}')
rt:set("laminar/B747/newsimconfig", 1)
rt:set("sim/operation/prefs/startup_running", 1)
for i = 6, 8 do rt:set("laminar/B747/electrical/display_has_power", i, 6) end
rt:callout("flight_start")
for _, cdu in ipairs({"cdu1", "cdu2"}) do
    for n = 0, 15 do rt:set("sim/cockpit2/radios/indicators/fms_" .. cdu .. "_text_line" .. n, string.rep(" ", 24)) end
end
local function frames(seconds)
    for _ = 1, math.floor(seconds * 30 + 0.5) do rt:frame(1 / 30) end
end
frames(4)

-- the left CDU: keys fms1, lines fms3; the right: keys and lines fms2
local CDU = {L = {keys = "laminar/B747/fms1/", lines = "laminar/B747/fms3/"},
             R = {keys = "laminar/B747/fms2/", lines = "laminar/B747/fms2/"}}
local function line(c, n) return rt:get(string.format("%sLine%02d_L", CDU[c].lines, n)) end
local function pad(c) return (line(c, 14):gsub("%s+$", "")) end
local function key(c, k, held)
    rt:command(CDU[c].keys .. k, held)
    frames(0.1)
end
local function type_in(c, text)
    for ch in text:gmatch(".") do
        local k = ch == "/" and "key/slash" or ch == "." and "key/period" or ch == " " and "key/space" or "alphanum_key/" .. ch
        rt:command(CDU[c].keys .. k)
    end
    frames(0.1)
end

-- the custom pages at once: no blank half second (CDU-23)
key("L", "func_key/fix")
T.check(line("L", 1):find("MENU"), "the MENU page at once (before: blank for half a second): " .. line("L", 1))

-- the scratchpad's keys
type_in("L", "FL350")
T.equal(pad("L"), "FL350", "typed in")
T.equal(pad("R"), "", "the right CDU's scratchpad its own")
key("L", "key/clear")
T.equal(pad("L"), "FL35", "CLR: the last character (before: all)")
key("L", "key/clear", 1.2)
T.equal(pad("L"), "", "CLR held a second: all")
type_in("L", "1")
key("L", "key/minus")
T.equal(pad("L"), "1-", "+/-: -")
key("L", "key/minus")
T.equal(pad("L"), "1+", "+/- again: + (before: always -)")
key("L", "key/clear", 1.2)
key("L", "key/del")
T.equal(pad("L"), "DELETE", "DEL in the empty scratchpad: DELETE")
type_in("L", "A")
T.equal(pad("L"), "DELETE", "no typing onto DELETE")
key("L", "key/clear")
T.equal(pad("L"), "", "CLR takes DELETE back")
type_in("L", "AB")
key("L", "key/del")
T.equal(pad("L"), "AB", "DEL with data: nothing (before: the last character)")
key("L", "key/clear", 1.2)
type_in("L", string.rep("9", 30))
T.equal(#pad("L"), 24, "24 characters at most")
key("L", "key/clear", 1.2)

-- an entry's message: this CDU's only; no typing under it; CLR
key("L", "func_key/index")
key("L", "ls_key/L6")  -- <INDEX (the INIT REF key goes by context: step 3a)
key("L", "ls_key/L3")                                 -- PERF INIT
type_in("L", "A")
key("L", "ls_key/R4")                                 -- CRZ CG: INVALID ENTRY
T.equal(pad("L"), "INVALID ENTRY", "the entry's message on the left CDU")
T.equal(pad("R"), "", "not on the right")
type_in("L", "B")
key("L", "key/clear")
T.equal(pad("L"), "A", "no typing while the message shows; CLR: the message goes, the scratchpad back")
key("L", "key/clear")

-- the FMC's messages: on every CDU, cleared from all by one CLR
local N = "laminar/B747/fms/notification"
rt:set(N, 33, 1)                                       -- RESET MCP ALT (B744.notifications.lua + 1)
frames(0.2)
T.check(pad("L") == "RESET MCP ALT" and pad("R") == "RESET MCP ALT", "an FMC alert on both CDUs")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 145), 1, ">FMC MESSAGE with the alert")
type_in("R", "X")
T.equal(pad("R"), "RESET MCP ALT", "no typing under it")
key("R", "key/clear")
T.check(pad("L") == "" and pad("R") == "", "CLR on the right CDU: gone from both (before: the flag cleared)")
T.equal(rt:get("laminar/B747/CAS/advisory_status", 145), 0, "no >FMC MESSAGE once cleared")
T.equal(rt:get(N, 33), 1, "the system's flag stays (its condition)")
frames(11)
T.equal(pad("L"), "", "not again while the condition holds (before: again in ten seconds)")
rt:set(N, 33, 0)
frames(0.2)
rt:set(N, 33, 1)
frames(0.2)
T.equal(pad("L"), "RESET MCP ALT", "the condition again: the message again")
rt:set(N, 33, 0)
frames(0.2)
T.equal(pad("L"), "", "the condition gone: the message gone")
rt:set(N, 30, 1)                                       -- PERF/VNAV UNAVAILABLE: an event
frames(0.2)
T.equal(pad("L"), "PERF/VNAV UNAVAILABLE", "an event's message")
T.equal(rt:get(N, 30), 0, "its flag cleared once posted, so that it can come again")
key("L", "key/clear")
T.equal(pad("L"), "", "cleared")
rt:set(N, 30, 1)
frames(0.2)
T.equal(pad("R"), "PERF/VNAV UNAVAILABLE", "the event again: the message again")
key("R", "key/clear")
rt:set(N, 8, 1)                                        -- DISCONTINUITY (FCOM's name)
frames(0.2)
T.equal(pad("L"), "DISCONTINUITY", "FCOM's name (before: DISCONTINUITY - LNAV)")
rt:set(N, 8, 0)
frames(0.2)

-- X-Plane's CDU's scratchpad (brackets always): the keys the FMC types into
-- it (custom2fmc) no message while they go in, nor the text it typed; its
-- message after that this CDU's (step 2 fix: the typed text blocked the
-- typing)
local NATIVE = "sim/cockpit2/radios/indicators/fms_cdu1_text_line13"
local EMPTY = "[" .. string.rep(" ", 22) .. "]"
rt:set(NATIVE, EMPTY)
key("L", "func_key/prog")
type_in("L", "AB")
key("L", "func_key/next_pg")
rt:set(NATIVE, "[DELETE                ]")
frames(0.05)
rt:set(NATIVE, "[AB                    ]")
frames(0.05)
type_in("L", "C")
T.equal(pad("L"), "C", "the keys going into X-Plane's CDU (PROGRESS's NEXT: DEL, CLR, NEXT): no message, the typing goes on")
frames(1)
T.equal(pad("L"), "C", "the text typed left in X-Plane's CDU: no message")
rt:set(NATIVE, "[NOT IN DATABASE       ]")
frames(0.2)
T.equal(pad("L"), "NOT IN DATABASE", "X-Plane's message after that: this CDU's")
rt:set(NATIVE, EMPTY)
key("L", "key/clear")
key("L", "key/clear", 1.2)
T.equal(pad("L"), "", "cleared")
key("L", "func_key/fix")

-- NEXT on the last page: the first
key("L", "func_key/des")                               -- VNAV: CLB, CRZ, DES
local first = line("L", 1)
key("L", "func_key/next_pg")
key("L", "func_key/next_pg")
T.check(line("L", 1):find("DES"), "the third page: " .. line("L", 1))
key("L", "func_key/next_pg")
T.equal(line("L", 1), first, "NEXT on the last page: the first (FMSPG p.42)")

-- the CDU's power: no keys without it; MENU when it comes
rt:set("laminar/B747/electrical/display_has_power", 8, 0)
frames(0.2)
type_in("L", "Z")
rt:set("laminar/B747/electrical/display_has_power", 8, 6)
frames(0.2)
T.equal(pad("L"), "", "no keys without power")
T.check(line("L", 1):find("MENU"), "the MENU page when power comes: " .. line("L", 1))

T.done()
