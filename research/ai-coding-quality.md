# AI Coding Quality: Research Findings

Design rationale for the skills system. This document captures what academic research, industry publications, and practitioners have found about getting AI agents to write good code. Reference this when building or updating skills — it explains WHY our skills recommend what they do.

This is NOT a skill. Agents don't load this. It's for the humans who design the agent's instructions.

---

## 1. What the Research Proves

Findings from peer-reviewed papers and large-scale empirical studies.

### Self-Repair Works for Syntax, Fails for Logic

LLMs can fix their own code, but only when given execution feedback (error messages, stack traces, test results). Without feedback, models often make code *worse*. Fix rates: 60-80% for runtime/syntax errors, only 20-30% for logical errors. 3-5 iteration loops are optimal — diminishing returns after that.

**Implication for skills:** Always tell agents to run tests after changes. The `typescript-refactoring` skill's "verify → change → verify → commit" loop is directly supported by this research.

*Sources: AlphaCodium (2024), InspectCoder (2025), Self-Debugging (Chen et al., 2023)*

### 40% of AI-Generated Code Has Security Vulnerabilities

Systematic study across 89 scenarios, 1,689 programs: ~40% of Copilot-generated code contained security vulnerabilities including SQL injection (25% of database code), XSS (30% of web code), hardcoded credentials (15% of auth code), and missing input validation (50% of user-facing code).

A separate controlled experiment (47 participants) found that developers with AI assistants wrote **significantly less secure code** while being **more confident** in its security.

**Implication for skills:** Every skill that touches code patterns should include security awareness. Our `typescript` skill now includes a security warning in "What NOT to Do."

*Sources: "Asleep at the Keyboard?" (NYU, IEEE S&P 2022, arXiv:2108.09293), Stanford CCS 2023 (arXiv:2211.03622)*

### Code Churn Is Doubling

Analysis of 153 million lines of code: code churn (lines reverted/updated within 2 weeks of authoring) projected to double in 2024 vs 2021 baseline. Pattern: increase in copy/paste code, decrease in code reuse (DRY violations). The pattern resembles "itinerant contributor" — someone who doesn't understand the codebase writing short-term fixes.

**Implication for skills:** The `typescript-refactoring` skill's emphasis on naming, structure, and consistency directly combats this pattern. The `karpathy-guidelines` skill's "surgical changes" rule is also supported.

*Source: GitClear "Coding on Copilot" report (2024), 153M lines analyzed*

### Long Context Is a Red Herring

Models with 128K+ context windows don't use the extra context effectively. On SWE-bench, GPT-4 with 128K context performed *worse* than GPT-4 with 32K + retrieval-augmented generation. The "lost-in-the-middle" effect causes models to ignore information in the middle of long contexts.

**Implication for skills:** Skills should be concise. Reference files should be self-contained. Don't dump everything into one massive file hoping the model will find what it needs.

*Sources: "The Limits of Long-Context Reasoning" (2026), multiple RAG-for-code papers (2024-2025)*

### Agent Architecture > Model Size

SWE-agent (Princeton) showed that a well-designed agent with custom tools outperforms a larger model with generic tools. A mini-SWE-agent achieved 65% on SWE-bench Verified in just 100 lines of Python. The interface between agent and environment (the "ACI" — Agent-Computer Interface) matters more than raw model capability.

**Implication for skills:** Tool design and interface design for agents deserve as much investment as the prompts themselves. Skills are part of this interface.

*Sources: SWE-agent (Princeton, arXiv:2405.15793), Anthropic "Building Effective Agents" (Dec 2024)*

### Chain-of-Thought: Helps for Algorithms, Hurts for CRUD

CoT prompting improves complex algorithmic problems (+12%) but degrades simple CRUD tasks (-8%). Models already know common patterns; step-by-step reasoning adds noise for straightforward code.

**Implication for skills:** Don't instruct agents to "think step by step" for simple tasks. Reserve detailed reasoning for complex refactoring, debugging, and architectural decisions.

*Sources: Multiple CoT-for-code papers (2024)*

### Few-Shot: Helps for Unfamiliar APIs Only

Few-shot examples improve code generation for domain-specific APIs (+15-25%) but hurt for standard library usage (-5-10%). The model already knows `Array.filter()` — showing it examples wastes tokens and introduces noise.

