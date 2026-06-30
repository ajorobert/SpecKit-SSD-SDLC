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

- Always (canonical SSOT): `.claude/skills/backend-architecture/SKILL.md`
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`
- `bff`, `aggregation`, `endpoint`, `http entry` in any story tag → `.claude/skills/api-endpoint-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `hangfire`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus`, `workflow`, `elsa`, `activity`, `signal`, `bookmark`, `human in the loop`, `job`, `scheduled`, `recurring`, `cron`, `background`, `batch`, `dashboard`, `sla`, `timer`, `breach` → `.claude/skills/orchestration-patterns/SKILL.md`
- `authorization`, `role`, `policy`, `rbac`, `abac`, `permission`, `user context`, `resource ownership`, `audit identity` → `.claude/skills/authorization-patterns/SKILL.md`
- `authentication`, `jwt`, `bearer`, `keycloak`, `oidc`, `claim`, `mfa`, `otp`, `m2m`, `claim mapping`, `composition root`, `wiring` → `.claude/skills/infrastructure-wiring/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

List the packs loaded before continuing.

## Design Output Layout
All design artifacts for the unit live under `specs/intents/{intent}/units/{unit}/02-design/`
(the design sibling of the story phase's `01-story/`). This sub-skill writes
`02-design/architecture.md` and `02-design/impact-analysis.md`. Create the `02-design/`
folder if it does not exist.

## Input Artifacts
specs/intents/{intent}/units/{unit}/unit-brief.md
specs/intents/{intent}/units/{unit}/{NN}-story/ (all story folders — story.md, requirement.md, acceptance-criteria.md)
.specify/memory/domain-model.md
.specify/memory/service-registry.md
.specify/memory/architecture-decisions.md
.claude/skills/design-principles/SKILL.md

## Steps
1. [REFINE MODE] if architecture.md exists, [CREATE MODE] if not
2. If REFINE: read existing fully, preserve valid content, update changed sections
3. List all stories in unit (read every `{NN}-story/` folder) — confirm architecture covers each one
4. Define: service responsibility, bounded context, communication
   patterns, internal components, data flow, security approach
5. Write architecture document to `02-design/architecture.md`
   (use `templates/artifacts/architecture-template.md` as the structure)
6. Write the impact analysis to `02-design/impact-analysis.md`:
   - Read `unit-brief.md` → Impacted Projects table (canonical list of affected projects)
   - For each project, record change type (new | modified | config-only | none) and what the
     design changes in it; capture cross-project contracts and sequencing/dependencies
   - Use `templates/artifacts/impact-analysis-template.md` as the structure
   - This is the design-phase, unit-scoped impact view; it does NOT replace sk.impact's
     blast-radius report. Every project in unit-brief.md must appear exactly once.
7. If validate checkpoint: pause for user approval before continuing
8. Suggest ADR for any cross-service decision made

## Engineering Review (mandatory — runs after steps 5–6)
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
specs/intents/{intent}/units/{unit}/02-design/architecture.md
specs/intents/{intent}/units/{unit}/02-design/impact-analysis.md
specs/intents/{intent}/units/{unit}/knowledge-base.md
  (unit-tier KB stays at unit root — boundary section updated if architecture changes domain ownership)

## Steps (continued)
9. If architecture introduces or changes domain boundary:
   Update unit knowledge-base.md boundary rationale
   If boundary change is significant: suggest domain-level
   knowledge base update via sk.knowledge-base --tier domain

## Quality Bar
- Both `02-design/architecture.md` and `02-design/impact-analysis.md` written
- impact-analysis.md lists every project from unit-brief.md Impacted Projects exactly once, each with a change type
- All unit stories explicitly listed in stories-covered
- Bounded context clearly defined
- No conflicts with service-registry.md
- Security approach defined
- Open questions listed not hidden
- Consistency requirement declared for every write path (strong / eventual / causal)
- Failure mode documented for every external dependency (timeout, fallback, circuit breaker)
- DDIA-significant decisions recorded in unit knowledge-base (why, not what)
