from __future__ import annotations

import importlib.util
import json
import plistlib
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "check_defold_engine_release.py"
TOOLKIT_PLIST_PATH = ROOT / "launchd" / "com.doctorclawler.defold-codex-toolkit.latest-check.plist"
ENGINE_PLIST_PATH = ROOT / "launchd" / "com.doctorclawler.defold-engine-release-check.plist"
MANIFEST_PATH = ROOT / ".codex-plugin" / "plugin.json"
ENGINE_SKILL_PATH = ROOT / "skills" / "defold-engine-upgrade" / "SKILL.md"


def load_monitor():
    spec = importlib.util.spec_from_file_location("check_defold_engine_release", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def write_release(path: Path, *, tag_name: str, body: str = "- Engine fix\n- Build update\n") -> None:
    path.write_text(
        json.dumps(
            {
                "tag_name": tag_name,
                "name": f"Defold {tag_name}",
                "html_url": f"https://github.com/defold/defold/releases/tag/{tag_name}",
                "published_at": "2026-07-03T09:00:00Z",
                "body": body,
            }
        ),
        encoding="utf-8",
    )


class DefoldEngineReleaseMonitorTests(unittest.TestCase):
    def test_initial_release_records_baseline_without_message(self) -> None:
        monitor = load_monitor()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            release_path = temp_path / "release.json"
            state_path = temp_path / "state.json"
            write_release(release_path, tag_name="1.10.0")

            result = monitor.check_release(
                monitor.ReleaseMonitorConfig(
                    release_json_path=release_path,
                    state_path=state_path,
                    channel="C0ARH1MHF4H",
                    notify=False,
                )
            )

            self.assertFalse(result.changed)
            self.assertIsNone(result.message)
            self.assertEqual(result.current_tag, "1.10.0")
            self.assertEqual(json.loads(state_path.read_text(encoding="utf-8"))["tag_name"], "1.10.0")

    def test_new_release_builds_message_and_updates_state(self) -> None:
        monitor = load_monitor()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            release_path = temp_path / "release.json"
            state_path = temp_path / "state.json"
            state_path.write_text(json.dumps({"tag_name": "1.9.9"}), encoding="utf-8")
            write_release(
                release_path,
                tag_name="1.10.0",
                body="- Physics runtime fix\n- Android bundle correction\n",
            )

            result = monitor.check_release(
                monitor.ReleaseMonitorConfig(
                    release_json_path=release_path,
                    state_path=state_path,
                    channel="C0ARH1MHF4H",
                    notify=False,
                )
            )

            self.assertTrue(result.changed)
            self.assertEqual(result.previous_tag, "1.9.9")
            self.assertEqual(result.current_tag, "1.10.0")
            self.assertIsNotNone(result.message)
            assert result.message is not None
            self.assertIn("Defold Engine 새 릴리즈", result.message)
            self.assertIn("1.9.9 -> 1.10.0", result.message)
            self.assertIn("Physics runtime fix", result.message)
            self.assertIn("defold-engine-upgrade", result.message)
            self.assertEqual(json.loads(state_path.read_text(encoding="utf-8"))["tag_name"], "1.10.0")

    def test_same_release_is_silent(self) -> None:
        monitor = load_monitor()
        with tempfile.TemporaryDirectory() as temp_dir:
            temp_path = Path(temp_dir)
            release_path = temp_path / "release.json"
            state_path = temp_path / "state.json"
            state_path.write_text(json.dumps({"tag_name": "1.10.0"}), encoding="utf-8")
            write_release(release_path, tag_name="1.10.0")

            result = monitor.check_release(
                monitor.ReleaseMonitorConfig(
                    release_json_path=release_path,
                    state_path=state_path,
                    channel="C0ARH1MHF4H",
                    notify=False,
                )
            )

            self.assertFalse(result.changed)
            self.assertIsNone(result.message)

    def test_toolkit_latest_check_runs_weekly_on_friday(self) -> None:
        with TOOLKIT_PLIST_PATH.open("rb") as plist_file:
            plist = plistlib.load(plist_file)
        schedule = plist["StartCalendarInterval"]

        self.assertEqual(schedule["Weekday"], 5)
        self.assertEqual(schedule["Hour"], 9)
        self.assertEqual(schedule["Minute"], 0)

    def test_engine_release_check_runs_weekly_on_friday(self) -> None:
        with ENGINE_PLIST_PATH.open("rb") as plist_file:
            plist = plistlib.load(plist_file)
        schedule = plist["StartCalendarInterval"]

        self.assertEqual(schedule["Weekday"], 5)
        self.assertEqual(schedule["Hour"], 9)
        self.assertEqual(schedule["Minute"], 15)

    def test_manifest_and_skill_document_engine_helper_coupling(self) -> None:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        skill_text = ENGINE_SKILL_PATH.read_text(encoding="utf-8")

        self.assertIn("engine upgrades", manifest["description"])
        self.assertIn("Defold Engine Upgrade", skill_text)
        self.assertIn("defold_helper", skill_text)
        self.assertIn("release notes", skill_text)
        self.assertIn("do not upgrade every discovered project automatically", skill_text)


if __name__ == "__main__":
    unittest.main()
