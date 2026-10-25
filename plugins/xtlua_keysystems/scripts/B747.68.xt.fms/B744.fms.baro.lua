-- The CDU's EFIS CONTROL page BARO SET entry (5-2 step 4b; FCOM p.1062-1064
-- (10.10.100-102)): S or STD for STD, I or H for the units, 22.00 to 32.00
-- or 2200 to 3200 for inches of mercury, 745 to 1084 for hectopascals.
-- dofile'd from B747.68.xt.fms.lua before B744.fms.pages.lua (the page's
-- "BARO" entry uses it).
--
--   local kind, inhg, hpa = B744_cdu_baro_entry(text)
--
-- kind: "std"; "units" (hpa true for H); "set" (inhg, and hpa true when it
-- displays in hectopascals); nil for INVALID ENTRY.

local HPA_PER_INHG = 33.863892

function B744_cdu_baro_entry(text)
    if text == "S" or text == "STD" then return "std" end
    if text == "I" then return "units", nil, false end
    if text == "H" then return "units", nil, true end
    if type(text) ~= "string" or not text:match("^%d+%.?%d*$") then return nil end
    local v = tonumber(text)
    if text:find(".", 1, true) then
        if v >= 22 and v <= 32 then return "set", v, false end
        return nil
    end
    if v >= 2200 and v <= 3200 then return "set", v / 100, false end
    if v >= 745 and v <= 1084 then return "set", v / HPA_PER_INHG, true end
    if v >= 22 and v <= 32 then return "set", v, false end
    return nil
end
