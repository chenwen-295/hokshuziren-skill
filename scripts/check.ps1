# check.ps1 - 数字人环境自检脚本

$ErrorActionPreference = "Continue"
Write-Host "===== 数字人环境自检 =====" -ForegroundColor Cyan

$ok = $true

# 1. GPU
Write-Host "`n--- GPU ---" -ForegroundColor Yellow
try {
    $gpu = & nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>&1
    Write-Host "[OK] GPU: $gpu"
} catch {
    Write-Host "[FAIL] 未检测到NVIDIA GPU"; $ok = $false
}

# 2. Docker Desktop
Write-Host "`n--- Docker Desktop ---" -ForegroundColor Yellow
$dockerProc = Get-Process "Docker Desktop" -ErrorAction SilentlyContinue
if ($dockerProc) {
    Write-Host "[OK] Docker Desktop 运行中"
} else {
    Write-Host "[FAIL] Docker Desktop 未运行"; $ok = $false
}

try {
    $info = & docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[OK] docker info 可执行"
        $mirrors = $info | Select-String "Registry Mirrors" -Context 0,5
        if ($mirrors) { Write-Host "[OK] 镜像加速源已配置" } else { Write-Host "[WARN] 未检测到镜像加速源" }
    } else {
        Write-Host "[FAIL] docker info 执行失败"; $ok = $false
    }
} catch {
    Write-Host "[FAIL] Docker CLI 不可用"; $ok = $false
}

# 3. 容器
Write-Host "`n--- Docker 容器 ---" -ForegroundColor Yellow
$containers = @(
    @{Name="duix-avatar-tts"; Port=18180; Desc="TTS(语音合成)"},
    @{Name="duix-avatar-asr"; Port=10095; Desc="ASR(语音识别)"},
    @{Name="duix-avatar-gen-video"; Port=8383; Desc="视频生成"}
)
foreach ($c in $containers) {
    try {
        $status = & docker inspect -f '{{.State.Running}}' $c.Name 2>&1
        if ($status -eq 'true') {
            Write-Host "[OK] $($c.Desc) ($($c.Name)) - running"
        } else {
            Write-Host "[FAIL] $($c.Desc) ($($c.Name)) - 未运行"; $ok = $false
        }
    } catch {
        Write-Host "[FAIL] $($c.Desc) ($($c.Name)) - 检查失败"; $ok = $false
    }
}

# 4. 端口
Write-Host "`n--- 端口 ---" -ForegroundColor Yellow
foreach ($c in $containers) {
    try {
        $conn = New-Object System.Net.Sockets.TcpClient("localhost", $c.Port)
        if ($conn.Connected) {
            Write-Host "[OK] 端口 $($c.Port) ($($c.Desc)) 可访问"
            $conn.Close()
        }
    } catch {
        Write-Host "[FAIL] 端口 $($c.Port) ($($c.Desc)) 不可访问"; $ok = $false
    }
}

# 5. 桌面应用
Write-Host "`n--- 桌面应用 ---" -ForegroundColor Yellow
$voicebox = Get-ChildItem "C:\Users\$env:USERNAME\AppData\Local\Programs\Voicebox" -ErrorAction SilentlyContinue
if ($voicebox) { Write-Host "[OK] Voicebox 已安装" } else { Write-Host "[WARN] Voicebox 未找到（可能安装路径不同）" }

$duix = Get-ChildItem "C:\Users\$env:USERNAME\AppData\Local\Programs\Duix.Avatar" -ErrorAction SilentlyContinue
if ($duix) { Write-Host "[OK] Duix.Avatar 客户端已安装" } else { Write-Host "[WARN] Duix.Avatar 客户端未找到" }

# 6. 防火墙
Write-Host "`n--- 防火墙 ---" -ForegroundColor Yellow
foreach ($port in @(18180, 10095, 8383)) {
    $rule = Get-NetFirewallRule -DisplayName "Duix Avatar Port $port" -ErrorAction SilentlyContinue
    if ($rule) { Write-Host "[OK] 端口 $port 防火墙规则已添加" } else { Write-Host "[WARN] 端口 $port 防火墙规则未找到" }
}

# 结果
Write-Host "`n===== 自检结果 =====" -ForegroundColor Cyan
if ($ok) {
    Write-Host "所有检查通过! 数字人环境就绪。" -ForegroundColor Green
} else {
    Write-Host "部分检查未通过，请查看上方详情。" -ForegroundColor Red
}
