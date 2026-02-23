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
- Name branches using the format `u/{user_name}/{feature_title}` (e.g., `u/johndoe/organize-core-by-business-concern`).

## Shell commands

- When running commands like `git commit -m` or `az repos pr create --description`, always use single quotes around string arguments to avoid permission issues caused by shell expansion of `$()` or similar constructs.

## Project Structure

```
skills/      - Claude Code skills (each skill in its own subdirectory)
hooks/       - Claude Code event-driven hook scripts
settings/    - Reusable settings snippets
git-hooks/   - Git hooks for repo workflow (not Claude hooks)
```

## Documentation Conventions

### Paths

- Use **Windows-style backslashes** (`\`) as the primary path format in all inline references and examples (e.g., `~\.claude\hooks\`, `<project-root>\.claude\skills\`).
- Always show both **user-level** (`~\.claude\...`) and **project-level** (`<project-root>\.claude\...`) install locations.

### Code blocks

- Show **Windows (PowerShell)** commands first, followed by **Linux / macOS** alternatives in a separate code block.
- Use `powershell` as the language tag for Windows blocks, `sh` for Linux/macOS.
- Exception: platform-specific items (e.g., a Windows-only hook) should only show commands for their platform, without the `# Windows (PowerShell)` comment header.

### Installation instructions

- Each skill and hook README must include:
  1. **Prerequisites** with install commands (not just names).
  2. **Copy-to-`.claude`** step showing how to install at user or project level.
  3. **Registration** step (for hooks: settings.json config; for skills: just the copy is enough).
- Parent-level READMEs (`skills/README.md`, `hooks/README.md`) must include an **Available [Skills/Hooks]** table listing all items.
- The repo-level `README.md` must mirror those tables for discoverability.

### Naming

- Use platform suffixes for platform-specific items (e.g., `notify-windows` instead of `notify`).

## Guidelines

- Each skill must live in its own folder under `skills/`.
- Every directory should have a `README.md` explaining its contents and usage.
- Do not commit secrets, credentials, or `.env` files.
