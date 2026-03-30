# Intents
Hierarchy: Intent → Unit → Story
Session focus tracked in .claude/session.yaml (local, gitignored)
Team work status tracked in story frontmatter

## ID Format
Intent code: CHK, AUTH, ORD (short uppercase)
Unit ID: {INTENT-CODE}-{UNIT-CODE} e.g. CHK-PAY
Story ID: {INTENT-CODE}-{UNIT-CODE}-{NNN} e.g. CHK-PAY-001

## Structure
specs/intents/{NNN}-{intent-name}/
  intent.md
  system-context.md
  units/
    {unit-name}/
      unit-brief.md
      architecture.md      ← unit-level, covers all stories
      data-model.md        ← unit-level
      contracts/           ← unit-level
        api-spec.json
      stories/
        story-{ID}.md      ← story-level, has status frontmatter
        {story-id}/
          plan.md          ← story-level
          tasks.md         ← story-level

## Team Coordination
sk.session list            ← kanban view of all stories
sk.session status          ← current session focus
Story status flow: draft → ready → in-progress → review → done
