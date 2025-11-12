# LiteLLM Proxy 5명 사용자 제한 우회 가이드

## 📋 개요

LiteLLM Proxy를 self-hosted로 운영할 때, 기본적으로 5명의 사용자 제한이 적용됩니다.
이 문서는 해당 제한을 분석하고 우회하는 방법을 설명합니다.

## 🔍 제한이 적용되는 위치

### 1. SSO 로그인 시
- **파일**: `litellm/proxy/management_endpoints/ui_sso.py`
- **라인**: 159
- **동작**: SSO가 활성화되어 있고 premium_user가 아닐 때, 사용자가 5명을 초과하면 로그인 차단

```python
if total_users and total_users > 5:
    raise ProxyException(
        message="You must be a LiteLLM Enterprise user to use SSO for more than 5 users..."
    )
```

### 2. 새 사용자 생성 시
- **파일**: `litellm/proxy/management_endpoints/internal_user_endpoints.py`
- **라인**: 369
- **동작**: `/user/new` API 호출 시 `_license_check.is_over_limit()` 메서드로 체크

```python
if total_users and _license_check.is_over_limit(total_users=total_users):
    raise HTTPException(
        status_code=403,
        detail="License is over limit. Please contact support@berri.ai to upgrade your license.",
    )
```

### 3. UI 표시 제한
- **파일**: `enterprise/litellm_enterprise/proxy/management_endpoints/internal_user_endpoints.py`
- **라인**: 44
- **동작**: `/user/available_users` 엔드포인트에서 `max_users=5` 반환 (Admin UI 왼쪽 하단 표시)

```python
if _has_user_setup_sso():
    premium_user_data = EnterpriseLicenseData(
        max_users=5,
    )
```

### 4. UI Usage 패널 표시
- **파일**: `ui/litellm-dashboard/src/app/(dashboard)/components/Sidebar2.tsx`
- **라인**: 407
- **동작**: Admin UI 왼쪽 하단에 Usage 패널을 표시 (환경 변수로 제어 가능)

```tsx
{isAdminRole(userRole) && 
 !collapsed && 
 process.env.NEXT_PUBLIC_HIDE_USAGE_INDICATOR !== 'true' && 
 <UsageIndicator accessToken={accessToken} width={220} />}
```

## 💡 해결 방법

### ✅ 옵션 1: SSO 비활성화 (가장 간단)

환경변수에서 SSO 설정을 제거하면 5명 제한이 해제됩니다:

```bash
# .env 파일 또는 환경변수에서 아래 항목 제거/주석 처리
# MICROSOFT_CLIENT_ID=...
# GOOGLE_CLIENT_ID=...
# GENERIC_CLIENT_ID=...
```

**장점**: 코드 수정 없음, 즉시 적용  
**단점**: SSO 로그인 기능 사용 불가

### ✅ 옵션 2: 코드 직접 수정 (권장)

5명 체크 로직을 주석 처리하거나 제한 숫자를 변경합니다.

**수정 파일 목록:**
1. `litellm/proxy/management_endpoints/ui_sso.py` (라인 159)
2. `litellm/proxy/management_endpoints/internal_user_endpoints.py` (라인 369)
3. `enterprise/litellm_enterprise/proxy/management_endpoints/internal_user_endpoints.py` (라인 44)

자세한 수정 내용은 아래 "적용된 수정 사항" 섹션을 참조하세요.

**장점**: SSO를 계속 사용하면서 제한만 제거  
**단점**: 코드 수정 필요, 업데이트 시 재적용 필요

### ✅ 옵션 3: premium_user 플래그 강제 활성화

`litellm/proxy/proxy_server.py`에서 `premium_user` 변수를 강제로 True로 설정합니다.

**장점**: 다른 Enterprise 기능도 활성화 가능  
**단점**: 예상치 못한 부작용 가능성

## 🔧 적용된 수정 사항

### 1. SSO 로그인 제한 주석 처리
**파일**: `litellm/proxy/management_endpoints/ui_sso.py`

```python
# 원본 (라인 159)
if total_users and total_users > 5:
    raise ProxyException(...)

# 수정 후 - 제한 제거 (주석 처리)
# if total_users and total_users > 5:
#     raise ProxyException(...)
```

### 2. 사용자 생성 제한 주석 처리
**파일**: `litellm/proxy/management_endpoints/internal_user_endpoints.py`

