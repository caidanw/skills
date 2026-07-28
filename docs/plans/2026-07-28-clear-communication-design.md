# Clear Communication Skill Design

## Purpose

Create a persistent communication mode for clear, natural agent responses. Draw from the public principles of ASD-STE100 Simplified Technical English, ISO 24495-1 plain language, and George Orwell's writing rules without claiming conformity.

## Scope

Apply the style to all user-facing prose after explicit mode activation. Do not change code, commands, logs, quotations, or exact technical terms. Keep the mode active until the user directly asks to stop it. Treat one-off plain-language requests as local to the requested response or artifact.

## Design

Use four reader-centered tests from public descriptions of ISO 24495-1:

1. Give the reader relevant information.
2. Make the information easy to find.
3. Make the information easy to understand.
4. Make the information easy to use.

Add selected controlled-language practices from ASD-STE100:

- Use one stable term for each concept.
- Prefer active voice when it identifies responsibility.
- Put conditions and prerequisites before actions.
- Give one primary action in each numbered step.
- State warnings directly and explain the consequence.

Add Orwell's revision principles:

- Remove clichés, inflated wording, filler, and repetition.
- Prefer familiar words when they preserve precision.
- Cut words that add no meaning.
- Keep technical terms when they are more accurate.
- Break any style rule that harms clarity, accuracy, safety, courtesy, or natural grammar.

## Constraints

Do not enforce the ASD-STE100 dictionary, hard sentence-length limits, restricted verb forms, or an absolute ban on passive voice, contractions, and technical terms. Do not remove useful context or genuine uncertainty for brevity.

Describe the result as informed by the sources. Do not reproduce either standard or claim certification or compliance.

If the user needs formal conformity, state that the skill cannot verify it. Offer a clear-language draft and recommend review with the authorized standard and a qualified human reviewer.

## Structure

Use one `clear-communication/SKILL.md` file. Include persistence rules, the writing workflow, exceptions, before-and-after examples, a pre-send check, source links, and a non-conformity notice. No scripts or reference files are necessary.

## Verification

- Validate the skill frontmatter and package structure with the skill-creator tools.
- Regenerate the Available Skills table in `README.md`.
- Review the final diff for unrelated changes.
