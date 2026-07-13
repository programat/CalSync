#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="CalSync"
CONFIGURATION="${CONFIGURATION:-debug}"
SWIFT_BIN="${SWIFT:-swift}"
SWIFT_PACKAGE_FLAGS="${SWIFT_PACKAGE_FLAGS:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST_SOURCE="$ROOT_DIR/Config/Info.plist"
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST_SOURCE")"
LOGGER_SUBSYSTEM="CalSync"
DIST_DIR="$ROOT_DIR/dist"
STAGED_APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
STAGED_APP_CONTENTS="$STAGED_APP_BUNDLE/Contents"
STAGED_APP_MACOS="$STAGED_APP_CONTENTS/MacOS"
STAGED_APP_RESOURCES="$STAGED_APP_CONTENTS/Resources"
STAGED_APP_BINARY="$STAGED_APP_MACOS/$APP_NAME"
INFO_PLIST="$STAGED_APP_CONTENTS/Info.plist"
ENTITLEMENTS="$ROOT_DIR/CalSync/CalSync.entitlements"
PKG_INFO="$STAGED_APP_CONTENTS/PkgInfo"
INSTALL_DIR="${CALSYNC_INSTALL_DIR:-$HOME/Applications}"
INSTALLED_APP_BUNDLE="$INSTALL_DIR/$APP_NAME.app"
INSTALLED_APP_BINARY="$INSTALLED_APP_BUNDLE/Contents/MacOS/$APP_NAME"

swift_command() {
  local arguments=("$@")
  local package_flags=()

  if [ -n "$SWIFT_PACKAGE_FLAGS" ]; then
    # Makefile passes simple SwiftPM flags such as --disable-sandbox.
    read -r -a package_flags <<<"$SWIFT_PACKAGE_FLAGS"
    "$SWIFT_BIN" "${arguments[0]}" "${package_flags[@]}" "${arguments[@]:1}"
  else
    "$SWIFT_BIN" "${arguments[0]}" "${arguments[@]:1}"
  fi
}

sign_staged_app_bundle() {
  local requirements="=designated => identifier \"$BUNDLE_ID\""

  codesign \
    --force \
    --sign - \
    --entitlements "$ENTITLEMENTS" \
    --requirements "$requirements" \
    --timestamp=none \
    "$STAGED_APP_BUNDLE" >/dev/null
}

verify_staged_app_bundle() {
  local signed_entitlements

  plutil -lint "$INFO_PLIST" >/dev/null
  codesign --verify --deep --strict "$STAGED_APP_BUNDLE"
  signed_entitlements="$(codesign -d --entitlements - "$STAGED_APP_BUNDLE" 2>&1)"

  test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")" = "$BUNDLE_ID"
  test "$(/usr/libexec/PlistBuddy -c 'Print :NSCalendarsFullAccessUsageDescription' "$INFO_PLIST")" != ""
  [[ "$signed_entitlements" == *"com.apple.security.app-sandbox"* ]]
  [[ "$signed_entitlements" == *"com.apple.security.personal-information.calendars"* ]]
  test -x "$STAGED_APP_BINARY"
}

stage_app_bundle() {
  local build_bin_dir
  local build_binary

  swift_command build --configuration "$CONFIGURATION" >&2
  build_bin_dir="$(swift_command build --configuration "$CONFIGURATION" --show-bin-path)"
  build_binary="$build_bin_dir/$APP_NAME"

  rm -rf "$STAGED_APP_BUNDLE"
  mkdir -p "$STAGED_APP_MACOS" "$STAGED_APP_RESOURCES"
  ditto "$build_binary" "$STAGED_APP_BINARY"
  chmod +x "$STAGED_APP_BINARY"
  ditto "$INFO_PLIST_SOURCE" "$INFO_PLIST"
  printf 'APPL????' >"$PKG_INFO"

  sign_staged_app_bundle
  verify_staged_app_bundle
}

install_app_bundle() {
  pkill -x "$APP_NAME" >/dev/null 2>&1 || true
  mkdir -p "$INSTALL_DIR"
  rm -rf "$INSTALLED_APP_BUNDLE"
  ditto "$STAGED_APP_BUNDLE" "$INSTALLED_APP_BUNDLE"
}

open_app() {
  /usr/bin/open -n "$INSTALLED_APP_BUNDLE"
}

stage_app_bundle

case "$MODE" in
  bundle)
    printf '%s\n' "$STAGED_APP_BUNDLE"
    ;;
  run)
    install_app_bundle
    open_app
    ;;
  debug)
    install_app_bundle
    lldb -- "$INSTALLED_APP_BINARY"
    ;;
  logs)
    install_app_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  telemetry)
    install_app_bundle
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$LOGGER_SUBSYSTEM\""
    ;;
  *)
    echo "usage: $0 [bundle|run|debug|logs|telemetry]" >&2
    exit 2
    ;;
esac
