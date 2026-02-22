# Skills

Custom slash-command skills for Claude Code.

## Structure

Each skill lives in its own subdirectory:

```
skills/
  my-skill/
    my-skill.md
  another-skill/
    another-skill.md
```

## Installation

Copy or symlink skill folders into `~/.claude/skills/`:

```bash
# Single skill
cp -r skills/my-skill ~/.claude/skills/

# All skills
cp -r skills/*/ ~/.claude/skills/
```

## Creating a new skill

1. Create a new directory under `skills/` named after your skill
2. Add an `.md` file inside it with the prompt/instructions
3. Use `$ARGUMENTS` placeholder for user-provided arguments

See the [Claude Code docs](https://code.claude.com/docs/en/skills) for more details.
