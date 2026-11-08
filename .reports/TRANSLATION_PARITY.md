# Translation parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `0590067` |
| Upstream messages | 44 (distinct `(msgctxt, msgid)` keys; see methodology note below) |

**Re-checked this round against `0590067`**, one commit past the sha
(`6bfc160`) this ledger was last pinned to. That commit implements
`ni18n`/`ni18n_f`/`ni18n_k`/`pi18n_f`/`pi18n_k`/`pni18n`/`pni18n_f`/
`pni18n_k` in `lib/solanum_rb/i18n.rb` and rewires `window.rb`'s lap label
to call `ni18n_f`, which is **this ledger's own previous finding, fixed**:
`I18n` can now select `msgstr[1]` (or whichever index a catalogue's own
`Plural-Forms` rule picks) for a plural entry, instead of always reading
`msgstr[0]`.

**What this ledger checks, and what it does not.** The *key axis* — does
every upstream `(msgctxt, msgid)` exist in `po/*.po`, and only those keys —
is 44/44, 0 gaps, 0 extra, genuinely, and was never in question (the plural
gap was always a dispatch-code gap, not a missing-key gap). I re-ran the
fix this round rather than taking the commit message at its word:

```sh
$ nix develop --command xvfb-run -a ruby -r./lib/solanum_rb -e '
  ENV["LANGUAGE"]="ca"; SolanumRb::I18n.reset!
  puts SolanumRb::I18n.ni18n_f("Lap {}", "Lap {}", 1, 1)
  puts SolanumRb::I18n.ni18n_f("Lap {}", "Lap {}", 2, 2)'
Volta 1
Voltes 2
```

Catalan (and, by the same code path, `fur`/`oc`/`pt_BR`) now renders the
plural `msgstr` from lap 2 onward, matching upstream's visible output. The
previously-reported rendering bug in those four locales is closed **as a
rendering outcome**.

**It is not closed as a mechanism, and that distinction matters for this
ledger specifically.** `.reports/TEST_PARITY.md` traces the code and finds
that `plural_rule` never actually reads any catalogue's `Plural-Forms`
header — `store` discards the PO header entry (`msgid ""`) for every
locale before it reaches the catalogue hash, so `ni18n_f` always falls back
to English's hardcoded binary rule. The four locales render correctly only
because their real plural rules happen to coincide with that hardcoded
fallback — not because their `Plural-Forms` header was read and honoured.
Translation-parity's own job (does every msgid/msgstr exist, correctly) is
still done — the `.po` files themselves are correct and complete — but this
ledger would be overstating the finding to call the *dispatch* fixed. It is
closed for the one string this app currently has; the mechanism that would
keep it closed for the next plural string in a 3-or-4-form locale (`be`,
`cs`, `hr`, `pl`, `ro`, `ru`, `he`, `sl`, `sr`, `uk` — 10 of 47 shipped
locales) does not exist yet. See `.reports/TEST_PARITY.md` for the full
trace, including a second, independent defect found in the (currently
unreachable) plural-rule expression compiler itself. Separately, four of
the eight new wrapper methods (`ni18n_k`, `pni18n`, `pni18n_f`, `pni18n_k`)
are called by no test anywhere.
| Port messages | 44 |
| Gaps | 0 |
| Extra | 0 |
| Languages | 47 upstream, 47 port (byte-identical `po/*.po`, `LINGUAS` matches both) |

## The scanner in `.claude/skills/translation-parity/scripts/msgid-census.sh` undercounts this app — by nearly all of it

This is the headline finding, and it is exactly the kind of false-green risk
`accountability-ensurance` exists to catch, so it goes first.

Running the skill's own script as documented:

```sh
scripts/msgid-census.sh <upstream-tree>
```

returns **zero** rows from `src/app.rs`, `src/window.rs`,
`src/preferences_window.rs`, `src/config.rs`, and `src/main.rs` combined —
every upstream `.rs` file *except* `src/i18n.rs`, and even there the only
twelve rows it finds are `!unresolved` matches against the *implementation*
of the wrapper functions (`src/i18n.rs`'s own `gettext(format)` /
`ngettext(single, multiple, number)` source text), not real call sites.

