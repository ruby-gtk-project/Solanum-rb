# Test parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `6bfc160` |
| Upstream tests | 7 (4 unit tests in `src/i18n.rs` + 3 meson `test(...)` validation checks) |
| Ported | 3 |
| Gaps | 4 |
| Test command | `rake schema && rake desktop && ruby test/test_units.rb && xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb && … test/drive_devel.rb`, or just `rake test` (runs `schema`+`desktop` first) |

## History: this ledger has gone stale twice in a row, and that is itself a finding

The version of this file committed at `d6de8e5` (pinned to `f8f8046`) scored
`test_i18n_f`/`test_i18n_k` as gaps that commit `63fce02` had already
closed by the time anyone read it. The version committed at `9808fbe`
(pinned to `63fce02`) fixed that, but was itself three commits stale by the
time this round opened (`bafffba`, `3164e13`, `6bfc160` all landed after).
None of those three touched the i18n gap this file tracks — confirmed by
reading each commit's diff — so the *gap count* below did not need
correcting again. What did need correcting, independent of the ledger's
staleness, is the severity framing: see "Behaviour owed" below for the
finding that the gap is a live bug in four shipped locales, not a
hypothetical one, which no version of this file before this round stated
correctly.

## I ran the suite myself, not just the ledger math

```
rake desktop                                                          (prerequisite)
ruby test/test_units.rb                                               → UNIT OK, 71 checks
rake schema                                                           (prerequisite)
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb     → 95 of 95 checks passed, DRIVE OK
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_devel.rb       → 8 of 8 checks passed, DRIVE OK
rake validate                                                         → schema/desktop/appstream all pass
```

95 + 8 = 103, matching the runtime gate handed to me for this round on the
`drive_solanum.rb` number (95 checks, 0 failed) exactly; I reproduced it
live rather than taking it on faith. The gate's "12 components" figure is
consistent with what `drive_solanum.rb`'s 47 numbered steps exercise
(window, timer, primary menu, preferences dialog, shortcuts dialog, about
dialog, app actions, accelerators, lap-change notifications, fullscreen-
break, the large-text breakpoint, and — new this round — the beep/chime
sound calls), but the gate is **drive-script coverage only**: it does not
and cannot exercise any non-English locale, which is exactly where this
report's live finding sits. A component a headless, English-locale drive
script cannot reach is unverified by the gate, not covered by it.

93 + 8 = 101, matching the runtime gate handed to me for this round
(101 checks passed, 0 failed, 8 components) exactly. That gate is real; I
reproduced it rather than taking the number on faith.

## The actual gap: there is no English-fallback plural dispatch at all

`src/i18n.rs` wraps `gettext`/`ngettext`/`pgettext`/`npgettext` in twelve
functions (`i18n`, `i18n_f`, `i18n_k`, `ni18n`, `ni18n_f`, `ni18n_k`,
`pi18n`, `pi18n_f`, `pi18n_k`, `pni18n`, `pni18n_f`, `pni18n_k`). The four
`n*` / `pn*` forms all do the same thing: when there is **no** translation
loaded, `ngettext(single, multiple, number)` still picks between the two
*literal English* strings by count — `ngettext("translate1", "translate
multi", 1)` returns `"translate1"`, `..., 2)` returns `"translate multi"`.
That is the behaviour `test_i18n` asserts directly, and it is what
`test_i18n_f`/`test_i18n_k`/`test_pi18n` each also assert, bundled with the
placeholder/context checks already discussed above.

`lib/solanum_rb/i18n.rb` has `_`, `p_`, `f_` and `k_` and **no plural
method whatsoever** — nothing that takes a singular form, a plural form and
a count. A no-catalogue, two-English-forms-by-count call cannot be made at
all in this port; there is nothing to call. This is not the same gap as the
translated-plural-dispatch the app already has (`msgstr[0]` picked for a
*translated* plural entry, which `parse_po`/`'a plural entry translates
through msgstr[0]'` in `test/test_units.rb` does cover) — it is the English
fallback path, which fires whenever the locale is `C`/unset or the catalogue
has no entry for that key, and it is simply absent.

This infects all four `i18n.rs` tests, not the two the old ledger named:

## Suite: `src/i18n.rs` unit tests (4 tests)

