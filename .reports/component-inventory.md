# Component inventory — Solanum upstream vs. `ruby` port

Surveyed against `origin/main` (Rust/libadwaita, GResource-based) with the
`component-identification` skill. Solanum is a small app — one window, one
preferences surface, one shortcuts surface, one about dialog, plus the
application shell — so the whole app is one unit rather than a sliced survey.

Upstream has **no `.ui` files**: `window.blp` and `preferences-window.blp` are
blueprint sources compiled to `.ui` at build time and loaded from a
GResource; `help-overlay.blp` likewise. These three blueprints are read
alongside their Rust subclass for each component below, per the
component-identification skill's "one component is often two upstream files"
rule.

## Legend

- **Kind**: `window` / `dialog` / `widget-class` / `data` (schema, resource
  manifest, catalogue)
- **Exists**: whether `ruby` branch `lib/` already has the mapped file, and
  whether its content covers the upstream component

---

## 1. Application shell — `SolanumApplication`

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/app.rs`, `src/main.rs` | `lib/solanum_rb/application.rb` | application | **Yes** — startup/activate, icon theme registration, stylesheet loading, `app.about`/`app.preferences`/`app.quit`/`app.toggle-timer`/`app.skip` actions, `<Primary>comma`/`<Primary>q`/`<Primary>question` accelerators all present |
| `src/config.rs` | `lib/solanum_rb/config.rb` | data | **Yes** — `APP_ID`, `COPYRIGHT`, `VERSION`, profile/devel suffix all ported; `PKGDATADIR`/`LOCALEDIR` mapped to `Paths` since there is no GResource |
| `src/i18n.rs` | `lib/solanum_rb/i18n.rb` | data | **Yes** — `i18n`/`ni18n`/`pi18n`/`pni18n` family and the `{}`/`{key}` interpolation helpers ported, including the test-covered formatting behaviour |

**Component detail** — `SolanumApplication` (app.rs):

| Item | Upstream | Port |
|---|---|---|
| Actions | `about`, `preferences`, `quit`, `toggle-timer`, `skip` | same 5, in `install_actions` |
| Accels | `app.preferences` → `<Primary>comma`; `app.quit` → `<Primary>q` | same 2 (plus `win.show-help-overlay` → `<Primary>question`, added by hand since `AdwShortcutsDialog` has no `set_help_overlay` hook — noted in-code) |
| About window | `AboutWindow::from_appdata`, developer/icon/sound credits, Patreon + GitHub Sponsors links, supporters | `AboutDialog#build` — same links/credits, reading generated metainfo instead of a GResource |

## 2. Main window — `SolanumWindow` (`src/window.rs` + `data/ui/window.blp`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/window.rs`, `data/ui/window.blp` | `lib/solanum_rb/window.rb` | window | **Yes** — full widget tree, actions, signals and CSS all present (454 lines; see detail below) |
| `src/timer.rs` | `lib/solanum_rb/timer.rb` | behaviour (GObject, no widget) | **Yes** — `countdown-update`/`lap` signals, start/stop/running, duration-from-minutes, same 100ms tick |

**Widget tree** (`window.blp` template `$SolanumWindow : Adw.ApplicationWindow`):

| Widget | × | CSS | Signals/actions | Port method |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (conditional, devel build only) | `default-widget: timer_button`; installs `win.toggle-timer`, `win.reset`, `win.skip` | `window` |
| `Adw.ToolbarView` | 1 | — | — | `toolbar_view` |
| `Adw.HeaderBar` | 1 | `show-title: false` | — | `header_bar` |
| `Gtk.Box` (main) | 1 | `main-box` | vertical, `valign: center`, spacing 6 | `main_box` |
| `Gtk.Label` (lap) | 1 | `heading`, `dim-label` (→ `title-4`/no-`heading` at the large breakpoint) | — | `lap_label` |
| `Gtk.Label` (timer) | 1 | `timer-label`, `accent`, `blinking` (→ +`large-timer` at breakpoint) | — | `timer_label` |
| `Gtk.CenterBox` | 1 | — | `margin-bottom: 48`, `halign: center` | inline in `build` |
| `Gtk.Box` (button row) | 1 | — | spacing 12, `halign: center` | inline |
| `Gtk.Button` (timer/play-pause) | 1 | `circular`, `large`, `suggested-action` (toggled off while running) | `action-name: win.toggle-timer` | `timer_button` |
| `Gtk.Button` (skip) | 1 | `circular`, `large` | `action-name: win.skip` | `skip_button` |
| `Gtk.MenuButton` (primary menu) | 1 | `circular` | `primary: true`, `menu-model: app_menu` | `menu_button` |
| `Adw.Breakpoint` (`large_text_bp`) | 1 | — | `condition("min-width: 800sp and min-height: 800sp")`; `apply`/`unapply` swap the CSS above | `apply_fullscreen`/breakpoint wiring in `build` |
| `menu app_menu` (3 items) | 1 | — | `win.reset`, `app.preferences`, `win.show-help-overlay`, `app.about` | `window`'s menu-model construction |

