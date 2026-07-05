#!/usr/bin/env bash
# build-module.sh - 构建并打包 AxonHub Magisk 模块
#
# 功能：
#   1. 使用 NDK 交叉编译 axonhub 为 Android ARM64 二进制
#   2. 动态注入版本号到 module.prop（支持 beta/rc/alpha 预发布版本）
#   3. 打包为符合 Magisk 规范的 zip（正斜杠分隔符）
#
# 用法：
#   ./build-module.sh <version> [output_dir]
#
# 参数：
#   version     - 上游版本号，如 v0.9.38 或 v1.0.0-beta4（不带 magisk- 前缀）
#   output_dir  - 输出目录，默认为当前目录
#
# 环境变量：
#   ANDROID_NDK_HOME - NDK 根目录路径
#   GO_BUILD_TAGS    - Go 构建标签，默认为 nomsgpack
#   UPSTREAM_REPO    - 上游仓库（默认 looplj/axonhub），用于 clone 源码
#
# versionCode 规则：
#   X.Y.Z         → X*10000 + Y*100 + Z           (v1.0.0 → 10000)
#   X.Y.Z-betaN   → X*10000 + Y*100 + Z - N       (v1.0.0-beta4 → 9996)
#   X.Y.Z-rcN     → X*10000 + Y*100 + Z - N       (v1.0.0-rc1 → 9999)
#   X.Y.Z-alphaN  → X*10000 + Y*100 + Z - N       (v1.0.0-alpha2 → 9998)
#
# 示例：
#   ./build-module.sh v0.9.38
#   ./build-module.sh v1.0.0-beta4 /tmp/output
set -euo pipefail

# ========== 参数校验 ==========
VERSION="${1:-}"
OUTPUT_DIR="${2:-.}"

if [[ -z "$VERSION" ]]; then
    echo "ERROR: 缺少 version 参数" >&2
    echo "用法: $0 <version> [output_dir]" >&2
    echo "示例: $0 v0.9.38" >&2
    echo "      $0 v1.0.0-beta4" >&2
    exit 1
fi

# 去掉可能的 magisk- 前缀
VERSION="${VERSION#magisk-}"

# ========== versionCode 计算（支持预发布版本）==========
# 解析主版本号 X.Y.Z 和预发布标识 -betaN/-rcN/-alphaN
if [[ "$VERSION" =~ ^v?([0-9]+)\.([0-9]+)\.([0-9]+)(-(beta|rc|alpha)([0-9]+))?$ ]]; then
    MAJOR="${BASH_REMATCH[1]}"
    MINOR="${BASH_REMATCH[2]}"
    PATCH="${BASH_REMATCH[3]}"
    PRE_TYPE="${BASH_REMATCH[5]:-}"
    PRE_NUM="${BASH_REMATCH[6]:-0}"

    BASE_CODE=$((MAJOR * 10000 + MINOR * 100 + PATCH))
    if [[ -n "$PRE_TYPE" ]]; then
        # 预发布版本：从基础版本号减去预发布序号
        # v1.0.0-beta4 → 10000 - 4 = 9996
        # v1.0.0-rc1   → 10000 - 1 = 9999
        # v1.0.0       → 10000 (正式版总是大于预发布版)
        VERSION_CODE=$((BASE_CODE - PRE_NUM))
    else
        VERSION_CODE="$BASE_CODE"
    fi
else
    echo "ERROR: 无法解析版本号 '$VERSION'" >&2
    echo "支持的格式: v0.9.38, v1.0.0, v1.0.0-beta4, v1.0.0-rc1, v1.0.0-alpha2" >&2
    exit 1
fi

echo "=========================================="
echo " 构建 AxonHub Magisk 模块"
echo " 版本: $VERSION"
echo " versionCode: $VERSION_CODE"
echo "=========================================="

# ========== 路径定位 ==========
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$SCRIPT_DIR"
BUILD_DIR=$(mktemp -d)
trap 'rm -rf "$BUILD_DIR"' EXIT

UPSTREAM_REPO="${UPSTREAM_REPO:-looplj/axonhub}"

echo "[1/7] 路径信息:"
echo "  模块目录:   $MODULE_DIR"
echo "  上游仓库:   $UPSTREAM_REPO"
echo "  临时构建:   $BUILD_DIR"

