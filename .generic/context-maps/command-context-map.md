# Command Context Map
Before executing any sk.* command, load only the context files listed here.
Do not load unlisted files — load on demand if needed mid-execution.

## sk.specify
- .specify/memory/system-context.md
- .specify/memory/domain-model.md

## sk.clarify
- specs/intents/{intent}/intent.md
- specs/intents/{intent}/units/{unit}/unit-brief.md

## sk.impact
- .specify/memory/system-context.md
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md

## sk.architecture
- .specify/memory/service-registry.md
- .specify/memory/domain-model.md
- .specify/memory/architecture-decisions.md
- .specify/memory/standards/api-standards.md
- .specify/memory/standards/data-standards.md

## sk.datamodel
- .specify/memory/domain-model.md
- .specify/memory/standards/data-standards.md

## sk.contracts
- .specify/memory/service-registry.md
- .specify/memory/standards/api-standards.md
- specs/intents/{intent}/units/{unit}/architecture.md

## sk.plan
- specs/intents/{intent}/units/{unit}/architecture.md
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
- specs/intents/{intent}/units/{unit}/data-model.md
- .specify/memory/standards/tech-stack.md

## sk.tasks
- specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md
- .specify/memory/standards/tech-stack.md

## sk.implement
- specs/intents/{intent}/units/{unit}/stories/{story-id}/plan.md
- specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
- .specify/memory/standards/coding-standards.md
- .specify/memory/architecture-decisions.md

## sk.verify
- .generic/context-maps/governance.md
- .specify/memory/architecture-decisions.md
- .specify/memory/standards/ (all files)

## sk.test
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
- specs/intents/{intent}/units/{unit}/contracts/test-plan.md
- specs/intents/{intent}/units/{unit}/stories/{story-id}/story-{ID}.md
- .specify/memory/standards/tech-stack.md
- .specify/memory/standards/coding-standards.md

## sk.security-audit
- src/{service}/**
- specs/intents/{intent}/units/{unit}/contracts/api-spec.json
- .specify/memory/architecture-decisions.md
- .specify/memory/standards/coding-standards.md
- story-{ID}.md

## sk.ff
- .generic/context-maps/governance.md
- .specify/memory/service-registry.md

## sk.adr
- .specify/memory/architecture-decisions.md

## sk.phr
- history/prompts/ (recent entries)

## sk.session
- .generic/session.yaml

## sk.analyze
- .specify/memory/system-context.md
- .specify/memory/architecture-decisions.md

## sk.knowledge-base (system)
- .specify/memory/system-context.md
- history/adr/

## sk.knowledge-base (domain)
- history/adr/
- specs/domains/{domain}/

## sk.knowledge-base (unit)
- specs/intents/{intent}/units/{unit}/architecture.md
- history/adr/

## sk.implement (knowledge base context)
- specs/knowledge-base.md (all tiers, before code)
- specs/domains/{relevant-domain}/knowledge-base.md (tier 2, if exists)
- specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3, if exists)

## sk.test (knowledge base context)
- specs/knowledge-base.md (tier 1, before tests)
- specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3, if exists)

## sk.security-audit (knowledge base context)
- specs/intents/{intent}/units/{unit}/knowledge-base.md (tier 3, before code)
