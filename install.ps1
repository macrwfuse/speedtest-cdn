<#
speedtest-cdn — Windows 环境安装

作用:
  1. 检测系统 Node.js (>= 18)；缺失或过旧时下载便携版到 .\node-runtime\
  2. 创建 data\ reports\ 运行目录

项目无 npm 依赖（仅使用 Node 内置模块），无需 npm install。

用法:
  .\install.ps1             自动安装
  .\install.ps1 --force     强制重新下载便携 Node

如遇执行策略限制:
  powershell -ExecutionPolicy Bypass -File install.ps1
#>

$ErrorActionPreference = 'Stop'
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$NodeVersion = 'v20.19.0'
$Force = $args -contains '--force'

Write-Host "════════════════════════════════════════════════════════════"
Write-Host "  speedtest-cdn — 环境安装"
Write-Host "════════════════════════════════════════════════════════════"

# ── 检测系统 Node ──
$SystemNode = $null
$cmd = Get-Command node -ErrorAction SilentlyContinue
if ($cmd) {
    $major = & $cmd.Source -p "process.versions.node.split('.')[0]"
    if ([int]$major -ge 18) {
        Write-Host "✅ 系统已安装 Node.js $(& $cmd.Source -v)" -ForegroundColor Green
        $SystemNode = $cmd.Source
    } else {
        Write-Host "⚠️  系统 Node.js 版本过低: $(& $cmd.Source -v)" -ForegroundColor Yellow
    }
} else {
    Write-Host "⚠️  未检测到系统 Node.js" -ForegroundColor Yellow
}

if ($SystemNode -and -not $Force) {
    Write-Host "   无需安装便携版 (如需强制重装: .\install.ps1 --force)"
} else {
    # ── 下载便携 Node ──
    $arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
    $Filename = "node-$NodeVersion-win-$arch.zip"
    $MirrorUrl = "https://npmmirror.com/mirrors/node/$NodeVersion/$Filename"
    $OfficialUrl = "https://nodejs.org/dist/$NodeVersion/$Filename"

    Write-Host ""
    Write-Host "📦 下载便携版 Node.js $NodeVersion (win-$arch)..."

    $TmpZip = Join-Path $env:TEMP $Filename
    $Source = $null

    try {
        Invoke-WebRequest -Uri $MirrorUrl -OutFile $TmpZip -UseBasicParsing -TimeoutSec 120
        $Source = 'npmmirror 镜像'
    } catch {
        try {
            Invoke-WebRequest -Uri $OfficialUrl -OutFile $TmpZip -UseBasicParsing -TimeoutSec 120
            $Source = 'nodejs.org 官方'
        } catch {
            Write-Host "❌ 下载失败，请手动安装 Node.js 18+:" -ForegroundColor Red
            Write-Host "   winget:   winget install OpenJS.NodeJS.LTS"
            Write-Host "   官方:     https://nodejs.org/"
            exit 1
        }
    }
    Write-Host "   来源: $Source"

    Write-Host "📂 解压到 .\node-runtime\ ..."
    $ExtractDir = Join-Path $ScriptDir 'node-runtime-tmp'
    if (Test-Path $ExtractDir) { Remove-Item -Recurse -Force $ExtractDir }
    if (Test-Path (Join-Path $ScriptDir 'node-runtime')) { Remove-Item -Recurse -Force (Join-Path $ScriptDir 'node-runtime') }

    Expand-Archive -Path $TmpZip -DestinationPath $ExtractDir -Force
    # zip 内含 node-vXX-win-x64 顶层目录，移动到 node-runtime
    $InnerDir = Get-ChildItem $ExtractDir -Directory | Select-Object -First 1
    Move-Item $InnerDir.FullName (Join-Path $ScriptDir 'node-runtime')
    Remove-Item -Recurse -Force $ExtractDir
    Remove-Item -Force $TmpZip

    $PortableNode = Join-Path $ScriptDir 'node-runtime\node.exe'
    Write-Host "✅ 便携版已就绪: $(& $PortableNode -v)" -ForegroundColor Green
}

# ── 运行目录 ──
foreach ($d in @('data', 'reports')) {
    $p = Join-Path $ScriptDir $d
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p | Out-Null }
}
Write-Host "✅ 运行目录就绪: data\ reports\"

# ── 完成 ──
Write-Host ""
Write-Host "════════════════════════════════════════════════════════════"
Write-Host "  ✅ 安装完成"
Write-Host ""
Write-Host "  运行全流程:  .\run.bat  (或 .\run.ps1)"
Write-Host "  快速模式:    .\run.bat --quick"
Write-Host "  仅检测:      .\run.bat --check-only"
Write-Host "════════════════════════════════════════════════════════════"
