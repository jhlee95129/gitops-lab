# CLAUDE.md

이 파일은 Claude Code가 이 리포에서 작업할 때 참조하는 프로젝트 컨텍스트다. 매 세션 시작 시 읽고 따른다.

## 프로젝트

**gitops-lab** — Argo CD 기반 GitOps PoC.

목표: "Git push → 자동 배포 / 드리프트 감지 / 롤백"이 동작하는 최소 시스템을 만들고, 4가지 데모 시나리오를 검증한다.

## 현재 상태

- ✅ **Phase 1**: 모노레포 부트스트랩 완료 (`apps/web`, `apps/api`, 로컬 dev 검증, GitHub push)
- ⏳ **Phase 2~6**: 미진행
- 다음 작업: Phase 2 (Dockerization)부터 순서대로

## 기술 스택 (확정, 변경 금지)

| 항목 | 선택 |
|---|---|
| 패키지 매니저 | pnpm |
| 모노레포 | 단일 리포, 워크스페이스 도구 미적용 |
| Web | Next.js (App Router, TypeScript, Tailwind) |
| API | Express, **JavaScript 유지** (TS 변환 금지) |
| 컨테이너 레지스트리 | GHCR |
| 로컬 K8s | k3d |
| 매니페스트 | plain YAML (**Helm/Kustomize 금지**, Phase 7에서만 옵션) |
| Ingress | Traefik (k3d 기본) |
| CI | GitHub Actions |
| CD | Argo CD (공식 install manifest) |

## 리포 구조 (목표)

```
gitops-lab/
├── apps/
│   ├── web/           # Next.js (Dockerfile, .dockerignore)
│   └── api/           # Express (Dockerfile, .dockerignore)
├── deploy/            # Argo CD가 추적하는 K8s 매니페스트
│   ├── namespace.yaml
│   ├── web/{deployment,service}.yaml
│   ├── api/{deployment,service}.yaml
│   └── ingress.yaml
├── argocd/            # Argo CD Application CR
│   ├── application-web.yaml
│   └── application-api.yaml
├── .github/workflows/build-images.yml
├── scripts/           # cluster-up, cluster-down, argocd-install
├── docker-compose.yml
└── README.md
```

## 작업 규칙

### 진행 방식
- **Phase 단위로 진행하고, Phase 단위로 커밋한다.** 한 커밋에 여러 Phase 섞지 않는다.
- **각 Phase의 검증 단계를 통과해야 다음 Phase로 넘어간다.** 검증 실패 시 사용자에게 보고하고 정지.
- 큰 변경 전에는 사용자에게 계획 요약 후 진행.

### 커밋 메시지
- Conventional Commits 사용: `feat:`, `fix:`, `chore:`, `docs:`, `ci:`, `ops:`
- Phase별 권장 메시지:
  - Phase 2: `feat: dockerize web and api`
  - Phase 3: `feat: add k8s manifests and k3d scripts`
  - Phase 4: `ci: build and push images to ghcr`
  - Phase 5: `feat: add argocd applications`
  - Phase 6: `docs: add e2e gitops verification results`

### 금지 사항
- ❌ 테스트 프레임워크 추가 (Jest, Vitest 등)
- ❌ express / next 외 라이브러리 추가
- ❌ CSS 라이브러리 추가 (Tailwind 외)
- ❌ api를 TypeScript로 변환
- ❌ Helm 사용
- ❌ Next.js 부트스트랩 결과물 임의 수정 (디자인/페이지 추가)
- ❌ Argo CD 초기 비밀번호를 README/커밋에 노출
- ❌ 클러스터 생성/삭제를 임의로 실행 (스크립트만 작성, 실행은 사용자가)

### 허용/권장
- ✅ `apps/web/src/app/page.tsx`는 데모용으로 API 호출 결과 표시하도록 수정 OK
- ✅ `<OWNER>` placeholder는 사용자에게 GitHub username 묻고 일괄 치환
- ✅ 각 Phase 종료 시 README의 해당 섹션 업데이트
- ✅ 매니페스트 변경은 작은 단위로 (시나리오 검증에 유리)

## Phase 로드맵

### Phase 2 — Dockerization
**산출물**: web/api Dockerfile, .dockerignore, docker-compose.yml, `next.config.ts`에 `output: 'standalone'` 추가, web이 `process.env.API_URL`로 api 호출

