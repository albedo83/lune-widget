#!/usr/bin/env bash
# Signing is disabled for tests: the App Group entitlement needs a provisioning profile,
# which is unavailable for unregistered devices/CI. Real builds keep automatic signing.
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen
xcodebuild test -scheme Lune -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY=
(cd LuneKit && swift test)
