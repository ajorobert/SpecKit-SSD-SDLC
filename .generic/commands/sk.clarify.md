<!-- GENERIC LAYER — self-contained command -->
<!-- Before executing: read .generic/hooks/pre-command.md -->
<!-- After executing: read .generic/hooks/post-command.md -->
<!-- Context to load: see .generic/context-maps/command-context-map.md -->

# sk.clarify
Wraps: upstream.clarify
Story-level command — requires active_story_id

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Execute upstream clarify
Read upstream.clarify from upstream-adapter.md
Execute upstream clarify instructions in full

## Post-execution
If clarification changes scope:
- Flag to user — sk.specify may need updating
- Suggest re-running checkpoint classification
- Update story frontmatter if scope changed