#!/usr/bin/env bash

set -euo pipefail

out=../sysproxy-cmd/binaries/darwin/sysproxy
xcodebuild build
codesign --options runtime --strict --timestamp --force --deep -r="designated => anchor trusted and identifier com.getlantern.lantern" -s "Developer ID Application: Innovate Labs LLC (4FYC28AXA2)" -v build/Release/sysproxy
cp build/Release/sysproxy $out
file $out