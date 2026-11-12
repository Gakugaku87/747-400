-- Run from the repository root with LuaJIT: luajit tests/static/snd_format_test.lua
-- (2026-11-12) The custom acf's sound definition fmod/747-400_custom.snd
-- (fmod/747-400.snd on the custom branch and in the release) against
-- X-Plane's "Sound (.snd) File Format Specification" (developer.x-plane.com,
-- read 2026-11-12) and the FMOD names of fmod/GUIDs.txt, without X-Plane:
--   - the header: A, 1000, ACF_SOUNDS;
--   - every other line blank, a '#' line (the spec has no comments; X-Plane
--     passes over the file's) or a directive of the spec, in its place:
--     REQUIRES_BANK, DISABLE_LEGACY_ALERT_SOUNDS and REF_POINT_ACF outside
--     the blocks, an attachment's directives in a BEGIN_SOUND_ATTACHMENT, a
--     sound space's in a BEGIN_SOUND_SPACE;
--   - each BEGIN ended by its END before the next BEGIN and before the end
--     of the file, no END without its BEGIN;
--   - each attachment with exactly one EVENT_NAME or SNAPSHOT_NAME, found as
--     event:<name> or snapshot:<name> on a line of GUIDs.txt that does not
--     start with '#'; each REQUIRES_BANK a file in fmod/.
-- Both kinds of error happened: EVENT_START_END for EVENT_END_COND in the
-- rain sound, which X-Plane 12.4.4 logged as "E/SOUN: Warning: unknown
-- line" at each load and ignored (2026-11-12), and the GPWS dontsink event,
-- commented out in GUIDs.txt, whose GUID X-Plane read with the '#': it hung
-- at the aircraft's load (2026-10-25, TESTING.md). The checker also runs on
-- small broken samples, so the test fails if it stops seeing them.
-- Not checked: the form of the conditions (the spec shows
-- "<dataref> <op> <value>"; 119 lines of the sound pack are a dataref alone,
-- most with DELTA=) and the attachment's location (the spec asks for a
-- VEH_XYZ or VEH_PART; the snapshots have none, and one gear_lock event
-- has none, as in the stock file).
-- On the development PC fmod/747-400.snd is the 3D set's local copy
-- (skip-worktree), which CLAUDE.md keeps the same as 747-400_custom.snd: the
-- two are then compared line by line. Elsewhere it is git's stock file, not
-- compared.
local T = dofile("tests/lib/check.lua")("snd_format")
local src = dofile("tests/lib/source.lua")

local SND = "fmod/747-400_custom.snd"
local GUIDS = "fmod/GUIDs.txt"
local LOCAL_COPY = "fmod/747-400.snd"

-- the spec's directives, by where they may appear
local HEADER = {"A", "1000", "ACF_SOUNDS"}
local OUTSIDE = {REQUIRES_BANK = true, DISABLE_LEGACY_ALERT_SOUNDS = true, REF_POINT_ACF = true}
local INSIDE = {
    BEGIN_SOUND_ATTACHMENT = {"EVENT_NAME", "SNAPSHOT_NAME", "VEH_XYZ", "VEH_THE", "VEH_PSI", "VEH_PHI",
        "VEH_PART", "EVENT_ALLOWED_FOR_AI", "PARAM_DREF_IDX", "EVENT_START_COND", "EVENT_END_COND",
        "EVENT_ALWAYS", "CUE_TRIGGER_COND", "EVENT_CMND_DOWN", "EVENT_CMND_UP", "EVENT_CMND_HOLD_STOP",
        "EVENT_CMND_HOLD_CUE", "EVENT_AUTO_END_FROM_START_COND", "EVENT_POLYPHONIC"},
    BEGIN_SOUND_SPACE = {"SOUND_INDEX", "BLEND_DEPTH", "SPHERE", "AABB"},
}
local END_OF = {BEGIN_SOUND_ATTACHMENT = "END_SOUND_ATTACHMENT", BEGIN_SOUND_SPACE = "END_SOUND_SPACE"}
local BEGIN_OF = {END_SOUND_ATTACHMENT = "BEGIN_SOUND_ATTACHMENT", END_SOUND_SPACE = "BEGIN_SOUND_SPACE"}
local KIND = {EVENT_NAME = "event", SNAPSHOT_NAME = "snapshot"}
local BLOCK_OF = {}  -- directive -> the BEGIN of the block it belongs in
for begin, words in pairs(INSIDE) do
    for _, word in ipairs(words) do BLOCK_OF[word] = begin end
end

