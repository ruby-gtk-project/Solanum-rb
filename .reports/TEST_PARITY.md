# Test parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `0590067` |
| Upstream tests | 7 (4 unit tests in `src/i18n.rs` + 3 meson `test(...)` validation checks) |
| Ported | 4 |
| Gaps | 3 |
| Test command | `rake schema && rake desktop && ruby test/test_units.rb && xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb && … test/drive_devel.rb`, or just `rake test` (runs `schema`+`desktop` first) |

## This round's headline finding: the one new test that was supposed to prove the previous gap closed is a false green

The ledger at `10a0b2f` (pinned to `6bfc160`) scored all four `src/i18n.rs`
unit tests as gaps, because `lib/solanum_rb/i18n.rb` had no plural-dispatch
method at all. Commit `0590067`, landed after that ledger, implements eight
new methods, rewires `window.rb`'s live lap label to `ni18n_f`, and adds a
unit test — `'count 1 renders the singular form'` / `'count 2 renders the
plural form'` against `ca.po` — specifically to prove the catalogue's own
`Plural-Forms` header now drives the dispatch instead of English's hardcoded
rule. **I traced that test's own code path by hand, and it does not test
what it claims to.**

`plural_rule` reads the header via `catalogue['']` (the PO header entry has
`msgid ""`). `store`, the function that populates the catalogue hash from a
parsed entry, has an unrelated, pre-existing guard:

```ruby
usable = !entry[:fuzzy] && !entry[:msgid].empty? && entry[:msgstrs].values.any? { |form| !form.empty? }
```

`entry[:msgid].empty?` is `true` for the header entry by definition (its
`msgid` *is* the empty string) — so `usable` is always `false` for it, and
**the header entry is never stored in the catalogue, for any language, ever.**
Confirmed directly for the four locales that matter most to this finding:

```sh
$ cat tmp/checkbug.rb  # (ad hoc, removed after use)
require_relative '../lib/solanum_rb'
["ru", "ca", "pl", "uk"].each do |loc|
  ENV["LANGUAGE"] = loc
  SolanumRb::I18n.reset!
  cat = SolanumRb::I18n.send(:catalogue)
  puts "#{loc}: has empty-key header? #{cat.key?('')}  plural_rule=#{SolanumRb::I18n.send(:plural_rule).inspect}"
end
$ nix develop --command xvfb-run -a ruby tmp/checkbug.rb
ru: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
ca: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
pl: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
uk: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
```

Every locale, including `ru` (`Plural-Forms: nplurals=3; ...`) and `uk`
(`nplurals=4`), reports `plural_rule` as `{nplurals: 2, proc: <English's
n==1?0:1>}` — the hardcoded `ENGLISH_PLURAL_RULE` fallback, because
`parse_plural_forms(nil)` always takes that branch. **The `PluralExpr`
recursive-descent compiler this commit added — the thing the commit message
says is the fix — is never reached by any locale, including the one the new
test exercises.** The new test passes only because Catalan's actual rule
(`n != 1`) happens to be mathematically identical to English's hardcoded
`n == 1 ? 0 : 1` for every non-negative integer — the test cannot distinguish
"read the catalogue's own rule" from "always use English's rule regardless of
catalogue," because for `ca.po` those two give the same answer.

I confirmed this is not merely academic by evaluating the (unreachable, but
still present and shipped) `PluralExpr` output directly against Russian's
real header string, and it is independently broken on its own terms —
`n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 || n%100>=20) ?
1 : 2` should give `0,1,1,1,2,2,0,1,2,0,2,0` for `n =
1,2,3,4,5,11,21,22,25,101,111,121`; calling the compiled proc directly gives
`0,1,1,1,1,1,1,1,1,1,1,1` — right only for `n ∈ {1,2,3,4}`, wrong for every
other value tried, including the ones (`n=21`, `n=101`, `n=121`) that should
map back to index 0. So even if the `store` bug above is fixed, the compiler
itself has a second, independent defect for this specific three-branch
nested-ternary shape — and nothing in the shipped test suite would catch
either bug, because the one test added to cover this feature never reaches
either piece of broken code.

