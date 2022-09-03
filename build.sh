#!/usr/bin/env bash

set -euo pipefail

xcodebuild build
codesign --options runtime --strict --timestamp --force --deep -r="designated => anchor trusted and identifier com.getlantern.lantern" -s "Developer ID Application: Innovate Labs LLC (4FYC28AXA2)" -v build/Release/sysproxy
cp build/Release/sysproxy ../sysproxy-cmd/darwin
file ../sysproxy-cmd/darwin
