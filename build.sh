#!/bin/zsh
set -eu
cd "${0:A:h}"
umask 077
kiyo_build_tmp=$(mktemp -d "${TMPDIR:-/tmp}/kiyo-build.XXXXXX")
trap 'rm -rf "$kiyo_build_tmp"' EXIT
kiyo_app="$kiyo_build_tmp/Kiyo.app"
mkdir -p "$kiyo_app/Contents/MacOS" "$kiyo_app/Contents/Resources" dist
swiftc -O -module-cache-path "$kiyo_build_tmp/modules" Sources/main.swift Sources/PreferencesSync.swift Sources/SingleInstance.swift Sources/SelectionConversion.swift Sources/VisibleWord.swift -o "$kiyo_app/Contents/MacOS/KiyoSwitchet" -framework ServiceManagement -framework AppKit -framework Carbon -framework ApplicationServices -target arm64-apple-macosx13.0
cp Resources/Info.plist "$kiyo_app/Contents/Info.plist"
cp Resources/AppIcon.icns Resources/LogoTemplate.png Resources/PrivacyInfo.xcprivacy "$kiyo_app/Contents/Resources/"
cp -R Resources/ru.lproj Resources/en.lproj "$kiyo_app/Contents/Resources/"
if [[ -n "${KIYO_SIGNING_IDENTITY:-}" ]]; then
  codesign --force --options runtime --timestamp --sign "$KIYO_SIGNING_IDENTITY" "$kiyo_app"
else
  codesign --force --options runtime --sign - "$kiyo_app"
  print 'Development build: ad-hoc signed, not notarized. Do not replace an installed official release with this build.'
fi
codesign --verify --deep --strict "$kiyo_app"
# Replace only generated output after compilation and signing have succeeded.
rm -rf dist/Kiyo.app
ditto "$kiyo_app" dist/Kiyo.app
print 'Built dist/Kiyo.app'
