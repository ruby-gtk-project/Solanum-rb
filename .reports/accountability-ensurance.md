# Accountability ensurance — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `0590067` |

## Finding 1 (most serious this round): a test written specifically to prove a fix was true is a false green — the fix it tests for does not run

Commit `0590067` ("Implement ni18n/pni18n plural dispatch") was written to
close the exact finding this file's previous round raised: four shipped
locales rendered the wrong grammatical form on the lap label because
`I18n` had no plural dispatch. The commit's own message says it "parses
each catalogue's own `Plural-Forms` header into a real plural rule via a
small recursive-descent expression compiler, rather than assuming English's
'singular iff n == 1'," and adds a unit test specifically to pin that claim
(`'count 1 renders the singular form'` / `'count 2 renders the plural
form'` against `ca.po`). The test passes. **The claim is false anyway.**

Tracing `plural_rule` → `catalogue['']` → `store`:

```ruby
usable = !entry[:fuzzy] && !entry[:msgid].empty? && entry[:msgstrs].values.any? { |form| !form.empty? }
```

The PO header entry's `msgid` is `""` by definition, so `!entry[:msgid].empty?`
is always `false`, so the header is **never stored in the catalogue, for
any locale**. `plural_rule` therefore always falls through to the hardcoded
`ENGLISH_PLURAL_RULE`, regardless of what `Plural-Forms` line the loaded
`.po` file actually has. Checked directly:

```sh
$ nix develop --command xvfb-run -a ruby tmp/checkbug.rb   # ad hoc, removed after use
ru: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
ca: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
pl: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
uk: has empty-key header? false  plural_rule={:nplurals=>2, :proc=>#<Proc ...>}
```

`ru`'s header says `nplurals=3`; `uk`'s says `nplurals=4`. Both report back
`nplurals: 2` — English's — because the catalogue's actual header is never
reached. The `PluralExpr` recursive-descent compiler the commit added is
genuinely unreachable code: nothing in the running program ever calls
`PluralExpr.compile` with a real, non-nil header, because `parse_plural_forms`
only gets `nil` to work with (`singularize(catalogue[''])` where
`catalogue['']` is always `nil`).

**The test added to prove this works cannot tell the difference, by
construction.** Catalan's real rule is `n != 1`; English's hardcoded rule is
`n == 1 ? 0 : 1`. These give the same answer for every non-negative integer.
So a test against `ca.po` is green whether the catalogue's own rule is read
or completely ignored. This is the single most dangerous shape a test can
take: not absent, not skipped, not weakened — present, passing, reviewed,
and incapable of catching the defect it was written for, because the one
fixture chosen cannot distinguish "fixed" from "still broken."

