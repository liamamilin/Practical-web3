"""demo_tamper.py — "篡改即暴露"演示，以及它的边界。

场景一：改一笔交易，链条当场断裂。
场景二：攻击者把后续区块全部重算——结构上又能骗过 is_valid()。
        这暴露了纯数据结构的边界：结构验证只保证"改了必被发现"，
        不保证"发现之后全网不接受你"。那是第 6 章共识要回答的问题。

运行：python3 demo_tamper.py
"""

from toy_chain import Chain, Block, hash_json, build_merkle_root, print_chain


def build_chain() -> Chain:
    chain = Chain()
    chain.append([{"from": "alice", "to": "bob", "amount": 10}])
    chain.append([{"from": "bob", "to": "carol", "amount": 3}])
    chain.append([{"from": "carol", "to": "erin", "amount": 2}])
    return chain


print("======== 场景一：改一笔交易 ========")
chain = build_chain()
print("篡改前：", chain.is_valid()[1])

# 攻击者把第 1 块里 bob 付给 carol 的 3 个币改成 300 个
chain.blocks[1].transactions[0]["amount"] = 300
ok, msg = chain.is_valid()
print(f"篡改后：{ok} —— {msg}")

print("\n======== 场景二：把后续区块全部重算 ========")
chain = build_chain()
chain.blocks[1].transactions[0]["amount"] = 300

# 第一步：修复第 1 块自己的指纹（重算 Merkle 根，区块 hash 是属性，随之改变）
block1 = chain.blocks[1]
block1.txids = [hash_json(tx) for tx in block1.transactions]
block1.merkle_root = build_merkle_root(block1.txids)

# 第二步：顺着重算后面每一块的 prev_hash
for i in range(2, len(chain.blocks)):
    chain.blocks[i].prev_hash = chain.blocks[i - 1].hash

ok, msg = chain.is_valid()
print(f"全量重算后，结构验证：{ok} —— {msg}")
print_chain(chain)
print("""
结论：
  1. 数据结构层面的保证是"改了必被发现"——但前提是有人去验证。
  2. 只要肯花功夫重算，结构上可以造出一条"完整"的假链。
  3. 所以真正的问题是：全网凭什么接受你的假链，而不是原链？
     —— 这不是数据结构能回答的，是第 6 章共识机制要回答的。
""")
