#!/bin/bash

# 고객 셀프 서비스 온보딩 스크립트
# 고객이 자신의 프로젝트에서 플랫폼 팀 접근을 허용하는 스크립트

set -e

# 플랫폼 팀 정보 (고객에게 제공)
PLATFORM_SA="crossplane-sa@sa-team-471206.iam.gserviceaccount.com"
PLATFORM_TEAM="awsdevteam7@gmail.com"

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
고객 셀프 서비스 온보딩 스크립트

이 스크립트는 고객이 자신의 GCP 프로젝트에서 실행하여
플랫폼 팀의 Crossplane 서비스 접근을 허용합니다.

Usage: $0 [options]

Options:
    --project-id <ID>    프로젝트 ID (생략시 현재 설정된 프로젝트 사용)
    --dry-run           실제 변경 없이 미리보기
    --minimal          최소 권한만 부여
    --help             도움말 표시

실행 전 요구사항:
1. gcloud CLI 설치 및 로그인
2. 대상 프로젝트의 Owner 또는 Project IAM Admin 권한
3. 필요한 API들이 활성화되어 있어야 함

Examples:
    $0                                    # 현재 프로젝트에 설정
    $0 --project-id my-project-123        # 특정 프로젝트에 설정
    $0 --dry-run                         # 미리보기
    $0 --minimal                         # 최소 권한만 부여
EOF
}

# 현재 프로젝트 확인
get_current_project() {
    gcloud config get-value project 2>/dev/null || echo ""
}

# 권한 확인
check_permissions() {
    local project_id=$1
    
    log_info "Checking your permissions in project: $project_id"
    
    # 프로젝트 접근 확인
    if ! gcloud projects describe "$project_id" &>/dev/null; then
        log_error "Cannot access project: $project_id"
        log_error "Please check project ID and your permissions"
        return 1
    fi
    
    # IAM 권한 확인
    local current_user
    current_user=$(gcloud config get-value account)
    local user_roles
    user_roles=$(gcloud projects get-iam-policy "$project_id" \
        --flatten="bindings[].members" \
        --filter="bindings.members:user:$current_user" \
        --format="value(bindings.role)" 2>/dev/null || echo "")
    
    local has_required_permissions=false
    while IFS= read -r role; do
        if [[ "$role" == "roles/owner" ]] || [[ "$role" == "roles/resourcemanager.projectIamAdmin" ]]; then
            has_required_permissions=true
            break
        fi
    done <<< "$user_roles"
    
    if [ "$has_required_permissions" = "false" ]; then
        log_error "Insufficient permissions!"
        log_error "You need Owner or Project IAM Admin role in project: $project_id"
        log_error "Current roles:"
        while IFS= read -r role; do
            echo "  - $role"
        done <<< "$user_roles"
        return 1
    fi
    
    log_success "Permission check passed"
    return 0
}

# API 활성화
enable_apis() {
    local project_id=$1
    local dry_run=$2
    
    log_info "Enabling required APIs..."
    
    local apis=(
        "iam.googleapis.com"
        "cloudresourcemanager.googleapis.com"
        "compute.googleapis.com"
        "container.googleapis.com"
    )
    
    for api in "${apis[@]}"; do
        if gcloud services list --project="$project_id" --filter="name:$api" --format="value(name)" | grep -q "$api"; then
            log_info "✓ API already enabled: $api"
        else
            if [ "$dry_run" = "true" ]; then
                log_info "[DRY RUN] Would enable API: $api"
            else
                log_info "Enabling API: $api"
                gcloud services enable "$api" --project="$project_id"
            fi
        fi
    done
}

# Crossplane SA 생성
create_crossplane_sa() {
    local project_id=$1
    local dry_run=$2
    local crossplane_sa="crossplane-sa@${project_id}.iam.gserviceaccount.com"
    
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would create Service Account: $crossplane_sa"
        return 0
    fi
    
    if gcloud iam service-accounts describe "$crossplane_sa" --project="$project_id" &>/dev/null; then
        log_warning "Crossplane Service Account already exists: $crossplane_sa"
    else
        log_info "Creating Crossplane Service Account: $crossplane_sa"
        gcloud iam service-accounts create "crossplane-sa" \
            --project="$project_id" \
            --display-name="Crossplane Service Account" \
            --description="Service Account for Platform Team Crossplane access"
    fi
    
    log_success "Crossplane Service Account ready: $crossplane_sa"
}

