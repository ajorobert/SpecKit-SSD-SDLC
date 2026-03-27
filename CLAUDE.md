<!-- SPECKIT-SSD-SDLC MANAGED — do not edit this section manually -->
SpecKit-SSD-SDLC

Identity
This is a spec-driven development framework for full-stack multi-service systems.
All sk.* commands live in .claude/commands/

Rules
- Before any sk.* command: read .specify/memory/command-rules.md
- Before any upstream reference: read .specify/memory/upstream-adapter.md
- For specialized context: load the relevant skill from .claude/skills/
- Never edit files inside upstream/
- Never load memory files not listed in the command's skill definition

State
- Local session state: .claude/session.yaml (gitignored)
- Lock file (runtime only): .claude/session.lock (gitignored)
<!-- END SPECKIT-SSD-SDLC MANAGED -->