I went one step further and evaluated the unreachable `PluralExpr` output
directly against Russian's real `Plural-Forms` expression (`nplurals=3;
plural=(n%10==1 && n%100!=11 ? 0 : n%10>=2 && n%10<=4 && (n%100<10 ||
n%100>=20) ? 1 : 2)`) to see whether fixing the `store` bug alone would be
enough:

```
expected for n = 1,2,3,4,5,11,21,22,25,101,111,121:  0,1,1,1,2,2,0,1,2,0,2,0
got      for the same inputs, calling the proc raw:  0,1,1,1,1,1,1,1,1,1,1,1
```

Right only for `n ∈ {1,2,3,4}`. There is a **second, independent** bug in
the compiler for this specific nested-ternary/3-branch shape (I did not
chase the exact token-handling defect further; the fix for Finding 1's
`store` bug should not be shipped without also re-testing this). Two bugs,
stacked, both invisible to the one test the commit added, both invisible to
the 179-check runtime gate (which only ever runs in `C`/English or `ca`).

**Current real-world consequence: none, visibly, today — and that is
exactly the reassurance this file exists to not accept at face value.**
Every shipped `.po` file happens to give the lap label identical or
English-equivalent plural forms, so the wrong mechanism currently produces
the right output. The moment a future plural string has genuinely distinct
wording in one of the 10 shipped locales with 3+ plural forms (`be`, `cs`,
`hr`, `pl`, `ro`, `ru`, `he`, `sl`, `sr`, `uk`), this renders wrong, silently,
with every existing check still green. This is the identical shape — "looks
fine today, for reasons that don't generalize" — that this file's own
previous round flagged as the central lesson of the lap-label bug it found.
That lesson did not prevent its own recurrence one commit later, in the code
written to fix it.

## Finding 2: the parity fix shipped four more wrapper methods with zero test coverage

`ni18n_k`, `pni18n`, `pni18n_f`, `pni18n_k` — four of the eight methods
`0590067` adds — are called by nothing in `lib/`, `test/` or `exe/` beyond
their own definitions:

```sh
$ grep -rn "ni18n_k\|pni18n\|pi18n_f\|pi18n_k" lib/ test/ exe/
# every hit is a definition line; zero call sites
```

Not a laundered excuse in the strict sense (nobody wrote a comment claiming
these are tested) — but the commit message's "ports upstream's full
i18n-wrapper family" is a completeness claim the test suite does not back
up for half of what it names. See `TEST_PARITY.md` for the full row-by-row.

## `find-excuses.sh` run over the whole tree

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Hits, read in place (same baseline as previous rounds, re-confirmed this
round against `0590067`):

- `code-of-conduct.md`, `LICENSE.md` — imported boilerplate, not this port's
  own work. Not rewritten.
- `lib/solanum_rb/i18n.rb` ("not required", PO continuation-line grammar) —
  re-read this round; still describes real, implemented parser behaviour,
  not a punt. Not rewritten.
- `.reports/component-inventory.md` ("N/A by design", GResource manifest) —
  re-read this round; this is a genuine architectural fact (the house style
  has no `.ui`/GResource layer anywhere in the fleet, confirmed against
  `CLAUDE.md` and the `ruby-gtk` skill), not an excuse for missing
  behaviour. Not rewritten, consistent with the previous round's judgement.
- `.reports/accountability-ensurance.md` itself (this file, and its
  predecessors) — matches the scanner's wordlist because it discusses
  excuse language by name. The skill's own documented false-positive mode.

Broader grep for `TODO|FIXME|not implemented|for now\b|in a future` over
`lib/`, `exe/`, `PORTING.md` and `.reports/` returns nothing beyond the hits
above and prior rounds' own corrected prose — confirmed again this round.
No new excuse construction (a hedge word standing in for a located gap) was
introduced in `lib/`, `exe/`, or `PORTING.md` by `0590067`. What was
introduced is worse than an excuse: a test that affirmatively, confidently,
and wrongly says a specific claim is true. `find-excuses.sh`'s wordlist
cannot catch that shape — a false green has no hedge word to grep for — which
is exactly why this file does not stop at the script's output and instead
traces code paths by hand every round.

## What was not excused, but was asserted beyond what was checked

Nobody in this round's commit lied about having tested the plural-dispatch
mechanism — the commit plainly includes a test and describes what it is
meant to prove. The failure mode here is narrower and, in a sense, harder to
catch than a bare assertion: a real test, genuinely run, genuinely green,
whose fixture cannot discriminate between the claim being true and the claim
being false. The only way to find this was to not stop at "the test passes"
and instead trace what code the test's assertions actually touch — which is
this skill's whole method, restated: a green check is evidence of whatever
it actually executes, and nothing else.

## Verdict

One real finding this round, more serious than either of last round's two:

1. **A test that cannot fail even when the feature it covers is broken.**
   The plural-dispatch "fix" for the previous round's four-locale rendering
   bug does not read any catalogue's `Plural-Forms` header, for any locale,
   ever — confirmed by code trace and direct execution, not inferred. Its
   one dedicated test is green by mathematical coincidence (Catalan's real
   rule equals the hardcoded fallback), not because the mechanism works. A
   second, independent bug in the (currently unreachable) expression
   compiler was found and demonstrated on Russian's real rule. Current
   visible behaviour is correct for the app's one existing plural string in
   all 47 locales, by the same coincidence, which is exactly why nobody
   before this round's trace would have noticed.

Also carried forward: four of the fix's eight new methods have zero test
coverage (Finding 2 / `TEST_PARITY.md`).

The runtime gate (179 checks, reproduced live this round) is real, and still
by construction English-and-Catalan-only — which this round's finding shows
is not the safety margin it looks like, since the one non-English check in
the gate is the exact test that turned out to prove nothing. A passing gate
is evidence of what it runs; it is not evidence about a catalogue header
that nothing in the gate's own code path ever reads.
