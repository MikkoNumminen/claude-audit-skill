# Trigger calibration — `readme-drift-sync`

The `description:` field in `SKILL.md` is a classifier prompt: Claude reads it and decides whether to load this skill on a given user message. A vague description never fires; an over-broad one fires in the wrong context.

This file lists ten plausible user messages, predicts whether the current description would route correctly, and notes any mismatches.

## Methodology

For each message, I imagine Claude reading the skill's description and asking: "does this user message match the description's trigger phrases AND not match the `NOT for` exclusions?"

- ✅ Fires correctly = matches an intended trigger
- ❌ Misfires = fires when it shouldn't
- ⚠️ Misses = should fire but doesn't
- 🟡 Ambiguous = unclear; intentional bail-to-clarification

The current description (excerpt of trigger language):

> Use whenever the user says "sync the README", "update the README", "check README drift", "has the README fallen out of date", or after a release-cut before the next push. NOT for initial README creation, full rewrites, CONTRIBUTING/CHANGELOG edits, or general code edits where the README isn't in scope.

## Test cases

| # | User message | Expected | Predicted | Verdict | Notes |
| --- | --- | --- | --- | --- | --- |
| 1 | "update the README" | fire | fire | ✅ | Exact trigger phrase. |
| 2 | "sync the README with the repo" | fire | fire | ✅ | Exact trigger phrase. |
| 3 | "the README mentions a `--legacy` flag we removed, can you fix it" | fire | fire | ✅ | "Mentions X but removed" is feature-drift; description's "drift" language covers this. |
| 4 | "write a README for this project" | NOT fire | NOT fire | ✅ | "Write a README" matches the "initial README creation" exclusion. |
| 5 | "rewrite the README in a more formal tone" | NOT fire | NOT fire | ✅ | "Rewrite" matches the "full rewrites" exclusion; tone change is structural, not drift. |
| 6 | "update CONTRIBUTING.md to mention the new test command" | NOT fire | NOT fire | ✅ | "CONTRIBUTING.md" matches the explicit exclusion. |
| 7 | "after the release-cut, make sure all the docs are up to date" | fire | fire | ✅ | "After release-cut" + "docs up to date" matches. NOTE: "all the docs" is broader than README, but the skill is README-only — it will fire AND should bail with "this skill is README-only; for other docs, edit by hand or ask for a different skill." |
| 8 | "add a section to the README about how to deploy" | NOT fire | fire | ❌ | This is "add new content," not drift detection. The description should add `NOT for adding new sections about features that are documented elsewhere` to its exclusions, OR the skill should detect that the request is additive (not drift) at runtime and bail. **Action:** add to the SKILL.md "When NOT to invoke" section: "Not for adding new sections that document existing-but-undocumented features — that's `feature-drift` only when the feature is in scope and the README claims completeness. For deliberate new section authoring, edit by hand." |
| 9 | "the README feels out of date, can you check it" | fire | fire | ✅ | "Out of date" matches "has the README fallen out of date". |
| 10 | "the README needs work" | 🟡 ambiguous | likely fire | 🟡 | "Needs work" is vague — could mean drift, restructure, tone, anything. Current description would probably fire. **Intentional behavior:** the skill should fire AND immediately ask the user for clarification: "drift-sync runs five specific checks (file structure, deps, skills, features, status). Is that what you mean by 'needs work', or do you want a restructure / tone change / new sections? The first is my job; the others aren't." This is bail-to-clarification, not a misfire. |

## Summary

- **Correct fires:** 6 (#1, 2, 3, 7, 9, + #10 conditional)
- **Correct non-fires:** 3 (#4, 5, 6)
- **Misfires:** 1 (#8)
- **Bail-to-clarification:** 1 (#10) — intentional, not a misfire

## Recommended description tweaks

1. **Add to "When NOT to invoke" in SKILL.md** (for case #8):
   > Not for adding new sections that document existing-but-undocumented features unless the README explicitly claims completeness ("All flags:", "Full reference:"). For deliberate new-section authoring, the human writes the first draft; this skill is for keeping existing sections honest.

2. **Add to the skill's pre-flight** (for case #10):
   > If the user's request is vague ("the README needs work", "fix the README"), bail with: "drift-sync runs five specific checks: file structure, dependencies, skills list, features (CLI flags / env vars / endpoints), and status claims (versions, test counts). Want me to run all five, or did you mean something else?" Wait for clarification before extracting voice or running checks.

3. **No change needed to the `description:` field itself** — the classifier-prompt scoring is acceptable. The two adjustments above are runtime behaviors, not trigger-routing changes.

## Validation cadence

This file is part of the skill's deliverable, not a one-shot artifact. Re-run trigger calibration:

- After any change to the `description:` field
- When real usage reveals a misfire or miss not in this table (add the case as #11+)
- Quarterly, with fresh test cases drawn from the past quarter's real messages if available

A skill that's never re-calibrated drifts the same way the READMEs it audits do.
