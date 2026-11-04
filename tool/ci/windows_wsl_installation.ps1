# Finite facts only. This helper never installs or changes a Windows feature.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try {
  if ($env:GITHUB_ACTIONS -cne 'true' -or $env:RUNNER_OS -cne 'Windows' -or
      $env:RUNNER_ARCH -cne 'ARM64' -or $env:SYRIUS_HOSTED_RUNNER -cne 'github-hosted' -or
      $env:GITHUB_REPOSITORY -cne 'edgepillar/syrius' -or
      $env:GITHUB_EVENT_NAME -cne 'workflow_dispatch' -or
      $env:GITHUB_REF -cne 'refs/heads/redesign' -or $env:GITHUB_RUN_ATTEMPT -cne '1' -or
      $env:SYRIUS_WINDOWS_WSL_INSTALLATION -cne 'true') { throw 'ENVIRONMENT_REFUSED' }
  $stage = $env:SYRIUS_WSL_INSTALL_STAGE
  if ($stage -ceq 'preflight') {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    try {
      $principal = [Security.Principal.WindowsPrincipal]::new($identity)
      $admin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } finally { $identity.Dispose() }
    $os = @(Get-CimInstance -ClassName Win32_OperatingSystem -Property ProductType -OperationTimeoutSec 5)
    if ($os.Count -ne 1) { throw 'PREFLIGHT_REFUSED' }
    $vmp = @(Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='VirtualMachinePlatform'" -Property InstallState -OperationTimeoutSec 5)
    $wsl = @(Get-CimInstance -ClassName Win32_OptionalFeature -Filter "Name='Microsoft-Windows-Subsystem-Linux'" -Property InstallState -OperationTimeoutSec 5)
    if ($vmp.Count -ne 1 -or $wsl.Count -ne 1) { throw 'PREFLIGHT_REFUSED' }
    $packages = @(Get-AppxPackage -AllUsers -Name MicrosoftCorporationII.WindowsSubsystemForLinux)
    $existing = Test-Path -LiteralPath (Join-Path $env:ProgramFiles 'WSL/wsl.exe') -PathType Leaf
    $pending = (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') -or
      (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired')
    $value = [ordered]@{
      schema = 1; scope = 'wsl_install_preflight'; administrator = [bool]$admin
      desktop_windows = ($os[0].ProductType -eq 1)
      native_arm64 = ([Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() -ceq 'Arm64')
      virtual_machine_platform_enabled = ($vmp[0].InstallState -eq 1)
      wsl_feature_enabled = ($wsl[0].InstallState -eq 1)
      existing_msi_binary = [bool]$existing; store_package_present = ($packages.Count -gt 0)
      known_windows_reboot_pending = [bool]$pending
    }
  } elseif ($stage -ceq 'signature') {
    if ([string]::IsNullOrEmpty($env:SYRIUS_WSL_MSI_FILE)) { throw 'SIGNATURE_REFUSED' }
    $signatures = @(Get-AuthenticodeSignature -LiteralPath $env:SYRIUS_WSL_MSI_FILE)
    if ($signatures.Count -ne 1) { throw 'SIGNATURE_REFUSED' }
    $signature = $signatures[0]
    $microsoft = $false
    if ($null -ne $signature.SignerCertificate) {
      $microsoft = $signature.SignerCertificate.Subject -cmatch '(^|, )O=Microsoft Corporation(,|$)'
    }
    $value = [ordered]@{
      schema = 1; scope = 'wsl_install_signature'
      valid = ($signature.Status.ToString() -ceq 'Valid'); microsoft_publisher = [bool]$microsoft
    }
  } else { throw 'STAGE_REFUSED' }
  [Console]::Out.WriteLine((ConvertTo-Json -InputObject $value -Depth 3 -Compress))
  exit 0
} catch {
  [Console]::Out.WriteLine('WSL_INSTALL_FACTS_REFUSED')
  exit 1
}
