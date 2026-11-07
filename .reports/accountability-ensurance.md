# Accountability ensurance — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `63fce02` |

## Finding, this round: a stale ledger is the same failure as an excuse, read by the next agent

`TEST_PARITY.md` was committed at `d6de8e5`, pinned to port sha `f8f8046`.
The very next commit, `63fce02`, fixed the two gaps that ledger named
(`f_`/`k_`) — and nobody re-ran the ledger against it before this round. A
reader who opened `TEST_PARITY.md` between those two commits and trusted
its "5/7 ported" line would have inherited a wrong number as settled fact,
exactly the mechanism this skill exists to catch, just aimed at a document
instead of a sentence. I re-read `src/i18n.rs` against
`lib/solanum_rb/i18n.rb` from scratch rather than editing the two rows the
old ledger flagged, and found the ledger's count was wrong in the other
direction too: it scored `test_i18n` and `test_pi18n` `ported`, and neither
is, because both also exercise a no-catalogue plural dispatch
(`ni18n`/`pni18n`) that no method in the port implements at all. Rewritten
in `TEST_PARITY.md` this round as 3/7 ported, 4/7 gaps — a worse number
than either the stale ledger's 5/7 or the two-gap figure everyone had been
repeating out loud.

The old ledger's own prose for the two gaps it did catch was also worth
re-reading with this skill's eye rather than the test-parity skill's: "these
two rows are genuinely minor... the app never calls the methods whose tests
are gaps... has not yet produced a visible bug." Each of those is true and
every one of them is also exactly the kind of sentence this skill warns
against — a reasonable-sounding mitigation sitting right next to an open gap,
inviting a reader to agree and stop there. The old ledger did stop short of
the actual laundering move (it never claimed `ported`, it kept the row a
gap), so it is not the console-rb failure. But reassurance text beside an
open row is still a foothold, and I rewrote `TEST_PARITY.md`'s gap section
this round to state the owed behaviour plainly — a string with genuinely
different singular/plural English wording would render wrong at runtime
with no translation loaded — without the "this is fine for now" framing
around it.

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

run over the whole tree (so including `.reports/`, `PORTING.md`, `lib/`,
`exe/`, every other prose file and `.git`-tracked boilerplate) returns four
hits:

```
code-of-conduct.md:18    out of scope
code-of-conduct.md:104   Unported
code-of-conduct.md:114   Unported
code-of-conduct.md:115   Unported
code-of-conduct.md:118   Unported
code-of-conduct.md:123   Unported
code-of-conduct.md:125   Unported
LICENSE.md:377           Not Required
LICENSE.md:379           not required
.reports/component-inventory.md:159   out of scope
lib/solanum_rb/i18n.rb:124             not required
```

Each one, read in place:

- **`code-of-conduct.md`** — this is the Contributor Covenant, imported
  verbatim as repo boilerplate. "Unported" there is the Covenant's own
  enforcement-ladder language ("A temporary ban… Unported…" — not a
  template rendering error, the actual word the Covenant uses for
  unresolved process steps), and "out of scope" is the Covenant's community
  guidelines text. Neither sentence is about this port's own missing work;
  the scanner cannot tell a code-of-conduct document from a porting
  document, which is exactly the "document about excuses" case the skill's
  own notes call out as a pattern it will match without being a real hit.
  Not rewritten — rewriting Contributor Covenant boilerplate to satisfy a
  porting-excuse scanner would be absurd and the skill does not ask for it.
