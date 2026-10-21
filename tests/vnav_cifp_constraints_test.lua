-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The SID, STAR and approach constraints of the route, read from X-Plane's
-- CIFP (B747.70.xt.autopilot.constraints.lua): records parsed as X-Plane
-- writes them, the procedures found again from the route's idents (the 747
-- gets each entry's position, ident and one altitude through xtlua/fms, not
-- the procedures nor the constraints' kinds and speeds), the files read over
-- several frames. The procedures below are made up (ZZDP, ZZAR) in the CIFP's
-- form; with XPLANE_ROOT set to an X-Plane 12 folder the real EIDW, EHAM and
-- EINN data are checked as well.
local AP = "plugins/xtlua_keysystems/scripts/B747.70.xt.autopilot/"
local C = dofile(AP.."B747.70.xt.autopilot.constraints.lua")

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function case(name, body)
    local ok, err = pcall(body)
    if not ok then
        checks = checks + 1
        failures[#failures + 1] = name..": "..tostring(err)
    end
end

-- One CIFP record: 38 fields after "KIND:", as X-Plane writes them (vangle: the final approach angle, "-300").
local function rec(kind, seq, route_type, proc, trans, fix, desc, path, alt_desc, alt1, alt2, speed_desc, speed,
        vangle)
    local f = {}
    for i = 1, 38 do f[i] = " " end
    f[1], f[2], f[3], f[4], f[5] = seq, route_type, proc, trans, fix ~= "" and fix or " "
    if fix ~= "" then f[6], f[7], f[8] = "ZZ", "P", "C" end
    f[9], f[12] = desc or "E   ", path or "TF"
    f[23], f[24], f[25] = alt_desc or " ", alt1 or "     ", alt2 or "     "
    f[27], f[28], f[29] = speed_desc or " ", speed or "   ", vangle or "    "
    return kind..":"..table.concat(f, ",")..";"
end

local ZZDP = table.concat({
    "PRDAT:010,5,ALPHA1,RW09,ZD09E,ZZ,P,C,EY  ;",
    -- ALPHA1 and BRAVO1 share everything but their last fix; the runway sits in the common route's
    -- transition column, as X-Plane writes it
    rec("SID", "010", "5", "ALPHA1", "RW09", "ZD09E", "EY  ", "IF"),
    rec("SID", "020", "5", "ALPHA1", "RW09", "", "    ", "CA", "+", "00650", nil, "-", "210"),
    rec("SID", "030", "5", "ALPHA1", "RW09", "ZD001", nil, "CF", nil, nil, nil, "-", "210"),
    rec("SID", "040", "5", "ALPHA1", "RW09", "ZD002", nil, "TF", "-", "FL090"),
    rec("SID", "050", "5", "ALPHA1", "RW09", "ALPHA", "EE  ", "TF", "-", "FL230", nil, "-", "290"),
    rec("SID", "010", "5", "BRAVO1", "RW09", "ZD09E", "EY  ", "IF"),
    rec("SID", "020", "5", "BRAVO1", "RW09", "", "    ", "CA", "+", "00650", nil, "-", "210"),
    rec("SID", "030", "5", "BRAVO1", "RW09", "ZD001", nil, "CF", nil, nil, nil, "-", "220"),
    rec("SID", "040", "5", "BRAVO1", "RW09", "ZD002", nil, "TF", "-", "FL080"),
    rec("SID", "050", "5", "BRAVO1", "RW09", "BRAVO", "EE  ", "TF", "-", "FL230"),
    -- the same fixes off the other runway, with other constraints
    rec("SID", "010", "5", "ALPHA2", "RW27", "ZD27E", "EY  ", "IF"),
    rec("SID", "020", "5", "ALPHA2", "RW27", "ZD001", nil, "TF", "-", "05000", nil, "-", "180"),
    rec("SID", "030", "5", "ALPHA2", "RW27", "ZD002", nil, "TF", "-", "FL060"),
    rec("SID", "040", "5", "ALPHA2", "RW27", "ALPHA", nil, "TF", "-", "FL100"),
    -- a common route for both runways and an enroute transition
    rec("SID", "010", "4", "CHAR1", "RW09", "ZD09E", "EY  ", "IF"),
    rec("SID", "020", "4", "CHAR1", "RW09", "ZD003", nil, "DF", "+", "03000"),
    rec("SID", "010", "5", "CHAR1", "ALL", "ZD003", nil, "IF", "+", "03000"),
    rec("SID", "020", "5", "CHAR1", "ALL", "ZD004", nil, "TF", "-", "FL150", nil, "-", "250"),
    rec("SID", "010", "6", "CHAR1", "CHARL", "ZD004", nil, "IF", "-", "FL150", nil, "-", "250"),
    rec("SID", "020", "6", "CHAR1", "CHARL", "CHARL", nil, "TF", "B", "FL200", "FL170"),
    "RWY:RW09,+0100,      ,0123, ,     , ,   ;N50000000,E000000000,0000;",
}, "\n")

local ZZAR = table.concat({
    rec("STAR", "010", "5", "STAR1A", "ALL", "STRIF", "E C ", "IF", "-", "FL230"),
    rec("STAR", "020", "5", "STAR1A", "ALL", "STR02", nil, "TF"),
    rec("STAR", "030", "5", "STAR1A", "ALL", "JOINX", "EECH", "TF", "B", "FL100", "FL070", "-", "250"),
    -- the approach transition starting at the STAR's last fix, with its own window there
    rec("APPCH", "010", "A", "I18R", "JOIN1", "JOINX", "E CA", "IF", "B", "FL140", "FL100"),
    rec("APPCH", "020", "A", "I18R", "JOIN1", "APP01", nil, "TF", "+", "FL070", nil, "-", "250"),
    rec("APPCH", "030", "A", "I18R", "JOIN1", "APP02", nil, "TF", "+", "FL055", nil, "-", "220"),
    rec("APPCH", "040", "A", "I18R", "JOIN1", "APP03", nil, "TF"),
    rec("APPCH", "050", "A", "I18R", "JOIN1", "ZA621", "EE  ", "CF", "+", "02000"),
    -- a holding transition from the same fix
    rec("APPCH", "010", "A", "I18R", "JOINH", "JOINX", "E CA", "IF", "B", "FL100", "FL070", "-", "250"),
    rec("APPCH", "020", "A", "I18R", "JOINH", "ZHOLD", "V  H", "TF", "+", "FL070", nil, "-", "220"),
    -- the ILS final: the IF, the FAF on the glide slope, the runway, then the missed approach
    rec("APPCH", "010", "I", "I18R", " ", "ZA621", "E  I", "IF", "J", "02000", "02000"),
    rec("APPCH", "020", "I", "I18R", " ", "ZA622", "E  F", "CF", "H", "02000", "01310", "+", "160", "-300"),
    rec("APPCH", "030", "I", "I18R", " ", "RW18R", "G  M", "CF", nil, "00037", nil, nil, nil, "-300"),
    rec("APPCH", "040", "I", "I18R", " ", "RW18R", "G M ", "FA", "+", "00500"),
    rec("APPCH", "050", "I", "I18R", " ", "ZA624", "E   ", "DF", nil, "02000", nil, "-", "220"),
    -- an RNAV approach to the same runway without the FAF ZA622, from the same transition
    rec("APPCH", "010", "A", "R18R", "JOIN1", "JOINX", "E CA", "IF", "B", "FL140", "FL100"),
    rec("APPCH", "020", "A", "R18R", "JOIN1", "APP01", nil, "TF", "+", "FL060", nil, "-", "240"),
    rec("APPCH", "030", "A", "R18R", "JOIN1", "APP02", nil, "TF", "+", "FL050", nil, "-", "210"),
    rec("APPCH", "040", "A", "R18R", "JOIN1", "APP03", nil, "TF"),
    rec("APPCH", "050", "A", "R18R", "JOIN1", "ZA621", "EE  ", "TF", "+", "02000"),
    rec("APPCH", "010", "R", "R18R", " ", "ZA621", "E  I", "IF", "+", "02000"),
    rec("APPCH", "020", "R", "R18R", " ", "RW18R", "G  M", "TF", nil, "00037"),
    rec("APPCH", "030", "R", "R18R", " ", "RW18R", "G M ", "CA", "+", "00500"),
    -- an approach to another runway
    rec("APPCH", "010", "I", "I27", " ", "APP02", "E  I", "IF", "+", "03000"),
    rec("APPCH", "020", "I", "I27", " ", "RW27", "G  M", "CF", nil, "00030"),
}, "\n")

-- A file system with the made-up airports (in Custom Data unless given otherwise) for the loader.
local function fake_open(files)
    return function(path)
        local text = files[path]
        if text == nil then return nil end
        local lines, i = {}, 0
        for line in string.gmatch(text.."\n", "([^\n]*)\n") do lines[#lines + 1] = line end
        return {read = function() i = i + 1 return lines[i] end, close = function() end}
    end
end
local FILES = {["Custom Data/CIFP/ZZDP.dat"] = ZZDP, ["Custom Data/CIFP/ZZAR.dat"] = ZZAR}

local function load(airports, files, lines_per_step)
    local loader = C.new_loader(fake_open(files or FILES))
    C.loader_start(loader, airports)
    local steps = 0
    while not C.loader_step(loader, lines_per_step or 1000) do steps = steps + 1 end
    return loader.records, steps, loader
end

local function entry(name, kind, alt)
    return {0, kind or 512, 0, 0, 0, 0, 0, name, alt or 0, false}
end
local function route_of(names)
    local route = {}
    for i, name in ipairs(names) do
        route[i] = entry(name, (i == 1 or i == #names) and 1 or (string.sub(name, 1, 1) == "(" and 2048 or 512))
    end
    return route
end
local FLIGHT = {"ZZDP", "RW09", "ZD09E", "(650)", "ZD001", "ZD002", "ALPHA", "ENR01", "ENR02", "STRIF", "STR02",
    "JOINX", "APP01", "APP02", "APP03", "ZA621", "ZA622", "RW18R", "(500)", "ZA624", "(VECT)", "ZZAR"}
local function index_of(names, name)
    for i, n in ipairs(names) do if n == name then return i end end
end

-- 1. Records as X-Plane writes them.
case("records", function()
    local r = C.parse_record(rec("SID", "020", "5", "ALPHA1", "RW09", "", "    ", "CA", "+", "00650", nil, "-", "210"))
    check(r ~= nil and r.kind == "SID" and r.proc == "ALPHA1" and r.trans == "RW09" and r.fix == "" and r.path == "CA",
        "a CA leg's record")
    check(r.alt_desc == "+" and r.floor == 650 and r.ceiling == nil and r.speed_desc == "-" and r.speed == 210,
        "the CA leg: at or above 650, at or below 210 kt")
    r = C.parse_record(rec("STAR", "030", "5", "STAR1A", "ALL", "JOINX", "EECH", "TF", "B", "FL100", "FL070", "-", "250"))
    check(r.floor == 7000 and r.ceiling == 10000 and r.fl == true and r.speed == 250, "a window FL070-FL100")
    r = C.parse_record(rec("APPCH", "030", "I", "I18R", " ", "RW18R", "G  M", "CF", nil, "00037", nil, nil, nil, "-300"))
    check(r.alt_desc == "@" and r.floor == 37 and r.ceiling == 37 and r.missed_start == false, "the runway at 37 ft")
    check(r.vangle == 3, "the final approach angle 3.00 deg: "..tostring(r.vangle))
    r = C.parse_record(rec("APPCH", "030", "I", "I18R", " ", "RW18R", "G  M", "CF", nil, "00037", nil, nil, nil, "-250"))
    check(r.vangle == 2.5, "2.50 deg: "..tostring(r.vangle))
    r = C.parse_record(rec("APPCH", "040", "I", "I18R", " ", "RW18R", "G M ", "FA", "+", "00500"))
    check(r.missed_start == true, "the missed approach's first leg")
    r = C.parse_record(rec("APPCH", "020", "I", "I18R", " ", "ZA622", "E  F", "CF", "H", "02000", "01310", "+", "160"))
    check(r.floor == 1310 and r.ceiling == nil and r.speed_desc == "+" and r.speed == 160,
        "the FAF: its glide slope altitude 1310, at or above 160 kt")
    r = C.parse_record(rec("APPCH", "010", "I", "I18R", " ", "ZA621", "E  I", "IF", "J", "02000", "02000"))
    check(r.floor == 2000 and r.ceiling == nil and r.vangle == nil, "the FACF: at or above 2000, no angle")
    check(C.parse_record("RWY:RW09,+0100,      ,0123, ,     , ,   ;N50000000,E000000000,0000;") == nil, "no RWY record")
    check(C.parse_record("PRDAT:010,5,ALPHA1,RW09,ZD09E;") == nil, "no PRDAT record")
    check(select(1, C.parse_altitude("-0013")) == -13 and select(1, C.parse_altitude("FL090")) == 9000,
        "altitudes below sea level and flight levels")
end)

-- 2. The flight ZZDP RW09 ALPHA1 ... STAR1A, ILS 18R via JOIN1.
case("the flight", function()
    local records, steps = load({"ZZDP", "ZZAR"})
    local result = C.match_route(route_of(FLIGHT), records)
    local c = result.constraints
    check(result.summary == "SID ALPHA1/4 STAR STAR1A/3 APPCH I18R JOIN1/7", "summary: "..result.summary)
    local function at(name) return c[index_of(FLIGHT, name)] end
    local ca = at("(650)")
    check(ca ~= nil and ca.floor == 650 and ca.speed == 210 and ca.phase == "climb", "(650): the CA leg's constraints")
    check(at("ZD001") ~= nil and at("ZD001").speed == 210 and at("ZD001").speed_desc == "-", "ZD001 at or below 210 kt")
    check(at("ZD002") ~= nil and at("ZD002").ceiling == 9000 and at("ZD002").floor == nil, "ZD002 at or below FL090")
    check(at("ALPHA") ~= nil and at("ALPHA").ceiling == 23000 and at("ALPHA").speed == 290
        and at("ALPHA").source == "SID ALPHA1", "ALPHA at or below FL230 and 290 kt (ALPHA1)")
    check(at("ZD09E") == nil and at("ENR01") == nil, "no constraint at ZD09E nor the enroute fixes")
    check(at("STRIF") ~= nil and at("STRIF").ceiling == 23000 and at("STRIF").phase == "descent", "STRIF at or below FL230")
    local joinx = at("JOINX")
    check(joinx ~= nil and joinx.floor == 10000 and joinx.ceiling == 14000 and joinx.speed == nil
        and joinx.source == "APPCH I18R JOIN1", "JOINX: the approach transition's window over the STAR's")
    check(at("APP01").floor == 7000 and at("APP01").speed == 250, "APP01 at or above FL070, 250 kt")
    check(at("APP02").floor == 5500 and at("APP02").speed == 220, "APP02 at or above FL055, 220 kt (I18R, not R18R)")
    check(at("APP03") == nil, "no constraint at APP03")
    check(at("ZA621").alt_desc == "J" and at("ZA621").floor == 2000, "ZA621: the final's IF")
    check(at("ZA622").floor == 1310 and at("ZA622").speed_desc == "+" and at("ZA622").vangle == 3, "ZA622: the FAF")
    check(at("RW18R").floor == 37 and at("RW18R").ceiling == 37 and at("RW18R").vangle == 3, "RW18R at 37 ft, 3 deg")
    check(at("(500)") == nil and at("ZA624") == nil, "nothing from the missed approach")
end)

-- 3. Choosing among procedures.
case("the other SID", function()
    local names = {"ZZDP", "RW09", "ZD09E", "(650)", "ZD001", "ZD002", "BRAVO", "ENR01", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}))
    check(result.summary == "SID BRAVO1/4", "BRAVO1 from its last fix: "..result.summary)
    check(result.constraints[5].speed == 220 and result.constraints[6].ceiling == 8000, "BRAVO1's own constraints")
end)
case("the other runway", function()
    local names = {"ZZDP", "RW27", "ZD27E", "ZD001", "ZD002", "ALPHA", "ENR01", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}))
    check(result.summary == "SID ALPHA2/4", "RW27: ALPHA2 "..result.summary)
    check(result.constraints[4].ceiling == 5000 and result.constraints[4].speed == 180, "ZD001 at or below 5000, 180 kt")
end)
case("an enroute transition", function()
    local names = {"ZZDP", "RW09", "ZD09E", "ZD003", "ZD004", "CHARL", "ENR01", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}))
    check(result.summary == "SID CHAR1 CHARL/4", "CHAR1 CHARL: "..result.summary)
    check(result.constraints[4].floor == 3000 and result.constraints[5].ceiling == 15000
        and result.constraints[6].floor == 17000 and result.constraints[6].ceiling == 20000, "CHAR1's constraints")
