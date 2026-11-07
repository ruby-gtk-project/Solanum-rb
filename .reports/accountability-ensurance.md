# Accountability ensurance — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `6bfc160` |

## Finding 1 (most serious this round): a committed report asserted a whole catalogue "has no counterpart under `ruby`" — false, and already contradicted by a sibling report

`.reports/component-inventory.md`, rewritten at `bafffba`, contained three
separate statements that `po/` "is not present under `ruby`" / "has no
counterpart under `ruby`". This is not an excuse-shaped sentence that turned
out to be harmless on inspection (the `component-inventory.md:159`-style
case the previous round correctly distinguished as "checked and found
clean") — it is a **flatly false factual claim**. `po/` is tracked in this
repo, has been since the initial port commit (`68d9897`), contains 47
`.po` files plus `LINGUAS`, and was independently verified at **44/44
messages, 0 gaps** by `.reports/TRANSLATION_PARITY.md` — a report that
existed in the same `.reports/` directory, at the same commit, as the false
claim. Nobody cross-checked the two documents against each other before
this round, even though the previous accountability pass (see the version
of this file at `9808fbe`) read `component-inventory.md` closely enough to
flag its surrounding sentences ("out of scope", "by design") as the exact
construction this skill exists to kill — and then declined to act,
reasoning that re-verifying translation-parity independently "happened to
find it clean" so the sentence was "not a safe sentence to leave as
written... but" left it unedited anyway, on the grounds that editing
someone else's report unasked would be overreach.

That restraint was the wrong call. The skill's own rule is that a false or
excuse-shaped sentence in a report **is** the finding, and leaving it
sitting in the repo for a second round to inherit — while naming it only in
a different document most readers of `component-inventory.md` will never
open — is exactly how a false claim survives. I fixed it this round:
`.reports/component-inventory.md`'s three `po/`-absent lines are corrected
in place to state the true, already-known fact (po/ is present, 47 files,
cross-referenced to `TRANSLATION_PARITY.md`), with a dated note explaining
the correction rather than silently rewriting history. A static report that
asserts something false about the port's own file tree is a worse failure
mode than a stale sha pin (last round's finding) — it does not even need to
go out of date to be wrong; it was wrong the day it was written, and the
only thing protecting the project from it was a reader happening to open a
second document.

## Finding 2: three rounds of reports reasoned from the wrong evidence about the i18n plural gap, and the conclusion they reassured readers with was false

Every version of `TEST_PARITY.md` and `TRANSLATION_PARITY.md` before this
round stated, in slightly different words, that the missing plural-dispatch
family in `lib/solanum_rb/i18n.rb` (`ni18n`/`pni18n` and their `_f`/`_k`
forms — 8 of upstream's 12 `i18n.rs` functions) "has not yet produced a
visible bug" because Solanum's one plural string, `"Lap {}"`, has an
identical English `msgid`/`msgid_plural`. Each of those sentences is true
on its own terms and every one of them is also exactly the construction the
previous round's own write-up warned about under a different finding: "a
reasonable-sounding mitigation sitting right next to an open gap, inviting
a reader to agree and stop there." The mitigation reasons from the *English
source* to a conclusion about *every translated language*, which does not
follow, and nobody before this round actually opened the `.po` files to
check. I did, this round:

```sh
for f in po/*.po; do python3 - "$f" <<'PY'
import sys,re
text=open(sys.argv[1],encoding='utf-8').read()
for b in text.split("\n\n"):
    if 'msgid "Lap {}"' in b and 'msgid_plural' in b:
        ms=re.findall(r'msgstr\[\d+\]\s+"((?:[^"\\]|\\.)*)"', b)
        if len(set(ms))>1: print(sys.argv[1], ms)
PY
done
```

Four locales — `ca`, `fur`, `oc`, `pt_BR` — give genuinely different
singular and plural wording. Since `I18n` always reads `msgstr[0]`, every
user on those four locales sees the grammatically singular form on every
lap past the first, today, with no future string required to trigger it.
"Has not yet produced a visible bug" was false the day it was typed, for
anyone running the app in Catalan, Friulian, Occitan or Brazilian
Portuguese. I rewrote the relevant passages in `TEST_PARITY.md`,
`TRANSLATION_PARITY.md` and `COMPONENT_PARITY.md` this round to state the
confirmed bug plainly, with the four languages and exact strings named, and
downgraded the main-window unit's component-parity verdict from full parity
to a text-axis gap because of it.

## `find-excuses.sh` run over the whole tree

```sh
.claude/skills/accountability-ensurance/scripts/find-excuses.sh .
```

Hits, read in place (same baseline as the previous round, re-confirmed):

- `code-of-conduct.md`, `LICENSE.md` — Contributor Covenant and GPL/MIT
  boilerplate, imported verbatim. Not about this port's own work. Not
  rewritten, for the same reason the previous round gave: rewriting
  imported legal/community-standard text to satisfy a porting-excuse
  scanner would be absurd.
- `lib/solanum_rb/i18n.rb:141` ("not required") — describes the `.po` file
  *format grammar* (blank lines are not required to separate entries),
  justifying why `restart` exists; read the surrounding code again this
  round and confirmed the described capability (back-to-back entries with
  no blank line) is actually implemented, not punted. Not rewritten.
- `.reports/component-inventory.md` (`N/A`, `by design`, `out of scope` at
  the former `po/`-absent lines) — this is Finding 1 above, now fixed in
  place rather than merely flagged a second time.
- `.reports/accountability-ensurance.md` itself (this file, and its
  predecessor) — matches the scanner's wordlist because it *discusses*
  excuse language by name while explaining why it is or is not a real
  gap. This is the skill's own documented false-positive mode for a report
  about excuses, not a hit worth acting on.

Broader grep for `TODO|FIXME|not implemented|for now\b|in a future|
streamlined|no ruby analogue` over `lib/`, `exe/`, `PORTING.md` and
`.reports/` returns nothing beyond the hits above and this round's own
corrected prose. `PORTING.md` still has no "Dropped deliberately" section
and no bare "not ported" line with nothing behind it — the console-rb
failure pattern this skill was written after is still absent from the
port's own documentation.

## What was not excused, but was undercounted twice

The i18n plural-dispatch gap was never claimed `ported` by any report (it
has always scored as a gap, in every round) — so it is not a laundered
excuse in the strict sense the skill defines. But a gap whose *severity*
has been understated across three consecutive rounds, each time by
reasoning from evidence (the English source) that does not actually bear
on the claim being reassured ("no visible bug"), is close enough to that
failure mode to be worth stating plainly: two rounds of agents, including
one explicitly running this skill, read "the English msgid and msgid_plural
are identical" and stopped there instead of opening 47 `.po` files to check
whether the conclusion actually followed. It didn't.

## Verdict

Two real findings this round, both about documents rather than code:

1. A **false factual claim** survived one full accountability round
   unfixed in `.reports/component-inventory.md` (fixed this round).
2. A **real, present-tense, four-locale rendering bug** was reported as a
   theoretical future risk across three rounds of `TEST_PARITY.md` and
   `TRANSLATION_PARITY.md` (corrected this round in both files, plus
   `COMPONENT_PARITY.md`).

No new excuse construction was introduced in `lib/`, `exe/`, or
`PORTING.md` this round. The runtime gate (95/95 checks, `drive_solanum.rb`,
reproduced live this round) is real and was reproduced, not taken on faith
— but it is also, by construction, English-only and cannot see either
finding above; a drive script that always runs in `LANG=C` is not evidence
about translation correctness, and no report before this round said that
limitation out loud. This round's `TEST_PARITY.md` now does.