# ========== NDK 检测 ==========
if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
    # 常见路径
    if [[ -d "/usr/local/lib/android/sdk/ndk" ]]; then
        # GitHub Actions ubuntu runner
        ANDROID_NDK_HOME=$(ls -d /usr/local/lib/android/sdk/ndk/*/ | head -n1)
        ANDROID_NDK_HOME="${ANDROID_NDK_HOME%/}"
    elif [[ -n "${ANDROID_HOME:-}" && -d "${ANDROID_HOME}/ndk" ]]; then
        ANDROID_NDK_HOME=$(ls -d "${ANDROID_HOME}/ndk/"*/ | head -n1)
        ANDROID_NDK_HOME="${ANDROID_NDK_HOME%/}"
    fi
fi

if [[ -z "${ANDROID_NDK_HOME:-}" ]] || [[ ! -d "$ANDROID_NDK_HOME" ]]; then
    echo "ERROR: ANDROID_NDK_HOME 未设置或路径不存在" >&2
    echo "请安装 NDK 或设置 ANDROID_NDK_HOME 环境变量" >&2
    exit 1
fi

# 检测平台并选择 prebuilt 目录
PLATFORM_OS=$(uname -s)
case "$PLATFORM_OS" in
    Linux*)  PREBUILT_DIR="linux-x86_64" ;;
    Darwin*) PREBUILT_DIR="darwin-x86_64" ;;
    MINGW*|MSYS*|CYGWIN*) PREBUILT_DIR="windows-x86_64" ;;
    *)       PREBUILT_DIR="linux-x86_64" ;;
esac

NDK_TOOLCHAIN="$ANDROID_NDK_HOME/toolchains/llvm/prebuilt/$PREBUILT_DIR/bin"
CC="$NDK_TOOLCHAIN/aarch64-linux-android29-clang"
if [[ "$PLATFORM_OS" == MINGW* || "$PLATFORM_OS" == MSYS* || "$PLATFORM_OS" == CYGWIN* ]]; then
    CC="${CC}.cmd"
fi

if [[ ! -f "$CC" ]]; then
    echo "ERROR: NDK clang 不存在: $CC" >&2
    echo "NDK 路径: $ANDROID_NDK_HOME" >&2
    exit 1
fi

echo ""
echo "[2/7] NDK 配置:"
echo "  ANDROID_NDK_HOME: $ANDROID_NDK_HOME"
echo "  CC: $CC"

# ========== 获取上游源码 ==========
echo ""
echo "[3/7] 获取上游源码 ($UPSTREAM_REPO @ $VERSION)..."

# 优先使用本地源码（如果存在 axonhub 源码目录），否则 clone 上游
LOCAL_SOURCE=""
for candidate in "$MODULE_DIR/../axonhub" "$MODULE_DIR/axonhub" "$MODULE_DIR/.." "$MODULE_DIR/../../cmd/axonhub"; do
    if [[ -f "$candidate/cmd/axonhub/main.go" ]] || [[ -f "$candidate/go.mod" ]]; then
        LOCAL_SOURCE="$candidate"
        break
    fi
done

if [[ -n "$LOCAL_SOURCE" ]]; then
    echo "  使用本地源码: $LOCAL_SOURCE"
    REPO_ROOT="$LOCAL_SOURCE"
else
    # Clone 上游仓库指定 tag
    REPO_ROOT="$BUILD_DIR/axonhub-src"
    echo "  Clone 上游仓库到: $REPO_ROOT"
    git clone --depth 1 --branch "$VERSION" "https://github.com/$UPSTREAM_REPO.git" "$REPO_ROOT"
fi

if [[ ! -f "$REPO_ROOT/cmd/axonhub/main.go" ]]; then
    echo "ERROR: 上游源码中找不到 cmd/axonhub/main.go" >&2
    echo "  检查路径: $REPO_ROOT/cmd/axonhub/main.go" >&2
    exit 1
fi

# ========== Go 交叉编译 ==========
GO_BUILD_TAGS="${GO_BUILD_TAGS:-nomsgpack}"
AXONHUB_BIN="$BUILD_DIR/axonhub"

echo ""
echo "[4/7] Go 交叉编译 ARM64 二进制..."
(
    cd "$REPO_ROOT"
    GOOS=android \
    GOARCH=arm64 \
    CGO_ENABLED=1 \
    CC="$CC" \
    go build -ldflags "-s -w" -tags="$GO_BUILD_TAGS" -o "$AXONHUB_BIN" ./cmd/axonhub
)

if [[ ! -f "$AXONHUB_BIN" ]]; then
    echo "ERROR: 编译失败，二进制未生成" >&2
    exit 1
fi

