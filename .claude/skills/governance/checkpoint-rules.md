Checkpoint Rules
Read by: sk.specify (to classify), propagated via state.yaml to all subsequent commands

Classification
Evaluate the current work item against these criteria and write
result to state.yaml as: checkpoint_mode: autopilot | confirm | validate

Autopilot (0 checkpoints)
- Change isolated to one service
- No contract changes
- No new domain entities
- UI-only or bug fix

Confirm (1 checkpoint — after sk.plan, before sk.tasks)
- New feature within existing bounded context
- New endpoints on existing service
- Non-breaking schema additions

Validate (2 checkpoints — after sk.design AND after sk.plan)
- New service or bounded context
- Breaking API contract changes
- Cross-service data model changes
- Auth, payments, or security-adjacent work
- Multi-frontend impact

Checkpoint Behaviour
Autopilot: proceed without stopping
Confirm:   stop after sk.plan, show plan summary, wait for explicit approval
Validate:  stop after sk.design, wait for approval
           stop again after sk.plan, wait for approval
           only then proceed to sk.tasks
