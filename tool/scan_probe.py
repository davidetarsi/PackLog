"""Regressione AI dal nome, a pagamento: chiavi dal Portachiavi, risultati in build/recovery.

Uso: /usr/bin/python3 tool/scan_probe.py [--label NOME_PROVA]
Non modifica dati dell'app. I casi di sviluppo sono in regressioni_nome.json.
"""
from __future__ import annotations

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import subprocess
import sys

from scan_keychain import read_keys

ROOT = Path(__file__).resolve().parents[1]
CASES = ROOT / "supabase/functions/_shared/capi/test/regressioni_nome.json"


def evaluate(records, cases):
    by_name = {row["nome"]: row["risultato"]["items"][0]["metadata"] for row in records}
    errors = []
    for name, case in cases.items():
        if name not in by_name:
            errors.append(name + ": risultato mancante")
            continue
        actual = by_name[name]
        for field, expected in case.get("expected", {}).items():
            if actual.get(field) != expected:
                errors.append(name + ": " + field + " diverso dall'atteso")
        for field, forbidden in case.get("forbidden", {}).items():
            if field not in actual or actual[field] in forbidden:
                errors.append(name + ": " + field + " mancante o non valido")
    return errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--label", default=datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]{1,80}", args.label):
        parser.error("Etichetta non valida: usa lettere, cifre, trattini e underscore.")
    folder = ROOT / "build/recovery"
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / ("scan-" + args.label + "-live.json")
    log = output.with_suffix(".log")
    if output.exists() or log.exists():
        raise RuntimeError("La prova esiste gia: scegli un'altra etichetta.")
    cases = json.loads(CASES.read_text())
    keys = read_keys()
    environment = os.environ.copy()
    try:
        environment.update(keys)
        command = [
            "/opt/homebrew/bin/deno", "run", "--no-prompt", "--cached-only",
            "--config", str(ROOT / "supabase/functions/item-metadata/deno.json"),
            "--allow-env", "--allow-net=api.anthropic.com,api.typesafe.ai",
            "--allow-write=" + str(output),
            str(ROOT / "supabase/functions/_shared/capi/test/prova_dal_vivo.ts"),
            str(output), *cases,
        ]
        result = subprocess.run(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, text=True, timeout=900)
        safe_log = result.stdout
        for value in keys.values():
            safe_log = safe_log.replace(value, "[CHIAVE RIMOSSA]")
        log.write_text(safe_log)
        if result.returncode:
            print("Richiesta non riuscita; consulta il log:", log)
            return 1
        errors = evaluate(json.loads(output.read_text()), cases)
        for error in errors:
            print("ERRORE:", error)
        print("Prova su", len(cases), "nomi:", "superata" if not errors else "non superata")
        print("Risultati:", output)
        return int(bool(errors))
    finally:
        keys.clear()
        environment.clear()


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (Exception, KeyboardInterrupt) as error:
        print("Prova non completata (" + type(error).__name__ + "). Nessuna chiave mostrata.")
        sys.exit(1)
