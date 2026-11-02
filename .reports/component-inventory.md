# Solanum — upstream component inventory

Upstream: `origin/main` (Rust / gtk-rs + libadwaita, blueprint UI).
Port: `ruby` branch, `lib/solanum_rb/`.

Upstream is small: 7 `src/*.rs`, 3 `.blp`, one stylesheet, one GSettings
schema, one GResource manifest, 46 `po/` catalogues. Every user-facing
component is accounted for below.

## Component map

| # | Upstream file(s) | Port file | Kind | Exists |
|---|---|---|---|---|
| 1 | `src/main.rs` | `bin/solanum-rb` + `lib/solanum_rb.rb` | entry point | yes |
| 2 | `src/app.rs` | `lib/solanum_rb/application.rb` | application | yes |
| 3 | `src/app.rs` (`show_about`) + `data/org.gnome.Solanum.metainfo.xml.in.in` | `lib/solanum_rb/about_dialog.rb` | dialog | yes |
| 4 | `data/org.gnome.Solanum.metainfo.xml.in.in` (read at runtime by `AboutWindow::from_appdata`) | `lib/solanum_rb/appdata.rb` | support | yes |
| 5 | `src/window.rs` + `data/ui/window.blp` | `lib/solanum_rb/window.rb` | window | yes |
| 6 | `data/ui/window.blp` (`menu app_menu`) | `lib/solanum_rb/window.rb` (`app_menu`) | menu | yes |
| 7 | `src/preferences_window.rs` + `data/ui/preferences-window.blp` | `lib/solanum_rb/preferences_dialog.rb` | preferences | yes |
| 8 | `data/gtk/help-overlay.blp` | `lib/solanum_rb/shortcuts_dialog.rb` | shortcuts | yes |
| 9 | `src/timer.rs` | `lib/solanum_rb/timer.rb` | model | yes |
| 10 | `src/window.rs` (`play_sound`, gstreamer `Play`) + `data/sounds/*.ogg` | `lib/solanum_rb/sound.rb` | support | yes |
| 11 | `src/window.rs` (`send_notifcation`) | `lib/solanum_rb/window.rb` (`notification`) | notification | yes |
| 12 | `src/config.rs` + `meson.build` | `lib/solanum_rb/config.rb`, `lib/solanum_rb/paths.rb` | support | yes |
| 13 | `src/i18n.rs` + `po/` | `lib/solanum_rb/i18n.rb` | support | yes |
| 14 | `data/org.gnome.Solanum.gschema.xml` | `data/org.gnome.Solanum.Rb.gschema.xml` + `lib/solanum_rb/settings.rb` | settings | yes |
| 15 | `data/ui/style.css` | `data/style.css` | stylesheet | yes |
| 16 | `data/solanum.gresource.xml.in` | `lib/solanum_rb/paths.rb` (filesystem instead of GResource) | support | yes |
| 17 | `data/icons/**` | `data/icons/hicolor/**` | assets | yes |
| 18 | `po/LINGUAS`, `po/*.po` (46) | `po/` (46 + LINGUAS) | translations | yes |

No upstream component is missing. There are no empty states and no error
states upstream: the window always shows a countdown, and the only failure
path is a missing GSettings schema, which the port adds as
`Settings::SchemaMissing`.

## src/app.rs → lib/solanum_rb/application.rb — the application

Not a widget class; it owns the actions, the accelerators, the About dialog
and the preferences entry point.

| Actions | Target | Port |
|---|---|---|
| `app.about` | `show_about` | yes |
| `app.preferences` | `show_preferences` | yes |
| `app.quit` | `quit` | yes |
| `app.toggle-timer` | forwards to `win.toggle-timer` (reached from the notification button) | yes |
| `app.skip` | forwards to `win.skip` | yes |

| Accelerator | Action | Port |
|---|---|---|
| `<Primary>comma` | `app.preferences` | yes |
| `<Primary>q` | `app.quit` | yes |
| — | `win.show-help-overlay` | port adds `<Primary>question`; upstream gets it free from `GtkApplicationWindow::set_help_overlay`, which `AdwShortcutsDialog` has no equivalent for |

Upstream subclasses `Adw.Application`; the port uses `Gtk::Application` and
calls `Adwaita.init` on `startup`, because the Ruby bindings cannot subclass
`AdwApplication`. Upstream also loads the stylesheet and icons from a
GResource; the port registers `data/` with a `Gtk::CssProvider` and an
`Gtk::IconTheme` search path.

## src/window.rs + data/ui/window.blp → lib/solanum_rb/window.rb — the only window

| Widget | × | CSS | Signals / actions | Notes |
|---|---:|---|---|---|
| `Adw.ApplicationWindow` | 1 | `devel` (only when the app id ends `Devel`) | `win.toggle-timer`, `win.reset`, `win.skip`, `win.show-help-overlay` | 360×360, `height-request: 294`, `default-widget: timer_button` |
| `Adw.ToolbarView` | 1 | — | — | — |
| `Adw.HeaderBar` | 1 | — | — | `show-title: false` |
| `Gtk.Box` (vertical, 6) | 1 | `main-box` | — | `valign: center`, `vexpand` |
| `Gtk.Label` lap_label | 1 | `heading`, `dim-label`; `title-4` replaces `heading` under the breakpoint | — | `Lap {n}`, `Short Break`, `Long Break` |
| `Gtk.Label` timer_label | 1 | `timer-label`, `accent`, `blinking` (removed while running); `large-timer` under the breakpoint | — | `direction: ltr`, `MM∶SS` with U+2236 |
| `Gtk.CenterBox` | 1 | — | — | `margin-bottom: 48`, `halign: center` |
| `Gtk.Box` (horizontal, 12) | 1 | — | — | centre slot |
| `Gtk.Button` timer_button | 1 | `circular`, `large`, `suggested-action` (removed while running) | `win.toggle-timer` | icon flips start ↔ pause |
| `Gtk.Button` skip_button | 1 | `circular`, `large` | `win.skip` | disabled while the timer runs |
| `Gtk.MenuButton` menu_button | 1 | `circular` | `menu-model: app_menu` | `primary: true`, end slot |
| `Adw.Breakpoint` large_text_bp | 1 | — | `apply`, `unapply` | `min-width: 800sp and min-height: 800sp` |

