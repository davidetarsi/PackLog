"""Controlli senza chiavi reali; la prova nativa usa solo una voce fittizia temporanea."""
import os
import subprocess
import sys
import unittest
import uuid
from unittest.mock import patch

from scan_keychain import Keychain, read_keys, setup, validate


class InputTests(unittest.TestCase):
    def test_invalid_input_does_not_reveal_value(self):
        for value in ("", "DECOY WITH SPACE", "DECOY\nEXTRA"):
            with self.assertRaises(ValueError) as error:
                validate(value)
            if value:
                self.assertNotIn(value, str(error.exception))

    def test_setup_refuses_non_terminal_before_requesting_secrets(self):
        with patch("sys.stdin.isatty", return_value=False):
            with self.assertRaises(RuntimeError):
                setup()

    def test_missing_key_fails_without_returning_partial_credentials(self):
        with patch("scan_keychain.Keychain") as cls:
            cls.return_value.read.side_effect = ["DECOY_SECRET", None]
            with self.assertRaises(RuntimeError) as error:
                read_keys()
            self.assertNotIn("DECOY_SECRET", str(error.exception))


@unittest.skipUnless(sys.platform == "darwin" and os.environ.get("PACKLOG_KEYCHAIN_TEST") == "1",
                     "Prova nativa da abilitare esplicitamente, solo con valori fittizi")
class NativeKeychainTests(unittest.TestCase):
    def test_create_read_update_and_cleanup(self):
        service = "PackLog.scan.selftest." + uuid.uuid4().hex
        keychain = Keychain()
        try:
            self.assertIsNone(keychain.read(service))
            keychain.write(service, "DECOY_FIRST")
            self.assertEqual(keychain.read(service), "DECOY_FIRST")
            keychain.write(service, "DECOY_SECOND")
            self.assertEqual(keychain.read(service), "DECOY_SECOND")
        finally:
            result = subprocess.run([
                "/usr/bin/security", "delete-generic-password", "-s", service,
                "-a", keychain.account.decode("utf-8")], capture_output=True)
            self.assertIn(result.returncode, (0, 44))
        self.assertIsNone(keychain.read(service))


if __name__ == "__main__":
    unittest.main()
