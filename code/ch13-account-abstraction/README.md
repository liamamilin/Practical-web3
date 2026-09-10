# ch13-account-abstraction — 第 13 章：ERC-4337 账户抽象实验

在本地链上发起一笔 **Paymaster 代付的 UserOperation**：
一个从未有过任何 ETH 的智能账户在第一次 UserOperation 中被创建，随后发出一笔调用——
**全程 gas 由 Paymaster 保证金支付，账户主人只用一把私钥签了一次名。**

技术锚定（2026-09）：ERC-4337 v0.8（EntryPoint / SimpleAccountFactory 编译自官方
`@account-abstraction/contracts@0.8.0` 源码）+ viem。

## 验证状态

- 两个脚本在本书写作环境的本地 EVM 节点（等价 Anvil：chainId 31337、同一套测试账户）
  **实际跑通全流程**，输出见下。
- 写作环境没有 Anvil 二进制（Foundry 下载受限），因此 `anvil` 本身未实测；
  两者均为标准 JSON-RPC + EVM 等价实现，参数按 Anvil 默认值书写（base fee 1 gwei）。
  若遇 gas 价格类报错，调大 `gasFees` 中的 maxFeePerGas 即可。

实测输出（节选）：

```text
① 智能账户（将被创建于）: 0xBfe63953f21632D74cdfe167d35D4B389270f03e
② UserOperation 组装完成（sender 余额： 0 ETH）
③ userOpHash: 0x0c360521… （owner 已签名）
⑤ handleOps 已上链: block 4 status success
⑥ 执行结果：
   UserOperation 成功: true
   sender 余额: 0 ETH（从未注资，应保持 0）
   Paymaster 保证金: -0.000506730… ETH（代付了全部 gas）
   Bundler/受益人净变化: +0.000102551… ETH（收到 gas 奖励，扣除自身交易 gas 后的净值）
✅ 代付 UserOperation 全流程通过
```

## 步骤

```bash
# 0. 启动本地链（另开终端）
anvil

# 1. 安装依赖（EntryPoint/工厂源码来自官方 npm 包，编译在脚本内完成）
npm install

# 2. 部署三件套：EntryPoint + SimpleAccountFactory + 教学版 SponsorPaymaster
node scripts/deploy.mjs

# 3. 发起代付 UserOperation
node scripts/send-uop.mjs
```

## 文件说明

| 路径 | 作用 |
|---|---|
| `contracts/src/SponsorPaymaster.sol` | 教学版"无条件代付"Paymaster：`validatePaymasterUserOp` 永远放行、空 `postOp`。生产版必须加配额/风控/签名校验 |
| `scripts/lib/compile.mjs` | 用 solc-js 从官方 npm 包源码就地编译（零 Foundry 依赖） |
| `scripts/deploy.mjs` | 部署 EntryPoint + SimpleAccountFactory + Paymaster（随部署存入 0.1 ETH 保证金） |
| `scripts/send-uop.mjs` | 组装 → 签名 → 以"脚本扮演的 Bundler"提交 `handleOps` → 验证代付效果 |

## 实验脚本里值得盯住的四个点

1. **sender 地址先于账户存在**：`factory.getAddress(owner, salt)` 用 CREATE2 算出地址，
   `initCode = factory + createAccount(owner, salt)` 让 EntryPoint 在首次 UserOp 里把它创建出来。
2. **UserOperation 的两个打包字段**：`accountGasLimits` 与 `gasFees` 各是两个 uint128 的拼接；
   `paymasterAndData` 在 **v0.8 改过布局**（gas limit 紧跟地址，validUntil/validAfter 已移除）——
   本章实验曾因沿用 v0.7 布局拿到 `AA31` 报错，脚本注释里有说明。
3. **签名对象是 userOpHash**（EntryPoint 合约上的 `getUserOpHash` 视图调用结果），
   不是交易哈希——同一把 owner 私钥，签的完全是另一种东西。
4. **本实验没有独立 Bundler 进程**：由脚本持 Anvil 第 0 号账户直接调用 `entryPoint.handleOps`，
   这正是 Bundler 的协议角色；真实 Bundler 额外做 mempool 与 Gas 报价优化。

**警示**：脚本中的所有私钥都是 Anvil 公开测试助记词派生的，只属于本地链，永远不要在真实网络使用。
