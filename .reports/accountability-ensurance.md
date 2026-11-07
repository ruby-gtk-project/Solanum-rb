# Accountability ensurance — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `f8f8046` |

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

## Finding: the test-parity and translation-parity gaps this session found were not pre-excused

The two real gaps `TEST_PARITY.md` records (`test_i18n_f`'s multi-placeholder
behaviour, `test_i18n_k`'s keyword interpolation) were not written down
anywhere in this port before this session, in `PORTING.md` or otherwise, as
"not needed" or "out of scope." They were simply never tested, which this
skill's own rule treats as the honest, lesser failure — a silent gap, not a
laundered one. I recorded them in `TEST_PARITY.md` as `gap` with the
behaviour owed stated in user terms, not as a note here, because that is
where the `test-parity` skill's ledger wants them.

## Verdict

No real excuse laundering found. The four hits that matter structurally
(`i18n.rb`, `component-inventory.md`) are, respectively, an accurate
technical comment and a cross-skill hand-off that I independently verified
was honoured this session — not confirmed as reliably self-correcting in
general, just confirmed true today. The two boilerplate files are not about
this port at all. I found no sentence in this port's own prose that reads
as a made decision standing in for unmade work.
