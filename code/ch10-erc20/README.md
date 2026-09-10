# ch10-erc20 —— 从零手写的 ERC-20

本书第 10 章配套代码。不依赖 OpenZeppelin，只依赖 Forge 标准库（仅测试用）。

> **验证状态**：已在 Foundry 1.8.1 / Solc 0.8.30 下实机验证通过（forge test 全部 PASS）。

## 文件结构

```text
ch10-erc20/
├── foundry.toml          # Foundry 配置
├── src/
│   ├── IERC20.sol        # EIP-20 标准接口（与原文一一对应）
│   └── MyToken.sol       # 手写实现：每个函数的存在理由见第 10 章
└── test/
    └── MyToken.t.sol     # 单元测试 + 2 个模糊测试（fuzz）
```

## 运行步骤

```bash
# 1. 初始化（或复用第 9 章的 forge init 流程）
forge init ch10-erc20 && cd ch10-erc20
forge install foundry-rs/forge-std

# 2. 用本目录的 src/、test/、foundry.toml 替换生成物

# 3. 编译与测试
forge build
forge test -vvv
```

## 预期结果

- `forge build` 零警告零错误。
- `forge test` 全部 PASS：单元测试 9 个 + 模糊测试 2 个（fuzz 测试每次随机跑约 256 组输入）。
- 部署到 Anvil 并用 cast 调用的命令序列见本书第 10 章"动手实验"一节。

## 设计取舍说明（与第 10 章正文对应）

- **不做 unchecked 优化**：教学优先，保留 0.8 编译器的算术检查；生产实现（如 OpenZeppelin）在手动检查后用 `unchecked` 省 gas。
- **无限授权不扣减**：`type(uint256).max` 的 allowance 视为无限，这是社区约定，用于缓解 approve 竞态（见第 10 章 approve 争议一节）。
- **构造函数铸造、无后续 mint 权限**：刻意收窄权限面，呼应第 4 章 Rug Pull 检查清单。
