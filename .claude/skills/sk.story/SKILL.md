---
name: sk.story
description: "Invoke when: driving the complete story capture and clarification pipeline. Role: po (orchestrator). Invokes: sk.specify → loops sk.clarify (business) → loops sk.architect-probe (technical) → validation gate."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
rubric:
  name: story-completeness
  checks:
    - every acceptance criterion is independently testable
    - every acceptance criterion uses Given/When/Then or equivalent observable form
    - user story follows "As a {role} I want {action} so that {benefit}"
    - out-of-scope list is present and non-empty
    - minimum 3 acceptance criteria
    - no undefined external dependencies
---

Orchestrator skill — Full Story Capture Pipeline.
Invokes sk.specify -> loops sk.clarify (business) -> loops sk.architect-probe (technical) -> validates completeness.
This is the primary way Product Owners should capture and refine stories.

Read and execute the full workflow in `prompt.md` in this directory.