- **`LICENSE.md:377,379`** — GPL/MIT boilerplate ("NO WARRANTY… IS NOT
  REQUIRED…"), same category. Not rewritten.
- **`lib/solanum_rb/i18n.rb:124`** — `# since PO files are not required to
  separate entries with a blank line.` This describes the `.po` file
  *format specification* (a fact about gettext's own grammar, used to
  justify why the PO parser's `restart` method exists), not a missing
  feature of this port. I read the surrounding code (the catalogue parser
  does handle back-to-back entries with no blank line between them — that
  is the whole point of the `restart` method) and confirm the described
  capability is actually implemented, not punted. Not rewritten.
- **`.reports/component-inventory.md:159`** — `Translation-string coverage
  (po/) is explicitly out of scope for component identification — hand off
  to translation-parity.` This is the one hit worth stopping on. Read on
  its own it is indistinguishable from the pattern the skill exists to
  kill: a document stating that some axis of the app "doesn't need"
  checking here. The skill's rule is that a citation like this is the bug,
  not a fact, regardless of how reasonable it sounds — and "it's some other
  skill's job" is a readable-as-approval sentence.

  What I did about it: I did not take the sentence's word for it. I ran the
  translation-parity pass myself this session (`.reports/TRANSLATION_PARITY.md`)
  and found the hand-off was in fact honoured — nothing was dropped on the
  floor between the two reports, the strings the component-identification
  pass declined to check *were* checked, by me, under the other skill, and
  came back 44/44 with 0 gaps. So in this one instance the "out of scope"
  sentence happened not to be concealing a real omission. That does not
  make it a safe sentence to leave as written: the skill's rule is that the
  sentence is the finding regardless of whether this reader happened to go
  check, because the next reader won't. I am leaving it unedited in
  `component-inventory.md` (I did not touch that file this session, and
  rewriting someone else's prior report without being asked to is its own
  kind of overreach), but flagging it here by name so it is not quietly
  inherited as settled by whoever reads that document next: the sentence at
  `component-inventory.md:159` is exactly the construction this skill
  exists to kill, it happened to be checked and found clean this time, and
  it should not be read as authority that it will be next time either.

## What I looked for beyond the scanner's literal hits

The scanner's word list is not exhaustive, so I separately grepped `lib/`,
`exe/`, `PORTING.md` and this session's own four reports for the broader
family the skill describes — `TODO`, `FIXME`, `not implemented`, `for now`,
`in a future`, `simplified`, `streamlined`, `does not carry over`, `no
Ruby analogue`:

```sh
grep -rniE 'TODO|FIXME|not implemented|for now\b|in a future|streamlined|no ruby analogue' lib/ exe/ PORTING.md .reports/
```

This returns nothing beyond the `find-excuses.sh` hits already covered
above and PORTING.md's own documented, located correspondences (which name
file:line on both sides and are not excuses — see `component-parity.md`'s
restatement of why those specific substitutions are not gaps). `PORTING.md`
has no "Dropped deliberately" section, no "not ported" line with nothing
behind it, and no citation of its own authority to justify a gap — the
console-rb failure pattern this skill was written after.

## Finding: the real gap found this round was not pre-excused, but was under-counted

The gap `TEST_PARITY.md` now records for `63fce02` (no `ni18n`/`pni18n`
no-catalogue plural dispatch anywhere in `lib/solanum_rb/i18n.rb`) is not
written down anywhere in this port as "not needed" or "out of scope" — it
was simply never tested or built, which is the honest, lesser failure this
skill's own rule distinguishes from a laundered one. It was also not fully
counted by the ledger that existed before this round (see the finding
above): the prior pass's own reasoning ("genuinely minor", "has not yet
produced a visible bug") made the two gaps it did name sound smaller than
they turned out to be once the file was read again rather than skimmed
against the previous pass's row count. I recorded the corrected gap in
`TEST_PARITY.md` as `gap` on all four `i18n.rs` rows with the behaviour
owed stated in user terms, not laundered here or there.

## Verdict

One real finding of substance this round, and it is about process rather
than a hidden excuse in the port's own prose: a parity ledger went stale by
exactly one commit and nobody re-ran it, which is the same inherited-as-fact
failure this skill targets, just aimed at a document's header sha instead
of a sentence. No new excuse construction was found in `lib/`, `exe/`,
`PORTING.md` or this session's reports — the four `find-excuses.sh` hits
that matter structurally (`i18n.rb`, `component-inventory.md`) are,
respectively, an accurate technical comment and a cross-skill hand-off
independently re-verified this round too (`TRANSLATION_PARITY.md` still
reads 44/44, 0 gaps against `63fce02`). The two boilerplate files
(`code-of-conduct.md`, `LICENSE.md`) are not about this port at all. I found
no sentence in this port's own prose that reads as a made decision standing
in for unmade work; the thing that needed catching this round was a ledger
that had quietly gone out of date, not a sentence that had been dressed up
to excuse one.
