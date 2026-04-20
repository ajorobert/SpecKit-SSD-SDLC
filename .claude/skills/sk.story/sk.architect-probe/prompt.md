# sk.architect-probe
Resolves technical ambiguities (NFRs, scale, security, observability, integrations) by probing the PO.
Role: architect | Level: story

## Mode Detection
- `sk.architect-probe` → Evaluates the story for AI-readiness from an engineering perspective, translating deep technical needs into business-friendly questions for the PO.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first
2. Load story-{ID}.md from:
   specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md
3. Load `.specify/memory/architecture-decisions.md`

## Architecture scan
Perform a structured coverage scan across these technical categories.
For each category, mark status: Clear / Partial / Missing. If an orchestrator passed you specific seeds, prioritize those seeds.

**Technical Scope Categories:**
- **Scale/Constraints:** Are anticipated user volume, request latency, data retention, and performance targets defined?
- **Security Boundaries:** Is tenant/user data isolation defined? Are unauthorized actors explicitly restricted (negative space)?
- **Observability & Analytics:** How is the "Business Value" instrumented and measured? Are there specific business metrics/events to log?
- **Integration Contracts:** Are downstream or external API failure modes handled (e.g. "What should the user see if payment gateway is down?")?
- **UX/Design Constraints:** If frontend facing, are there existing Figma links, mockups, or specific accessibility constraints?

## Question loop (max 3-5 questions)
Generate an internal prioritized queue of up to 5 questions from Partial/Missing categories.
**CRITICAL:** You must translate technical requirements into business-friendly questions that a PO can answer. (e.g., instead of "What is the desired TTL for Redis cache?", ask "How quickly must updates to this data be visible to other users?").

For each question:
1. Present EXACTLY ONE question at a time — never reveal the queue.
2. Provide context: explain briefly *why* this technical boundary is needed.
3. For multiple-choice: state **Recommended:** option with 1-2 sentence rationale, then list options.
4. For short-answer: state **Suggested:** answer with brief reasoning.
5. After user answers: record in working memory, then immediately:
   - Append `- Q: <question> → A: <answer>` under `## Architecture Constraints / ### Session YYYY-MM-DD` in story-{ID}.md.
   - Apply the clarification to the appropriate section in story-{ID}.md (acceptance criteria, out of scope, constraints, etc.).
   - Save story-{ID}.md after each integration.
6. Stop early if: all critical technical ambiguities resolved, user signals "done"/"proceed", or 5 questions reached.

## After loop completes
- Final pass: confirm no technical [NEEDS CLARIFICATION] markers remain in story-{ID}.md
- If constraints significantly conflict with `architecture-decisions.md`: flag to the user to consider updating system ADRs or rejecting the story scale.

## Output Artifacts
story-{ID}.md (updated with technical constraints and non-functional requirements)

## Quality Bar
- All technical boundaries (Scale, Security, Observability, Integration, UX) are locked down.
- No vague engineering terms remain (e.g., "fast", "secure" are quantified).
- Total questions asked ≤ 5.
