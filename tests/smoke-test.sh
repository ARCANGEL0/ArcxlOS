#!/usr/bin/env bash
# ArchangelOS smoke test: static checks that must pass before a release build.
# Does NOT run mkarchiso; it validates scripts, installers, launcher data and paths.
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
fail=0
note() { printf '%-6s %s\n' "$1" "$2"; }

echo "== bash -n on shell scripts =="
while IFS= read -r f; do
  if bash -n "$f" 2>/dev/null; then note "ok" "$f"; else note "FAIL" "$f"; fail=1; fi
done < <(find bin build.sh system -type f \( -name '*.sh' -o -name 'profiledef.sh' \) 2>/dev/null; \
         find system -type f -name 'customize_airootfs.sh')

echo "== python compile (installers + launcher) =="
while IFS= read -r f; do
  if python3 -m py_compile "$f" 2>/dev/null; then note "ok" "$f"; else note "FAIL" "$f"; fail=1; fi
done < <(find system -type f -name 'archangelos-gui-installer'; \
         echo system/common/airootfs/usr/bin/archangelos-launcher)

echo "== launcher menu.json is valid JSON =="
for ed in home gaming fallen; do
  f="system/$ed/airootfs/usr/share/archangelos/launcher/menu.json"
  if [ -f "$f" ] && python3 -c "import json;json.load(open('$f'))" 2>/dev/null; then
    note "ok" "$f"; else note "FAIL" "$f"; fail=1; fi
done

echo "== no stale configs/ or bin/lib-less script paths =="
if grep -rIn --include='*.sh' 'AX_ROOT}/configs' bin build.sh 2>/dev/null | grep -q .; then
  note "FAIL" "stale AX_ROOT}/configs reference"; fail=1
else note "ok" "no stale profile paths"; fi

echo
[ "$fail" -eq 0 ] && echo "SMOKE TEST PASSED" || echo "SMOKE TEST FAILED"
exit "$fail"
