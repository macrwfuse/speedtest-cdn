#!/usr/bin/env bash
# speedtest-cdn — Linux / macOS 一键运行
#
# 用法:
#   ./run.sh                 完整流程
#   ./run.sh --quick         快速模式
#   ./run.sh --check-only    只检测不修改
#   ./run.sh --nodes cdn-360 仅验证指定节点

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# ── Node.js 检测（优先使用项目内置 node-runtime） ──
NODE_BIN=""
if [ -x "$SCRIPT_DIR/node-runtime/bin/node" ]; then
    NODE_BIN="$SCRIPT_DIR/node-runtime/bin/node"
elif command -v node >/dev/null 2>&1; then
    NODE_BIN="$(command -v node)"
fi

if [ -z "$NODE_BIN" ]; then
    echo "❌ 未检测到 Node.js (需要 18+)"
    echo ""
    echo "请先安装 Node.js，任选一种方式："
    echo "  1) 运行本项目安装脚本:  ./install.sh"
    echo "  2) Ubuntu/Debian:       curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash - && sudo apt-get install -y nodejs"
    echo "  3) macOS (Homebrew):    brew install node"
    echo "  4) 官方下载:            https://nodejs.org/"
    exit 1
fi

# 版本检查 (>= 18)
NODE_MAJOR="$("$NODE_BIN" -p "process.versions.node.split('.')[0]")"
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "❌ Node.js 版本过低: $("$NODE_BIN" -v) (需要 18+)"
    echo "   请运行 ./install.sh 或手动升级"
    exit 1
fi

echo "✅ Node.js $("$NODE_BIN" -v) ($NODE_BIN)"
echo ""

# ── 执行全流程 ──
exec "$NODE_BIN" scripts/pipeline.mjs "$@"
