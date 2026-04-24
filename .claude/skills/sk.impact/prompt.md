# sk.impact
Assesses blast radius of proposed work before starting.
Role: architect | Level: intent

## Input Artifacts
.specify/memory/system-context.md
.specify/memory/service-registry.md
.specify/memory/domain-model.md
.claude/skills/governance/checkpoint-rules.md  — drives step 4 (recommended checkpoint_mode)

## Steps
1. Collect from user: proposed intent/unit description
2. Evaluate service impact, domain impact, cross-cutting impact
3. Classify risk: LOW | MEDIUM | HIGH
4. Determine recommended checkpoint_mode
5. Write impact report

## Output Artifacts
specs/intents/{intent}/impact-{date}-{NNN}.md
(NNN increments if multiple reports same date)

## Quality Bar
- All existing services evaluated for impact
- Domain conflicts explicitly identified
- ADR requirement stated clearly
- Checkpoint recommendation justified
