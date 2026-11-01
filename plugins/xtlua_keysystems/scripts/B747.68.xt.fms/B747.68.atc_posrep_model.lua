-- 747-400 FMC POS REPORT without X-Plane (6-1/6-2 step 12g3b; docs/
-- overhaul/notes/ATA-34-61-FMC.md §119): the page's values and the
-- reports' text (FCOM p.766-768; FMSPG p.340-343):
--  - LAST and its ATA, ALT, TEMP, WIND, FUEL: the FMC's;
--  - TO, NEXT (a position), SPD (IAS or Mach), ETA, DEST ETA (XXXXZ): the
--    FMC's or the crew's entries, which go to ATC only (the company report
--    takes the FMC's); DELETE back to the FMC's; SPD's entry gone when the
--    page is left (FCOM p.767);
--  - the ATC report: POSITION REPORT with the fields (no fuel: FMSPG
--    p.342), then DEVIATING [offset] OF ROUTE with an offset and CLIMBING
--    TO or DESCENDING TO [altitude] with the MCP altitude more than 150 ft
--    away (FMSPG p.343); the company report with the fuel.
-- The fields' words and order in the text are estimates (the FANS
-- position report's data as text).
--
--   local P = B747_atc_posrep_model
--   local p = P.new() ; P.enter(p, "eta", "1555")
--   local v = P.values(p, defaults)          -- defaults: the FMC's (P.new's fields and the rest)
--   local shown = P.display(v)                -- the page's strings
--   local text = P.atc_text(v, {offset = -10, mcp_ft = 35000, alt_ft = 33000, mcp_text = "FL350"})

local M = setmetatable({}, {})
B747_atc_posrep_model = M
M.INVALID = "INVALID ENTRY"
M.LEVEL_FT = 150

function M.new() return {to = nil, nxt = nil, spd = nil, eta = nil, dest_eta = nil} end

-- an entry: nil or the message; to and nxt take a position the FMS
-- checked (B747_fmc_with_fix), spd an IAS or a Mach, eta and dest_eta a
-- time (the ATC request model's forms)
function M.enter(p, field, text)
    local Q = B747_atc_request_model
    if text == "DELETE" then
        if p[field] == nil then return "INVALID DELETE" end
        p[field] = nil
        return nil
    end
    if field == "to" or field == "nxt" then
        p[field] = text
    elseif field == "spd" then
        local t = Q.speed_text(text)
        if not t then return M.INVALID end
        p.spd = t
    elseif field == "eta" or field == "dest_eta" then
        local t = Q.time_text(text)
        if not t then return M.INVALID end
        p[field] = t
    else
        return M.INVALID
    end
    return nil
end
-- SPD's entry, gone when the page is left
function M.leave(p) p.spd = nil end

-- the values: the crew's entries over the FMC's (`d`: last, ata, alt, to,
-- eta, nxt, dest_eta, spd, temp_c, wind_dir, wind_kt, fuel_k)
function M.values(p, d)
    local v = {}
    for k, x in pairs(d) do v[k] = x end
    for _, k in ipairs({"to", "eta", "nxt", "dest_eta", "spd"}) do
        if p[k] then v[k] = p[k] end
    end
    return v
end
-- a speed as the page and the text show it: .80, 280KT
local function spd_text(s)
    if not s then return nil end
    if string.sub(s, 1, 1) == "." then return s end
    return s .. "KT"
end
-- the page's strings ("`" the CDU's degree sign)
function M.display(v)
    return {last = v.last or "", ata = v.ata or "", alt = v.alt or "", spd = spd_text(v.spd) or "",
        to = v.to or "", eta = v.eta or "", nxt = v.nxt or "", dest_eta = v.dest_eta or "",
        temp = v.temp_c and string.format("%d`C", v.temp_c) or "",
        wind = v.wind_dir and string.format("%03d`/%3dKT", v.wind_dir, v.wind_kt or 0) or "",
        fuel = v.fuel_k and string.format("%.1f", v.fuel_k) or ""}
end

local function fields(v)
    local parts = {"POSITION REPORT"}
    local function add(t) parts[#parts + 1] = t end
    if v.last then add("LAST " .. v.last .. (v.ata and (" AT " .. v.ata) or "")) end
    if v.alt then add("ALT " .. v.alt) end
    if v.spd then add("SPD " .. spd_text(v.spd)) end
    if v.to then add("TO " .. v.to .. (v.eta and (" AT " .. v.eta) or "")) end
    if v.nxt then add("NEXT " .. v.nxt) end
    if v.dest_eta then add("DEST ETA " .. v.dest_eta) end
    if v.temp_c then add(string.format("TEMP %dC", v.temp_c)) end
    if v.wind_dir then add(string.format("WIND %03d/%03dKT", v.wind_dir, v.wind_kt or 0)) end
    return parts
end
-- the ATC report: `x` offset (nm, left negative), alt_ft and mcp_ft (the
-- altitude now and the MCP's), mcp_text (the MCP's as the CDU shows it)
function M.atc_text(v, x)
    local parts = fields(v)
    x = x or {}
    if x.offset and x.offset ~= 0 then
        parts[#parts + 1] = string.format("DEVIATING %s%dNM OF ROUTE", x.offset < 0 and "L" or "R", math.abs(x.offset))
    end
    if x.mcp_ft and x.alt_ft and x.mcp_text then
        if x.mcp_ft > x.alt_ft + M.LEVEL_FT then parts[#parts + 1] = "CLIMBING TO " .. x.mcp_text
        elseif x.mcp_ft < x.alt_ft - M.LEVEL_FT then parts[#parts + 1] = "DESCENDING TO " .. x.mcp_text end
    end
    return table.concat(parts, " ")
end
-- the company report: the FMC's values and the fuel
function M.company_text(d)
    local parts = fields(d)
    if d.fuel_k then parts[#parts + 1] = string.format("FUEL %.1f", d.fuel_k) end
    return table.concat(parts, " ")
end

return M