**Implication for skills:** Include concrete code examples in skills for domain-specific patterns (branded types, Result types, Disposable). Don't waste space on examples of basic language features.

*Sources: Few-shot code generation papers (2023-2024)*

---

## 2. What Practitioners Report

Insights from credible practitioners and company engineering teams.

### Anthropic: Tools > Prompts

"We spent more time optimizing our tools than the overall prompt" for SWE-bench. Specific finding: changing tools to require absolute filepaths instead of relative ones eliminated a class of errors entirely. Tool documentation should include example usage, edge cases, input format requirements, and clear boundaries.

Key framework: Workflows (predefined paths) vs. Agents (LLM-directed). "Start simple, add complexity only when needed." The most successful implementations use simple, composable patterns — not complex frameworks.

*Source: anthropic.com/research/building-effective-agents (Dec 2024)*

### Böckeler / Martin Fowler: Context Engineering

"Context engineering is curating what the model sees so that you get a better result." Key insight: "This is not *really* engineering... execution still depends on how well the LLM interprets them!"

Recommendation: Build context gradually. Don't front-load rules. "The models have gotten quite powerful, so what you might have had to put into context half a year ago might not even be necessary anymore."

Transparency about context size is crucial. Track what's consuming context and prune regularly.

*Source: martinfowler.com/articles/exploring-gen-ai/context-engineering-coding-agents.html (Feb 2026)*

### OpenAI: Harness Engineering

A team built a 1M+ line codebase with zero manually typed code. Their harness has three components:

1. **Context engineering**: Continuously enhanced knowledge base in the codebase
2. **Architectural constraints**: Deterministic custom linters AND structural tests (not just LLM-based enforcement)
3. **Garbage collection agents**: Run periodically to find inconsistencies, fight entropy

Key quote: "When the agent struggles, we treat it as a signal: identify what is missing — tools, guardrails, documentation — and feed it back into the repository, always by having Codex itself write the fix."

**Missing from their writeup:** Verification of functionality and behavior (noted by Böckeler).

*Source: openai.com/index/harness-engineering/ (Feb 2026), analysis by Böckeler at martinfowler.com*

### Simon Willison: Cognitive Debt

When you lose track of how agent-written code works, you accumulate "cognitive debt" — similar to technical debt but harder to pay down. Mitigation: interactive explanations (ask the agent to explain its code), linear walkthroughs, maintaining test coverage, using agents to generate documentation.

Anti-patterns: Don't file PRs with unreviewed code. Don't inflict agent output on collaborators without understanding it.

*Source: simonwillison.net, multiple posts 2024-2026*

### Andrej Karpathy: The November 2025 Inflection

"Coding agents basically didn't work before December and basically work since." The unlock was not smarter models alone — it was test suites + benchmarking scripts enabling agents to self-correct.

*Source: Twitter/X, Feb 2026*

### Matt Pocock: TypeScript for AI

