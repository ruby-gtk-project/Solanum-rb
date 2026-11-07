# Test parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `63fce02` |
| Upstream tests | 7 (4 unit tests in `src/i18n.rs` + 3 meson `test(...)` validation checks) |
| Ported | 3 |
| Gaps | 4 |
| Test command | `rake schema && rake desktop && ruby test/test_units.rb && xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb && … test/drive_devel.rb`, or just `rake test` (runs `schema`+`desktop` first) |

## This ledger was stale, and that is itself a finding

The previous version of this file (committed at `d6de8e5`, header pinned to
port sha `f8f8046`) scored `test_i18n_f` and `test_i18n_k` as gaps because at
that commit `I18n#f_` only filled one trailing `{}` and there was no `k_`
method at all. Commit `63fce02` ("Add i18n keyword interpolation and
multi-placeholder f_") landed *after* that report was written and fixed
exactly those two things — `f_` now `gsub`s every `{}` from a splat of
values, and a new `k_` fills named `{name}` slots from kwargs — and ported
the upstream multi/mid/end-placeholder and named-placeholder cases into
`test/test_units.rb`'s new "the placeholder helpers" section. Nobody
re-ran this ledger against that commit before now. A parity ledger that is
one commit behind the behaviour it is scoring is not evidence of anything;
it is read as settled by the next agent regardless, which is the same
failure `accountability-ensurance` exists to catch, just aimed at a ledger
instead of a prose excuse. See `.reports/accountability-ensurance.md` for
that finding written up properly.

The good news from re-running this pass: the two gaps the stale ledger
named are closed. The bad news, found only by reading `src/i18n.rs` line by
line against `lib/solanum_rb/i18n.rb` again rather than trusting the old
row count: **the previous ledger was also wrong about which of the four
`i18n.rs` tests had parity**, in the direction that matters — it scored two
of the four `ported`, and under this skill's own rule ("a partially-ported
test is a gap... half a test is not half a pass") none of the four
actually qualifies, because of one capability that is missing from *every
one* of them.

## I ran the suite myself, not just the ledger math

```
rake desktop                                                          (prerequisite)
ruby test/test_units.rb                                               → UNIT OK, 71 checks
rake schema                                                           (prerequisite)
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb     → 93 of 93 checks passed, DRIVE OK
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_devel.rb       → 8 of 8 checks passed, DRIVE OK
rake validate                                                         → schema/desktop/appstream all pass
```

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

**Behaviour still owed (all four rows, the one gap behind them):** a
string that has no translation loaded — a cold start, an unsupported
locale, `LANG=C` — and whose upstream source picks between two different
English sentences depending on a count (an upstream `ngettext`/`npgettext`
call with genuinely different singular/plural wording) would render the
*singular* wording in this port no matter what the count is, because there
is no method in `lib/solanum_rb/i18n.rb` that even takes two forms. Right
now Solanum's own single plural string (`"Lap {}"`/`"Lap {}"`) happens to
use identical wording for both forms — recorded correctly as a
correspondence in `PORTING.md` and in `TRANSLATION_PARITY.md` — so this has
not produced a visible bug in today's four-string catalogue. It would
produce one the moment anybody adds a plural string to this app whose
English wording actually differs between the two forms, English locale and
all, and nothing in the test suite would catch it, because the capability
the test would need to exist to drive isn't there yet to write a test
against.

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
- `test/drive_solanum.rb` — 93 checks driving the real window: the full
  lap/break cycle, pause/resume, reset, live preference changes,
  fullscreen-on-break, the large-text breakpoint, all three dialogs, the
  five app actions, the three accelerators, the lap-change notifications,
  and `app.skip`.
- `test/drive_devel.rb` — 8 checks on the devel-profile window and its about
  dialog (striped header, suffixed id, devel icon, commit-stamped version).

172 of the port's own checks, genuinely run and genuinely green, and still
not the same claim as 7/7 upstream. The count went up (71 vs the previous
pass's 45, from the newly-ported placeholder cases) while the upstream
parity fraction went *down* (3/7 vs the stale ledger's claimed 5/7), because
reading the file again found a wider gap than the last pass reported, not a
narrower one.
