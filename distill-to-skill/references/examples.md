# Distillation Examples

Concrete before/after examples showing how source material becomes skill content.

## Example 1: Blog Post → Single SKILL.md

**Source:** "Parse, Don't Validate" by Alexis King (~5,000 words, Haskell)

**What the article contains:**
- Motivation: why `head :: [a] -> a` is partial (700 words)
- Two approaches: weaken output vs strengthen input (1,500 words)
- The `NonEmpty` list example with full Haskell code (800 words)
- "What is a parser?" philosophical discussion (600 words)
- Practical advice section (800 words)
- Recap and related reading (600 words)

**What the skill extracted:**
- The core idea in 6 lines (validate returns void, parse returns proof)
- The two strategies as a decision rule: "Try strategy 2 first. Fall back to 1."
- 7 practical rules, each with a TypeScript code example
- The shotgun parsing anti-pattern (3 sentences, not 3 paragraphs)
- A code review checklist (9 concrete smells)

**What was cut:**
- The entire Haskell-specific `NonEmpty` walkthrough → replaced with TS `[T, ...T[]]`
- "What is a parser?" philosophical section → collapsed to 1 sentence
- All motivation/persuasion → the agent doesn't need to be sold
- Recap and related reading → not actionable
- Footnotes about type theory → too academic

**Compression:** ~5,000 words → 210 lines (~750 words). Ratio: ~7:1

---

## Example 2: Article + Exemplary Doc → Workflow Skill

**Source:** matklad's "ARCHITECTURE.md" article (~800 words) + rust-analyzer's
architecture.md (~420 lines) as a concrete example

**What the article contains:**
- Why architecture docs matter (contributor 10x cost) (200 words)
- The rules: short, stable, codemap, name don't link, invariants, boundaries (400 words)
- Link to rust-analyzer as example (200 words)

**What the skill extracted:**
- 7 principles distilled from the article prose
- A 3-step workflow (explore → identify → write) that the article implies but doesn't state
- A concrete template with `### \`path/\`` headers, **Boundary:** and **Invariant:** callouts
- Style rules derived from studying the rust-analyzer example
- A quality checklist

**What was added (not in the source):**
- The workflow — the article says "what" but not "how an agent should do it"
- The template — extracted by studying rust-analyzer's structure
- The reference example — a generic TypeScript project demonstrating all patterns

**Key insight:** The article was 800 words of principles. The exemplary doc was 420
lines of practice. The skill bridged the two: principles + template + workflow.

---

## Example 3: Multiple Repos → Themed Skill with References

**Source:** 7 GitHub repos (citty, consola, ofetch, defu, scule, pathe, taze)

**What the repos contain:** ~15,000+ lines of source code across 7 repositories

**The distillation process:**
1. Explored each repo independently, documenting patterns
2. Identified the **common thread**: zero-dep, lightweight, TypeScript-first
3. Found 7 shared principles across all repos
4. Grouped patterns by domain: CLI, logging, fetch, data utils, TS tricks
5. Extracted copy-paste utilities (ANSI colors, isPlainObject, etc.)

**What the skill contains:**
- SKILL.md (193 lines): 7 principles, 4 copy-paste patterns, quick reference table
- 5 reference files (192-349 lines each): deep dives by domain

**What was kept:**
- Architectural patterns (factory over classes, one primitive compose everything)
- Copy-paste utilities under 25 lines
- TypeScript type tricks that are non-obvious
- Design decisions (why retries default to 0 for POST)

**What was cut:**
- Build configuration, CI setup, test infrastructure
- Implementation details specific to each repo's domain
- Anything that only makes sense in the context of that specific library
- Code that depends on those libraries' internal types

**Compression:** ~15,000 lines of code → 1,519 lines of skill. Ratio: ~10:1

---

## Example 4: Long-Form Article → Umbrella Skill + Companions

**Source:** OpenAI "Harness Engineering" article (~3,000 words)

**The decomposition decision:**
The article contained 5+ distinct ideas that trigger in different contexts:
1. How to write AGENTS.md → triggers when creating agent instruction files
2. Repo structure for agents → triggers when setting up new projects
3. Progressive disclosure → sub-topic of repo structure
4. Mechanical enforcement → sub-topic of repo structure
5. Entropy management → sub-topic of repo structure

Ideas 1 and 2 trigger independently (different user intents), so they became
separate skills. Ideas 3-5 are always needed in the context of idea 2, so they
became reference files within the `agent-first-repo` skill.

**The cross-reference pattern:**
The article also referenced two external concepts:
- matklad's ARCHITECTURE.md → already a skill (`architecture-md`)
- "Parse, don't validate" → already a skill (`parse-dont-validate`)

Rather than duplicating those skills' content, `agent-first-repo` includes
2-3 sentences of contextualized summary + a name-drop pointing to the companion
skill. This keeps each skill lean and avoids content drift between copies.

**Result:**
- `agents-md` — standalone, 184 lines
- `agent-first-repo` — 156 lines SKILL.md + 3 references (505 lines)
- Cross-references to `architecture-md` and `parse-dont-validate`

---

## The Pattern

Across all examples, the distillation process follows the same shape:

```
Source material (broad, explanatory, motivational)
    ↓ Extract transferable principles
    ↓ Cut motivation, history, persuasion
    ↓ Translate to user's language/ecosystem
    ↓ Add structure: rules → examples → anti-patterns → checklist
    ↓ Decide shape: single file / with references / split skills
    ↓ Cross-reference companions, don't duplicate
Skill (narrow, imperative, actionable)
```

The compression ratio is consistently 7:1 to 20:1. If your skill is longer than
1/5th the source material, you're likely summarizing rather than distilling.
