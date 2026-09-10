#!/usr/bin/env python3
"""
wallet_tool.py —— 第 2 章配套实验工具（纯标准库，全程离线）

用法：
  python3 wallet_tool.py test                      # 运行已知向量自检（推荐先跑）
  python3 wallet_tool.py generate                  # 生成一套全新钱包（助记词+地址）
  python3 wallet_tool.py derive --mnemonic "..."   # 从助记词推导地址（可加 --passphrase）
  python3 wallet_tool.py sign --key 0x... --message hello
  python3 wallet_tool.py verify --pubkey 0x... --message hello --r 0x... --s 0x...

警告：本工具仅用于学习。生成结果请勿存入任何真实资产；
真实钱包的安全要求（离线环境、物理备份）远高于本演示。
"""

import argparse
import hashlib
import hmac
import secrets
import sys
import unicodedata
from os import path

HERE = path.dirname(path.abspath(__file__))
WORDLIST_FILE = path.join(HERE, "bip39_wordlist_english.txt")

MASK256 = (1 << 256) - 1


# ---------- Keccak-256（以太坊地址所用哈希，注意它不是标准 SHA-3） ----------

_ROUND_CONSTANTS = [
    0x0000000000000001, 0x0000000000008082, 0x800000000000808A, 0x8000000080008000,
    0x000000000000808B, 0x0000000080000001, 0x8000000080008081, 0x8000000000008009,
    0x000000000000008A, 0x0000000000000088, 0x0000000080008009, 0x000000008000000A,
    0x000000008000808B, 0x800000000000008B, 0x8000000000008089, 0x8000000000008003,
    0x8000000000008002, 0x8000000000000080, 0x000000000000800A, 0x800000008000000A,
    0x8000000080008081, 0x8000000000008080, 0x0000000080000001, 0x8000000080008008,
]
_ROTATION = [
    [0, 36, 3, 41, 18],
    [1, 44, 10, 45, 2],
    [62, 6, 43, 15, 61],
    [28, 55, 25, 21, 56],
    [27, 20, 39, 8, 14],
]


MASK64 = (1 << 64) - 1


def _rotl64(x, n):
    return ((x << n) | (x >> (64 - n))) & MASK64 if n else x


def _keccak_f(state):
    for rc in _ROUND_CONSTANTS:
        c = [state[x][0] ^ state[x][1] ^ state[x][2] ^ state[x][3] ^ state[x][4] for x in range(5)]
        d = [c[(x - 1) % 5] ^ _rotl64(c[(x + 1) % 5], 1) for x in range(5)]
        for x in range(5):
            for y in range(5):
                state[x][y] ^= d[x]
        b = [[0] * 5 for _ in range(5)]
        for x in range(5):
            for y in range(5):
                b[y][(2 * x + 3 * y) % 5] = _rotl64(state[x][y], _ROTATION[x][y])
        for x in range(5):
            for y in range(5):
                state[x][y] = b[x][y] ^ ((~b[(x + 1) % 5][y]) & b[(x + 2) % 5][y])
        state[0][0] ^= rc


