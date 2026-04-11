---
name: sk.phr
description: "Invoke when: recording a Prompt History Record after a significant decision, root cause finding, or recurring issue. Role: any. Reads: session.yaml. Writes: history/prompts/{feature}/PHR-{NNN}-{date}.md."
inject_files:
  - .claude/session.yaml
---

Records a Prompt History Record. Run after sk.investigate to prevent repeating root causes.
No subagent — runs inline.

Read and execute the full workflow in `prompt.md` in this directory.
