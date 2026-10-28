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
