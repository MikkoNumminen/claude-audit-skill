# Voice profile template

The fields the `readme-drift-sync` skill extracts from an existing `README.md` before rewriting any drifted section. The profile is the constraint every rewrite must satisfy — without it, the skill regresses to generic prose.

The skill writes the filled profile to `docs/audits/readme-drift-scratch.md` using the structure below. Every field must include at least one **quoted example** from the README being audited. A quote is proof; an adjective without a quote is a guess.

If a field cannot be filled with a quoted example (because the README is too short, or the trait isn't present), write `not detected — insufficient sample` and downgrade rewrite confidence for that axis.

---

## 1. Tone register

Pick one or two — combinations are common:

- `formal` — full sentences, no contractions, no first/second person
- `casual` — contractions, conversational asides, occasional incomplete sentences
- `sardonic` — dry wit, ironic asides about the obvious
- `earnest` — direct, no irony, no hedging
- `technical` — heavy jargon use, terse, assumes background knowledge
- `marketing` — superlatives, benefit-led framing, exclamation marks
- `academic` — passive voice, citations, hedged claims

**Quoted example from the README:**

```
<paste a 1-3 sentence quote that exemplifies the register>
```

**Notes:** Anything the register tells you about the audience (assumed expertise, formality expected back, etc.)

---

## 2. Humor style

`absent` — no humor; rewrites must also be straight.

If present, pick one or more:

- `self-deprecating` — author downplays own work
- `ironic` — says the opposite of what's meant, expecting reader to catch it
- `deadpan` — funny without acknowledging it; humor is in the framing
- `exuberant` — explicit "fun" voice; exclamation marks, ALL CAPS, emoji
- `nerdy-reference` — jokes that require domain context (e.g. "640K should be enough")

**Quoted example:**

```
<paste the funniest single line in the README, or the most obviously humor-marked one>
```

**Notes:** If humor is present but sparse (one joke in 200 lines), rewrites must NOT add new humor — that would change the density.

---

## 3. Pronoun choice

How does the author refer to actors? Pick the dominant choice per actor:

| Actor | Choice | Example |
| --- | --- | --- |
| The author | `I` / `we` / impersonal / not mentioned | |
| The reader | `you` / impersonal / `the user` | |
| The tool / agent | by name / `it` / `the script` | |

**Quoted examples:**

```
<author>: <quote>
<reader>: <quote>
<tool>: <quote>
```

**Notes:** If the README mixes (some sections "we", some "I"), record the mix and the boundary — rewrites must match the same boundary, not pick one globally.

---

## 4. Sentence rhythm

Pick the dominant pattern:

- `short and punchy` — most sentences ≤15 words
- `long and clausal` — most sentences ≥25 words, multiple clauses
- `mixed deliberately` — alternates short and long for effect
- `mixed accidentally` — no apparent rhythm

**Quoted example:**

Three consecutive sentences from one paragraph (paste verbatim; preserve line breaks):

```
<sentence 1>
<sentence 2>
<sentence 3>
```

**Notes:** Sentence rhythm is the easiest trait to break in rewriting. Generic LLM prose tends to medium-length, clausal sentences with parallel structure — if the README is punchier, the rewrite must be too.

---

## 5. Vocabulary tells

Concrete word choices the author favors. Look for ≥3 examples and record both the word used AND the obvious alternative the author *didn't* use:

| Concept | Author says | Author does NOT say |
| --- | --- | --- |
| `release / ship` | | |
| `library / tool / kit` | | |
| `authentication` | | |
| `function / helper / method` | | |
| `bug / defect / issue` | | |
| `documentation / docs` | | |
| <add domain-specific terms> | | |

**Quoted examples:** at least three.

```
1. <quote with vocab tell>
2. <quote with vocab tell>
3. <quote with vocab tell>
```

**Notes:** Vocabulary tells are the strongest single signal of voice mismatch. A rewrite that uses "authentication" in a README that consistently says "auth" reads wrong even if every other axis matches.

---

## 6. Structural patterns

How is the content shaped?

- **Prose vs bullets ratio.** Roughly `<X>% prose, <Y>% bullets` (eyeball it).
- **Header style.** Pick: `descriptive statements` ("## Installation") / `questions` ("## How do I install this?") / `commands` ("## Install it") / `metaphorical` ("## The recipe card").
- **Code block introductions.** Does the author say "Run this:" / "Like so:" / just stand the block alone?
- **Mermaid / ASCII diagrams.** Present or absent? If present, how introduced?
- **Tables.** Used for comparisons? For listings? Not used at all?
- **Callouts.** Does the author use `> blockquote` callouts, `**Note:**` prefixes, or no callouts?

**Quoted examples (one per pattern that's present):**

```
<header example>
<code-block intro example>
<callout example if present>
```

**Notes:** Structural patterns rarely need to be preserved literally — but if the README is mostly prose, rewrites must not introduce bullet lists; if mostly bullets, must not introduce dense paragraphs.

---

## 7. Reference / explanation style

How does the author treat the reader's assumed knowledge?

Pick one:

- `barney style` — explain everything from scratch, assume zero context ("If you've used X you know. If not: X is...")
- `educational` — explain the *why* before the *how*, structured pedagogy
- `assumes domain expertise` — no explanations; reader is expected to know
- `humor-forward` — explanations are vehicles for jokes
- `ironic understatement` — downplays everything ("a small file you drop in...")
- `marketing-led` — explanations are benefits ("never worry about X again")

**Quoted example:**

A passage where the author teaches something — paste verbatim:

```
<3-5 line quote of an explanatory passage>
```

**Notes:** This is the hardest axis to match because it requires recognising the *function* of a sentence (is it teaching? selling? joking? understating?), not just its surface texture. Rewrites that match register but miss the explanatory function still read wrong.

---

## 8. Forbidden moves (derived)

Based on the seven axes above, enumerate concrete things the skill MUST NOT do when rewriting. Examples drawn from a real run:

- "Author uses `you`; do not switch to `we` or `the user`."
- "Author uses `auth`; do not write `authentication`."
- "Author humor is deadpan and rare; do not add exclamation marks or new jokes."
- "Author uses prose with code blocks introduced by short setup sentences; do not introduce a bullet list as a substitute for prose."
- "Author uses barney-style explanation; do not assume domain knowledge in rewrites."

**This is the actionable section** — every rewrite is checked against this list before the voice-match test runs.

---

## Worked example: voice profile for `claude-skills/README.md`

Filled-in example so the skill (and the human reviewer) can see what a complete profile looks like. Drawn from the README at the moment this template was authored (2026-05-20); kept as a reference, not a cache for the actual skill run.

### 1. Tone register
- `casual` + `earnest`
- Quote: `"You ask 'audit this codebase', go make coffee, and come back to a written report listing every bug it found, with file names and line numbers."`

### 2. Humor style
- `ironic understatement` — sparse, dry
- Quote: `"if it saves you a day of firefighting, that's enough"`

### 3. Pronoun choice
| Actor | Choice | Example |
| --- | --- | --- |
| Author | impersonal / not mentioned | (no "I", no "we" anywhere) |
| Reader | `you` | `"You ask 'audit this codebase'..."` |
| Tool | `Claude` / `the skill` / `it` | `"Claude Code notices the trigger phrase..."` |

### 4. Sentence rhythm
- `mixed deliberately` — short punchy declaratives interspersed with longer clausal sentences
- Quote: `"One run. About ten minutes. The rest of the day is just fixing the list."` (three sentences, 2/4/9 words)

### 5. Vocabulary tells

| Concept | Author says | Author does NOT say |
| --- | --- | --- |
| skill/recipe | `recipe card` | `template` / `prompt` |
| reviewers | `five colleagues, each with a different obsession` | `agents` / `analyzers` |
| report | `written report` | `output` / `findings document` |
| pattern | `quiet bugs` | `latent defects` / `edge cases` |

Quotes:
```
1. "This repo holds the recipe card for a code audit."
2. "Think of them as five colleagues, each with a different obsession"
3. "looking for leaks, races, swallowed exceptions, missing timeouts, and the other quiet bugs"
```

### 6. Structural patterns
- ~70% prose, ~30% bullets and code
- Header style: `descriptive statements` mixed with `questions` ("What a 'skill' even is", "Why this recipe is interesting")
- Code-block intros: short setup sentence ("Here's the shape of one run:")
- Mermaid diagrams: present, introduced by prose
- Tables: not used
- Callouts: not used

### 7. Reference / explanation style
- `barney style` + `ironic understatement`
- Quote: `"If you've used Claude Code you already know. If not: Claude Code is a command-line assistant that can read and edit your code. A *skill* is a markdown file that teaches Claude Code how to do one specific job — like a recipe card."`

### 8. Forbidden moves
- Do not use `we` or `I` anywhere.
- Do not use `authentication`, `analyzer`, `latent defect`, `findings document` (use the author's terms).
- Do not add exclamation marks or new jokes — humor is deadpan and rare.
- Do not introduce bullet-only sections; the author favors prose with bullets as garnish.
- Do not skip the barney-style framing — if explaining a concept, explain it from zero, even if it feels redundant.
- Do not introduce tables; the author uses prose + bullets + Mermaid, not tables.
- Do not write headers as commands or marketing taglines; descriptive or question form only.
