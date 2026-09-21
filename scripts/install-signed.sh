#!/usr/bin/env bash
# Installs GitLabBar into /Applications signed with a real code-signing
# certificate, then relaunches it.
#
# Why: ad-hoc builds (Homebrew, plain xcodebuild) get a new code hash on every
# build, so macOS treats each one as a different app and asks for the login
# keychain password again. A certificate-signed app is identified by bundle ID
# + certificate instead, so one "Always Allow" survives every rebuild.
#
# Usage:
#   scripts/install-signed.sh          build from this checkout, then install
#   scripts/install-signed.sh --brew   install the app `brew upgrade` just built
#
# SIGN_ID=<sha1|name> overrides the auto-detected certificate.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dest="/Applications/GitLabBar.app"

# Prefer Developer ID, then Apple Development. Revoked certificates still show
# up in find-identity output (with a CSSMERR_TP_CERT_REVOKED suffix), so skip them.
detect_identity() {
  local ids
  ids="$(security find-identity -v -p codesigning | grep -v REVOKED || true)"
  for kind in "Developer ID Application" "Apple Development"; do
    local hash
    hash="$(grep "\"$kind:" <<<"$ids" | head -1 | awk '{print $2}')"
    if [[ -n "$hash" ]]; then echo "$hash"; return; fi
  done
}

sign_id="${SIGN_ID:-$(detect_identity)}"
if [[ -z "$sign_id" ]]; then
  echo "No usable signing certificate found (need Developer ID Application or Apple Development)." >&2
  echo "Create one in Xcode → Settings → Accounts → Manage Certificates, or pass SIGN_ID=..." >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

if [[ "${1:-}" == "--brew" ]]; then
  src="$(brew --prefix gitlab-bar)/GitLabBar.app"
  [[ -d "$src" ]] || { echo "Homebrew GitLabBar not found at $src — run: brew install gitlab-bar" >&2; exit 1; }
  echo "Using Homebrew build: $src"
else
  command -v xcodegen >/dev/null || { echo "xcodegen not found: brew install xcodegen" >&2; exit 1; }
  echo "Building from $repo_root ..."
  (
    cd "$repo_root/GitLabBar"
    xcodegen generate --quiet
    xcodebuild -project GitLabBar.xcodeproj -scheme GitLabBar -configuration Release \
      -derivedDataPath "$work/derived" CONFIGURATION_BUILD_DIR="$work/out" \
      CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO \
      -quiet build
  )
  src="$work/out/GitLabBar.app"
fi

# Quit the running copy so its binary can be replaced.
if pgrep -x GitLabBar >/dev/null; then
  osascript -e 'quit app "GitLabBar"' >/dev/null 2>&1 || true
  for _ in {1..10}; do pgrep -x GitLabBar >/dev/null || break; sleep 0.5; done
  pkill -x GitLabBar 2>/dev/null || true
fi

rm -rf "$dest"
ditto "$src" "$dest"
codesign --force --deep --timestamp=none --sign "$sign_id" "$dest"
codesign --verify --strict "$dest"

version="$(plutil -extract CFBundleShortVersionString raw "$dest/Contents/Info.plist")"
echo "Installed GitLabBar $version signed with $sign_id"
open "$dest"
