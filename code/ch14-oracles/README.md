# ch14-oracles — 第 14 章：本地 mock 预言机读喂价实验

喂价的生命周期：**写入（模拟预言机报告）→ 读取（消费合约换算）→ 更新（新一轮）→ 过期（新鲜度守卫拒绝）**。

## 验证状态

- `scripts/drive.mjs`（编译 → 部署 → 读价 → 改价 → 时间快进 → 过期拒绝）在本书写作环境的
  本地 EVM 节点（等价 Anvil：chainId 31337）**实际跑通**，输出：

  ```text
  初始喂价: 2000
  带新鲜度守卫的读法: 2000
  1 个代币按喂价折算: 2000
  改价后读数: 2100
  ✅ 过期喂价被拒绝（StalePrice）
  ```

- `test/MockPriceFeed.t.sol`（forge 测试，含 `vm.warp` 写法）为标准 Foundry 写法；
  已在 Foundry 1.8.1 下实机复跑：forge test 6/6 PASS。

## 步骤

```bash
anvil            # 终端 1：启动本地链
npm install
node scripts/drive.mjs
# 可选：forge test（需要 Foundry；forge 会重新编译到 out/，与 drive.mjs 的内置编译互不干扰）
```

## 文件说明

| 路径 | 作用 |
|---|---|
| `src/MockPriceFeed.sol` | 教学版预言机：实现主流喂价接口（AggregatorV3 形状），价格由部署者手工设定。演示"喂价的形态"，不代表真实预言机网络的信任机制 |
| `src/PriceConsumer.sol` | 消费侧标准姿势：不设防读法 / 新鲜度守卫读法 / decimals 换算 |
| `test/MockPriceFeed.t.sol` | forge 测试：读价、轮次递增、`vm.warp` 过期拒绝、换算正确性 |
| `scripts/drive.mjs` | 交易视角全流程（内置 solc 编译，零 Foundry 依赖） |
| `scripts/lib/compile.mjs` | 极简 solc-js 编译工具 |

## 阅读要点

1. MockPriceFeed 与真实预言机的**接口完全相同**——差别只在"answer 从哪来"（本章正文）。
2. `latestRoundData()` 的 `updatedAt` 字段是新鲜度守卫的原料；不设防的读法在生产代码中不可接受。
3. decimals 换算（喂价 8 位 vs 链上金额 18 位）是喂价消费中最高频的出错点，`valueOf()` 给出标准写法。
