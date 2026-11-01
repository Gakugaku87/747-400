-- 747-400 FMC ATC logon without X-Plane (6-1/6-2 step 12e; docs/overhaul/
-- notes/ATA-34-61-FMC.md §113): the ATC LOGON/STATUS page's state, the AFN
-- logon and the ATC COMM connection (FCOM p.755-757, p.1431, p.1433, p.1436;
-- FMSPG p.258, p.277-280):
--   LOGON TO     the ATS facility to log on to (four letters): boxes
--                without one, dashes once ATC COMM is established with it
--                (until a new one is entered or ATC COMM ends), blank
--                while the position or the tail number is invalid;
--                deletable while an identifier shows;
--   LOGON        SEND> with LOGON TO, FLT NO and the datalink READY;
--                SENDING until the network's acknowledgement, SENT, RESEND>
--                without one (ACK_S) or without ATC's response (AFN_S: both
--                estimates), ACCEPTED or REJECTED after ATC's response,
--                blank once the connection comes;
--   ATC COMM     <SELECT OFF while connected: ends it (not a logon in
--                progress);
--   ACT CTR, NEXT CTR the connected facility and the next one when known;
--   ADS          (ARM) <SELECT OFF, (OFF) <SELECT ARM; ADS EMERG SELECT
--                ON> or SELECT OFF> while not off (no ADS connections
--                here: never (ACT));
--   the FMC's messages: ATC COMM ESTABLISHED (a connection, also to a new
--   facility), ATC COMM TERMINATED, RE-LOGON TO ATC COMM (no response in
--   time, a negative one, a disconnection after NO COMM for NO_COMM_S
--   without a transfer, a flight number change during a logon).
--
--   local A = B747_atc_logon_model
--   local s = A.new()
--   A.enter_ctr(s, "KZAK"); A.send(s, now, ready)   -- the glue sends the AFN
--   A.ack(s); A.response(s, true, now); local msg = A.connect(s, "KZAK")
--   local msgs = A.update(s, now, ready)            -- timers; the messages to post

local M = setmetatable({}, {})
B747_atc_logon_model = M

M.ACK_S = 60          -- no network acknowledgement: RESEND (estimate)
M.AFN_S = 120         -- no AFN response: RESEND and RE-LOGON TO ATC COMM (estimate)
M.NO_COMM_S = 16 * 60 -- NO COMM while connected: disconnected (FMSPG p.258)
M.ESTABLISHED, M.TERMINATED, M.RELOGON = "ATC COMM ESTABLISHED", "ATC COMM TERMINATED", "RE-LOGON TO ATC COMM"

function M.new()
    return {ctr = nil,              -- LOGON TO's entry
        status = nil,               -- nil, "SENDING", "SENT", "RESEND", "ACCEPTED", "REJECTED"
        sent_ctr = nil,             -- the facility the last logon went to
        sent_t = nil,
        comm = false, act = nil, next = nil,
        no_comm_t = nil,            -- since when NO COMM while connected
        ads = "ARM", emerg = false}
end

-- LOGON TO: four letters; nil or the message
function M.enter_ctr(s, text)
    if not string.match(text or "", "^%a%a%a%a$") then return "INVALID ENTRY" end
    s.ctr, s.status = text, nil
    return nil
end
-- DELETE: only while an identifier shows
function M.delete_ctr(s)
    if not s.ctr then return "INVALID DELETE" end
    s.ctr, s.status = nil, nil
    return nil
end

-- SEND> (RESEND>) shown: LOGON TO, FLT NO, the datalink READY, not in progress
function M.can_send(s, flt_ok, ready)
    if not s.ctr or not flt_ok or not ready then return false end
    return s.status == nil or s.status == "RESEND" or s.status == "REJECTED"
end
-- SEND or RESEND pushed: true when sent (the glue sends the AFN logon)
function M.send(s, now, flt_ok, ready)
    if not M.can_send(s, flt_ok, ready) then return false end
    s.status, s.sent_ctr, s.sent_t = "SENDING", s.ctr, now
    return true
end
-- the network's acknowledgement
function M.ack(s)
    if s.status == "SENDING" then s.status = "SENT" end
end
-- ATC's AFN response: the messages to post
function M.response(s, positive)
    if s.status ~= "SENDING" and s.status ~= "SENT" and s.status ~= "RESEND" then return {} end
    if positive then
        s.status = "ACCEPTED"
        return {}
    end
    s.status = "REJECTED"
    return {M.RELOGON}
end
-- the connection with a facility (its connection request): the message
function M.connect(s, ctr)
    s.comm, s.act, s.no_comm_t = true, ctr, nil
    if s.ctr == nil or s.ctr == ctr then s.ctr, s.status = nil, nil end
    return M.ESTABLISHED
end
-- the next facility, when known
function M.set_next(s, ctr) s.next = ctr end
-- ATC COMM ended: by the crew (SELECT OFF) or ATC without a transfer; the
-- messages to post
function M.terminate(s, relogon)
    if not s.comm then return {} end
    s.comm, s.act, s.next, s.no_comm_t = false, nil, nil, nil
    return {relogon and M.RELOGON or M.TERMINATED}
end
-- a new flight number: every ATC COMM and logon in progress ends (FMSPG
-- p.278, p.258)
function M.new_flight(s)
    local msgs = M.terminate(s, false)
    if s.status == "SENDING" or s.status == "SENT" then
        s.status = "RESEND"
        msgs[#msgs + 1] = M.RELOGON
    end
    return msgs
end
-- the timers: the messages to post
function M.update(s, now, ready)
    local msgs = {}
    if s.status == "SENDING" and s.sent_t and now - s.sent_t >= M.ACK_S then
        s.status = "RESEND"
    elseif s.status == "SENT" and s.sent_t and now - s.sent_t >= M.AFN_S then
        s.status = "RESEND"
        msgs[#msgs + 1] = M.RELOGON
    end
    if s.comm then
        if ready then
            s.no_comm_t = nil
        elseif not s.no_comm_t then
            s.no_comm_t = now
        elseif now - s.no_comm_t >= M.NO_COMM_S then
            for _, m in ipairs(M.terminate(s, true)) do msgs[#msgs + 1] = m end
        end
    end
    return msgs
end

-- ADS: (ARM) and (OFF) by the crew; ADS EMERG
function M.ads_toggle(s)
    if s.ads == "OFF" then s.ads = "ARM" else s.ads, s.emerg = "OFF", false end
end
function M.emerg_toggle(s)
    if s.ads == "OFF" then return false end
    s.emerg = not s.emerg
    return true
end

-- the page's fields: l1 (boxes, the facility, dashes, blank), r1 (SEND>,
-- SENDING, ...), act, next; inp.flt_ok, inp.ready, inp.pos_ok, inp.tail_ok
function M.view(s, inp)
    local v = {}
    if not inp.pos_ok or not inp.tail_ok then
        v.l1 = ""
    elseif s.ctr then
        v.l1 = s.ctr
    elseif s.comm then
        v.l1 = "----"
    else
        v.l1 = "****"
    end
    if s.status == "RESEND" then
        v.r1 = (s.ctr and inp.flt_ok and inp.ready) and "RESEND>" or ""
    elseif s.status then
        v.r1 = s.status
    else
        v.r1 = M.can_send(s, inp.flt_ok, inp.ready) and "SEND>" or ""
    end
    v.act = s.comm and s.act or ""
    v.next = s.comm and s.next or ""
    return v
end

return M
