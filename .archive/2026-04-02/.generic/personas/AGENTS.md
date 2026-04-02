# SpecKit-SSD-SDLC Agent Personas

Read your assigned persona file before starting any work.

## Available Personas

| Role | File | Natural Commands |
|------|------|-----------------|
| po | personas/po.md | sk.specify, sk.clarify |
| architect | personas/architect.md | sk.architecture, sk.datamodel, sk.contracts, sk.impact, sk.adr, sk.verify, sk.knowledge-base |
| lead | personas/lead.md | sk.plan, sk.tasks, sk.analyze, sk.ff |
| backend | personas/backend.md | sk.implement |
| frontend | personas/frontend.md | sk.implement |
| backend-qa | personas/backend-qa.md | sk.test |
| frontend-qa | personas/frontend-qa.md | sk.test |
| security | personas/security.md | sk.security-audit |

## Multi-role Commands
sk.verify    → architect or lead
sk.clarify   → po, architect, or lead
sk.session   → any role
sk.phr       → any role
sk.adr       → architect preferred
sk.reset-lock → any role

## Role Switching
Update .generic/session.yaml role field.
Re-read your new persona file.
Continue working.
