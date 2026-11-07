# Test parity — Solanum-rb

| | |
|---|---|
| Upstream | `main` @ `bd2738d` |
| Port | `ruby` @ `f8f8046` |
| Upstream tests | 7 (4 unit tests in `src/i18n.rs` + 3 meson `test(...)` validation checks) |
| Ported | 5 |
| Gaps | 2 |
| Test command | `rake schema && rake desktop && ruby test/test_units.rb && xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb && … test/drive_devel.rb`, or just `rake test` (runs `schema`+`desktop` first) |

## The suite was actually run, not just claimed

I ran it myself, in the fork's `nix develop` shell under `xvfb-run`, rather
than trusting the "93 checks passed" figure handed to me:

```
rake desktop  (prerequisite — generates build/generated/*.desktop, *.metainfo.xml)
ruby test/test_units.rb                                         → UNIT OK (every check listed below passed)
rake schema   (prerequisite — compiles the gschema into build/)
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_solanum.rb  → 93 of 93 checks passed, DRIVE OK
xvfb-run -a -s '-screen 0 1600x1200x24' ruby test/drive_devel.rb    → 8 of 8 checks passed, DRIVE OK
```

Running `test/test_units.rb` or `test/drive_solanum.rb` *without* first
running `rake desktop`/`rake schema` fails outright (`Errno::ENOENT` on the
generated desktop/metainfo files, and a `GSettings schema … is not
installed` abort from `drive_solanum.rb`) — the claimed 93/0 figure is only
real when the full `rake test` prerequisite chain is honoured, and I
confirmed it is. This matches the runtime gate handed to me (93 checks
passed, 0 failed) exactly for `drive_solanum.rb`; `drive_devel.rb`'s 8
checks are additional and were not part of that gate's count.

## Upstream's real test suite

`meson.build`/`src/meson.build` register no `test()` beyond the three data
validations (schema, desktop, appstream — already censused in `PORTING.md`
and ported as `rake validate`, confirmed passing above with
`appstreamcli validate`). Beyond that, upstream's *only* tests are four
`#[test]` functions inside `#[cfg(test)] mod tests` in `src/i18n.rs` —
boilerplate copied, like the rest of that file, from the GNOME Rust app
template, but still a real upstream test suite that `cargo test` runs.

No other `.rs` file in `src/` has a `#[test]` or `#[cfg(test)]` block, and
there is no `tests/` directory.

## Suite: `src/i18n.rs` unit tests (4 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test_i18n` | `i18n("translate1")` falls back to the literal with no catalogue loaded; `ni18n` dispatches singular/plural by count (1 vs 2) | `test/test_units.rb`: `'a plain string translates'`, `'and every string is its own msgid'`, `'a plural entry translates through msgstr[0]'` (via `f_`) | ported |
| 2 | `test_i18n_f` | `i18n_f` fills a `{}` placeholder at the **start**, **middle**, and **end** of a string, and fills **two** placeholders (`"multiple {} and {}"` → `"multiple one and two"`) from an array of values | `test/test_units.rb` / `test/drive_solanum.rb` exercise `f_('Lap {}', n)` — one placeholder, always at the end | **gap** |
| 3 | `test_i18n_k` | `i18n_k`/`ni18n_k` fill **named** placeholders (`{one}`, `{two}`) from a keyword list, in any order, including repeats | — (the port's `I18n` module has no keyword-interpolation method at all: `_`, `p_`, `f_` only, `f_` taking exactly one positional value) | **gap** |
| 4 | `test_pi18n` | `pi18n`/`pni18n`/`pi18n_f`/`pi18n_k` — the same four behaviours, each under a message context | `test/test_units.rb`: `'a contextual string translates'` pins `p_(context, text)` with no interpolation; the interpolated-and-contextual combinations (`pi18n_f`, `pi18n_k`) are not separately pinned | ported for the plain-context case; the `pi18n_f`/`pi18n_k` half is the same gap as #2/#3, not pinned again separately |

**Behaviour still owed, #2 (`test_i18n_f`):** a translatable string with more
than one `{}` placeholder, or one whose placeholder is not the last token in
the string, is not correctly filled by this port today. `I18n#f_` calls
`text.sub('{}', value.to_s)` — `sub`, not `gsub`, and it takes exactly one
`value` argument — so a second `{}` in the same string is left literally as
`{}` in what the user sees, and there is no way to pass a second value even
if the placeholder were replaced. Nothing in Solanum's own UI currently
needs a second placeholder (I checked: every real `i18n_f`/`f_` call site in
both trees uses exactly one, `"Lap {}"`), so this has not yet produced a
visible bug — but the upstream test exists because the shared wrapper
promises that capability, and the Ruby wrapper does not have it.

**Behaviour still owed, #3 (`test_i18n_k`):** upstream's wrapper (and its
test) promises a keyword-interpolation form entirely absent from the port.
No `lib/solanum_rb/i18n.rb` method takes a keyword list, and no test in
`test/` exercises one. If any future upstream string is ever written with
`{name}`-style placeholders instead of positional `{}`, there is nothing in
this port that could translate it correctly, and nothing that would catch
the regression.

These two rows are genuinely minor — the underlying file is GNOME Rust
boilerplate, not Solanum-specific logic, and the app never calls the methods
whose tests are gaps. But "the test pins boilerplate" is not one of the
states the `test-parity` skill recognises, and marking it `ported` because
the app happens not to need the capability yet would be exactly the kind of
unearned green this audit exists to catch.

## Suite: meson validation tests (3 tests)

| # | Upstream test | Purpose | Port test | State |
|---|---|---|---|---|
| 1 | `test('Validate schema file', ...)` | `glib-compile-schemas --strict --dry-run` on `data/` | `rake validate` → `glib-compile-schemas --strict --dry-run data` | ported |
| 2 | `test('Validate desktop file', ...)` | `desktop-file-validate` on the generated `.desktop` | `rake validate` → `desktop-file-validate build/generated/….desktop` | ported |
| 3 | `test('Validate appstream file', ...)` | `appstreamcli validate` on the generated metainfo | `rake validate` → `appstreamcli validate --no-net --explain …` | ported |

I ran `rake validate` myself; all three passed (the appstream validator
emits one deprecation info about `developer_name`, inherited from the
metainfo structure itself, not a failure).

## Extra

- `test/test_units.rb` — 45 checks: the countdown/lap-advance state machine,
  the PO-catalogue reader (locale switching, plural dispatch via
  `msgstr[0]`, context, multi-line `msgstr`, fallback, encoding), the build
  profile (devel vs release, icon lookup, name suffix, version stamping),
  the generated desktop/metainfo substitution, and the stylesheet guard
  against the `var()`-in-`@keyframes` regression. None of these exist
  upstream as a test — upstream links real `gettext` and reads its schema
  and `.desktop`/metainfo from a GResource built by meson, so there is
  nothing there to port a PO-reader test or a substitution test *from*.
  They are the port's own safety net for plumbing upstream does not need,
  not parity work.
- `test/drive_solanum.rb` — 93 checks driving the real window: the full
  lap/break cycle, pause/resume, reset, live preference changes,
  fullscreen-on-break, the large-text breakpoint, all three dialogs, the
  five app actions, the three accelerators, the lap-change notifications,
  and `app.skip`.
- `test/drive_devel.rb` — 8 checks on the devel-profile window and its about
  dialog (striped header, suffixed id, devel icon, commit-stamped version).

173 of the port's own checks, none of them standing in for the two i18n
wrapper-interpolation gaps above — a bigger, green, genuinely-run suite is
not the same claim as 7/7.
