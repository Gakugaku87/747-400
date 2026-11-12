#!/bin/bash
# Runs flight-test scenarios (tests/flight/scenarios/*.json) one after the
# other with run_scenario.ps1 on the custom acf and writes each one's result
# line into tests/flight/runs/run_all_<time>.txt (docs/overhaul/TESTING.md
# §4). The landing tool is not included (bash tests/flight/tools/landing.sh).
#
#   bash tests/flight/tools/run_all.sh                  every scenario, by name
#                                                       (the major milestones:
#                                                       CLAUDE.md)
#   bash tests/flight/tools/run_all.sh <name>           from that scenario on
#   bash tests/flight/tools/run_all.sh --only <name>... those, in that order
#   bash tests/flight/tools/run_all.sh --list <file>    those of the file, one
#                                                       a line ("#" comments),
#                                                       in its order
# A name is a scenario's (s285_vnav_spd_trans_accel_heavy), its number alone
# (s285) or its file. With --only and --list a name not found stops the list
# before anything runs. (2026-11-12: on the user's PC s285 to s287 and eight
# regression scenarios were run in a set order by a script of that session.)
#
# X-Plane slows with the aircraft's reloads until its Web API times out
# (2026-11-02: two scenarios with no result about an hour after a start;
# TESTING.md §4.6). So X-Plane is started again (xp_restart.ps1:
# stopped, started, the Web API waited for, the 747 loaded once as a
# throwaway) before a scenario when its private memory is over MEM_LIMIT_GB,
# after RESTART_EVERY scenarios, and when it is not running; a scenario with
# no result is run once more after a restart. Restarts are "#" lines in the result file.
set -u
cd "$(dirname "$0")/../../.." || exit 2     # the aircraft folder
OUT="tests/flight/runs/run_all_$(date +%Y%m%d_%H%M%S).txt"
# (X-Plane with the 747 just loaded already uses 13-15 GB of private memory)
MEM_LIMIT_GB=${MEM_LIMIT_GB:-24}
RESTART_EVERY=${RESTART_EVERY:-8}
RESTART_PS=$(cygpath -w tests/flight/tools/xp_restart.ps1)
mkdir -p tests/flight/runs

# a scenario's file by its name, its number or its path
find_scenario() {
  local n=$1 f
  [ -f "$n" ] && { echo "$n"; return 0; }
  n=$(basename "$n" .json)
  [ -f "tests/flight/scenarios/$n.json" ] && { echo "tests/flight/scenarios/$n.json"; return 0; }
  for f in tests/flight/scenarios/"$n"_*.json; do
    [ -f "$f" ] && { echo "$f"; return 0; }
  done
  return 1
}

# the scenarios to run
files=()
case "${1:-}" in
  --only|--list)
    mode=$1; shift
    names=()
    if [ "$mode" = "--list" ]; then
      [ -f "${1:-}" ] || { echo "run_all.sh --list <file>: no file ${1:-}" >&2; exit 2; }
      while IFS= read -r line || [ -n "$line" ]; do
        line=${line%%#*}
        line=${line//$'\r'/}      # a file with CRLF line ends
        for w in $line; do names+=("$w"); done
      done < "$1"
    else
      names=("$@")
    fi
    [ ${#names[@]} -gt 0 ] || { echo "run_all.sh $mode: no scenario named" >&2; exit 2; }
    for n in "${names[@]}"; do
      f=$(find_scenario "$n") || { echo "run_all.sh: no scenario $n" >&2; exit 2; }
      files+=("$f")
    done
    ;;
  *)
    start=${1:-}
    started=0
    [ -z "$start" ] && started=1
    for f in tests/flight/scenarios/*.json; do
      name=$(basename "$f" .json)
      [ $started = 0 ] && [ "$name" = "$start" ] && started=1
      [ $started = 0 ] && continue
      files+=("$f")
    done
    [ ${#files[@]} -gt 0 ] || { echo "run_all.sh: no scenario ${start}" >&2; exit 2; }
    ;;
esac

# RUN_ALL_DRY=1: the scenarios that would run, one a line, and nothing else
# (tests/flight/kit_offline_test.ps1)
if [ -n "${RUN_ALL_DRY:-}" ]; then printf '%s\n' "${files[@]}"; exit 0; fi

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

stop_list() {
  echo "# $1" | tee -a "$OUT"
  exit 1
}

since=0
for f in "${files[@]}"; do
  name=$(basename "$f" .json)
  mem=$(xp_mem)
  case "$mem" in ''|*[!0-9-]*) mem=-1 ;; esac
  if [ "$mem" -lt 0 ]; then
    restart "not running" || stop_list "X-Plane did not come up: stopped before $name"
  elif [ "$mem" -gt "$MEM_LIMIT_GB" ] || [ "$since" -ge "$RESTART_EVERY" ]; then
    restart "${mem} GB, $since scenarios" || stop_list "X-Plane did not come up: stopped before $name"
  fi
  t0=$SECONDS
  res=$(run_one "$f")
  since=$((since + 1))
  if [ -z "$res" ]; then
    echo "$name no result $((SECONDS - t0)) s" | tee -a "$OUT"
    restart "no result" || stop_list "X-Plane did not come up: stopped after $name"
    t0=$SECONDS
    res=$(run_one "$f")
    since=$((since + 1))
    echo "$name (again) ${res:-no result} $((SECONDS - t0)) s" | tee -a "$OUT"
  else
    echo "$name $res $((SECONDS - t0)) s" | tee -a "$OUT"
  fi
done
echo "done: $OUT"