The reason: Solanum's upstream is a GNOME Rust app, and like most of them it
wraps gettext in its own `i18n`/`i18n_f`/`i18n_k`/`ni18n`/`ni18n_f`/
`ni18n_k`/`pi18n`/`pi18n_f`/`pi18n_k`/`pni18n*` functions (boilerplate from
the GNOME Rust app template, see `src/i18n.rs`). The census script's marker
list is `_, N_, C_, NC_, ngettext, n_, Nn_, p_, np_, s_, pgettext` — the
*standard* gettext call names. It does not know the `i18n*` family at all.
Every real translatable string in every `.rs` file in this app's `src/` is
called through that family, so the script sees **none of them**. Only the
three `.blp` files (which use plain `_()`/`C_()`) and the `.desktop.in.in`/
`.metainfo.xml.in.in`/`.gschema.xml` sources (read by field name, not by
marker) are counted correctly.

Taken at face value, a run of this script would report upstream's catalogue
at 29 messages (the `.blp`/data-file set only) and would then score every
one of the port's genuinely-ported `.rs`-sourced strings — `"Solanum"`,
`"translator-credits"`, the two funding links, the three credit sections,
`"Long Break"`/`"Short Break"`, `"Lap {}"`, and all seven notification
strings — as **unexplained extras nobody asked for**, when every one of
them is a real, correctly-ported translation of a real upstream string.
That is a false gap report and a false extra report at the same time, on
the single largest slice of this app's catalogue, produced by trusting the
tool's raw output instead of opening the files it claims are empty.

**I fixed this by hand** rather than editing the YAML (there is no YAML
here — `catalogue.rb` was not run, for the same reason): I grepped
`src/*.rs` directly for the `i18n`/`ni18n`/`i18n_f` family, discarded the
matches inside `src/i18n.rs`'s own `#[cfg(test)] mod tests` block (unit
tests of the wrapper itself — `"translate1"`, `"{} param"`, etc. — not
app strings), and reconciled every remaining literal against the port by
hand. The counts and tables below are the result. **This script needs the
`i18n*` family added to its marker list** — it is a few characters of regex,
per the skill's own note on where scanner defects get fixed, and until that
lands, this app's translation parity cannot be run from the script alone.

## The reconciled catalogue (44 messages)

From `.blp`/data files (scanner-correct, 29 messages, including the 5 under
`msgctxt "shortcut window"`): `_About Solanum`, `Balance working time and
break time`, `Christopher Davis`, `Fullscreen During Breaks`,
`_Keyboard Shortcuts`, `Lap Length`, `Long Break Length`, `Main Menu`,
`Pomodoro;Timer;Productivity;`, `_Preferences`, `Reset Sessions`,
`Session Length`, `Sessions Until Long Break`, `Short Break Length`, `Skip`,
`Solanum` (×2 sites, one key), `Solanum is a time tracking app…`,
`The length of a long/short break in minutes.` (×2), `The length of a work
lap in minutes.`, `The length of each session type in minutes. Changes
apply to the next session of each type.`, `The number of sessions until a
long break.`, `Toggle Timer`, `Whether the window should fullscreen during
breaks.`, and `shortcut window / {General Shortcuts, Quit, Show Keyboard
Shortcuts, Show Preferences, Show Primary Menu}`.

From `.rs` files, hand-censused (15 new messages beyond the above —
`"Solanum"` and `"Skip"` are shared keys already counted): `translator-credits`,
`_Donate on Patreon`, `_Sponsor on GitHub`, `Icon by`, `Sound by`,
`Supported by`, `Long Break`, `Short Break`, `Back to Work`, `Ready to keep
working?`, `Start Working`, `Break Time`, `Stretch your legs, and drink some
water.`, `Start Break`, `Lap {}` (upstream: `ni18n_f("Lap {}", "Lap {}", n,
…)` — singular and plural msgids are identical, per the translator comment
in `src/window.rs`: "Lap is always singular").

29 + 15 = **44**, and every one of them has a located, byte-identical
counterpart in the port — I read each port call site (`lib/solanum_rb/*.rb`)
against the upstream one above; none is reworded, retyped, or unmarked.

## Two things that look like gaps in the port's own census and are not

