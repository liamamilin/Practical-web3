# code/ch09-env — 第 9 章实验脚手架（Foundry）

> **验证状态**：已在 Foundry 1.8.1 / Solc 0.8.30 下实机验证通过（forge test 4/4 PASS）。
> 版本锚定 2026-09；运行时以 `forge --version` 实际输出为准。

## 内容

- `src/Counter.sol` — 模板计数器合约（含一个总是 revert 的示例函数，用于演示 `expectRevert`）
- `test/Counter.t.sol` — 单元测试 + fuzz 测试 + revert 断言测试
- `foundry.toml` — 项目配置（锁定 solc 版本 0.8.30，可按需修改）
- `setup.sh` — 一键脚本：安装 Foundry（如缺失）→ 安装 forge-std → 编译 → 测试

## 快速开始

```bash
bash setup.sh
```

或手动执行：

```bash
# 1. 安装 Foundry（如已安装可跳过）
curl -L https://foundry.paradigm.xyz | bash
foundryup

# 2. 安装测试库并编译测试
forge install foundry-rs/forge-std --no-commit
forge build
forge test          # 预期：4 个测试全部 [PASS]，其中 fuzz 测试 runs: 256

# 3. 另开终端启动本地链
anvil               # 预期：Listening on 127.0.0.1:8545, Chain ID: 31337

# 4. 部署（私钥为 anvil 预置的公开测试钥匙，切勿用于真实资产）
forge create src/Counter.sol:Counter \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# 5. 调用与验证
cast call <合约地址> "number()(uint256)"   # 预期：0
cast send <合约地址> "increment()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
cast call <合约地址> "number()(uint256)"   # 预期：1
```

## 安全提醒

- anvil 预置账户与私钥是**全网公开**的测试钥匙，只用于本地链。
- 真实私钥永远不出现在命令行参数、环境变量或代码仓库中。
