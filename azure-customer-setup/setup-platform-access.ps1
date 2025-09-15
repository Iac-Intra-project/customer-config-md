# Platform Team Crossplane Setup Script (PowerShell)
# 고객이 실행하는 자동화 스크립트

param(
    [string]$AppClientId = "0dd41fa3-9db7-48cd-9892-6756399a3803",
    [string]$PlatformTenantId = "ab2773f0-5bcf-42c6-8b33-94ea19af0463",
    [string]$ResourceGroupName = "platform-setup-rg",
    [string]$Location = "Korea Central"
)

# 에러 발생시 중단
$ErrorActionPreference = "Stop"

# 색상 함수
function Write-ColorOutput($ForegroundColor) {
    $fc = $host.UI.RawUI.ForegroundColor
    $host.UI.RawUI.ForegroundColor = $ForegroundColor
    if ($args) {
        Write-Output $args
    }
    $host.UI.RawUI.ForegroundColor = $fc
}

function Write-Step($StepNumber, $Message) {
    Write-ColorOutput Blue "[단계 $StepNumber] $Message"
}

function Write-Success($Message) {
    Write-ColorOutput Green "✓ $Message"
}

function Write-Warning($Message) {
    Write-ColorOutput Yellow "⚠ $Message"
}

function Write-Error($Message) {
    Write-ColorOutput Red "✗ $Message"
}

function Test-Prerequisites {
    Write-Step "0" "사전 요구사항 확인 중..."
    
    # Azure PowerShell 모듈 확인
    if (-not (Get-Module -ListAvailable -Name Az)) {
        Write-Error "Azure PowerShell 모듈이 설치되지 않았습니다. 'Install-Module -Name Az'를 실행해주세요."
        exit 1
    }
    
    # Azure 로그인 확인
    try {
        $context = Get-AzContext
        if (-not $context) {
            Write-Error "Azure PowerShell에 로그인이 필요합니다. 'Connect-AzAccount'를 실행해주세요."
            exit 1
        }
    }
    catch {
        Write-Error "Azure PowerShell에 로그인이 필요합니다. 'Connect-AzAccount'를 실행해주세요."
        exit 1
    }
    
    Write-Success "사전 요구사항 확인 완료"
}

function Get-TenantInfo {
    Write-Step "1" "테넌트 정보 확인 중..."
    
    $context = Get-AzContext
    $script:CurrentTenantId = $context.Tenant.Id
    $script:CurrentSubscriptionId = $context.Subscription.Id
    $script:CurrentUser = $context.Account.Id
    
    Write-Output "현재 테넌트 ID: $script:CurrentTenantId"
    Write-Output "현재 구독 ID: $script:CurrentSubscriptionId"
    Write-Output "현재 사용자: $script:CurrentUser"
    
    Write-Success "테넌트 정보 확인 완료"
}

function Invoke-AdminConsent {
    Write-Step "2" "관리자 동의 수행"
    
    $AdminConsentUrl = "https://login.microsoftonline.com/$script:CurrentTenantId/adminconsent?client_id=$AppClientId"
    
    Write-Output ""
    Write-Output "아래 URL을 클릭하여 관리자 동의를 완료해주세요:"
    Write-Output ""
    Write-ColorOutput Yellow $AdminConsentUrl
    Write-Output ""
    Write-Output "브라우저에서 다음 작업을 수행해주세요:"
    Write-Output "1. 위 링크를 클릭하거나 복사하여 브라우저에서 열기"
    Write-Output "2. Azure 관리자 계정으로 로그인"
    Write-Output "3. 권한 요청을 검토하고 'Accept' 클릭"
    Write-Output ""
    
    # Windows에서 자동으로 브라우저 열기
    Start-Process $AdminConsentUrl
    
    Read-Host "관리자 동의를 완료했으면 Enter를 눌러 계속하세요"
    
    Write-Success "관리자 동의 단계 완료"
}

function Get-ServicePrincipalInfo {
    Write-Step "3" "서비스 주체 정보 확인 중..."
    
    # 서비스 주체가 생성될 때까지 대기
    Write-Output "서비스 주체 생성 대기 중..."
    Start-Sleep -Seconds 10
    
    # 최대 5번 재시도
    for ($i = 1; $i -le 5; $i++) {
        try {
            $sp = Get-AzADServicePrincipal -ApplicationId $AppClientId -ErrorAction Stop
            $script:ServicePrincipalObjectId = $sp.Id
            Write-Output "서비스 주체 Object ID: $script:ServicePrincipalObjectId"
            Write-Success "서비스 주체 확인 완료"
            return
        }
        catch {
            Write-Warning "서비스 주체를 찾을 수 없습니다. ($i/5) 10초 후 재시도..."
            Start-Sleep -Seconds 10
        }
    }
    
    Write-Error "서비스 주체를 찾을 수 없습니다. 관리자 동의가 올바르게 완료되었는지 확인해주세요."
    exit 1
}

