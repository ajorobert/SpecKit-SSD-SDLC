Roles
Read by: sk.verify (ownership checks), .claude/agents/ definitions

Role Definitions

Product Owner
- Owns: intent definition, acceptance criteria, story prioritization
- Gates: Spec Gate approval
- Commands: sk.specify, sk.clarify, sk.story

Architect
- Owns: service boundaries, domain model, ADRs, contract standards
- Gates: Architecture Gate approval, Validate checkpoint approval
- Commands: sk.design, sk.impact, sk.adr, sk.architect-probe

Backend Lead
- Owns: implementation plan for backend units, API contract detail
- Gates: Plan Gate approval for backend units
- Commands: sk.plan

Frontend Lead
- Owns: implementation plan for frontend units
- Gates: Plan Gate approval for frontend units
- Commands: sk.plan

Engineer
- Owns: task execution, PHR creation
- Commands: sk.implement, sk.phr

Any Role
- Commands: sk.verify, sk.ff
