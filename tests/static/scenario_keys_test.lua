-- Run from the repository root with LuaJIT: luajit tests/static/scenario_keys_test.lua
-- (2026-11-13; the 2026-11-12 review C-5) Every flight-test scenario
-- (tests/flight/scenarios/) and measurement (tests/flight/measure/) against
-- the kit's list of keys, tests/flight/scenario_keys.json: a key the kit
-- does not read, a key a step needs and lacks, an op or a level the kit
-- does not know, a number or a true/false given as something else.
-- run_scenario.ps1 does not start such a scenario (exit status 4); this
-- test finds it without X-Plane. Before, the kit passed over a key it did
-- not know: s256's and s257's CLR steps with "seconds": 1.5 (for
-- "duration") pressed the key once, not for 1.5 s. The checker also runs on
-- small broken samples, so the test fails if it stops seeing them.
local T = dofile("tests/lib/check.lua")("scenario_keys")
local json = dofile("plugins/xtlua/scripts/B747.05.xt.simconfig/json/json.lua")

local function read(path)
    local f = io.open(path, "rb")
    if not f then return nil end
    local text = f:read("*a")
    f:close()
    return text
end

local defText = read("tests/flight/scenario_keys.json")
T.check(defText ~= nil, "tests/flight/scenario_keys.json not found")
local DEF = json.decode(defText or "{}")

local function set_of(list)
    local s = {}
    for _, v in ipairs(list or {}) do s[v] = true end
    return s
end
local OPS, LEVELS = set_of(DEF.ops), set_of(DEF.levels)
local NUMBERS, BOOLEANS, COMMON = set_of(DEF.numbers), set_of(DEF.booleans), set_of(DEF.common)

