-- 747-400 EFB performance, the FMC's side (2026-11-25, the user's takeoff
-- and landing performance window "in X-Plane"; docs/overhaul/notes/
-- ATA-34-61-FMC.md §191). The sim's window (Plugins > 747-400 > Takeoff and
-- landing performance..., b747_fms_bridge perf_window.c: the EFB's
-- PERFORMANCE pages, FCOM p.1181-1183) asks; this module (dofile'd by
-- B747.68.xt.fms.lua, B747_efb_update every frame) looks the runway up in
-- the FMC's navigation data, works the performance out
-- (B747.68.efb_to_model.lua) and answers, and SENDs the takeoff's data to
-- the TAKEOFF REF and THRUST LIM pages through their own entries (a crew's
-- entries: the 405's and 570's data link loads takeoff data there, FCOM
-- p.1277, p.1320; the 109 has none: the sim's convenience).
--
-- The window's (b747_fms_bridge's datarefs):
--   laminar/B747/efb/req_id    (int) counted up after each request
--   laminar/B747/efb/req_kind  (int) 1 a runway, 2 the takeoff, 3 SEND the
--                              takeoff, 4 the landing, 5 the FMC's route
--   laminar/B747/efb/req_i     (int[16]) 0 the airport (4 characters in
--                              base 37, the first highest: unpack_id), 1 the
--                              runway ("34L" likewise), 2 the flaps, 3 the
--                              rating (0 TO, 1
--                              TO 1, 2 TO 2), 4 the assumed temperature
--                              wanted, 5 the packs on (3, 1, 0), 6 the
--                              anti-ice (0 off, 1 engines, 2 engines and
--                              wings), 7 the runway's condition (0 dry; the
--                              takeoff's 1 wet, 2 slush or standing water, 3
--                              medium, 4 poor braking action; the landing's
--                              1 good, 2 medium, 3 poor), 8 the autobrake, 9
--                              the landing's reversers (4, 2, 0), 10 the
--                              takeoff's on a contaminated runway (2, 0)
--   laminar/B747/efb/req_f     (float[16]) 0 OAT (°C), 1 QNH (hPa), 2 the
--                              headwind (kt, tail -), 3 the weight (kg), 4
--                              the CG (% MAC), 5 the runway not available
--                              behind the start (m: an intersection), 6 the
--                              runway's length (m) for one the data lack (0
--                              the data's), 7 the slope (%, -99 the data's),
--                              8 VREF's additive (kt), 9 the crosswind (kt),
--                              10 the slush or standing water's depth (mm)
-- This module's answers:
--   laminar/B747/efb/ans_id    the request answered (its req_id)
--   laminar/B747/efb/rwy       (array[16]) 0 1 found, 0 no airport, -1 no
--                              runway, -2 the data not read yet; 1 the
--                              runway's length (ft), 2 its threshold's
--                              displacement (ft), 3 the far end's, 4 its
--                              threshold's elevation (ft), 5 the far one's,
--                              6 the airport's, 7 the slope (%, uphill +),
--                              8 the true bearing (°), 9 latitude, 10
--                              longitude, 11 the request's kind
--   laminar/B747/efb/rwy_list  (string) the airport's runways ("16L 16R 34L")
--   laminar/B747/efb/out       (array[40]) the takeoff's (2, 3): 0 the kind,
--                              1 1 worked out (0 not: msg), 2 the pressure
--                              altitude (ft), 3-7 the field, climb, tire
--                              speed, brake energy and structural limit
--                              weights (kg; 0 none), 8 the most (kg), 9 the
--                              limit's (1 field, 2 climb, 3 tire, 4 brake,
--                              5 structural), 10 the assumed temperature
--                              (°C, -99 none), 11 what held it (0 none, 1 the
--                              limit line, 2 25 % thrust, 3 field, 4 climb,
--                              5 brake energy, 6 the runway not dry), 12-14
--                              V1, VR, V2, 15 VMBE, 16 VMBE checked, 17 the
--                              thrust (EPR or %N1), 18 1 for N1, 19 its
--                              reduction (%), 20 the trim (-1 none), 21 VREF
--                              30, 22 the field length (ft), 23 the slope,
--                              24 the headwind, 25 the elevation, 26 the
--                              flaps, 27 the rating, 28 the weight, 29 SEND
--                              done (1) or refused (0: msg); 30 the rating's
--                              thrust reduction (%); a contaminated runway's
--                              31 adjusted field length limit, 32 VMCG limit
--                              weight, 33 weight adjustment, 34 condition,
--                              35 depth (mm). The landing's (4): 0
--                              the kind, 1 1 worked out, 2 the pressure
--                              altitude, 3 VREF (the flaps'), 4 the approach
--                              speed (VREF and the additive), 5 the FCOM's
--                              landing distance (m), 6 the runway's from its
--                              threshold (m), 7 their difference, 8 and 9
--                              the FPPM's field length and climb limit
--                              weights, 10 the dispatch's normal limit (the
--                              least with the structural), 11 its VREF, 12
--                              the quick turnaround limit, 13 its time to
--                              wait (min), 14 the flaps, 15 the weight, 16
--                              the headwind, 17 the slope, 18 the
--                              elevation, 19 the low visibility's limit, 20
--                              with ice, 21 1 when the FPPM advises flaps 25,
--                              22 the structural landing weight
--   laminar/B747/efb/msg       (string) the answer's message, "" none
--   laminar/B747/efb/route     (string) the FMC's route for the window's
--                              defaults: "ORIG RWY DEST RWY FLAPS RATING"
--                              ("-" for none)
--   laminar/B747/efb/route_n   (array[8]) the same in numbers for the window
--                              (an XTLua string reaches another plugin a
--                              frame or so after the numbers: s435): 0-3 the
--                              origin, its runway, the destination, its
--                              runway (base 37 as req_i's, 0 none), 4 the
--                              flaps, 5 the rating
-- The models: this module's, the flight instruments' takeoff speeds and the
-- EEC's reference thrust (another XTLua plugin's folder: XTLua's dofile
-- reads a path from the module's own folder). Each load guarded: one that
-- fails leaves the window's answers "EFB NOT LOADED", not the FMC stopped
-- (an error in a module stops every module of its XTLua plugin)
local EEC = "../../../xtlua/scripts/B747.42.xt.EEC/"
local efbLoaded = true
for _, path in ipairs({"B747.68.efb_field_model.lua", "B747.68.efb_limits_model.lua", "B747.68.efb_to_model.lua",
    "B747.68.efb_ldg_model.lua", "B747.68.efb_contam_model.lua",
    "../B747.60.xt.fltInst/B747.60.to_speeds_model.lua", EEC .. "B747.42.eec_model.lua",
    EEC .. "B747.42.epr_model.lua", EEC .. "B747.42.ge_n1_model.lua", EEC .. "B747.42.rr_model.lua",
    EEC .. "B747.42.ref_thrust_model.lua"}) do
    if not pcall(dofile, path) then efbLoaded = false end
end

B747DR_efb_req_id = find_dataref("laminar/B747/efb/req_id")
B747DR_efb_req_kind = find_dataref("laminar/B747/efb/req_kind")
B747DR_efb_req_i = find_dataref("laminar/B747/efb/req_i")
B747DR_efb_req_f = find_dataref("laminar/B747/efb/req_f")
B747DR_efb_ans_id = deferred_dataref("laminar/B747/efb/ans_id", "number")
B747DR_efb_rwy = deferred_dataref("laminar/B747/efb/rwy", "array[16]")
B747DR_efb_rwy_list = deferred_dataref("laminar/B747/efb/rwy_list", "string")
B747DR_efb_out = deferred_dataref("laminar/B747/efb/out", "array[40]")
B747DR_efb_msg = deferred_dataref("laminar/B747/efb/msg", "string")
B747DR_efb_route = deferred_dataref("laminar/B747/efb/route", "string")
B747DR_efb_route_n = deferred_dataref("laminar/B747/efb/route_n", "array[8]")
B747DR_efb_engine_type = find_dataref("laminar/B747/engines/type")
B747DR_efb_m_max = find_dataref("sim/aircraft/weight/acf_m_max")

local NI, NF = 16, 16
local reqI, reqF = {}, {}
local efbSeen, efbWarm, efbPrimed = 0, 0, false

-- the request's arrays (XTLua gives a read of another plugin's dataref the
-- value fetched at its previous read: read twice, the second the request's)
local function read_request()
    for k = 0, NI - 1 do reqI[k] = B747DR_efb_req_i[k] or 0 end
    for k = 0, NF - 1 do reqF[k] = B747DR_efb_req_f[k] or 0 end
end

-- a packed identifier: up to 4 characters in base 37, the first highest
-- (A-Z 1-26, 0-9 27-36, none 0: at most 1,874,160, whole in the float
-- XTLua reads another plugin's int as; s435 2026-11-25: a byte a character
-- lost the last ones)
local function unpack_id(code)
    code = math.floor((tonumber(code) or 0) + 0.5)
    local s = ""
    for k = 3, 0, -1 do
        local d = math.floor(code / 37 ^ k) % 37
        if d >= 1 and d <= 26 then
            s = s .. string.char(64 + d)
        elseif d >= 27 then
            s = s .. string.char(48 + d - 27)
        end
    end
    return s
end

-- an identifier packed as unpack_id reads it ("-" or "" 0)
local function pack_id(s)
    local v, n = 0, 0
    for c in string.upper(s or ""):gmatch("[%w]") do
        if n == 4 then break end
        local b = string.byte(c)
        v = v * 37 + ((b >= 65 and b <= 90) and b - 64 or (b >= 48 and b <= 57) and b - 48 + 27 or 0)
        n = n + 1
    end
    for _ = n + 1, 4 do v = v * 37 end
    return v
end

-- "34L", "RW34L", "9" -> "RW34L", "RW09"; nil not a runway
local function runway_id(s)
    s = string.upper(s or ""):gsub("^RW", "")
    local n, side = string.match(s, "^(%d%d?)([LCRT]?)$")
    if not n or tonumber(n) < 1 or tonumber(n) > 36 then return nil end
    return string.format("RW%02d%s", tonumber(n), side)
end

-- the initial true course (°) from one point to another
local function course(lat1, lon1, lat2, lon2)
    local r = math.rad
    local p1, p2, dl = r(lat1), r(lat2), r(lon2 - lon1)
    local y = math.sin(dl) * math.cos(p2)
    local x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl)
    return (math.deg(math.atan2(y, x)) + 360) % 360
