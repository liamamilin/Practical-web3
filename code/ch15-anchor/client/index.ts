// 第 15 章：独立的 TypeScript 客户端脚本
// 与测试的区别：不依赖 anchor test 的环境注入，
// 自建 keypair、空投本地 SOL、手动构造 provider——这就是"前端如何连程序"的最小原型。
//
// 运行前提：solana-test-validator 已在运行（或直接用 `yarn client`，
// 本脚本假定本地 8899 端口有 validator）。
// 注意：此脚本使用全新的 keypair，因此每次运行都会创建一个新计数器。
//
// 账户传递说明（Anchor 新版客户端的关键变化）：
// - initialize 的 counter：PDA 地址可由种子确定性派生（我们显式给出，见 accountsStrict）
// - increment 的 authority：has_one 关系在链上校验（程序内）
// - 全部账户显式传入（accountsStrict），与链上账户上下文一一对应，最利于理解

import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Ch15Anchor } from "../target/types/ch15_anchor";
import {
  Connection,
  Keypair,
  LAMPORTS_PER_SOL,
  PublicKey,
} from "@solana/web3.js";

async function main() {
  const connection = new Connection("http://127.0.0.1:8899", "confirmed");

  // 1. 建一个本地账户并向其空投测试 SOL（仅 localnet 有效）
  const payer = Keypair.generate();
  const airdropSig = await connection.requestAirdrop(
    payer.publicKey,
    LAMPORTS_PER_SOL,
  );
  await connection.confirmTransaction(airdropSig, "confirmed");
  console.log("payer:", payer.publicKey.toBase58());

  // 2. 构造 provider 与程序实例
  const provider = new anchor.AnchorProvider(
    connection,
    new anchor.Wallet(payer),
    {},
  );
  const program = anchor.workspace.Ch15Anchor as Program<Ch15Anchor>;

  // 3. 派生该用户的 PDA（与程序内 seeds 一致：["counter", payer]）
  const [counterPda] = PublicKey.findProgramAddressSync(
    [Buffer.from("counter"), payer.publicKey.toBuffer()],
    program.programId,
  );

  // 4. initialize：accountsStrict 显式列出全部账户（见正文"显式派 vs 自动派"）
  await program.methods
    .initialize()
    .accountsStrict({
      counter: counterPda,
      user: payer.publicKey,
      systemProgram: anchor.web3.SystemProgram.programId,
    })
    .signers([payer])
    .rpc();
  console.log("Counter initialized at:", counterPda.toBase58());

  // 5. 连续递增三次：同样显式传参，不依赖自动解析
  for (let i = 0; i < 3; i++) {
    await program.methods
      .increment()
      .accountsStrict({
        counter: counterPda,
        authority: payer.publicKey,
      })
      .signers([payer])
      .rpc();
  }

  // 6. 读回状态
  const counter = await program.account.counter.fetch(counterPda);
  console.log("count after 3 increments:", counter.count.toNumber());
  console.log("done.");
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
