app := "Pomokaffee"
bundle_id := "com.guilospanck.pomokaffee"
install_dir := env_var_or_default("POMOKAFFEE_INSTALL_DIR", "/Applications")

default:
	@just --justfile "{{justfile_directory()}}/.justfile" --list

# Checks the build prerequisites; read-only
doctor:
	#!/usr/bin/env bash
	set -u
	bad=0
	need() { if command -v "$1" >/dev/null 2>&1; then echo "ok       $1"; else echo "MISSING  $1  ($2)"; bad=1; fi; }
	need swift "xcode-select --install"
	need gitleaks "brew install gitleaks; the pre-commit hook needs it"
	[[ "$(git -C "{{justfile_directory()}}" config core.hooksPath)" == .githooks ]] && echo "ok       pre-commit hook" || echo "optional pre-commit hook  (just install-hooks)"
	exit $bad

# Debug build
build:
	swift build

# Release build wrapped in build/Pomokaffee.app (ad-hoc signed)
bundle:
	{{justfile_directory()}}/scripts/bundle.sh

# Builds and launches the app from build/ without installing it
run: bundle
	open "{{justfile_directory()}}/build/{{app}}.app"

# Builds, copies the app into /Applications (or POMOKAFFEE_INSTALL_DIR) and launches it
install: bundle
	#!/usr/bin/env bash
	set -euo pipefail
	pkill -x "{{app}}" 2>/dev/null || true
	rm -rf "{{install_dir}}/{{app}}.app"
	cp -R "{{justfile_directory()}}/build/{{app}}.app" "{{install_dir}}/"
	open "{{install_dir}}/{{app}}.app"
	echo "Installed {{install_dir}}/{{app}}.app"

# Tells you which Focus Shortcuts are still in the Shortcuts app. AppleScript `delete shortcut` does nothing (checked), so they must be removed by hand.
remove-shortcuts:
	#!/usr/bin/env bash
	for n in "Pomokaffee Focus On" "Pomokaffee Focus Off"; do
		shortcuts list | grep -qx "$n" && echo "Still installed: Shortcut '$n'. Delete it in the Shortcuts app (select it, press Cmd-Delete)."
	done
	true

# Quits the app and removes it; keeps settings and log (see purge)
uninstall:
	#!/usr/bin/env bash
	set -euo pipefail
	pkill -x "{{app}}" 2>/dev/null || true
	"{{install_dir}}/{{app}}.app/Contents/MacOS/{{app}}" --unregister-login 2>/dev/null || true
	rm -rf "{{install_dir}}/{{app}}.app"
	just --justfile "{{justfile_directory()}}/.justfile" remove-shortcuts
	echo "Removed {{install_dir}}/{{app}}.app (launch-at-login entry dropped)."

# Uninstall plus settings (including the Slack token) and the log
purge: uninstall
	#!/usr/bin/env bash
	set -euo pipefail
	defaults delete "{{bundle_id}}" 2>/dev/null || true
	security delete-generic-password -s "{{bundle_id}}" -a slackToken >/dev/null 2>&1 || true
	rm -f "$HOME/Library/Logs/{{app}}.log"
	echo "Removed settings and log"

# Removes build output
clean:
	rm -rf "{{justfile_directory()}}/.build" "{{justfile_directory()}}/build"

# Tails the app log (rest commands, call detection, errors); Ctrl-C to stop
logs:
	tail -f "$HOME/Library/Logs/{{app}}.log"

# Once per clone: enable the pre-commit secret/PII scan
install-hooks:
	sh "{{justfile_directory()}}/.githooks/install.sh"

# Lints the Homebrew cask CI will publish (style checks)
lint:
	#!/usr/bin/env bash
	set -euo pipefail
	command -v brew >/dev/null || { echo "install Homebrew to lint the cask: https://brew.sh" >&2; exit 1; }
	# Rendered under a Casks/ dir so `brew style` applies the cask cops.
	tmp="$(mktemp -d)"
	trap 'rm -rf -- "$tmp"' EXIT
	mkdir -p "$tmp/Casks"
	"{{justfile_directory()}}/scripts/render-cask.sh" 0.0.0 "$(printf '%064d' 0)" > "$tmp/Casks/pomokaffee.rb"
	prefix="$(brew --prefix)"
	library="$prefix/Library/Homebrew"
	if [[ -d "$library" && "$(cd "$library" && pwd -P)" == /nix/store/* ]]; then
		# Nix's Homebrew is immutable and lint gems install inside it: run a writable copy.
		source_repo="$(cd -P "$library" && cd ../.. && pwd -P)"
		mkdir -p "$tmp/brew"
		cp -R "$source_repo/." "$tmp/brew/"
		chmod -R u+w "$tmp/brew"
		HOMEBREW_PREFIX="$prefix" HOMEBREW_REPOSITORY="$tmp/brew" HOMEBREW_LIBRARY="$tmp/brew/Library" \
		HOMEBREW_BREW_FILE="$(command -v brew)" HOMEBREW_USER_CONFIG_HOME="$tmp/brew/config" \
		HOMEBREW_DEVELOPER=1 HOMEBREW_NO_AUTO_UPDATE=1 \
			/bin/bash "$tmp/brew/Library/Homebrew/brew.sh" style "$tmp/Casks/pomokaffee.rb"
	else
		brew style "$tmp/Casks/pomokaffee.rb"
	fi
	echo "cask lint clean"

# Tags and pushes vX.Y[.Z], which triggers the Release workflow. Usage: just tag 1.1 ["notes"]
tag version $notes="":
	#!/usr/bin/env bash
	set -euo pipefail
	ver="{{version}}"
	[[ "$ver" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "version must look like 1.1 or 1.1.0 (got '$ver')" >&2; exit 1; }
	[[ -z "$(git status --porcelain)" ]] || { echo "working tree not clean" >&2; exit 1; }
	! git rev-parse "v$ver" >/dev/null 2>&1 || { echo "tag v$ver already exists" >&2; exit 1; }
	VERSION="$ver" just --justfile "{{justfile_directory()}}/.justfile" bundle
	just --justfile "{{justfile_directory()}}/.justfile" lint
	if [[ -n "${notes//[[:space:]]/}" ]]; then
		git tag -a "v$ver" --cleanup=verbatim -m "$notes"
	else
		git tag "v$ver"
	fi
	git push origin HEAD
	git push origin "v$ver"
	echo "Pushed v$ver; CI builds, releases and updates the tap."

# One-time: deploy key for the tap, private half stored as a secret in this repo so CI can push the cask
setup-tap-key:
	#!/usr/bin/env bash
	set -euo pipefail
	title="pomokaffee release CI"
	tap=Guilospanck/homebrew-tap
	old_ids="$(gh repo deploy-key list -R "$tap" --json id,title --jq ".[] | select(.title == \"$title\") | .id")"
	umask 077
	tmp="$(mktemp -d)"
	trap 'rm -rf -- "$tmp"' EXIT
	ssh-keygen -t ed25519 -N "" -C "$title" -f "$tmp/key" >/dev/null
	gh repo deploy-key add "$tmp/key.pub" -R "$tap" --title "$title" --allow-write
	gh secret set HOMEBREW_TAP_DEPLOY_KEY -R Guilospanck/pomokaffee < "$tmp/key"
	for id in $old_ids; do gh repo deploy-key delete "$id" -R "$tap" && echo "Removed earlier deploy key $id."; done
	echo "Deploy key added to homebrew-tap (write) and stored as HOMEBREW_TAP_DEPLOY_KEY."