# Crossplane SA에 권한 부여
grant_crossplane_permissions() {
    local project_id=$1
    local minimal=$2
    local dry_run=$3
    local crossplane_sa="crossplane-sa@${project_id}.iam.gserviceaccount.com"
    
    local roles
    if [ "$minimal" = "true" ]; then
        log_info "Granting minimal permissions to Crossplane SA..."
        roles=(
            "roles/compute.instanceAdmin.v1"
            "roles/compute.networkAdmin"
            "roles/container.admin"
            "roles/iam.serviceAccountUser"
        )
    else
        log_info "Granting comprehensive permissions to Crossplane SA..."
        roles=(
            "roles/compute.admin"
            "roles/container.admin"
            "roles/iam.serviceAccountAdmin"
            "roles/iam.serviceAccountUser"
            "roles/storage.admin"
            "roles/cloudsql.admin"
            "roles/monitoring.admin"
            "roles/logging.admin"
            "roles/dns.admin"
        )
    fi
    
    for role in "${roles[@]}"; do
        if [ "$dry_run" = "true" ]; then
            log_info "[DRY RUN] Would grant role: $role"
        else
            log_info "Granting role: $role"
            gcloud projects add-iam-policy-binding "$project_id" \
                --member="serviceAccount:$crossplane_sa" \
                --role="$role" \
                --quiet
        fi
    done
    
    log_success "Crossplane SA permissions granted"
}

# 플랫폼 SA에 impersonation 권한 부여
grant_platform_access() {
    local project_id=$1
    local dry_run=$2
    local crossplane_sa="crossplane-sa@${project_id}.iam.gserviceaccount.com"
    
    if [ "$dry_run" = "true" ]; then
        log_info "[DRY RUN] Would grant impersonation access to platform SA: $PLATFORM_SA"
        return 0
    fi
    
    log_info "Granting impersonation access to platform team..."
    log_info "Platform SA: $PLATFORM_SA"
    
    gcloud iam service-accounts add-iam-policy-binding "$crossplane_sa" \
        --member="serviceAccount:$PLATFORM_SA" \
        --role="roles/iam.serviceAccountTokenCreator" \
        --quiet
    
    log_success "Platform team access granted"
}

# 설정 요약 출력
show_summary() {
    local project_id=$1
    local crossplane_sa="crossplane-sa@${project_id}.iam.gserviceaccount.com"
    
    echo ""
    echo "================================="
    echo "설정 완료 요약"
    echo "================================="
    echo "프로젝트 ID: $project_id"
    echo "생성된 SA: $crossplane_sa"
    echo "플랫폼 팀 SA: $PLATFORM_SA"
    echo ""
    echo "다음 단계:"
    echo "1. 플랫폼 팀($PLATFORM_TEAM)에게 온보딩 완료를 알려주세요"
    echo "2. 프로젝트 ID를 공유해주세요: $project_id"
    echo "3. 플랫폼 팀이 Crossplane 리소스 생성을 시작할 수 있습니다"
    echo ""
}

# 메인 함수
main() {
    local project_id=""
    local dry_run="false"
    local minimal="false"
    
    # 인자 파싱
    while [[ $# -gt 0 ]]; do
        case $1 in
            --project-id)
                project_id="$2"
                shift 2
                ;;
            --dry-run)
                dry_run="true"
                shift
                ;;
            --minimal)
                minimal="true"
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
    
    # 프로젝트 ID 확인
    if [ -z "$project_id" ]; then
        project_id=$(get_current_project)
        if [ -z "$project_id" ]; then
            log_error "No project specified and no default project set"
            log_error "Please set default project or use --project-id option"
            exit 1
        fi
        log_info "Using current project: $project_id"
    fi
    
    # 인증 확인
    if ! gcloud auth list --filter="status:ACTIVE" --format="value(account)" | head -1 &>/dev/null; then
        log_error "Not authenticated with gcloud"
        log_error "Please run: gcloud auth login"
        exit 1
    fi
    
    local current_user
    current_user=$(gcloud config get-value account)
    log_info "Authenticated as: $current_user"
    
    if [ "$dry_run" = "true" ]; then
        log_warning "DRY RUN MODE - No changes will be made"
    fi
    
    # 온보딩 프로세스 시작
    log_info "Starting self-service onboarding process..."
    echo "Project: $project_id"
    echo "Platform Team: $PLATFORM_TEAM"
    echo "Platform SA: $PLATFORM_SA"
    echo ""
    
    # 1. 권한 확인
    check_permissions "$project_id" || exit 1
    
    # 2. API 활성화
    enable_apis "$project_id" "$dry_run"
    
    # 3. Crossplane SA 생성
    create_crossplane_sa "$project_id" "$dry_run"
    
    # 4. Crossplane SA 권한 부여
    grant_crossplane_permissions "$project_id" "$minimal" "$dry_run"
    
    # 5. 플랫폼 팀 접근 권한 부여
    grant_platform_access "$project_id" "$dry_run"
    
    if [ "$dry_run" != "true" ]; then
        log_success "Self-service onboarding completed successfully!"
        show_summary "$project_id"
    else
        log_info "Dry run completed. Run without --dry-run to apply changes."
    fi
}

main "$@"