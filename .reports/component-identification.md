# Component identification — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `f8f8046` |

## What already exists

`.reports/component-inventory.md` (166 lines, last written at `914e699`/`9988755`)
already does a per-file inventory of all six upstream units — `app.rs`,
`window.rs` + `window.blp`, `timer.rs`, `preferences_window.rs` +
`preferences-window.blp`, `help-overlay.blp`, and the `AboutWindow::from_appdata`
call — against the six port files. Re-deriving that whole document here would
duplicate it; this report records what I independently re-verified by reading
upstream and the port side by side, and — this is the part the existing
document does not cover — what it admits it never checked.

## The file map (re-confirmed against `origin/main`)

```sh
git ls-tree -r --name-only origin/main | grep -E '\.(rs|blp|ui)$'
```

returns exactly: `src/main.rs`, `src/app.rs`, `src/window.rs`, `src/timer.rs`,
`src/preferences_window.rs`, `src/i18n.rs`, `src/config.rs`,
`data/ui/window.blp`, `data/ui/preferences-window.blp`,
`data/gtk/help-overlay.blp`. Every one of these has a named counterpart in
`PORTING.md`'s file map and in `lib/solanum_rb/*.rb`. No upstream unit — no
window, no dialog, no shortcuts surface — is missing a port file.

## Per-unit widget read (window, preferences, shortcuts, about, app)

I read `data/ui/window.blp` against `lib/solanum_rb/window.rb` widget by
widget: `Adw.ApplicationWindow`/`Adwaita::ApplicationWindow` (title, icon,
default size 360×360, height-request 294, default-widget), `Adw.ToolbarView`,
`Adw.HeaderBar` (`show-title: false`), the vertical `Gtk.Box` (`main-box`/
`main-box` — see translation-parity's css note), `lap_label`
(`heading`,`dim-label`), `timer_label` (`timer-label`,`accent`,`blinking`),
the `Gtk.CenterBox`, `timer_button`/`skip_button` (`circular`,`large`,
(+`suggested-action` on the timer button)), `menu_button` (`circular`,
`primary: true`), and the `Adw.Breakpoint` at `min-width: 800sp and
min-height: 800sp`. All present, same CSS classes, same action names
(`win.toggle-timer`, `win.skip`, `win.reset`, `win.show-help-overlay`),
same menu structure (two sections: reset alone, then preferences/shortcuts/
about).

Did the same for `data/ui/preferences-window.blp` → `preferences_dialog.rb`
(5 rows: 3 spin rows + session-count spin + fullscreen switch, same titles,
same GSettings bindings), `data/gtk/help-overlay.blp` →
`shortcuts_dialog.rb` (4 items + the un-actioned "Show Primary Menu" row,
all under the `"shortcut window"` msgctxt), and the `show_about` body of
`src/app.rs` → `about_dialog.rb` (developers, the two funding links, the
three credit/acknowledgement sections, `translator-credits`). I found no
widget, CSS class, signal, or action present on one side and absent on the
other for any of these five units.

## Round 2: the scan ran

The gap this section used to describe is closed. I built the GI symbol
table with `gir-symbols.sh` inside `nix develop` (against the Nix store's
gtk4 4.22 / libadwaita 1.9 `.gir` files), ran `component-scan.sh` against
both a worktree of `origin/main` and the `ruby` tree, and diffed the two
TSVs per mapped file group. The reconciliation, including the three
apparent widget/signal mismatches the diff raised and how each resolved by
reading the flagged file (shared-factory undercounting in both spin rows
and shortcuts items; `Timer`'s GObject signals vs the port's plain-Ruby
callback procs), is recorded in `.reports/COMPONENT_PARITY.md`'s "Round 2:
tool-assisted scan, confirming the hand read" section rather than repeated
here.

`src/timer.rs` and `src/config.rs` still got a lighter read than the five UI
units in the sense that I did not re-derive their Rust line by line — but
`component-scan.sh`'s own output, run against both trees, confirms they
produce zero widget/CSS/signal/action rows on either side (there is nothing
for the scanner to find: neither file touches a GTK type), so there is no
tool-assisted check left undone for them; a scan has nothing further to add
beyond `PORTING.md`'s description of the `Timer`/`Config` correspondences.
