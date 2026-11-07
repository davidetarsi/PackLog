---
name: packlog-bench-vps-setup
description: "How the PackLog checklist bench (AI-checklist-test-script) runs on the VPS — OpenAI key location, venv, runner"
metadata:
  node_type: memory
  type: project
  originSessionId: 5eceae35-a71b-445d-8005-0eb18ee843e4
  modified: 2026-10-08T15:00:08.404Z
---

The checklist bench lives in /srv/claude/workspaces/AI-checklist-test-script (moved from Davide's Mac on 2026-09-27; the claude.ai chat history is in docs/chat-claude-ai-transcript.txt, later Claude Code state in stato-*.md and .superpowers/sdd/progress.md).

- OpenAI key: ~/.config/packlog/openai_api_key (mode 600), created by Davide via SSH with `read -s`. Never read/print it; launch paid runs only through `packlog_keychain_runner.py` (status / smoke / matrix --version 48 --ripetizioni N), which passes it only to the child process.
- .venv is `--without-pip --system-site-packages` (no python3-venv on the box; requests 2.31 comes from the system).
- The OpenAI account is prepaid: on 2026-09-27 credits ran out right after a full 660-cell run (~$0.49).

**Why:** Davide wants Claude to launch the bench itself without the key ever passing through chat.
**How to apply:** Run `status` before a paid run, and get Davide's explicit go-ahead for every paid run. If you get a 429 "no credits remaining", ask him to top up. Don't retry. `status` checks only that the key file exists and looks valid, not that OpenAI accepts it: on 2026-10-08 the holdout v2 run failed at the first call with 401 "Incorrect API key" (key revoked or rotated), so Davide had to rewrite the file via SSH with `read -s`.

Jev (TypeSafe AI), 8 ottobre 2026: chiave in ~/.config/packlog/typesafe_api_key (600), funzionante; POST https://api.typesafe.ai/v1/systemone, header Bearer, model "jev-latest" (risponde jev-1.13.0). Mai leggerla ne' stamparla; script che la legge e la cancella dalla memoria subito dopo l'uso. Lezioni dal salvataggio: (1) Davide aveva riusato il comando con openai_api_key e sovrascritto la chiave OpenAI; (2) `read -s` gli ha perso il primo carattere ("k-proj" invece di "sk-proj"); sulla VPS non c'e' nano: usare `read -r -p "Chiave: " K` (visibile) seguito da `cut -c1-8 file` per controllare. Verifica gratuita OpenAI: GET /v1/models.

Remoto GitHub (10 ottobre 2026): il repo del bench ha origin = git@github.com-ai-checklist:davidetarsi/checklist-script-packlog.git, con tutti i rami gia' presenti. ISTRUZIONE DI DAVIDE: alla fine di ogni sessione di lavoro (verso mezzanotte del giorno in cui si e' lavorato) fare il push dei risultati sul remoto: push normale del ramo di lavoro, mai main, mai force. Il promemoria pianificato (CronCreate) vive solo nella sessione e scade dopo 7 giorni: in una sessione nuova va ricreato o il push va fatto a mano a fine lavoro.
