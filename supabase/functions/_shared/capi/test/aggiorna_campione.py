#!/usr/bin/env python3
"""Riallinea oracolo_scheda_campione.json all'oracolo scheda intero del bench.

Dopo un cambio del catalogo (esporta_catalogo.mjs) l'oracolo del bench si
rigenera con `esporta_oracolo.py scheda FILE`. Il campione dell'app e' un
sottoinsieme: stessi campi in testa (hash del catalogo, prompt, domande di Jev,
nomi) e solo i casi che ha gia', ricercati per ingresso (risposta grezza e
nome) nell'oracolo nuovo. Non basta cambiare l'hash: prompt_scan e
domande_jev cambiano con le voci del catalogo.

Uso (solo libreria standard, va bene il python del venv del bench):
  python aggiorna_campione.py ORACOLO_INTERO.json [CAMPIONE.json]
Senza il secondo argomento riscrive il campione accanto a questo file.
Con un catalogo che non e' cambiato non cambia nulla (stessi byte).
"""
import json
import sys
from pathlib import Path

nuovo = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
dest = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(__file__).with_name("oracolo_scheda_campione.json")
vecchio = json.loads(dest.read_text(encoding="utf-8"))

chiave = lambda c: json.dumps([c["grezzo"], c["nome"]], sort_keys=True, ensure_ascii=False)
per_ingresso = {}
for c in nuovo["casi"]:
    per_ingresso.setdefault(chiave(c), c)
mancanti = [chiave(c) for c in vecchio["casi"] if chiave(c) not in per_ingresso]
if mancanti:
    sys.exit(f"{len(mancanti)} casi del campione non sono nell'oracolo nuovo, primo: {mancanti[0][:120]}")

# l'ordine dei campi e' quello del campione, perche' il diff mostri solo i cambi
out = {k: nuovo[k] for k in vecchio if k != "casi" and k in nuovo}
out.update({k: v for k, v in nuovo.items() if k not in out and k != "casi"})
out["casi"] = [per_ingresso[chiave(c)] for c in vecchio["casi"]]
dest.write_text(json.dumps(out, ensure_ascii=False), encoding="utf-8")
print(f"{len(out['casi'])} casi, catalogo_sha256 {out['catalogo_sha256']} -> {dest}")
