# ch16-move — 第 16 章配套代码

Sui 上最小的 Move 模块，用于感受资源（resource）语义。配套《Web3 基石》第 16 章实验。

**验证状态：已在 Sui CLI 1.79.0（Homebrew）下实机验证——`sui move build` 构建成功；`sui move test` 3/3 通过（含 expected_failure 的超额取出用例）；"复制资产被编译器拒绝"实验实测复现（错误码 EC05001）。framework 依赖通过 git rev 自动拉取并缓存；升级 Sui 版本后如报兼容性错误，按官方文档更新 `Move.toml` 中的 rev。**

## 目录结构

```
ch16-move/
├── Move.toml                # 包清单：依赖 Sui framework，包地址 0x0（发布时分配）
├── sources/
│   └── vault.move           # Vault 模块：create / deposit / withdraw / balance
└── tests/
    └── vault_tests.move     # 3 个测试：存入 / 取出 / 超额取出中止
```

## 运行步骤

```bash
# 1. 安装 Sui CLI（三选一）
brew install sui
# 或从 GitHub Releases 下载二进制
# 或 cargo install --locked --git https://github.com/MystenLabs/sui.git sui

sui --version
# 验证版本：sui 1.79.0-homebrew

# 2. 初始化本地环境
sui client new-address ed25519
sui start                 # 终端 1：启动本地节点

# 3. 建包（也可直接使用本目录）
sui move new ch16_move
# 把本目录的 sources/ 与 tests/ 内容放进生成的项目

# 4. 构建
sui move build
# 预期：构建成功（无 error；linter 可能提示风格建议，可忽略）

# 5. 【关键实验】在 deposit 里加一行试图复制 Vault：
#      let stolen = *vault;
#    再 build，实测报错（Sui 1.79.0）：
#      error[EC05001]: ability constraint not satisfied
#      Invalid dereference. Dereference requires the 'copy' ability
#      The type 'ch16_move::vault::Vault' does not have the ability 'copy'
#    ——这就是资源语义：复制资产无法通过编译。改完删掉这行。

# 6. 测试
sui move test
# 实测：Test result: OK. Total tests: 3; passed: 3; failed: 0

# 7.（可选）发布到本地网络
sui client publish --gas-budget 100000000 .
```

## 模块要点（对照第 16 章正文）

- `public struct Vault has key, store`：能作为链上顶层对象、能被转移；**没有 `copy`**（不可复制）、**没有 `drop`**（不可隐式销毁）
- `object::new(ctx)`：每个 Vault 有全局唯一 UID（对象 ID）
- `transfer::public_transfer(vault, owner)`：资产的"转移"是显式动作
- 测试里 `destroy_for_test` 必须显式解构销毁 —— 连"扔掉"都要明写
- 错误码 + `assert!`：Move 的运行时校验写法（对应 Solidity 的 `require`）
- 测试环境用 `tx_context::new_from_hint(...)` 构造 `TxContext`（现代 Sui 测试 API）
