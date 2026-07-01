from __future__ import annotations

import importlib.util
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT_PATH = ROOT / "scripts" / "check_latest_and_update.py"


def load_checker():
    spec = importlib.util.spec_from_file_location("check_latest_and_update", SCRIPT_PATH)
    assert spec is not None
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def git(cwd: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=cwd,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def commit_file(repo: Path, relative_path: str, content: str, message: str) -> str:
    path = repo / relative_path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    git(repo, "add", relative_path)
    git(repo, "commit", "-m", message)
    return git(repo, "rev-parse", "HEAD")


def init_remote_with_clone(tmp_path: Path) -> tuple[Path, Path, Path]:
    remote = tmp_path / "remote.git"
    source = tmp_path / "source"
    local = tmp_path / "local"

    git(tmp_path, "init", "--bare", str(remote))
    git(tmp_path, "clone", str(remote), str(source))
    git(source, "config", "user.email", "codex@example.test")
    git(source, "config", "user.name", "Codex Test")
    commit_file(source, "README.md", "# Toolkit\n", "Initial toolkit")
    git(source, "branch", "-M", "main")
    git(source, "push", "-u", "origin", "main")

    git(tmp_path, "clone", str(remote), str(local))
    git(local, "checkout", "main")
    git(local, "config", "user.email", "codex@example.test")
    git(local, "config", "user.name", "Codex Test")
    return remote, source, local


class CheckLatestAndUpdateTests(unittest.TestCase):
    def test_no_remote_update_is_silent(self) -> None:
        checker = load_checker()
        with tempfile.TemporaryDirectory() as temp_dir:
            _, _, local = init_remote_with_clone(Path(temp_dir))

            result = checker.check_and_update(
                checker.UpdateConfig(
                    repo_path=local,
                    remote="origin",
                    branch="main",
                    channel="C0ARH1MHF4H",
                    notify=False,
                )
            )

            self.assertFalse(result.updated)
            self.assertIsNone(result.message)
            self.assertEqual(result.before, result.after)

    def test_remote_update_fast_forwards_and_builds_slack_patch_note(self) -> None:
        checker = load_checker()
        with tempfile.TemporaryDirectory() as temp_dir:
            _, source, local = init_remote_with_clone(Path(temp_dir))
            second_sha = commit_file(
                source,
                "skills/defold-ui-input/SKILL.md",
                "# Defold UI Input\n\nUpdated input routing notes.\n",
                "Add input routing guidance",
            )
            git(source, "push", "origin", "main")

            result = checker.check_and_update(
                checker.UpdateConfig(
                    repo_path=local,
                    remote="origin",
                    branch="main",
                    channel="C0ARH1MHF4H",
                    notify=False,
                )
            )

            self.assertTrue(result.updated)
            self.assertEqual(result.after, second_sha)
            self.assertEqual(git(local, "rev-parse", "HEAD"), second_sha)
            self.assertIsNotNone(result.message)
            assert result.message is not None
            self.assertIn("Defold Codex Toolkit 업데이트", result.message)
            self.assertIn("Add input routing guidance", result.message)
            self.assertIn("skills/defold-ui-input/SKILL.md", result.message)

    def test_dry_run_does_not_merge_or_notify(self) -> None:
        checker = load_checker()
        with tempfile.TemporaryDirectory() as temp_dir:
            _, source, local = init_remote_with_clone(Path(temp_dir))
            before = git(local, "rev-parse", "HEAD")
            remote_sha = commit_file(
                source,
                "README.md",
                "# Toolkit\n\nDry run update.\n",
                "Document dry run update",
            )
            git(source, "push", "origin", "main")

            result = checker.check_and_update(
                checker.UpdateConfig(
                    repo_path=local,
                    remote="origin",
                    branch="main",
                    channel="C0ARH1MHF4H",
                    dry_run=True,
                    notify=True,
                    slack_runner=Path(temp_dir) / "missing-slack-runner.py",
                )
            )

            self.assertFalse(result.updated)
            self.assertEqual(result.before, before)
            self.assertEqual(result.after, remote_sha)
            self.assertEqual(git(local, "rev-parse", "HEAD"), before)
            self.assertIsNotNone(result.message)
            assert result.message is not None
            self.assertIn("Document dry run update", result.message)


if __name__ == "__main__":
    unittest.main()
