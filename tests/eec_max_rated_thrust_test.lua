-- Run from the repository root with Lua 5.1 or LuaJIT.
-- The PW4056's maximum EPR in flight (B747.42.xt.EEC.PW.lua): the EICAS's amber maximum line and the levers' full
-- forward stop (throttle_resolver_angle_PW gives the EPR of a lever position between 0.95 at idle and the maximum).
-- On the 747-400 the FMC's thrust limit follows the reference it selects (TO, CLB, CRZ, GA) and is the green
-- reference cursor; the maximum thrust limit, sent to the EIUs and the EECs, is the most the engines may give
-- whatever that reference (Lufthansa B747-400 ATA 34-61 training notes, EICAS thrust display). The module took the
-- maximum from the reference: max climb in CRZ, the GA rating in GA, and in CLB whatever it held from the takeoff.
-- The FMC selects GA in the approach (here below 1,500 ft RA with the flaps out), and at the same levers the EPR
-- rose with the maximum: p32-line1 (2026-10-20) at 1,496 ft on EHAM's ILS 18R, the A/T in SPD at 0.44, N1 went from
-- 58 to 68 % in 6 s and the speed from 160 to 167 kt, then the A/T went to idle for the 139 kt set at AM622 and the
-- 747 sank 2.3 dots below the glide slope slowing down. The maximum is now the GA rating in the CLB, CRZ and GA
-- references alike. The branches run in XTLua's namespace against mocked ratings; this does not validate the
-- engine model.
local EEC = "plugins/xtlua/scripts/B747.42.xt.EEC/B747.42.xt.EEC."
-- XTLua's script runtime (the EEC's plugin), for its namespaces
local runtime = setmetatable({}, {__index = _G})
setfenv(assert(loadfile("plugins/xtlua/init.lua")), runtime)()

