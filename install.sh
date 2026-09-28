#!/bin/sh
# Install or update Dash from the public release repository.
#
#   curl -fsSL https://raw.githubusercontent.com/openloopagentics/dash-releases/main/install.sh | sh
#
# DASH_VERSION=0.1.1 pins a release; DASH_NO_LAUNCH=1 skips opening the app on macOS.
# The whole script is inside main so a partially downloaded copy never runs.

main() {
  set -eu
  repo=openloopagentics/dash-releases
  version=${DASH_VERSION:-latest}
  if [ "$version" = latest ]; then
    base="https://github.com/$repo/releases/latest/download"
  else
    base="https://github.com/$repo/releases/download/v${version#v}"
  fi

  need curl
  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT INT TERM
  # apt reads the package as its sandbox user, so the download must be readable
  chmod 755 "$tmp"

  case "$(uname -s)" in
    Darwin) install_mac ;;
    Linux) install_linux ;;
    *) fail "unsupported operating system $(uname -s)" ;;
  esac
}

say() { printf '%s\n' "$*" >&2; }
fail() { say "dash install: $*"; exit 1; }
need() { command -v "$1" >/dev/null 2>&1 || fail "$1 is required"; }

as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else need sudo; sudo "$@"; fi
}

fetch() {
  say "Downloading $1"
  curl -fL --progress-bar -o "$tmp/$1" "$base/$1" || fail "could not download $base/$1"
  chmod 644 "$tmp/$1"
  verify "$1"
}

verify() {
  [ -f "$tmp/SHA256SUMS" ] || curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || fail "could not download checksums"
  expected=$(awk -v f="$1" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS")
  [ -n "$expected" ] || fail "no checksum published for $1"
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$tmp/$1" | awk '{ print $1 }')
  else
    actual=$(shasum -a 256 "$tmp/$1" | awk '{ print $1 }')
  fi
  [ "$actual" = "$expected" ] || fail "checksum mismatch for $1"
}

install_mac() {
  [ "$(uname -m)" = arm64 ] || fail "Dash is built for Apple Silicon Macs only"
  fetch Dash-mac-arm64.zip
  ditto -x -k "$tmp/Dash-mac-arm64.zip" "$tmp/app"
  # Builds are not signed with a Developer ID yet; an ad-hoc signature lets Apple Silicon run them.
  codesign --force --deep --sign - "$tmp/app/Dash.app" >/dev/null 2>&1 || fail "could not sign Dash.app"

  dest=/Applications
  [ -w "$dest" ] || dest="$HOME/Applications"
  mkdir -p "$dest"
  if pgrep -f "Dash.app/Contents/MacOS/" >/dev/null 2>&1; then
    say "Quitting the running Dash"
    osascript -e 'tell application id "com.openloopagentics.dash" to quit' >/dev/null 2>&1 || true
    sleep 2
  fi
  rm -rf "$dest/Dash.app"
  ditto "$tmp/app/Dash.app" "$dest/Dash.app"
  xattr -dr com.apple.quarantine "$dest/Dash.app" 2>/dev/null || true
  say "Installed Dash $(defaults read "$dest/Dash.app/Contents/Info" CFBundleShortVersionString) to $dest/Dash.app"
  [ -n "${DASH_NO_LAUNCH:-}" ] || open "$dest/Dash.app"
}

install_linux() {
  case "$(uname -m)" in
    x86_64 | amd64) arch=x64 ;;
    aarch64 | arm64) arch=arm64 ;;
    *) fail "unsupported architecture $(uname -m)" ;;
  esac

  if command -v pacman >/dev/null 2>&1; then
    fetch "Dash-linux-$arch.pacman"
    # The package used to be called openloop-dash; data stays in place when it is replaced.
    if pacman -Q openloop-dash >/dev/null 2>&1; then as_root pacman -R --noconfirm openloop-dash; fi
    as_root pacman -U --noconfirm "$tmp/Dash-linux-$arch.pacman"
  elif command -v apt-get >/dev/null 2>&1; then
    fetch "Dash-linux-$arch.deb"
    as_root apt-get install -y "$tmp/Dash-linux-$arch.deb"
  else
    fetch "Dash-linux-$arch.AppImage"
    mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
    install -m 755 "$tmp/Dash-linux-$arch.AppImage" "$HOME/.local/bin/dash-desktop"
    cat >"$HOME/.local/share/applications/dash.desktop" <<EOF
[Desktop Entry]
Name=Dash
Comment=Startup finances and connected business data
Exec=$HOME/.local/bin/dash-desktop %U
Terminal=false
Type=Application
Categories=Development;
StartupWMClass=dash
EOF
    say "The AppImage needs FUSE 2 (libfuse2) to run."
  fi
  say "Installed Dash. Open it from your launcher or run dash-desktop."
}

main "$@"
