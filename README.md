# Dash

Installers for Dash, the OpenLoop Agentics startup finance app.

Install or update on macOS (Apple Silicon) or Linux (x64 and arm64):

```sh
curl -fsSL https://raw.githubusercontent.com/openloopagentics/dash-releases/main/install.sh | sh
```

On macOS the app goes to `/Applications/Dash.app`. On Linux the script installs the pacman package on Arch/Omarchy, the Debian package where `apt` is available, and otherwise the AppImage in `~/.local/bin/dash-desktop`. Downloads are checked against the release's `SHA256SUMS`.

Set `DASH_VERSION=0.1.1` to install a specific release. Individual installers are on the [releases page](https://github.com/openloopagentics/dash-releases/releases).
