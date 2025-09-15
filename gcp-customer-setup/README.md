# GCP Crossplane Self-Service Onboarding Script

이 저장소는 **GCP 프로젝트에 Crossplane 접근을 허용**하기 위한  
**셀프 서비스 온보딩 스크립트**를 제공합니다.  

고객이 직접 자신의 프로젝트에서 이 스크립트를 실행하면,  
플랫폼 팀이 Crossplane을 통해 필요한 클라우드 리소스를  
대신 생성/운영할 수 있게 됩니다.

---

## 📋 주요 기능
- 현재 GCP 프로젝트 확인 및 권한 검증
- 필요한 GCP API 자동 활성화
- Crossplane 전용 Service Account 자동 생성
- Crossplane Service Account에 권한(Role) 부여
- 플랫폼 팀 서비스 계정(Platform SA)에 **Impersonation 권한** 부여
- Dry-run 모드 지원 (실제 변경 없이 미리보기 가능)
- 최소 권한 부여 모드 지원 (`--minimal`)

---

## ⚙️ 요구사항
1. [Google Cloud SDK (gcloud CLI)](https://cloud.google.com/sdk/docs/install) 설치 및 로그인 완료
   ```bash
   gcloud auth login


1. 스크립트 다운로드:
```powershell
curl -O https://raw.githubusercontent.com/Iac-Intra-project/customer-config-md/refs/heads/main/gcp-customer-setup/gcp-customer-self-service.sh
chmod +x gcp-customer-self-service.sh
```


2. 스크립트 실행:
```bash
./gcp-customer-self-service.sh
./gcp-customer-self-service.sh --minimal #권한최소
./gcp-customer-self-service.sh --dry-run #미리보기
```