# ch15-anchor — 第 15 章配套代码

一个最小的 Solana（Anchor 框架）计数器程序，配套《Web3 基石》第 15 章实验。

**验证状态：已在本地实机全流程验证（2026-09，macOS）：anchor build（SBF 编译）成功；测试套件 3/3 通过（含权限拒绝用例）；solana-test-validator 部署成功；独立 TypeScript 客户端完成 空投→初始化(PDA)→递增×3→链上读回 count=3。版本：Anchor CLI 1.2.0 / anchor-lang 1.2.0 / @coral-xyz/anchor 0.32.1（注意 JS 包版本号与 CLI 不同步）/ platform-tools v1.57。运行中曾修复：init 缺 seeds 导致计数器并非 PDA（正文与代码均已修正）；新版客户端类型要求显式传参（accountsStrict）。**

## 目录结构

```
ch15-anchor/
├── Anchor.toml              # Anchor 配置：程序 ID、集群、测试脚本
├── Cargo.toml               # Rust workspace
├── package.json             # TypeScript 依赖与脚本（test / client）
├── tsconfig.json
├── programs/ch15-anchor/
│   ├── Cargo.toml           # 程序 crate
│   └── src/lib.rs           # 程序代码（计数器：initialize + increment）
├── tests/ch15-anchor.ts     # mocha 测试（初始化 / 递增 / 权限拒绝）
└── client/index.ts          # 独立 TS 客户端（自建 keypair，前端调用的最小原型）
```

## 环境准备（详见第 15 章正文）

1. Rust：`curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
2. Solana CLI：`sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"`
3. Anchor：`cargo install --git https://github.com/coral-xyz/anchor avm --locked --force && avm install latest && avm use latest`
4. yarn：`npm install -g yarn`
5. 本地钱包：`solana-keygen new`，然后 `solana config set --url localhost`

## 运行步骤

```bash
yarn install

# 1. 构建程序
anchor build

# 2. 把自己的程序 ID 写进 declare_id!（重要，漏掉会部署报错）
anchor keys list
#   ch15_anchor: <你的程序ID>
# → 编辑 programs/ch15-anchor/src/lib.rs 的 declare_id!
#   以及 Anchor.toml 的 [programs.localnet] 一行 → 重新 anchor build

# 3. 测试（自动启动/关闭本地 validator）
anchor test
# 预期：3 passing（initialize / increment twice / rejects unauthorized）

# 4. 手动部署（可选，体会 anchor test 背后的流程）
solana-test-validator --reset      # 终端 1
anchor deploy                      # 终端 2
solana program show <你的程序ID>

# 5. 独立客户端（需要 validator 在跑）
yarn client
```

## 程序要点（对照第 15 章正文）

- **程序无状态**：`#[program]` 模块内无任何全局变量，状态在 `Counter` 中
- **账户即容器**：`#[account]` 类型序列化进数据账户的 data
- **PDA**：种子 `[b"counter", user_pubkey]`，每个用户一个独立账户
- **权限**：`Signer` + `has_one = authority` 声明式校验
- **算术**：`checked_add` 防溢出回绕

## 常见问题

- **部署报 "program id mismatch"**：`declare_id!` / `Anchor.toml` / 实际部署 key 未同步（见上第 2 步）。
- **anchor test 卡在启动 validator**：确认 8899 端口未被占用；`test-ledger/` 目录可删除重试。
- **Anchor 版本差异**：本项目基于 0.30.x 布局（`InitSpace` 等）。更新版本若脚手架不同，以 `anchor init` 实际生成内容为准，迁移 lib.rs 与测试逻辑即可。