Key recommendations that directly influenced our `typescript` skill:
- Default to `type`, use `interface` only for `extends`
- Declare return types on exported functions (helps AI comprehension AND compilation performance)
- Enable `noUncheckedIndexedAccess` (catches the most common AI-generated bug: unsafe indexed access)
- Use `--erasableSyntaxOnly` (aligns with Node's native TS support, disables enums/namespaces)

*Source: totaltypescript.com, multiple articles 2024-2026*

### Ladybird Browser: Conformance-Suite-Driven Migration

Ported 25,000 lines of JavaScript engine from C++ to Rust in 2 weeks using Claude Code + Codex. The unlock: test262 conformance suite enabled byte-for-byte verification. Without the suite, this would have been impossible to trust.

**Key pattern:** Conformance test suites are a massive unlock for AI-assisted large-scale migrations.

*Source: ladybird.org/posts/adopting-rust/ (Feb 2026)*

---

## 3. Context Engineering Principles

How to structure the information agents receive, based on the research.

### The Knowledge Hierarchy

From Böckeler's analysis of Claude Code and other tools:

| Layer | Loading Strategy | Example |
|-------|-----------------|---------|
| Always-loaded | Agent software loads at session start | CLAUDE.md, AGENTS.md |
| Path-scoped | Loaded when files at configured paths are opened | `.cursor/rules`, glob-matched rules |
| Lazy-loaded | LLM decides to load based on description | Skills (SKILL.md) |
| Deterministic | Triggered by agent lifecycle events | Hooks (pre-commit, post-edit) |
| LLM-triggered | LLM decides to call based on tool description | MCP servers, tool calls |

**Implication:** Put the most critical guidance (style rules, "never do this" rules) in always-loaded context. Put domain-specific guidance in lazy-loaded skills. Put deep reference material in files that skills can point to.

### Rules of Thumb

1. **Less context is often better.** Beyond 32K tokens, performance degrades.
2. **Build up gradually.** Start with minimal rules. Add only when you see repeated failures.
3. **Scope rules to file types.** Don't load TypeScript conventions for Python files.
4. **Code examples > prose.** Models learn better from examples than descriptions.
5. **Prune regularly.** Remove rules that are no longer needed as models improve.
6. **Track context size.** Know what's consuming your context window.

### What Makes Good Context

- **Explicit types and return types** — models infer purpose from types
- **Descriptive function/variable names** — AI infers intent from names more than humans realize
- **Consistent patterns across the codebase** — models learn by example
- **Small, focused files** — models struggle with 500+ line files
- **Architecture documentation** — ARCHITECTURE.md helps agents navigate unfamiliar codebases

---

## 4. The Harness Concept

From OpenAI's Harness Engineering and related work.

A "harness" is the combination of tooling and practices that keeps AI agents in check. It has three components:

### Component 1: Context Engineering
The knowledge base — AGENTS.md, ARCHITECTURE.md, rules files, skills. Continuously enhanced: when the agent struggles, feed the missing knowledge back into the repo.

### Component 2: Architectural Constraints
Enforced by BOTH deterministic tools (linters, structural tests, type checkers) AND LLM-based agents. Key insight: deterministic enforcement is more reliable than LLM-based enforcement. Use both.

Examples:
- Custom ESLint rules for project-specific patterns
- TypeScript strict mode + `noUncheckedIndexedAccess`
- Structural tests (ArchUnit-style) for module boundaries
- CI checks that block PRs with `any` or missing return types

### Component 3: Garbage Collection
Periodic cleanup agents that find inconsistencies, stale documentation, violations of architectural constraints. Fights the entropy that accumulates as agents generate code over time.

### Böckeler's Key Question

"Will harnesses — with custom linters, structural tests, basic context and knowledge documentation, and additional context providers — become the new service templates?"

The answer isn't clear yet, but the direction is: **the harness IS the engineering.** The code is an output.

---

## 5. Key Statistics

| Statistic | Source | Year | Confidence |
|-----------|--------|------|------------|
| 40% of AI-generated code contains security vulnerabilities | NYU / IEEE S&P | 2022 | High (peer-reviewed) |
| Code churn projected to double with AI adoption | GitClear, 153M lines | 2024 | High (large-scale empirical) |
| Users with AI write less secure code, with more confidence | Stanford / CCS | 2023 | High (controlled experiment, n=47) |
| Self-repair: 60-80% fix rate for syntax, 20-30% for logic | Multiple papers | 2023-2025 | High (replicated) |
| 55% faster task completion with Copilot | GitHub | 2022 | Medium (self-reported, no quality measure) |
| RAG improves repository-level tasks by 20-40% | Multiple papers | 2024-2025 | Medium-high |
| Few-shot helps +15-25% for unfamiliar APIs, hurts -5-10% for standard APIs | Multiple papers | 2023-2024 | Medium |
| AlphaCodium: GPT-4 accuracy 19% → 44% with multi-stage flow | Ridnik et al. | 2024 | High |
| 3-5 iteration loops optimal, diminishing returns after | Multiple papers | 2023-2025 | Medium-high |
| Long context (>32K): performance degrades vs. RAG approach | Multiple papers | 2025-2026 | Medium |

---

## 6. Unsolved Problems

What the research says we DON'T know how to solve yet.

### Repository-Level Understanding
Models process files independently and lack global reasoning about cross-file dependencies. Even GPT-4 fails on 70% of multi-file tasks. Promising approaches: code graphs, hierarchical summarization, architectural constraints. But none are production-ready at scale.

### Logical Error Detection
Self-repair works for syntax and runtime errors but fails for semantic bugs — when code runs but produces wrong results. No good automated solution exists. Human review or property-based testing are the best available tools.

### Long-Horizon Planning
Models can work for 100+ turns but errors compound. No robust checkpointing or rollback mechanism. Costs spiral. Current practical limit: ~10-20 coherent steps before models "lose the plot."

### True Learning Within Sessions
Current "self-improvement" is just iteration + self-critique, not actual learning. No weight updates, no retained knowledge across sessions. Fine-tuning on specific codebases is expensive and rarely done.

### Security by Default
Models are trained on Stack Overflow and GitHub — which contain insecure code. They reproduce what they've seen. Fine-tuning on secure code examples can reduce vulnerabilities by 96% (DeepSeek study), but this isn't standard practice.

---

## 7. How This Informs Our Skills

Mapping from research findings to specific skill decisions.

| Research Finding | Skill | Section | How It Influenced The Skill |
|-----------------|-------|---------|---------------------------|
| Explicit return types help AI comprehension | `typescript` | Style | "Declare return types on top-level exported functions" |
| `noUncheckedIndexedAccess` catches AI's most common bug | `typescript` | Style | Added as a recommended tsconfig flag |
| 40% security vulnerability rate | `typescript` | What NOT to Do | Added security warning |
| Self-repair needs execution feedback | `typescript-refactoring` | Iron Rules | "Never refactor without tests" |
| Code churn doubles with AI | `typescript-refactoring` | Priority Order | Naming and consistency emphasized |
| Small functions improve AI comprehension | `typescript` | Section 2 | "Small Functions That Compose" |
| Discriminated unions prevent boolean soup | `typescript` | Section 5 | "Make Illegal States Unrepresentable" |
| Consistent patterns help AI learn | `typescript-refactoring` | AI-Friendliness | "Consistent patterns teach by example" |
| Long context degrades performance | Skill design | N/A | Skills kept concise (~300 lines), deep content in references/ |
| Few-shot helps for unfamiliar patterns | Skill design | N/A | Code examples for domain-specific patterns, not basic syntax |
| Build context gradually | Skill design | N/A | Knowledge hierarchy: always-loaded → lazy-loaded → references |
| Tools > prompts | `agent-first-repo` | Architecture | Emphasis on mechanical enforcement (linters, tests) over prose |
| Cognitive debt from AI code | `typescript-refactoring` | What NOT to Do | "Don't inflict unreviewed agent code" (implicit) |

---

## Sources

### Tier 1: Peer-Reviewed / Official Research
- "Asleep at the Keyboard?" — NYU, IEEE S&P 2022 (arXiv:2108.09293)
- "Do Users Write More Insecure Code with AI?" — Stanford, CCS 2023 (arXiv:2211.03622)
- SWE-bench — Jimenez et al., ICLR 2024 (swebench.com)
- SWE-agent — Princeton/Stanford (arXiv:2405.15793)
- AlphaCodium — Ridnik et al., 2024
- HumanEval / Codex — OpenAI (arXiv:2107.03374)
- Anthropic: "Building Effective Agents" (anthropic.com/research/building-effective-agents)
- Anthropic: SWE-bench Sonnet (anthropic.com/research/swe-bench-sonnet)

### Tier 2: Industry Research & Large-Scale Studies
- GitClear "Coding on Copilot" report, 2024 (153M lines analyzed)
- GitHub Copilot productivity study, 2022
- OpenAI: "Harness Engineering" (openai.com/index/harness-engineering)
- HELM framework — Stanford (arXiv:2211.09110)
- Code Llama technical report — Meta (arXiv:2308.12950)

### Tier 3: Practitioner Blogs & Analysis
- Birgitta Böckeler / Martin Fowler: "Context Engineering for Coding Agents" (Feb 2026)
- Birgitta Böckeler / Martin Fowler: "Harness Engineering" (Feb 2026)
- Simon Willison: Agentic engineering patterns, cognitive debt (simonwillison.net)
- Matt Pocock / Total TypeScript: cursor rules, return types, erasableSyntaxOnly
- Andrej Karpathy: November 2025 inflection point (Twitter/X)
- Ladybird Browser: Rust adoption with AI (ladybird.org/posts/adopting-rust)