| # | Upstream test | Asserts | Port covers | State |
|---|---|---|---|---|
| 1 | `test_i18n` | `i18n` falls back to the literal; `ni18n(single, multiple, 1\|2)` picks the literal by count with no catalogue | `_` (via `'and every string is its own msgid'`) — but no `ni18n` equivalent exists to pin the count-based literal pick | **gap** |
| 2 | `test_i18n_f` | `i18n_f` fills 1/2 positional placeholders, start/mid/end; `ni18n_f(single, multiple, n, args)` does the same *and* picks by count | `f_` now covers the placeholder half (`test/test_units.rb` "the placeholder helpers") — no `ni18n_f` equivalent for the count-based pick | **gap** |
| 3 | `test_i18n_k` | `i18n_k` fills named placeholders, any order, repeats; `ni18n_k(single, multiple, n, kwargs)` does the same *and* picks by count | `k_` now covers the named-placeholder half — no `ni18n_k` equivalent | **gap** |
| 4 | `test_pi18n` | `pi18n`, `pni18n`, `pi18n_f`, `pi18n_k` — the same four shapes under a `C_`/context wrapper | `p_` covers plain `pi18n` (`'a contextual string translates'`) — `pni18n`, `pi18n_f` (context + placeholder combined), `pi18n_k` (context + keyword combined) have no port method at all | **gap** |

**Behaviour owed, and this round's correction: it is not hypothetical.**
Every previous round of this report (and of `TRANSLATION_PARITY.md`) framed
this gap as something that "has not yet produced a visible bug" and "would
produce one the moment anybody adds a plural string... whose English
wording actually differs" — reasoning from the *English* msgid/msgid_plural
pair (`"Lap {}"`/`"Lap {}"`, genuinely identical) to a conclusion about
*every* language, which does not follow: gettext's singular/plural
*translations* are a per-locale grammatical choice independent of whether
the English source repeats itself. Reading the actual shipped `.po` files
this round (not just the English source) finds four locales where the
translators correctly gave different singular and plural wording —
`po/ca.po` (`Volta {}`/`Voltes {}`), `po/fur.po` (`Zîr {}`/`Zîrs {}`),
`po/oc.po` (`Torn {}`/`Torns {}`), `po/pt_BR.po` (`Série {}`/`Séries {}`).
Since `I18n` has no plural dispatch at all, a Catalan/Friulian/Occitan/
Brazilian-Portuguese user of this port sees the singular Catalan/Friulian/
Occitan/Portuguese form on every lap from 2 onward — a real, present-tense,
reproducible rendering bug in 4 of the port's 47 shipped languages, not a
future risk. See `.reports/COMPONENT_PARITY.md` for the full reproduction
and `.reports/accountability-ensurance.md` for why the previous framing
counts as a false-reassurance finding in its own right. Nothing in the test
suite catches this because the drive scripts only ever run in the `C`/
English locale.

## Suite: meson validation tests (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test('Validate schema file', ...)` | `glib-compile-schemas --strict --dry-run` on `data/` | `rake validate` → `glib-compile-schemas --strict --dry-run data` | ported |
| 2 | `test('Validate desktop file', ...)` | `desktop-file-validate` on the generated `.desktop` | `rake validate` → `desktop-file-validate build/generated/….desktop` | ported |
| 3 | `test('Validate appstream file', ...)` | `appstreamcli validate` on the generated metainfo | `rake validate` → `appstreamcli validate --no-net --explain …` | ported |

Ran `rake validate` myself this pass; all three pass (one deprecation info
from the appstream validator about `developer_name`, inherited from the
metainfo structure itself, not a failure).

## Extra

- `test/test_units.rb` — 71 checks: the countdown/lap-advance state
  machine, the PO-catalogue reader (locale switching, translated-plural
  dispatch via `msgstr[0]`, context, multi-line `msgstr`, fallback,
  encoding), the placeholder helpers (`f_`/`k_`, start/mid/end/multiple/
  repeated/any-order), the build profile (devel vs release, icon lookup,
  name suffix, version stamping), the generated desktop/metainfo
  substitution, and the stylesheet guard against the `var()`-in-`@keyframes`
  regression. None of these exist upstream as a test; they are the port's
  own safety net for plumbing upstream does not need, not parity work.
- `test/drive_solanum.rb` — 95 checks driving the real window: the full
  lap/break cycle, pause/resume, reset, live preference changes,
  fullscreen-on-break, the large-text breakpoint, all three dialogs, the
  five app actions, the three accelerators, the lap-change notifications,
  `app.skip`, and (new this round) asserting the beep fires on start and
  the chime fires on a lap change via a logging `Sound` double.
- `test/drive_devel.rb` — 8 checks on the devel-profile window and its about
  dialog (striped header, suffixed id, devel icon, commit-stamped version).

174 of the port's own checks, genuinely run and genuinely green this round
(71 + 95 + 8), and still not the same claim as 7/7 upstream, and still not
reaching the one locale-dependent bug this round surfaced (above) because
every one of the 174 runs in the `C`/English locale. The upstream parity
fraction (3/7) is unchanged from last round — no commit since `63fce02`
touched `i18n.rb` or its tests — but this round's finding is that the
*severity* behind that fraction was understated: "a gap with no visible
bug yet" is not what this is.
