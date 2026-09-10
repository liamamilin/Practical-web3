//! 第 15 章示例程序：最小计数器
//!
//! 演示 Solana 编程模型的四个核心点：
//! 1. 程序无状态：本模块里没有任何全局变量，状态全部存在数据账户中
//! 2. 账户即容器：Counter 结构体会被序列化进一个数据账户的 data 字段
//! 3. PDA：每个用户一个独立计数器账户，地址由种子确定性派生
//! 4. 权限校验：Signer + has_one 由 Anchor 声明式完成

use anchor_lang::prelude::*;

// 注意：这是占位程序 ID。首次 `anchor build` 后，用 `anchor keys list`
// 取出你自己的程序 ID 并替换这里，再重新 build。
declare_id!("CZQ7AXaJ8zJfPPSYf2LDcFxGiegEGU5gQrMz6iesVVcu");

#[program]
pub mod ch15_anchor {
    use super::*;

    /// 创建属于调用者的计数器账户，余额置零
    pub fn initialize(ctx: Context<Initialize>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        counter.authority = ctx.accounts.user.key();
        counter.count = 0;
        Ok(())
    }

    /// 递增一次。只有 initialize 时的 user（authority）能调用
    pub fn increment(ctx: Context<Increment>) -> Result<()> {
        let counter = &mut ctx.accounts.counter;
        // checked_add：溢出时报错而不是回绕
        counter.count = counter
            .count
            .checked_add(1)
            .ok_or(error!(ErrorCode::Overflow))?;
        Ok(())
    }
}

/// 存在"数据账户"里的状态。#[account] 让 Anchor 处理序列化与 discriminator
#[account]
#[derive(InitSpace)]
pub struct Counter {
    /// 谁有权递增这个计数器
    pub authority: Pubkey,
    /// 计数值
    pub count: u64,
}

/// initialize 的账户上下文：
/// - init + seeds：首次调用时由系统程序创建账户，地址由种子确定性派生（PDA）
/// - payer = user：创建账户的租金押金由 user 支付
/// - space：账户数据大小（8 字节 discriminator + Counter 大小）
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(
        init,
        payer = user,
        space = 8 + Counter::INIT_SPACE,
        seeds = [b"counter", user.key().as_ref()],
        bump
    )]
    pub counter: Account<'info, Counter>,
    #[account(mut)]
    pub user: Signer<'info>,
    pub system_program: Program<'info, System>,
}

/// increment 的账户上下文：
/// - mut：counter 数据将被修改
/// - has_one = authority：runtime 校验 counter.authority == 传入的 authority
#[derive(Accounts)]
pub struct Increment<'info> {
    #[account(mut, has_one = authority)]
    pub counter: Account<'info, Counter>,
    pub authority: Signer<'info>,
}

#[error_code]
pub enum ErrorCode {
    #[msg("count would overflow u64")]
    Overflow,
}
