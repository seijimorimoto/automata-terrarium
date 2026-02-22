# CLAUDE.md

This repo stores reusable Claude Code skills, hooks, and settings.

## Commit Message Style

Use [Conventional Commits](https://www.conventionalcommits.org/) for individual commits on non-main branches:

```
<type>(<scope>): <short summary in imperative mood>

<optional body -- explains the "why", wraps at 72 chars>
```

**Types:** `feat`, `fix`, `docs`, `refactor`, `chore`, `test`, `style`

**Scope:** the area of the codebase affected (e.g., `hook`, `settings`, `skills`, etc.)

**Examples:**

```
feat(skills): add code-review skill
fix(hooks): handle missing stdin in pre-commit hook
docs(settings): document permission presets
chore: update .gitignore
```

## Pull Request Template

```markdown
## Summary
<!-- 1-3 bullet points describing what this PR does and why -->

## Changes
<!-- List of notable changes, grouped by area if needed -->

## Test plan
<!-- How to verify this works — checklist format -->
- [ ] Step 1
- [ ] Step 2
```

## Branching

- Never commit directly to `main` — a pre-commit hook enforces this.
- Create feature branches for all changes and merge via PRs.

## Project Structure

```
skills/      - Claude Code skills (each skill in its own subdirectory)
hooks/       - Claude Code event-driven hook scripts
settings/    - Reusable settings snippets
git-hooks/   - Git hooks for repo workflow (not Claude hooks)
```

## Guidelines

- Each skill must live in its own folder under `skills/`.
- Every directory should have a `README.md` explaining its contents and usage.
- Do not commit secrets, credentials, or `.env` files.
