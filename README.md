<p align="center"><img src="assets/icon.png" alt="Pomokaffee icon" width="128" height="128"></p>

<h1 align="center">Pomokaffee</h1>

Menu bar pomodoro for macOS. Apple icon with coffee steam; calm while you focus.

- **Focus**: optional macOS Focus (via Shortcuts) and Slack pause + status.
- **Last minute**: floating card, postpone +5 min then +10 min (max 2). Skipped during calls.
- **Rest**: full-screen blocker with an apple being eaten. Skip only by typing a long phrase (paste is rejected). Runs the rest commands you add in Settings.
- **Calls**: mic or camera running anywhere (Slack huddle, Meet, Teams, Zoom...) or Zoom's `CptHost` counts as a meeting. Rest waits until it ends, then gives a 60 s warning. Menu has a manual "I'm in a meeting" override.
- **Keep awake**: menu toggle. Runs the one keep-alive command selected in Settings (default `caffeinate -disu`); disabled if none is selected.

## Install

    brew install --cask guilospanck/tap/pomokaffee

The cask installs the prebuilt app into `/Applications` and clears the download quarantine (the app is ad-hoc signed, not notarized). Upgrade with `brew upgrade --cask pomokaffee`, remove with `brew uninstall --cask pomokaffee` (turn off Launch at Login first).

## Run

    just run         # build and launch from build/
    just install     # copy to /Applications and launch
    just uninstall   # quit and remove (just purge also wipes settings and log)
    just install-hooks   # once per clone: gitleaks pre-commit scan (needs gitleaks)

`just --list` shows every recipe.

## Setup notes

- macOS Focus has no public API. Turning on "Run macOS Shortcuts" in Settings opens the bundled "Pomokaffee Focus On/Off" Shortcuts (also in `shortcuts/`); click *Add Shortcut* in each dialog. macOS does not allow a silent import.
- Slack: user token (`xoxp-`) with `dnd:write` and `users.profile:write`. Stored in the macOS Keychain.
- Rest and keep-alive commands run through `zsh -ilc`, so PATH/aliases from `.zshrc` apply. Log: `~/Library/Logs/Pomokaffee.log`.
- Rest blocks the Dock, menu bar and app switching. Force Quit (Cmd-Opt-Esc) stays available as an escape hatch.

## Releasing

One-time: `just setup-tap-key` (needs `gh`). Then `just tag 1.1 ["notes"]` lints the cask, pushes tag `v1.1`, and the Release workflow builds the zip, creates the GitHub Release and updates `Casks/pomokaffee.rb` in `Guilospanck/homebrew-tap`.
