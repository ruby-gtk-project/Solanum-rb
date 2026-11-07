# Component parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `f8f8046` |
| Units checked | 5 / 5 (window, preferences, shortcuts, about, app) |
| Units with parity | 5 / 5 |

This is a hand comparison on all four axes (count, style, behaviour, text),
not a `component-scan.sh`-driven one — see `component-identification.md` for
why the scan itself was not run this pass. Where I say "parity" below it
means I read both sides' source and found the same widget, the same classes,
the same signal/action wiring, and the same msgid; it does not mean I ran
the GI-symbol scan or screenshotted the running app to confirm rendering
(Step 4/5 of the skill). The drive scripts (93+8 checks) do exercise the
behaviour axis for everything they touch — see `test-parity.md` for what
that is and is not.

## Unit: main window — `src/window.rs` + `data/ui/window.blp` → `lib/solanum_rb/window.rb`

| Widget | Up × | Port × | CSS | Signals/Actions | Text | Verdict |
|---|---:|---:|---|---|:-:|---|
| `Adw.ApplicationWindow` | 1 | 1 | `devel` (conditional) | — | ✓ title `_("Solanum")` | parity |
| `Adw.ToolbarView` | 1 | 1 | — | — | — | parity |
| `Adw.HeaderBar` | 1 | 1 | `show-title: false` | — | — | parity |
| `Gtk.Box` (main) | 1 | 1 | `.main_box`→`.main-box` (see below) | — | — | parity |
| `Gtk.Label` lap | 1 | 1 | `heading`,`dim-label` | — | ✓ `_("Lap {}")`/`_("Long Break")`/`_("Short Break")` | parity |
| `Gtk.Label` timer | 1 | 1 | `timer-label`,`accent`,`blinking` | — | — | parity |
| `Gtk.CenterBox` | 1 | 1 | — | — | — | parity |
| `Gtk.Button` timer_button | 1 | 1 | `circular`,`large`,(+`suggested-action` when stopped) | `win.toggle-timer` | ✓ `_("Toggle Timer")` | parity |
| `Gtk.Button` skip_button | 1 | 1 | `circular`,`large` | `win.skip` | ✓ `_("Skip")` | parity |
| `Gtk.MenuButton` menu_button | 1 | 1 | `circular` | primary menu | ✓ `_("Main Menu")` | parity |
| `Gio::Menu` (2 sections) | 1 | 1 | — | `win.reset`, `app.preferences`, `win.show-help-overlay`, `app.about` | ✓ all 4 items byte-identical | parity |
| `Adw.Breakpoint` | 1 | 1 | — | `min-width:800sp and min-height:800sp` | — | parity |
| window actions | 4 (`toggle-timer`,`reset`,`skip`,`show-help-overlay`) | 4 | — | — | — | parity |
| notification (`Gio::Notification`) | 1 built per lap change | 1 | — | buttons: `app.toggle-timer`, `app.skip` | ✓ 7 strings (`Back to Work`/`Ready to keep working?`/`Start Working`/`Break Time`/`Stretch your legs, and drink some water.`/`Start Break`/`Skip`), byte-identical | parity |

Stylesheet: `.main_box` (upstream, never matches the window's applied class,
a pre-existing upstream bug) vs `.main-box` (port, matches) — a documented,
justified fix, and `var(--accent-color)`/`var(--view-fg-color)` vs
`@accent_color`/`@view_fg_color` — a documented GTK 4.22 workaround. Both are
in `PORTING.md`, both are correspondences per `component-parity`'s own
rules, not gaps.

Driven: `test/drive_solanum.rb` exercises the full lap cycle (pomodoro →
short break → pomodoro → … → long break), pause/resume, reset, preference
changes taking effect on the next lap, fullscreen-on-break with and without
the preference, the breakpoint growing/shrinking, and all three
dialogs opening and closing — 93/93 passing, confirmed by re-running it
(see `test-parity.md`).

## Unit: preferences dialog — `src/preferences_window.rs` + `data/ui/preferences-window.blp` → `lib/solanum_rb/preferences_dialog.rb`

| Row | Up | Port | Text | Verdict |
|---|---|---|:-:|---|
| `Adw.SpinRow` lap length | 1-99 | 1-99 | ✓ `_("Lap Length")` | parity |
| `Adw.SpinRow` short break | 1-99 | 1-99 | ✓ `_("Short Break Length")` | parity |
| `Adw.SpinRow` long break | 1-99 | 1-99 | ✓ `_("Long Break Length")` | parity |
| `Adw.SpinRow` session count | 1-99 | 1-99 | ✓ `_("Sessions Until Long Break")` | parity |
| `Adw.SwitchRow` fullscreen | — | — | ✓ `_("Fullscreen During Breaks")` | parity |
| group title/description | — | — | ✓ `_("Session Length")` + the full 2-sentence description, byte-identical | parity |

