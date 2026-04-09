# Defold Codex Toolkit

이 저장소는 공개 GitHub에 올릴 수 있는 Defold용 Codex plugin 저장소입니다.

## 프로젝트 소개

`defold-codex-toolkit`은 Defold 프로젝트 작업에서 반복되는 워크플로우를 Codex가 더 일관되게 지원할 수 있도록 정리한 plugin 패키지입니다. 이 저장소는 Codex에서 로컬로 로드되는 plugin 형식이며, 공개 GitHub 업로드 자체가 OpenAI 공식 공개 marketplace 자동 등록을 뜻하지 않습니다.

## 제공 기능

- Defold 빌드 및 번들 작업 가이드
- Slack `/build` 연동용 Android build/upload 스크립트 규약
- Defold GUI 및 입력 처리 가이드
- Defold 디버깅 워크플로우 가이드
- Defold 프로젝트 컨벤션 점검 가이드

각 항목은 `skills/` 하위 `SKILL.md`로 제공됩니다.

## Shared `/build` Contract

이 plugin은 `_ops` 같은 공유 Slack daemon이 Defold 프로젝트 루트에서 표준 build script를 찾아 실행하는 워크플로우를 전제로 합니다.

- 표준 진입 스크립트: `scripts/build_and_upload_android.sh`
- 권장 분리 스크립트:
  - `scripts/build_android.sh`
  - `scripts/upload_android_build_to_slack.sh`
- 권장 산출물 경로: `.local/artifacts/<project-slug>-android.apk`

기본 운영 모델은 다음과 같습니다.

1. Slack `/build`가 현재 active project root를 찾습니다.
2. `<project>/scripts/build_and_upload_android.sh`가 있으면 그 스크립트를 실행합니다.
3. 스크립트가 없으면 daemon은 `빌드 스크립트가 없습니다.`를 반환합니다.
4. 스크립트 자체가 Android build와 Slack 업로드를 모두 책임집니다.

이 계약을 따르면 새로운 Defold 프로젝트도 `_ops` 쪽에 프로젝트별 artifact branch를 추가하지 않고 같은 `/build` 표면을 재사용할 수 있습니다.

## 디렉터리 구조 설명

```text
.codex-plugin/plugin.json
skills/
  defold-build-bundle/SKILL.md
  defold-ui-input/SKILL.md
  defold-debug-workflow/SKILL.md
  defold-project-conventions/SKILL.md
examples/marketplace.json.example
README.md
LICENSE
```

## 설치 방법

1. 이 저장소를 로컬에 가져옵니다.

```bash
git clone https://github.com/doctor-clawler/defold-codex-toolkit.git defold-codex-toolkit
```

2. 또는 GitHub URL을 직접 설치 대상으로 쓰는 것이 아니라, 클론하거나 복사한 로컬 저장소를 사용합니다.

## 프로젝트 한정 사용 방법

다른 프로젝트에서 plugin을 붙여 쓰려면 다음 순서를 따릅니다.

1. 현재 프로젝트 루트에 `plugins/defold-codex-toolkit` 폴더를 준비합니다.
2. 이 저장소를 그 경로에 `clone`하거나 전체를 복사합니다.
3. 프로젝트의 `.agents/plugins/marketplace.json`에서 `source.path`를 로컬 경로로 지정합니다.
4. Codex를 재시작하거나 plugin discovery를 갱신합니다.

예시 경로:

- `./plugins/defold-codex-toolkit`

## marketplace.json 예시

아래 예시는 다른 프로젝트의 `.agents/plugins/marketplace.json`에서 추가하거나 적용할 내용입니다.

```json
{
  "name": "example-project-marketplace",
  "interface": {
    "displayName": "Example Project Marketplace"
  },
  "plugins": [
    {
      "name": "defold-codex-toolkit",
      "source": {
        "source": "local",
        "path": "./plugins/defold-codex-toolkit"
      },
      "policy": {
        "installation": "AVAILABLE",
        "authentication": "ON_INSTALL"
      },
      "category": "Coding"
    }
  ]
}
```

실제 적용은 [`examples/marketplace.json.example`](examples/marketplace.json.example) 파일을 복사해서 시작하는 방식을 권장합니다.

## Codex에서 사용되는 방식 설명

Codex는 호스트 프로젝트의 `.agents/plugins/marketplace.json`에 등록된 plugin path를 통해 `defold-codex-toolkit`의 `.codex-plugin/plugin.json`을 읽고, `skills/` 아래 `SKILL.md` 파일을 탐색합니다. 즉, Codex는 원격 GitHub URL을 직접 설치하는 것이 아니라 로컬 경로를 참조해서 plugin을 로드합니다.

`defold-build-bundle` skill은 위 Shared `/build` Contract를 따르는 Android build/upload 스크립트를 프로젝트에 정착시키는 지침으로도 사용됩니다.

## 주의사항 / 제한사항

- 이 저장소는 공개 GitHub용 plugin package이지만 OpenAI 공식 marketplace 자동 등록과는 무관합니다.
- GitHub URL만 넣어서 바로 설치되는 구조가 아닙니다.
- 반드시 프로젝트 안에 이 plugin 저장소를 로컬로 clone 또는 copy한 뒤, 프로젝트 쪽 marketplace가 그 로컬 path를 참조해야 합니다.
- README의 clone URL은 공개 저장소 `doctor-clawler/defold-codex-toolkit` 기준입니다.
