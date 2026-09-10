#!/usr/bin/env bash
# speedtest-cdn — Linux / macOS 环境安装
#
# 作用:
#   1. 检测系统 Node.js (>= 18)；缺失或过旧时下载便携版到 ./node-runtime/
#   2. 创建 data/ reports/ 运行目录
#
# 项目无 npm 依赖（仅使用 Node 内置模块），无需 npm install。
#
# 用法:
#   ./install.sh             自动安装
#   ./install.sh --force     强制重新下载便携 Node

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

NODE_VERSION="v20.19.0"
FORCE="${1:-}"

echo "════════════════════════════════════════════════════════════"
echo "  speedtest-cdn — 环境安装"
echo "════════════════════════════════════════════════════════════"

# ── 检测系统 Node ──
check_system_node() {
    if command -v node >/dev/null 2>&1; then
        local major
        major="$(node -p "process.versions.node.split('.')[0]")"
        if [ "$major" -ge 18 ]; then
            echo "✅ 系统已安装 Node.js $(node -v)"
            return 0
        fi
        echo "⚠️  系统 Node.js 版本过低: $(node -v)"
    else
        echo "⚠️  未检测到系统 Node.js"
    fi
    return 1
}

if check_system_node && [ "$FORCE" != "--force" ]; then
    echo "   无需安装便携版 (如需强制重装: ./install.sh --force)"
else
    # ── 下载便携 Node ──
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    case "$OS" in
        Linux*)  PLATFORM="linux" ;;
        Darwin*) PLATFORM="darwin" ;;
        *) echo "❌ 不支持的系统: $OS (Windows 请运行 install.bat)"; exit 1 ;;
    esac

    case "$ARCH" in
        x86_64|amd64) ARCH_TAG="x64" ;;
        aarch64|arm64) ARCH_TAG="arm64" ;;
        armv7l) ARCH_TAG="armv7l" ;;
        *) echo "❌ 不支持的架构: $ARCH"; exit 1 ;;
    esac

    FILENAME="node-${NODE_VERSION}-${PLATFORM}-${ARCH_TAG}.tar.gz"
    URL="https://nodejs.org/dist/${NODE_VERSION}/${FILENAME}"

    # 国内镜像优先
    MIRROR_URL="https://npmmirror.com/mirrors/node/${NODE_VERSION}/${FILENAME}"

    echo ""
    echo "📦 下载便携版 Node.js ${NODE_VERSION} (${PLATFORM}-${ARCH_TAG})..."

    TMP_FILE="$(mktemp)"
    trap 'rm -f "$TMP_FILE"' EXIT

    if curl -fsSL --retry 2 --connect-timeout 15 "$MIRROR_URL" -o "$TMP_FILE" 2>/dev/null; then
        echo "   来源: npmmirror 镜像"
    elif curl -fsSL --retry 2 --connect-timeout 15 "$URL" -o "$TMP_FILE"; then
        echo "   来源: nodejs.org 官方"
    else
        echo "❌ 下载失败，请手动安装 Node.js 18+:"
        echo "   Ubuntu/Debian: curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
        echo "   macOS:         brew install node"
        exit 1
    fi

    echo "📂 解压到 ./node-runtime/ ..."
    rm -rf node-runtime node-runtime-tmp
    mkdir -p node-runtime-tmp
    tar -xzf "$TMP_FILE" -C node-runtime-tmp --strip-components=1
    mv node-runtime-tmp node-runtime

    echo "✅ 便携版已就绪: $(./node-runtime/bin/node -v)"
fi

# ── 运行目录 ──
mkdir -p data reports
echo "✅ 运行目录就绪: data/ reports/"

# ── 完成 ──
echo ""
echo "════════════════════════════════════════════════════════════"
echo "  ✅ 安装完成"
echo ""
echo "  运行全流程:  ./run.sh"
echo "  快速模式:    ./run.sh --quick"
echo "  仅检测:      ./run.sh --check-only"
echo "════════════════════════════════════════════════════════════"
