#!/bin/bash

# AWS 고객 셀프 서비스 온보딩 스크립트
# 고객이 자신의 AWS 계정에서 실행하여 플랫폼 팀 접근을 허용하는 스크립트

set -e

# 플랫폼 팀 정보
PLATFORM_ACCOUNT_ID="806263093053"
PLATFORM_USER_ARN="arn:aws:iam::062196287647:user/lsh202"
PLATFORM_TEAM_CONTACT="lsh40382753@gmail.com"
CROSSPLANE_ROLE_NAME="CrossplaneAccessRole"
CROSSPLANE_EXTERNAL_ID="crossplane-external-id-ALPHA"

# 색상 출력
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

usage() {
    cat << EOF
AWS 고객 셀프 서비스 온보딩 스크립트

이 스크립트는 고객이 자신의 AWS 계정에서 실행하여
플랫폼 팀의 Crossplane 서비스 접근을 허용합니다.

Usage: $0 [options]

Options:
    --role-name <NAME>       역할 이름 (기본값: CrossplaneAccessRole)
    --minimal               최소 권한만 부여 (AdministratorAccess 대신)
    --dry-run               실제 변경 없이 미리보기
    --help                  도움말 표시

실행 전 요구사항:
1. AWS CLI 설치 및 설정
2. 대상 계정의 IAM 관리 권한
3. 필요한 서비스들이 활성화되어 있어야 함

참고: External ID '$CROSSPLANE_EXTERNAL_ID'가 자동으로 적용됩니다.

Examples:
    $0                                          # 기본 설정으로 온보딩
    $0 --minimal                               # 최소 권한으로 설정
    $0 --dry-run                              # 미리보기
EOF
}

# 현재 계정 정보 확인
get_current_account() {
    aws sts get-caller-identity --query Account --output text 2>/dev/null || echo ""
}

# 현재 사용자/역할 정보 확인
get_current_identity() {
    aws sts get-caller-identity --query Arn --output text 2>/dev/null || echo ""
}

# 권한 확인
check_permissions() {
    log_info "Checking your AWS permissions..."
    
    local current_identity
    current_identity=$(get_current_identity)
    
    if [ -z "$current_identity" ]; then
        log_error "Not authenticated with AWS CLI"
        log_error "Please run: aws configure"
        return 1
    fi
    
    log_info "Authenticated as: $current_identity"
    
    # IAM 권한 확인
    if ! aws iam list-roles --max-items 1 &>/dev/null; then
        log_error "Insufficient IAM permissions!"
        log_error "You need IAM administrative permissions in this account"
        return 1
    fi
    
    log_success "Permission check passed"
    return 0
}


# create_trust_policy() 함수 전체
create_trust_policy() {
  # Check if the required variables are set
  if [ -z "$PLATFORM_USER_ARN" ] || [ -z "$CROSSPLANE_EXTERNAL_ID" ]; then
    log_error "Required variables are not set: PLATFORM_USER_ARN or CROSSPLANE_EXTERNAL_ID"
    return 1
  fi
  
  # Use a here document (cat << EOF) to generate clean JSON without leading whitespace
  cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": "${PLATFORM_USER_ARN}"
      },
      "Action": [
        "sts:AssumeRole",
        "sts:TagSession"
      ],
      "Condition": {
        "StringEquals": {
          "sts:ExternalId": "${CROSSPLANE_EXTERNAL_ID}"
        }
      }
    }
  ]
}
EOF
}

