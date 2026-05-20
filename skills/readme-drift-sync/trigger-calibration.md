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
| 8 | "add a section to the README about how to deploy" | NOT fire (end-state) | fire-then-bail | ✅ | **Fixed via body-level catch**, not classifier change. The `description:` field wasn't modified, so the classifier still loads the skill on phrases that partially overlap with documented triggers ("README" + verb). SKILL.md's "When NOT to invoke" section now contains an explicit "Not for adding new sections that document existing-but-undocumented features" bullet — once the skill loads, it reads its own body and bails. Effective outcome is no work done; mechanism is the same as case #10's vague-request bail. |
| 9 | "the README feels out of date, can you check it" | fire | fire | ✅ | "Out of date" matches "has the README fallen out of date". |
| 10 | "the README needs work" | 🟡 ambiguous | fire-then-bail | 🟡 | **Resolved**: SKILL.md Procedure step 1 now starts with an explicit vague-request bail. The skill fires (the description has broad-enough wording that it loads), but immediately stops to ask the user "drift-sync runs five specific checks... want all five, or did you mean something else?" Wait for clarification before extracting voice or running drift checks. Bail-to-clarification is the intended behavior, not a misfire. |

## Summary

- **Correct fires:** 5 (#1, 2, 3, 7, 9)
- **Correct non-fires:** 3 (#4, 5, 6)
- **Fire-then-bail (correct end-state, body-level catch):** 2 (#8, #10)
- **Misfires:** 0

10/10 reach the correct end-state after the SKILL.md fixes. Two of those (#8 and #10) get there via body-level catches rather than classifier-level routing — see the rows for the mechanism.

## Applied changes

Both recommendations from the original draft of this file are now in SKILL.md:

1. **"When NOT to invoke" bullet for case #8** — the "not for adding new sections that document existing-but-undocumented features" exclusion is live. Catches the deploy-section-add case without changing the `description:` classifier prompt.

2. **Pre-flight vague-request bail for case #10** — Procedure step 1 now bails with the clarifying question before any drift detection or voice extraction runs. The skill loads on vague phrases, then stops to ask scope.

3. **No change to the `description:` field itself** — the classifier-prompt scoring stays acceptable. The two adjustments are runtime behaviors, not trigger-routing changes.

## Validation cadence

This file is part of the skill's deliverable, not a one-shot artifact. Re-run trigger calibration:

- After any change to the `description:` field
- When real usage reveals a misfire or miss not in this table (add the case as #11+)
- Quarterly, with fresh test cases drawn from the past quarter's real messages if available

A skill that's never re-calibrated drifts the same way the READMEs it audits do.
