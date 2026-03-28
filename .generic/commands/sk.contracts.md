# sk.contracts
Unit-level command. Defines API contracts for all stories in unit.

## Pre-flight
1. Read session.yaml active_unit_id
   NULL → STOP: run sk.session focus --unit {id} first
2. Load skills:
   a. .claude/skills/service-registry/SKILL.md
   b. .claude/skills/standards/SKILL.md (api-standards.md only)
3. Read unit architecture.md — contracts must align with it
4. Read unit data-model.md if exists — contracts expose data model
5. Check if contracts/ directory exists for active unit:
   EXISTS → [REFINE MODE]
   MISSING → [CREATE MODE]

## Steps

### A. Contract discovery
From unit architecture and stories:
- List all endpoints this unit exposes
- List all events this unit publishes
- List all external contracts this unit consumes
- Check service-registry.md for existing contracts to avoid conflicts

### B. Contract design
For each endpoint, follow api-standards.md:
- URL structure and method
- Request schema
- Response envelope
- Error responses
- Authentication requirement
- Versioning

### C. Write contracts
Targets:
  specs/intents/{intent}/units/{unit}/contracts/api-spec.json
  specs/intents/{intent}/units/{unit}/contracts/README.md

If [REFINE MODE]:
  For api-spec.json:
  1. Read existing spec fully
  2. Add new endpoints — never remove or rename existing ones
  3. If an existing endpoint must change: add new version
     e.g. /v2/resource alongside existing /v1/resource
  4. Flag breaking changes explicitly to user before writing
     Wait for confirmation before proceeding with breaking change

  For README.md:
  1. Read existing README fully
  2. Add new endpoints to table
  3. Mark modified endpoints with: ⚠ Modified: {date}
  4. Append revision note:
     ---
     Revised: {date}
     Session: {session_id}
     Changes: {endpoints added, modified}
     Breaking: YES | NO
     ---

If [CREATE MODE]:
  Write fresh files using these structures:

  api-spec.json: OpenAPI 3.x specification

  README.md:
  ---
  unit: {unit-id}
  intent: {intent-id}
  version: v1
  updated: {date}
  ---

  # Contracts: {unit-name}

  ## Endpoints
  | Method | Path | Description | Auth |
  |--------|------|-------------|------|

  ## Events Published

  ## Events Consumed

  ## Breaking Change Policy

## Post-execution
Post-command hook updates service-registry.md automatically
Flag any breaking changes vs existing service-registry entries
Suggest ADR if new auth pattern or versioning strategy introduced
