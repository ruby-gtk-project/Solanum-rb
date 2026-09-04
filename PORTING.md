# Porting Solanum to Ruby

How this port maps onto the Rust original on `main`, and the ruby-gnome and
GTK defects found on the way. Read this before changing the timer, the
stylesheet or the shortcuts dialog.

## File map

| Upstream | Here |
|---|---|
| `src/main.rs` | `bin/solanum-rb` |
| `src/app.rs` | `lib/solanum_rb/application.rb` |
| `src/window.rs` + `data/ui/window.blp` | `lib/solanum_rb/window.rb` |
| `src/timer.rs` | `lib/solanum_rb/timer.rb` |
| `src/preferences_window.rs` + `data/ui/preferences-window.blp` | `lib/solanum_rb/preferences_dialog.rb` |
| `data/gtk/help-overlay.blp` | `lib/solanum_rb/shortcuts_dialog.rb` |
| the `AboutWindow::from_appdata` call in `src/app.rs` | `lib/solanum_rb/about_dialog.rb` |
| `src/i18n.rs` + gettext | `lib/solanum_rb/i18n.rb` |
| `src/config.rs` | constants on the classes that use them |
| `data/*.gschema.xml` | same file, plus `lib/solanum_rb/settings.rb` |
| GResource | `data/` read off disk, via `lib/solanum_rb/paths.rb` |

Everything upstream has is here: both dialogs, the shortcuts window, the about
window, all five preferences, all five app actions and four window actions, the
primary menu, the two accelerators, the breakpoint, the timer notification with
both of its buttons, the fullscreen-break behaviour, and the beep and chime.

## Things that are deliberately not a translation of upstream

**`Timer` is a plain object, not a GObject.** Upstream gives it
`countdown-update` and `lap` signals, and nothing outside the window ever
connects to them. Here they are two blocks passed to the constructor. This is
also what makes the timer testable without a display: `Timer#now` is a public
method, so a test subclass drives the clock and a 25-minute lap checks in
microseconds (`test/test_units.rb`).

**`update_lap` and `next_lap` are merged.** Upstream splits the lap count and
the lap label across two methods that always run together. `start_lap` does
both.

**AdwPreferencesDialog, not AdwPreferencesWindow.** The window form is
deprecated in libadwaita 1.6. The dialog is the same page, presented inside
the parent window.

**AdwShortcutsDialog, not GtkShortcutsWindow.** Not a preference: GTK 4.22
deprecates the old widget, and the Ruby bindings cannot construct it at all —
`Gtk::ShortcutsWindow.new` raises `GtkWindow is not subtype of
GtkShortcutsWindow`.

**No gettext.** There is no gettext binding in the Ruby GTK stack, so
`I18n` reads the `po/*.po` files directly. It handles `msgctxt` (the
help-overlay strings need it) and takes `msgstr[0]` for plural entries — every
plural msgid in this catalogue has an identical `msgid_plural`, so the
singular form covers both. A real Plural-Forms evaluator would be needed only
if that stops being true.

**GStreamer through `playbin`, not `GstPlay`.** Upstream uses `gstreamer_play`;
the Ruby `gstreamer` gem exposes the pipeline one layer down. `Gtk::MediaFile`
would have been simpler still, but nixpkgs' gtk4 is built without any
GtkMediaFile backend, so it resolves to `GtkNothingMedia` and plays silence.

## Defects found while porting

**GTK 4.22 cannot resolve `var()` inside `@keyframes`.** Upstream's
`style.css` writes the blink colours as `var(--accent-color)` and
`var(--view-fg-color)`. GTK emits four `"…" is not a valid color name` parser
errors *per animation frame* — around 200 a second while the countdown blinks,
and the colours do not resolve. libadwaita's `@accent_color` and
`@view_fg_color` name the same colours and work. `test/test_units.rb` guards
against the syntax coming back.

**`Adwaita::ShortcutsItem` has two unreachable-by-one constructors.** The C API
offers `(title, accelerator)` and `(title, action_name)`; both are
`(utf8, utf8)`, so the Ruby bindings can only ever dispatch to the first. An
action-backed row is built with an empty accelerator and given its action
afterwards, which works and lets the dialog show whatever accelerator the
application registered.

**`Gio::Settings#get_value` returns a native Ruby value**, not a `GLib::Variant`
— `settings['lap-length']` is an `Integer`, so there is no `get_uint32` to call.

**`Gtk::Window#is_active` does not exist**; the binding is `active?`.

**`Gtk::Button#activate` is asynchronous.** It runs the button's press
animation and only emits `clicked` on a later turn of the main loop, so several
activations inside one test step collapse into one. `test/drive_solanum.rb`
uses the button for the single-step wiring checks and activates the action
directly when it needs several in a row.

**`Gtk::WidgetPaintable` needs a frame before it observes its widget.** A
freshly built one snapshots to nothing, which made screenshots fail at random.
`test/gtk_driver.rb` keeps one paintable per widget for the session. This is
the only change to the file copied from the `ruby-gtk-testing` skill.

**Building the GStreamer pipeline stalls the UI.** Creating `playbin` scans the
plugin registry: ~240 ms warm, seconds cold. Left lazy, that lands on the first
press of Start. `Window#build` touches `sound` so it is paid at startup.

**`Gio::Settings.new` aborts the process on a missing schema**, which in a dev
checkout means a SIGTRAP and no explanation. `Settings` looks the schema up
first and raises a Ruby error naming the fix.

**nixpkgs' glib setup hook relocates the compiled schema** from
`$out/share/glib-2.0/schemas` to `$out/share/gsettings-schemas/$name/…`, so the
wrapper has to put *that* directory on `XDG_DATA_DIRS`, not just `$out/share`.

## Carried over from upstream unchanged

`data/style.css` defines `.main_box`, but the window applies `main-box`, so
that 24px padding has never taken effect. It is left as-is: fixing it would
change how the app looks relative to upstream.

The countdown separator is U+2236 RATIO, not a colon, as upstream uses.
