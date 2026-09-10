"""fork_sim.py — 最小化分叉模拟（约 100 行）。

回答两个问题：
  1. "确认数增长"到底意味着什么？——为什么确认数多了也不等于"不可逆"？
  2. 一个算力占比为 a 的攻击者，想撤销已经拿到 n 个确认的交易，
     大概需要多幸运？（蒙特卡洛估算 vs 中本聪白皮书公式 (a/(1-a))^n）

模型刻意简化到最小：
  - 每个 tick，诚实链挖出一块的概率 = (1-a)，攻击者秘密链 +1 的概率 = a
  - 攻击者从落后 n 块开始追；追平即成功（全网会跟着更长的攻击链走）；
    落后超过放弃阈值则失败。
  - 这不是真实的网络协议，只是把"概率性终局"的直觉跑给你看。

依赖：仅 Python 标准库。运行：python3 fork_sim.py
"""

import random

random.seed(2026)  # 固定种子，结果可复现

GIVE_UP = 200      # 攻击者落后这么多块就放弃
TRIALS = 20000     # 每组参数重复次数


def attacker_wins(advantage: float, deficit: int) -> bool:
    """攻击者算力占比 advantage，落后 deficit 块，返回这次秘密挖矿是否追平。"""
    while deficit <= GIVE_UP:
        if deficit <= 0:
            return True
        r = random.random()
        if r < advantage:
            deficit -= 1     # 攻击者挖到一块
        else:
            deficit += 1     # 诚实链挖到一块
    return False


def theory(a: float, n: int) -> float:
    """中本聪白皮书（Nakamoto 2008, 第 11 节）的追平概率公式。"""
    if a >= 0.5:
        return 1.0
    q = a / (1 - a)
    return q ** n


print("攻击者算力占比 a | 确认数 n | 模拟成功率 | 理论值 (a/(1-a))^n")
print("-----------------+----------+------------+-------------------")
for a in (0.1, 0.2, 0.3):
    for n in (1, 3, 6):
        wins = sum(attacker_wins(a, n) for _ in range(TRIALS))
        sim = wins / TRIALS
        print(f"        {a:.0%}      |    {n}     |   {sim:6.2%}   |      {theory(a, n):6.2%}")

print("""
观察：
  1. 确认数 n 每加一层，撤销难度按几何级数上升——这就是"等几个确认"的真实含义：
     它不是倒计时，是把攻击者需要的好运乘上好几层。
  2. 但它永远是概率，不是零。只要 a < 50%，数学上仍存在追平的可能。
  3. 当 a >= 50%，公式发散，成功率恒为 100%——此时确认数再多也没有意义。
  4. 所以 Bitcoin 的"6 个确认"只是工程惯例（把成本推到几乎不可行），
     不是协议里的硬性保证。它的终局性是概率性的（probabilistic finality）。

下一块积木：能不能设计一种机制，让"终局"不是概率、而是明确的规则？
—— 这是第 6 章正文里 PoS + 终局性小工具（finality gadget）要回答的问题。
""")
