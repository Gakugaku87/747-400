#!/usr/bin/env bash
# Run every regression test (tests/**/*_test.lua) with LuaJIT, each in its own
# interpreter, from the repository root. docs/overhaul/TESTING.md §3.
#   tests/run.sh            all tests
#   tests/run.sh static     only tests whose path contains "static"
# LUAJIT overrides the interpreter (default: the copy installed for this project).
# The last line but one counts the checks of the tests that passed (their
# "N checks passed" lines): the same commit gives the same numbers on every
# machine (TESTING.md §3: a cloud session's stand-in for X-Plane's DataRefs.txt).
cd "$(dirname "$0")/.." || exit 2
LUAJIT="${LUAJIT:-/c/Users/gakug/tools/luajit/bin/luajit.exe}"
filter="${1:-}"
pass=0
fail=0
checks=0
while IFS= read -r test; do
    case "$test" in *"$filter"*) ;; *) continue ;; esac
    if out=$("$LUAJIT" "$test" 2>&1); then
        pass=$((pass + 1))
        last=$(printf '%s\n' "$out" | tail -n 1)
        echo "ok   $test: $last"
        n=$(printf '%s\n' "$last" | tr -d '\r' | sed -n 's/^.*: \([0-9][0-9]*\) checks passed$/\1/p')
        checks=$((checks + ${n:-0}))
    else
        fail=$((fail + 1))
        echo "FAIL $test"
        printf '%s\n' "$out" | sed 's/^/     /'
    fi
done < <(find tests -name '*_test.lua' | sort)
echo "checks $checks"
echo "passed $pass, failed $fail"
[ "$fail" -eq 0 ]
