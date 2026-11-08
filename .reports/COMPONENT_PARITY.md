# Component parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `0590067` |
| Units checked | 5 / 5 (window, preferences, shortcuts, about, app) |
| Units with parity | 5 / 5 on the four widget/CSS/signal/text axes — **the i18n support layer behind the window has a coverage gap**, not a behaviour gap (see below) |

**Re-verified this round against `0590067`**, one commit past the sha
(`6bfc160`) this file was last pinned to. That commit
("Implement ni18n/pni18n plural dispatch") is a direct fix of this file's
own previous finding: it adds `ni18n`/`ni18n_f`/`ni18n_k`/`pi18n_f`/
`pi18n_k`/`pni18n`/`pni18n_f`/`pni18n_k` to `lib/solanum_rb/i18n.rb` and
switches `window.rb`'s live lap label from `f_('Lap {}', @pomodoro_count)` to
`ni18n_f('Lap {}', 'Lap {}', @pomodoro_count, @pomodoro_count)`, matching
`src/window.rs`'s call shape exactly. I read the diff and confirmed the fix
by hand (below) rather than trusting the commit message.

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
| `Gtk.Label` lap | 1 | 1 | `heading`,`dim-label` | — | `_("Long Break")`/`_("Short Break")` parity; `"Lap {}"` plural dispatch now matches upstream's call shape — see below | parity |
| `Gtk.Label` timer | 1 | 1 | `timer-label`,`accent`,`blinking` | — | — | parity |
| `Gtk.CenterBox` | 1 | 1 | — | — | — | parity |
| `Gtk.Button` timer_button | 1 | 1 | `circular`,`large`,(+`suggested-action` when stopped) | `win.toggle-timer` | ✓ `_("Toggle Timer")` | parity |
| `Gtk.Button` skip_button | 1 | 1 | `circular`,`large` | `win.skip` | ✓ `_("Skip")` | parity |
| `Gtk.MenuButton` menu_button | 1 | 1 | `circular` | primary menu | ✓ `_("Main Menu")` | parity |
| `Gio::Menu` (2 sections) | 1 | 1 | — | `win.reset`, `app.preferences`, `win.show-help-overlay`, `app.about` | ✓ all 4 items byte-identical | parity |
| `Adw.Breakpoint` | 1 | 1 | — | `min-width:800sp and min-height:800sp` | — | parity |
| window actions | 4 (`toggle-timer`,`reset`,`skip`,`show-help-overlay`) | 4 | — | — | — | parity |
| notification (`Gio::Notification`) | 1 built per lap change | 1 | — | buttons: `app.toggle-timer`, `app.skip` | ✓ 7 strings (`Back to Work`/`Ready to keep working?`/`Start Working`/`Break Time`/`Stretch your legs, and drink some water.`/`Start Break`/`Skip`), byte-identical | parity |

## Previous-round regression, now fixed and re-verified by hand

Last round's main finding here: `src/window.rs` sets the lap label with
`ni18n_f("Lap {}", "Lap {}", count, &[count.to_s])`, and `window.rb` instead
called `f_('Lap {}', @pomodoro_count)` — no plural dispatch at all, so four
shipped locales (`ca`, `fur`, `oc`, `pt_BR`, whose `.po` files give genuinely
different singular/plural wording for this msgid) rendered the singular
form on every lap past the first.

