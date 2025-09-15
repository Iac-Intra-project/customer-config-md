# customer-config-md

이 저장소는 고객(테넌트)이 자신의 클라우드 계정에서 플랫폼 팀의 Crossplane 접근을 허용하기 위한 셀프 서비스 온보딩 스크립트들을 제공합니다.

## 디렉토리 구조

### `aws-customer-setup/`
AWS 고객을 위한 셀프 서비스 온보딩 스크립트
- `aws-customer-self-service.sh` - AWS IAM Role 생성 및 Trust Policy 설정 스크립트
- `README.md` - AWS 온보딩 가이드 및 사용법

### `azure-customer-setup/`
Azure 고객을 위한 셀프 서비스 온보딩 스크립트
- `setup-platform-access.sh` - Bash 스크립트 (Linux/macOS/WSL용)
- `setup-platform-access.ps1` - PowerShell 스크립트 (Windows용)
- `azuredeploy.json` - ARM 템플릿 (자동 배포용)
- `deploy-to-azure.json` - Azure 배포 매개변수 파일
- `README.md` - Azure 온보딩 가이드 및 사용법

### `gcp-customer-setup/`
GCP 고객을 위한 셀프 서비스 온보딩 스크립트
- `gcp-customer-self-service.sh` - GCP Service Account 생성 및 권한 설정 스크립트
- `README.md` - GCP 온보딩 가이드 및 사용법

## 사용 방법

각 클라우드 플랫폼별 디렉토리의 README.md 파일을 참조하여 해당하는 스크립트를 다운로드하고 실행하세요.

1. **AWS**: `aws-customer-setup/README.md` 참조
2. **Azure**: `azure-customer-setup/README.md` 참조  
3. **GCP**: `gcp-customer-setup/README.md` 참조