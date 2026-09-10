/// 第 16 章配套模块：最小的 Vault，用于感受 Move 的资源语义。
///
/// 核心观察点：
/// 1. Vault 只有 `key` 能力 —— 没有 `copy`（不可复制）、没有 `drop`（不可随手销毁）
/// 2. 试着在函数里写 `let stolen = *vault;`，`sui move build` 会直接拒绝
/// 3. 测试结束时必须显式拆解 Vault —— "销毁"也是显式的
module ch16_move::vault {
    use sui::event;
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::tx_context::{Self, TxContext};

    // ---- 错误码 ----

    /// 金额必须大于零
    const EZeroAmount: u64 = 0;
    /// 余额不足
    const EInsufficientBalance: u64 = 1;

    // ---- 事件 ----

    public struct VaultCreated has copy, drop {
        vault_id: ID,
        owner: address,
    }

    public struct Deposited has copy, drop {
        vault_id: ID,
        amount: u64,
    }

    public struct Withdrawn has copy, drop {
        vault_id: ID,
        amount: u64,
    }

    // ---- 资源类型 ----

    /// 一个 Vault 对象。
    /// `key + store`：可以作为链上顶层对象、可被 public_transfer 转移；
    /// 没有 `copy`：不可复制——`let stolen = *vault` 会被编译器直接拒绝；
    /// 没有 `drop`：不可被隐式丢弃，销毁必须显式拆解。
    public struct Vault has key, store {
        id: UID,
        balance: u64,
    }

    // ---- 公开函数 ----

    /// 创建一个余额为零的 Vault，转给交易发起者
    public fun create(ctx: &mut TxContext) {
        let vault = Vault { id: object::new(ctx), balance: 0 };
        let owner = tx_context::sender(ctx);
        event::emit(VaultCreated { vault_id: object::uid_to_inner(&vault.id), owner });
        transfer::public_transfer(vault, owner);
    }

    /// 存入：给 Vault 增加余额
    public fun deposit(vault: &mut Vault, amount: u64) {
        assert!(amount > 0, EZeroAmount);
        vault.balance = vault.balance + amount;
        event::emit(Deposited {
            vault_id: object::uid_to_inner(&vault.id),
            amount,
        });
    }

    /// 取出：减少余额
    public fun withdraw(vault: &mut Vault, amount: u64) {
        assert!(amount > 0, EZeroAmount);
        assert!(vault.balance >= amount, EInsufficientBalance);
        vault.balance = vault.balance - amount;
        event::emit(Withdrawn {
            vault_id: object::uid_to_inner(&vault.id),
            amount,
        });
    }

    /// 只读：查询余额
    public fun balance(vault: &Vault): u64 {
        vault.balance
    }

    // ---- 仅测试可用的辅助函数 ----

    /// 没有drop能力，测试结束后必须显式拆解销毁。
    /// 解构本身是"合法的销毁路径"——显式、可审计。
    #[test_only]
    public fun destroy_for_test(vault: Vault) {
        let Vault { id, balance: _ } = vault;
        sui::object::delete(id);
    }

    /// 测试用：创建但不转移（entry 函数会转移，测试里不方便持有）
    #[test_only]
    public fun create_for_test(ctx: &mut TxContext): Vault {
        Vault { id: object::new(ctx), balance: 0 }
    }
}
