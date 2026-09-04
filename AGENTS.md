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

- `bin/solanum-rb` runs the app. `SOLANUM_RB_PROFILE=development` gives the
  devel build — own app id and icon, striped header, commit-stamped version.
- `rake` runs the checks, the validation and rubocop.
  - `rake schema` compiles `data/org.gnome.Solanum.Rb.gschema.xml` into
    `build/`, which the dev shell puts on `XDG_DATA_DIRS`. Nothing that touches
    settings works until this has run; `rake test` depends on it.
  - `rake desktop` regenerates the desktop entry and metainfo from `po/`, for
    both profiles. They are build outputs, not tracked — the nix build makes
    its own. The about dialog reads the metainfo back at runtime.
  - `rake validate` runs the three checks upstream runs from meson:
    `glib-compile-schemas --strict`, `desktop-file-validate` and
    `appstreamcli validate`.
  - `test/test_units.rb` needs no display: the countdown arithmetic, the PO
    catalogue, the build profile, the appdata reader, the generated data files
    and the stylesheet.
  - `test/drive_solanum.rb` builds the real window headlessly, drives every
    state and every dialog, and writes screenshots to `tmp/shots`.
    `test/drive_devel.rb` does the same for the devel profile, which needs its
    own process because the profile is read before the application id is built.
- `nix build` produces the installable app, `nix build .#devel` the devel one.

`PORTING.md` records how this port maps onto the Rust original and the
ruby-gnome and GTK defects found while writing it — read it before changing the
timer, the stylesheet or the shortcuts dialog.

## Style

`.rubocop.yml` plus the custom cops in `cops/` are enforced: no `return`, no
modifier `if`, no conditional assignment, `tap` where it applies, and fixed
multi-line argument/hash layout. Run `bundle exec rubocop` before committing.