# 최소 권한 정책 생성
create_minimal_policy() {
    cat << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "VPCNetworkingPermissions",
      "Effect": "Allow",
      "Action": [
        "ec2:CreateVpc",
        "ec2:DeleteVpc",
        "ec2:DescribeVpcs",
        "ec2:ModifyVpcAttribute",
        "ec2:CreateSubnet",
        "ec2:DeleteSubnet",
        "ec2:DescribeSubnets",
        "ec2:ModifySubnetAttribute",
        "ec2:CreateInternetGateway",
        "ec2:DeleteInternetGateway",
        "ec2:DescribeInternetGateways",
        "ec2:AttachInternetGateway",
        "ec2:DetachInternetGateway",
        "ec2:CreateRouteTable",
        "ec2:DeleteRouteTable",
        "ec2:DescribeRouteTables",
        "ec2:CreateRoute",
        "ec2:DeleteRoute",
        "ec2:AssociateRouteTable",
        "ec2:DisassociateRouteTable",
        "ec2:CreateTags",
        "ec2:DeleteTags",
        "ec2:DescribeTags"
      ],
      "Resource": "*"
    },
    {
      "Sid": "IAMRoleManagement",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole",
        "iam:DeleteRole",
        "iam:GetRole",
        "iam:ListRoles",
        "iam:UpdateAssumeRolePolicy",
        "iam:TagRole",
        "iam:UntagRole",
        "iam:ListRoleTags",
        "iam:AttachRolePolicy",
        "iam:DetachRolePolicy",
        "iam:ListAttachedRolePolicies",
        "iam:ListRolePolicies",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::*:role/*-cluster-role",
        "arn:aws:iam::*:role/*-node-role"
      ]
    },
    {
      "Sid": "IAMPolicyAccess",
      "Effect": "Allow",
      "Action": [
        "iam:GetPolicy",
        "iam:ListPolicies"
      ],
      "Resource": [
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
        "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
        "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
        "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
      ]
    },
    {
      "Sid": "EKSClusterManagement",
      "Effect": "Allow",
      "Action": [
        "eks:CreateCluster",
        "eks:DeleteCluster",
        "eks:DescribeCluster",
        "eks:ListClusters",
        "eks:UpdateClusterConfig",
        "eks:UpdateClusterVersion",
        "eks:TagResource",
        "eks:UntagResource",
        "eks:ListTagsForResource"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSNodeGroupManagement",
      "Effect": "Allow",
      "Action": [
        "eks:CreateNodegroup",
        "eks:DeleteNodegroup",
        "eks:DescribeNodegroup",
        "eks:ListNodegroups",
        "eks:UpdateNodegroupConfig",
        "eks:UpdateNodegroupVersion"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EC2InstanceManagement",
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceTypes",
        "ec2:DescribeInstanceAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeKeyPairs",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeAvailabilityZones",
        "ec2:DescribeAccountAttributes",
        "ec2:DescribeAddresses"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AutoScalingPermissions",
      "Effect": "Allow",
      "Action": [
        "autoscaling:CreateAutoScalingGroup",
        "autoscaling:DeleteAutoScalingGroup",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DescribeAutoScalingInstances",
        "autoscaling:DescribeLaunchConfigurations",
        "autoscaling:DescribeScalingActivities",
        "autoscaling:UpdateAutoScalingGroup",
        "autoscaling:CreateLaunchConfiguration",
        "autoscaling:DeleteLaunchConfiguration"
      ],
      "Resource": "*"
    },
    {
      "Sid": "CloudWatchLogsPermissions",
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:DescribeLogGroups",
        "logs:DeleteLogGroup",
        "logs:PutRetentionPolicy"
      ],
      "Resource": "arn:aws:logs:*:*:log-group:/aws/eks/*"
    },
    {
      "Sid": "ECRPermissions",
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Sid": "STSPermissions",
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

# Crossplane 역할 생성
create_crossplane_role() {
    local role_name=$1
    local minimal=$2
    local dry_run=$3
    
    # Debugging step
    log_info "Debugging variables..."
    log_info "PLATFORM_USER_ARN: $PLATFORM_USER_ARN"
    log_info "CROSSPLANE_EXTERNAL_ID: $CROSSPLANE_EXTERNAL_ID"
    local customer_account
    customer_account=$(get_current_account)
    local role_arn="arn:aws:iam::${customer_account}:role/${role_name}"
    
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would create IAM role: $role_name"
        log_info "[DRY RUN] Role ARN would be: $role_arn"
        log_info "[DRY RUN] Would use External ID: $CROSSPLANE_EXTERNAL_ID"
        return 0
    fi
    
    # 역할이 이미 존재하는지 확인
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        log_warning "Role already exists: $role_name"
        log_info "Updating trust policy..."
    else
        log_info "Creating IAM role: $role_name"
    fi
    
    # Trust Policy 파일 생성
    local trust_policy_file="/tmp/trust-policy-$$.json"
    create_trust_policy > "$trust_policy_file"
    
# Trust Policy 검증 (RESOURCE_POLICY 로 지정)
log_info "Validating trust policy..."
cat "$trust_policy_file"

# validate-policy 는 findings 를 JSON 으로 반환
validation_output=$(aws iam validate-policy \
  --policy-document "file://$trust_policy_file" \
  --policy-type RESOURCE_POLICY 2>&1)  # stderr도 캡처

# AWS CLI가 JSON을 반환했는지 확인
if echo "$validation_output" | jq -e . >/dev/null 2>&1; then
  errors=$(echo "$validation_output" | jq '.findings[]? | select(.findingType=="ERROR")')
  warnings=$(echo "$validation_output" | jq '.findings[]? | select(.findingType=="SECURITY_WARNING" or .findingType=="WARNING")')

  if [ -n "$errors" ]; then
    log_error "Trust policy has errors:"
    echo "$errors" | jq -r '.issue // .findingDetails'
    rm -f "$trust_policy_file"
    return 1
  fi

  if [ -n "$warnings" ]; then
    log_warning "Trust policy has warnings:"
    echo "$warnings" | jq -r '.issue // .findingDetails'
    # 경고는 계속 진행
  fi

  log_success "Trust policy validation passed"
else
  # JSON이 아니면(예: 명령 사용 불가/버전 문제) 메시지 출력
  log_warning "Policy validation output (non-JSON):"
  echo "$validation_output"
  log_warning "Proceeding without validator enforcement (create-role will still validate)."
fi

    
    # 역할 생성 또는 업데이트
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        # 기존 역할의 trust policy 업데이트
        log_info "Updating trust policy for existing role..."
        aws iam update-assume-role-policy \
            --role-name "$role_name" \
            --policy-document "file://$trust_policy_file"
    else
        # 새 역할 생성
        log_info "Creating new IAM role..."
        aws iam create-role \
            --role-name "$role_name" \
            --assume-role-policy-document "file://$trust_policy_file" \
            --description "Role for Platform Team Crossplane access" \
            --tags Key=ManagedBy,Value=PlatformTeam Key=Purpose,Value=Crossplane
    fi
    
    # 정책 연결이 성공한 경우에만 계속 진행
    if [ $? -eq 0 ]; then
        log_success "Role creation/update successful"
        
        # 정책 연결
        if [ "$minimal" = "true" ]; then
            log_info "Attaching minimal permissions..."
            
            # 최소 권한 정책 생성
            local policy_name="${role_name}MinimalPolicy"
            local policy_file="/tmp/minimal-policy-$$.json"
            create_minimal_policy > "$policy_file"
            
            # 정책이 이미 존재하는지 확인
            local policy_arn="arn:aws:iam::${customer_account}:policy/${policy_name}"
            if ! aws iam get-policy --policy-arn "$policy_arn" &>/dev/null; then
                log_info "Creating minimal policy..."
                aws iam create-policy \
                    --policy-name "$policy_name" \
                    --policy-document "file://$policy_file" \
                    --description "Minimal permissions for Crossplane operations"
            fi
            
            # 정책 연결
            aws iam attach-role-policy \
                --role-name "$role_name" \
                --policy-arn "$policy_arn"
            
            rm -f "$policy_file"
        else
            log_info "Attaching AdministratorAccess policy..."
            aws iam attach-role-policy \
                --role-name "$role_name" \
                --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
        fi
    else
        log_error "Role creation/update failed"
        rm -f "$trust_policy_file"
        return 1
    fi
    
    # 임시 파일 정리
    rm -f "$trust_policy_file"
    
    log_success "Crossplane role created: $role_arn"
    log_info "External ID configured: $CROSSPLANE_EXTERNAL_ID"
    return 0
}

# 역할 테스트
test_role_assumption() {
    local role_name=$1
    
    local customer_account
    customer_account=$(get_current_account)
    local role_arn="arn:aws:iam::${customer_account}:role/${role_name}"
    
    log_info "Testing role assumption (simulation)..."
    log_info "Platform team would assume: $role_arn"
    log_info "Using External ID: $CROSSPLANE_EXTERNAL_ID"
    
    # 역할 정보 확인
    if aws iam get-role --role-name "$role_name" &>/dev/null; then
        log_success "✓ Role exists and is accessible"
        
        # Trust policy 확인
        local trust_policy
        trust_policy=$(aws iam get-role --role-name "$role_name" --query 'Role.AssumeRolePolicyDocument' --output text)
        if echo "$trust_policy" | grep -q "$PLATFORM_USER_ARN"; then
            log_success "✓ Trust policy allows platform team access"
        else
            log_error "✗ Trust policy does not allow platform team access"
            return 1
        fi
        
        if echo "$trust_policy" | grep -q "$CROSSPLANE_EXTERNAL_ID"; then
            log_success "✓ External ID properly configured"
        else
            log_error "✗ External ID not found in trust policy"
            return 1
        fi
        
        # 연결된 정책 확인
        local attached_policies
        attached_policies=$(aws iam list-attached-role-policies --role-name "$role_name" --query 'AttachedPolicies[].PolicyArn' --output text)
        if [ -n "$attached_policies" ]; then
            log_success "✓ Policies attached to role"
            while IFS= read -r policy; do
                log_info "  - $policy"
            done <<< "$attached_policies"
        else
            log_warning "⚠ No policies attached to role"
        fi
    else
        log_error "✗ Role not found or not accessible"
        return 1
    fi
    
    return 0
}

# 설정 요약 출력
show_summary() {
    local role_name=$1
    local minimal=$2
    
    local customer_account
    customer_account=$(get_current_account)
    local role_arn="arn:aws:iam::${customer_account}:role/${role_name}"
    
    echo ""
    echo "================================="
    echo "AWS 온보딩 완료 요약"
    echo "================================="
    echo "고객 계정 ID: $customer_account"
    echo "생성된 역할: $role_name"
    echo "역할 ARN: $role_arn"
    echo "플랫폼 팀 사용자: $PLATFORM_USER_ARN"
    echo "External ID: $CROSSPLANE_EXTERNAL_ID"
    if [ "$minimal" = "true" ]; then
        echo "권한 수준: 최소 권한"
    else
        echo "권한 수준: 관리자 권한"
    fi
    echo ""
    echo "다음 단계:"
    echo "1. 플랫폼 팀($PLATFORM_TEAM_CONTACT)에게 온보딩 완료를 알려주세요"
    echo "2. 다음 정보를 공유해주세요:"
    echo "   - 계정 ID: $customer_account"
    echo "   - 역할 ARN: $role_arn"
    echo "   - External ID: $CROSSPLANE_EXTERNAL_ID"
    echo "3. 플랫폼 팀이 Crossplane 리소스 생성을 시작할 수 있습니다"
    echo ""
}

# 메인 함수
main() {
    local role_name="$CROSSPLANE_ROLE_NAME"
    local minimal="false"
    local dry_run="false"
    
    # 인자 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --role-name)
                role_name="$2"
                shift 2
                ;;
            --minimal)
                minimal="true"
                shift
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            -*)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
            *)
                log_error "Unexpected argument: $1"
                usage
                exit 1
                ;;
        esac
    done
    
    # 인증 확인
    check_permissions || exit 1
    
    local customer_account
    customer_account=$(get_current_account)
    
    if [ "$dry_run" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    # 온보딩 프로세스 시작
    log_info "Starting AWS self-service onboarding process..."
    echo "Customer Account: $customer_account"
    echo "Platform Team: $PLATFORM_TEAM_CONTACT"
    echo "Platform User: $PLATFORM_USER_ARN"
    echo "Role Name: $role_name"
    echo "External ID: $CROSSPLANE_EXTERNAL_ID"
    echo ""
    
    # Crossplane 역할 생성
    create_crossplane_role "$role_name" "$minimal" "$dry_run" || exit 1
    
    if [ "$dry_run" != "true" ]; then
        log_success "AWS onboarding completed successfully!"
        
        # 설정 테스트
        echo ""
        log_info "Testing configuration..."
        test_role_assumption "$role_name"
        
        # 요약 출력
        show_summary "$role_name" "$minimal"
    else
        log_info "Dry run completed. Run without --dry-run to apply changes."
    fi
}

main "$@"