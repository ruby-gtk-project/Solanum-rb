# Component identification — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `0590067` |

Re-checked this round against `0590067`, one commit past the sha
(`6bfc160`) this file was last pinned to. That commit closes this file's own
previous finding (below) — re-verified, not re-derived from scratch, since
the file map and unit boundaries are unchanged (confirmed: `git show --stat
0590067` touches only `lib/solanum_rb/i18n.rb`, `lib/solanum_rb/window.rb`
and `test/test_units.rb`, none of which adds, removes or moves a unit).

## The file map (re-confirmed against `origin/main`)

```sh
git ls-tree -r --name-only origin/main | grep -E '\.(rs|blp|ui)$'
```

returns exactly: `src/main.rs`, `src/app.rs`, `src/window.rs`, `src/timer.rs`,
`src/preferences_window.rs`, `src/i18n.rs`, `src/config.rs`,
`data/ui/window.blp`, `data/ui/preferences-window.blp`,
`data/gtk/help-overlay.blp`. Every one has a named counterpart in
`PORTING.md`'s file map and in `lib/solanum_rb/*.rb`. No upstream window,
dialog or shortcuts surface is missing a port file.

Also present on the upstream side but easy to miss in a `.rs`/`.blp`-only
grep, and confirmed carried: `data/org.gnome.Solanum.gschema.xml` →
`data/org.gnome.Solanum.Rb.gschema.xml` + `lib/solanum_rb/settings.rb`;
`data/org.gnome.Solanum.metainfo.xml.in.in` → `lib/solanum_rb/appdata.rb`;
`data/ui/style.css` → `data/style.css`; the two `.ogg` sounds + GstPlay
wiring → `lib/solanum_rb/sound.rb`; and the full `po/` catalogue (47
locales, `LINGUAS`, `POTFILES.in`) — all tracked under `ruby`.

## Units identified (5 widget-bearing units + the i18n/config support layer)

1. **Application shell** — `src/app.rs` + `src/main.rs` → `application.rb` +
   `exe/solanum-rb` + `about_dialog.rb`. Actions: `about`, `preferences`,
   `quit`, `toggle-timer`, `skip`. Accels: `<Primary>comma`, `<Primary>q`,
   plus the hand-added `<Primary>question` for the shortcuts dialog (no
   upstream `set_help_overlay` hook exists in the Ruby bindings for
   `Adw.ShortcutsDialog`, documented in `window.rb`).
2. **Main window** — `src/window.rs` + `data/ui/window.blp` → `window.rb`.
   Widget tree, 4 window actions (`win.toggle-timer`, `win.reset`,
   `win.skip`, `win.show-help-overlay`), the breakpoint, the primary menu
   (3 items + reset), the notification flow, the stylesheet classes.
3. **Timer** — `src/timer.rs` → `timer.rb`. Deliberately not a GObject (see
   `PORTING.md`); countdown/lap behaviour only, no widget.
4. **Preferences** — `src/preferences_window.rs` +
   `data/ui/preferences-window.blp` → `preferences_dialog.rb`. 5 bound rows,
   `Adw.PreferencesDialog` instead of the deprecated `Adw.PreferencesWindow`.
5. **Shortcuts** — `data/gtk/help-overlay.blp` → `shortcuts_dialog.rb`.
   `Adw.ShortcutsDialog` instead of the deprecated, Ruby-unconstructable
   `Gtk.ShortcutsWindow`.

Support layer (not independently widget-bearing, but user-visible through
the units above): `config.rb`, `i18n.rb`, `appdata.rb`, `paths.rb`,
`settings.rb`, `sound.rb`.

## What this pass explicitly did not re-run

- `component-scan.sh` (the GI-symbol-level scanner) was not re-run this
  round. The commits since the last scan (`bafffba` rewriting
  `component-inventory.md`'s prose, `3164e13` adding `po/POTFILES.in`,
  `6bfc160` adding sound assertions to the drive script) touch no widget,
  signal, action or CSS class in any of the five units above — confirmed by
  reading each diff (`git show --stat`) rather than assumed. Flagging this
  explicitly per the skill's own rule about naming what was not re-run
  rather than implying blanket freshness.
- Screenshot-level rendering confirmation (skill step 4/5) is not redone
  here; it is exercised by the drive scripts, which this round re-ran live
  (95/95 + 8/8, DRIVE OK twice) — see `.reports/TEST_PARITY.md`.

## Previous finding, now closed: all 12 upstream `i18n.rs` symbols have a port counterpart

Last round: upstream's `src/i18n.rs` exports 12 wrapper functions (`i18n`,
`i18n_f`, `i18n_k`, `ni18n`, `ni18n_f`, `ni18n_k`, `pi18n`, `pi18n_f`,
`pi18n_k`, `pni18n`, `pni18n_f`, `pni18n_k`); `lib/solanum_rb/i18n.rb`
implemented 4 (`_`, `f_`, `k_`, `p_`), missing the entire plural-dispatch
family.

`0590067` adds the other 8 (`ni18n`, `ni18n_f`, `ni18n_k`, `pi18n_f`,
`pi18n_k`, `pni18n`, `pni18n_f`, `pni18n_k` — `pi18n` itself maps onto the
pre-existing `p_`). Re-read `lib/solanum_rb/i18n.rb` this round and confirmed
all 12 upstream symbols now have a named counterpart by signature and
purpose. This closes the identification-level gap.

**This is identification, not verification, and this round that gap between
the two is the whole story.** A symbol existing with the right name and the
right arity is not the same claim as "it was exercised" or "it works" — see
`.reports/TEST_PARITY.md` and `.reports/accountability-ensurance.md`:
`ni18n_k`, `pni18n`, `pni18n_f` and `pni18n_k` are present but called by
nothing in `lib/`, `test/` or `exe/`, and `ni18n`/`ni18n_f` — the two that
*are* exercised by a test — turn out, on tracing, to never actually read the
behaviour their names promise (the catalogue's own `Plural-Forms` header is
silently dropped before the plural-dispatch code ever sees it). 12/12
symbols present is true and is the limit of what this skill can state;
naming that limit here too since a reader of only this file would otherwise
read "12/12 symbols present" as "12/12 done."
