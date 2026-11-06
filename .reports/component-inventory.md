# Solanum-rb component inventory

Survey of `origin/main` (upstream Rust/GTK implementation) against the `ruby`
branch's `lib/`, produced with the `component-identification` method: upstream
source paired with its `.blp` where one exists, mapped to the port file that
should hold it.

Upstream tree (`git ls-tree -r --name-only origin/main`), filtered to
everything that contributes a user-facing component, plus settings/resources/
translation infrastructure:

```
src/main.rs
src/app.rs
src/window.rs
src/timer.rs
src/preferences_window.rs
src/config.rs
src/i18n.rs
data/ui/window.blp
data/ui/preferences-window.blp
data/gtk/help-overlay.blp
data/ui/style.css
data/org.gnome.Solanum.gschema.xml
data/org.gnome.Solanum.desktop.in.in
data/org.gnome.Solanum.metainfo.xml.in.in
data/solanum.gresource.xml.in
data/icons/**
po/*.po (47 catalogues) + po/LINGUAS + po/POTFILES.in
```

## Component list

| Upstream file | Port path | Kind | Exists? |
|---|---|---|---|
| `src/main.rs` | `exe/solanum-rb` | entry point | Yes |
| `src/app.rs` (`SolanumApplication`) | `lib/solanum_rb/application.rb` | application class — actions (`app.preferences`, `app.quit`, `app.about`, …), accelerators, startup | Yes |
| `src/app.rs` (the `AboutWindow::from_appdata` call) | `lib/solanum_rb/about_dialog.rb` | dialog | Yes |
| `src/window.rs` + `data/ui/window.blp` (template `$SolanumWindow : Adw.ApplicationWindow`) | `lib/solanum_rb/window.rb` | main window — header bar, lap/timer labels, timer/skip buttons, primary menu button + menu model, breakpoint, notification | Yes |
| `src/timer.rs` (`Timer`, GObject with `countdown-update`/`lap` signals) | `lib/solanum_rb/timer.rb` | timer model (ported as a plain object per `PORTING.md`, not a GObject — block callbacks instead of signals) | Yes |
| `src/preferences_window.rs` + `data/ui/preferences-window.blp` | `lib/solanum_rb/preferences_dialog.rb` | preferences dialog (ported as `Adw.PreferencesDialog`, not the deprecated `Adw.PreferencesWindow`) — 5 preference rows | Yes |
| `data/gtk/help-overlay.blp` (`Gtk.ShortcutsWindow help_overlay`) | `lib/solanum_rb/shortcuts_dialog.rb` | shortcuts window (ported as `Adw.ShortcutsDialog`; `Gtk::ShortcutsWindow.new` is unconstructable from the Ruby bindings — see `PORTING.md`) — 4 shortcuts (menu, preferences, show-help-overlay, quit) | Yes |
| `src/i18n.rs` + gettext | `lib/solanum_rb/i18n.rb` | translation loader — reads `po/*.po` directly (no gettext binding in the Ruby GTK stack) | Yes |
| `src/config.rs` + meson profile logic | `lib/solanum_rb/config.rb` | build/profile info (app id, name suffix, devel styling) | Yes |
| `adw_about_dialog_new_from_appdata` (GResource-backed) | `lib/solanum_rb/appdata.rb` | metainfo reader, replaces the GResource call by reading the generated file off disk | Yes |
| `data/org.gnome.Solanum.gschema.xml` | `data/org.gnome.Solanum.Rb.gschema.xml` + `lib/solanum_rb/settings.rb` | GSettings schema + wrapper | Yes |
| `data/solanum.gresource.xml.in` | `lib/solanum_rb/paths.rb` | resource lookup, replaced with reading `data/` off disk (no GResource bundle) | Yes |
| meson's `i18n.merge_file` (desktop entry / metainfo localisation) | `scripts/merge_translations.rb` (via `rake desktop`) | build-time generator, not a `lib/` component | Yes |
| meson's three `test(...)` validation calls | `rake validate` | build-time check, not a `lib/` component | Yes |
| `data/ui/style.css` | `data/style.css` | stylesheet | Yes |
| `data/icons/**` | `data/icons/**` (renamed `org.gnome.Solanum.Rb[.Devel]`) | icon assets | Yes |
| `po/*.po`, `po/LINGUAS`, `po/POTFILES.in` | `po/*.po` (47 catalogues present) | translation catalogue, read by `lib/solanum_rb/i18n.rb` | Yes |
| `data/org.gnome.Solanum.desktop.in.in` | `data/org.gnome.Solanum.Rb.desktop.in` | desktop entry | Yes |
| `data/org.gnome.Solanum.metainfo.xml.in.in` | `data/org.gnome.Solanum.Rb.metainfo.xml.in` | metainfo, read back by `about_dialog.rb`/`appdata.rb` | Yes |
| GStreamer sound playback (upstream `gstreamer_play`) | `lib/solanum_rb/sound.rb` | sound player — beep/chime, ported through `playbin` (the `gstreamer` gem exposes one layer below `GstPlay`; `Gtk::MediaFile` was ruled out because nixpkgs' gtk4 has no media backend) | Yes |

## Result

Every upstream file that contributes a user-facing component, plus every
non-code artifact (schema, desktop entry, metainfo, stylesheet, icons,
translation catalogue, GResource manifest), already has a corresponding file
on `ruby`. `PORTING.md` on this branch documents the same file map and lists
the deliberate deviations (`Timer` as a plain object, `Adw.PreferencesDialog`
instead of the deprecated window form, `Adw.ShortcutsDialog` instead of
`Gtk.ShortcutsWindow`, no gettext, no GResource, GStreamer via `playbin`) and
the GTK/ruby-gnome defects found while porting.

No gap was found: this is a full-parity port already. Nothing in this survey
calls for new `lib/` files. A follow-up pass should instead verify each
existing `lib/solanum_rb/*.rb` file widget-by-widget (types, CSS classes,
signals, actions) against its upstream `.blp`/`.rs` pairing — per the
`component-identification` method — rather than against this file-level map,
and should re-check the MANDATORY binding-gems section of this task (gemspec
dependencies, `nix/Gemfile`, typelibs) against what `lib/` actually requires,
since this survey step was scoped to component inventory only and did not
touch the gemspec or `flake.nix`.