```python
# 원본 (라인 367-373)
total_users = await prisma_client.db.litellm_usertable.count()
if total_users and _license_check.is_over_limit(total_users=total_users):
    raise HTTPException(
        status_code=403,
        detail="License is over limit. Please contact support@berri.ai to upgrade your license.",
    )

# 수정 후 - 제한 제거 (주석 처리)
# total_users = await prisma_client.db.litellm_usertable.count()
# if total_users and _license_check.is_over_limit(total_users=total_users):
#     raise HTTPException(
#         status_code=403,
#         detail="License is over limit. Please contact support@berri.ai to upgrade your license.",
#     )
```

### 3. UI 표시 제한 제거
**파일**: `enterprise/litellm_enterprise/proxy/management_endpoints/internal_user_endpoints.py`

```python
# 원본 (라인 38-45)
if not premium_user:
    from litellm.proxy.auth.auth_utils import _has_user_setup_sso
    
    if _has_user_setup_sso():
        premium_user_data = EnterpriseLicenseData(
            max_users=5,
        )

# 수정 후 - SSO 설정 시에도 제한 표시 안 함 (주석 처리)
# if not premium_user:
#     from litellm.proxy.auth.auth_utils import _has_user_setup_sso
#     
#     if _has_user_setup_sso():
#         premium_user_data = EnterpriseLicenseData(
#             max_users=5,
#         )
```

### 4. UI Usage 패널 숨기기 (환경 변수로 제어)

#### (1) Sidebar 컴포넌트 수정
**파일**: `ui/litellm-dashboard/src/app/(dashboard)/components/Sidebar2.tsx`

```tsx
# 원본 (라인 407)
{isAdminRole(userRole) && !collapsed && <UsageIndicator accessToken={accessToken} width={220} />}

# 수정 후 - 환경 변수로 제어 가능
{isAdminRole(userRole) && 
 !collapsed && 
 process.env.NEXT_PUBLIC_HIDE_USAGE_INDICATOR !== 'true' && 
 <UsageIndicator accessToken={accessToken} width={220} />}
```

#### (2) Dockerfile에 환경 변수 추가
**파일**: `Dockerfile`

```dockerfile
# 원본 (라인 22-25)
# Copy the current directory contents into the container at /app
COPY . .

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh

# 수정 후 - UI 빌드 전에 환경 변수 설정
# Copy the current directory contents into the container at /app
COPY . .

# Set environment variable to hide usage indicator in UI
ENV NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true

# Build Admin UI
RUN chmod +x docker/build_admin_ui.sh && ./docker/build_admin_ui.sh
```

**참고**: 
- Dockerfile에 직접 설정되어 있으므로, Docker 이미지를 빌드하면 자동으로 Usage 패널이 숨겨집니다.
- `build_admin_ui.sh`도 수정하여 enterprise 모드가 아니어도 UI를 새로 빌드하도록 변경했습니다.

**⚠️ 중요 - build_admin_ui.sh 수정이 필요한 이유:**

원래 `build_admin_ui.sh`는 `enterprise_colors.json` 파일이 없으면 UI 빌드를 스킵했습니다:

```bash
# 원본 코드
if [ ! -f "enterprise/enterprise_ui/enterprise_colors.json" ]; then
    echo "Admin UI - using default LiteLLM UI"
    exit 0  # ← UI 빌드 없이 종료!
fi
```

이로 인해:
- ❌ 환경 변수가 설정되어도 UI가 새로 빌드되지 않음
- ❌ 기본 패키징된 UI(환경 변수 없이 빌드된 버전)를 사용
- ❌ `NEXT_PUBLIC_HIDE_USAGE_INDICATOR`가 적용되지 않음

수정 후:
- ✅ Enterprise 모드가 아니어도 UI를 새로 빌드
- ✅ 환경 변수가 빌드 타임에 적용됨
- ✅ Usage 패널이 올바르게 숨겨짐

**⚠️ 추가 수정 - build_ui.sh에서 환경 변수 확실히 적용:**

Next.js 정적 빌드에서 환경 변수를 확실히 적용하기 위해 세 가지 방법을 사용합니다:

```bash
# 1. Dockerfile에서 ENV 설정
ENV NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true

# 2. build_ui.sh에서 export
export NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true

# 3. .env.production 파일 생성 (가장 확실)
cat > .env.production << EOF
NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true
EOF
```

