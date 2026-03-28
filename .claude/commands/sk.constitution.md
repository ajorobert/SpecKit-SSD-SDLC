# sk.constitution
Initializes project principles and standards.
Role: any | Level: project

## Input Artifacts
.specify/memory/system-context.md (check if populated)

## Steps
1. [REFINE MODE] if constitution.md exists, [CREATE MODE] if not
2. Execute upstream.constitution from upstream-adapter.md
3. After completion prompt user to populate:
   .specify/memory/system-context.md
   .specify/memory/standards/tech-stack.md

## Output Artifacts
.specify/memory/constitution.md (upstream managed)

## Quality Bar
- System context populated before any other command runs
- Tech stack defined and stable
