# install.ps1 - 数字人一键部署脚本
# 需要管理员权限运行

$ErrorActionPreference = "Stop"
$LogFile = "$env:USERPROFILE\Desktop\数字人部署包\install.log"

function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg"
    Add-Content -Path $LogFile -Value "[$ts] $msg" -ErrorAction SilentlyContinue
}

# === Step 0: 管理员权限检查 ===
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Log "需要管理员权限，自动提权..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Log "===== 数字人部署开始 ====="

# === Step 1: 确定安装盘 ===
$InstallDrive = $null
foreach ($drive in @('D','E')) {
    if (Test-Path "${drive}:") {
        $free = (Get-PSDrive $drive).Free / 1GB
        if ($free -ge 85) {
            $InstallDrive = $drive
            Log "安装盘: ${drive}: (可用 $([math]::Round($free,1))GB)"
            break
        }
    }
}
if (-not $InstallDrive) {
    Log "错误: D盘和E盘都没有85GB可用空间!"
    exit 1
}

# === Step 2: GPU检测 ===
Log "检测GPU..."
try {
    $gpuInfo = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1
    Log "GPU: $gpuInfo"
    $vram = [int](($gpuInfo -split ',')[1] -replace '[^0-9]','')
    if ($vram -lt 8000) {
        Log "错误: VRAM $($vram)MB < 8GB, 不满足要求!"
        exit 1
    }
    $gpuName = ($gpuInfo -split ',')[0]
    if ($gpuName -match '5090|5080') {
        $ComposeFile = "docker-compose-5090.yml"
    } else {
        $ComposeFile = "docker-compose.yml"
    }
    Log "选择compose: $ComposeFile"
} catch {
    Log "错误: 未检测到NVIDIA GPU!"
    exit 1
}

# === Step 3: 创建目录 ===
$DesktopDir = "$env:USERPROFILE\Desktop\数字人部署包"
$DockerDataDir = "${InstallDrive}:\DockerData"
$DuixDataDir = "${InstallDrive}:\duix_avatar_data"

New-Item -ItemType Directory -Force -Path $DesktopDir | Out-Null
New-Item -ItemType Directory -Force -Path $DockerDataDir | Out-Null
New-Item -ItemType Directory -Force -Path $DuixDataDir | Out-Null
Log "目录创建完成"

# === Step 4: 下载安装包到桌面 ===
$Repo = "https://github.com/chenwen-295/hokshuziren-skill/releases/download/v1.0"

$files = @(
    @{Url="$Repo/DockerDesktopInstaller.exe"; Name="DockerDesktopInstaller.exe"},
    @{Url="$Repo/Voicebox_0.4.5_x64-setup.exe"; Name="Voicebox_0.4.5_x64-setup.exe"},
    @{Url="$Repo/Duix.Avatar-1.0.6-lite-setup.exe"; Name="Duix.Avatar-1.0.6-lite-setup.exe"},
    @{Url="$Repo/shuziren_deploy_video.mp4"; Name="数字人部署视频.mp4"}
)

foreach ($f in $files) {
    $dst = Join-Path $DesktopDir $f.Name
    if (Test-Path $dst) {
        Log "已存在: $($f.Name)"
    } else {
        Log "下载: $($f.Name)..."
        try {
            Invoke-WebRequest -Uri $f.Url -OutFile $dst -UseBasicParsing
            Log "下载完成: $($f.Name)"
        } catch {
            Log "警告: 下载失败 $($f.Name), 请手动下载"
        }
    }
}

# === Step 5: 安装 Voicebox ===
$VoiceboxExe = Join-Path $DesktopDir "Voicebox_0.4.5_x64-setup.exe"
if (Test-Path $VoiceboxExe) {
    Log "安装 Voicebox..."
    Start-Process -FilePath $VoiceboxExe -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
    Log "Voicebox 安装完成"
}

# === Step 6: 启用 Hyper-V + WSL2 ===
Log "启用 Hyper-V 和 WSL2..."
$needReboot = $false
try {
    $hv = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All
    if ($hv.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V-All -NoRestart
        $needReboot = $true
        Log "Hyper-V 已启用（需重启）"
    }
} catch { Log "Hyper-V 可能已启用" }

