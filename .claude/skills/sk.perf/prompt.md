# sk.perf
Performance profiling and optimization cycle.
Role: backend | frontend | Level: unit or cross-unit

## Mode declaration
Declare at start: `[PERF MODE] Input: {load-test | profiler | both}. Role: {backend | frontend}.`

## Pre-flight
1. Read session.yaml role
   NULL → ask user: "backend or frontend performance work?"
2. Ask user to provide one of:
   (a) Load test results (k6, JMeter, Gatling output — paste or file path)
   (b) Profiler output (dotnet-trace, Chrome DevTools, Lighthouse — paste or file path)
   (c) Both
   NEITHER provided → STOP: this skill requires empirical input, not hypothesis
3. Ask: "What is the target metric and acceptance threshold?"
   Example: "p99 < 200ms under 500 concurrent users", "LCP < 2.5s on 3G"
   Record as: perf_target

## Capability pack selection
Load packs matching role (≤4 packs):

Role = backend: always `.claude/skills/csharp-clean-arch/SKILL.md`
- DB bottleneck signals → `.claude/skills/postgresql-patterns/SKILL.md`
- Cache opportunity signals → `.claude/skills/redis-patterns/SKILL.md`
- Search bottleneck signals → `.claude/skills/elasticsearch-patterns/SKILL.md`

Role = frontend: always `.claude/skills/react-component-patterns/SKILL.md`, `.claude/skills/frontend-design-system/SKILL.md`

List packs loaded.

## Step 1 — Diagnose
Analyse the profiler/load-test input:
- Identify the top-3 bottlenecks by impact (latency, throughput, or bundle weight)
- For each bottleneck:
  - Location: file:line or component name
  - Root cause: (N+1 query / missing index / no cache / render waterfall / large bundle / etc.)
  - Estimated impact: what % of latency/size this represents
  - Evidence: quote the specific metric from the input

Write findings to: perf-findings.md (see Output Artifacts)

## Step 2 — Prioritise
Rank bottlenecks by: (estimated impact) × (implementation risk⁻¹)
Present ranked list to user. Ask: "Which optimizations should I implement? (all / list numbers)"
Record selected optimizations.

## Step 3 — Generate tasks
For each selected optimization, write a task entry:
- Task description
- Target file/component
- Acceptance criterion: measurable, tied to perf_target
- Test method: how the improvement will be verified (benchmark, re-run load test, Lighthouse CI)

Write tasks to: specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md
(If no active story: write to .specify/perf-tasks.md and remind user to create a story)

## Step 4 — Implement
Execute tasks in priority order:
- Read existing code before editing
- Implement the optimization (query rewrite, index addition, cache layer, lazy load, code split, etc.)
- Add or update the benchmark/test for each change
- After each task: report metric delta if measurable inline (e.g. "query reduced from 12 to 1 round trip")
- Mark each task [X] in tasks.md

## Step 5 — Verify
Run the agreed test method for each completed optimization:
- Re-run benchmark or targeted load test segment
- Compare before/after against perf_target
- Report: target MET / target MISSED (by how much)
If target missed: report remaining gap and suggest next candidate optimization.

## Output Artifacts
perf-findings.md (diagnosis + ranked bottlenecks)
specs/intents/{intent}/units/{unit}/stories/{story-id}/tasks.md (or .specify/perf-tasks.md)
src/** (optimized files)
benchmark results summary (inline report)

## Quality Bar
- All findings backed by empirical input — no hypothesis-only entries
- Each optimization has a measurable acceptance criterion tied to perf_target
- Before/after comparison reported for each implemented optimization
- No behaviour changes — only performance characteristics altered
