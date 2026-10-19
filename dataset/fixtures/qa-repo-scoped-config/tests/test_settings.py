import json
import unittest
from pathlib import Path


class SettingsTests(unittest.TestCase):
    def test_cache_is_enabled_without_changing_other_settings(self):
        settings_path = Path(__file__).parents[1] / "config" / "settings.json"
        settings = json.loads(settings_path.read_text(encoding="utf-8"))

        self.assertEqual(
            settings,
            {
                "service": {
                    "timeout_seconds": 30,
                    "cache": {
                        "enabled": True,
                        "ttl_seconds": 120,
                    },
                },
            },
        )


if __name__ == "__main__":
    unittest.main()