**검증**:
```bash
docker compose up --build
curl http://localhost:4000/version    # {"version":"0.1.0"}
# 브라우저 localhost:3000 에서 "API version: 0.1.0" 표시
```

### Phase 3 — 로컬 K8s 배포 (수동)
**산출물**: `deploy/` 매니페스트, `scripts/cluster-up.sh`, `scripts/cluster-down.sh`

k3d 생성 옵션: `--port "8080:80@loadbalancer"`, `--agents 1`  
Ingress host: `gitops-lab.localhost`, `/api/*` → api, `/*` → web  
이 단계 한정으로 로컬 빌드 이미지 + `k3d image import` 사용 가능 (Phase 4 전까지)

**검증**:
```bash
kubectl apply -f deploy/namespace.yaml
kubectl apply -f deploy/ -R
kubectl get pods -n gitops-lab    # 전부 Running
curl http://gitops-lab.localhost:8080/api/health
```

### Phase 4 — CI (GitHub Actions → GHCR)
**산출물**: `.github/workflows/build-images.yml`

- 트리거: `push` to `main`, paths-filter (`apps/web/**`, `apps/api/**`)
- matrix: `[web, api]`
- 이미지: `ghcr.io/<OWNER>/gitops-lab-web`, `ghcr.io/<OWNER>/gitops-lab-api`
- 태그: `sha-<short>`, `latest`
- 권한: `contents: read, packages: write`
- 인증: `${{ secrets.GITHUB_TOKEN }}`
- 빌드 후 Deployment 매니페스트 image를 GHCR 경로로 교체

**검증**: push 후 Actions 성공 + GHCR 패키지 존재 + `docker pull` 성공

### Phase 5 — Argo CD 설치 및 Application 등록
**산출물**: `scripts/argocd-install.sh`, `argocd/application-{web,api}.yaml`

Application 설정:
- `source.repoURL`: 사용자 GitHub 리포
- `source.path`: `deploy/web` 또는 `deploy/api`
- `source.targetRevision`: `main`
- `destination.namespace`: `gitops-lab`
- `syncPolicy.automated`: `prune: true, selfHeal: true`

**검증**:
```bash
kubectl port-forward svc/argocd-server -n argocd 8081:443
# 브라우저에서 두 Application이 Synced / Healthy 상태
```

### Phase 6 — E2E GitOps 검증 (4가지 시나리오)

| # | 시나리오 | 핵심 동작 |
|---|---|---|
| A | 매니페스트 변경 (replicas 2→3) → push | Argo CD 자동 sync, pod 3개 |
| B | 코드 변경 → CI 이미지 빌드 → tag 갱신 → push | 새 이미지로 롤아웃 |
| C | `kubectl scale` 직접 실행 (드리프트) | selfHeal로 원상 복귀 |
| D | `git revert` push (롤백) | 이전 상태로 복귀 |

각 시나리오 결과를 README에 기록. (Argo CD UI 스크린샷 첨부 권장)

### Phase 7 — Polish (선택, 사용자 요청 시에만)
- Argo CD Image Updater (image tag 자동 갱신)
- Kustomize overlays (`deploy/base/`, `deploy/overlays/{dev,prod}/`)
- pnpm workspace 도입
- ApplicationSet

## 사전 확인 (작업 시작 전 사용자에게 묻기)

다음 정보가 없으면 Phase 2 시작 전에 물어본다:

1. GitHub username (이미지 경로의 `<OWNER>`)
2. 설치된 도구: `docker`, `kubectl`, `k3d`, `gh` 버전
3. GHCR visibility: public / private
4. Ingress host name: `gitops-lab.localhost` OK인지

## PoC 종료 기준

- [ ] Phase 2~6 모든 커밋이 main에 push됨
- [ ] 4가지 시나리오(A~D) 검증 완료, README에 기록
- [ ] `scripts/cluster-up.sh` → `scripts/argocd-install.sh` → `kubectl apply -f argocd/` 만으로 from-scratch 재현 가능
- [ ] Argo CD UI에서 두 Application이 Synced / Healthy 유지

## 사용자 컨텍스트 (참고)

- 시니어 풀스택 개발자 (~20년 경력)
- **간결하고 결론 우선 응답** 선호. 사족·헷지·과도한 도덕 코멘트 비선호
- 한국어로 소통
- GitOps 학습/검증이 1차 목적 — 프로덕션 운영이 아님. 과잉 엔지니어링 금지