---
name: giri-prova-dev-valigia
description: giri di prova di pack-trip su Supabase DEV con utente di prova; registro errori per la PR dopo feat/valigia-ai
metadata:
  type: project
---

Dal 25 ott 2026 la valigia AI si prova dal vivo su DEV con uno script node (fasi tutto/verifica/finiti/pulizia) e un utente di prova email+password creato da Davide. Credenziali in `/srv/claude/workspaces/.segreti/packlog-dev-test.env` (600, mai aprirlo né stampare: lo legge solo lo script). Armadi dal bench. Niente emulatore: la VPS non ha KVM.

Registro errori: `/srv/claude/workspaces/PackLog-valigia-ai/docs/superpowers/notes/2026-10-25-errori-giri-dev.md` (docs/ è gitignored). Sezioni A avvisi (uscita.ts), B testi motivi (motivi.ts, uguale al bench: correggere bench e TS insieme), C logica del generatore.

**Why:** Davide vuole tutto segnato per la PR subito dopo feat/valigia-ai, e testi coerenti su ogni output.
**How to apply:** a ogni giro aggiorna il registro; per i crediti dell'utente di prova usare ai_credit_grants, non alzare ai_monthly_cap (globale). Script e risposte in docs/superpowers/notes/prova-dev/ del worktree. Vedi [[design-valigia-ai]], [[produzione-generatore]].

Crediti finiti provato il 25 ott: 429 senza scalare, OK. Dopo il test il grant dell'utente di prova era esaurito (used = credits); Davide poteva ripristinarlo a used = 27.

25 ott sera: PR successiva in lavorazione. App: ramo fix/valigia-errori-dev (worktree /srv/claude/workspaces/PackLog-valigia-errori, base feat/valigia-ai), commit 1763218 testi motivi, 027450b avvisi, c943aaf litri+lavanderia, a4183bd tappe dei mancanti. Bench: ramo fix/errori-giri-dev (012a8af, 993497f, 676db67). 888/888 identici; sviluppo 4671 -> 4661 (Alaska 60 L, C7). Registro aggiornato in PackLog-valigia-errori/docs/superpowers/notes/2026-10-25-errori-giri-dev.md (sezioni Fatto / Ancora aperto). Per provare dal vivo serve deploy di pack-trip da questo ramo su DEV. Su questa VPS i test Flutter vogliono LD_LIBRARY_PATH con un link libsqlite3.so -> /usr/lib/x86_64-linux-gnu/libsqlite3.so.0 (nello scratchpad).

**Prima di un giro, controllare la versione distribuita con un caso solo (1 credito).** Il 26 ott un giro mirato di 13 casi è finito sulla pack-trip vecchia (feat/valigia-ai) e ha sprecato i crediti. Segno della versione nuova (fix/valigia-errori-dev, da 6b7d20d anche "Considera un bagaglio più grande" invece di "Valuta di lasciare"): nei motivi "più un ricambio" con l'accento invece di "piu' un"; con 60 giorni senza lavatrice i pezzi si fermano a 15 e compare l'avviso "Prevedi una lavanderia". Fase `mirato` dello script = 13 casi toccati dalle correzioni.

**Suite Flutter sul VPS dal 26 ott sera:** 31–39 test UI falliscono anche sul commit di base 26a8f5e (che il 25 passava 1446/1446): asserzione Flutter "ListTile wrapped in a DecoratedBox" e simili. L'SDK ha fatto fetch/engine.stamp alle 17:50 del 26 (non io). Prima di dare colpa a un ramo, far girare gli stessi file sul commit di base. Nei worktree nuovi mancano i file generati (54): build_runner su questo VPS si blocca per ore; copiarli da un worktree con sorgenti identiche (controllo con cmp). `analysis_options.yaml` (exclude build/android/ios) e `pubspec.lock` risultano modificati da fuori: non committarli.