def keccak256(data: bytes) -> bytes:
    rate = 136  # bytes, capacity = 1600 - 136*8 = 1088 bits
    state = [[0] * 5 for _ in range(5)]

    def absorb(block: bytes):
        for i in range(rate // 8):
            state[i % 5][i // 5] ^= int.from_bytes(block[8 * i:8 * i + 8], "little")
        _keccak_f(state)

    offset = 0
    while len(data) - offset >= rate:
        absorb(data[offset:offset + rate])
        offset += rate
    tail = bytearray(data[offset:])
    tail += b"\x01" + b"\x00" * (rate - len(tail) - 1)
    tail[-1] |= 0x80
    absorb(bytes(tail))
    return b"".join(state[i % 5][i // 5].to_bytes(8, "little") for i in range(4))


# ---------- secp256k1 椭圆曲线 ----------

P = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F
N = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141
G = (
    0x79BE667EF9DCBBAC55A06295CE870B07029BFCDB2DCE28D959F2815B16F81798,
    0x483ADA7726A3C4655DA4FBFC0E1108A8FD17B448A68554199C47D08FFB10D4B8,
)


def _inv(a, m):
    return pow(a, -1, m)


def _point_add(p1, p2):
    if p1 is None:
        return p2
    if p2 is None:
        return p1
    x1, y1 = p1
    x2, y2 = p2
    if x1 == x2 and (y1 + y2) % P == 0:
        return None
    if p1 == p2:
        lam = (3 * x1 * x1) * _inv(2 * y1, P) % P
    else:
        lam = (y2 - y1) * _inv((x2 - x1) % P, P) % P
    x3 = (lam * lam - x1 - x2) % P
    y3 = (lam * (x1 - x3) - y1) % P
    return (x3, y3)


def _point_mul(k, point):
    result = None
    addend = point
    while k:
        if k & 1:
            result = _point_add(result, addend)
        addend = _point_add(addend, addend)
        k >>= 1
    return result


def pubkey_from_priv(priv: int):
    return _point_mul(priv % N, G)


def pubkey_bytes_compressed(priv: int) -> bytes:
    x, y = pubkey_from_priv(priv)
    prefix = b"\x03" if y & 1 else b"\x02"
    return prefix + x.to_bytes(32, "big")


def pubkey_bytes_uncompressed(priv: int) -> bytes:
    x, y = pubkey_from_priv(priv)
    return b"\x04" + x.to_bytes(32, "big") + y.to_bytes(32, "big")


def address_from_priv(priv: int) -> str:
    body = keccak256(pubkey_bytes_uncompressed(priv)[1:])
    return "0x" + body[-20:].hex()


def to_checksum_address(addr: str) -> str:
    """EIP-55 校验和地址：用地址哈希的大小写混合校验抄写错误。"""
    body = addr[2:].lower()
    digest = keccak256(body.encode()).hex()
    return "0x" + "".join(
        c.upper() if int(digest[i], 16) >= 8 else c
        for i, c in enumerate(body)
    )


def sign(priv: int, message: bytes):
    z = int.from_bytes(keccak256(message), "big")
    # 简化版确定性 k（真实钱包按 RFC-6979 由私钥与消息共同决定，原理相同：k 不靠随机数也安全）
    k = int.from_bytes(hashlib.sha256(priv.to_bytes(32, "big") + message).digest(), "big") % N
    if k == 0:
        raise RuntimeError("bad k")
    point = _point_mul(k, G)
    r = point[0] % N
    s = _inv(k, N) * (z + r * priv) % N
    return r, s


def verify(pubkey, message: bytes, r: int, s: int) -> bool:
    if not (1 <= r < N and 1 <= s < N):
        return False
    z = int.from_bytes(keccak256(message), "big")
    w = _inv(s, N)
    point = _point_add(_point_mul((z * w) % N, G), _point_mul((r * w) % N, pubkey))
    if point is None:
        return False
    return point[0] % N == r


# ---------- BIP-39：助记词 ----------

def load_wordlist():
    with open(WORDLIST_FILE, encoding="utf-8") as f:
        words = [w.strip() for w in f if w.strip()]
    if len(words) != 2048:
        raise RuntimeError(f"wordlist must have 2048 words, got {len(words)}")
    return words


def entropy_to_mnemonic(entropy: bytes) -> str:
    words = load_wordlist()
    checksum = hashlib.sha256(entropy).digest()
    checksum_bits = checksum[0] >> 4 if len(entropy) == 16 else None
    # 仅支持 128 位熵（12 词），checksum 取 SHA-256 前缀
    cs_len = len(entropy) // 4  # 4 bits for 16-byte entropy
    total = int.from_bytes(entropy, "big") * (1 << cs_len) + (int.from_bytes(checksum, "big") >> (256 - cs_len))
    total_bits = len(entropy) * 8 + cs_len
    indices = [(total >> (total_bits - 11 * (i + 1))) & 0x7FF for i in range(total_bits // 11)]
    return " ".join(words[i] for i in indices)


def mnemonic_to_seed(mnemonic: str, passphrase: str = "") -> bytes:
    norm = unicodedata.normalize("NFKD", " ".join(mnemonic.split()))
    salt = unicodedata.normalize("NFKD", "mnemonic" + passphrase)
    return hashlib.pbkdf2_hmac("sha512", norm.encode(), salt.encode(), 2048)


# ---------- BIP-32/44：从种子推导以太坊账户 ----------

HARDENED = 0x80000000


def _hmac_sha512(key: bytes, data: bytes):
    return hmac.new(key, data, hashlib.sha512).digest()


def _ckd_priv(k: int, c: bytes, index: int):
    if index >= HARDENED:
        data = b"\x00" + k.to_bytes(32, "big") + index.to_bytes(4, "big")
    else:
        data = pubkey_bytes_compressed(k) + index.to_bytes(4, "big")
    i_l, i_r = _hmac_sha512(c, data)[:32], _hmac_sha512(c, data)[32:]
    k_child = (int.from_bytes(i_l, "big") + k) % N
    return k_child, i_r


def derive_path(seed: bytes, path="m/44'/60'/0'/0/0"):
    i_l, i_r = _hmac_sha512(b"Bitcoin seed", seed)[:32], _hmac_sha512(b"Bitcoin seed", seed)[32:]
    k, c = int.from_bytes(i_l, "big"), i_r
    for step in path[2:].split("/"):
        hardened = step.endswith("'")
        idx = int(step[:-1]) + HARDENED if hardened else int(step)
        k, c = _ckd_priv(k, c, idx)
    return k, c


# ---------- 子命令 ----------

def cmd_test(_):
    ok = True

    def check(name, got, want):
        nonlocal ok
        good = got == want
        ok = ok and good
        print(f"[{'PASS' if good else 'FAIL'}] {name}")
        if not good:
            print(f"       got:  {got}\n       want: {want}")

    check("keccak256(b'')", keccak256(b"").hex(),
          "c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470")
    check("keccak256(b'abc')", keccak256(b"abc").hex(),
          "4e03657aea45a94fc7d47ba826c8d667c0d1e6e33a64a036ec44f58fa12d6c45")
    addr1 = address_from_priv(1)
    check("私钥=1 的地址", addr1.lower(),
          "0x7e5f4552091a69125d5dfcb7b8c2659029395bdf")
    check("EIP-55 校验和（私钥=1）", to_checksum_address(addr1),
          "0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf")

    mnemonic = "abandon " * 11 + "about"
    seed = mnemonic_to_seed(mnemonic)
    check("BIP-39 种子（测试向量）", seed.hex(),
          "5eb00bbddcf069084889a8ab9155568165f5c453ccb85e70811aaed6f6da5fc19a5ac40b389cd370d086206dec8aa6c43daea6690f20ad3d8d48b2d2ce9e38e4")
    k, _ = derive_path(seed)
    addr0 = address_from_priv(k)
    check("m/44'/60'/0'/0/0 地址", addr0.lower(),
          "0x9858effd232b4033e47d90003d41ec34ecaeda94")
    check("EIP-55 校验和（abandon 向量）", to_checksum_address(addr0),
          "0x9858EfFD232B4033E47d90003D41EC34EcaEda94")

    msg = b"hello web3"
    r, s = sign(k, msg)
    check("签名可验证", verify(pubkey_from_priv(k), msg, r, s), True)
    check("篡改消息后验签失败", verify(pubkey_from_priv(k), b"hello web4", r, s), False)
    check("篡改签名后验签失败", verify(pubkey_from_priv(k), msg, r, (s + 1) % N), False)

    print("=> 全部通过" if ok else "=> 存在失败项")
    return 0 if ok else 1


def cmd_generate(_):
    entropy = secrets.randbits(128).to_bytes(16, "big")
    mnemonic = entropy_to_mnemonic(entropy)
    seed = mnemonic_to_seed(mnemonic)
    k, _ = derive_path(seed)
    print("助记词（12 词，只能出现一次，截图即泄露）:")
    print("  " + mnemonic)
    print()
    print(f"以太坊地址（账户 #0）: {address_from_priv(k)}")
    print()
    print("注意：本工具没有安全擦除内存的能力，仅用于理解原理，")
    print("请勿把这里生成的助记词用于任何真实资产。")


def cmd_derive(args):
    seed = mnemonic_to_seed(args.mnemonic, args.passphrase)
    k, _ = derive_path(seed)
    print(f"BIP-39 种子: {seed.hex()}")
    print(f"账户 #0 私钥: 0x{k:064x}")
    print(f"账户 #0 地址: {address_from_priv(k)}")


def cmd_sign(args):
    k = int(args.key, 16)
    message = args.message.encode()
    r, s = sign(k, message)
    print(f"消息: {args.message}")
    print(f"消息哈希 keccak256: 0x{keccak256(message).hex()}")
    print(f"公钥(压缩): 0x{pubkey_bytes_compressed(k).hex()}")
    print(f"签名 r: 0x{r:064x}")
    print(f"签名 s: 0x{s:064x}")
    print(f"验签结果: {verify(pubkey_from_priv(k), message, r, s)}")


def cmd_verify(args):
    if args.pubkey:
        pk_hex = args.pubkey[2:]
        if len(pk_hex) == 66:  # 压缩公钥
            prefix = int(pk_hex[:2], 16)
            x = int(pk_hex[2:], 16)
            y_sq = (pow(x, 3, P) + 7) % P
            y = pow(y_sq, (P + 1) // 4, P)
            if (y * y) % P != y_sq:
                print("公钥无效"); return 1
            if (y & 1) != (prefix & 1):
                y = P - y
            pub = (x, y)
        else:  # 非压缩公钥
            pub = (int(pk_hex[2:66], 16), int(pk_hex[66:130], 16))
    else:
        print("需要 --pubkey"); return 1
    message = args.message.encode()
    r, s = int(args.r, 16), int(args.s, 16)
    ok = verify(pub, message, r, s)
    print(f"验签结果: {ok}")
    return 0 if ok else 1


def main():
    parser = argparse.ArgumentParser(description="第 2 章离线钱包实验工具")
    sub = parser.add_subparsers(dest="cmd", required=True)
    sub.add_parser("test")
    sub.add_parser("generate")
    d = sub.add_parser("derive")
    d.add_argument("--mnemonic", required=True)
    d.add_argument("--passphrase", default="")
    s = sub.add_parser("sign")
    s.add_argument("--key", required=True)
    s.add_argument("--message", required=True)
    v = sub.add_parser("verify")
    v.add_argument("--pubkey", required=True)
    v.add_argument("--message", required=True)
    v.add_argument("--r", required=True)
    v.add_argument("--s", required=True)
    args = parser.parse_args()
    handlers = {"test": cmd_test, "generate": cmd_generate,
                "derive": cmd_derive, "sign": cmd_sign, "verify": cmd_verify}
    sys.exit(handlers[args.cmd](args))


if __name__ == "__main__":
    main()