end)
case("the final only, no STAR", function()
    local names = {"ZZDP", "RW09", "ENR01", "ZA621", "ZA622", "RW18R", "(500)", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}))
    check(result.summary == "APPCH I18R/3", "the ILS final: "..result.summary)
    check(result.constraints[4].floor == 2000 and result.constraints[5].floor == 1310, "ZA621 and ZA622")
end)
case("the RNAV approach", function()
    local names = {"ZZDP", "RW09", "ENR01", "JOINX", "APP01", "APP02", "APP03", "ZA621", "RW18R", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}))
    check(result.summary == "APPCH R18R JOIN1/6", "without ZA622: R18R "..result.summary)
    check(result.constraints[6].floor == 5000 and result.constraints[6].speed == 210, "APP02 as R18R has it")
end)
case("the route back to the departure airport", function()
    local names = {"ZZAR", "RW18R", "ENR01", "ENR02", "ZA621", "ZA622", "RW18R", "(500)", "ZA624", "ZZAR"}
    local loader = C.new_loader(fake_open(FILES))
    local opened = 0
    local open = loader.open
    loader.open = function(...) opened = opened + 1 return open(...) end
    C.loader_start(loader, {"ZZAR", "ZZAR"})
    while not C.loader_step(loader, 1000) do end
    local result = C.match_route(route_of(names), loader.records)
    check(opened == 1, "one file read for both ends, opened "..opened)
    check(result.summary == "APPCH I18R/3", "the approach at the end: "..result.summary)
end)
case("no CIFP file", function()
    local result = C.match_route(route_of(FLIGHT), load({"ZZDP", "ZZAR"}, {}))
    check(result.summary == "" and next(result.constraints) == nil, "no constraints without files")
end)
case("Custom Data first", function()
    local files = {["Custom Data/CIFP/ZZAR.dat"] = ZZAR,
        ["Resources/default data/CIFP/ZZAR.dat"] = string.gsub(ZZAR, "FL055", "FL045"),
        ["Resources/default data/CIFP/ZZDP.dat"] = ZZDP}
    local records, _, loader = load({"ZZDP", "ZZAR"}, files)
    local result = C.match_route(route_of(FLIGHT), records)
    check(result.constraints[index_of(FLIGHT, "APP02")].floor == 5500, "ZZAR from Custom Data")
    check(loader.sources.ZZAR == "Custom Data/CIFP/" and loader.sources.ZZDP == "Resources/default data/CIFP/",
        "ZZDP from the default data")
end)

