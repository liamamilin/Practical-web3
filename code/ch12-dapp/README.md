# ch12-dapp — 第 12 章：DApp 全栈实验

为第 10 章手写的 ERC-20（`code/ch10-erc20/`）做一个完整前端：连接钱包 → 查余额 → 转账 → 看事件。

技术栈（2026-09 锚定）：Vite + React + **wagmi v3 + viem v2**。

## 验证状态

- 前端：`npm install && npm run build` 已在本书写作环境（node 22）实际执行通过。
- 合约链路：`scripts/deploy.mjs`（读 Foundry 格式产物 → viem 部署 → 给演示账户转
  1000 C10 → 余额与 Transfer 事件读取）已在写作环境的本地 EVM 节点（等价 Anvil：
  chainId 31337、同一套测试账户）**实测跑通**；写作环境没有 Foundry 二进制，
  `forge build` 本身未运行（编译产物由等价编译器按 forge 产物格式生成）。
- 浏览器手工步骤（MetaMask 添加本地网络、导入私钥、页面交互）：**未验证**——
  步骤按 MetaMask 官方文档书写，无需额外依赖。

## 步骤

```bash
# 1. 启动本地链（第 3 章已用过）
anvil

# 2. 编译第 10 章的 ERC-20（本目录 contracts/ 跨目录引用它，单一事实来源）
cd code/ch10-erc20 && forge build
cd code/ch12-dapp/contracts && forge build

# 3. 部署 + 给演示账户发初始持仓（需要 anvil 在跑）
cd code/ch12-dapp
npm install
node scripts/deploy.mjs        # 地址写入 src/deployed.json

# 4. 起前端
npm run dev                    # http://localhost:5173

# 5. 浏览器钱包准备（一次性）
#   - 添加网络：Anvil，RPC http://127.0.0.1:8545，链 ID 31337
#   - 导入账户私钥（Anvil 默认助记词 #1）：
#     59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
#     （deploy.mjs 已给该账户转了 1000 C10；它也是 anvil 预置账户，自带 ETH 付 gas）
```

收款地址可用 Anvil 账户 #2：`0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`。
**Anvil 重启 = 世界重来**：重启后必须重新编译并部署，否则前端拿着旧地址会对空合约发请求。

## 文件说明

| 路径 | 作用 |
|---|---|
| `contracts/foundry.toml` + `contracts/src/MyToken.sol` | 跨目录复用第 10 章 MyToken，单一事实来源 |
| `scripts/deploy.mjs` | 用 viem 读 Foundry 产物并部署（注意补 `0x` 前缀的坑），转 1000 C10 给演示账户 |
| `src/config.js` | wagmi 配置：链 + transport + 连接器 |
| `src/token.js` | 前端用到的 ABI 子集 + 部署地址 |
| `src/components/ConnectWallet.jsx` | 连接/断开钱包（EIP-1193 握手） |
| `src/components/TokenCard.jsx` | 读路径：批量读取元数据与余额，随区块高度自动刷新 |
| `src/components/TransferForm.jsx` | 写路径：签名 → 广播 → 等确认的两拍状态机 |
| `src/components/RecentTransfers.jsx` | 事件：getLogs 扫历史（小范围）+ 实时订阅 |

**警示**：Anvil 默认助记词是全网公开的测试助记词，永远不要在真实网络使用。本书所有私钥仅限本地链。
