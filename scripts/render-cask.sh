#!/usr/bin/env bash
# Render the Homebrew cask for a given version + sha256 to stdout.
#
# Single source of truth for the cask, used by both:
#   - `just lint`      renders with a placeholder sha and lints locally.
#   - Release workflow renders with the real sha and publishes to the tap.
#
# $version / $sha256 are expanded here; #{version} is left intact for
# Homebrew's own Ruby interpolation, and {{appdir}} is an install-steps
# template token Homebrew expands at install time.
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <version> <sha256>" >&2
    exit 2
fi

version="$1"
sha256="$2"

cat <<RUBY
cask "pomokaffee" do
  version "${version}"
  sha256 "${sha256}"

  url "https://github.com/Guilospanck/pomokaffee/releases/download/v#{version}/Pomokaffee-#{version}.zip"
  name "Pomokaffee"
  desc "Menu-bar Pomodoro timer that quiets Slack and Focus and keeps the machine awake"
  homepage "https://github.com/Guilospanck/pomokaffee"

  depends_on macos: :sonoma

  app "Pomokaffee.app"

  # App is ad-hoc signed (not notarized): clear the download quarantine
  # so Gatekeeper lets it launch.
  postflight_steps do
    run "/usr/bin/xattr",
        args: ["-dr", "com.apple.quarantine", "{{appdir}}/Pomokaffee.app"]
  end

  zap trash: [
    "~/Library/Logs/Pomokaffee.log",
    "~/Library/Preferences/com.guilospanck.pomokaffee.plist",
  ]
end
RUBY
