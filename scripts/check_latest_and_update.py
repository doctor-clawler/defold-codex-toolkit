#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
import subprocess
import sys
from dataclasses import dataclass
from pathlib import Path


DEFAULT_REPO_PATH = Path(__file__).resolve().parents[1]
DEFAULT_REMOTE = "origin"
DEFAULT_BRANCH = "main"
DEFAULT_CHANNEL = "C0ARH1MHF4H"
DEFAULT_SLACK_RUNNER = Path("/Users/clawler/.codex/skills/slack-send/scripts/slack_send.py")


@dataclass(frozen=True)
class UpdateConfig:
    repo_path: Path = DEFAULT_REPO_PATH
    remote: str = DEFAULT_REMOTE
    branch: str = DEFAULT_BRANCH
    channel: str = DEFAULT_CHANNEL
    notify: bool = True
    dry_run: bool = False
    slack_runner: Path = DEFAULT_SLACK_RUNNER
    python_bin: str = sys.executable
    max_commits: int = 20


@dataclass(frozen=True)
class UpdateResult:
    updated: bool
    before: str
    after: str
    message: str | None = None
    slack_link: str | None = None


def run_git(repo_path: Path, *args: str) -> str:
    result = subprocess.run(
        ["git", *args],
        cwd=repo_path,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip()


def short_sha(sha: str) -> str:
    return sha[:7]


def parse_ahead_behind(value: str) -> tuple[int, int]:
    left, right = value.split()
    return int(left), int(right)


def ensure_clean_worktree(repo_path: Path) -> None:
    status = run_git(repo_path, "status", "--porcelain")
    if status:
        raise RuntimeError("working tree has uncommitted changes; refusing automatic update")


def format_patch_message(
    *,
    before: str,
    after: str,
    commits: list[str],
    diff_stat: str,
    max_commits: int,
) -> str:
    visible_commits = commits[:max_commits]
    hidden_count = max(0, len(commits) - len(visible_commits))
    commit_lines = [f"- {line}" for line in visible_commits]
    if hidden_count:
        commit_lines.append(f"- ...외 {hidden_count}개 commit")

    if not commit_lines:
        commit_lines = ["- commit subject를 확인할 수 없음"]

    diff_summary = diff_stat.strip() or "파일 변경 요약 없음"

    return "\n".join(
        [
            "*Defold Codex Toolkit 업데이트 감지 및 적용 완료*",
            f"버전 범위: `{short_sha(before)}` -> `{short_sha(after)}`",
            "",
            "*패치 노트*",
            *commit_lines,
            "",
            "*갱신 내용 요약*",
            "```",
            diff_summary,
            "```",
        ]
    )


def send_slack_message(config: UpdateConfig, message: str) -> str | None:
    if not config.slack_runner.exists():
        raise FileNotFoundError(config.slack_runner)

    result = subprocess.run(
        [
            config.python_bin,
            str(config.slack_runner),
            "--channel",
            config.channel,
            "--message",
            message,
            "--cwd",
            str(config.repo_path),
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip() or None


def check_and_update(config: UpdateConfig) -> UpdateResult:
    repo_path = Path(config.repo_path).resolve()
    remote_ref = f"{config.remote}/{config.branch}"

    run_git(repo_path, "fetch", "--tags", "--prune", config.remote)
    before = run_git(repo_path, "rev-parse", "HEAD")
    remote_sha = run_git(repo_path, "rev-parse", remote_ref)
    ahead, behind = parse_ahead_behind(
        run_git(repo_path, "rev-list", "--left-right", "--count", f"HEAD...{remote_ref}")
    )

    if behind == 0:
        return UpdateResult(updated=False, before=before, after=before)

    if ahead:
        raise RuntimeError(
            f"local branch diverged from {remote_ref}: ahead={ahead}, behind={behind}; refusing automatic update"
        )

    ensure_clean_worktree(repo_path)
    commit_output = run_git(repo_path, "log", "--reverse", "--pretty=format:%h %s", f"HEAD..{remote_ref}")
    commits = [line for line in commit_output.splitlines() if line.strip()]
    diff_stat = run_git(repo_path, "diff", "--stat", "--compact-summary", f"HEAD..{remote_ref}")

    if config.dry_run:
        after = before
    else:
        run_git(repo_path, "merge", "--ff-only", remote_ref)
        after = run_git(repo_path, "rev-parse", "HEAD")
        if after != remote_sha:
            raise RuntimeError(f"updated HEAD {after} does not match {remote_ref} {remote_sha}")

    message = format_patch_message(
        before=before,
        after=remote_sha if config.dry_run else after,
        commits=commits,
        diff_stat=diff_stat,
        max_commits=config.max_commits,
    )
    slack_link = send_slack_message(config, message) if config.notify and not config.dry_run else None
    return UpdateResult(
        updated=not config.dry_run,
        before=before,
        after=remote_sha if config.dry_run else after,
        message=message,
        slack_link=slack_link,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Fast-forward Defold Codex Toolkit when origin has new commits and notify Slack only on updates."
    )
    parser.add_argument("--repo", default=os.environ.get("DEFOLD_TOOLKIT_REPO", str(DEFAULT_REPO_PATH)))
    parser.add_argument("--remote", default=os.environ.get("DEFOLD_TOOLKIT_REMOTE", DEFAULT_REMOTE))
    parser.add_argument("--branch", default=os.environ.get("DEFOLD_TOOLKIT_BRANCH", DEFAULT_BRANCH))
    parser.add_argument("--channel", default=os.environ.get("DEFOLD_TOOLKIT_SLACK_CHANNEL", DEFAULT_CHANNEL))
    parser.add_argument("--slack-runner", default=os.environ.get("DEFOLD_TOOLKIT_SLACK_RUNNER", str(DEFAULT_SLACK_RUNNER)))
    parser.add_argument("--python-bin", default=os.environ.get("DEFOLD_TOOLKIT_PYTHON_BIN", sys.executable))
    parser.add_argument("--max-commits", type=int, default=int(os.environ.get("DEFOLD_TOOLKIT_MAX_COMMITS", "20")))
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-notify", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = check_and_update(
        UpdateConfig(
            repo_path=Path(args.repo),
            remote=args.remote,
            branch=args.branch,
            channel=args.channel,
            notify=not args.no_notify,
            dry_run=args.dry_run,
            slack_runner=Path(args.slack_runner),
            python_bin=args.python_bin,
            max_commits=args.max_commits,
        )
    )
    if result.updated:
        print(f"updated {short_sha(result.before)} -> {short_sha(result.after)}")
        if result.slack_link:
            print(result.slack_link)
    else:
        print(f"no update at {short_sha(result.before)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
