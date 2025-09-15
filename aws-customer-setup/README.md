# AWS Crossplane Self-Service Onboarding

이 저장소는 **고객(테넌트) AWS 계정에서 플랫폼 팀의 Crossplane 접근을 허용**하기 위한  
**셀프 서비스 온보딩 스크립트**(`onboard-aws.sh`)를 제공합니다.

고객이 자신의 계정에서 스크립트를 실행하면, **신뢰 정책(Trust Policy) + 권한(Policy) + External ID**가 설정되어  
플랫폼 팀이 Crossplane을 통해 필요한 클라우드 리소스를 대신 생성/운영할 수 있게 됩니다.

---

## 📦 제공 스크립트

- `onboard-aws.sh`  
  - IAM Role 생성/갱신
  - Trust Policy에 **플랫폼 사용자 ARN**과 **External ID** 반영
  - 권한(AdministratorAccess 또는 최소 권한) 부여
  - 유효성 검사(`aws iam validate-policy`) 및 요약 출력
  - `--dry-run`(미리보기), `--minimal`(최소 권한) 지원

> 스크립트 상의 주요 기본값  
> - 플랫폼 사용자 ARN: `arn:aws:iam::062196287647:user/lsh202`  
> - 플랫폼 연락처: `lsh40382753@gmail.com`  
> - 기본 역할명: `CrossplaneAccessRole`  
> - External ID: `crossplane-external-id-ALPHA`

---

## ⚙️ 사전 요구사항

1. **AWS CLI v2** 설치 및 자격 설정이 완료되어있어야 합니다.
   ```bash
   aws configure
   # 또는 SSO 사용 시
   aws sso login

1. 스크립트 다운로드:
```bash
curl -O https://raw.githubusercontent.com/Iac-Intra-project/customer-config-md/refs/heads/main/aws-customer-setup/aws-customer-self-service.sh
chmod +x aws-customer-self-service.sh
```

3. 스크립트 실행:
```bash
./aws-customer-self-service.sh #
./aws-customer-self-service.sh --minimal # 최소권한만 부여
./aws-customer-self-service.sh --dry-run # 미리보기
```

