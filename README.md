# Defold Codex Toolkit

이 저장소는 공개 GitHub에 올릴 수 있는 Defold용 Codex plugin 저장소입니다.

## 프로젝트 소개

`defold-codex-toolkit`은 Defold 프로젝트 작업에서 반복되는 워크플로우를 Codex가 더 일관되게 지원할 수 있도록 정리한 plugin 패키지입니다. 이 저장소는 Codex에서 로컬로 로드되는 plugin 형식이며, 공개 GitHub 업로드 자체가 OpenAI 공식 공개 marketplace 자동 등록을 뜻하지 않습니다.

## 제공 기능

- Defold 빌드 및 번들 작업 가이드
- Defold GUI 및 입력 처리 가이드
- Defold 디버깅 워크플로우 가이드
- Defold 프로젝트 컨벤션 점검 가이드

각 항목은 `skills/` 하위 `SKILL.md`로 제공됩니다.

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
git clone https://github.com/<your-org>/<repo-name>.git defold-codex-toolkit
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

## 주의사항 / 제한사항

- 이 저장소는 공개 GitHub용 plugin package이지만 OpenAI 공식 marketplace 자동 등록과는 무관합니다.
- GitHub URL만 넣어서 바로 설치되는 구조가 아닙니다.
- 반드시 프로젝트 안에 이 plugin 저장소를 로컬로 clone 또는 copy한 뒤, 프로젝트 쪽 marketplace가 그 로컬 path를 참조해야 합니다.
- README의 `git clone` 예시는 치환용 URL을 사용하므로 실제 공개 저장소 주소로 바꿔 써야 합니다.
