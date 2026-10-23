#!/bin/zsh
set -eu
umask 077
cd "${0:A:h}/.."
kiyo_package_tmp=$(mktemp -d ${TMPDIR:-/tmp}/kiyo-package.XXXXXX)
kiyo_mounted=0
cleanup() {
  if [[ "$kiyo_mounted" == 1 ]]; then hdiutil detach "$kiyo_package_tmp/volume" >/dev/null || true; fi
  rm -rf "$kiyo_package_tmp"
}
trap cleanup EXIT
mkdir -p "$kiyo_package_tmp/stage"
ditto dist/Kiyo.app "$kiyo_package_tmp/stage/Kiyo.app"
ln -s /Applications "$kiyo_package_tmp/stage/Applications"
cp Docs/INSTALLATION.txt "$kiyo_package_tmp/stage/Read Me - Installation.txt"
hdiutil create -volname KiYo -srcfolder "$kiyo_package_tmp/stage" -format UDRW "$kiyo_package_tmp/image.dmg" >/dev/null
hdiutil attach "$kiyo_package_tmp/image.dmg" -nobrowse -mountpoint "$kiyo_package_tmp/volume" >/dev/null
kiyo_mounted=1
cp Resources/AppIcon.icns "$kiyo_package_tmp/volume/.VolumeIcon.icns"
xcrun SetFile -a C "$kiyo_package_tmp/volume"
codesign --verify --deep --strict "$kiyo_package_tmp/volume/Kiyo.app"
hdiutil detach "$kiyo_package_tmp/volume" >/dev/null
kiyo_mounted=0
hdiutil convert "$kiyo_package_tmp/image.dmg" -format UDZO -ov -o dist/KiYo.dmg >/dev/null
hdiutil verify dist/KiYo.dmg >/dev/null
swift -module-cache-path "$kiyo_package_tmp/modules" scripts/set-file-icon.swift "$PWD/Resources/AppIcon.icns" "$PWD/dist/KiYo.dmg"
print 'KiYo.dmg ready'
