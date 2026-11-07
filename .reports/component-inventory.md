# Component inventory — Solanum-rb

Upstream is a small Rust/gtk-rs app (one window, one preferences window, no
list views, no pages). Surveyed from `origin/main` via
`git ls-tree -r --name-only origin/main` and a read of every `src/*.rs`,
`data/ui/*.blp`, `data/gtk/*.blp`, the gschema, the gresource manifest and the
metainfo, compared against `lib/` on `ruby`.

Scope note: upstream has no list rows, pages, or repeated widgets — it is one
window with one countdown display, three buttons, a primary menu, and one
preferences window with five bound rows. The whole app is one unit.

## Summary

| | Upstream | `ruby` branch |
|---|---|---|
| Source files | 5 `.rs` + 2 `.blp` + 1 shortcuts `.blp` | 11 `.rb` under `lib/solanum_rb/` + 1 `lib/solanum/rb.rb` |
| Windows | `SolanumWindow`, `SolanumPreferencesWindow` | present |
| Dialogs | About (built in `app.rs`, not templated), Shortcuts (`help-overlay.blp`) | present |
| GSettings schema | `org.gnome.Solanum.gschema.xml`, 5 keys | present, app-id renamed |
| GResource manifest | `solanum.gresource.xml.in` | N/A by design (Ruby port has no `.ui`/GResource; widgets built in code per house style) |
| Sound | GstPlay via `gstreamer_play` crate, 2 `.ogg` | ported via `gstreamer_play` gem (ruby binding) — see `lib/solanum_rb/sound.rb` |
| po/ catalogue | 45 `.po` files + `POTFILES.in`/`LINGUAS` | not carried (expected: translations are a separate upstream artifact; no `po/` present in `ruby`'s file list, not assessed further here) |

**Finding: every user-facing component in this small app already has a
corresponding, already-built `lib/*.rb` file on `ruby`.** This is not a
partial port — it is a small, fully-scoped app where the prior pass(es)
already built the whole surface. No net-new widget code is called for by
this survey; see Blockers/Notes below for the one open question worth
flagging to the next pass.

## Components, upstream file → port file

| Upstream file(s) | Kind | → `lib/*.rb` | Exists? |
|---|---|---|---|
| `src/main.rs` | entry point (gstreamer init, resource load, app name, locale setup) | `lib/solanum_rb.rb` (+ `exe/solanum-rb`) | yes |
| `src/app.rs` — `SolanumApplication` (`Adw.Application` subclass): actions `app.about`, `app.preferences`, `app.quit`, `app.toggle-timer`, `app.skip`; accels `<Primary>comma`→`app.preferences`, `<Primary>q`→`app.quit`; About dialog built inline (not templated) | window/app class + 2 dialogs' worth of logic | `lib/solanum_rb/application.rb` (actions/accels/app lifecycle) + `lib/solanum_rb/about_dialog.rb` (About) | yes |
| `src/config.rs` — `APP_ID`, `COPYRIGHT`, `PKGDATADIR`, `VERSION`, `LOCALEDIR` consts | config/constants | `lib/solanum_rb/config.rb` | yes |
| `src/i18n.rs` — `i18n`/`ni18n`/`pi18n`/`pni18n` + `_f`/`_k` variants wrapping gettext | i18n helpers | `lib/solanum_rb/i18n.rb` | yes |
| `src/window.rs` — `SolanumWindow` (`Adw.ApplicationWindow` subclass): template children `lap_label` (`Gtk.Label`), `timer_label` (`Gtk.Label`), `timer_button` (`Gtk.Button`), `menu_button` (`Gtk.MenuButton`), `large_text_bp` (`Adw.Breakpoint`); actions `win.toggle-timer`, `win.reset`, `win.skip`; signal `Timer#countdown-update`/`Timer#lap` consumed here; CSS classes applied dynamically: `large-timer`/`title-4`/`heading` (breakpoint apply/unapply), `blinking`/`suggested-action` (toggle/reset), `devel` (Devel build) | window | `lib/solanum_rb/window.rb` | yes |
| `data/ui/window.blp` — template `$SolanumWindow : Adw.ApplicationWindow`; tree: `Adw.ToolbarView` → `Adw.HeaderBar` (top) + `Gtk.Box` (vertical, `main-box`) containing `Gtk.Label lap_label` (`heading dim-label`), `Gtk.Label timer_label` (`timer-label accent blinking`), `Gtk.CenterBox` → center `Gtk.Box` with `Gtk.Button timer_button` (`circular large suggested-action`, action `win.toggle-timer`) and `Gtk.Button skip_button` (`circular large`, action `win.skip`), end `Gtk.MenuButton menu_button` (`circular`, primary, menu-model `app_menu`); `Adw.Breakpoint large_text_bp`; menu `app_menu` with 2 sections: reset (`win.reset`), then preferences/shortcuts/about (`app.preferences`, `win.show-help-overlay`, `app.about`) | widget tree + menu (same component as `src/window.rs`) | `lib/solanum_rb/window.rb` (declarative `.tap`-built tree; primary menu built in same file) | yes |
| `data/gtk/help-overlay.blp` — `Gtk.ShortcutsWindow help_overlay`, 1 section, 1 group "General Shortcuts", 4 `Gtk.ShortcutsShortcut` rows (`win.menu`, `app.preferences`, `win.show-help-overlay`, `app.quit`) | shortcuts dialog (standalone `.blp`, no backing Rust struct) | `lib/solanum_rb/shortcuts_dialog.rb` | yes |
| `src/preferences_window.rs` — `SolanumPreferencesWindow` (`Adw.PreferencesWindow` subclass): template children `lap_spin`, `short_break_spin`, `long_break_spin`, `session_count_spin` (all `Adw.SpinRow`), `fullscreen_switch` (`Adw.SwitchRow`); binds all 5 to GSettings keys | preferences dialog | `lib/solanum_rb/preferences_dialog.rb` | yes |
| `data/ui/preferences-window.blp` — template `$SolanumPreferencesWindow : Adw.PreferencesWindow`; one `Adw.PreferencesPage` → 3 `Adw.PreferencesGroup`s: (1) "Session Length" group with `lap_spin`/`short_break_spin`/`long_break_spin` (3× `Adw.SpinRow`, shared `Gtk.Adjustment` bounds via `bind`), (2) group with `session_count_spin` (`Adw.SpinRow`), (3) group with `fullscreen_switch` (`Adw.SwitchRow`) | widget tree (same component as `src/preferences_window.rs`) | `lib/solanum_rb/preferences_dialog.rb` | yes |
| `src/timer.rs` — `Timer` (plain `glib::Object` subclass, not a widget): signals `countdown-update(u32,u32)`, `lap()`; `start`/`stop`/`set_duration`/`running` | non-widget model/behaviour | `lib/solanum_rb/timer.rb` | yes |
| `data/org.gnome.Solanum.gschema.xml` — schema `org.gnome.Solanum`, keys `lap-length`(u,25), `short-break-length`(u,5), `long-break-length`(u,15), `sessions-until-long-break`(u,4), `fullscreen-break`(b,false) | GSettings schema | `lib/solanum_rb/settings.rb` + `data/org.gnome.Solanum.Rb.gschema.xml` | yes (renamed to `.Rb` app id, same 5 keys — confirm key names/defaults match exactly, see Notes) |
| `data/org.gnome.Solanum.metainfo.xml.in.in` | metainfo (consumed at runtime for About dialog) | `lib/solanum_rb/appdata.rb` + `data/org.gnome.Solanum.Rb.metainfo.xml.in` | yes |
| `data/sounds/org.gnome.Solanum-{beep,chime}.ogg` + GstPlay in `src/window.rs`/`app.rs` | sound playback component | `lib/solanum_rb/sound.rb` (uses `gstreamer_play` gem's `GstPlay::Play`) + `data/sounds/*.ogg` | yes |
| `data/ui/style.css` | stylesheet (`.main-box`, `.timer-label`, `.blinking`, `.large-timer`) | `data/style.css` | yes (present; byte-for-byte diff not checked in this pass) |
| `data/solanum.gresource.xml.in` | GResource manifest | N/A — house style builds widgets in code, no `.ui`/GResource layer | n/a by design |
| `po/*.po` (45 locales), `po/POTFILES.in`, `po/LINGUAS` | translation catalogue | not present under `ruby` | **gap** — out of scope for `translation-parity` work, not attempted here |

## Non-widget support files (for completeness, not components)

| Upstream | Port |
|---|---|
| `Cargo.toml`/`Cargo.lock` (deps) | `solanum-rb.gemspec`, `nix/Gemfile` |
| `meson.build` (build) | `flake.nix`, `Rakefile` |
| `data/org.gnome.Solanum.desktop.in.in` | `data/org.gnome.Solanum.Rb.desktop.in` |
| `data/icons/**` | present under `data/icons` (not diffed pixel-for-pixel) |

## Notes / things the next pass should check, not act on here

- **Gem wiring audit (required by this task's preamble) — verified clean.**
  `gstreamer_play` is declared in the gemspec (`~> 1.1`), listed in
  `nix/Gemfile`, `require`d in `lib/solanum_rb/sound.rb`, and the typelib
  wiring (`gstStack`/`gstPluginPath`/`GI_TYPELIB_PATH`) is in `flake.nix`.
  Proved live: `nix develop --command ruby -e 'require "gstreamer_play";
  puts GstPlay.constants.size'` → `19`. No hand-rolled audio fallback found;
  `Sound#build_play` calls `GstPlay::Play.new` directly and only rescues to
  log-and-continue when GStreamer itself is unavailable (expected — audio
  can't be proven in a headless test per the file's own comment).
- **GSettings key parity** (`org.gnome.Solanum` vs `org.gnome.Solanum.Rb`
  gschema) was read but not diffed key-by-key against
  `lib/solanum_rb/settings.rb`'s usage; worth a quick confirm in the next
  pass that all 5 keys/types/defaults match exactly.
- **`po/` catalogue** has no counterpart under `ruby`. This is squarely
  `translation-parity` scope, not `component-identification`, so it is
  recorded here as a known gap and left untouched.
- **Style.css** exists on both sides but was not diffed line-by-line in this
  pass; given the CSS classes seen in `window.rs`/`window.blp`
  (`main-box`, `timer-label`, `blinking`, `large-timer`, `accent`) a
  `component-parity` pass should confirm `data/style.css` defines all of
  them.

## Conclusion

No app code was written in this step, per instructions. Every upstream
user-facing component for this app already maps onto an existing `lib/*.rb`
file on `ruby`; there is no missing window, dialog, page, row, or menu to
scaffold. The two concrete loose ends for a follow-up pass are the `po/`
catalogue (translation-parity) and a byte-level confirm of `data/style.css`
and the gschema key values (component-parity).
