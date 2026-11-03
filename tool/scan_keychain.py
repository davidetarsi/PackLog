"""Chiavi dei test PackLog nel Portachiavi macOS, mai negli argomenti o nei file.

Prima configurazione: /usr/bin/python3 tool/scan_keychain.py
Controllo senza mostrare valori: /usr/bin/python3 tool/scan_keychain.py --check
I runner importano read_keys() e passano il risultato nell'ambiente del figlio.
"""
from __future__ import annotations

import ctypes as c
import getpass
import sys
import warnings

SERVICES = {
    "ANTHROPIC_API_KEY": "PackLog.scan.Anthropic",
    "TYPESAFE_API_KEY": "PackLog.scan.TypeSafe",
}
NOT_FOUND = -25300


def validate(value: str) -> str:
    if not value or any(ch.isspace() for ch in value):
        raise ValueError("Inserisci solo la chiave, senza spazi o righe aggiuntive.")
    return value


class Keychain:
    def __init__(self):
        if sys.platform != "darwin":
            raise RuntimeError("Questo strumento richiede il Portachiavi di macOS.")
        self.lib = c.CDLL("/System/Library/Frameworks/Security.framework/Security")
        self.cf = c.CDLL("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation")
        self.cf.CFRelease.argtypes = [c.c_void_p]
        self.cf.CFRelease.restype = None
        prefix = [c.c_void_p, c.c_uint32, c.c_char_p, c.c_uint32, c.c_char_p]
        self.lib.SecKeychainFindGenericPassword.argtypes = prefix + [
            c.POINTER(c.c_uint32), c.POINTER(c.c_void_p), c.POINTER(c.c_void_p)]
        self.lib.SecKeychainAddGenericPassword.argtypes = prefix + [
            c.c_uint32, c.c_void_p, c.POINTER(c.c_void_p)]
        self.lib.SecKeychainItemModifyAttributesAndData.argtypes = [
            c.c_void_p, c.c_void_p, c.c_uint32, c.c_void_p]
        self.lib.SecKeychainItemFreeContent.argtypes = [c.c_void_p, c.c_void_p]
        for name in ("SecKeychainFindGenericPassword", "SecKeychainAddGenericPassword",
                     "SecKeychainItemModifyAttributesAndData", "SecKeychainItemFreeContent"):
            getattr(self.lib, name).restype = c.c_int32
        self.account = getpass.getuser().encode("utf-8")

    def _identity(self, service):
        name = service.encode("utf-8")
        return [None, len(name), name, len(self.account), self.account]

    @staticmethod
    def _check(status):
        if status:
            raise RuntimeError("Accesso al Portachiavi non riuscito (codice " + str(status) + ").")

    def read(self, service):
        length, data = c.c_uint32(), c.c_void_p()
        status = self.lib.SecKeychainFindGenericPassword(
            *self._identity(service), c.byref(length), c.byref(data), None)
        if status == NOT_FOUND:
            return None
        self._check(status)
        try:
            return validate(c.string_at(data, length.value).decode("utf-8"))
        finally:
            self.lib.SecKeychainItemFreeContent(None, data)

    def write(self, service, value):
        password = validate(value).encode("utf-8")
        item = c.c_void_p()
        status = self.lib.SecKeychainFindGenericPassword(
            *self._identity(service), None, None, c.byref(item))
        if status == NOT_FOUND:
            self._check(self.lib.SecKeychainAddGenericPassword(
                *self._identity(service), len(password), password, None))
        else:
            self._check(status)
            try:
                self._check(self.lib.SecKeychainItemModifyAttributesAndData(
                    item, None, len(password), password))
            finally:
                self.cf.CFRelease(item)


def read_keys():
    keychain = Keychain()
    keys = {key: keychain.read(service) for key, service in SERVICES.items()}
    if not all(keys.values()):
        keys.clear()
        raise RuntimeError("Completa la configurazione con tool/scan_keychain.py nel Terminale.")
    return keys


def setup():
    if not sys.stdin.isatty():
        raise RuntimeError("Apri questo strumento nel Terminale locale interattivo.")
    values = {}
    try:
        print("PackLog: salva le due chiavi nel Portachiavi Apple per riusarle nei test.")
        print("Inserimento nascosto; nessun valore viene scritto in file o comandi.")
        with warnings.catch_warnings():
            warnings.simplefilter("error", getpass.GetPassWarning)
            for key in SERVICES:
                values[key] = validate(getpass.getpass(key + ": "))
        keychain = Keychain()
        for key, service in SERVICES.items():
            keychain.write(service, values[key])
            if keychain.read(service) != values[key]:
                raise RuntimeError("Verifica del salvataggio non riuscita.")
        print("Chiavi salvate e rilette correttamente dal Portachiavi. Nessun test AI avviato.")
    finally:
        values.clear()


if __name__ == "__main__":
    try:
        if sys.argv[1:] == ["--check"]:
            keys = read_keys()
            keys.clear()
            print("Portachiavi OK: entrambe le chiavi disponibili, nessun valore mostrato.")
        elif not sys.argv[1:]:
            setup()
        else:
            raise RuntimeError("Uso: scan_keychain.py [--check]")
    except KeyboardInterrupt:
        print("\nConfigurazione annullata.")
        sys.exit(1)
    except Exception:
        print("Operazione non riuscita: chiavi mancanti, input non valido o accesso al Portachiavi negato.")
        sys.exit(1)