Window-level actions: `win.toggle-timer`, `win.reset`, `win.skip`,
`win.show-help-overlay` — all 4 present in `install_actions`.

Behavioural signals from `Timer`/notification flow, all present in
`window.rb`: `countdown-update` → `on_countdown`, `lap` → `on_lap`,
fullscreen-on-break toggling, fullscreen desktop notification with
`app.toggle-timer`/`app.skip` buttons (`send_notification`), the lap-label
pluralisation (`ni18n_f`/`update_lap_label`), and the blinking/suggested-action
CSS swap on start/stop (`run_timer`/`pause_timer`).

CSS classes from `data/ui/style.css` (`button.large`, `.main_box`/`main-box`,
`.blinking`+`@keyframes blinkingText`, `.timer-label`, `.large-timer`): ported
onto the matching Ruby widgets (`lap_label`, `timer_label`, `main_box`,
`timer_button`). The stylesheet file itself (`data/style.css`) is read
directly by `Application#load_stylesheet`.

## 3. Preferences — `SolanumPreferencesWindow` (`src/preferences_window.rs` + `data/ui/preferences-window.blp`)

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/preferences_window.rs`, `data/ui/preferences-window.blp` | `lib/solanum_rb/preferences_dialog.rb` | dialog | **Yes** — all 5 rows + bindings present; upstream's deprecated `Adw.PreferencesWindow` is intentionally rehosted on `Adw.PreferencesDialog`, documented in-file |

| Widget | × | GSettings binding | Port |
|---|---:|---|---|
| `Adw.PreferencesPage` | 1 | — | `page` |
| `Adw.PreferencesGroup` (session lengths) | 1 | — | group accessor |
| `Adw.SpinRow` (`lap_spin`) | 1 | `lap-length` ↔ `value` | present |
| `Adw.SpinRow` (`short_break_spin`) | 1 | `short-break-length` ↔ `value` | present |
| `Adw.SpinRow` (`long_break_spin`) | 1 | `long-break-length` ↔ `value` | present |
| `Adw.PreferencesGroup` (long-break count) | 1 | — | present |
| `Adw.SpinRow` (`session_count_spin`) | 1 | `sessions-until-long-break` ↔ `value` | present |
| `Adw.PreferencesGroup` (fullscreen) | 1 | — | present |
| `Adw.SwitchRow` (`fullscreen_switch`) | 1 | `fullscreen-break` ↔ `active` | present |
| `Gtk.Adjustment` (shared lower/upper/step, bound across all 4 spin rows) | 1 shared + 3 bound | — | `LOWER`/`UPPER` constants + shared adjustment in `preferences_dialog.rb` |

## 4. Keyboard shortcuts — `help-overlay.blp`

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `data/gtk/help-overlay.blp` (no backing Rust source — standalone `.blp` object per the skill's "one unit per standalone .blp with no backing source" rule) | `lib/solanum_rb/shortcuts_dialog.rb` | dialog | **Yes**, on a different widget class: `Gtk.ShortcutsWindow` is deprecated in GTK 4.22 and unconstructable from the Ruby bindings, so the port uses `Adw.ShortcutsDialog` — documented in-file |

| Shortcut | Action | Port |
|---|---|---|
| "Show Primary Menu" | `win.menu` (upstream's action name; no actual `win.menu` action exists upstream either — it is informational F10 binding) | present, spelled out as a literal accelerator since there is no action behind it |
| "Show Preferences" | `app.preferences` | present |
| "Show Keyboard Shortcuts" | `win.show-help-overlay` | present |
| "Quit" | `app.quit` | present |

## 5. About dialog

Built in code (`app.rs::show_about`), not from a `.blp`/`.ui`. Already
covered under §1 app shell; cross-referenced here as its own component since
it is a distinct top-level window:

| Upstream file(s) | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `src/app.rs` (`show_about`), `data/org.gnome.Solanum.metainfo.xml.in.in` | `lib/solanum_rb/about_dialog.rb`, `lib/solanum_rb/appdata.rb` | dialog + data | **Yes** — `Adw.AboutWindow::from_appdata` behaviour reimplemented by hand (`Appdata` reads the generated metainfo off disk, with a `NullAppdata` fallback since there is no GResource to guarantee its presence); same links/credit sections/acknowledgements |

## 6. GSettings schema

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `data/org.gnome.Solanum.gschema.xml` (keys: `lap-length`, `short-break-length`, `long-break-length`, `sessions-until-long-break`, `fullscreen-break`) | `lib/solanum_rb/settings.rb` | data | **Yes** — schema ID rehosted as `org.gnome.Solanum.Rb` (own schema file expected under `data/`, compiled by `rake schema` per in-code comment); all 5 keys consumed from `window.rb`/`preferences_dialog.rb` |

## 7. GResource manifest / data files

| Upstream file | → `lib/*.rb` | Kind | Exists |
|---|---|---|---|
| `data/solanum.gresource.xml.in` | `lib/solanum_rb/paths.rb` | data | **Yes, by substitution** — there is no GResource in the port; every file it would have bundled (`window.ui`, `preferences-window.ui`, `style.css`, `help-overlay.ui`, `chime.ogg`, `beep.ogg`, the appdata) is instead read straight off `data/` through `Paths`, and `.ui`/`.blp` files are never generated at all since widgets are built declaratively in Ruby |
| `data/sounds/org.gnome.Solanum-{beep,chime}.ogg` | consumed by `lib/solanum_rb/sound.rb` | asset | **Yes** — `Sound#play` drives a `playbin` through `Paths.sound`, mirroring upstream's `gstreamer_play::Play` usage from `window.rs` |
| `data/icons/**` | registered by `Application#register_icons` | asset | **Yes** |

## 8. `po/` catalogue

| Upstream file | Port equivalent | Kind | Exists |
|---|---|---|---|
| `po/POTFILES.in` (lists `app.rs`, `window.rs`, the 3 `.blp` files, the appdata/desktop/gschema XML as translatable sources) | `lib/solanum_rb/paths.rb#po_dir` points at this repo's own `po/` | data | **Not verified in this pass** — the port's own `po/POTFILES.in`/catalogue was not read; translation-string parity (the `_()`/`i18n`/`ni18n_f` call sites across `window.rb`, `preferences_dialog.rb`, `shortcuts_dialog.rb`, `about_dialog.rb`, `application.rb`) is in scope for the `translation-parity` skill, not this component survey |

---

## Summary

Every upstream user-facing component — the application shell and its
actions/accelerators, the main window and its full widget tree, the timer
object, the preferences dialog, the shortcuts dialog, and the about dialog —
already has a corresponding, content-complete file on `lib/` in the `ruby`
branch. No net-new `lib/*.rb` file is required by this survey.

**Open items for a follow-up pass (not component gaps, but worth flagging):**

- `data/org.gnome.Solanum.gschema.xml`'s Ruby-side counterpart,
  `data/org.gnome.Solanum.Rb.gschema.xml` (matching `settings.rb`'s
  `SCHEMA_ID`), is present and was not diffed key-by-key against upstream in
  this pass.
- I did not check translation-string coverage (`po/`) in this pass: I
  surveyed file-level component mapping only, and read nothing in `po/` to
  confirm every upstream msgid has a port-side counterpart. That check, if
  it has not already been done elsewhere, still needs to happen before
  translation coverage can be called verified — I have not verified it
  myself.
- This survey itself did not run `component-scan.sh` against both trees —
  I avoided entering the `nix develop` shell in this pass since it writes
  no app code and `gir-symbols.sh` needs the Ruby GTK4/libadwaita `.gir`
  files from inside it. That scan has since been run, in a later pass, and
  its reconciliation against this file-level mapping is recorded in
  `.reports/COMPONENT_PARITY.md`'s "Round 2" section and in
  `.reports/component-identification.md`.