try {
    $wsl = Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
    if ($wsl.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux -NoRestart
        $needReboot = $true
        Log "WSL 已启用（需重启）"
    }
} catch { Log "WSL 可能已启用" }

try {
    $vmp = Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform
    if ($vmp.State -ne "Enabled") {
        Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform -NoRestart
        $needReboot = $true
        Log "虚拟机平台已启用（需重启）"
    }
} catch { Log "虚拟机平台可能已启用" }

# === Step 7: 安装 Docker Desktop ===
$DockerExe = Join-Path $DesktopDir "DockerDesktopInstaller.exe"
if (Test-Path $DockerExe) {
    Log "安装 Docker Desktop..."
    Start-Process -FilePath $DockerExe -ArgumentList "install","--quiet","--accept-license" -Wait
    Log "Docker Desktop 安装完成"
}

# === Step 8: 启动 Docker 等初始化 ===
Log "启动 Docker Desktop..."
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
Log "等待 Docker 初始化（最多5分钟）..."
$ready = $false
for ($i = 0; $i -lt 300; $i++) {
    Start-Sleep 1
    try {
        $null = & docker info 2>&1
        if ($LASTEXITCODE -eq 0) { $ready = $true; break }
    } catch {}
}
if ($ready) { Log "Docker 已就绪" } else { Log "警告: Docker 初始化超时，继续执行..." }

# === Step 9: 写入 daemon.json ===
Log "写入 Docker 镜像加速配置..."
$dockerDir = "$env:USERPROFILE\.docker"
New-Item -ItemType Directory -Force -Path $dockerDir | Out-Null

$daemonJson = @"
{
  "builder": {
    "gc": {
      "defaultKeepStorage": "20GB",
      "enabled": true
    }
  },
  "experimental": false,
  "registry-mirrors": [
    "https://docker.1ms.run",
    "https://docker.3panel.live",
    "https://dockerpull.org",
    "https://docker.m.daocloud.io"
  ]
}
"@

# 关Docker再写配置
Stop-Process -Name "Docker Desktop" -Force -ErrorAction SilentlyContinue
Start-Sleep 5
[IO.File]::WriteAllText("$dockerDir\daemon.json", $daemonJson, [System.Text.UTF8Encoding]::new($false))
Log "daemon.json 已写入"

# === Step 10: 注册Docker开机自启 ===
$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
Set-ItemProperty -Path $regPath -Name "Docker Desktop" -Value "C:\Program Files\Docker\Docker\Docker Desktop.exe" -ErrorAction SilentlyContinue
Log "Docker Desktop 开机自启已注册"

# === Step 11: 安装 Duix.Avatar 客户端 ===
$DuixExe = Join-Path $DesktopDir "Duix.Avatar-1.0.6-lite-setup.exe"
if (Test-Path $DuixExe) {
    Log "安装 Duix.Avatar 客户端..."
    Start-Process -FilePath $DuixExe -ArgumentList "/S" -Wait -ErrorAction SilentlyContinue
    Log "Duix.Avatar 客户端安装完成"
}

# === Step 12: 修改compose数据卷路径 ===
Log "修改compose文件数据卷路径为 ${InstallDrive}: 盘..."
$composeSrc = Join-Path $PSScriptRoot "..\deploy\$ComposeFile"
if (Test-Path $composeSrc) {
    $content = Get-Content $composeSrc -Raw -Encoding UTF8
    $content = $content -replace 'd:/duix_avatar_data', "${InstallDrive}:/duix_avatar_data"
    $composeDst = Join-Path $DesktopDir $ComposeFile
    [IO.File]::WriteAllText($composeDst, $content, [System.Text.UTF8Encoding]::new($false))
    Log "compose文件已修改并复制到桌面"
}

# === Step 13: 添加防火墙规则 ===
Log "添加防火墙规则..."
foreach ($port in @(18180, 10095, 8383)) {
    New-NetFirewallRule -DisplayName "Duix Avatar Port $port" -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow -ErrorAction SilentlyContinue | Out-Null
}
Log "防火墙规则已添加"

# === Step 14: 写入重启后执行脚本 ===
Log "生成重启后自动执行脚本..."
$afterRebootScript = @'
# after-reboot.ps1 - 重启后自动执行
$ErrorActionPreference = "Stop"
$LogFile = "$env:USERPROFILE\Desktop\数字人部署包\install.log"
function Log($msg) {
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$ts] $msg"
    Add-Content -Path $LogFile -Value "[$ts] $msg" -ErrorAction SilentlyContinue
}