BIN_SIZE=$(du -h "$AXONHUB_BIN" | cut -f1)
echo "  编译完成: $AXONHUB_BIN ($BIN_SIZE)"

# 验证 ELF 格式
MAGIC_HEX=$(xxd -l 20 "$AXONHUB_BIN" | head -1)
if [[ ! "$MAGIC_HEX" =~ 7f45 4c46 ]]; then
    echo "ERROR: 二进制不是 ELF 格式" >&2
    echo "  magic: $MAGIC_HEX" >&2
    exit 1
fi
echo "  ELF 格式验证通过"

# ========== 准备模块文件 ==========
echo ""
echo "[5/7] 准备模块文件..."

# 复制目录结构
mkdir -p "$BUILD_DIR/module/bin"
mkdir -p "$BUILD_DIR/module/config"
mkdir -p "$BUILD_DIR/module/webroot"

# 复制二进制
cp "$AXONHUB_BIN" "$BUILD_DIR/module/bin/axonhub"
chmod 755 "$BUILD_DIR/module/bin/axonhub"

# 复制静态文件（从模块目录）
cp "$MODULE_DIR/customize.sh" "$BUILD_DIR/module/"
cp "$MODULE_DIR/service.sh" "$BUILD_DIR/module/"
cp "$MODULE_DIR/action.sh" "$BUILD_DIR/module/"
cp "$MODULE_DIR/config/config.yml" "$BUILD_DIR/module/config/"
cp "$MODULE_DIR/webroot/index.html" "$BUILD_DIR/module/webroot/"

# 动态生成 module.prop（注入版本号）
cat > "$BUILD_DIR/module/module.prop" <<EOF
id=axonhub
name=AxonHub
version=$VERSION
versionCode=$VERSION_CODE
author=sche11
description=AxonHub LLM Gateway - 在 Android 设备上运行完整的 axonhub 服务（含 Web 管理面板）。开机自启，通过 http://127.0.0.1:8090 访问。Action 按钮重启服务，WebUI 面板直达前端。
updateJson=https://raw.githubusercontent.com/sche11/axonhub-magisk/main/update.json
EOF

chmod 755 "$BUILD_DIR/module/customize.sh" \
          "$BUILD_DIR/module/service.sh" \
          "$BUILD_DIR/module/action.sh" \
          "$BUILD_DIR/module/bin/axonhub"

echo "  模块文件准备完成"
ls -la "$BUILD_DIR/module/"

# ========== 打包 zip ==========
ZIP_NAME="axonhub-${VERSION}-magisk.zip"
mkdir -p "$OUTPUT_DIR"
ZIP_PATH="$OUTPUT_DIR/$ZIP_NAME"

echo ""
echo "[6/7] 打包 zip: $ZIP_PATH"
(
    cd "$BUILD_DIR/module"
    # 使用 zip 命令打包，Linux 上自动使用正斜杠
    zip -r -9 "$ZIP_PATH" . \
        -x "*.DS_Store" "*/.DS_Store"
)

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "ERROR: zip 打包失败" >&2
    exit 1
fi

ZIP_SIZE=$(du -h "$ZIP_PATH" | cut -f1)
echo "  打包完成: $ZIP_PATH ($ZIP_SIZE)"

# 验证 zip 条目（确保正斜杠分隔符）
echo ""
echo "[7/7] 验证 zip 结构..."
unzip -l "$ZIP_PATH" | head -20

# 检查是否有反斜杠（应该没有）
if unzip -l "$ZIP_PATH" | grep -q '\\'; then
    echo "ERROR: zip 中存在反斜杠分隔符，将导致 Magisk 无法识别" >&2
    exit 1
fi

# 验证 module.prop 中的 versionCode 是数字
if ! unzip -p "$ZIP_PATH" module.prop | grep -q "^versionCode=[0-9]\+$"; then
    echo "ERROR: module.prop 中 versionCode 不是纯数字" >&2
    exit 1
fi
echo ""
echo "=========================================="
echo " 构建成功"
echo " 版本: $VERSION (versionCode=$VERSION_CODE)"
echo " 输出: $ZIP_PATH"
echo " 大小: $ZIP_SIZE"
echo "=========================================="

# 输出 JSON 元数据（供 CI 使用）
echo ""
echo "::set-output name=zip-path::$ZIP_PATH"
echo "::set-output name=zip-name::$ZIP_NAME"
echo "::set-output name=version::$VERSION"
echo "::set-output name=version-code::$VERSION_CODE"
