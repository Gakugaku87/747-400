#!/bin/bash
# Runs every flight-test scenario (tests/flight/scenarios/*.json) one after
# the other with run_scenario.ps1 on the custom acf, for the major milestones
# (docs/overhaul/TESTING.md §4; CLAUDE.md: all scenarios only then), and
# writes each one's result line into tests/flight/runs/run_all_<time>.txt.
# The landing tool is not included (bash tests/flight/tools/landing.sh).
#
# X-Plane slows with the aircraft's reloads until its Web API times out
# (2026-11-02: two scenarios with no result about an hour after a start;
# TESTING.md §4.6). So X-Plane is started again (xp_restart.ps1:
# stopped, started, the Web API waited for, the 747 loaded once as a
# throwaway) before a scenario when its private memory is over MEM_LIMIT_GB,
# after RESTART_EVERY scenarios, and when it is not running; a scenario with
# no result is run once more after a restart. Restarts are "#" lines in the
# result file.
#
#   bash tests/flight/tools/run_all.sh [first scenario name to start from]
set -u
cd "$(dirname "$0")/../../.." || exit 2     # the aircraft folder
OUT="tests/flight/runs/run_all_$(date +%Y%m%d_%H%M%S).txt"
# (X-Plane with the 747 just loaded already uses 13-15 GB of private memory)
MEM_LIMIT_GB=${MEM_LIMIT_GB:-24}
RESTART_EVERY=${RESTART_EVERY:-8}
RESTART_PS=$(cygpath -w tests/flight/tools/xp_restart.ps1)
start=${1:-}
started=0
[ -z "$start" ] && started=1

xp_mem() { powershell -NoProfile -ExecutionPolicy Bypass -File "$RESTART_PS" -Mem 2>/dev/null | tr -d '\r' | tail -1; }

# (up to three starts: X-Plane sometimes stays on its menus after the load,
# paused at time 0; a new start got past it)
restart() {
  local why=$1 t0 state try
  for try in 1 2 3; do
    t0=$SECONDS
    state=$(powershell -NoProfile -ExecutionPolicy Bypass -File "$RESTART_PS" 2>/dev/null | tr -d '\r' | tail -1)
    echo "# restart ($why, try $try) $(date +%H:%M:%S): X-Plane ${state:-down}, $((SECONDS - t0)) s" | tee -a "$OUT"
    [ "$state" = "up" ] && break
  done
  since=0
  [ "$state" = "up" ]
}

run_one() {
  powershell -NoProfile -ExecutionPolicy Bypass -File tests/flight/run_scenario.ps1 \
      -Scenario "$(cygpath -w "$1")" -Acf custom 2>&1 | sed -n 's/^result: .*  (\(pass .*\))$/\1/p'
}

since=0
for f in tests/flight/scenarios/*.json; do
  name=$(basename "$f" .json)
  [ $started = 0 ] && [ "$name" = "$start" ] && started=1
  [ $started = 0 ] && continue
  mem=$(xp_mem)
  case "$mem" in ''|*[!0-9-]*) mem=-1 ;; esac
  if [ "$mem" -lt 0 ]; then
    restart "not running" || { echo "# X-Plane did not come up: stopped before $name" | tee -a "$OUT"; exit 1; }
  elif [ "$mem" -gt "$MEM_LIMIT_GB" ] || [ "$since" -ge "$RESTART_EVERY" ]; then
    restart "${mem} GB, $since scenarios" || { echo "# X-Plane did not come up: stopped before $name" | tee -a "$OUT"; exit 1; }
  fi
  t0=$SECONDS
  res=$(run_one "$f")
  since=$((since + 1))
  if [ -z "$res" ]; then
    echo "$name no result $((SECONDS - t0)) s" | tee -a "$OUT"
    restart "no result" || { echo "# X-Plane did not come up: stopped after $name" | tee -a "$OUT"; exit 1; }
    t0=$SECONDS
    res=$(run_one "$f")
    since=$((since + 1))
    echo "$name (again) ${res:-no result} $((SECONDS - t0)) s" | tee -a "$OUT"
  else
    echo "$name $res $((SECONDS - t0)) s" | tee -a "$OUT"
  fi
done
echo "done: $OUT"
