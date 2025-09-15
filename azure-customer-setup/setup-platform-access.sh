#!/bin/bash

# Platform Team Crossplane Setup Script
# 고객이 실행하는 자동화 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 설정값
APP_CLIENT_ID="0dd41fa3-9db7-48cd-9892-6756399a3803"
PLATFORM_TENANT_ID="ab2773f0-5bcf-42c6-8b33-94ea19af0463"
RESOURCE_GROUP_NAME="platform-setup-rg"
DEPLOYMENT_NAME="platform-crossplane-setup-$(date +%Y%m%d-%H%M%S)"

# 함수 정의
print_step() {
    echo -e "${BLUE}[단계 $1]${NC} $2"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

check_prerequisites() {
    print_step "0" "사전 요구사항 확인 중..."
    
    # Azure CLI 설치 확인
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI가 설치되지 않았습니다. https://docs.microsoft.com/cli/azure/install-azure-cli 에서 설치해주세요."
        exit 1
    fi
    
    # Azure CLI 로그인 확인
    if ! az account show &> /dev/null; then
        print_error "Azure CLI에 로그인이 필요합니다. 'az login'을 실행해주세요."
        exit 1
    fi
    
    print_success "사전 요구사항 확인 완료"
}

get_tenant_info() {
    print_step "1" "테넌트 정보 확인 중..."
    
    CURRENT_TENANT_ID=$(az account show --query tenantId -o tsv)
    CURRENT_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
    CURRENT_USER=$(az account show --query user.name -o tsv)
    
    echo "현재 테넌트 ID: $CURRENT_TENANT_ID"
    echo "현재 구독 ID: $CURRENT_SUBSCRIPTION_ID"
    echo "현재 사용자: $CURRENT_USER"
    
    print_success "테넌트 정보 확인 완료"
}

admin_consent() {
    print_step "2" "관리자 동의 수행"
    
    ADMIN_CONSENT_URL="https://login.microsoftonline.com/$CURRENT_TENANT_ID/adminconsent?client_id=$APP_CLIENT_ID"
    
    echo "아래 URL을 클릭하여 관리자 동의를 완료해주세요:"
    echo ""
    echo -e "${YELLOW}$ADMIN_CONSENT_URL${NC}"
    echo ""
    echo "브라우저에서 다음 작업을 수행해주세요:"
    echo "1. 위 링크를 클릭하거나 복사하여 브라우저에서 열기"
    echo "2. Azure 관리자 계정으로 로그인"
    echo "3. 권한 요청을 검토하고 'Accept' 클릭"
    echo ""
    
    # macOS/Linux에서 자동으로 브라우저 열기 시도
    if command -v open &> /dev/null; then
        open "$ADMIN_CONSENT_URL"
    elif command -v xdg-open &> /dev/null; then
        xdg-open "$ADMIN_CONSENT_URL"
    fi
    
    read -p "관리자 동의를 완료했으면 Enter를 눌러 계속하세요..."
    
    print_success "관리자 동의 단계 완료"
}

get_service_principal() {
    print_step "3" "서비스 주체 정보 확인 중..."
    
    # 서비스 주체가 생성될 때까지 대기
    echo "서비스 주체 생성 대기 중..."
    sleep 10
    
    # 최대 5번 재시도
    for i in {1..5}; do
        if SP_OBJECT_ID=$(az ad sp show --id "$APP_CLIENT_ID" --query id -o tsv 2>/dev/null); then
            echo "서비스 주체 Object ID: $SP_OBJECT_ID"
            print_success "서비스 주체 확인 완료"
            return 0
        else
            print_warning "서비스 주체를 찾을 수 없습니다. ($i/5) 10초 후 재시도..."
            sleep 10
        fi
    done
    
    print_error "서비스 주체를 찾을 수 없습니다. 관리자 동의가 올바르게 완료되었는지 확인해주세요."
    exit 1
}

create_resource_group() {
    print_step "4" "리소스 그룹 생성 중..."
    
    # 기본 위치 설정 (고객이 변경 가능)
    LOCATION="koreacentral"
    
    if az group show --name "$RESOURCE_GROUP_NAME" &> /dev/null; then
        print_warning "리소스 그룹 '$RESOURCE_GROUP_NAME'이 이미 존재합니다."
    else
        az group create --name "$RESOURCE_GROUP_NAME" --location "$LOCATION"
        print_success "리소스 그룹 '$RESOURCE_GROUP_NAME' 생성 완료"
    fi
}

deploy_arm_template() {
    print_step "5" "ARM 템플릿 배포 중..."
    
    # 매개변수 파일 임시 생성
    TEMP_PARAMS_FILE=$(mktemp)
    cat > "$TEMP_PARAMS_FILE" << EOF
{
  "\$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "servicePrincipalObjectId": {
      "value": "$SP_OBJECT_ID"
    },
    "applicationClientId": {
      "value": "$APP_CLIENT_ID"
    },
    "resourceGroupName": {
      "value": "$RESOURCE_GROUP_NAME"
    },
    "location": {
      "value": "koreacentral"
    }
  }
}
EOF

    # ARM 템플릿 URL (GitHub Raw URL로 교체 필요)
    #TEMPLATE_URI="https://raw.githubusercontent.com/Iac-Intra-project/infra/refs/heads/main/azure-customer-setup/azuredeploy.json"
    TEMPLATE_FILE="./azuredeploy.json"
    echo "ARM 템플릿 배포 시작..."
    echo "배포 이름: $DEPLOYMENT_NAME"
    
    if az deployment sub create \
        --location "koreacentral" \
        --name "$DEPLOYMENT_NAME" \
        --template-file "$TEMPLATE_FILE" \
        --parameters "@$TEMP_PARAMS_FILE" \
        --output table; then
        
        print_success "ARM 템플릿 배포 완료"
    else
        print_error "ARM 템플릿 배포 실패"
        rm -f "$TEMP_PARAMS_FILE"
        exit 1
    fi
    
    # 임시 파일 정리
    rm -f "$TEMP_PARAMS_FILE"
}

