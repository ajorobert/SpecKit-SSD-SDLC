Quality Gates
Used by: sk.verify

Gate Definitions
Each gate is PASS or FAIL. sk.verify reports all results.
A single FAIL blocks progression to next phase.

Spec Gate (before sk.plan)
- [ ] Intent exists in .specify/intents/
- [ ] Active unit and story set in state.yaml
- [ ] All user stories have acceptance criteria
- [ ] No undefined external dependencies

Architecture Gate (before sk.tasks)
- [ ] Architecture doc exists for this intent
- [ ] All new services registered in service-registry.md
- [ ] All new domain entities added to domain-model.md
- [ ] ADR raised for any cross-service decision
- [ ] Checkpoint mode set in state.yaml

Plan Gate (before sk.implement)
- [ ] plan.md exists for active story
- [ ] API contracts defined for any new endpoints
- [ ] Data model changes documented
- [ ] No conflicts with existing contracts in service-registry.md
- [ ] Confirm/Validate checkpoint approved if required

Implementation Gate (before merge)
- [ ] All tasks in tasks.md marked complete
- [ ] PHR created if novel tradeoffs were resolved
- [ ] Standards compliance: coding-standards.md
- [ ] No new domain entities introduced outside sk.datamodel
