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

**참고**: Dockerfile에 직접 설정되어 있으므로, Docker 이미지를 빌드하면 자동으로 Usage 패널이 숨겨집니다.

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

