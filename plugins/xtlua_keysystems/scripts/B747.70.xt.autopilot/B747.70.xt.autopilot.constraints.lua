-- The altitude and speed constraints of the route's SID, STAR and approach,
-- read from X-Plane's CIFP (ARINC 424 in X-Plane's text form, one record a
-- line). The route reaches the autopilot through xtlua/fms with each entry's
-- position, ident and one altitude, but not the procedures nor the
-- constraints' kinds and speeds, so the procedures are found again here: the
-- SID from the departure runway and the route's idents after it, the STAR and
-- the approach (to the arrival runway) from the route's idents.
--
-- A constraint, keyed by route index:
--   alt_desc  "+" at or above, "-" at or below, "B" window, "@" at, or the
--             glide slope kinds "J"/"I" (the FACF) and "H"/"G" (the FAF);
--   floor, ceiling  the lowest and the highest altitude it allows (ft, nil
--             when unbounded; a FAF's floor is its glide slope altitude);
--   fl        the altitude was given as a flight level;
--   speed_desc "-" at or below, "+" at or above, "@" at; speed (kt);
--   phase     "climb" for a SID, "descent" for a STAR or an approach;
--   source    e.g. "SID ENDE3J", "APPCH I18R SUG1D".
local constraints = {}

constraints.CIFP_FOLDERS = {"Custom Data/CIFP/", "Resources/default data/CIFP/"}
-- lines read per frame, so a file (up to about 3,000 lines) is read over a few frames, as the ND reads
-- its fixes (XTLua warns of a time overflow for a long frame)
constraints.LINES_PER_STEP = 150

local SID_PARTS = {runway = "14FT", common = "25MU", enroute = "36SV"}
local STAR_PARTS = {enroute = "147F", common = "258M", runway = "369S"}

local function trim(text)
    text = string.gsub(text or "", "^%s+", "")
    text = string.gsub(text, "%s+$", "")
    return text
end

-- A CIFP altitude: "03000" 3000, "FL090" 9000, "-0013" -13, blank nil; and whether it was a flight level.
function constraints.parse_altitude(text)
    text = trim(text)
    if text == "" then return nil, false end
    if string.sub(text, 1, 2) == "FL" then
        local level = tonumber(string.sub(text, 3))
        if level == nil then return nil, false end
        return level * 100, true
    end
    return tonumber(text), false
end

-- The lowest and highest altitudes an altitude descriptor allows.
local function altitude_limits(desc, alt1, alt2)
    if alt1 == nil then return nil, nil end
    if desc == "+" or desc == "J" then return alt1, nil end
    if desc == "-" then return nil, alt1 end
    if desc == "B" then
        if alt2 == nil then return nil, alt1 end
        return math.min(alt1, alt2), math.max(alt1, alt2)
    end
    if desc == "C" then return alt2, nil end
    -- a FAF on a glide slope: its glide slope altitude (alt2), at or above for H
    if desc == "H" then return alt2 or alt1, nil end
    if desc == "G" then return alt2 or alt1, alt2 or alt1 end
    if desc == "@" or desc == "I" then return alt1, alt1 end
    return nil, nil
end

-- One SID, STAR or APPCH record, or nil for any other line.
function constraints.parse_record(line)
    local kind, rest = string.match(line or "", "^(%u+):(.*)$")
    if kind ~= "SID" and kind ~= "STAR" and kind ~= "APPCH" then return nil end
    local f = {}
    for field in string.gmatch(rest..",", "([^,]*),") do f[#f + 1] = field end
    if #f < 28 then return nil end
    local desc = f[9] or ""
    local record = {
        kind = kind, seq = tonumber(f[1]) or 0, route_type = trim(f[2]), proc = trim(f[3]),
        trans = trim(f[4]), fix = trim(f[5]), path = trim(f[12]),
        flyover = string.sub(desc, 2, 2) == "Y" or string.sub(desc, 2, 2) == "B",
        missed_start = string.sub(desc, 3, 3) == "M",
    }
    local altDesc = trim(f[23])
    local alt1, fl1 = constraints.parse_altitude(f[24])
    local alt2, fl2 = constraints.parse_altitude(f[25])
    if alt1 ~= nil then
        if altDesc == "" then altDesc = "@" end
        record.alt_desc, record.alt1, record.alt2, record.fl = altDesc, alt1, alt2, fl1 or fl2
        record.floor, record.ceiling = altitude_limits(altDesc, alt1, alt2)
    end
    local speed = tonumber(trim(f[28]))
    if speed ~= nil and speed > 0 then
        local speedDesc = trim(f[27])
        if speedDesc == "" then speedDesc = "@" end
        record.speed_desc, record.speed = speedDesc, speed
    end
    return record
end

-- The records grouped by procedure, then by route type and transition, in file order.
local function group(records, kind)
    local procs, order = {}, {}
    for _, record in ipairs(records or {}) do
        if record.kind == kind then
            local proc = procs[record.proc]
            if proc == nil then
                proc = {name = record.proc, groups = {}, index = {}}
                procs[record.proc] = proc
                order[#order + 1] = proc
            end
            local key = record.route_type.."|"..record.trans
            local g = proc.index[key]
            if g == nil then
                g = {route_type = record.route_type, trans = record.trans, legs = {}}
                proc.index[key] = g
                proc.groups[#proc.groups + 1] = g
            end
            g.legs[#g.legs + 1] = record
        end
    end
    return order
end

-- How well a transition's runway field fits the runway: 3 the runway, 2 both parallels ("RW28B"), 1 any
-- (ALL or blank), 0 another runway.
local function runway_score(trans, runway)
    if runway ~= nil and trans == runway then return 3 end
    if runway ~= nil and string.match(trans, "^RW%d%dB$") and string.sub(trans, 1, 4) == string.sub(runway, 1, 4) then
        return 2
    end
    if trans == "ALL" or trans == "" then return 1 end
    return 0
end

local function is_part(g, types)
    return string.find(types, g.route_type, 1, true) ~= nil and g.route_type ~= ""
end

-- The part of a procedure for the runway: of its groups of these route types, the one whose transition
-- fits the runway best (the later of equals), or nil.
local function runway_part(proc, types, runway)
    local best, bestScore = nil, 0
    for _, g in ipairs(proc.groups) do
        if is_part(g, types) then
            local score = runway_score(g.trans, runway)
            if score > 0 and score >= bestScore then best, bestScore = g, score end
        end
    end
    return best
end

-- Legs of the parts in order; where one part ends at the fix the next starts at, the later's leg stands
-- (an approach transition's last fix is the final's IF, a STAR's last fix an approach transition's IF),
-- unless it has no constraint there.
local function join(parts)
    local legs = {}
    for _, part in ipairs(parts) do
        for k, leg in ipairs(part.legs) do
            local last = legs[#legs]
            if k == 1 and last ~= nil and last.fix ~= "" and last.fix == leg.fix then
                if leg.alt_desc ~= nil or leg.speed_desc ~= nil then legs[#legs] = leg end
            else
                legs[#legs + 1] = leg
            end
        end
    end
    return legs
end

local function entry_name(entry)
    return string.upper(trim(tostring(entry and entry[8] or "")))
end
-- An altitude-terminated leg's end ("(650)"): its altitude
local function altitude_leg_end(entry)
    local alt = string.match(entry_name(entry), "^%((%d+)%)$")
    return tonumber(alt)
end
-- Entries the route has between a procedure's fixes that are not its fixes: altitude legs' ends,
-- "(VECT)", "(INTC)" and the like
local function skippable(entry)
    return string.sub(entry_name(entry), 1, 1) == "("
end

-- The legs matched against the route from index first: route index for each leg found, the number of
-- fixes found and of the candidate's fixes, and the route index after the last match. Legs at one fix in
-- a row (a hold after the fix, HF/HM after a TF) go to the route's next entry if it is that fix again
-- (X-Plane may list the hold), else to its one entry for it.
local function match_from(route, first, legs)
    local matched, found, fixes = {}, 0, 0
    local i = first
    local lastFix, lastIndex = nil, nil
    for k, leg in ipairs(legs) do
        if leg.fix ~= "" and leg.fix == lastFix then
            local j = i
            while route[j] ~= nil and entry_name(route[j]) ~= leg.fix and skippable(route[j]) do j = j + 1 end
            if route[j] ~= nil and entry_name(route[j]) == leg.fix then
                matched[k] = j
                i = j + 1
                lastIndex = j
            else
                matched[k] = lastIndex
            end
        elseif leg.fix ~= "" then
            fixes = fixes + 1
            local j = i
            while route[j] ~= nil and entry_name(route[j]) ~= leg.fix and skippable(route[j]) do j = j + 1 end
            if route[j] ~= nil and entry_name(route[j]) == leg.fix then
                matched[k] = j
                found = found + 1
                i = j + 1
                lastFix, lastIndex = leg.fix, j
            else
                break
            end
        elseif leg.alt1 ~= nil and route[i] ~= nil and altitude_leg_end(route[i]) == leg.alt1 then
            matched[k] = i
            i = i + 1
        end
    end
    return matched, found, fixes, i
end

-- The route index a candidate whose first fix is fix starts at, searched from first to last: the fix's,
-- or before it the altitude legs' ends and the like that lead to it (a SID's CA leg before its first fix).
local function find_fix(route, first, fix, last)
    for j = first, last or #route do
        if entry_name(route[j]) == fix then
            while j > first and skippable(route[j - 1]) do j = j - 1 end
            return j
        end
    end
    return nil
end

-- The best of the candidates (each {legs=, name=}) against the route: the most fixes found in order
-- (at least two, or all of a one-fix candidate), then the fewest of the candidate's fixes left over,
-- then the first. start(legs) gives the route index the candidate starts at, or nil.
local function best_candidate(route, candidates, start)
    local best
    for _, candidate in ipairs(candidates) do
        local first = start(candidate.legs)
        if first ~= nil then
            local matched, found, fixes, after = match_from(route, first, candidate.legs)
            if found >= math.min(2, fixes) and found > 0 then
                local left = fixes - found
                if best == nil or found > best.found or (found == best.found and left < best.left) then
                    best = {name = candidate.name, legs = candidate.legs, matched = matched, found = found,
                        left = left, after = after}
                end
            end
        end
    end
    return best
end

local function first_fix(legs)
    for _, leg in ipairs(legs) do
        if leg.fix ~= "" then return leg.fix end
    end
    return nil
end

-- The route's departure runway (the entry after the origin) and arrival runway (the last runway entry
-- before the destination, whatever missed approach entries follow it).
local function runways(route)
    local n = #route
    local departure, arrival, arrivalIndex
    if route[2] ~= nil and string.match(entry_name(route[2]), "^RW%d%d[LRCB]?$") then departure = entry_name(route[2]) end
    for j = n, 3, -1 do
        if string.match(entry_name(route[j]), "^RW%d%d[LRCB]?$") then
            arrival, arrivalIndex = entry_name(route[j]), j
            break
        end
    end
    return departure, arrival, arrivalIndex
end

local function sid_candidates(records, runway)
    local candidates = {}
    for _, proc in ipairs(group(records, "SID")) do
        local rw = runway_part(proc, SID_PARTS.runway, runway)
        local common = runway_part(proc, SID_PARTS.common, runway)
        if rw ~= nil or common ~= nil then
            local enroute = {false}
            for _, g in ipairs(proc.groups) do
                if is_part(g, SID_PARTS.enroute) then enroute[#enroute + 1] = g end
            end
            for _, e in ipairs(enroute) do
                local parts = {}
                if rw then parts[#parts + 1] = rw end
                if common then parts[#parts + 1] = common end
                if e then parts[#parts + 1] = e end
                candidates[#candidates + 1] = {legs = join(parts),
                    name = "SID "..proc.name..(e and (" "..e.trans) or "")}
            end
        end
    end
    return candidates
end

local function star_candidates(records, runway)
    local candidates = {}
    for _, proc in ipairs(group(records, "STAR")) do
        local common = runway_part(proc, STAR_PARTS.common, runway)
        local rw = runway_part(proc, STAR_PARTS.runway, runway)
        local enroute = {false}
        for _, g in ipairs(proc.groups) do
            if is_part(g, STAR_PARTS.enroute) then enroute[#enroute + 1] = g end
        end
        for _, e in ipairs(enroute) do
            local parts = {}
            if e then parts[#parts + 1] = e end
            if common then parts[#parts + 1] = common end
            if rw then parts[#parts + 1] = rw end
            if #parts > 0 then
                candidates[#candidates + 1] = {legs = join(parts),
                    name = "STAR "..proc.name..(e and (" "..e.trans) or "")}
            end
        end
    end
    return candidates
end

local function approach_candidates(records, runway)
    local candidates = {}
    for _, proc in ipairs(group(records, "APPCH")) do
        -- the final: every group but the transitions, up to the missed approach
        local final, missed, toRunway = {legs = {}}, false, false
        for _, g in ipairs(proc.groups) do
            if g.route_type ~= "A" then
                for _, leg in ipairs(g.legs) do
                    if leg.missed_start then missed = true end
                    if not missed then
                        final.legs[#final.legs + 1] = leg
                        if leg.fix == runway then toRunway = true end
                    end
                end
            end
        end
        if toRunway then
            local transitions = {false}
            for _, g in ipairs(proc.groups) do
                if g.route_type == "A" then transitions[#transitions + 1] = g end
            end
            for _, t in ipairs(transitions) do
                local parts = {}
                if t then parts[#parts + 1] = t end
                parts[#parts + 1] = final
                candidates[#candidates + 1] = {legs = join(parts),
                    name = "APPCH "..proc.name..(t and (" "..t.trans) or "")}
            end
        end
    end
    return candidates
end

local function constraint_of(leg, phase, source)
    if leg.alt_desc == nil and leg.speed_desc == nil then return nil end
    return {alt_desc = leg.alt_desc, floor = leg.floor, ceiling = leg.ceiling, fl = leg.fl,
        speed_desc = leg.speed_desc, speed = leg.speed, phase = phase, source = source}
end

local function assign(result, best, phase)
    for k = 1, #best.legs do
        local j = best.matched[k]
        if j ~= nil then
            local c = constraint_of(best.legs[k], phase, best.name)
            -- a later procedure's (or leg's) constraint at the same fix stands (the native FMS keeps the
            -- approach transition's window at SUGOL over the STAR's); without one the earlier's stays
            if c ~= nil then result[j] = c end
        end
    end
end

-- The constraints of the route's procedures. route: xtlua/fms entries ([2] type, 1 an airport; [8]
-- ident); records: the CIFP records by airport ident. Returns {constraints = {[route index] = ...},
-- summary = "SID ENDE3J/6 STAR LAMS2A/3 APPCH I18R SUG1D/8"} (each with the fixes found).
function constraints.match_route(route, records)
    local result, summary = {}, {}
    local n = #route
    if n < 3 then return {constraints = result, summary = ""} end
    local origin = route[1][2] == 1 and entry_name(route[1]) or nil
    local destination = route[n][2] == 1 and entry_name(route[n]) or nil
    local departure, arrival, arrivalIndex = runways(route)
    local sidEnd = 2
    if origin ~= nil and records[origin] ~= nil and departure ~= nil then
        local best = best_candidate(route, sid_candidates(records[origin], departure),
            function(legs)
                local fix = first_fix(legs)
                return fix and find_fix(route, 3, fix, math.min(n, 6)) or nil
            end)
        if best ~= nil then
            assign(result, best, "climb")
            sidEnd = best.after
            summary[#summary + 1] = best.name.."/"..best.found
        end
    end
    if destination ~= nil and records[destination] ~= nil then
        local star = best_candidate(route, star_candidates(records[destination], arrival),
            function(legs)
                local fix = first_fix(legs)
                return fix and find_fix(route, sidEnd, fix, arrivalIndex) or nil
            end)
        if star ~= nil then
            assign(result, star, "descent")
            summary[#summary + 1] = star.name.."/"..star.found
        end
        if arrival ~= nil then
            local approach = best_candidate(route, approach_candidates(records[destination], arrival),
                function(legs)
                    local fix = first_fix(legs)
                    return fix and find_fix(route, sidEnd, fix, arrivalIndex) or nil
                end)
            if approach ~= nil then
                assign(result, approach, "descent")
                summary[#summary + 1] = approach.name.."/"..approach.found
            end
        end
    end
    return {constraints = result, summary = table.concat(summary, " ")}
end

-- Reading the airports' CIFP files over several frames.
function constraints.new_loader(open_fn)
    return {open = open_fn or io.open, records = {}, queue = {}, file = nil, current = nil, done = true}
end

-- Start reading the airports not read yet (a list of idents); records of others are dropped, and an
-- airport whose file was being read is read again.
function constraints.loader_start(loader, airports)
    if loader.file ~= nil then
        loader.file:close()
        if loader.current ~= nil then loader.records[loader.current] = nil end
    end
    local keep, queue, seen = {}, {}, {}
    for _, icao in ipairs(airports) do
        if icao ~= nil and icao ~= "" and not seen[icao] then
            seen[icao] = true
            keep[icao] = loader.records[icao]
            if keep[icao] == nil then queue[#queue + 1] = icao end
        end
    end
    loader.records, loader.queue, loader.file, loader.current = keep, queue, nil, nil
    loader.done = #queue == 0
    loader.sources = loader.sources or {}
end

-- Read up to max_lines lines; true once every airport has been read (an airport without a CIFP file has
-- no records).
function constraints.loader_step(loader, max_lines)
    if loader.done then return true end
    local lines = 0
    while lines < (max_lines or constraints.LINES_PER_STEP) do
        if loader.file == nil then
            local icao = table.remove(loader.queue, 1)
            if icao == nil then
                loader.done = true
                return true
            end
            loader.current = icao
            loader.records[icao] = {}
            for _, folder in ipairs(constraints.CIFP_FOLDERS) do
                local file = loader.open(folder..icao..".dat", "r")
                if file ~= nil then
                    loader.file = file
                    loader.sources[icao] = folder
                    break
                end
            end
        end
        if loader.file ~= nil then
            local line = loader.file:read("*l")
            if line == nil then
                loader.file:close()
                loader.file = nil
            else
                local record = constraints.parse_record(line)
                if record ~= nil then
                    local list = loader.records[loader.current]
                    list[#list + 1] = record
                end
            end
            lines = lines + 1
        end
    end
    return false
end

return constraints
