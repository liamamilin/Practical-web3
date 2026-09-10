# ch11-playground —— 重入漏洞靶场（三合约 + 回归测试）

本书第 11 章配套代码：先攻击、再修复，用测试证明"同一攻击者、同一战术"在修复版面前失效。

> **验证状态**：已在 Foundry 1.8.1 / Solc 0.8.30 下实机验证通过（4/4 PASS）。

## 文件结构

```text
ch11-playground/
├── foundry.toml
├── src/
│   ├── IBank.sol                  # 靶场"银行"最小接口（攻击者不关心对面是谁）
│   ├── ReentrancyVulnerable.sol   # 漏洞版：先转钱、后改账本
│   ├── ReentrancyAttacker.sol     # 攻击者：利用 receive 回调发起递归提款
│   └── ReentrancyFixed.sol        # 修复版：checks-effects-interactions + 互斥锁
└── test/
    └── Reentrancy.t.sol           # 攻击成功 / 修复后失败 / 正常用户回归，共 4 组测试
```

## 运行步骤

```bash
forge init ch11-playground && cd ch11-playground
forge install foundry-rs/forge-std
# 用本目录的 src/、test/、foundry.toml 替换生成物
forge build
forge test -vvv
```

## 预期结果

`forge test -vvv` 全部 PASS，四个测试的含义：

| 测试 | 验证什么 |
|---|---|
| `test_VulnerableBankGetsDrained` | 攻击者用 1 ETH 借口掏空 10 ETH 存款，重入共发生 11 次 |
| `test_FixedBankSurvivesSameAttack` | 同一攻击合约、同一战术，修复版分毫未损 |
| `test_FixedBankNormalUserCanDepositAndWithdraw` | 修复没有破坏正常功能，权限校验照常工作 |
| `test_VulnerableBankNormalPathWorksFine` | 漏洞版的正常路径毫无异常——这就是它危险的原因 |

## 设计取舍说明（与第 11 章正文对应）

- **漏洞只有一处**：`withdraw` 里 `call`（交互）在 `balances` 扣减（生效）之前。除此之外一切正常，包括 checks 本身。
- **攻击者的两个终止守卫**：银行 ETH 不足本次提款时停手（漏洞版被取空的收敛条件）；自己账上余额已被清零时安静返回（修复版把状态改在交互之前，重入者看到新余额）。
- **修复版加了两层**：CEI（顺序）+ `nonReentrant` 互斥锁（纵深防御）。CEI 已足以挡住本靶场的攻击，但跨函数重入等变种依然存在——生产合约通常两者都加。
- **不涉及真实协议、不使用任何真实项目代码**：全部为教学虚构合约，所有交互仅发生在本地 Anvil/Foundry 环境。