이렇게 3중으로 설정하면 Next.js 빌드 시 확실하게 환경 변수가 적용됩니다.

**🎯 최종 해결책 - UsageIndicator 컴포넌트 직접 수정:**

환경 변수 방식이 계속 작동하지 않아, 가장 직접적이고 확실한 방법을 적용했습니다:

**파일**: `ui/litellm-dashboard/src/components/usage_indicator.tsx`

```typescript
export default function UsageIndicator({ accessToken, width = 220 }: UsageIndicatorProps) {
  // Force return null to never render the usage panel
  return null;
}
```

**장점:**
- ✅ 100% 확실하게 Usage 패널 제거
- ✅ 환경 변수에 의존하지 않음
- ✅ 빌드 설정과 무관하게 작동
- ✅ 코드가 명확하고 간단함

**복원 방법:**
원본 코드가 파일 하단에 주석으로 보관되어 있습니다. 필요시 주석을 해제하고 `return null` 라인을 제거하면 됩니다.

## 🚀 적용 방법

### 1. 환경 변수 설정 (.env 파일)

`.env` 파일을 생성하고 필수 설정을 입력합니다:

```bash
# 필수 설정
LITELLM_MASTER_KEY=sk-1234567890abcdefghijklmnopqrstuvwxyz
LITELLM_SALT_KEY=sk-salt-d9f8c7b6a5e4321098765432fedcba09  # ⚠️ 변경 불가!
DATABASE_URL=postgresql://llmproxy:dbpassword9090@db:5432/litellm
PORT=4000
STORE_MODEL_IN_DB=True
LITELLM_LOG=INFO

# UI 설정 (선택사항)
NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true  # Usage 패널 숨기기 (true/false)
```

**중요:**
- `LITELLM_MASTER_KEY`: Admin UI 접근에 사용되는 마스터 키
- `LITELLM_SALT_KEY`: DB에 저장된 credential 암호화에 사용 (한 번 설정하면 변경 불가!)
- `DATABASE_URL`: docker-compose.yml의 DB 설정과 일치해야 함
- `NEXT_PUBLIC_HIDE_USAGE_INDICATOR`: Admin UI 왼쪽 하단 Usage 패널 표시 여부 (`true`로 설정 시 숨김)

**프로덕션 환경에서는 반드시 키를 변경하세요:**
```bash
# 안전한 랜덤 키 생성
openssl rand -hex 32
```

### 2. 코드 수정 (이미 완료됨)

위의 3개 파일이 수정되었습니다.

### 3. Docker Compose 재시작

```bash
# LiteLLM 컨테이너만 재시작
docker-compose restart litellm

# 또는 전체 재시작
docker-compose down && docker-compose up -d
```

### 4. Admin UI 접근

```bash
# 브라우저에서 접속
http://localhost:4000/ui

# 로그인 시 MASTER_KEY 입력
# Key: sk-1234567890abcdefghijklmnopqrstuvwxyz
```

### 5. 확인 사항

- ✅ 새 사용자 생성이 5명 제한 없이 가능한지 확인
- ✅ 왼쪽 하단의 사용자 제한 표시 확인 (무제한 또는 표시 안 됨)
- ✅ SSO 로그인 시 제한 없이 로그인 가능한지 확인

## ⚠️ 주의사항

1. **업스트림 업데이트 시**: 원본 리포지토리에서 업데이트를 가져올 때, 수정한 부분이 덮어써질 수 있습니다. 업데이트 후 다시 적용하세요.

2. **라이센스 준수**: 이 수정은 개인적인 학습/테스트 목적으로만 사용하세요. 프로덕션 환경에서는 공식 Enterprise 라이센스 구매를 권장합니다.

3. **백업**: 수정 전에 원본 파일을 백업해두는 것을 권장합니다.

4. **Git 관리**: 
   ```bash
   # 변경 사항을 별도 브랜치로 관리
   git checkout -b custom/remove-user-limit
   git add .
   git commit -m "Remove 5 user limit for self-hosted deployment"
   ```

## 📚 관련 코드 구조

