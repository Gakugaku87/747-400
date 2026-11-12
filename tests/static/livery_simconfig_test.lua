-- Run from the repository root with LuaJIT: luajit tests/static/livery_simconfig_test.lua
-- (2026-11-13; the 2026-11-12 review C-1, C-2, case 11) Each livery's
-- B747-400_simconfig.dat (liveries/*/), as the simconfig module reads it
-- (the whole file, a BOM dropped): it decodes, names its engines, its
-- thrust_ref fits the engines (GE in N1, P&W and RR in EPR: the EICAS's
-- primary engine indication), and its enumerated values are among those the
-- code knows. On 2026-11-12 the KLM PH-BFV livery had GE engines in EPR.
local T = dofile("tests/lib/check.lua")("livery_simconfig")
local json = dofile("plugins/xtlua/scripts/B747.05.xt.simconfig/json/json.lua")

local ENUM = {
    ["SIM.weight_display_units"] = {KGS = true, LBS = true},
    ["SIM.baro_indicator"] = {IN = true, HPA = true},
    ["SIM.baro_sync"] = {YES = true, NO = true},
    ["SIM.auto_fuel_mgmt"] = {YES = true, NO = true},
    ["SIM.capt_inbd"] = {EICAS = true, NORM = true, PFD = true},
    ["SIM.capt_lwr"] = {["EICAS PRI"] = true, NORM = true, ND = true},
    ["SIM.fo_inbd"] = {EICAS = true, NORM = true, PFD = true},
    ["SIM.fo_lwr"] = {["EICAS PRI"] = true, NORM = true, ND = true},
    ["PLANE.thrust_ref"] = {EPR = true, N1 = true},
    ["PLANE.pfd_style"] = {CRT = true, LCD = true},
    ["PLANE.nd_style"] = {CRT = true, LCD = true},
    ["PLANE.aircraft_type"] = {PASSENGER = true, FREIGHTER = true},
}
local function flat(t, prefix, into)
    for k, v in pairs(t) do
        local key = prefix == "" and k or (prefix .. "." .. k)
        if type(v) == "table" then flat(v, key, into) else into[key] = v end
    end
    return into
end

local windows = package.config:sub(1, 1) == "\\"
local pipe = assert(io.popen(windows and 'dir /b /ad "liveries" 2>nul' or 'ls liveries 2>/dev/null'))
local count = 0
for dir in pipe:lines() do
    local path = "liveries/" .. dir .. "/B747-400_simconfig.dat"
    local f = io.open(path, "rb")
    if f then
        count = count + 1
        local text = f:read("*a"):gsub("^\239\187\191", "")
        f:close()
        local ok, data = pcall(json.decode, text)
        if T.check(ok and type(data) == "table", path .. ": does not decode: " .. tostring(data)) then
            local plane = data.PLANE or {}
            local engines = string.upper(tostring(plane.engines or ""))
            T.check(engines ~= "", path .. ": no PLANE.engines")
            local ge = engines:find("CF6", 1, true) ~= nil
            local want = ge and "N1" or "EPR"
            T.check(plane.thrust_ref == want, path .. ": engines " .. tostring(plane.engines) .. " but thrust_ref "
                .. tostring(plane.thrust_ref) .. " (want " .. want .. ")")
            for key, value in pairs(flat(data, "", {})) do
                if ENUM[key] then T.check(ENUM[key][value] ~= nil, path .. ": " .. key .. " = " .. tostring(value) .. " not known") end
            end
        end
    end
end
pipe:close()
T.check(count >= 10, "liveries with a simconfig found (" .. count .. ")")
T.done()
