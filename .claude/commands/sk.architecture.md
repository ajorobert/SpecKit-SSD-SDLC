# sk.architecture
Defines service boundaries and design for a unit.
Role: architect | Level: unit
ONE document per unit — covers all stories in unit.

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md
specs/intents/{intent}/units/{unit}/stories/ (all stories)
.specify/memory/domain-model.md
.specify/memory/service-registry.md
.specify/memory/architecture-decisions.md
.claude/skills/design-principles/SKILL.md

## Steps
1. [REFINE MODE] if architecture.md exists, [CREATE MODE] if not
2. If REFINE: read existing fully, preserve valid content, update changed sections
3. List all stories in unit — confirm architecture covers each one
4. Define: service responsibility, bounded context, communication
   patterns, internal components, data flow, security approach
5. Write architecture document
6. If validate checkpoint: pause for user approval before continuing
7. Suggest ADR for any cross-service decision made

## Output Artifacts
specs/intents/{intent}/units/{unit}/architecture.md
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (boundary section updated if architecture changes domain ownership)

## Steps (continued)
8. If architecture introduces or changes domain boundary:
   Update unit knowledge-base.md boundary rationale
   If boundary change is significant: suggest domain-level
   knowledge base update via sk.knowledge-base --tier domain

## Quality Bar
- All unit stories explicitly listed in stories-covered
- Bounded context clearly defined
- No conflicts with service-registry.md
- Security approach defined
- Open questions listed not hidden
- Consistency requirement declared for every write path (strong / eventual / causal)
- Failure mode documented for every external dependency (timeout, fallback, circuit breaker)
- DDIA-significant decisions recorded in unit knowledge-base (why, not what)
