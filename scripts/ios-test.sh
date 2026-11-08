#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY' > .build/simulator-ids
import json, subprocess
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
runtimes = sorted((key for key in devices if 'iOS-' in key),
                  key=lambda key: tuple(map(int, key.split('iOS-')[1].split('-'))), reverse=True)
for family in ['iPhone', 'iPad']:
    found = next((d['udid'] for runtime in runtimes for d in devices[runtime]
                  if family in d['name'] and d['isAvailable']), None)
    if not found:
        raise SystemExit('No available ' + family + ' simulator')
    print(found)
PY
while IFS= read -r simulator; do
  xcrun simctl bootstatus "$simulator" -b
  xcodebuild test -project ios/OpenShareCI.xcodeproj -scheme OpenShareCI \
    -destination "platform=iOS Simulator,id=$simulator,arch=$(uname -m)" \
    -resultBundlePath ".build/tests-$simulator.xcresult" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 120 \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=-
done < .build/simulator-ids
