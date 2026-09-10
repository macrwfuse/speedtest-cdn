<#
speedtest-cdn — Windows PowerShell 一键运行

用法:
  .\run.ps1                 完整流程
  .\run.ps1 --quick         快速模式
  .\run.ps1 --check-only    只检测不修改
  .\run.ps1 --nodes cdn-360 仅验证指定节点

如遇执行策略限制:
  powershell -ExecutionPolicy Bypass -File run.ps1
#>

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

# ── Node.js 检测（优先使用项目内置 node-runtime） ──
$NodeBin = $null
$Bundled = Join-Path $ScriptDir 'node-runtime\node.exe'
if (Test-Path $Bundled) {
    $NodeBin = $Bundled
} else {
    $cmd = Get-Command node -ErrorAction SilentlyContinue
    if ($cmd) { $NodeBin = $cmd.Source }
}

if (-not $NodeBin) {
    Write-Host "[ERROR] 未检测到 Node.js (需要 18+)" -ForegroundColor Red
    Write-Host ""
    Write-Host "请先安装 Node.js，任选一种方式："
    Write-Host "  1) 运行本项目安装脚本:  .\install.ps1"
    Write-Host "  2) winget:              winget install OpenJS.NodeJS.LTS"
    Write-Host "  3) 官方下载:            https://nodejs.org/"
    exit 1
}

# 版本检查 (>= 18)
$major = & $NodeBin -p "process.versions.node.split('.')[0]"
if ([int]$major -lt 18) {
    Write-Host "[ERROR] Node.js 版本过低: $(& $NodeBin -v) (需要 18+)" -ForegroundColor Red
    Write-Host "        请运行 .\install.ps1 或手动升级"
    exit 1
}

Write-Host "[OK] Node.js $(& $NodeBin -v) ($NodeBin)" -ForegroundColor Green
Write-Host ""

# ── 执行全流程 ──
& $NodeBin scripts/pipeline.mjs @args
exit $LASTEXITCODE
