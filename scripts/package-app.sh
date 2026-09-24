#!/bin/zsh
set -euo pipefail

repo_root="${0:A:h:h}"
configuration="${CONFIGURATION:-release}"
requested_version="${PLATFORM_VERSION:-}"
requested_build="${PLATFORM_BUILD:-}"
source "$repo_root/release/version.env"
if [[ -n "$requested_version" ]]; then
  PLATFORM_VERSION="$requested_version"
fi
if [[ -n "$requested_build" ]]; then
  PLATFORM_BUILD="$requested_build"
fi
staging_dir=$(mktemp -d /tmp/platform-package.XXXXXX)
app_path="$staging_dir/Platform.app"
archive_path="$staging_dir/Platform-macOS.zip"
build_args=(-c "$configuration")
if [[ "${PLATFORM_UNIVERSAL:-0}" == "1" ]]; then
  build_args+=(--arch arm64 --arch x86_64)
fi

cd "$repo_root"
swift build "${build_args[@]}"
bin_path=$(swift build "${build_args[@]}" --show-bin-path)
binary_path="$bin_path/Platform"

mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources" "$app_path/Contents/Frameworks"
cp "$binary_path" "$app_path/Contents/MacOS/Platform"
cp "$repo_root/release/Info.plist" "$app_path/Contents/Info.plist"
cp "$repo_root/LICENSE" "$app_path/Contents/Resources/Platform-LICENSE.txt"
cp "$repo_root/THIRD_PARTY_NOTICES.md" "$app_path/Contents/Resources/THIRD_PARTY_NOTICES.md"
cp "$repo_root/LICENSES/OFL-1.1.txt" "$app_path/Contents/Resources/OFL-1.1.txt"

icon_source="$repo_root/Sources/PlatformApp/Resources/Artwork/PlatformIcon.png"
iconset_path="$staging_dir/Platform.iconset"
if [[ ! -f "$icon_source" ]]; then
  echo "Platform app icon source was not found."
  exit 1
fi
mkdir -p "$iconset_path"
for specification in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"; do
  size="${specification%% *}"
  filename="${specification#* }"
  sips -z "$size" "$size" "$icon_source" --out "$iconset_path/$filename" >/dev/null
done
iconutil -c icns "$iconset_path" -o "$app_path/Contents/Resources/Platform.icns"

resource_bundle="$bin_path/Platform_PlatformApp.bundle"
if [[ -d "$resource_bundle" ]]; then
  cp -R "$resource_bundle" "$app_path/Contents/Resources/"
fi

sparkle_framework="$repo_root/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
if [[ ! -d "$sparkle_framework" ]]; then
  echo "Sparkle.framework was not found in SwiftPM artifacts."
  exit 1
fi
cp -R "$sparkle_framework" "$app_path/Contents/Frameworks/"
install_name_tool -add_rpath '@executable_path/../Frameworks' "$app_path/Contents/MacOS/Platform"

if [[ -n "${PLATFORM_GITHUB_REPOSITORY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUFeedURL https://github.com/$PLATFORM_GITHUB_REPOSITORY/releases/latest/download/appcast.xml" "$app_path/Contents/Info.plist"
fi
if [[ -n "${PLATFORM_API_BASE_URL:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :PlatformAPIBaseURL $PLATFORM_API_BASE_URL" "$app_path/Contents/Info.plist"
fi
if [[ -n "${SPARKLE_PUBLIC_KEY:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $SPARKLE_PUBLIC_KEY" "$app_path/Contents/Info.plist"
fi
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $PLATFORM_VERSION" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $PLATFORM_BUILD" "$app_path/Contents/Info.plist"

xattr -cr "$app_path"
find "$app_path" -name '._*' -delete
codesign --force --deep --sign - "$app_path"
codesign --verify --deep --strict "$app_path"
ditto -c -k --norsrc --keepParent "$app_path" "$archive_path"
cp "$archive_path" "$repo_root/Platform-macOS.zip"
rm -rf "$staging_dir"
echo "Packaged $repo_root/Platform-macOS.zip"
