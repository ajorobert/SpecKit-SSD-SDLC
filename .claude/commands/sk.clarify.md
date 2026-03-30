# sk.clarify
Resolves ambiguities in the active story.
Role: po, architect, lead | Level: story

## Input Artifacts
story-{ID}.md (active story)

## Steps
1. Execute upstream.clarify from upstream-adapter.md in full
2. If clarification changes scope: flag to user
   suggest updating story acceptance criteria

## Output Artifacts
story-{ID}.md (updated if scope changed)

## Quality Bar
- All ambiguities resolved before sk.plan proceeds
- Scope changes reflected in story frontmatter
