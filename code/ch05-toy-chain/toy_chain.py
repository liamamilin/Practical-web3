"""toy_chain.py — 约 150 行的玩具区块链。

目的：展示区块链数据结构的三个核心机制
  1. 哈希指纹（sha256）——任何字节改动都会让指纹完全变样
  2. 链式结构——每个区块的头部存着前一个区块的指纹
  3. Merkle 树——把一批交易浓缩成一条指纹，并支持"单笔交易证明"

依赖：仅 Python 标准库。运行：python3 toy_chain.py
"""

import hashlib
import json
import time


# ---------- 第一块积木：哈希 ----------

def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def hash_json(obj) -> str:
    """对任意可序列化对象取指纹。sort_keys 保证同样内容同样指纹。"""
    canonical = json.dumps(obj, sort_keys=True, ensure_ascii=False)
    return sha256(canonical.encode("utf-8"))


# ---------- 第二块积木：Merkle 树 ----------

def build_merkle_root(txids: list[str]) -> str:
    """自底向上两两合并，最后剩一条指纹。奇数个时复制最后一个。"""
    if not txids:
        return sha256(b"empty")
    level = list(txids)
    while len(level) > 1:
        if len(level) % 2 == 1:
            level.append(level[-1])
        level = [
            sha256((level[i] + level[i + 1]).encode())
            for i in range(0, len(level), 2)
        ]
    return level[0]


def build_merkle_proof(txids: list[str], index: int) -> list[tuple[str, str]]:
    """生成第 index 笔交易的证明路径：[(兄弟哈希, 兄弟在左边还是右边), ...]"""
    level = list(txids)
    proof = []
    idx = index
    while len(level) > 1:
        if len(level) % 2 == 1:
            level.append(level[-1])
        sibling = idx ^ 1  # 成对节点中，兄弟的下标
        side = "left" if sibling < idx else "right"
        proof.append((level[sibling], side))
        level = [
            sha256((level[i] + level[i + 1]).encode())
            for i in range(0, len(level), 2)
        ]
        idx //= 2
    return proof


def verify_merkle_proof(txid: str, proof: list[tuple[str, str]], root: str) -> bool:
    """只凭 txid + 证明路径 + 区块头里的 root，验证这笔交易确实在区块里。"""
    current = txid
    for sibling, side in proof:
        pair = sibling + current if side == "left" else current + sibling
        current = sha256(pair.encode())
    return current == root


# ---------- 第三块积木：区块与链 ----------

class Block:
    def __init__(self, height: int, prev_hash: str, transactions: list[dict]):
        self.height = height
        self.prev_hash = prev_hash
        self.timestamp = int(time.time())
        self.transactions = transactions
        self.txids = [hash_json(tx) for tx in transactions]
        self.merkle_root = build_merkle_root(self.txids)

    def header(self) -> dict:
        """区块头：真正参与链式哈希的部分。"""
        return {
            "height": self.height,
            "prev_hash": self.prev_hash,
            "timestamp": self.timestamp,
            "merkle_root": self.merkle_root,
        }

    @property
    def hash(self) -> str:
        return hash_json(self.header())


class Chain:
    def __init__(self):
        genesis = Block(0, "0" * 64, [{"type": "genesis", "note": "创世区块"}])
        self.blocks = [genesis]

    def append(self, transactions: list[dict]) -> Block:
        block = Block(len(self.blocks), self.blocks[-1].hash, transactions)
        self.blocks.append(block)
        return block

    def is_valid(self) -> tuple[bool, str]:
        """从创世区块逐块重算：链是否完整。这就是"被验证出来"的实现。"""
        for i in range(1, len(self.blocks)):
            block, prev = self.blocks[i], self.blocks[i - 1]
            # 检查 1：区块头里的指纹是否还能对上内容
            if block.hash != hash_json(block.header()):
                return False, f"第 {i} 块：内容被改过，区块头指纹对不上"
            # 检查 2：Merkle 根是否还能对上交易列表
            if build_merkle_root([hash_json(tx) for tx in block.transactions]) != block.merkle_root:
                return False, f"第 {i} 块：交易列表被改过，Merkle 根对不上"
            # 检查 3：本块记录的前块指纹是否还等于前块现在的指纹
            if block.prev_hash != prev.hash:
                return False, f"第 {i} 块：prev_hash 不再匹配第 {i-1} 块，链条断裂"
        return True, f"链完整，共 {len(self.blocks)} 块，全部验证通过"


def print_chain(chain: Chain) -> None:
    for b in chain.blocks:
        print(f"  块 #{b.height}  hash={b.hash[:16]}...  prev={b.prev_hash[:16]}...  txs={len(b.transactions)}")


# ---------- 演示 ----------

if __name__ == "__main__":
    chain = Chain()
    chain.append([{"from": "alice", "to": "bob", "amount": 10}])
    chain.append([
        {"from": "bob", "to": "carol", "amount": 3},
        {"from": "bob", "to": "dave", "amount": 2},
        {"from": "carol", "to": "erin", "amount": 1},
    ])
    print("== 原始链 ==")
    print_chain(chain)
    print("验证：", chain.is_valid()[1])

    print("\n== 轻节点验证演示（SPV）==")
    target_block = chain.blocks[2]
    tx = target_block.transactions[1]
    txid = target_block.txids[1]
    proof = build_merkle_proof(target_block.txids, 1)
    print(f"  只凭 1 笔交易 + {len(proof)} 个中间哈希，验证它是否在第 2 块中：",
          verify_merkle_proof(txid, proof, target_block.merkle_root))
    fake_tx = hash_json({"from": "eve", "to": "mallory", "amount": 999})
    print(f"  换一笔伪造交易，同一证明路径：", verify_merkle_proof(fake_tx, proof, target_block.merkle_root))