```
litellm/
├── proxy/
│   ├── auth/
│   │   └── litellm_license.py          # LicenseCheck 클래스, is_over_limit() 메서드
│   └── management_endpoints/
│       ├── ui_sso.py                    # SSO 로그인 시 사용자 수 체크
│       └── internal_user_endpoints.py   # 새 사용자 생성 시 체크
├── enterprise/
│   └── litellm_enterprise/
│       └── proxy/
│           └── management_endpoints/
│               └── internal_user_endpoints.py  # UI에 표시되는 제한 정보
└── ui/
    └── litellm-dashboard/
        └── src/
            └── components/
                ├── usage_indicator.tsx   # 왼쪽 하단 사용자 수 표시 컴포넌트
                └── networking.tsx        # /user/available_users API 호출
```

## 🐳 Docker 이미지 빌드 및 배포

### ⚠️ 중요: 빌드 문제 해결

#### 1. Docker 캐시 문제
Docker 빌드 시 레이어 캐시로 인해 UI가 새로 빌드되지 않을 수 있습니다.
이 경우 `--no-cache` 옵션이 자동으로 적용됩니다.

#### 2. Node 버전 호환성 문제 (해결됨)
- **문제 1**: Node v18.17.0 사용 시 npm 호환성 에러 발생
  - **에러**: `npm ERR! notsup Required: {"node":"^20.17.0 || >=22.9.0"}`
  - **해결**: `docker/build_admin_ui.sh`에서 Node v20 사용하도록 수정

- **문제 2**: nvm 버전 인식 문제
  - **에러**: `! WARNING: Version 'v20' does not exist.`
  - **원인**: `nvm install v20`은 v20.19.5를 설치하지만, `nvm use v20`은 정확히 "v20" 버전을 찾으려고 시도
  - **해결**: `v20` 대신 `20` 사용 (버전 prefix 제거)
    - `nvm install 20` → 최신 Node 20.x 설치
    - `nvm use 20` → 설치된 Node 20.x 사용

- **문제 3**: subshell에서 nvm 환경 미전달
  - **에러**: `N/A: version "20 -> N/A" is not yet installed.`
  - **원인**: `build_admin_ui.sh`에서 `./build_ui.sh`를 실행할 때 새로운 subshell에서 실행되어 nvm 환경이 전달되지 않음
  - **시도한 해결책**: `bash -c "source $NVM_DIR/nvm.sh && nvm use 20 && ./build_ui.sh"`로 변경
  - **결과**: 여전히 실패 (nvm이 subshell에서 Node를 찾지 못함)

- **문제 4**: nvm 명령어 자체의 불안정성
  - **에러**: `! WARNING: Version '20' does not exist.` (nvm install은 성공했지만 nvm use는 실패)
  - **원인**: nvm의 alias 및 버전 인식 메커니즘이 Docker 빌드 환경에서 불안정
  - **해결**: nvm 명령 완전히 우회
    - 설치된 Node 바이너리 경로를 직접 찾아서 PATH에 추가
    - `NODE_VERSION=$(ls $NVM_DIR/versions/node/ | grep '^v20' | sort -V | tail -1)`
    - `export PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"`

- **문제 5**: Next.js linting 에러 (최종 해결)
  - **에러**: `Error: 'useState' is defined but never used. unused-imports/no-unused-imports`
  - **원인**: `usage_indicator.tsx`에서 `return null`로 변경했지만 사용하지 않는 import들이 남아있음
  - **해결**: 사용하지 않는 모든 import와 불필요한 타입 정의 제거
  - **결과**: UI가 정상적으로 빌드되고 `usage_indicator.tsx`의 `return null` 코드가 적용됨

### GCR에 이미지 빌드 & 푸시

macOS M4 환경에서 Colima를 사용하여 Docker 이미지를 빌드하고 GCP GCR에 푸시합니다.

```bash
# custom 디렉토리로 이동
cd custom

# 이미지 빌드 및 푸시 (한번에)
./build_and_push.sh

# 빌드만 수행 (푸시 안 함)
./build_and_push.sh --build-only

# 푸시만 수행 (이미지가 이미 빌드되어 있을 때)
./build_and_push.sh --push-only

# 멀티 플랫폼 빌드 (amd64 + arm64)
./build_and_push.sh --multi-platform

# 도움말
./build_and_push.sh --help
```

**빌드 전 준비사항:**
1. Colima가 실행 중인지 확인: `colima status`
2. gcloud CLI가 설치되어 있는지 확인: `gcloud --version`
3. GCP 프로젝트에 로그인: `gcloud auth login`
4. GCP 프로젝트 설정: `gcloud config set project liner-219011`

