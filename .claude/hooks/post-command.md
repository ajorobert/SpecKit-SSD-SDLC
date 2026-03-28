# Post-Command Hook

## Trigger
event: after_tool_use
matcher: sk.*

## Steps
1. Read active story ID from .claude/session.yaml active_story_id
   If null: skip steps 2 and 3

2. Update story status in frontmatter based on command completed:
   sk.specify completion    → status: draft
   sk.plan completion       → status: ready
   sk.implement completion  → status: testing
   sk.verify PASS           → status: done

3. Write updated story file
   Re-read to confirm write succeeded