-- a text's lines: Unix or Windows line ends (the spec), the last line with or without one
local function lines_of(text)
    if text:sub(-1) ~= "\n" then text = text .. "\n" end
    local lines = {}
    for line in text:gmatch("([^\n]*)\n") do lines[#lines + 1] = (line:gsub("\r$", "")) end
    return lines
end

-- the first line where two texts differ (their line ends aside), or nil
local function first_difference(a, b)
    a, b = lines_of(a), lines_of(b)
    for k = 1, math.max(#a, #b) do
        if a[k] ~= b[k] then return k end
    end
end

-- GUIDs.txt ("{guid} event:/path"): the names X-Plane can use, and those
-- only on a line that starts with '#' (X-Plane reads that line's GUID with
-- the '#', which no bank has)
local function guid_names(text)
    local names, commented = {}, {}
    for _, line in ipairs(lines_of(text)) do
        local hash, name = line:match("^%s*(#?)%s*{[%x%-]+}%s+(%a+:.-)%s*$")
        if name then
            if hash == "" then names[name] = true else commented[name] = true end
        end
    end
    return names, commented
end

-- The problems of an .snd text ("line N: what") and what was read.
-- has_bank(file) tells whether fmod/<file> exists.
local function check_snd(text, guids_text, has_bank)
    local names, commented = guid_names(guids_text)
    local problems, seen = {}, {attachments = 0, spaces = 0, names = 0, banks = 0}
    local function bad(n, what) problems[#problems + 1] = "line " .. n .. ": " .. what end
    local lines = lines_of(text)
    for k, want in ipairs(HEADER) do
        local got = (lines[k] or ""):match("^%s*(.-)%s*$")
        if got ~= want then bad(k, "the header's line " .. k .. " is \"" .. got .. "\", not " .. want) end
    end
    local block, block_line, named = nil, 0, 0
    local function close()
        if block == "BEGIN_SOUND_ATTACHMENT" and named ~= 1 then
            bad(block_line, "the attachment has " .. named .. " EVENT_NAME or SNAPSHOT_NAME (exactly one)")
        end
        block = nil
    end
    for n = #HEADER + 1, #lines do
        local word, rest = lines[n]:match("^%s*(%S+)%s*(.-)%s*$")
        if word and word:sub(1, 1) ~= "#" then
            if END_OF[word] then
                if block then
                    bad(n, word .. " before the " .. END_OF[block] .. " of line " .. block_line)
                    close()
                end
                block, block_line, named = word, n, 0
                if word == "BEGIN_SOUND_ATTACHMENT" then
                    seen.attachments = seen.attachments + 1
                else
                    seen.spaces = seen.spaces + 1
                end
            elseif BEGIN_OF[word] then
                if block == BEGIN_OF[word] then close() else bad(n, word .. " without its " .. BEGIN_OF[word]) end
            elseif BLOCK_OF[word] then
                if block ~= BLOCK_OF[word] then bad(n, word .. " not in a " .. BLOCK_OF[word] .. " block") end
                if KIND[word] then
                    named = named + 1
                    seen.names = seen.names + 1
                    local name = KIND[word] .. ":" .. rest
                    if rest == "" then
                        bad(n, word .. " without a name")
                    elseif not names[name] then
                        bad(n, name .. (commented[name] and " is only on a line of GUIDs.txt that starts with '#'"
                            or " is not in GUIDs.txt"))
                    end
                end
            elseif OUTSIDE[word] then
                if block then bad(n, word .. " inside the " .. block .. " of line " .. block_line) end
                if word == "REQUIRES_BANK" then
                    seen.banks = seen.banks + 1
                    if not has_bank(rest) then bad(n, "REQUIRES_BANK " .. rest .. ": no such file in fmod/") end
                end
            else
                bad(n, "not a directive of the .snd format: " .. word)
            end
        end
    end
    if block then
        bad(block_line, block .. " not ended before the end of the file")
        close()
    end
    return problems, seen
end

-- The checker on samples: a good one (the custom file's own lines), and
-- that one broken in the ways it must catch.
local SAMPLE = table.concat({
    "A",
    "1000",
    "ACF_SOUNDS",
    "",
    "REQUIRES_BANK ambience.bank",                                            -- 5
    "DISABLE_LEGACY_ALERT_SOUNDS",
    "###########################",
    "#SNAPSHOTS",
    "BEGIN_SOUND_ATTACHMENT",                                                 -- 9
    "\tSNAPSHOT_NAME /in_mute",
    "\tEVENT_START_COND sim/graphics/view/view_is_external == 1",
    "\tEVENT_END_COND sim/graphics/view/view_is_external == 0",
    "END_SOUND_ATTACHMENT",
    "",
    "BEGIN_SOUND_SPACE",                                                      -- 15
    "    SOUND_INDEX 0",
    "    BLEND_DEPTH 0.0",
    "    AABB -1.5 3.6 -27.5 1.5 6.2 -23.0",
    "END_SOUND_SPACE",
    "",
    "BEGIN_SOUND_ATTACHMENT",                                                 -- 21
    "        EVENT_NAME /Boeing/747/-400/Ambience/Weather/rain",
    "        VEH_XYZ 0 0 0",
    "\tEVENT_START_COND sim/weather/precipitation_on_aircraft_ratio > 0",
    "\tEVENT_END_COND sim/weather/precipitation_on_aircraft_ratio == 0",     -- 25
    "END_SOUND_ATTACHMENT",
    "",
    "BEGIN_SOUND_ATTACHMENT",                                                 -- 28
    "    EVENT_NAME /Boeing/747/-400/PM Callouts/10000",
    "    VEH_XYZ 0.5 5.2 -26",
    "#    EVENT_END_COND ABS_DELTA=sim/cockpit2/autopilot/heading_dial_deg_mag_copilot < 5",
    "    EVENT_START_COND DELTA=laminar/B747/toggle_switch/position[29]",
    "END_SOUND_ATTACHMENT",
}, "\n")
local SAMPLE_GUIDS = table.concat({
    "{b45856d7-41c3-499d-8db2-88fefad80e57} snapshot:/in_mute",
    "{dbd292f3-6786-48bc-902c-89893631370a} event:/Boeing/747/-400/Ambience/Weather/rain",
    "{c0f3180a-e187-4d2f-b63d-4fea36c289cd} event:/Boeing/747/-400/PM Callouts/10000",
    "#{efa352e6-60c1-474a-bb55-f96c0ff71646} event:/Boeing/747/-400/Warnings/GPWS/dontsink",
}, "\r\n")
local function sample_bank(file) return file == "ambience.bank" end
local function sample_problems(text) return (check_snd(text, SAMPLE_GUIDS, sample_bank)) end
-- text with the first old (plain text) replaced by new
local function edit(text, old, new)
    local i = assert(text:find(old, 1, true), old)
    return text:sub(1, i - 1) .. new .. text:sub(i + #old)
end

local good, seen = check_snd(SAMPLE, SAMPLE_GUIDS, sample_bank)
T.equal(#good, 0, "the good sample's problems (" .. table.concat(good, "; ") .. ")")
T.check(seen.attachments == 3 and seen.spaces == 1 and seen.names == 3 and seen.banks == 1,
    "the good sample read whole")
T.equal(#sample_problems((SAMPLE:gsub("\n", "\r\n"))), 0, "the good sample with Windows line ends: problems")
T.equal(#sample_problems(SAMPLE .. "\n"), 0, "the good sample with a line end at its end: problems")
for _, ending in ipairs({"", "\r\n", "\r"}) do
    T.equal(first_difference(SAMPLE, (SAMPLE:gsub("\n", "\r\n")) .. ending), nil, string.format(
        "the good sample and itself with Windows line ends (ending %q): the first line that differs", ending))
end
T.equal(first_difference(SAMPLE, edit(SAMPLE, "== 0\nEND", "== 1\nEND")), 12,
    "a line changed: the first line that differs")
T.equal(first_difference(SAMPLE, edit(SAMPLE, "\nEND_SOUND_ATTACHMENT\n\nBEGIN_SOUND_SPACE", "")), 13,
    "lines taken out: the first line that differs")
T.equal(first_difference(SAMPLE, SAMPLE .. "\n#"), 34, "a line added at the end: the first line that differs")

local BROKEN = {
    {"EVENT_START_END for EVENT_END_COND (the rain sound, 2026-11-12)",
        "\tEVENT_END_COND sim/weather", "\tEVENT_START_END sim/weather",
        "line 25: not a directive of the .snd format: EVENT_START_END"},
    {"an attachment's END left out before the next attachment",
        "aircraft_ratio == 0\nEND_SOUND_ATTACHMENT", "aircraft_ratio == 0",
        "line 27: BEGIN_SOUND_ATTACHMENT before the END_SOUND_ATTACHMENT of line 21"},
    {"the last attachment's END left out",
        "position[29]\nEND_SOUND_ATTACHMENT", "position[29]",
        "line 28: BEGIN_SOUND_ATTACHMENT not ended before the end of the file"},
    {"an END twice", "END_SOUND_SPACE", "END_SOUND_SPACE\nEND_SOUND_SPACE",
        "line 20: END_SOUND_SPACE without its BEGIN_SOUND_SPACE"},
    {"an attachment ended by END_SOUND_SPACE",
        "view_is_external == 0\nEND_SOUND_ATTACHMENT", "view_is_external == 0\nEND_SOUND_SPACE",
        "line 15: BEGIN_SOUND_SPACE before the END_SOUND_ATTACHMENT of line 9"},
    {"an attachment's directive outside the attachments",
        "DISABLE_LEGACY_ALERT_SOUNDS", "DISABLE_LEGACY_ALERT_SOUNDS\nEVENT_ALWAYS",
        "line 7: EVENT_ALWAYS not in a BEGIN_SOUND_ATTACHMENT block"},
    {"a sound space's directive in an attachment", "        VEH_XYZ 0 0 0", "        SOUND_INDEX 1",
        "line 23: SOUND_INDEX not in a BEGIN_SOUND_SPACE block"},
    {"REQUIRES_BANK in an attachment", "        VEH_XYZ 0 0 0", "        VEH_XYZ 0 0 0\nREQUIRES_BANK ambience.bank",
        "line 24: REQUIRES_BANK inside the BEGIN_SOUND_ATTACHMENT of line 21"},
    {"a bank not in fmod/", "REQUIRES_BANK ambience.bank", "REQUIRES_BANK ambiance.bank",
        "line 5: REQUIRES_BANK ambiance.bank: no such file in fmod/"},
    {"an event commented out in GUIDs.txt (GPWS dontsink, 2026-10-25)",
        "/Ambience/Weather/rain", "/Warnings/GPWS/dontsink",
        "line 22: event:/Boeing/747/-400/Warnings/GPWS/dontsink is only on a line of GUIDs.txt that starts with '#'"},
    {"an event not in GUIDs.txt", "/Ambience/Weather/rain", "/Ambience/Weather/snow",
        "line 22: event:/Boeing/747/-400/Ambience/Weather/snow is not in GUIDs.txt"},
    {"a snapshot named as an event", "\tSNAPSHOT_NAME /in_mute", "\tEVENT_NAME /in_mute",
        "line 10: event:/in_mute is not in GUIDs.txt"},
    {"EVENT_NAME without its name", "    EVENT_NAME /Boeing/747/-400/PM Callouts/10000", "    EVENT_NAME",
        "line 29: EVENT_NAME without a name"},
    {"an attachment without a name", "    EVENT_NAME /Boeing/747/-400/PM Callouts/10000\n", "",
        "line 28: the attachment has 0 EVENT_NAME or SNAPSHOT_NAME"},
    {"an attachment with two names", "        VEH_XYZ 0 0 0", "        VEH_XYZ 0 0 0\n\tSNAPSHOT_NAME /in_mute",
        "line 21: the attachment has 2 EVENT_NAME or SNAPSHOT_NAME"},
    {"the header's version", "A\n1000\n", "A\n1100\n", "line 2: the header's line 2 is \"1100\", not 1000"},
}
for _, case in ipairs(BROKEN) do
    local problems = sample_problems(edit(SAMPLE, case[2], case[3]))
    local found = false
    for _, p in ipairs(problems) do
        if p:find(case[4], 1, true) then found = true end
    end
    T.check(found, case[1] .. ": want \"" .. case[4] .. "\", got: " .. table.concat(problems, "; "))
end

-- the custom acf's file
local function has_bank(file)
    local f = io.open("fmod/" .. file, "rb")
    if f then f:close() end
    return f ~= nil
end
local text = src.read(SND)
local problems, counts = check_snd(text, src.read(GUIDS), has_bank)
T.check(counts.attachments > 1000 and counts.banks > 0, string.format("%s read: %d attachments, %d banks",
    SND, counts.attachments, counts.banks))
T.equal(#problems, 0, SND .. ": lines against the .snd format and GUIDs.txt, problems")
for _, p in ipairs(problems) do T.check(false, SND .. " " .. p) end

-- fmod/747-400.snd: on the development PC the local copy (skip-worktree,
-- "S" in git ls-files -v), the same as 747-400_custom.snd (CLAUDE.md)
local null = package.config:sub(1, 1) == "\\" and "nul" or "/dev/null"
local pipe = io.popen('git ls-files -v -- "' .. LOCAL_COPY .. '" 2>' .. null)
local flag = pipe and pipe:read("*l") or ""
if pipe then pipe:close() end
if flag:match("^[Ss] ") then
    local differ = first_difference(src.read(LOCAL_COPY), text)
    T.check(differ == nil, LOCAL_COPY .. " (the local copy, skip-worktree) differs from " .. SND
        .. " from line " .. tostring(differ) .. ": make the two the same (CLAUDE.md)")
end
T.done()