-- 4. Over several frames: a few lines a frame give the same result; a new route keeps the airports read.
case("several frames", function()
    local records, steps = load({"ZZDP", "ZZAR"}, nil, 5)
    local lines = 0
    for _ in string.gmatch(ZZDP.."\n"..ZZAR.."\n", "\n") do lines = lines + 1 end
    check(steps >= math.floor(lines / 5) - 1, "5 lines a frame: "..steps.." frames for "..lines.." lines")
    local result = C.match_route(route_of(FLIGHT), records)
    check(result.summary == "SID ALPHA1/4 STAR STAR1A/3 APPCH I18R JOIN1/7", "the same procedures: "..result.summary)
    local loader = C.new_loader(fake_open(FILES))
    C.loader_start(loader, {"ZZDP", "ZZAR"})
    while not C.loader_step(loader, 1000) do end
    local opened = 0
    local open = loader.open
    loader.open = function(...) opened = opened + 1 return open(...) end
    C.loader_start(loader, {"ZZDP", "ZZAR"})
    check(C.loader_step(loader, 1000) == true and opened == 0, "the same airports again: nothing read")
    C.loader_start(loader, {"ZZAR", "ZZDP"})
    check(loader.records.ZZDP ~= nil and loader.records.ZZAR ~= nil, "the records kept")
end)

