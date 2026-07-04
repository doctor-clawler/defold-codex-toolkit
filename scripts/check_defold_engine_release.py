#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from pathlib import Path
from typing import Any


DEFAULT_CHANNEL = "C0ARH1MHF4H"
DEFAULT_RELEASE_URL = "https://api.github.com/repos/defold/defold/releases/latest"
DEFAULT_STATE_PATH = Path(__file__).resolve().parents[1] / ".local" / "state" / "defold-engine-release.json"
DEFAULT_SLACK_RUNNER = Path("/Users/clawler/.codex/skills/slack-send/scripts/slack_send.py")


@dataclass(frozen=True)
class ReleaseMonitorConfig:
    release_url: str = DEFAULT_RELEASE_URL
    release_json_path: Path | None = None
    state_path: Path = DEFAULT_STATE_PATH
    channel: str = DEFAULT_CHANNEL
    notify: bool = True
    dry_run: bool = False
    notify_initial: bool = False
    slack_runner: Path = DEFAULT_SLACK_RUNNER
    python_bin: str = sys.executable
    max_body_lines: int = 18
    max_body_chars: int = 2400


@dataclass(frozen=True)
class ReleaseMonitorResult:
    changed: bool
    current_tag: str
    previous_tag: str | None = None
    message: str | None = None
    slack_link: str | None = None


def load_release(config: ReleaseMonitorConfig) -> dict[str, Any]:
    if config.release_json_path is not None:
        return json.loads(Path(config.release_json_path).read_text(encoding="utf-8"))

    request = urllib.request.Request(
        config.release_url,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": "defold-codex-toolkit-release-monitor",
        },
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        return json.loads(response.read().decode("utf-8"))


def read_state(path: Path) -> dict[str, Any] | None:
    if not path.exists():
        return None
    return json.loads(path.read_text(encoding="utf-8"))


def write_state(path: Path, release: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "tag_name": release["tag_name"],
        "name": release.get("name"),
        "html_url": release.get("html_url"),
        "published_at": release.get("published_at"),
    }
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def summarize_body(body: str, *, max_lines: int, max_chars: int) -> str:
    lines: list[str] = []
    for raw_line in body.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        lines.append(line)
        if len(lines) >= max_lines:
            break

    summary = "\n".join(lines) if lines else "release note body가 비어 있습니다."
    if len(summary) > max_chars:
        return summary[: max_chars - 3].rstrip() + "..."
    return summary


def format_release_message(
    *,
    previous_tag: str | None,
    release: dict[str, Any],
    max_body_lines: int,
    max_body_chars: int,
) -> str:
    current_tag = str(release["tag_name"])
    release_url = str(release.get("html_url") or DEFAULT_RELEASE_URL)
    version_line = f"{previous_tag} -> {current_tag}" if previous_tag else current_tag
    body_summary = summarize_body(
        str(release.get("body") or ""),
        max_lines=max_body_lines,
        max_chars=max_body_chars,
    )

    return "\n".join(
        [
            "*Defold Engine 새 릴리즈 감지*",
            f"버전: `{version_line}`",
            f"릴리즈 노트: {release_url}",
            "",
            "*패치 노트 요약*",
            "```",
            body_summary,
            "```",
            "",
            "*권장 다음 단계*",
            "- `defold-engine-upgrade` skill로 영향 프로젝트를 먼저 inventory 합니다.",
            "- 프로젝트별 Defold Editor/bob 버전과 `defold_helper` dependency tag/commit을 함께 맞춥니다.",
            "- `defold_helper` 호환 tag가 아직 없으면 이 toolkit에서 먼저 검증한 뒤 소비 프로젝트를 올립니다.",
        ]
    )


def send_slack_message(config: ReleaseMonitorConfig, message: str) -> str | None:
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
            str(Path(__file__).resolve().parents[1]),
        ],
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    return result.stdout.strip() or None


def check_release(config: ReleaseMonitorConfig) -> ReleaseMonitorResult:
    release = load_release(config)
    current_tag = str(release["tag_name"])
    state = read_state(Path(config.state_path))
    previous_tag = str(state["tag_name"]) if state and state.get("tag_name") else None

    if previous_tag == current_tag:
        return ReleaseMonitorResult(changed=False, current_tag=current_tag, previous_tag=previous_tag)

    if previous_tag is None and not config.notify_initial:
        if not config.dry_run:
            write_state(Path(config.state_path), release)
        return ReleaseMonitorResult(changed=False, current_tag=current_tag)

    message = format_release_message(
        previous_tag=previous_tag,
        release=release,
        max_body_lines=config.max_body_lines,
        max_body_chars=config.max_body_chars,
    )
    slack_link = send_slack_message(config, message) if config.notify and not config.dry_run else None
    if not config.dry_run:
        write_state(Path(config.state_path), release)
    return ReleaseMonitorResult(
        changed=True,
        current_tag=current_tag,
        previous_tag=previous_tag,
        message=message,
        slack_link=slack_link,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Check the latest Defold engine release and notify Slack only when a new release appears."
    )
    parser.add_argument("--release-url", default=os.environ.get("DEFOLD_ENGINE_RELEASE_URL", DEFAULT_RELEASE_URL))
    parser.add_argument("--release-json-file")
    parser.add_argument("--state-path", default=os.environ.get("DEFOLD_ENGINE_RELEASE_STATE_PATH", str(DEFAULT_STATE_PATH)))
    parser.add_argument("--channel", default=os.environ.get("DEFOLD_ENGINE_RELEASE_SLACK_CHANNEL", DEFAULT_CHANNEL))
    parser.add_argument("--slack-runner", default=os.environ.get("DEFOLD_ENGINE_RELEASE_SLACK_RUNNER", str(DEFAULT_SLACK_RUNNER)))
    parser.add_argument("--python-bin", default=os.environ.get("DEFOLD_ENGINE_RELEASE_PYTHON_BIN", sys.executable))
    parser.add_argument("--max-body-lines", type=int, default=int(os.environ.get("DEFOLD_ENGINE_RELEASE_MAX_BODY_LINES", "18")))
    parser.add_argument("--max-body-chars", type=int, default=int(os.environ.get("DEFOLD_ENGINE_RELEASE_MAX_BODY_CHARS", "2400")))
    parser.add_argument("--notify-initial", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--no-notify", action="store_true")
    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)
    result = check_release(
        ReleaseMonitorConfig(
            release_url=args.release_url,
            release_json_path=Path(args.release_json_file) if args.release_json_file else None,
            state_path=Path(args.state_path),
            channel=args.channel,
            notify=not args.no_notify,
            dry_run=args.dry_run,
            notify_initial=args.notify_initial,
            slack_runner=Path(args.slack_runner),
            python_bin=args.python_bin,
            max_body_lines=args.max_body_lines,
            max_body_chars=args.max_body_chars,
        )
    )
    if result.changed:
        previous = result.previous_tag or "none"
        print(f"new defold release {previous} -> {result.current_tag}")
        if result.slack_link:
            print(result.slack_link)
    else:
        print(f"no new defold release at {result.current_tag}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