-- the problems of one scenario (a decoded table): a list of texts
local function problems_of(spec)
    local bad = {}
    local function say(fmt, ...) bad[#bad + 1] = string.format(fmt, ...) end
    if type(spec) ~= "table" then say("not a JSON object") return bad end
    local top = set_of(DEF.top.need)
    for _, k in ipairs(DEF.top.may) do top[k] = true end
    for k in pairs(spec) do
        if not top[k] then say("the scenario: unknown key '%s'", tostring(k)) end
    end
    for _, k in ipairs(DEF.top.need) do
        if spec[k] == nil then say("the scenario: no '%s'", k) end
    end
    if spec.reload ~= nil and type(spec.reload) ~= "boolean" then say("the scenario: 'reload' not true or false") end
    if type(spec.steps) ~= "table" then return bad end
    local function cond(n, kind, c, keys, where)
        for k in pairs(c) do
            if not keys[k] then say("step %d (%s): unknown key '%s'%s", n, kind, tostring(k), where) end
        end
    end
    for n, step in ipairs(spec.steps) do
        local kind = step["do"]
        local d = kind and DEF.steps[kind]
        if not kind then
            say("step %d: no 'do'", n)
        elseif not d then
            say("step %d: unknown step type '%s'", n, tostring(kind))
        else
            local keys = set_of(DEF.common)
            for _, k in ipairs(d.need) do keys[k] = true end
            for _, k in ipairs(d.may) do keys[k] = true end
            cond(n, kind, step, keys, "")
            for _, k in ipairs(d.need) do
                if step[k] == nil then say("step %d (%s): no '%s'", n, kind, k) end
            end
            if d.need_one_of then
                local any = false
                for _, group in ipairs(d.need_one_of) do
                    local all = true
                    for _, k in ipairs(group) do if step[k] == nil then all = false end end
                    if all then any = true end
                end
                if not any then
                    local g = {}
                    for _, group in ipairs(d.need_one_of) do g[#g + 1] = table.concat(group, " and ") end
                    say("step %d (%s): needs %s", n, kind, table.concat(g, ", or "))
                end
            end
            for k, v in pairs(step) do
                if NUMBERS[k] and type(v) ~= "number" then say("step %d (%s): '%s' not a number", n, kind, k) end
                if BOOLEANS[k] and type(v) ~= "boolean" then say("step %d (%s): '%s' not true or false", n, kind, k) end
            end
            if step.op ~= nil and not OPS[step.op] then say("step %d (%s): unknown op '%s'", n, kind, tostring(step.op)) end
            if step.level ~= nil and not LEVELS[step.level] then say("step %d (%s): unknown level '%s'", n, kind, tostring(step.level)) end
            if (step.op == "between" or step.op == "outside") and not (type(step.value) == "table" and #step.value == 2) then
                say("step %d (%s): '%s' needs two values", n, kind, step.op)
            end
            if type(step["until"]) == "table" then
                local u = step["until"]
                local ukeys = set_of(DEF["until"].need)
                for _, k in ipairs(DEF["until"].may) do ukeys[k] = true end
                cond(n, kind, u, ukeys, " in 'until'")
                for _, k in ipairs(DEF["until"].need) do
                    if u[k] == nil then say("step %d (%s): no '%s' in 'until'", n, kind, k) end
                end
                if u.op ~= nil and not OPS[u.op] then say("step %d (%s): unknown op '%s' in 'until'", n, kind, tostring(u.op)) end
            elseif step["until"] ~= nil then
                say("step %d (%s): 'until' not an object", n, kind)
            end
        end
    end
    return bad
end

-- the samples: each must give the problem named
local samples = {
    {[[{"name": "x", "steps": [{"do": "cmd", "name": "a/b", "seconds": 1.5}]}]], "step 1 (cmd): unknown key 'seconds'"},
    {[[{"name": "x", "steps": [{"do": "watch", "dref": "a/b", "mx": 1}]}]], "step 1 (watch): unknown key 'mx'"},
    {[[{"name": "x", "steps": [{"do": "wiat", "dref": "a/b"}]}]], "step 1: unknown step type 'wiat'"},
    {[[{"name": "x", "steps": [{"do": "check", "dref": "a/b", "op": "=", "value": 1}]}]], "step 1 (check): unknown op '='"},
    {[[{"name": "x", "steps": [{"do": "check", "dref": "a/b", "value": 1}]}]], "step 1 (check): no 'op'"},
    {[[{"name": "x", "steps": [{"do": "wait", "dref": "a/b", "op": "==", "value": 1, "level": "warning"}]}]], "step 1 (wait): unknown level 'warning'"},
    {[[{"name": "x", "steps": [{"do": "sleep", "seconds": "5"}]}]], "step 1 (sleep): 'seconds' not a number"},
    {[[{"name": "x", "steps": [{"do": "watch", "dref": "a/b", "spread": "0.4"}]}]], "step 1 (watch): 'spread' not a number"},
    {[[{"name": "x", "steps": [{"do": "check", "dref": "a/b", "op": "==", "value": 1, "stop": "yes"}]}]], "step 1 (check): 'stop' not true or false"},
    {[[{"name": "x", "steps": [{"do": "watch", "dref": "a/b", "until": {"dref": "c/d", "op": "==", "valeu": 1}}]}]], "step 1 (watch): unknown key 'valeu' in 'until'"},
    {[[{"name": "x", "steps": [{"do": "view", "the": 10}]}]], "step 1 (view): needs name, or the and psi"},
    {[[{"name": "x", "steps": [{"do": "check", "dref": "a/b", "op": "between", "value": 1}]}]], "step 1 (check): 'between' needs two values"},
    {[[{"name": "x", "flight": {}, "step": []}]], "the scenario: unknown key 'step'"},
}
for _, s in ipairs(samples) do
    local got = problems_of(json.decode(s[1]))
    local seen = false
    for _, p in ipairs(got) do if p == s[2] then seen = true end end
    T.check(seen, "the sample " .. s[1] .. ": want \"" .. s[2] .. "\", got: " .. table.concat(got, "; "))
end
T.equal(#problems_of(json.decode([[{"name": "x", "description": "d", "reload": true, "flight": {},
    "steps": [{"do": "cmd", "note": "n", "name": "a/b", "duration": 0.2}, {"do": "view", "name": "panel"},
    {"do": "watch", "dref": "a/b", "max": 2, "until": {"dref": "c/d", "op": "==", "value": 1, "rel": "x"}},
    {"do": "watch", "dref": "a/b", "spread": 0.4, "timeout": 20}]}]])), 0,
    "a good sample: no problem")

-- every scenario and measurement
local function json_files(dir)
    local windows = package.config:sub(1, 1) == "\\"
    local command = windows and ('dir /b "' .. dir:gsub("/", "\\") .. '\\*.json" 2>nul') or ('ls ' .. dir .. '/*.json 2>/dev/null')
    local pipe = assert(io.popen(command))
    local files = {}
    for line in pipe:lines() do
        local name = line:gsub("\\", "/"):match("([^/]+%.json)$")
        if name then files[#files + 1] = dir .. "/" .. name end
    end
    pipe:close()
    table.sort(files)
    return files
end
local count = 0
for _, dir in ipairs({"tests/flight/scenarios", "tests/flight/measure"}) do
    for _, path in ipairs(json_files(dir)) do
        local text = read(path)
        local ok, spec = pcall(json.decode, text)
        if T.check(ok, path .. ": not JSON: " .. tostring(spec)) then
            count = count + 1
            for _, p in ipairs(problems_of(spec)) do T.check(false, path .. ": " .. p) end
            local base = path:match("([^/]+)%.json$")
            T.check(spec.name == base, path .. ": its name is '" .. tostring(spec.name) .. "', not its file's")
        end
    end
end
T.check(count > 300, "scenarios and measurements found (" .. count .. ")")
T.done()
