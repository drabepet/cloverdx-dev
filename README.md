# cloverAssistant

Workspace for building and maintaining the [cloverdx-dev](https://github.com/drabepet/cloverdx-dev) Claude skill.

## Structure

```
skill/          — The Claude skill (published to cloverdx-dev repo)
  SKILL.md      — Skill definition and trigger instructions
  README.md     — Public-facing documentation
  references/   — 24 reference files loaded on demand by the skill
examples/       — CloverDX TrainingExamples sandbox (gitignored)
*.txt           — Raw doc extracts used to build reference files (gitignored)
```

## Remotes

| Remote | Repo | Visibility |
|---|---|---|
| `origin` | `drabepet/cloverAssistant` | Private — full workspace |
| `cloverdx-dev` | `drabepet/cloverdx-dev` | Public — skill only |

## Publishing Updates

Edit files under `skill/`, then:

```bash
git add skill/
git commit -m "describe what changed"
git push                    # private workspace
git push cloverdx-dev main  # public skill repo
```
