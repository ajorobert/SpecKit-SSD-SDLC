# sk.review
Spec-aware code review: validates against bounded context, contracts, and ADRs.
Role: backend, frontend | Level: story
gstack: optional enhancement — if installed, invoke after Claude's own review for additional signal

## Step 0: Capability Pack Selection
Load the tech stack packs relevant to this review before reading any code.

1. Read session.yaml → get `role` (backend | frontend) and `active_story_id`
2. Read the active story frontmatter → check `tags` array
3. Read applicable packs. **Load ≤6 packs total.**

**Role = backend**
- Always (canonical SSOT): `.claude/skills/backend-architecture/SKILL.md`
- Always: `.claude/skills/backend-feature-patterns/SKILL.md`, `.claude/skills/design-code-review/SKILL.md`
- `bff`, `aggregation`, `endpoint`, `http entry` → `.claude/skills/api-endpoint-patterns/SKILL.md`
- `messaging`, `events`, `queue`, `rabbitmq`, `hangfire`, `command`, `query`, `handler`, `publish`, `subscribe`, `outbox`, `saga`, `integration event`, `scheduled message`, `message bus`, `workflow`, `elsa`, `activity`, `signal`, `bookmark`, `human in the loop`, `job`, `scheduled`, `recurring`, `cron`, `background`, `batch`, `dashboard`, `sla`, `timer`, `breach` → `.claude/skills/orchestration-patterns/SKILL.md`
- `authorization`, `role`, `policy`, `rbac`, `abac`, `permission`, `user context`, `resource ownership`, `audit identity` → `.claude/skills/authorization-patterns/SKILL.md`
- `authentication`, `jwt`, `bearer`, `keycloak`, `oidc`, `claim`, `mfa`, `otp`, `m2m`, `claim mapping`, `composition root`, `wiring` → `.claude/skills/infrastructure-wiring/SKILL.md`
- `persist`, `persistence`, `database`, `db`, `postgres`, `postgresql`, `ef core`, `dapper`, `migration`, `schema`, `jsonb`, `postgis`, `geo`, `transaction`, `repository`, `read model`, `projection`, `rls`, `tenant isolation`, `concurrency`, `xmin` → `.claude/skills/data-access-patterns/SKILL.md`
- `cache`, `caching`, `redis`, `hybrid cache`, `l1`, `l2`, `tag invalidation`, `distributed lock`, `rate limit`, `redlock`, `redis stream` → `.claude/skills/caching-patterns/SKILL.md`
- `search`, `elasticsearch` → `.claude/skills/search-patterns/SKILL.md`
- `file`, `upload`, `attachment`, `image`, `blob`, `storage`, `seaweedfs`, `s3`, `presigned`, `virus`, `scan`, `clamav`, `imagesharp`, `resize`, `thumbnail`, `quarantine`, `exif`, `signed url`, `bucket` → `.claude/skills/file-pipeline-patterns/SKILL.md`
- `adapter`, `integration adapter`, `external service adapter`, `vendor api`, `external integration`, `DelegatingHandler`, `chain order`, `M2M handler`, `typed httpclient`, `polly`, `resilience pipeline`, `resilience handler`, `port adapter split` → `.claude/skills/integration-adapter-patterns/SKILL.md`
- `feature flag`, `feature toggle`, `feature gate`, `rollout`, `gradual release`, `percentage rollout`, `a/b test`, `variant`, `gating`, `IFeatureManager`, `IFeatureManagerSnapshot`, `IVariantFeatureManager`, `sunset`, `flag cleanup` → `.claude/skills/feature-management-patterns/SKILL.md`

**Role = frontend (surface = web | admin | mobile)**
Do NOT hardcode a per-surface pack list here. Review must load the *same* packs
the code was generated under — resolve via the shared surface-resolution
preamble:
1. Read `.claude/skills/shared/surface-resolution.md`.
2. It resolves the surface from the story frontmatter / unit-brief Impacted
   Projects, then loads that surface's **Always-load skill packs** from
   `.specify/memory/projects/{surface}/project.md` (+ keyword overlays:
   `state`/`zustand`, `auth` → `authorization-patterns`, `file`/`upload`).
   Note this correctly loads `observability-frontend` on every surface and does
   NOT load the web-only `frontend-design-system` on mobile.

List the packs loaded before continuing.

