# ch10-erc721 —— 从零手写的 ERC-721

本书第 10 章配套代码。不依赖 OpenZeppelin，只依赖 Forge 标准库（仅测试用）。

> **验证状态**：已在 Foundry 1.8.1 / Solc 0.8.30 下实机验证通过（12/12 PASS）。

## 文件结构

```text
ch10-erc721/
├── foundry.toml
├── src/
│   ├── IERC721.sol       # ERC-721 / Metadata / ERC-165 / Receiver 四个接口
│   └── MyNFT.sol         # 手写实现：所有权模型与两层授权见第 10 章
└── test/
    └── MyNFT.t.sol       # 单元测试（含好/坏两种接收方合约）
```

## 运行步骤

```bash
forge init ch10-erc721 && cd ch10-erc721
forge install foundry-rs/forge-std
# 用本目录的 src/、test/、foundry.toml 替换生成物
forge build
forge test -vvv
```

## 预期结果

- `forge build` 零警告零错误。
- `forge test` 全部 PASS：12 个单元测试。
- 重点观察 `test_SafeTransferToBadReceiverReverts`：向未实现 `onERC721Received` 的合约做安全转账会被拒绝，NFT 不会掉进黑洞——这正是 `safeTransferFrom` 存在的理由（第 10 章正文）。

## 设计取舍说明（与第 10 章正文对应）

- **单枚授权 + 全量操作员两层授权**：对应市场合约（只管某一枚）与钱包/代理（批量管理）两类真实场景。
- **转移前清除单枚授权**：防止旧授权"跟着 tokenId 走"。
- **mint 权限仅限部署者**：教学演示 `modifier onlyOwner`；真实项目应换成多签或治理合约，且必须向用户交代铸造规则（第 4 章检查清单）。
- **`tokenURI` 采用简单拼接**：元数据本身存链下，链上只存指针——"链上只存发生了什么"的又一例证（第 12 章）。
