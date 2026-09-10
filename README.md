# Practical Web3 — 《Web3 基石：从认知到构建》

一本帮助读者真正进入 Web3 领域的书：前半部建立认知体系，后半部亲手构建，配套 15 个可运行的代码项目。

- **在线阅读**：GitHub Pages（见仓库 Pages 部署）
- **内容**：信任问题 → 钱包与密钥 → 链上交易 → 原理（数据结构/共识/EVM/L2）→ 开发（Foundry/Solidity/安全/全栈/账户抽象）→ 多链（Solana/Move）→ DeFi 机制 → 毕业项目
- **实验环境**：全部本地模拟网络（Anvil、solana-test-validator、Sui 本地），零真实资金

## 本地构建

```bash
quarto render          # 生成 _book/，浏览器打开 _book/index.html
```

配套代码在 `code/` 目录下按章节组织，每个项目含完整可运行源码与验证状态说明的 README。