end

local OTHER_SIDE = {L = "R", R = "L", C = "C", T = "T", [""] = ""}
-- a runway of an airport from the FMC's data: {ident, lat, lon, elev,
-- displaced, apt_elev, length_ft, far_displaced, far_elev, slope, brg};
-- nil and the status (0 no airport, -1 no runway, -2 the data not read
-- yet), the airport and its runways' list
local function efb_runway(icao, id)
    local N, db = B747_navdb, B747_fmc_navdb
    if not (db and db.ready) then return nil, -2 end
    local apt = string.match(icao, "^%u%u%u%u$") and N.airport(db, icao) or nil
    if not apt then return nil, 0 end
    local c = N.cifp(db, icao)
    local list = {}
    if c then
        for k in pairs(c.runways) do list[#list + 1] = (k:gsub("^RW", "")) end
        table.sort(list)
    end
    local rw = c and id and c.runways[id]
    if not rw then return nil, -1, apt, list end
    local r = {ident = id, lat = rw.lat, lon = rw.lon, elev = rw.elev, displaced = rw.displaced or 0,
        apt_elev = apt.elev or rw.elev}
    local num, side = string.match(id, "^RW(%d%d)([LCRT]?)$")
    local other = num and c.runways[string.format("RW%02d%s", (tonumber(num) + 17) % 36 + 1, OTHER_SIDE[side])]
    if other then
        local d_ft = N.distance(rw.lat, rw.lon, other.lat, other.lon) * 6076.12
        r.length_ft = d_ft + r.displaced + (other.displaced or 0)
        r.far_displaced = other.displaced or 0
        r.far_elev = other.elev
        -- the average gradient between the thresholds (the CIFP's own
        -- gradient field is mostly blank: estimate)
        r.slope = d_ft > 0 and (other.elev - rw.elev) / d_ft * 100 or 0
        r.brg = course(rw.lat, rw.lon, other.lat, other.lon)
    end
    return r, 1, apt, list
end

local function set_rwy(kind, r, status)
    local a = B747DR_efb_rwy
    for k = 0, 15 do a[k] = 0 end
    a[0] = status
    a[11] = kind
    if not r then return end
    a[1] = r.length_ft or 0
    a[2] = r.displaced or 0
    a[3] = r.far_displaced or 0
    a[4] = r.elev or 0
    a[5] = r.far_elev or r.elev or 0
    a[6] = r.apt_elev or 0
    a[7] = r.slope or 0
    a[8] = r.brg or 0
    a[9] = r.lat or 0
    a[10] = r.lon or 0
end

local STATUS_TEXT = {[0] = "AIRPORT NOT FOUND", [-1] = "RUNWAY NOT FOUND", [-2] = "NAV DATA NOT READY"}

-- the request's runway (looked up and answered); nil, the message
local function request_runway(kind)
    local icao, id = unpack_id(reqI[0]), runway_id(unpack_id(reqI[1]))
    local r, status, _, list = efb_runway(icao, id)
    B747DR_efb_rwy_list = list and table.concat(list, " ") or ""
    set_rwy(kind, r, status)
    if not r then return nil, STATUS_TEXT[status] or "RUNWAY NOT FOUND" end
    -- the window's length (m) when the data lack the far end
    if (reqF[6] or 0) > 0 then r.length_ft = reqF[6] / 0.3048 end
    if not r.length_ft then return nil, "RUNWAY LENGTH UNKNOWN" end
    if (reqF[7] or -99) > -90 then r.slope = reqF[7] end
    B747DR_efb_rwy[1] = r.length_ft
    B747DR_efb_rwy[7] = r.slope or 0
    return r
end

local LIMITS = {"field", "climb", "tire", "brake", "struct"}
local LIMIT_CODE = {field = 1, climb = 2, tire = 3, brake = 4, struct = 5}
local ATM_CODE = {["LIMIT LINE"] = 1, ["25 % THRUST"] = 2, FIELD = 3, CLIMB = 4, ["BRAKE ENERGY"] = 5,
    ["RUNWAY NOT DRY"] = 6}

local lastTo = nil     -- the last takeoff worked out: {inp, out}

-- the takeoff's inputs from the request and the runway
local function takeoff_inputs(r)
    local engine = math.floor(B747DR_efb_engine_type or 0)
    local rating = math.floor(reqI[3] or 0)
    if rating < 0 or rating > 2 then rating = 0 end
    local fla = r.length_ft - math.max(0, reqF[5] or 0) / 0.3048
    local w = reqF[3] or 0
    local cg = reqF[4] or 0
    return {
        engine = engine, flaps = (reqI[2] == 10) and 10 or 20, rating = rating,
        to_pct = B747_fms_thrlim_pct and B747_fms_thrlim_pct(rating) or ({[0] = 0, 8, 20})[rating],
        atm = (reqI[4] or 0) ~= 0, cond = math.floor(reqI[7] or 0),
        rev = (reqI[10] or 2) == 0 and 0 or 2, depth_mm = reqF[10] or 0,
        packs = ({[0] = 0, [1] = 1})[math.floor(reqI[5] or 3)] or 3,
        eng_ai = (reqI[6] or 0) >= 1, wing_ai = (reqI[6] or 0) >= 2,
        oat_c = reqF[0] or 15, qnh_hpa = (reqF[1] or 0) > 800 and reqF[1] or 1013.25,
        elev_ft = r.apt_elev or r.elev or 0, fla_ft = fla, slope_pct = r.slope or 0,
        wind_kt = reqF[2] or 0, tow_kg = w > 0 and w or nil, cg_pct = cg > 0 and cg or nil,
        mtow_kg = (B747DR_efb_m_max or 0) > 0 and B747DR_efb_m_max or 396893,
    }
end

local function answer_takeoff(kind, inp, out)
    local a = B747DR_efb_out
    for k = 0, 39 do a[k] = 0 end
    a[0] = kind
    a[1] = out.err and 0 or 1
    a[2] = out.pa_ft or 0
    for k, name in ipairs(LIMITS) do a[2 + k] = out.lim[name] or 0 end
    a[8] = out.max_kg or 0
    a[9] = LIMIT_CODE[out.limit or ""] or 0
    a[10] = out.sel_c or -99
    a[11] = ATM_CODE[out.atm_why or ""] or 0
    a[12], a[13], a[14] = out.v1 or 0, out.vr or 0, out.v2 or 0
    a[15] = out.vmbe or 0
    a[16] = out.vmbe_check and 1 or 0
    a[17] = out.thrust or 0
    a[18] = out.thrust_n1 and 1 or 0
    a[19] = out.thrust_red or 0
    a[20] = out.trim or -1
    a[21] = out.vref30 or 0
    a[22] = inp.fla_ft or 0
    a[23] = inp.slope_pct or 0
    a[24] = inp.wind_kt or 0
    a[25] = inp.elev_ft or 0
    a[26] = inp.flaps
    a[27] = inp.rating
    a[28] = inp.tow_kg or 0
    a[30] = inp.to_pct or 0
    -- a contaminated runway's working (B747.68.efb_to_model.lua out.contam)
    local c = out.contam
    if c then
        -- the VMCG limit weight read past the tables' heavy end (the model
        -- carries it on: not limiting) shown as none
        local vm = c.vmcg_kg or 0
        a[31], a[32], a[33] = c.limit_kg or 0, vm < 500000 and vm or 0, c.adjust_kg or 0
        a[34], a[35] = inp.cond or 0, (inp.cond == 2) and (inp.depth_mm or 0) or 0
    end
