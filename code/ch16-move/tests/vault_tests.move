/// Vault 模块的测试：验证资源语义下的存取行为。
/// 运行：sui move test
#[test_only]
module ch16_move::vault_tests {
    use ch16_move::vault;
    use sui::tx_context::{Self, TxContext};

    #[test]
    fun deposit_increases_balance() {
        let admin = @0xA;
        let mut ctx = tx_context::new_from_hint(admin, 0, 0, 0, 0);

        let mut v = vault::create_for_test(&mut ctx);
        vault::deposit(&mut v, 100);
        assert!(vault::balance(&v) == 100, 0);

        // 资源没有 drop 能力：显式拆解，不能丢着不管
        vault::destroy_for_test(v);
    }

    #[test]
    fun withdraw_respects_balance() {
        let admin = @0xA;
        let mut ctx = tx_context::new_from_hint(admin, 0, 0, 0, 0);

        let mut v = vault::create_for_test(&mut ctx);
        vault::deposit(&mut v, 50);
        vault::withdraw(&mut v, 30);
        assert!(vault::balance(&v) == 20, 0);

        vault::destroy_for_test(v);
    }

    #[test, expected_failure(abort_code = 1)]
    fun withdraw_more_than_balance_aborts() {
        let admin = @0xA;
        let mut ctx = tx_context::new_from_hint(admin, 0, 0, 0, 0);

        let mut v = vault::create_for_test(&mut ctx);
        vault::deposit(&mut v, 10);
        // 余额 10，取 20 → abort EInsufficientBalance (1)
        vault::withdraw(&mut v, 20);

        vault::destroy_for_test(v);
    }
}