1. **`p_(CONTEXT, 'General Shortcuts')` et al. in `shortcuts_dialog.rb`**
   census as `!unresolved`, because `CONTEXT` is a frozen Ruby constant
   (`'shortcut window'`), not a string literal, at the call site. Read by
   hand, `CONTEXT` is always `'shortcut window'`, and the five messages this
   produces (`General Shortcuts`, `Show Primary Menu`, `Show Preferences`,
   `Show Keyboard Shortcuts`, `Quit`) are exactly upstream's five
   `"shortcut window"`-context messages, byte-identical.
2. **`"Solanum@NAME_SUFFIX@"`** censuses as an extra message from the raw
   `data/org.gnome.Solanum.Rb.desktop.in` template — upstream's template has
   the plain literal `Name=Solanum`. This looks like a reworded/retyped
   string, which the `component-parity`/`translation-parity` skills both
   call a gap on sight. It is not: `scripts/merge_translations.rb#lookup_key`
   explicitly strips `@NAME_SUFFIX@` *before* the catalogue lookup
   (`value.sub('@NAME_SUFFIX@', '')`) and reappends it after substitution
   (`suffix_of`), so the actual gettext lookup key used at build time is
   `"Solanum"` — the same key upstream's translators translated. I confirmed
   this by reading `merge_translations.rb` itself, not by assuming it from
   the variable name.

## Languages and catalogues

```sh
diff <(ls up/po/*.po | xargs -n1 basename) <(ls po/*.po | xargs -n1 basename)   # empty
diff -rq up/po po                                                               # only meson.build, POTFILES.in differ (build-only files)
```

All 47 `.po` files upstream ships are present in the port, byte-identical,
and `po/LINGUAS` matches the file listing on both sides exactly (47 == 47,
no stray entries either direction).

**Correction (this round):** the previous version of this note said the
port "ships no `.pot`/`POTFILES.in`... so there is nothing to diff there".
That is no longer true — `po/POTFILES.in` was added in `3164e13`, after
this ledger was last written, listing the six Ruby sources
(`about_dialog.rb`, `preferences_dialog.rb`, `shortcuts_dialog.rb`,
`window.rb`) and two generated-template inputs
(`org.gnome.Solanum.Rb.desktop.in`, `org.gnome.Solanum.Rb.metainfo.xml.in`)
that carry translatable strings, mirroring upstream's eight-entry
`po/POTFILES.in`. Confirmed this round: every file it lists is a real
source of a translated string (`application.rb`, `timer.rb` and
`config.rb` — the three `.rb` files it omits — have no `_`/`p_`/`f_`/`k_`
call anywhere), and nothing in `rake`/`test/` reads `POTFILES.in` (there is
still no `xgettext` step; `I18n` reads `po/*.po` directly, as before). It
is documentation that now matches upstream's shape rather than a load-
bearing file, and was untested before and after — not a gap, since nothing
depends on it, but noted for completeness since this report is in the
business of saying what is and is not exercised.

## Stylesheet-side classes (the other half of the text/style boundary)

Not this skill's axis, but worth stating once since it was checked for
`component-parity`: `data/style.css`'s `.main_box`/`.main-box` fix and the
`var()`/`@accent_color` substitution are rule changes, not catalogue
changes — no msgid lives in CSS — and both are documented in `PORTING.md`.

## Verdict

0 gaps, 0 extras, 47/47 languages on the key axis — every upstream
`(msgctxt, msgid)` exists, correctly, in `po/*.po` — once the census is
corrected for the upstream app's `i18n*` wrapper convention by hand. Running
the shared script as-is and trusting its output would have produced a wrong
report in both directions at once; that correction, not the script's raw
numbers, is what this report's "0 gaps" rests on.

This is **not** a verdict on whether the shipped msgids are reliably
selected at runtime. See this round's correction above and
`.reports/TEST_PARITY.md`/`.reports/accountability-ensurance.md`: the
plural-dispatch mechanism added this round does not read any catalogue's
own `Plural-Forms` header, so a key existing correctly in `po/ru.po` is not
yet proof that the port will ever select the right form of it. That is a
test-parity/component-parity finding, not a translation-parity one — the
keys are genuinely all there — but a reader stopping at this file's "0
gaps" would miss it, so it is named here too.
