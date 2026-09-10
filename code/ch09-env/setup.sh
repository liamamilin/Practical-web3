#!/usr/bin/env bash
# ch09 环境一键脚本：安装 Foundry（如缺失）→ 安装依赖 → 编译 → 测试
# 注意：作者本机截至写作时未安装 Foundry，本脚本未验证；实际输出以运行结果为准。
set -euo pipefail
cd "$(dirname "$0")"

if ! command -v forge >/dev/null 2>&1; then
  echo "[1/4] 未检测到 Foundry，开始安装（foundryup）"
  curl -L https://foundry.paradigm.xyz | bash
  foundryup
else
  echo "[1/4] Foundry 已安装：$(forge --version)"
fi

echo "[2/4] 检查工具版本"
forge --version
cast --version
anvil --version

if [ ! -d lib/forge-std ]; then
  echo "[3/4] 安装测试依赖 forge-std"
  forge install foundry-rs/forge-std --no-commit
else
  echo "[3/4] forge-std 已就绪"
fi

echo "[4/4] 编译并运行测试"
forge build
forge test -vvv
