#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
cleanup_owned_simulators() {
  if [[ -n "${OPENSHARE_IOS_RUNTIME:-}" && -f .build/simulator-ids ]]; then
    while IFS= read -r owned_simulator; do
      xcrun simctl shutdown "$owned_simulator" >/dev/null 2>&1 || true
      xcrun simctl delete "$owned_simulator" >/dev/null 2>&1 || true
    done < .build/simulator-ids
  fi
}
trap cleanup_owned_simulators EXIT
python3 - <<'PY' > .build/simulator-ids
import json, subprocess, sys, os
requested = os.environ.get('OPENSHARE_IOS_RUNTIME')
if requested:
    runtimes = json.loads(subprocess.check_output(['xcrun', 'simctl', 'list', 'runtimes', '-j']))['runtimes']
    required_build = os.environ.get('OPENSHARE_IOS_RUNTIME_BUILD')
    runtime = next((r for r in runtimes if r.get('isAvailable') and r['version'] == requested and
                    (not required_build or r.get('buildversion') == required_build)), None)
    if not runtime:
        raise SystemExit(f'Required iOS {requested} runtime ({required_build}) is not installed')
    for family in ['iPhone', 'iPad']:
        device_type = next((t for t in runtime.get('supportedDeviceTypes', []) if t['name'].startswith(family + ' ')), None)
        if not device_type:
            raise SystemExit(f'iOS {requested} does not provide a supported {family} device type')
        device = subprocess.check_output(['xcrun', 'simctl', 'create', f'OpenShare CI {family}',
                                         device_type['identifier'], runtime['identifier']], text=True).strip()
        print(f'Testing {family} on iOS {requested} build {runtime.get("buildversion")} ({device})', file=sys.stderr)
        print(device)
    raise SystemExit(0)
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
  # Hosted runners have limited memory; release the tested phone before booting the iPad.
  if [[ "${CI:-}" == "true" || -n "${OPENSHARE_IOS_RUNTIME:-}" ]]; then
    xcrun simctl shutdown "$simulator" >/dev/null 2>&1 || true
  fi
done < .build/simulator-ids
