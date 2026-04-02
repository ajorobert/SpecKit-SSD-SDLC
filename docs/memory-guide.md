Memory Layer Guide

Files

system-context.md         — high-level system map
domain-model.md           — canonical entities, check before adding new ones
service-registry.md       — service contracts
architecture-decisions.md — ADR index, managed by sk.adr
command-rules.md          — agent behavior rules
upstream-adapter.md       — upstream file path references
state.yaml                — live session state, managed by commands
standards/                — set during project setup, stable after that

Editing rules

Memory files: structured data only
Standards: change via ADR only
state.yaml: never edit manually during active sessions
upstream-adapter.md: update only after running reconcile-upstream.sh
