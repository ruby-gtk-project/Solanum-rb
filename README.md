# Solanum-rb

A Ruby GTK4 / Libadwaita port of [Solanum](https://apps.gnome.org/Solanum), the
GNOME pomodoro timer. Work in sessions, with a short break between each and a
long break after the fourth.

Feature parity with the Rust original: the timer with pause and resume, skip
and reset, the lap counter, the session-length preferences, fullscreen breaks,
the beep and the chime, the lap-change notification with its two buttons, the
keyboard shortcuts and about windows, and the large-text breakpoint.

## Running

```sh
nix develop        # or: direnv allow
rake schema        # compile the GSettings schema into build/
bin/solanum-rb
```

`nix build` produces the installable app; `nix run` starts it.

## Development

`rake` runs the tests and rubocop. `PORTING.md` maps this port onto the Rust
original and records the binding defects worked around along the way.

Upstream lives on the `main` branch of this fork.

## Licence

GPL-3.0-or-later, as upstream. See `LICENSE.md`.
