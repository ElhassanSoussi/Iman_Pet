#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
CHECK_DIR=$(mktemp -d)
trap 'rm -rf "$CHECK_DIR"' EXIT
swiftc Iman/Voice/WakePhrase.swift Iman/Voice/TranscriptOptions.swift Iman/Voice/HandsFreeSession.swift Tests/HandsFreeChecks.swift -o "$CHECK_DIR/voice-checks"
"$CHECK_DIR/voice-checks"
