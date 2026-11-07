---
name: sala-doganale-artifact
description: "Sala Doganale (review of the bench's ground-truth assertions) is a claude.ai artifact whose answers live in its db — read them with ArtifactData"
metadata:
  node_type: memory
  type: reference
  originSessionId: e349a6cc-3bd9-4d6c-af17-65591b818287
  modified: 2026-10-03T08:20:17.298Z
---

Sala Doganale = Davide's review of the 376 assertions in assertions_pool44.json (AI-checklist-test-script).
Artifact: https://claude.ai/artifact/LzyLwkFXpLwKoFC9XQokqu. Davide thought it was a local file and lost track of it.

Answers are stored in the artifact db: collection `review` (doc id `<scenarioId>__<idx>`, fields status ok/dubbio/correggere, nota, updatedAt) and `scenario_note` (doc id = scenarioId). Read them with ArtifactData list, limit 1000, out_dir. No download from Davide is needed.
State on 2026-10-03: 295/376 reviewed (277 ok, 15 dubbio, 3 correggere), 0 scenario notes, last save 2026-09-25.
Notes are saved only on the textarea's `change` (blur) event.

Related: [[packlog-bench-vps-setup]]
