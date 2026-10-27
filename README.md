# Pomokaffee

Menu bar pomodoro for macOS. Apple icon with coffee steam; calm while you focus.

- **Focus**: optional macOS Focus (via Shortcuts) and Slack pause + status.
- **Last minute**: floating card, postpone +5 min then +10 min (max 2). Skipped during calls.
- **Rest**: full-screen blocker with an apple being eaten. Skip only by typing a long phrase (paste is rejected). Runs `cleanup-caches --deep` and your own commands.
- **Calls**: mic or camera running anywhere (Slack huddle, Meet, Teams, Zoom...) or Zoom's `CptHost` counts as a meeting. Rest waits until it ends, then gives a 60 s warning. Menu has a manual "I'm in a meeting" override.
- **Keep awake**: `caffeinate -disu` toggle.

## Run

    just run         # build and launch from build/
    just install     # copy to /Applications and launch
    just uninstall   # quit and remove (just purge also wipes settings and log)
    just install-hooks   # once per clone: gitleaks pre-commit scan (needs gitleaks)

`just --list` shows every recipe.

## Setup notes

- macOS Focus has no public API. Create two Shortcuts ("Pomokaffee Focus On" / "Pomokaffee Focus Off", each with a *Set Focus* action) and enable them in Settings.
- Slack: user token (`xoxp-`) with `dnd:write` and `users.profile:write`. Stored in UserDefaults (plain).
- Rest commands run through `zsh -ilc`, so PATH/aliases from `.zshrc` apply. Log: `~/Library/Logs/Pomokaffee.log`.
- Rest blocks the Dock, menu bar and app switching. Force Quit (Cmd-Opt-Esc) stays available as an escape hatch.
