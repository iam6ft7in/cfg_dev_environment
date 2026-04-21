---
description: Documentation rules, Markdown style, link hygiene, American English
paths: ["**/*.md", "**/*.mdx"]
---

# Documentation Rules

## Scope
- Applies to repos created with `platform=docs` and to any Markdown files in
  other repos.
- A docs repo has no build step and no compiled output. If a linter or static
  site generator is added later, document it in the project README.

## Markdown Style
- One H1 per file. The H1 is the document title.
- Use ATX heading syntax (`#`, `##`) only, not Setext (`===`, `---`).
- Leave a blank line above and below every heading, list, code block, and
  table.
- Line length: 88 characters soft limit, same as code. Wrap prose for diffs,
  not for display.
- Fenced code blocks only, not indented. Always specify the language:
  ```bash
  echo hello
  ```
- Prefer ordered lists when sequence matters, unordered lists otherwise.
- Use `-` for unordered list bullets. Consistency matters more than the
  specific character.

## Link Hygiene
- Prefer relative links for intra-repo references: `[text](../other.md)`, not
  a full GitHub URL. Relative links survive forks and renames.
- Use full URLs only for external resources.
- Never link to a specific commit SHA unless you need a point-in-time anchor.
  Prefer a branch or tag name.
- Check for dead links before merging doc changes. If the repo uses a link
  checker in CI, run it locally first.

## Writing Style
- American English for all prose, same as code comments and commit messages.
- No em dashes (see `core.md`). Use commas, parentheses, colons, or periods.
- Present tense, active voice. Second person (`you`) for instructions, not
  first person (`we`).
- Define acronyms on first use within a document.
- No marketing language. State what the thing is and what it does.

## File Organization
- Top-level docs: `README.md` (what it is), `CONTRIBUTING.md` (how to help),
  `CHANGELOG.md` (what changed), `SECURITY.md` (how to report issues).
- Additional docs go under `docs/`. Use snake_case filenames:
  `docs/architecture_overview.md`, not `docs/Architecture Overview.md`.
- Images and diagrams under `docs/assets/` or `docs/images/`. Reference with
  relative links.

## Code Examples in Docs
- Every code block must run (or be explicitly marked as pseudocode).
- When showing a command, include the expected output or note that output is
  omitted.
- When showing a file path, use the repo-relative form:
  `src/main.py`, not `C:\Users\...\src\main.py`.

## Review Checklist
- All headings follow the hierarchy (no skipped levels like H2 then H4).
- All links resolve.
- All code blocks specify a language.
- No typos in the first paragraph. Readers bounce on typos early.