function New-PlatformResourceGroup {
    Write-Step "4" "리소스 그룹 생성 중..."
    
    $existingRg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
    if ($existingRg) {
        Write-Warning "리소스 그룹 '$ResourceGroupName'이 이미 존재합니다."
    }
    else {
        New-AzResourceGroup -Name $ResourceGroupName -Location $Location
        Write-Success "리소스 그룹 '$ResourceGroupName' 생성 완료"
    }
}

function Deploy-ARMTemplate {
    Write-Step "5" "ARM 템플릿 배포 중..."
    
    $DeploymentName = "platform-crossplane-setup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    
    # ARM 템플릿 URL (GitHub Raw URL로 교체 필요)
    $TemplateUri = "https://raw.githubusercontent.com/Iac-Intra-project/customer-config-md/refs/heads/main/azure-customer-setup/azuredeploy.json"
    
    $TemplateParameters = @{
        servicePrincipalObjectId = $script:ServicePrincipalObjectId
        applicationClientId = $AppClientId
    }
    
    Write-Output "ARM 템플릿 배포 시작..."
    Write-Output "배포 이름: $DeploymentName"
    
    try {
        $deployment = New-AzResourceGroupDeployment `
            -ResourceGroupName $ResourceGroupName `
            -Name $DeploymentName `
            -TemplateUri $TemplateUri `
            -TemplateParameterObject $TemplateParameters `
            -Verbose
        
        Write-Success "ARM 템플릿 배포 완료"
        $script:DeploymentName = $DeploymentName
    }
    catch {
        Write-Error "ARM 템플릿 배포 실패: $($_.Exception.Message)"
        exit 1
    }
}

function Test-Deployment {
    Write-Step "6" "배포 결과 검증 중..."
    
    Write-Output "역할 할당 확인 중..."
    $roleAssignments = Get-AzRoleAssignment -ObjectId $script:ServicePrincipalObjectId -RoleDefinitionName "Contributor"
    
    if ($roleAssignments) {
        Write-Success "Contributor 역할 할당 확인됨"
    }
    else {
        Write-Warning "Contributor 역할 할당을 확인할 수 없습니다"
    }
    
    Write-Output "리소스 공급자 등록 상태 확인 중..."
    $networkProvider = Get-AzResourceProvider -ProviderNamespace "Microsoft.Network"
    $containerProvider = Get-AzResourceProvider -ProviderNamespace "Microsoft.ContainerService"
    
    Write-Output "Microsoft.Network: $($networkProvider.RegistrationState)"
    Write-Output "Microsoft.ContainerService: $($containerProvider.RegistrationState)"
    
    if ($networkProvider.RegistrationState -eq "Registered" -and $containerProvider.RegistrationState -eq "Registered") {
        Write-Success "모든 리소스 공급자가 등록됨"
    }
    else {
        Write-Warning "일부 리소스 공급자가 아직 등록 중일 수 있습니다"
    }
}

function New-Summary {
    Write-Step "7" "설정 요약 생성 중..."
    
    Write-Output ""
    Write-Output "=================================="
    Write-Output "  플랫폼 설정 완료 요약"
    Write-Output "=================================="
    Write-Output "구독 ID: $script:CurrentSubscriptionId"
    Write-Output "테넌트 ID: $script:CurrentTenantId"
    Write-Output "애플리케이션 Client ID: $AppClientId"
    Write-Output "서비스 주체 Object ID: $script:ServicePrincipalObjectId"
    Write-Output "배포 이름: $script:DeploymentName"
    Write-Output "리소스 그룹: $ResourceGroupName"
    Write-Output ""
    Write-Output "할당된 권한:"
    Write-Output "- Contributor 역할 (구독 범위)"
    Write-Output ""
    Write-Output "등록된 리소스 공급자:"
    Write-Output "- Microsoft.Network"
    Write-Output "- Microsoft.ContainerService"
    Write-Output "=================================="
    Write-Output ""
    
    Write-Success "플랫폼 팀 Crossplane 설정이 완료되었습니다!"
    Write-Output "이제 플랫폼 팀이 귀하의 구독에서 리소스를 관리할 수 있습니다."
}

# 메인 실행
function Main {
    Write-Output "=================================="
    Write-Output "  Platform Team Crossplane Setup"
    Write-Output "=================================="
    Write-Output ""
    
    Test-Prerequisites
    Get-TenantInfo
    Invoke-AdminConsent
    Get-ServicePrincipalInfo
    New-PlatformResourceGroup
    Deploy-ARMTemplate
    Test-Deployment
    New-Summary
}

# 스크립트 실행
Main