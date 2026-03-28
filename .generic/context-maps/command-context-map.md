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