verify_deployment() {
    print_step "6" "배포 결과 검증 중..."
    
    echo "역할 할당 확인 중..."
    if az role assignment list \
        --assignee "$SP_OBJECT_ID" \
        --role "Contributor" \
        --scope "/subscriptions/$CURRENT_SUBSCRIPTION_ID" \
        --query "[].{Role:roleDefinitionName, Scope:scope}" \
        --output table | grep -q "Contributor"; then
        print_success "Contributor 역할 할당 확인됨"
    else
        print_warning "Contributor 역할 할당을 확인할 수 없습니다"
    fi
    
    echo "리소스 공급자 등록 상태 확인 중..."
    NETWORK_STATUS=$(az provider show --namespace Microsoft.Network --query registrationState -o tsv)
    CONTAINER_STATUS=$(az provider show --namespace Microsoft.ContainerService --query registrationState -o tsv)
    
    echo "Microsoft.Network: $NETWORK_STATUS"
    echo "Microsoft.ContainerService: $CONTAINER_STATUS"
    
    if [[ "$NETWORK_STATUS" == "Registered" && "$CONTAINER_STATUS" == "Registered" ]]; then
        print_success "모든 리소스 공급자가 등록됨"
    else
        print_warning "일부 리소스 공급자가 아직 등록 중일 수 있습니다"
    fi
}

generate_summary() {
    print_step "7" "설정 요약 생성 중..."
    
    echo ""
    echo "=================================="
    echo "  플랫폼 설정 완료 요약"
    echo "=================================="
    echo "구독 ID: $CURRENT_SUBSCRIPTION_ID"
    echo "테넌트 ID: $CURRENT_TENANT_ID"
    echo "애플리케이션 Client ID: $APP_CLIENT_ID"
    echo "서비스 주체 Object ID: $SP_OBJECT_ID"
    echo "배포 이름: $DEPLOYMENT_NAME"
    echo "리소스 그룹: $RESOURCE_GROUP_NAME"
    echo ""
    echo "할당된 권한:"
    echo "- Contributor 역할 (구독 범위)"
    echo ""
    echo "등록된 리소스 공급자:"
    echo "- Microsoft.Network"
    echo "- Microsoft.ContainerService"
    echo "=================================="
    echo ""
    
    print_success "플랫폼 팀 Crossplane 설정이 완료되었습니다!"
    echo "이제 플랫폼 팀이 귀하의 구독에서 리소스를 관리할 수 있습니다."
}

# 메인 실행 함수
main() {
    echo "=================================="
    echo "  Platform Team Crossplane Setup"
    echo "=================================="
    echo ""
    
    check_prerequisites
    get_tenant_info
    admin_consent
    get_service_principal
    deploy_arm_template
    verify_deployment
    generate_summary
}

# 스크립트 실행
main "$@"