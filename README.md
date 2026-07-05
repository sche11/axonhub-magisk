# AxonHub Magisk Module

> 在 Android 设备上运行完整的 [AxonHub](https://github.com/looplj/axonhub) LLM 网关服务，开机自启，Web 面板管理。

[![Magisk Module](https://img.shields.io/badge/Magisk-Module-blueviolet?style=flat-square)](https://github.com/topjohnwu/Magisk)
[![Platform](https://img.shields.io/badge/Platform-ARM64-orange?style=flat-square)](#系统要求)
[![Release](https://img.shields.io/github/v/release/sche11/axonhub-magisk?include_prereleases&style=flat-square)](https://github.com/sche11/axonhub-magisk/releases)
[![CI](https://img.shields.io/github/actions/workflow/status/sche11/axonhub-magisk/magisk-release.yml?branch=main&style=flat-square&label=CI)](https://github.com/sche11/axonhub-magisk/actions)

## 简介

本项目将 [AxonHub](https://github.com/looplj/axonhub)（开源 AI 网关，支持 100+ LLM、故障转移、负载均衡、成本控制）打包为 Magisk 模块，在已 root 的 Android 设备上以常驻服务运行。

**特性：**

- 🔌 **开机自启**：通过 `service.sh` 在系统启动后自动拉起服务
- 🌐 **Web 管理面板**：通过 `http://127.0.0.1:8090` 访问完整管理界面
- 🔄 **自动更新**：集成 `update.json`，Magisk Manager 可自动检测新版本
- 📱 **WebUI 集成**：在 Magisk Manager 模块列表中直接打开 Web 面板
- ⚡ **Action 按钮**：点击即重启服务，无需重启设备
- 🤖 **CI/CD 自动化**：监听上游 release，自动交叉编译并发布

## 系统要求

| 项目 | 要求 |
|------|------|
| Root 框架 | Magisk 24.0+ |
| CPU 架构 | ARM64 / aarch64（不支持 x86 / ARM32） |
| Android 版本 | 10+ |
| 存储空间 | ≥ 50 MB（二进制约 30 MB + 数据库/日志） |

## 安装

### 方式一：下载 Release（推荐）

1. 前往 [Releases 页面](https://github.com/sche11/axonhub-magisk/releases) 下载最新 `axonhub-vX.Y.Z-magisk.zip`
2. 打开 Magisk Manager → **模块** → **从存储安装**
3. 选择下载的 zip 文件
4. **重启设备**

### 方式二：Magisk Manager 自动更新

模块已配置 `update.json`，Magisk Manager 会在模块列表中显示更新提示，点击更新即可。

## 配置

| 项目 | 路径 |
|------|------|
| 配置文件 | `/data/adb/axonhub/config.yml` |
| 数据目录 | `/data/adb/axonhub/` |
| SQLite 数据库 | `/data/adb/axonhub/axonhub.db` |
| 日志文件 | `/data/adb/axonhub/logs/axonhub.log` |
| 默认监听 | `127.0.0.1:8090` |

### 默认配置

```yaml
server:
  host: "127.0.0.1"     # 仅本机访问，避免暴露到局域网
  port: 8090
  api:
    auth:
      allow_no_auth: true  # 首次使用无需 API Key，请在 WebUI 中配置
db:
  dialect: "sqlite3"
  dsn: "file:/data/adb/axonhub/axonhub.db?cache=shared&_fk=1&_pragma=journal_mode(WAL)"
```

> 如需从局域网访问，将 `host` 改为 `0.0.0.0`，并配置 API Key 鉴权。

## 使用

### 访问 Web 面板

- **方式 A**：浏览器访问 `http://127.0.0.1:8090`
- **方式 B**：Magisk Manager → 模块 → AxonHub → **WebUI** 按钮（自动重定向到管理界面）

### Action 按钮

在 Magisk Manager 模块列表中，点击 AxonHub 旁边的 ⚡ 按钮可重启服务（无需重启设备）。用于：
- 修改 `config.yml` 后生效
- 服务异常时恢复
- 升级二进制后重启

### 查看日志

```bash
adb shell tail -f /data/adb/axonhub/logs/axonhub.log
```

## 从源码构建

### 前置依赖

- **Go** 1.24+
- **Android NDK** r27c（含 `aarch64-linux-android-clang`）
- **zip**、**xxd**、**du** 命令（Linux/macOS 自带，Windows 需 WSL 或 Git Bash）

### 本地构建

```bash
# 克隆本仓库
git clone https://github.com/sche11/axonhub-magisk.git
cd axonhub-magisk

# 指定版本构建（会自动 clone 上游 axonhub 源码）
./build-module.sh v1.0.0-beta4 ./artifacts

# 如果本地已有 axonhub 源码（与本项目同级目录），脚本会自动检测并复用
./build-module.sh v1.0.0-beta4 ./artifacts
```

构建产物：`artifacts/axonhub-vX.Y.Z-magisk.zip`

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `ANDROID_NDK_HOME` | — | NDK 安装路径（必需） |
| `UPSTREAM_REPO` | `looplj/axonhub` | 上游源码仓库 |
| `GO_VERSION` | `1.24` | Go 版本（仅 CI 使用） |

## CI/CD 自动化

本项目通过 GitHub Actions（[`.github/workflows/magisk-release.yml`](.github/workflows/magisk-release.yml)）实现全自动发布：

### 触发方式

1. **定时轮询**：每小时整点（UTC）检查上游 `looplj/axonhub` 最新 release
2. **手动触发**：Actions 页面 → "Magisk Module Release" → Run workflow（可指定版本号）

### 流水线阶段

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────────┐     ┌───────────┐
│  check-upstream │ ──▶ │   build-magisk    │ ──▶ │  publish-release  │ ──▶ │   notify  │
│                 │     │                  │     │                  │     │           │
│ • 查询上游 release│     │ • 设置 Go + NDK   │     │ • 创建 GitHub Release│   │ • 汇总状态  │
│ • 比对是否已构建  │     │ • 交叉编译 ARM64  │     │ • 上传 zip 资产     │     │ • 失败告警  │
│ • 获取 changelog │     │ • 打包 Magisk zip │     │ • 更新 update.json  │     │           │
└─────────────────┘     └──────────────────┘     └──────────────────┘     └───────────┘
```

### versionCode 计算规则

Magisk 模块的 `versionCode` 必须为整数，本项目采用以下公式保证预发布版 < 正式版：

| 版本格式 | 公式 | 示例 |
|----------|------|------|
| `X.Y.Z` | `X*10000 + Y*100 + Z` | `v1.0.0` → `10000` |
| `X.Y.Z-betaN` | `X*10000 + Y*100 + Z - N` | `v1.0.0-beta4` → `9996` |
| `X.Y.Z-rcN` | `X*10000 + Y*100 + Z - N` | `v1.0.0-rc2` → `9998` |

> 正式版 `versionCode` 总是大于同版本的预发布版，确保 Magisk Manager 正确识别升级方向。

### Release 命名

- **Tag**：`magisk-vX.Y.Z`（如 `magisk-v1.0.0-beta4`）
- **资产**：`axonhub-vX.Y.Z-magisk.zip`
- **Changelog**：自动复用上游 release notes，并追加模块安装说明

## 模块结构

```
axonhub-magisk/
├── .github/workflows/
│   └── magisk-release.yml     # CI/CD 流水线
├── config/
│   └── config.yml             # 默认 AxonHub 配置
├── webroot/
│   └── index.html             # Magisk WebUI 入口（重定向到 :8090）
├── .gitattributes             # 强制 LF 换行（shell 脚本兼容）
├── .gitignore
├── build-module.sh            # 构建脚本（交叉编译 + 打包）
├── customize.sh               # Magisk 安装脚本
├── service.sh                 # 开机自启脚本
├── action.sh                  # Action 按钮脚本（重启服务）
├── module.prop                # 模块元数据
├── update.json                # Magisk Manager 更新检查
└── README.md
```

### 安装后的设备目录

```
/data/adb/modules/axonhub/      # 模块安装目录
├── module.prop
├── customize.sh
├── service.sh
├── action.sh
├── webroot/index.html
├── bin/axonhub                 # ARM64 二进制
└── config/config.yml

/data/adb/axonhub/              # 数据持久化目录（跨模块更新保留）
├── config.yml                  # 用户配置（覆盖默认）
├── axonhub.db                  # SQLite 数据库
└── logs/                       # 日志文件
```

## 技术实现

### 交叉编译

使用 Go + Android NDK 进行 CGO 交叉编译（`modernc.org/sqlite` 需要 CGO）：

```bash
CGO_ENABLED=1 \
GOOS=android \
GOARCH=arm64 \
CC=$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/linux-x86_64/bin/aarch64-linux-android24-clang \
go build -trimpath -ldflags="-s -w" -o axonhub ./cmd/axonhub
```

- **NDK r27c**：支持 `android24`（Android 7.0+）以上的 libc
- **CGO_ENABLED=1**：`modernc.org/sqlite` 依赖 CGO
- **`-trimpath -ldflags="-s -w"`**：去除调试信息，减小二进制体积

### ELF 验证

构建后自动验证二进制 ELF magic（`7f454c46`），确保交叉编译产物格式正确。

### ZIP 打包

使用 Linux `zip` 命令打包，确保路径分隔符为正斜杠（Magisk 要求）。Windows 的 `Compress-Archive` 会使用反斜杠，导致 Magisk 无法识别。

## 致谢

- **[AxonHub](https://github.com/looplj/axonhub)** — 上游项目，由 [@looplj](https://github.com/looplj) 开发
- **[Magisk](https://github.com/topjohnwu/Magisk)** — Android Root 框架，由 [@topjohnwu](https://github.com/topjohnwu) 开发

## 许可证

本 Magisk 模块项目遵循上游 [AxonHub 许可证](https://github.com/looplj/axonhub/blob/main/LICENSE)。
