import os
import unittest
from pathlib import Path
from unittest.mock import patch

import haizflow.services.secure_credentials as secure_credentials
import haizflow.utils.ffmpeg as ffmpeg


class LinuxCompatibilityTests(unittest.TestCase):
    def test_ffmpeg_fallback_has_no_exe_suffix_on_posix(self):
        with patch.object(ffmpeg.shutil, "which", return_value=None), patch.object(ffmpeg.os, "name", "posix"):
            self.assertEqual(Path(ffmpeg._binary("ffmpeg")).name, "ffmpeg")

    @unittest.skipIf(os.name == "nt", "Linux credential path")
    def test_linux_secret_service_round_trip(self):
        values = {}

        def secret_tool(arguments, *, secret=None):
            target = arguments[-1]
            if arguments[0] == "store":
                values[target] = secret
                return secure_credentials.subprocess.CompletedProcess(arguments, 0, "", "")
            if arguments[0] == "lookup":
                value = values.get(target)
                return secure_credentials.subprocess.CompletedProcess(
                    arguments, 0 if value is not None else 1, f"{value}\n" if value is not None else "", ""
                )
            values.pop(target, None)
            return secure_credentials.subprocess.CompletedProcess(arguments, 0, "", "")

        with patch.object(secure_credentials, "_secret_tool", side_effect=secret_tool):
            secure_credentials.write_secret("HaizFlow/Test", "secret")
            self.assertEqual(secure_credentials.read_secret("HaizFlow/Test"), "secret")
            self.assertTrue(secure_credentials.delete_secret("HaizFlow/Test"))
            self.assertFalse(secure_credentials.delete_secret("HaizFlow/Test"))