-- 4b. A new route while a file is read: the airport read in part is read again, not kept in part.
case("a new route while reading", function()
    local loader = C.new_loader(fake_open(FILES))
    C.loader_start(loader, {"ZZDP", "ZZAR"})
    C.loader_step(loader, 3)                                     -- ZZDP in part, ALPHA1 cut short
    C.loader_start(loader, {"ZZDP", "ZZAR"})
    while not C.loader_step(loader, 1000) do end
    local result = C.match_route(route_of(FLIGHT), loader.records)
    check(result.summary == "SID ALPHA1/4 STAR STAR1A/3 APPCH I18R JOIN1/7", "ZZDP read again: "..result.summary)
    local closed = 0
    loader = C.new_loader(function(path, mode)
        local file = fake_open(FILES)(path, mode)
        if file then
            local close = file.close
            file.close = function(...) closed = closed + 1 return close(...) end
        end
        return file
    end)
    C.loader_start(loader, {"ZZDP"})
    C.loader_step(loader, 3)
    C.loader_start(loader, {})
    check(closed == 1 and loader.file == nil, "no airport any more: the file is closed, closed "..closed)
end)

-- 4c. Legs at one fix in a row (a hold after the fix, HF/HM), a SID's altitude leg before its first fix,
-- and a join where the later procedure has no constraint at the fix.
case("legs at one fix, a leading altitude leg, an empty join", function()
    local extra = table.concat({
        rec("SID", "010", "5", "DELTA1", "RW09", "", "    ", "CA", "+", "00500", nil, "-", "200"),
        rec("SID", "020", "5", "DELTA1", "RW09", "ZD005", nil, "DF", "-", "04000"),
        rec("SID", "030", "5", "DELTA1", "RW09", "DELTA", nil, "TF", "-", "FL120"),
        rec("APPCH", "010", "A", "I18R", "HOLDX", "STR02", "E CA", "IF", "+", "FL080", nil, "-", "230"),
        rec("APPCH", "020", "A", "I18R", "HOLDX", "ZHLD1", "V   ", "TF", "+", "FL070", nil, "-", "220"),
        rec("APPCH", "030", "A", "I18R", "HOLDX", "ZHLD1", "V  H", "HF", "+", "FL060", nil, "-", "230"),
        rec("APPCH", "040", "A", "I18R", "HOLDX", "ZA621", "EE  ", "TF", "+", "02000"),
        rec("STAR", "010", "5", "STAR2B", "ALL", "STRJN", "E C ", "IF", "-", "FL230"),
        rec("STAR", "020", "5", "STAR2B", "ALL", "JOINY", "EECH", "TF", "-", "FL120", nil, "-", "250"),
        rec("APPCH", "010", "A", "I18R", "JOIN2", "JOINY", "E CA", "IF"),
        rec("APPCH", "020", "A", "I18R", "JOIN2", "APP01", nil, "TF", "+", "FL070", nil, "-", "250"),
        rec("APPCH", "030", "A", "I18R", "JOIN2", "APP02", nil, "TF", "+", "FL055", nil, "-", "220"),
        rec("APPCH", "040", "A", "I18R", "JOIN2", "APP03", nil, "TF"),
        rec("APPCH", "050", "A", "I18R", "JOIN2", "ZA621", "EE  ", "CF", "+", "02000"),
        -- an approach whose final starts at its transition's last fix without a constraint there
        rec("APPCH", "010", "A", "I27Y", "TRY", "ZB001", "E CA", "IF", "+", "04000"),
        rec("APPCH", "020", "A", "I27Y", "TRY", "APP02", "EE  ", "TF", "+", "03500", nil, "-", "210"),
        rec("APPCH", "010", "I", "I27Y", " ", "APP02", "E  I", "IF"),
        rec("APPCH", "020", "I", "I27Y", " ", "RW27", "G  M", "CF", nil, "00030"),
    }, "\n")
    local files = {["Custom Data/CIFP/ZZDP.dat"] = ZZDP.."\n"..extra, ["Custom Data/CIFP/ZZAR.dat"] = ZZAR.."\n"..extra}
    -- the hold transition: the route lists ZHLD1 once
    local names = {"ZZDP", "RW09", "ENR01", "STR02", "ZHLD1", "ZA621", "ZA622", "RW18R", "ZZAR"}
    local result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}, files))
    check(string.find(result.summary, "APPCH I18R HOLDX/5", 1, true) ~= nil, "the hold transition: "..result.summary)
    check(result.constraints[5] ~= nil and result.constraints[5].floor == 6000 and result.constraints[5].speed == 230,
        "ZHLD1: the hold's (the later leg's) at or above FL060, 230 kt")
    -- X-Plane may list the hold's fix twice: both entries, the transition still found
    names = {"ZZDP", "RW09", "ENR01", "STR02", "ZHLD1", "ZHLD1", "ZA621", "ZA622", "RW18R", "ZZAR"}
    result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}, files))
    check(string.find(result.summary, "APPCH I18R HOLDX/5", 1, true) ~= nil, "the hold listed twice: "..result.summary)
    check(result.constraints[5] ~= nil and result.constraints[5].floor == 7000 and result.constraints[6] ~= nil
        and result.constraints[6].floor == 6000, "ZHLD1 twice: the TF's then the HF's")
    -- the final's IF without a constraint at the transition's last fix: the transition's stays
    names = {"ZZDP", "RW09", "ENR01", "ZB001", "APP02", "RW27", "ZZAR"}
    result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}, files))
    check(result.summary == "APPCH I27Y TRY/3", "I27Y TRY: "..result.summary)
    check(result.constraints[5] ~= nil and result.constraints[5].floor == 3500 and result.constraints[5].speed == 210,
        "APP02: TRY's +3500 -210 where the final's IF has none")
    -- the SID's altitude leg before its first fix
    names = {"ZZDP", "RW09", "(500)", "ZD005", "DELTA", "ENR01", "ZZAR"}
    result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}, files))
    check(result.summary == "SID DELTA1/2", "DELTA1: "..result.summary)
    check(result.constraints[3] ~= nil and result.constraints[3].floor == 500 and result.constraints[3].speed == 200,
        "(500): the leading CA leg's +500 -200")
    -- STAR2B ends at JOINY with -FL120 -250; JOIN2 starts there without a constraint: STAR2B's stands
    names = {"ZZDP", "RW09", "ENR01", "STRJN", "JOINY", "APP01", "APP02", "APP03", "ZA621", "ZA622", "RW18R", "ZZAR"}
    result = C.match_route(route_of(names), load({"ZZDP", "ZZAR"}, files))
    check(result.constraints[5] ~= nil and result.constraints[5].ceiling == 12000 and result.constraints[5].speed == 250,
        "JOINY: STAR2B's -FL120 -250 where JOIN2 has none")
