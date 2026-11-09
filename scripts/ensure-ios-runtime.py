#!/usr/bin/env python3
"""Install an exact Apple simulator build and verify the registered result."""
import json
import os
import subprocess
import sys


def installed_runtime(version, build):
    runtimes = json.loads(subprocess.check_output(
        ["xcrun", "simctl", "list", "runtimes", "-j"], text=True))["runtimes"]
    for runtime in runtimes:
        print(f"Runtime: {runtime['version']} / {runtime.get('buildversion')} / "
              f"available={runtime.get('isAvailable')}", flush=True)
    return any(runtime.get("isAvailable") and runtime["version"] == version
               and runtime.get("buildversion") == build for runtime in runtimes)


def main():
    version = os.environ["OPENSHARE_IOS_RUNTIME"]
    build = os.environ["OPENSHARE_IOS_RUNTIME_BUILD"]
    if installed_runtime(version, build):
        print(f"Required iOS {version} ({build}) is already available.")
        return 0
    result = subprocess.run(["xcodebuild", "-downloadPlatform", "iOS", "-buildVersion", build,
                             "-architectureVariant", "arm64"])
    # Some Xcode builds return a nonzero status for an existing download. The
    # exact registered, usable runtime is the required postcondition.
    if installed_runtime(version, build):
        print(f"Verified iOS {version} ({build}); installer exit status {result.returncode}.")
        return 0
    print(f"Required iOS {version} ({build}) is unavailable after installation.", file=sys.stderr)
    return result.returncode or 1


if __name__ == "__main__":
    sys.exit(main())