All five rows bind straight to the matching GSettings key (`:default`
binding, same keys as `org.gnome.Solanum.gschema.xml`). Upstream shares one
`Gtk.Adjustment` across all four spin rows via `bind`; the port gives each
its own `Gtk::Adjustment` with the same bounds (1/99/1) and relies on the
GSettings bind for the value — same rendered behaviour, different
plumbing, a correspondence. `AdwPreferencesDialog` vs `AdwPreferencesWindow`
is documented in `PORTING.md` as the libadwaita-1.6-deprecation
correspondence.

## Unit: shortcuts dialog — `data/gtk/help-overlay.blp` → `lib/solanum_rb/shortcuts_dialog.rb`

| Item | Up | Port | Verdict |
|---|---|---|---|
| Show Primary Menu | accelerator-only (F10, no action) | same, hand-coded `MENU_ACCELERATOR = 'F10'` | parity |
| Show Preferences | `app.preferences` | `app.preferences` | parity |
| Show Keyboard Shortcuts | `win.show-help-overlay` | `win.show-help-overlay` | parity |
| Quit | `app.quit` | `app.quit` | parity |

`Gtk.ShortcutsWindow` → `Adwaita::ShortcutsDialog` is documented in
`PORTING.md` as forced by two independent things: GTK 4.22 deprecates the
former, and `Gtk::ShortcutsWindow.new` cannot even be constructed from these
Ruby bindings. The `AdwShortcutsItem` two-constructor collision (both
`(title, accelerator)` and `(title, action_name)` are `(utf8,utf8)`, so only
the first is reachable) is documented and worked around
(`item(title, '')` then `row.action_name = …`) — a binding defect with a
located workaround, not a silent gap.

## Unit: about dialog — the `show_about` body of `src/app.rs` → `lib/solanum_rb/about_dialog.rb`

| Field | Up | Port | Verdict |
|---|---|---|---|
| developers | 1 name | 1 name, byte-identical | parity |
| copyright | `© {year} Christopher Davis, et al.` | same, `Config::COPYRIGHT` year | parity |
| translator-credits | `i18n("translator-credits")`, blanked if literal | `_('translator-credits')`, same blanking rule | parity |
| funding links (2) | Patreon, GitHub Sponsors | same 2 URLs, same mnemonic labels | parity |
| credit sections (2) + ack section (1) | Icon by / Sound by / Supported by (4 names) | same 3 sections, same names | parity |
| name/summary/description/website/issue/license/release-notes | from `adw_about_dialog_new_from_appdata` (GResource) | from `Appdata` reading the generated metainfo off disk, same fallbacks | parity |

`AboutWindow::from_appdata` → `Appdata`+`AboutDialog#apply_appdata` is a
documented, well-reasoned correspondence (no GResource in this port), and
every fallback in `NullAppdata` degrades to upstream's own fallback value
rather than an empty field.

## Unit: application — `src/app.rs` (actions/accels) → `lib/solanum_rb/application.rb`

| Action/Accel | Up | Port | Verdict |
|---|---|---|---|
| `app.about` | ✓ | ✓ | parity |
| `app.preferences` | ✓ | ✓ | parity |
| `app.quit` | ✓ | ✓ | parity |
| `app.toggle-timer` | ✓ (proxies to `win.toggle-timer`) | ✓ (calls `main_window.toggle_timer` directly) | parity (correspondence: same effect, no widget round-trip) |
| `app.skip` | ✓ (proxies to `win.skip`) | ✓ (calls `main_window.skip` directly) | parity |
| `<Primary>comma` → `app.preferences` | ✓ | ✓ | parity |
| `<Primary>q` → `app.quit` | ✓ | ✓ | parity |
| `<Primary>question` → `win.show-help-overlay` | implicit (GtkApplicationWindow's built-in help-overlay binding) | explicit `set_accels_for_action` | parity (correspondence: the port has no `set_help_overlay` hook to bind it for, so it is wired by hand — stated in-code) |

## Nothing found missing

Across these five units — every window, every dialog, every menu item,
every accelerator, every window/app action — I found no widget, CSS class,
signal, action, or user-visible string on upstream's side without a located
counterpart in the port. Every difference I found (`main_box`/`main-box`,
`var()`/`@accent_color`, direct method call vs `activate_action`, explicit
vs implicit accelerator, `AdwPreferencesDialog`/`AdwShortcutsDialog`
substitutions) is named, located, and justified in `PORTING.md` rather than
asserted and left unlocated.

The caveat is the one `component-identification.md` already states: this is
five units read by hand, not a `component-scan.sh` diff over the whole
tree, and `Timer`/`Config` (the two remaining upstream `.rs` files) got a
lighter pass. I found nothing wrong in them either, but "I read it and it
looked right" is a weaker claim than a scan, and the ledger should say so
rather than imply otherwise.
