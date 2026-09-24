#!/bin/zsh
set -euo pipefail

archive_path="${1:-Platform-macOS.zip}"
expected_version="${2:-}"
expected_build="${3:-}"

if [[ ! -f "$archive_path" ]]; then
  echo "Release archive not found: $archive_path"
  exit 1
fi

verification_dir=$(mktemp -d /tmp/platform-release-verification.XXXXXX)
trap 'rm -rf "$verification_dir"' EXIT
ditto -x -k "$archive_path" "$verification_dir"

app_path="$verification_dir/Platform.app"
plist_path="$app_path/Contents/Info.plist"
binary_path="$app_path/Contents/MacOS/Platform"
icon_path="$app_path/Contents/Resources/Platform.icns"
font_license_path="$app_path/Contents/Resources/OFL-1.1.txt"
third_party_notices_path="$app_path/Contents/Resources/THIRD_PARTY_NOTICES.md"

[[ -d "$app_path" ]]
[[ -f "$plist_path" ]]
[[ -x "$binary_path" ]]
[[ -s "$icon_path" ]]
[[ -s "$font_license_path" ]]
[[ -s "$third_party_notices_path" ]]

plutil -lint "$plist_path" >/dev/null
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist_path")
build=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist_path")
minimum_system=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$plist_path")
api_url=$(/usr/libexec/PlistBuddy -c "Print :PlatformAPIBaseURL" "$plist_path")
bundle_icon=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIconFile" "$plist_path")
agent_app=$(/usr/libexec/PlistBuddy -c "Print :LSUIElement" "$plist_path")
feed_url=$(/usr/libexec/PlistBuddy -c "Print :SUFeedURL" "$plist_path")
public_key=$(/usr/libexec/PlistBuddy -c "Print :SUPublicEDKey" "$plist_path")

[[ -z "$expected_version" || "$version" == "$expected_version" ]]
[[ -z "$expected_build" || "$build" == "$expected_build" ]]
[[ "$minimum_system" == "14.0" ]]
[[ "$api_url" == https://* ]]
[[ "$bundle_icon" == "Platform.icns" ]]
[[ "$agent_app" == "true" ]]
[[ "$feed_url" == "https://github.com/OI1ver/Platform/releases/latest/download/appcast.xml" ]]
[[ -n "$public_key" && "$public_key" != "REPLACE_WITH_SPARKLE_PUBLIC_KEY" ]]

menu_icon=$(find "$app_path/Contents/Resources" -name 'PlatformBarIcon.png' -print -quit)
[[ -n "$menu_icon" && -s "$menu_icon" ]]

for architecture in arm64 x86_64; do
  lipo -verify_arch "$architecture" "$binary_path"
  binary_minimum=$(vtool -arch "$architecture" -show-build "$binary_path" | awk '/minos/ { print $2; exit }')
  [[ "$binary_minimum" == "14.0" ]]
done

codesign --verify --deep --strict "$app_path"

top_levels=$(zipinfo -1 "$archive_path" | awk -F/ 'NF { print $1 }' | sort -u)
[[ "$top_levels" == "Platform.app" ]]
if zipinfo -1 "$archive_path" | grep -Eq '(^|/)(__MACOSX|\._)'; then
  echo "Release archive contains Finder metadata."
  exit 1
fi

echo "Verified Platform $version ($build): universal, macOS 14+, ad-hoc signed, icon bundled."