Log "===== 重启后继续部署 ====="

# 等Docker启动
Log "等待 Docker Desktop 启动..."
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe"
for ($i = 0; $i -lt 300; $i++) {
    Start-Sleep 1
    try {
        $null = & docker info 2>&1
        if ($LASTEXITCODE -eq 0) { break }
    } catch {}
}
Log "Docker 已就绪"

# 验证加速源
Log "验证 Docker 镜像加速源..."
$mirrors = & docker info 2>&1 | Select-String "Registry Mirrors" -Context 0,5
Log "加速源状态: $mirrors"

# 逐个拉镜像（断点续传）
$images = @(
    "guiji2025/fish-speech-ziming",
    "guiji2025/fun-asr",
    "guiji2025/duix.avatar"
)
foreach ($img in $images) {
    Log "拉取镜像: $img (大镜像可能需要较长时间)..."
    & docker pull $img
    if ($LASTEXITCODE -eq 0) {
        Log "镜像完成: $img"
    } else {
        Log "警告: 镜像拉取失败 $img, 请手动重试: docker pull $img"
    }
}

# docker-compose up
$composeFile = $null
$desktopDir = "$env:USERPROFILE\Desktop\数字人部署包"
foreach ($cf in @("docker-compose-5090.yml","docker-compose.yml","docker-compose-lite.yml")) {
    $path = Join-Path $desktopDir $cf
    if (Test-Path $path) { $composeFile = $path; break }
}
if ($composeFile) {
    Log "启动 Duix 服务端..."
    Push-Location $desktopDir
    & docker-compose -f (Split-Path $composeFile -Leaf) up -d
    Pop-Location
    Log "Duix 服务端已启动"
} else {
    Log "错误: 找不到compose文件!"
}

# 自检
Log "===== 自检 ====="
$ok = $true

$dockerProc = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerProc) { Log "[OK] Docker Desktop 运行中" } else { Log "[FAIL] Docker Desktop 未运行"; $ok = $false }

foreach ($c in @('duix-avatar-tts','duix-avatar-asr','duix-avatar-gen-video')) {
    try {
        $status = & docker inspect -f '{{.State.Running}}' $c 2>&1
        if ($status -eq 'true') { Log "[OK] 容器 $c running" } else { Log "[FAIL] 容器 $c 未运行"; $ok = $false }
    } catch { Log "[FAIL] 容器 $c 检查失败"; $ok = $false }
}

foreach ($port in @(18180, 10095, 8383)) {
    try {
        $conn = New-Object System.Net.Sockets.TcpClient("localhost", $port)
        if ($conn.Connected) { Log "[OK] 端口 $port 可访问"; $conn.Close() }
    } catch { Log "[FAIL] 端口 $port 不可访问"; $ok = $false }
}

if ($ok) {
    Log "===== 部署完成! 所有检查通过 ====="
} else {
    Log "===== 部署完成，但有部分检查未通过，请查看上方日志 ====="
}

# 删除计划任务
Unregister-ScheduledTask -TaskName "DuixAfterReboot" -Confirm:$false -ErrorAction SilentlyContinue
Log "计划任务已清理"
'@

$afterRebootPath = "$DesktopDir\after-reboot.ps1"
[IO.File]::WriteAllText($afterRebootPath, $afterRebootScript, [System.Text.UTF8Encoding]::new($false))
Log "重启后脚本已生成"

# === Step 15: 注册计划任务 ===
Log "注册重启后自动执行的计划任务..."
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$afterRebootPath`""
$trigger = New-ScheduledTaskTrigger -AtLogOn -UserId $env:USERNAME
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest
Register-ScheduledTask -TaskName "DuixAfterReboot" -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
Log "计划任务已注册"

# === Step 16: 重启或直接执行 ===
if ($needReboot) {
    Log "需要重启，10秒后自动重启..."
    Log "重启后会自动继续拉取镜像和启动服务"
    Start-Sleep 10
    Restart-Computer -Force
} else {
    Log "无需重启，直接执行后续步骤..."
    & powershell -ExecutionPolicy Bypass -File $afterRebootPath
}