Repeaters: none. Conditional: the `devel` class; fullscreen on a break only
when `fullscreen-break` is set; the notification only when the window is not
active. Dynamic CSS: `blinking`, `suggested-action`, `large-timer`,
`title-4`/`heading` as listed.

### menu app_menu — 4 items in 2 sections

`Reset Sessions` → `win.reset`; then `_Preferences` → `app.preferences`,
`_Keyboard Shortcuts` → `win.show-help-overlay`, `_About Solanum` →
`app.about`. All present in the port as two `Gio::Menu` sections.

### the lap notification

`Gio.Notification`, id `timer-notif`, urgent, withdrawn when the timer
starts. Title/body/button per lap type: `Back to Work` / `Ready to keep
working?` / `Start Working`, and `Break Time` / `Stretch your legs, and drink
some water.` / `Start Break`, plus a second `Skip` button. Buttons target
`app.toggle-timer` and `app.skip`. Present in the port.

## src/preferences_window.rs + data/ui/preferences-window.blp → lib/solanum_rb/preferences_dialog.rb

| Widget | × | CSS | Signals | Notes |
|---|---:|---|---|---|
| `Adw.PreferencesWindow` → port `Adw.PreferencesDialog` | 1 | — | — | `search-enabled: false`; upstream is `transient-for` the window, the port presents on it |
| `Adw.PreferencesPage` | 1 | — | — | — |
| `Adw.PreferencesGroup` | 3 | — | — | `Session Length` + description; then two untitled groups |
| `Adw.SpinRow` | 4 | — | GSettings `bind` on `value` | `Lap Length`, `Short Break Length`, `Long Break Length`, `Sessions Until Long Break` |
| `Gtk.Adjustment` | 4 | — | — | 1–99 step 1; upstream binds three to the first, the port shares one object |
| `Adw.SwitchRow` fullscreen_switch | 1 | — | GSettings `bind` on `active` | `Fullscreen During Breaks` |

## data/gtk/help-overlay.blp → lib/solanum_rb/shortcuts_dialog.rb

A standalone `.blp` object with no backing source file: one
`Gtk.ShortcutsWindow` → one `Gtk.ShortcutsSection` → one
`Gtk.ShortcutsGroup` (`General Shortcuts`, msgctxt `shortcut window`) → four
`Gtk.ShortcutsShortcut`: `Show Primary Menu` (`win.menu`), `Show Preferences`
(`app.preferences`), `Show Keyboard Shortcuts` (`win.show-help-overlay`),
`Quit` (`app.quit`).

The port uses `Adw.ShortcutsDialog`/`Section`/`Item`: GTK 4.22 deprecates
`GtkShortcutsWindow` and the Ruby bindings cannot construct it. Note that
upstream's `win.menu` is a dangling action — nothing installs it — so the
port spells the first row's accelerator as `F10`, GTK's own primary-menu
binding.

## src/timer.rs → lib/solanum_rb/timer.rb

Not a widget: a `GObject` with `countdown-update(u32, u32)` and `lap`
signals, a 100 ms `timeout_add_local`, and pause-resume by subtracting
elapsed from the remaining duration. The port carries the same behaviour with
two callbacks instead of GObject signals and `CLOCK_MONOTONIC` for the
instant.

## Settings, stylesheet, translations

- Schema: five keys, `lap-length` 25, `short-break-length` 5,
  `long-break-length` 15, `sessions-until-long-break` 4,
  `fullscreen-break` false. Ported verbatim under the `.Rb` id.
- Stylesheet: `button.large`, `.blinking` (+ `:backdrop`), `@keyframes
  blinkingText`, `.timer-label`, `.large-timer`, and the padding rule.
  Upstream spells the padding rule `.main_box` while the window applies
  `main-box`, so upstream's 24px padding has never taken effect; the port
  spells it `.main-box`. The port also swaps `var(--accent-color)` /
  `var(--view-fg-color)` for `@accent_color` / `@view_fg_color`, because GTK
  4.22 cannot resolve a custom property inside `@keyframes`.
- `po/`: all 46 upstream catalogues plus `LINGUAS` are on `ruby`.

## Blockers

1. **Stale scaffold still in `lib/`.** `lib/solanum.rb`,
   `lib/solanum/application.rb` and `lib/solanum/rb/version.rb` are the
   gem-skeleton leftovers: a second `Solanum::Application` with an
   `Adw.StatusPage` reading "The Ruby port has not been written yet", a
   `Gtk::Application` under the id `org.rubygtkproject.Solanum`, and a
   `Solanum::Rb::VERSION`. They correspond to no upstream file, duplicate the
   real application under a different module, and should be deleted or folded
   into `lib/solanum_rb/`.
2. **No specs.** `spec/` holds only `README.md` and `spec_helper.rb`; every
   component above is untested. Out of scope for this step — it belongs to
   the test-parity pass.