**Current real-world impact is zero** only by coincidence: every shipped
`.po` file gives textually identical `msgstr[N]` forms for `"Lap {}"` in
every locale except `ca`/`fur`/`oc`/`pt_BR` (whose real rules happen to
equal English's), so the always-English fallback currently renders the same
visible text a correct implementation would. The moment any future plural
string gets genuinely different wording in a 3-or-4-form locale (10 of the
47 shipped languages: `be`, `cs`, `hr`, `pl`, `ro`, `ru`, `he`, `sl`, `sr`,
`uk`), this renders the wrong grammatical form silently, with a green test
suite the whole time. This is the exact "coincidentally not yet visible"
shape that sank the *previous* round's reports (see
`accountability-ensurance.md`) — recurring in the code that was written to
fix that very finding.

**Separately, and smaller:** four of the eight new methods —
`ni18n_k`, `pni18n`, `pni18n_f`, `pni18n_k` — are called from **no test, no
driver check, and no other line of `lib/` or `exe/`**, confirmed by:

```sh
$ grep -rn "ni18n_k\|pni18n\|pi18n_f\|pi18n_k" lib/ test/ exe/
lib/solanum_rb/i18n.rb:51:    def ni18n_k(single, multiple, number, **kwargs) = ...
lib/solanum_rb/i18n.rb:55:    def pi18n_f(context, text, *values) = ...
lib/solanum_rb/i18n.rb:57:    def pi18n_k(context, text, **kwargs) = ...
lib/solanum_rb/i18n.rb:60:    def pni18n(context, single, multiple, number)
lib/solanum_rb/i18n.rb:64:    def pni18n_f(context, single, multiple, number, *values)
lib/solanum_rb/i18n.rb:68:    def pni18n_k(context, single, multiple, number, **kwargs)
# every one of these six hits is the *definition line itself* — no call site
# anywhere in lib/, test/ or exe/ for pi18n_f, pi18n_k, pni18n, pni18n_f,
# pni18n_k or ni18n_k.
```

These methods exist to satisfy upstream's `test_i18n_k` and `test_pi18n`
(the two tests that assert them), and the commit that added them explicitly
frames itself as "ports upstream's full i18n-wrapper family" — a claim about
parity. Code that type-checks and that nothing ever calls is not evidence the
claim is true: a typo in `plural_lookup`'s argument order inside `pni18n`, or
a wrong key-join in `pni18n`'s `catalogue[key(context, single)]` lookup, would
currently pass every check in this suite, because no check reaches that line.
This is the "false green" shape `accountability-ensurance` is written to
catch — see that report.

## Suite: `src/i18n.rs` unit tests (4 tests)

| # | Upstream test | Asserts | Port covers | State |
|---|---|---|---|---|
| 1 | `test_i18n` | `i18n` falls back to the literal with no catalogue; `ni18n(single, multiple, 1\|2)` picks the literal by count with no catalogue entry | `_`'s identity fallback is genuinely pinned (`'and every string is its own msgid'`, C locale). The `ni18n` half is pinned only for the *no-entry* fallback (`default_plural`), which is correct behaviour but not what the row below is really about | ported |
| 2 | `test_i18n_f` | `i18n_f` fills 1/2 positional placeholders; `ni18n_f(single, multiple, n, args)` does the same *and* picks the form **by the catalogue's own plural rule when one is loaded** | `f_`'s placeholder checks are solid. The `ni18n_f`/catalogue-driven-dispatch checks (`'count 1/2 renders...'`) are a **false green** — see the headline finding above: the catalogue's `Plural-Forms` header is never actually read (`store` drops the header entry for every locale), so these checks pass only because `ca`'s real rule happens to coincide with the hardcoded English fallback the code always uses instead | **gap** |
| 3 | `test_i18n_k` | `i18n_k` fills named placeholders, any order, repeats; `ni18n_k(single, multiple, n, kwargs)` does the same *and* picks by count | `k_`'s six checks cover the `i18n_k` half fully. **`ni18n_k` has zero test coverage** — not called anywhere in `lib/`, `test/` or `exe/` | **gap** |
| 4 | `test_pi18n` | `pi18n`/`pni18n`/`pi18n_f`/`pi18n_k` — the same four shapes under a `C_`/context wrapper | `p_` covers plain `pi18n` (`'a contextual string translates'`). **`pni18n`, `pi18n_f`, `pi18n_k` are implemented and have zero test coverage** — not called anywhere outside their own definitions | **gap** |

