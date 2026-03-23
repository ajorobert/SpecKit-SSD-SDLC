# SpecKit-SSD-SDLC

A spec-driven development framework for full-stack multi-service systems,
built as a clean layer on top of [github/spec-kit](https://github.com/github/spec-kit).

## Structure

- `upstream/` — spec-kit source (read-only, managed via git subtree)
- `.your-layer/` — SpecKit-SSD-SDLC commands, templates, governance (created in Step 2)
- `.specify/` — project memory and standards (created in Step 3)
- `CLAUDE.md` — agent context file (created in Step 4)

## Updating Upstream

  git subtree pull --prefix upstream https://github.com/github/spec-kit.git main --squash

Never edit files inside `upstream/` directly.
