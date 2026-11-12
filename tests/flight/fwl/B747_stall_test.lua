-- B747 stall test for FlyWithLua (2026-11-12, the full review: docs/overhaul/REVIEW_2026-11-12.md D-1):
-- holds X-Plane's main thread for some seconds, as a long scenery load does, to see what the
-- aircraft's XTLua modules (their own worker threads) do meanwhile. The hold is a busy loop on
-- os.clock() (the wall clock on Windows) in the next frame's callback; the flight-test recorder's
-- `wall` column shows the long frame.
-- Commands FlyWithLua/B747_stall/ms600 (0.6 s: a flare's long frame), s1, s2, s5, s10, s30.
-- Does nothing unless the 747-400 is the user aircraft.
-- The kit's copy: tests/flight/fwl/B747_stall_test.lua; X-Plane's: Resources/plugins/FlyWithLua/Scripts/.
if not string.find(AIRCRAFT_PATH or "", "747-400", 1, true) then return end
B747ST_pending = 0
function B747ST_go(n) B747ST_pending = n end
function B747ST_frame()
    if B747ST_pending > 0 then
        local n = B747ST_pending
        B747ST_pending = 0
        local t = os.clock() + n
        while os.clock() < t do end
        logMsg("B747 stall test: the main thread held " .. n .. " s")
    end
end
create_command("FlyWithLua/B747_stall/ms600", "B747 stall test: hold X-Plane 0.6 s", "B747ST_go(0.6)", "", "")
create_command("FlyWithLua/B747_stall/s1", "B747 stall test: hold X-Plane 1 s", "B747ST_go(1)", "", "")
create_command("FlyWithLua/B747_stall/s2", "B747 stall test: hold X-Plane 2 s", "B747ST_go(2)", "", "")
create_command("FlyWithLua/B747_stall/s5", "B747 stall test: hold X-Plane 5 s", "B747ST_go(5)", "", "")
create_command("FlyWithLua/B747_stall/s10", "B747 stall test: hold X-Plane 10 s", "B747ST_go(10)", "", "")
create_command("FlyWithLua/B747_stall/s30", "B747 stall test: hold X-Plane 30 s", "B747ST_go(30)", "", "")
do_every_frame("B747ST_frame()")
