# sk.architecture
Defines service boundaries and design for a unit.
Role: architect | Level: unit
ONE document per unit — covers all stories in unit.

Internal sub-skill — invoked by sk.design. Do not invoke directly.

## Step 0: Capability Pack Selection
Load tech stack packs relevant to this unit's architecture before designing.

1. Read session.yaml → get `active_unit` and `active_intent`
2. Read all stories in the unit → check `tags` arrays for domain keywords
3. Read applicable packs. **Load ≤6 packs total.**

- Always: `.claude/skills/csharp-clean-arch/SKILL.md`
- `bff` in any story tag → `.claude/skills/bff-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `mediatr`, `hangfire` → `.claude/skills/messaging-patterns/SKILL.md`
- `workflow`, `elsa`, `sla`, `timer` → `.claude/skills/workflow-patterns/SKILL.md`
- `auth`, `keycloak`, `firebase` → `.claude/skills/auth-patterns/SKILL.md`

List the packs loaded before continuing.

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

## Engineering Review (mandatory — runs after step 5)
Validate the written architecture against:
- `.specify/memory/service-registry.md` — no new service boundary violations
- `.specify/memory/domain-model.md` — no entity ownership conflicts with existing units
- `.specify/memory/architecture-decisions.md` — no contradiction of existing ADR decisions

Flag findings as:
- BLOCKING: boundary violation, entity ownership conflict, or direct ADR contradiction
  → fix architecture before proceeding
- MEDIUM: consistency violation (undeclared or incorrect consistency level for a write path),
  missing index coverage for a query pattern, N+1 risk on a read path, undeclared
  transaction boundary on a write path, or missing failure mode for an external dependency
  → must be resolved before proceeding; counts as a blocker in autopilot mode
- ADVISORY: new cross-service decision introduced
  → suggest creating an ADR via sk.adr before implementation begins

If all checks pass: report "Engineering review passed — no findings."
If only ADVISORY findings: report "Engineering review passed with advisories." and list them.
If any MEDIUM or BLOCKING findings exist: report "Engineering review FAILED." and list all findings.

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