local checks, failures = 0, {}
local function check(condition, message)
    checks = checks + 1
    if not condition then failures[#failures + 1] = message end
end
local function read(path)
    local file = assert(io.open(path))
    local source = file:read("*a")
    file:close()
    return source
end

-- PW's reference branches, from the maximum's line (or the TO branch without it) to the end of the GA branch
local source = read(EEC.."PW.lua")
local first = source:find("-- [P38] The maximum rated EPR in flight", 1, true)
    or assert(source:find('if string.match(B747DR_ref_thr_limit_mode, "TO") or B747DR_ref_thr_limit_mode == "" then',
        1, true))
local last = assert(source:find("--Handle minor engine thrust differences", first, true))
local branches = source:sub(first, last - 1)
local tra_first = assert(source:find("function throttle_resolver_angle_PW(engine_in)", 1, true))
local tra_last = assert(source:find("function engine_idle_control_PW(", tra_first, true))
local tra = source:sub(tra_first, tra_last - 1)
-- the shared helpers of B747.42.xt.EEC.lua from B747_rescale on to round_thrustcalc, and the EEC's tables
local function helpers(env)
    local eec = read(EEC.."lua")
    local a = assert(eec:find("function B747_rescale(", 1, true))
    local b = assert(eec:find("function round_thrustcalc(", a, true))
    setfenv(assert(loadstring(eec:sub(a, b - 1))), env)()
    setfenv(assert(loadstring(read(EEC.."tbls.lua"))), env)()
end

-- One frame of the branches: the reference, pressure altitude ft, TAT C, the packs' adjustment, the target bug left
-- by the last frame (0.9 with the A/T in IDLE or HOLD in the descent), the maximum held from before (the takeoff's)
local function frame(mode, altitude, tat, packs, last_bug, held_max)
    local env = runtime.create_namespace()
    for name, value in pairs({B747DR_ref_thr_limit_mode = mode, altitude_ft_in = altitude, simDR_TAT = tat,
            simDR_temperature = tat - 5, mach = 0.45, simDR_altitude = altitude, B747DR_clbderate = 0,
            packs_adjustment_value = packs or 0, engine_anti_ice_adjustment_value = 0, orig_thrust_n = 254000,
            simDR_thrust_max = 254000, B747DR_newsimconfig_data = 0, B747DR_log_level = 0,
            simDR_acf_weight_total_kg = 300000}) do
        env[name] = value
    end
    helpers(env)
    env.in_flight_EPR_PW = function() return 1.20, 1.40, 1.40 end
    env.find_closest_weight = function() return 300 end
    env.find_closest_altitude = function() return 3 end
    env.P85M_epr_PW4062 = setmetatable({[300] = setmetatable({[3] = 1.20}, {})}, {})
    env.EPR_target_bug, env.display_EPR_ref, env.display_EPR_max = {}, {}, {}
    for i = 0, 3 do
        env.EPR_target_bug[i] = last_bug or 1.50
        env.display_EPR_ref[i] = 1.40
        env.display_EPR_max[i] = held_max or 1.58
    end
    env.simDR_EPR_target_bug = {[0] = last_bug or 1.50, last_bug or 1.50, last_bug or 1.50, last_bug or 1.50}
    env.B747DR_display_EPR_max = {[0] = held_max or 1.58, held_max or 1.58, held_max or 1.58, held_max or 1.58}
    env.B747DR_display_EPR_ref = {[0] = 1.40, 1.40, 1.40, 1.40}
    local ok, err = pcall(function() setfenv(assert(loadstring(branches)), env)() end)
    if not ok then return nil, err end
    -- the levers at 0.44 with that maximum (the TRA the EEC holds)
    env.B747DR_display_EPR_max = {[0] = env.display_EPR_max[0]}
    env.B747DR_throttle = {[0] = 0.44}
    setfenv(assert(loadstring(tra)), env)()
    return tonumber(env.display_EPR_max[0]), env.throttle_resolver_angle_PW(0)
end

-- The GA rating: 1.5 + 0.000017 x altitude below -10.15 TAT^2 + 57.654 TAT + 9526.4 ft, else 1.74 - 0.00669 TAT,
-- in hundredths with the packs' adjustment, at most 1.71 on the tape
local function rating(altitude, tat, packs)
    local epr = altitude < (-10.15 * tat ^ 2 + 57.654 * tat + 9526.4) and 0.000017 * altitude + 1.5
        or -0.00669 * tat + 1.74
    return math.min(tonumber(string.format("%3.2f", epr + (packs or 0))), 1.71)
end

-- the approach: CRZ above 1,500 ft and GA below at 3,000 ft, TAT 10 C, the A/T in SPD with the levers at 0.44
-- (the GA rating 1.55: TRA 1.214 in both; CRZ held max climb, 1.40, TRA 1.148, and GA's rating raised it to 1.214)
local crz_max, crz_tra = frame("CRZ", 3000, 10)
local ga_max, ga_tra = frame("GA", 3000, 10)
check(crz_max and ga_max and math.abs(crz_max - rating(3000, 10)) < 1e-6 and math.abs(ga_max - crz_max) < 1e-6,
    string.format("3,000 ft TAT 10 C: maximum CRZ %s, GA %s (%.2f)", tostring(crz_max), tostring(ga_max),
    rating(3000, 10)))
check(crz_tra and ga_tra and math.abs(crz_tra - ga_tra) < 1e-6, string.format(
    "levers at 0.44 from CRZ to GA: TRA %s to %s (no change)", tostring(crz_tra), tostring(ga_tra)))
-- CLB at the same point: the rating, not the takeoff's maximum held (1.58)
local clb_max, clb_err = frame("CLB", 3000, 10)
check(clb_max and math.abs(clb_max - rating(3000, 10)) < 1e-6, string.format(
    "CLB at 3,000 ft: maximum %s (%.2f; the takeoff's 1.58 held)", tostring(clb_max or clb_err), rating(3000, 10)))
-- GA with the A/T in IDLE or HOLD in the descent (the bug left at 0.9): the rating, not 0.9 (which held the levers'
-- full forward stop at idle)
local idle_max = frame("GA", 1200, 10, 0, 0.9)
check(idle_max and math.abs(idle_max - rating(1200, 10)) < 1e-6, string.format(
    "GA with the A/T at idle: maximum %s (%.2f)", tostring(idle_max), rating(1200, 10)))
-- cruise at FL370, TAT -27 C: the rating's 1.92 on the 1.71 cap, in CRZ as in CLB
for _, mode in ipairs({"CRZ", "CLB"}) do
    local max = frame(mode, 37000, -27)
    check(max and math.abs(max - 1.71) < 1e-6, string.format("%s at FL370 TAT -27 C: maximum %s (1.71)", mode,
        tostring(max)))
end
-- two packs off (the PW4056's TO/GA adjustment) raises it as it raises the GA bug
local packs_max = frame("CRZ", 3000, 10, 0.02)
check(packs_max and math.abs(packs_max - rating(3000, 10, 0.02)) < 1e-6, string.format(
    "two packs off: maximum %s (%.2f)", tostring(packs_max), rating(3000, 10, 0.02)))
-- a climb reference over the rating (none in the tables; held to it as before): the maximum not below the reference
do
    local env_max = frame("CLB", 0, 40)
    check(env_max and env_max >= 1.40 - 1e-6, "CLB at sea level, TAT 40 C: maximum "..tostring(env_max)
        .." not below the reference (1.40)")
end

assert(#failures == 0, #failures.." of "..checks.." checks failed:\n"..table.concat(failures, "\n"))
print("EEC maximum rated thrust tests passed: "..checks)
