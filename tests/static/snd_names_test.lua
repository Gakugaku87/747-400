-- Run from the repository root with LuaJIT: luajit tests/static/snd_names_test.lua
-- (2026-11-13; the 2026-11-12 review C-4) The names the custom acf's sound
-- definition (fmod/747-400_custom.snd) triggers on, against what exists,
-- and the conditions' form, by X-Plane's "Sound (.snd) File Format
-- Specification" (a condition is a dataref, an operator and a value; an
-- array's element in square brackets; DELTA= and ABS_DELTA= a change):
--   - each condition's dataref in X-Plane's Resources/plugins/DataRefs.txt,
--     made by an init script (run as XLua runs them: tests/lib/xtlua.lua) or
--     registered by the aircraft's native plugin (b747_fms_bridge);
--   - an array's element named and within the array, a scalar not indexed,
--     no string dataref; the operator one of < <= == != >= >, the value a
--     number; a dataref alone only with DELTA= or ABS_DELTA=;
--   - each command trigger's command in X-Plane's Commands.txt or made by
--     the aircraft (an init script, the native plugin);
--   - an end or cue condition only with a start condition; at most one
--     command trigger, not with conditions; EVENT_ALWAYS alone.
-- A condition no name answers never holds and X-Plane says nothing (the
-- review found 17 such lines, from the stock sound pack; the rebuilt
-- alerts' lines were right). Those are listed below as known: a new one
-- fails, and so does a known one that is gone (take it off the list). The
-- checker also runs on small broken samples, so the test fails if it stops
-- seeing them. Without X-Plane's DataRefs.txt (set XPLANE_ROOT) the test
-- fails, as tests/static/sim_datarefs_test.lua does; without its
-- Commands.txt (a cloud session's stand-in has DataRefs.txt alone:
-- docs/overhaul/TESTING.md 3) the commands are not checked.
local T = dofile("tests/lib/check.lua")("snd_names")
local xtlua = dofile("tests/lib/xtlua.lua")
local src = dofile("tests/lib/source.lua")

local SND = "fmod/747-400_custom.snd"

-- the known lines (the directive as written, or "no start: <event>"), from
-- the stock sound pack; the sounds are outside this work (CLAUDE.md)
local KNOWN = {
    -- X-Plane 12 has no sim/engines/TOGA_power (XP11's)
    ["EVENT_CMND_DOWN sim/engines/TOGA_power"] = true,
    ["EVENT_CMND_UP sim/engines/TOGA_power"] = true,
    -- a command's name as a dataref, no operator
    ["EVENT_START_COND laminar/B747/button_switch/press_altitude"] = true,
    -- float[12] without an element
    ["EVENT_START_COND ABS_DELTA=sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot > 10"] = true,
    ["EVENT_END_COND ABS_DELTA=sim/cockpit2/radios/actuators/nav_obs_deg_mag_pilot < 5"] = true,
    -- commands' names as datarefs (each button has another attachment that works)
    ["EVENT_START_COND DELTA=laminar/B747/efis/meters/capt/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/fpv/capt/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/dh/capt/reset_switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/baro_std/capt/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/nd/center/capt/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/nd/traffic/capt/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/meters/fo/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/fpv/fo/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/dh/fo/reset_switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/efis/baro_std/fo/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/nd/center/fo/switch"] = true,
    ["EVENT_START_COND DELTA=laminar/B747/nd/traffic/fo/switch"] = true,
    -- float[10] without an element
    ["EVENT_START_COND sim/flightmodel2/gear/tire_rotation_angle_deg > 0"] = true,
    -- an end condition alone
    ["no start: /Boeing/747/-400/Ambience/Flaps/flaps_stop"] = true,
}

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local t = f:read("*a")
    f:close()
    return t
end

-- the names: datarefs (name -> {type, int}), commands (name -> true)
local types, init_cmds = xtlua.created()
T.check(xtlua.datarefs_txt_found, "X-Plane's Resources/plugins/DataRefs.txt not found (set XPLANE_ROOT)")
local commands = {}
local ctext = read(xtlua.xplane_root .. "/Resources/plugins/Commands.txt")
local have_cmds = ctext ~= nil
if not have_cmds then print("snd_names: no Resources/plugins/Commands.txt: the commands not checked") end
for line in (ctext or ""):gmatch("[^\r\n]+") do
    local name = line:match("^(%S+)")
    if name then commands[name] = true end
end
for name in pairs(init_cmds) do commands[name] = true end
local native = {}
local windows = package.config:sub(1, 1) == "\\"
local pipe = assert(io.popen(windows and 'dir /b "plugins\\b747_fms_bridge\\src\\*.c" 2>nul' or 'ls plugins/b747_fms_bridge/src/*.c 2>/dev/null'))
local cfiles = 0
for line in pipe:lines() do
    local file = "plugins/b747_fms_bridge/src/" .. line:gsub("\\", "/"):match("([^/]+%.c)$")
    local text = read(file) or ""
    cfiles = cfiles + 1
    for name in text:gmatch('XPLMRegisterDataAccessor%s*%(%s*"([^"]+)"') do native[name] = true end
    for name in text:gmatch('XPLMCreateCommand%s*%(%s*"([^"]+)"') do commands[name] = true end
end
pipe:close()
T.check(cfiles > 0, "the native plugin's sources found")

local OPS = {["<"] = true, ["<="] = true, ["=="] = true, ["!="] = true, [">="] = true, [">"] = true}

-- the problems of a .snd's text: {key = the directive or "no start: ..", what = ..}
local function check_snd(text)
    local problems = {}
    local function bad(key, what) problems[#problems + 1] = {key = key, what = what} end
    local atts, cur = {}, nil
    for line in (text .. "\n"):gmatch("([^\n]*)\n") do
        line = line:gsub("\r$", "")
        local word, rest = line:match("^%s*(%S+)%s*(.-)%s*$")
        if word and word:sub(1, 1) ~= "#" then
            if word == "BEGIN_SOUND_ATTACHMENT" then
                cur = {conds = {}, cmds = {}, flags = {}}
                atts[#atts + 1] = cur
            elseif word == "END_SOUND_ATTACHMENT" then
                cur = nil
            elseif cur then
                local key = word .. " " .. rest
                if word == "EVENT_NAME" or word == "SNAPSHOT_NAME" then
                    cur.name, cur.kind = rest, word
                elseif word == "EVENT_START_COND" or word == "EVENT_END_COND" or word == "CUE_TRIGGER_COND" then
                    cur.conds[#cur.conds + 1] = {word = word, text = rest, key = key}
                elseif word:find("^EVENT_CMND_") then
                    cur.cmds[#cur.cmds + 1] = {word = word, name = rest, key = key}
                elseif word == "PARAM_DREF_IDX" then
                    cur.idx = tonumber(rest)
                elseif word == "EVENT_ALWAYS" then
                    cur.flags.always = true
                end
            end
        end
    end
    for _, a in ipairs(atts) do
        local starts, others = 0, 0
        for _, c in ipairs(a.conds) do
            if c.word == "EVENT_START_COND" then starts = starts + 1 else others = others + 1 end
            local body = c.text
            local prefix = body:match("^([%u_]+)=")
            if prefix then
                body = body:sub(#prefix + 2)
                if prefix ~= "DELTA" and prefix ~= "ABS_DELTA" then bad(c.key, "unknown " .. prefix .. "=") end
            end
            local parts = {}
            for p in body:gmatch("%S+") do parts[#parts + 1] = p end
            local dref, op, value = parts[1], parts[2], parts[3]
            if not dref then
                bad(c.key, "no condition")
            else
                if #parts == 1 and not prefix then bad(c.key, "a dataref alone without DELTA= (no operator)") end
                if #parts == 2 or #parts > 3 then bad(c.key, "not dataref, operator, value") end
                if op and not OPS[op] then bad(c.key, "the operator " .. op) end
                if value and not tonumber(value) then bad(c.key, "the value " .. value .. " not a number") end
                local base, idx = dref:match("^(.-)%[(.-)%]$")
                base = base or dref
                local t = types[base]
                local size = t and tonumber((t.type or ""):match("^array%[(%d+)%]$"))
                if not t and not native[base] then
                    bad(c.key, "no such dataref (DataRefs.txt, the init scripts, the native plugin): " .. base)
                elseif t then
                    if idx then
                        local i = tonumber(idx)
                        if idx == "*" or idx == "#" then
                            if not a.idx then bad(c.key, "a wildcard element without PARAM_DREF_IDX")
                            elseif size and a.idx >= size then bad(c.key, "PARAM_DREF_IDX beyond " .. t.type) end
                        elseif not i then bad(c.key, "the element " .. idx .. " not a number")
                        elseif not size then bad(c.key, "an element of a " .. t.type .. " dataref")
                        elseif i < 0 or i >= size then bad(c.key, "the element " .. idx .. " beyond " .. t.type) end
                    elseif size then
                        bad(c.key, "a " .. t.type .. " dataref without an element")
                    end
                    if t.type == "string" then bad(c.key, "a string dataref") end
                end
            end
        end
        for _, c in ipairs(a.cmds) do
            if c.name == "" then bad(c.key, "no command")
            elseif have_cmds and not commands[c.name] then bad(c.key, "no such command (Commands.txt, the init scripts, the native plugin)") end
        end
        local label = tostring(a.name)
        if #a.cmds > 1 then bad("more commands: " .. label, "more than one command trigger") end
        if #a.cmds > 0 and #a.conds > 0 then bad("command and conditions: " .. label, "a command trigger with dataref conditions") end
        if a.flags.always and (#a.cmds > 0 or #a.conds > 0) then bad("always: " .. label, "EVENT_ALWAYS with other triggers") end
        if starts == 0 and others > 0 then bad("no start: " .. label, "an end or cue condition without a start condition") end
    end
    return problems, #atts
end

-- the samples: each must give the problem named
local samples = {
    {"EVENT_START_COND laminar/B747/no/such/dataref > 0", "no such dataref"},
    {"EVENT_START_COND sim/flightmodel2/gear/tire_rotation_angle_deg > 0", "without an element"},
    {"EVENT_START_COND sim/flightmodel2/gear/tire_rotation_angle_deg[12] > 0", "beyond"},
    {"EVENT_START_COND sim/flightmodel/position/theta[1] > 0", "an element of a number dataref"},
    {"EVENT_START_COND sim/flightmodel/position/theta => 0", "the operator =>"},
    {"EVENT_START_COND sim/flightmodel/position/theta > x", "not a number"},
    {"EVENT_START_COND sim/flightmodel/position/theta", "a dataref alone without DELTA="},
    {"EVENT_CMND_DOWN sim/no/such/command", "no such command"},
    {"EVENT_END_COND sim/flightmodel/position/theta > 1", "without a start condition"},
}
for _, s in ipairs(samples) do
  if have_cmds or not s[1]:find("^EVENT_CMND_") then
    local text = "BEGIN_SOUND_ATTACHMENT\nEVENT_NAME /x/sample\n" .. s[1] .. "\nEND_SOUND_ATTACHMENT\n"
    local got = check_snd(text)
    local seen = false
    for _, p in ipairs(got) do if p.what:find(s[2], 1, true) then seen = true end end
    local w = {}
    for _, p in ipairs(got) do w[#w + 1] = p.what end
    T.check(seen, "the sample \"" .. s[1] .. "\": want \"" .. s[2] .. "\", got: " .. table.concat(w, "; "))
  end
end
T.equal(#check_snd("BEGIN_SOUND_ATTACHMENT\nEVENT_NAME /x/good\nEVENT_START_COND sim/flightmodel2/gear/tire_rotation_angle_deg[2] > 0\n"
    .. "EVENT_END_COND DELTA=sim/flightmodel/position/theta\nEND_SOUND_ATTACHMENT\n"
    .. "BEGIN_SOUND_ATTACHMENT\nEVENT_NAME /x/cmd\nEVENT_CMND_DOWN sim/flight_controls/flaps_down\nEND_SOUND_ATTACHMENT\n"), 0,
    "a good sample: no problem")

-- the custom acf's .snd
local text = read(SND)
T.check(text ~= nil, SND .. " not found")
local problems, count = check_snd(text or "")
T.check(count > 500, SND .. ": attachments found (" .. count .. ")")
local seen = {}
for _, p in ipairs(problems) do
    if KNOWN[p.key] then seen[p.key] = true
    else T.check(false, SND .. ": " .. p.key .. ": " .. p.what) end
end
for key in pairs(KNOWN) do
    if have_cmds or not key:find("^EVENT_CMND_") then T.check(seen[key], SND .. ": the known line \"" .. key .. "\" is no longer there or right now: take it off KNOWN") end
end
T.done()