## Pre-flight
1. Read session.yaml active_story_id
   NULL → STOP: run sk.session focus --story {id} first

## Context loading (cacheable — load first)
- specs/intents/{intent}/units/{unit}/architecture.md — bounded context, module boundaries, owned entities (Tier B)
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json — endpoint signatures (Tier B)
- .specify/memory/architecture-decisions.md — ADR constraints (Tier A)
- .specify/memory/standards/coding-standards.md — implementation rules (Tier A)
- .specify/memory/standards/observability-standards.md — logging/metrics/health requirements (Tier A)

## Story context (tail — load LAST)
Emit at end of user-input block, after all cacheable context:
```
<story id="{story-id}">
  <story-md>…STORY_DIR/story-{ID}.md…</story-md>
  <plan-md>…STORY_DIR/plan.md (if present)…</plan-md>
  <prior-review>…STORY_DIR/review-{story-id}.md (if present)…</prior-review>
</story>
```

## Context surface
Before invoking gstack /review, surface to agent:

"Reviewing story: {story-id} — {story title}
Bounded context: {unit name}. This unit owns: {entities/services from architecture.md}.
Must NOT cross into: {other units/services mentioned in architecture.md dependencies}
Contract: endpoints must match api-spec.json exactly — no undocumented changes.
ADR constraints: {applicable ADR summaries}

Pre-generation check: was existing code in the target area read before writing?
Flag if new abstractions were introduced that duplicate existing ones.

Module boundary checks (blocking):
- Method signatures changed from declared interface
- API response shape deviates from api-spec.json
- Untyped DTOs (any, raw maps, untyped dicts)
- Public method names don't describe intent (verb-noun)
- Direct access to another module's internal classes

Domain logic checks (findings):
- Business logic in a controller
- State change / DB write / external call outside injected interface
- Direct DB query outside a repository
- Command modifies more than one aggregate without going through domain events
- Function > 30 lines or > 1 logical operation
- Function > 3 parameters without a parameter object

Error handling: does code match the project's declared error handling pattern?

Observability (for stories adding new service endpoints):
- Structured JSON logging with trace_id and span_id present
- RED metrics instrumented (rate, errors, duration per endpoint)
- GET /health endpoint present and returning correct shape"

## Invoke
Claude performs the review natively using the context surface above.
If gstack is installed (`command -v gstack`): also invoke `gstack /review` for additional signal and merge findings.

## Output Artifact
If any findings exist, write a review report to:
  specs/intents/{intent}/units/{unit}/stories/{story-id}/review-{story-id}.md

Format:
```
# Review: {story-id}
Date: {YYYY-MM-DD}
Status: REJECTED | APPROVED

## Blocking Findings
- {finding}: {description} → {required action}

## Non-Blocking Findings
- {finding}: {description}
```

On REJECTED: write/overwrite the file with current findings.
On APPROVED: keep the review report at its path.
1. If any blocking findings were raised during this review cycle (i.e. the story was previously REJECTED):
   Append a `## Implementation Pitfalls` entry to the unit knowledge base:
     specs/intents/{intent}/units/{unit}/knowledge-base.md
   Format:
   ```
   ## Implementation Pitfalls
   <!-- Lessons from review cycles — sk.implement reads this to avoid repeating issues -->
   - [{story-id}] {short description of what was wrong} → {what the correct pattern is}
   ```
   If the section already exists, append to it rather than replacing it.
2. Keep the review report at its path — do NOT archive it on approval.
   Non-blocking findings remain available for the developer to act on via sk.implement.

## Post-execution
Flag any finding that:
- Violates bounded context boundaries (accessing another unit's internals directly)
- Deviates from api-spec.json endpoint signatures
- Contradicts an ADR decision
- Violates a module boundary rule (blocking)

Bounded context, ADR, and module boundary violations must be resolved before story can proceed to sk.verify.
Domain logic findings and observability gaps reported with severity from gstack /review output.

## Quality Bar
- No bounded context violations
- No endpoint signature deviations from api-spec.json
- No ADR constraint violations
- No module boundary violations
- All other findings reported with gstack /review output

## Completion Signal
Last line of output must be exactly one of:
`SK_RESULT: PASS` — Status is APPROVED, no blocking findings
`SK_RESULT: FAIL` — Status is REJECTED, blocking findings present
