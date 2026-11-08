#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
python3 - <<'PY' > .build/simulator-ids
import json, subprocess, sys
devices = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'devices', 'available', '-j']))['devices']
sdk = tuple(map(int, subprocess.check_output(
    ['xcrun', '--sdk', 'iphonesimulator', '--show-sdk-version'], text=True).strip().split('.')[:2]))
def version(key):
    return tuple(map(int, key.split('iOS-')[1].split('-')))
# Multiple Xcodes share CoreSimulator devices. A newer runtime may appear available
# even though the selected Xcode's XCTest services cannot run against it.
runtimes = sorted((key for key in devices if 'iOS-' in key and
                   version(key)[0] == sdk[0] and version(key)[:2] <= sdk),
                  key=version, reverse=True)
for family in ['iPhone', 'iPad']:
    found = next(((runtime, d['udid']) for runtime in runtimes for d in devices[runtime]
                  if family in d['name'] and d['isAvailable']), None)
    if not found:
        raise SystemExit(f'No {family} simulator compatible with iOS SDK {sdk}')
    print(f'Testing {family} on {found[0]} ({found[1]})', file=sys.stderr)
    print(found[1])
PY
while IFS= read -r simulator; do
  xcodebuild test -project ios/OpenShareCI.xcodeproj -scheme OpenShareCI \
    -destination "platform=iOS Simulator,id=$simulator,arch=$(uname -m)" \
    -resultBundlePath ".build/tests-$simulator.xcresult" \
    -test-timeouts-enabled YES -default-test-execution-time-allowance 60 \
    -maximum-test-execution-time-allowance 120 \
    CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- </dev/null
done < .build/simulator-ids
