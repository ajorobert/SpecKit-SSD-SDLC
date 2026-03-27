# Post-Command Hook
Executes after every sk.* command.

## Trigger
event: after_tool_use
matcher: sk.*

## Steps

1. UPDATE SESSION
   Read .claude/session.yaml
   Write:
   - last_command: <command that ran>
   - last_command_at: <ISO 8601 timestamp>
   - last_command_status: success | failed | interrupted
   Re-read and verify written values present
   If verification fails: report to user, do not release lock

2. UPDATE TOUCHED LISTS
   If last_command produced a unit-level artifact:
   - Add active_unit_id to units_touched if not already present
   If last_command produced a story-level artifact:
   - Add active_story_id to stories_touched if not already present

3. MEMORY UPDATES (conditional)
   sk.plan OR sk.architecture → update service-registry.md, domain-model.md if changed
   sk.datamodel               → update domain-model.md
   sk.contracts               → update service-registry.md
   sk.adr                     → update architecture-decisions.md index

4. STORY STATUS UPDATE (conditional)
   sk.specify completion      → set story status: draft
   sk.plan completion         → set story status: ready
   sk.implement completion    → set story status: review
   sk.verify PASS             → set story status: done
   Update story frontmatter directly in story-{ID}.md

5. ADR TRIGGER
   If sk.plan OR sk.architecture:
   - Cross-service decision made? → suggest ADR
   - Do not create without confirmation

6. PHR TRIGGER
   If sk.architecture: create PHR automatically
   If sk.implement AND novel tradeoffs resolved: create PHR automatically

7. RELEASE LOCK
   Delete .claude/session.lock
   Confirm deletion
   If deletion fails: report to user