Commit `0590067` fixes both halves: `I18n` gained real plural dispatch
(`ni18n`/`ni18n_f`, parsing each catalogue's own `Plural-Forms` header into a
proc rather than assuming English's "singular iff 1"), and `window.rb` now
calls:

```ruby
lap_label.label = ni18n_f('Lap {}', 'Lap {}', @pomodoro_count, @pomodoro_count)
```

— the same shape as upstream's call, byte-for-byte on the msgid pair. I
re-ran the reproduction from last round's report to confirm, rather than
trusting the fix on the diff alone:

```sh
$ nix develop --command xvfb-run -a ruby -r./lib/solanum_rb -e '
  ENV["LANGUAGE"]="ca"; SolanumRb::I18n.reset!
  puts SolanumRb::I18n.ni18n_f("Lap {}", "Lap {}", 1, 1)
  puts SolanumRb::I18n.ni18n_f("Lap {}", "Lap {}", 2, 2)'
Volta 1
Voltes 2
```

Catalan (and, by the same code path, `fur`/`oc`/`pt_BR`) now renders the
correct plural form from lap 2 onward, matching upstream — the *rendered
text* axis for this specific widget, in all 47 shipped locales, is parity.
The main window's verdict is restored to full parity on all four axes on
that basis.

**Important qualifier, not a reversal of the above:** tracing the mechanism
behind that correct output (see `TEST_PARITY.md`'s headline finding) found
that it is not reading the catalogue's `Plural-Forms` header at all —
`store` drops the PO header entry (`msgid ""`) for every locale before
`plural_rule` ever sees it, so `ni18n_f` always falls back to English's
hardcoded binary rule regardless of which `.po` file is loaded. The
*current* rendered text happens to be right in all 47 locales only because
every shipped `.po` file's actual plural rule for `"Lap {}"` coincides with
that hardcoded fallback (either identical `msgstr` forms, or a two-form rule
mathematically equal to English's). Component-parity's own axis is
"what does the user see," and what the user sees today is correct — so the
widget-level verdict above stands — but the mechanism producing it is not
the one upstream has, and the next plural string with real 3-or-4-form
grammatical variation (10 of the 47 shipped locales ship such rules) would
expose it immediately. Treating "the visible text matches today" as the
end of the story, without naming that the match is coincidental rather than
mechanistic, is exactly the gap this file's own previous round was written
to correct — so this round names it rather than repeating it.

**Also still true: the i18n support layer behind the window is not fully
verified.** `ni18n_k`/`pni18n`/`pni18n_f`/`pni18n_k`, added by the same
commit, are called by no test, driver check, or other line of `lib/`/`exe/`.
That is a test-parity/accountability finding, not a component-parity one —
but it is worth a pointer here since a reader of this file alone would
otherwise conclude the i18n layer is simply "done."

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
dialogs opening and closing, and (new this round) the beep/chime sound
calls — 95/95 passing, confirmed by re-running it this round (see
`TEST_PARITY.md`). None of these 95 checks assert the lap-label *text*
beyond English, so the drive suite does not and cannot catch the plural-
rendering gap above — it only ever runs in the default (English) locale.

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

## Summary: one confirmed gap, everything else located and justified

Across these five units — every window, every dialog, every menu item,
every accelerator, every window/app action — every widget, CSS class,
signal and action on upstream's side has a located counterpart in the
port. One user-visible *string behaviour* does not: the lap label's
plural dispatch (above). Every other difference found (`main_box`/
`main-box`, `var()`/`@accent_color`, direct method call vs
`activate_action`, explicit vs implicit accelerator,
`AdwPreferencesDialog`/`AdwShortcutsDialog` substitutions) is named,
located, and justified in `PORTING.md` rather than asserted and left
unlocated.

The caveat is the one `component-identification.md` already states: this is
five units read by hand, not a `component-scan.sh` diff over the whole
tree, and `Timer`/`Config` (the two remaining upstream `.rs` files) got a
lighter pass. I found nothing wrong in them either, but "I read it and it
looked right" is a weaker claim than a scan, and the ledger should say so
rather than imply otherwise.

## Round 2: tool-assisted scan, confirming the hand read

Ran `gir-symbols.sh` inside `nix develop` against the Nix store's `.gir`
files (gtk4 4.22, libadwaita 1.9), then `component-scan.sh` against a
worktree of `origin/main` and against the `ruby` tree, and diffed the two
TSVs per file-group (`window.blp`+`window.rs` → `window.rb`,
`preferences-window.blp`+`preferences_window.rs` → `preferences_dialog.rb`,
`help-overlay.blp` → `shortcuts_dialog.rb`, `app.rs` → `application.rb`).

Three apparent mismatches, all resolved by reading the flagged file rather
than being gaps:

- **`Adw.SpinRow` 4 (upstream) vs 1 (port) and `Gtk.Adjustment` 4 vs 1**:
  `preferences_dialog.rb` builds all four spin rows through one `spin_row`
  factory method; the scanner counts a shared factory's call site once,
  not once per widget it produces (`lap_row`, `short_break_row`,
  `long_break_row`, `session_count_row` each call it) — four widgets render,
  one line matched.
- **`Gtk.ShortcutsShortcut` 4 (upstream) vs `Adw.ShortcutsItem` 2 (port)**:
  same shared-factory effect — `shortcuts_dialog.rb`'s `item` helper builds
  three of the four rows (`preferences_item`, `shortcuts_item`, `quit_item`),
  and `menu_item` is built directly, so two call sites produce four items.
  The type substitution itself (`Gtk.ShortcutsWindow` → `Adw.ShortcutsDialog`)
  is the documented migration already named in `PORTING.md` and in the class
  comment of `shortcuts_dialog.rb`.
- **`signal lap`/`signal countdown-update` (upstream `window.rs`) have no
  match in `window.rb`**: upstream's `Timer` is a GObject that emits these as
  real signals; the port's `Timer` (`lib/solanum_rb/timer.rb`) is a plain
  Ruby object that takes `on_lap:`/`on_countdown:` callback procs instead —
  an intentional, documented architecture choice (no GObject subclassing
  needed for a non-widget model), not a dropped signal. `window.rb` wires
  those procs where upstream connects the signals.

Every CSS class the scan found in `window.blp`+`window.rs` (`accent`,
`blinking`, `circular`, `devel`, `dim-label`, `heading`, `large`,
`large-timer`, `main-box`, `suggested-action`, `timer-label`, `title-4`) has
an exact-name match in `window.rb`'s scan output — full CSS-class parity,
tool-confirmed rather than asserted. Every upstream action in the scanned
units (`win.skip`, `win.toggle-timer`, `win.reset`, `win.menu`,
`win.show-help-overlay`, `app.preferences`, `app.quit`) has a counterpart in
the port's scan output (`win.menu`'s role is covered by the dedicated
`MENU_ACCELERATOR` row documented above and in `shortcuts_dialog.rb`).

This closes the caveat above for the five units it already covered; `Timer`
and `Config` have no widgets, CSS, or GTK actions for `component-scan.sh` to
compare (confirmed by their absence from both scan outputs), so a GIR-based
scan has nothing further to add for those two files beyond the hand read.