Row 1 is a genuine, if narrow, pass (the literal no-catalogue fallback is
real and tested). Row 2 looked like a pass and is downgraded to a gap this
round once the test's actual code path was traced — it currently proves
nothing about catalogue-driven plural dispatch, which is the entire point of
`test_i18n_f`'s `ni18n_f` half. 1/4 ported, 3/4 gap — worse than last
round's reports claimed the fix would leave it, because last round's reports
(reasonably) took the new test's green result at face value.

## Suite: meson validation tests (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test('Validate schema file', ...)` | `glib-compile-schemas --strict --dry-run` on `data/` | `rake validate` → `glib-compile-schemas --strict --dry-run data` | ported |
| 2 | `test('Validate desktop file', ...)` | `desktop-file-validate` on the generated `.desktop` | `rake validate` → `desktop-file-validate build/generated/….desktop` | ported |
| 3 | `test('Validate appstream file', ...)` | `appstreamcli validate` on the generated metainfo | `rake validate` → `appstreamcli validate --no-net --explain …` | ported |

## I ran the suite myself this round, against current HEAD (`0590067`)

```
nix develop --command xvfb-run -a ruby test/test_units.rb
  → UNIT OK, 76 ok lines (was 71 before 0590067's +5 plural-dispatch checks)
nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb
  → 95 of 95 checks passed, DRIVE OK
SOLANUM_RB_PROFILE=development nix develop --command xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_devel.rb
  → 8 of 8 checks passed, DRIVE OK
```

76 + 95 + 8 = **179**, matching the runtime gate handed to me for this round
(179 checks, 0 failed, 10 components) exactly — reproduced live, not taken on
faith. The gate is real.

**The gate is still drive-script-and-unit-test coverage only, and that
boundary is exactly where this round's gap sits.** `test_units.rb`'s new
plural-dispatch section runs against `ca.po` (a real non-English catalogue) —
genuine progress, this is the first part of the suite that is not English-
only — but it only reaches `ni18n`/`ni18n_f`. `ni18n_k`, `pni18n`, `pni18n_f`
and `pni18n_k` are reached by nothing the gate runs, in any locale. A
component four checks don't exercise is unverified, not done, independent of
how many *other* checks are green.

## Extra

- `test/test_units.rb` — 76 checks: the countdown/lap-advance state machine,
  the PO-catalogue reader (locale switching, translated-plural dispatch,
  context, multi-line `msgstr`, fallback, encoding), plural dispatch against
  the real `ca.po` catalogue (new in `0590067`), the placeholder helpers
  (`f_`/`k_`), the build profile, the generated desktop/metainfo
  substitution, and the stylesheet guard. None of these exist upstream as a
  test; they are the port's own safety net, not parity work.
- `test/drive_solanum.rb` — 95 checks driving the real window: the full
  lap/break cycle, pause/resume, reset, live preference changes,
  fullscreen-on-break, the large-text breakpoint, all three dialogs, the five
  app actions, the three accelerators, the lap-change notifications,
  `app.skip`, and the beep/chime sound calls.
- `test/drive_devel.rb` — 8 checks on the devel-profile window and its about
  dialog.

179 of the port's own checks, genuinely run and genuinely green this round,
and that greenness is real for everything except the plural-dispatch family:
the gate catches zero of this round's two i18n findings, because the gate's
one plural-dispatch check (`ca.po`) is the exact test that this report found
to be a false green, and its three siblings (`ni18n_k`/`pni18n`/`pni18n_f`/
`pni18n_k`) are reached by nothing in the gate at all. 4/7 upstream tests
ported this round (up from 3/7 last round on the raw count, but for a
different and more concerning reason: the count went up because row 1 was
already a narrow pass, not because row 2 newly passed — row 2 is a
downgrade once traced).

## How this ledger relates to the others

See `COMPONENT_PARITY.md` for the four-axis component read: the lap label's
*currently rendered text* now matches upstream's in all 47 locales
(confirmed there), but that is because every shipped `.po` file's plural
forms for `"Lap {}"` happen to coincide with the always-English-fallback
output this round's finding describes — not because the dispatch mechanism
itself is correct. See `accountability-ensurance.md` for why "the test is
green and the output looks right" is treated as its own finding here rather
than closed as "fixed."