end

local function request_takeoff(kind)
    local r, why = request_runway(kind)
    if not r then
        lastTo = nil
        B747DR_efb_out[0], B747DR_efb_out[1] = kind, 0
        return why
    end
    local inp = takeoff_inputs(r)
    local ok, out = pcall(B747_efb_to_model.calc, inp)
    if not ok then
        lastTo = nil
        B747DR_efb_out[0], B747DR_efb_out[1] = kind, 0
        return "CALC ERROR"
    end
    answer_takeoff(kind, inp, out)
    lastTo = not out.err and inp.tow_kg and {inp = inp, out = out} or nil
    return out.err or ""
end

-- an entry as the CDU's: the key's function and the scratchpad's text;
-- the FMC's notification back ("" none)
local function cdu_entry(fn, key, text)
    local o = {id = "fmsL", scratchpad = text, notify = ""}
    fmsFunctions[fn](o, key)
    return o.notify or ""
end

-- SEND: the takeoff worked out with these inputs, into the TAKEOFF REF and
-- THRUST LIM pages' entries in the order that keeps the speeds (a flap,
-- wind, assumed temperature or rating change deletes selected speeds)
local function send_takeoff()
    if simDR_onGround ~= 1 then return "ON THE GROUND ONLY" end
    local t = lastTo
    if not t then return "CALC FIRST" end
    local inp, out = t.inp, t.out
    local steps = {
        {"setdata", "toflaps", string.format("%d", inp.flaps)},
        {"setDref", ({[0] = "TO", "TO1", "TO2"})[inp.rating], ""},
    }
    -- the wind and slope as the page takes them (HXX/TXX, UX.X/DX.X up to 2.0)
    local wind = math.floor(math.abs(inp.wind_kt) + 0.5)
    local slope = math.abs(inp.slope_pct)
    if wind <= 99 and slope <= 2.0 then
        steps[#steps + 1] = {"setdata", "towind", string.format("%s%02d/%s%.1f", inp.wind_kt < 0 and "T" or "H", wind,
            inp.slope_pct < 0 and "D" or "U", math.floor(slope * 10 + 0.5) / 10)}
    end
    if out.sel_c then
        steps[#steps + 1] = {"setdata", "thrustsel", string.format("%d", out.sel_c)}
    else
        steps[#steps + 1] = {"setdata", "thrustsel", "DELETE"}
    end
    if inp.cg_pct then steps[#steps + 1] = {"setdata", "cg_mac", string.format("%d", math.floor(inp.cg_pct + 0.5))} end
    steps[#steps + 1] = {"setDref", "V1", string.format("%d", out.v1)}
    steps[#steps + 1] = {"setDref", "VR", string.format("%d", out.vr)}
    steps[#steps + 1] = {"setDref", "V2", string.format("%d", out.v2)}
    for _, s in ipairs(steps) do
        local note = cdu_entry(s[1], s[2], s[3])
        if note ~= "" then return string.upper(s[2]) .. ": " .. note end
    end
    return ""
end

-- the FMC's route for the window: origin, its runway, destination, the
-- approach's runway, the TAKEOFF REF flaps and the takeoff rating
local function route_text()
    local st = B747_fmc_route
    -- the route being modified if any (a new runway not yet executed), else the route
    local r = st and (st.mod or st.rte) or nil
    -- none: nil, "" or the CDU's boxes ("****": RTE's DEST not entered)
    local function id(x) return (x and x ~= "" and not string.match(x, "^%*+$")) and x or "-" end
    local orig = r and r.origin and r.origin.ident or fmsModules["data"]["fltdep"]
    local dest = r and r.dest and r.dest.ident or fmsModules["data"]["fltdst"]
    local dep = r and r.runway and r.runway.ident or nil
    local arr = r and r.appr and r.appr.rwy or nil
    local flaps = tonumber(B747DR_airspeed_flapsRef) or 0
    local rating = B747_fms_thrlim and B747_fms_thrlim().to or 0
    local function clean(x) return x and (string.gsub(tostring(x), "%s", "")) or nil end
    local o, r1, d, r2 = id(clean(orig)), id(dep and (dep:gsub("^RW", ""))), id(clean(dest)),
        id(arr and (arr:gsub("^RW", "")))
    local f, rt = (flaps == 10 or flaps == 20) and flaps or 0, tonumber(rating) or 0
    local n = B747DR_efb_route_n
    n[0], n[1], n[2], n[3] = pack_id(o ~= "-" and o or ""), pack_id(r1 ~= "-" and r1 or ""),
        pack_id(d ~= "-" and d or ""), pack_id(r2 ~= "-" and r2 or "")
    n[4], n[5] = f, rt
    return string.format("%s %s %s %s %d %d", o, r1, d, r2, f, rt)
end

-- the landing (kind 4): VREF and the approach speed (the FMC's VREF table),
-- the FCOM's in-flight landing distance (PI.12, PI.22) against the
-- runway's from its threshold, the FPPM's dispatch limit weights (field
-- length, climb, with ice, low visibility) and the quick turnaround limit
-- (B747.68.efb_ldg_model.lua). The structural landing weight FCOM p.78
-- (L.10.2): the 109 (P&W, RR) 285,763 kg, the 570 (GE) 652,000 lb
local LDG_COND = {[0] = "DRY", "GOOD", "MEDIUM", "POOR"}
local LDG_BRAKE = {[0] = "MAX MANUAL", "MAX AUTO", "4", "3", "2", "1"}
local LDG_MLW = {[0] = 285763, [1] = 295742, [2] = 285763}
local function request_landing()
    local r, why = request_runway(4)
    local a = B747DR_efb_out
    for k = 0, 39 do a[k] = 0 end
    a[0] = 4
    if not r then return why end
    local L = B747_efb_ldg_model
    local engine = math.floor(B747DR_efb_engine_type or 0)
    local flaps = (reqI[2] == 25) and 25 or 30
    local cond = LDG_COND[math.floor(reqI[7] or 0)] or "DRY"
    local brake = LDG_BRAKE[math.floor(reqI[8] or 3)] or "3"
    local rev = math.floor(reqI[9] or 4)
    local oat = reqF[0] or 15
    local qnh = (reqF[1] or 0) > 800 and reqF[1] or 1013.25
    local wind = reqF[2] or 0
    local w = reqF[3] or 0
    local add = (reqF[8] or -1) >= 0 and reqF[8] or 5
    local elev = r.apt_elev or r.elev or 0
    local pa = B747_efb_to_model.pressure_altitude(elev, qnh)
    -- the landing distance available: from this end's threshold
    local lda_m = (r.length_ft - (r.displaced or 0)) * 0.3048
    local slope = r.slope or 0
    a[2], a[6], a[14], a[15], a[16], a[17], a[18] = pa, lda_m, flaps, w, wind, slope, elev
    if w <= 0 then return "WEIGHT NEEDED" end
    local vref = B747_vref_model.vref(flaps, w, elev)
    a[3] = math.floor(vref + 0.5)
    a[4] = math.floor(vref + add + 0.5)
    local d, dwhy = L.distance(engine, flaps, cond, brake, w, pa, oat, wind, slope, add, rev)
    a[5] = d or 0
    a[7] = d and (lda_m - d) or 0
    local disp = L.dispatch({flaps = flaps, lda_m = lda_m, pa_ft = pa, elev_ft = elev, oat_c = oat, wind_kt = wind,
        slope_pct = slope, cond = cond == "DRY" and "DRY" or "WET", packs = 3, mlw_kg = LDG_MLW[engine] or 285763,
        weight_kg = w, vref_add_kt = add})
    a[8] = disp.field or 0
    a[9] = disp.climb or 0
    if disp.normal then a[10], a[11] = disp.normal.kg or 0, disp.normal.vref or 0 end
    a[12] = disp.qt_kg or 0
    a[13] = disp.qt_min or 0
    a[19] = disp.lowvis and disp.lowvis.kg or 0
    a[20] = disp.ice and disp.ice.kg or 0
    a[21] = disp.f25_advised and 1 or 0
    a[22] = LDG_MLW[engine] or 285763
    a[1] = d and 1 or 0
    if not d then return dwhy or "OFF THE TABLES" end
    if w > (LDG_MLW[engine] or 285763) + 0.5 then return "ABOVE THE MAXIMUM LANDING WEIGHT" end
    return ""
end

local function efb_request(kind)
    local msg = ""
    if not efbLoaded and kind >= 1 and kind <= 4 then
        msg = "EFB NOT LOADED"
    elseif kind == 1 then
        local _, why = request_runway(1)
        msg = why or ""
    elseif kind == 2 then
        msg = request_takeoff(2)
    elseif kind == 3 then
        msg = request_takeoff(3)
        if msg == "" then
            msg = send_takeoff()
            B747DR_efb_out[29] = msg == "" and 1 or 0
        end
    elseif kind == 4 then
        msg = request_landing()
    elseif kind == 5 then
        B747DR_efb_route = route_text()
    end
    B747DR_efb_msg = msg
end

local function efb_frame()
    local id = B747DR_efb_req_id
    if efbWarm < 30 then
        -- what the window asked before this module's first second: done
        efbWarm = efbWarm + 1
        efbSeen = id
        return
    end
    if efbPrimed then
        efbPrimed = false
        read_request()
        local kind = math.floor(B747DR_efb_req_kind or 0)
        local ok, err = pcall(efb_request, kind)
        if not ok then B747DR_efb_msg = "ERROR " .. string.sub(tostring(err), -100) end
        B747DR_efb_ans_id = efbSeen
    elseif id ~= efbSeen then
        efbSeen = id
        read_request()
        local _ = B747DR_efb_req_kind
        efbPrimed = true
    end
end

-- every frame (B747.68.xt.fms.lua's after_physics): guarded, so that the
-- window's plugin missing or a fault here never stops the FMC
function B747_efb_update()
    pcall(efb_frame)
end
