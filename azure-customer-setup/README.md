# Platform Team Crossplane 설정 가이드

이 가이드는 플랫폼 팀이 고객의 Azure 구독에서 Crossplane을 통해 리소스를 관리할 수 있도록 필요한 권한과 설정을 자동으로 구성합니다.

## 🎯 설정 개요

이 자동화 프로세스는 다음 작업을 수행합니다:

1. **관리자 동의**: 플랫폼 팀 애플리케이션에 대한 테넌트 관리자 승인
2. **역할 할당**: 플랫폼 팀 서비스 주체에 Contributor 권한 부여
3. **리소스 공급자 등록**: Microsoft.Network 및 Microsoft.ContainerService 등록
4. **검증**: 모든 설정이 올바르게 구성되었는지 확인

## 🔧 사전 요구사항

### Azure CLI 사용시
```bash
# Azure CLI 설치 확인
az --version

# Azure 로그인
az login

# 올바른 구독 선택
az account set --subscription "your-subscription-id"
```

### PowerShell 사용시
```powershell
# Azure PowerShell 모듈 설치 확인
Get-Module -ListAvailable -Name Az

# Azure 로그인
Connect-AzAccount

# 올바른 구독 선택
Set-AzContext -SubscriptionId "your-subscription-id"
```

## 🚀 설정 실행 방법

### 방법 1: Bash 스크립트 (Linux/macOS/WSL)

1. 스크립트 다운로드:
```powershell
curl -O https://raw.githubusercontent.com/Iac-Intra-project/customer-config-md/refs/heads/main/azure-customer-setup/setup-platform-access.sh
chmod +x setup-platform-access.sh
```

2. 실행 정책 설정 (필요시):
```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

3. 스크립트 실행:
```powershell
.\setup-platform-access.ps1
```

### 방법 3: Deploy to Azure 버튼 (웹 브라우저)

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://raw.githubusercontent.com/Iac-Intra-project/customer-config-md/refs/heads/main/azure-customer-setup/azuredeploy.json)

> **주의**: Deploy to Azure 버튼 사용시 사전에 관리자 동의를 완료해야 합니다.

## 📋 단계별 실행 과정

### 1단계: 관리자 동의
- 브라우저에서 관리자 동의 URL이 자동으로 열립니다
- Azure 전역 관리자 계정으로 로그인
- 권한 요청을 검토하고 "Accept" 클릭

### 2단계: 자동 설정
스크립트가 다음 작업을 자동으로 수행합니다:
- 서비스 주체 정보 확인
- 리소스 그룹 생성
- ARM 템플릿 배포
- 역할 할당 및 리소스 공급자 등록
- 설정 검증

## 🔍 설정 검증

스크립트 완료 후 다음 명령어로 설정을 확인할 수 있습니다:

```bash
# 역할 할당 확인
az role assignment list --assignee <service-principal-object-id> --role "Contributor"

# 리소스 공급자 상태 확인
az provider show --namespace Microsoft.Network --query registrationState
az provider show --namespace Microsoft.ContainerService --query registrationState
```

## 🛠️ 문제 해결

### 일반적인 문제들

#### 1. "서비스 주체를 찾을 수 없습니다"
**원인**: 관리자 동의가 완료되지 않았거나 시간이 더 필요한 경우
**해결**: 
- 관리자 동의 URL에서 "Accept"를 클릭했는지 확인
- 2-3분 대기 후 스크립트 재실행

#### 2. "권한이 부족합니다" 
**원인**: 현재 사용자에게 역할 할당 권한이 없는 경우
**해결**: 
- 구독의 소유자 또는 사용자 액세스 관리자 역할 필요
- Azure 전역 관리자에게 권한 요청

#### 3. "리소스 공급자 등록 실패"
**원인**: 구독에서 리소스 공급자 등록 권한이 없는 경우
**해결**:
```bash
# 수동으로 리소스 공급자 등록
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.ContainerService
```

## 🔐 보안 고려사항

### 할당되는 권한
- **Contributor**: 구독 범위에서 리소스 생성, 수정, 삭제 권한
- **제외 권한**: 역할 할당 관리, 정책 관리, 구독 설정 변경

### 접근 범위
- 플랫폼 팀은 지정된 구독 내에서만 작업 가능
- 다른 구독이나 테넌트에는 접근 불가

### 감사 및 모니터링
- 모든 작업은 Azure Activity Log에 기록됨
- Azure Security Center에서 비정상적인 활동 모니터링 가능

## 📞 지원

### 기술 지원
문제가 발생하거나 추가 도움이 필요한 경우:
- 이메일: platform-support@yourcompany.com
- Slack: #platform-support
- 내부 지원 포털: https://support.yourcompany.com

### 긴급 상황
서비스에 영향을 주는 긴급한 문제:
- 24/7 지원 전화: +82-2-XXXX-XXXX
- 긴급 이메일: platform-emergency@yourcompany.com

## 📝 설정 정보 기록

설정 완료 후 다음 정보를 기록해 두세요:

| 항목 | 값 |
|------|-----|
| 구독 ID | ________________ |
| 테넌트 ID | ________________ |
| 서비스 주체 Object ID | ________________ |
| 배포 이름 | ________________ |
| 설정 완료 날짜 | ________________ |

## 🔄 설정 제거

나중에 플랫폼 팀 접근 권한을 제거하려면:

```bash
# 역할 할당 제거
az role assignment delete --assignee <service-principal-object-id> --role "Contributor"

# 리소스 그룹 제거 (옵션)
az group delete --name platform-setup-rg --yes
```

## 📋 체크리스트

설정 완료 전 다음 항목들을 확인하세요:

- [ ] Azure CLI 또는 PowerShell 설치 및 로그인 완료
- [ ] 적절한 권한 (구독 소유자 또는 기여자 + 사용자 액세스 관리자) 보유
- [ ] 관리자 동의 완료
- [ ] 스크립트 실행 성공
- [ ] 역할 할당 확인
- [ ] 리소스 공급자 등록 확인
- [ ] 설정 정보 기록 완료

---

> **참고**: 이 설정은 플랫폼 팀이 Crossplane을 통해 고객 환경에서 안전하고 효율적으로 인프라를 관리할 수 있도록 설계되었습니다. 모든 작업은 Azure의 보안 모범 사례를 따르며, 필요한 최소 권한 원칙을 적용합니다