**빌드된 이미지:**
```
us.gcr.io/liner-219011/litellm-proxy/omni:custom-1
```

**이미지 사용:**
```bash
# 이미지 다운로드
docker pull us.gcr.io/liner-219011/litellm-proxy/omni:custom-1

# 컨테이너 실행
docker run -p 4000:4000 \
  -e LITELLM_MASTER_KEY=sk-1234 \
  us.gcr.io/liner-219011/litellm-proxy/omni:custom-1
```

## 🔗 참고 링크

- [LiteLLM 공식 문서](https://docs.litellm.ai/)
- [LiteLLM GitHub](https://github.com/BerriAI/litellm)
- [LiteLLM Proxy 설정 가이드](https://docs.litellm.ai/docs/proxy/deploy)

## ✅ 적용 완료 상태

### 수정된 파일 목록:
1. ✅ `litellm/proxy/management_endpoints/ui_sso.py` (라인 155-174)
   - SSO 로그인 시 5명 체크 로직 주석 처리
   
2. ✅ `litellm/proxy/management_endpoints/internal_user_endpoints.py` (라인 367-375)
   - 새 사용자 생성 시 5명 체크 로직 주석 처리
   
3. ✅ `enterprise/litellm_enterprise/proxy/management_endpoints/internal_user_endpoints.py` (라인 38-47)
   - UI 표시용 5명 제한 정보 제거
   
4. ✅ `ui/litellm-dashboard/src/app/(dashboard)/components/Sidebar2.tsx` (라인 407-410)
   - UI Usage 패널을 환경 변수로 제어 가능하도록 수정
   
5. ✅ `Dockerfile` (라인 24-25)
   - UI 빌드 시 `NEXT_PUBLIC_HIDE_USAGE_INDICATOR=true` 환경 변수 설정
   
6. ✅ `docker/build_admin_ui.sh` (라인 11-18, 50-53)
   - Enterprise 모드가 아니어도 기본 UI를 빌드하도록 수정 (환경 변수 적용을 위해)
   
7. ✅ `ui/litellm-dashboard/build_ui.sh` (라인 26-53)
   - 환경 변수 디버깅 정보 추가
   - `.env.production` 파일 생성하여 Next.js 빌드 시 환경 변수 확실히 적용
   - `npm install` 추가하여 의존성 설치
   
8. ✅ `ui/litellm-dashboard/src/components/usage_indicator.tsx` (완전 재작성)
   - **최종 해결책**: 컴포넌트를 완전히 비활성화하여 항상 `null` 반환
   - 환경 변수 방식이 작동하지 않아 직접 코드 수정으로 해결
   - 사용하지 않는 import 및 타입 제거 (linting 에러 해결)

9. ✅ `docker/build_admin_ui.sh` (Node 버전 업데이트)
   - Node v18.17.0 → 20으로 변경 (`nvm install 20`, `nvm use 20`)
   - npm 버전 호환성 문제 해결
   - `v20` 대신 `20` 사용으로 nvm 버전 인식 문제 해결

10. ✅ `ui/litellm-dashboard/build_ui.sh` (간소화)
   - nvm 설치/설정 로직 제거 (build_admin_ui.sh에서 처리)
   - Node.js 버전 확인만 수행
   
11. ✅ `docker/build_admin_ui.sh` (Node PATH 직접 설정) - **최종 수정**
   - nvm 명령 대신 설치된 Node 바이너리를 직접 PATH에 추가
   - `NODE_VERSION=$(ls $NVM_DIR/versions/node/ | grep '^v20' | sort -V | tail -1)`
   - `export PATH="$NVM_DIR/versions/node/$NODE_VERSION/bin:$PATH"`
   - nvm subshell 문제 완전히 회피

### 다음 단계:
```bash
# 1. LiteLLM Proxy 재시작
# Docker를 사용하는 경우:
docker-compose restart

# 직접 실행하는 경우:
# Ctrl+C로 종료 후 다시 시작
litellm --config proxy_server_config.yaml

# 2. Admin UI에서 확인
# - http://localhost:4000/ui 접속
# - 새 사용자 생성 테스트
# - 왼쪽 하단 사용자 제한 표시 확인
```

---

**작성일**: 2025-11-11  
**버전**: LiteLLM v1.79.1  
**상태**: ✅ 코드 수정 완료 - 재시작 필요

