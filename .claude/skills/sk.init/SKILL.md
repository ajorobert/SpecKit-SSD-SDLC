---
name: sk.init
description: "Invoke when: initializing a new project or updating an existing project's SpecKit memory layer. Role: any. Reads: .specify/project-config.md (UPDATE mode). Writes: project-config.md, system-context.md, service-registry.md, constitution.md, all standards files."
inject_files: []
---

Initialize or update a project's SpecKit memory layer.
Mode: NEW PROJECT (project-config.md missing) or UPDATE (project-config.md exists).

Read and execute the full workflow in `prompt.md` in this directory.