end)

-- 5. The autopilot reads them when the route's idents change, over frames, and keeps them by route index
-- (B747_update_route_constraints, B747.70.xt.autopilot.lua).
case("the autopilot's frames", function()
    local file = assert(io.open(AP.."B747.70.xt.autopilot.lua"))
    local source = file:read("*a")
    file:close()
    local first = assert(source:find("B747_route_constraints=setmetatable({},{})", 1, true)
        or source:find("B747_route_constraints={}", 1, true))
    local last = assert(source:find("function B747_getCurrentWayPoint_default(fmsO)", first, true))
    local opened = {}
    local fake = setmetatable({LINES_PER_STEP = 10, new_loader = function()
        return C.new_loader(function(path, mode)
            opened[#opened + 1] = path
            return fake_open(FILES)(path, mode)
        end)
    end}, {__index = C})
    local env = setmetatable({print = function() end, B747_constraints = fake, B747DR_vnav_procedures = ""},
        {__index = _G})
    setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
    local route = route_of(FLIGHT)
    env.B747_update_route_constraints(route)
    check(env.B747DR_vnav_procedures == "reading" and next(env.B747_route_constraints) == nil,
        "the first frame: reading, got "..tostring(env.B747DR_vnav_procedures))
    local frames = 1
    while env.B747DR_vnav_procedures == "reading" and frames < 100 do
        env.B747_update_route_constraints(route)
        frames = frames + 1
    end
    check(frames > 2 and env.B747DR_vnav_procedures == "SID ALPHA1/4 STAR STAR1A/3 APPCH I18R JOIN1/7",
        "read over "..frames.." frames: "..tostring(env.B747DR_vnav_procedures))
    check(env.B747_route_constraints[index_of(FLIGHT, "APP02")].floor == 5500, "APP02's floor by route index")
    check(#opened == 2, "two files opened, "..#opened)
    env.B747_update_route_constraints(route)
    check(#opened == 2 and env.B747_route_constraints[index_of(FLIGHT, "APP02")] ~= nil, "the same route: kept")
    -- the approach changed to the final only: matched again without reading the files again
    local names = {"ZZDP", "RW09", "ZD09E", "(650)", "ZD001", "ZD002", "ALPHA", "ENR01", "ZA621", "ZA622", "RW18R",
        "ZZAR"}
    route = route_of(names)
    env.B747_update_route_constraints(route)
    check(env.B747DR_vnav_procedures == "SID ALPHA1/4 APPCH I18R/3", "a new approach: "..env.B747DR_vnav_procedures)
    check(#opened == 2 and env.B747_route_constraints[10].floor == 1310, "ZA622 by its new index, no file read")
    -- no route
    env.B747_update_route_constraints({})
    check(env.B747DR_vnav_procedures == "" and next(env.B747_route_constraints) == nil, "no route: none")
    -- a new route, then none while its file is read: the file is closed
    local closed = 0
    local new_loader = fake.new_loader
    fake.new_loader = function()
        local loader = new_loader()
        local open = loader.open
        loader.open = function(...)
            local f = open(...)
            if f then
                local close = f.close
                f.close = function(...) closed = closed + 1 return close(...) end
            end
            return f
        end
        return loader
    end
    env = setmetatable({print = function() end, B747_constraints = fake, B747DR_vnav_procedures = ""}, {__index = _G})
    setfenv(assert(loadstring(source:sub(first, last - 1))), env)()
    env.B747_update_route_constraints(route_of(FLIGHT))
    env.B747_update_route_constraints({})
    check(closed == 1, "the route gone while reading: the file closed, closed "..closed)
end)

-- 6. The real data, when an X-Plane 12 folder is given.
local root = os.getenv("XPLANE_ROOT")
if root ~= nil and root ~= "" then
    local function open_real(path, mode) return io.open(root.."/"..path, mode) end
    local function real(airports)
        local loader = C.new_loader(open_real)
        C.loader_start(loader, airports)
        while not C.loader_step(loader, 400) do end
        return loader.records
    end
    case("EIDW 28R ENDE3J, EHAM LAMS2A, ILS 18R via SUG1D", function()
        local names = {"EIDW", "RW28R", "DE28R", "(650)", "DW128", "DW129", "DW124", "ATGOW", "ENDEQ", "RULAV",
            "ABGEP", "ALAVA", "MALUD", "WAL", "MCT", "XAPOS", "NAPEX", "DOLAS", "DIBAL", "BUKUT", "LAMSO", "ETPOS",
            "SUGOL", "NETOM", "NIRSI", "AM607", "AM608", "AM621", "AM622", "RW18R", "(500)", "AM624", "(VECT)", "EHAM"}
        local result = C.match_route(route_of(names), real({"EIDW", "EHAM"}))
        local c = result.constraints
        local function at(name) return c[index_of(names, name)] or {} end
        check(string.find(result.summary, "SID ENDE3J", 1, true) and string.find(result.summary, "STAR LAMS2A", 1, true)
            and string.find(result.summary, "APPCH I18R SUG1D", 1, true), "real procedures: "..result.summary)
        check(at("(650)").floor == 650 and at("(650)").speed == 210, "(650): +650 -210")
        check(at("DW128").speed == 210 and at("DW129").speed == 210, "DW128 and DW129 at or below 210 kt")
        check(at("DW124").ceiling == 9000, "DW124 at or below FL090")
        check(at("ENDEQ").ceiling == 23000 and at("ENDEQ").speed == 290, "ENDEQ at or below FL230, 290 kt")
        check(at("LAMSO").ceiling == 23000, "LAMSO at or below FL230")
        check(at("SUGOL").floor == 10000 and at("SUGOL").ceiling == 14000 and at("SUGOL").speed == nil,
            "SUGOL: SUG1D's window FL100-FL140 over LAMS2A's")
        check(at("NETOM").floor == 7000 and at("NETOM").speed == 250, "NETOM at or above FL070, 250 kt")
        check(at("NIRSI").floor == 5500 and at("NIRSI").speed == 220, "NIRSI at or above FL055, 220 kt")
        check(at("AM608").floor == 3400, "AM608 at or above 3400")
        check(at("AM621").floor == 2000, "AM621 at or above 2000")
        check(at("AM622").floor == 1310 and at("AM622").speed_desc == "+" and at("AM622").speed == 160,
            "AM622: the glide slope's 1310, at or above 160 kt")
        check(at("AM622").vangle == 3 and at("RW18R").vangle == 3, "ILS 18R's 3.00 deg final")
        check(c[index_of(names, "AM624")] == nil, "nothing from the missed approach")
    end)
    case("TST744L: EINN back to EINN, ILS 06 from ELPOM", function()
        local names = {"EINN", "RW24", "EMPER", "BEDRA", "ETARI", "BILTO", "ELPOM", "ASGON", "RW06", "NN005", "SHA",
            "EINN"}
        local result = C.match_route(route_of(names), real({"EINN", "EINN"}))
        local c = result.constraints
        check(string.find(result.summary, "APPCH I06", 1, true) ~= nil, "ILS 06: "..result.summary)
        check(c[7] ~= nil and c[7].floor == 3000 and c[8] ~= nil and c[8].floor == 3000, "ELPOM and ASGON at 3000")
        check(c[8].vangle == 3 and c[9] ~= nil and c[9].vangle == 3, "ILS 06's 3.00 deg final")
        check(c[3] == nil and c[6] == nil, "nothing on the oceanic fixes")
    end)
else
    print("vnav_cifp_constraints_test: XPLANE_ROOT not set, the real CIFP data are not checked")
end

if #failures > 0 then
    error(string.format("vnav_cifp_constraints_test: %d of %d checks failed:\n  %s", #failures, checks,
        table.concat(failures, "\n  ")), 0)
end
print(string.format("vnav_cifp_constraints_test: %d checks passed", checks))
