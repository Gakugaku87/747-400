-- Run from the repository root with Lua 5.1 or LuaJIT.
-- XTLua gives 0 for the first read of a dataref in a script module: the
-- value only arrives on a later frame (X-Plane 2026-10-10: the autoland's
-- first read of vh_ind_fpm, at FLARE engagement, was 0). The modules keep
-- the datarefs they need at once fresh by reading them every frame
-- ("local refresh...=<dataref>" in the per-frame function). This suite checks
-- that the datarefs the fixes first read at a critical moment are among
-- those reads.
local checks = 0
local function check(condition, message)
    checks = checks + 1
    assert(condition, message)
end

-- The text of a top-level function: from "function <name>(" to the first
-- line that is just "end".
local function function_body(path, name)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("\nfunction "..name.."(", 1, true), path..": no function "..name)
    local last = assert(source:find("\nend", first + 1, true), path..": no end of "..name)
    return source:sub(first, last)
end

-- Whether the body reads the dataref variable on its own: "= <name>" not
-- followed by more of an identifier.
local function reads(body, name)
    local start = 1
    while true do
        local a, b = body:find("=%s*"..name, start)
        if not a then return false end
        local after = body:sub(b + 1, b + 1)
        if not after:match("[%w_]") then return true end
        start = b + 1
    end
end

local FMS = "plugins/xtlua_keysystems/scripts/B747.68.xt.fms/"
local cases = {
    -- [d] the CRZ ALT entry for the native FMS (B744.fms.step.lua
    -- native_cruise_altitude_entry) is formatted with the native transition
    -- altitude, read only at a CRZ ALT entry or change; a 0 fell back to
    -- 18000 ft for the first one of the session. The sync fault flag is read
    -- 0.5 s after its write, for the CDU message.
    {file=FMS.."B747.68.xt.fms.lua", func="after_physics",
        names={"simDR_fms_transition_alt", "B747DR_crzalt_sync_fault"}},
}

for _, case in ipairs(cases) do
    local body = function_body(case.file, case.func)
    for _, name in ipairs(case.names) do
        check(reads(body, name), case.func.." in "..case.file.." does not read "..name.." every frame")
    end
end

-- The helpers themselves.
check(reads("  local refresh=simDR_x\n", "simDR_x"), "a refresh read is found")
check(not reads("  local refresh=simDR_x_y\n", "simDR_x"), "a longer name is not taken for the dataref")
check(not reads("  simDR_x=1\n", "simDR_x"), "a write is not a read")

print("XTLua warm read tests passed: "..checks)
