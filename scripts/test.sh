#!/bin/zsh
set -eu
cd "${0:A:h}/.."
umask 077
kiyo_test_tmp=$(mktemp -d "${TMPDIR:-/tmp}/kiyo-test.XXXXXX")
trap 'rm -rf "$kiyo_test_tmp"' EXIT
swiftc -D KIYO_TESTING -module-cache-path "$kiyo_test_tmp/modules" Sources/main.swift Sources/PreferencesSync.swift Sources/SingleInstance.swift Sources/SelectionConversion.swift Sources/VisibleWord.swift Tests/TypingStress.swift Tests/SyncTests.swift Tests/LaunchTests.swift -o "$kiyo_test_tmp/KiyoTests" -framework ServiceManagement -framework AppKit -framework Carbon -framework ApplicationServices -target arm64-apple-macosx13.0
codesign --force --sign - "$kiyo_test_tmp/KiyoTests"
for kiyo_test in --launch-test --self-test --stress-test --sync-test; do
  "$kiyo_test_tmp/KiyoTests" "$kiyo_test"
done
