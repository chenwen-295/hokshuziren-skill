# 数字人部署 Skill (hokshuziren-skill)

一键部署完整数字人环境：Duix.Avatar + Voicebox + Docker Desktop

## 触发词

数字人部署、数字人安装、hokshuziren、duix部署、digital human

## 前置要求

- Windows 11（需管理员权限）
- NVIDIA GPU >= 8GB VRAM
- 可用磁盘空间 >= 85GB（D盘优先，无D盘则E盘）
- 网络连接

## 部署内容

| 组件 | 说明 | 运行方式 |
|------|------|---------|
| Voicebox | 语音克隆工作室 | 桌面应用（独立，不依赖Docker） |
| Duix.Avatar 客户端 | 数字人操控界面 | 桌面应用 |
| Duix.Avatar 服务端 | TTS + ASR + 视频生成 | Docker容器（3个镜像） |
| Docker Desktop | 容器运行环境 | 桌面服务 |
| daemon.json | Docker镜像加速配置 | 配置文件 |

## 安装流程

1. 检测管理员权限（不是则自动提权）
2. GPU检测 + NVIDIA驱动版本检查 -> 自动选择compose文件
3. 磁盘检测（D盘优先，没有则E盘，需85GB+可用）
4. 下载安装包到桌面 数字人部署包 文件夹（失败可手动安装）
5. 安装 Voicebox（静默，独立应用，装完即可用）
6. 启用 Hyper-V + WSL2 + 虚拟机平台（需重启）
7. 安装 Docker Desktop（静默）
8. 等待 Docker 初始化完成
9. 写入 daemon.json（国内镜像加速源）+ 重启 Docker
10. 注册 Docker Desktop 开机自启
11. 安装 Duix.Avatar 客户端（静默）
12. 修改 compose 文件数据卷路径（适配D/E盘）
13. 添加防火墙规则（端口 18180/10095/8383）
14. 注册计划任务：重启后自动拉镜像+启动服务
15. 重启电脑（一次性）
16. [自动] 等 Docker Desktop 启动完成
17. [自动] 逐个拉取3个Docker镜像（断点续传）
18. [自动] docker-compose up -d 启动服务端
19. [自动] 自检
20. 输出状态报告

## Docker 镜像

| 服务 | 镜像 | 端口 |
|------|------|------|
| TTS (语音合成) | guiji2025/fish-speech-ziming | 18180 |
| ASR (语音识别) | guiji2025/fun-asr | 10095 |
| 视频生成 | guiji2025/duix.avatar | 8383 |

## 安装路径

| 组件 | 路径 |
|------|------|
| Docker Desktop | C:\\Program Files\\Docker\\（固定） |
| Docker 数据 | D:\\DockerData\\ 或 E:\\DockerData\\ |
| Voicebox | D:\\Voicebox\\ 或 E:\\Voicebox\\ |
| Duix.Avatar 客户端 | D:\\DuixAvatar\\ 或 E:\\DuixAvatar\\ |
| Duix 数据卷 | D:\\duix_avatar_data\\ 或 E:\\duix_avatar_data\\ |
| 桌面安装包 | Desktop\\数字人部署包\\ |

## 故障恢复

如果自动化失败，所有安装包已下载到桌面 数字人部署包 文件夹，可手动安装：
1. 双击 DockerDesktopInstaller.exe 安装 Docker
2. 双击 Voicebox_0.4.5_x64-setup.exe 安装 Voicebox
3. 双击 Duix.Avatar-1.0.6-lite-setup.exe 安装 Duix 客户端
4. 参考 数字人部署视频.mp4 手动配置
5. 在 deploy 目录下运行 docker-compose up -d

## 来源

- Duix.Avatar: https://github.com/duixcom/duix.avatar
- Voicebox: https://github.com/jamiepine/voicebox (MIT license)
- Docker Desktop: https://www.docker.com/products/docker-desktop

## 龙虾（其他 OpenClaw）使用方法

### 方式一：自动安装（推荐）
在 OpenClaw 中执行：
`
openclaw skill install https://github.com/chenwen-295/hokshuziren-skill
`
然后对龙虾说「数字人部署」即可触发。

### 方式二：手动安装
1. 克隆仓库到 skills 目录：
`powershell
cd ~/.openclaw-autoclaw/skills
git clone https://github.com/chenwen-295/hokshuziren-skill.git
`
2. 重启 OpenClaw Gateway
3. 对龙虾说「数字人部署」

### 执行流程
龙虾读取 SKILL.md 后，以管理员身份运行 scripts/install.ps1，脚本会：
1. 自动从 GitHub Release v1.0 下载3个安装包+部署视频到桌面
2. 检测 GPU/磁盘/驱动
3. 全自动安装 + 配置 + 重启
4. 重启后自动拉 Docker 镜像 + 启动服务
5. 自检输出状态报告