# Solanum — Ruby port

The Ruby GTK4 / Libadwaita port of Solanum, a pomodoro timer. The upstream
Rust implementation lives on the fork's other branches (`main`); this branch is
the port.

## Skills — use them

Two skills are installed in `.claude/skills/`. They are not optional reading.

- **ruby-gtk** — the house style for Ruby GTK4/Libadwaita: the declarative
  memoized-widget pattern, Adwaita binding quirks, worked examples. Load it
  before writing or reviewing ANY Ruby GTK code, including single widgets, and
  before planning a port. The bindings are quirky enough that code written from
  memory is unreliable.
- **ruby-gtk-testing** — run the app headlessly and drive its UI: click through
  dialogs, assert widget state, capture screenshots. Use it before claiming any
  GTK change works. `ruby -c` and a successful `require` prove nothing about a
  UI.

## Running and testing

`direnv allow` (or `nix develop`) gets Ruby, GTK4, Libadwaita, GStreamer,
librsvg and the bundled gems from `gemset.nix`. Regenerate that file with
`bundix -l` whenever `Gemfile.lock` moves; nix only sees git-tracked files, so
`git add` it first.

- `bin/solanum-rb` runs the app.
- `rake` runs the checks and rubocop.
  - `rake schema` compiles `data/org.gnome.Solanum.Rb.gschema.xml` into
    `build/`, which the dev shell puts on `XDG_DATA_DIRS`. Nothing that touches
    settings works until this has run; `rake test` depends on it.
  - `test/test_units.rb` needs no display: the countdown arithmetic, the PO
    catalogue and the stylesheet.
  - `test/drive_solanum.rb` builds the real window headlessly, drives every
    state and every dialog, and writes screenshots to `tmp/shots`.
- `nix build` produces the installable app.

`PORTING.md` records how this port maps onto the Rust original and the
ruby-gnome and GTK defects found while writing it — read it before changing the
timer, the stylesheet or the shortcuts dialog.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.
