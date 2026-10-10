#!/usr/bin/env bash
# Runs every Godot test headless; prints failures. Used before committing main.gd changes.
cd "$(dirname "$0")/../.."
GODOT="tools/godot-portable/Godot_v4.7.2-stable_win64_console.exe"
fail=0
for f in tests/test_*.gd; do
  out=$(timeout 300 "$GODOT" --headless --path . --script "res://$f" 2>&1); code=$?
  if [ $code -ne 0 ] || echo "$out" | grep -q "SCRIPT ERROR\|FAILED\|Assertion failed"; then echo "FAIL $f (exit $code)"; echo "$out" | grep -i "error\|fail" | head -3; fail=1; fi
done
echo TESTS_DONE fail=$fail
