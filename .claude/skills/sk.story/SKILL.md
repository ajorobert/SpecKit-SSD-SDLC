---
name: sk.story
description: "Invoke when: driving the complete story capture and clarification pipeline. Role: po (orchestrator). Invokes: sk.specify → loops sk.clarify (business) → loops sk.architect-probe (technical) → validation gate → finalize single story folder (story.md, requirement.md, acceptance-criteria.md, optional jira.md). Jira mode (--jira {KEY}) ingests Summary/Description/Acceptance Criteria/Components/Labels/Attachments and maps Components → project names via .specify/memory/jira-component-map.md into a story.md ## Project section (scope signal for sk.design)."
subagent_type: SpecKit PO Agent
inject_files:
  - .specify/memory/system-context.md
  - .specify/memory/architecture-decisions.md
  - .specify/memory/domain-model.md
  - .specify/memory/projects/index.md
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
Invokes sk.specify -> loops sk.clarify (business) -> loops sk.architect-probe (technical) -> validates completeness -> finalizes a single story folder (story.md, requirement.md, acceptance-criteria.md, optional jira.md). The story is NOT split per project; impacted projects are recorded in unit-brief.md.
This is the primary way Product Owners should capture and refine stories.

Jira mode (`sk.story --jira {ISSUE_KEY}`) ingests the issue's Summary, Description, Acceptance
Criteria, Components, Labels, and Attachments. Jira Components are mapped to internal project
name(s) via the configurable `.specify/memory/jira-component-map.md` (names are never hardcoded)
and written into a `## Project` section in story.md — the scope signal consumed by sk.design.

Read and execute the full workflow in `prompt.md` in this directory.
