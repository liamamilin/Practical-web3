import * as anchor from "@coral-xyz/anchor";
import { Program } from "@coral-xyz/anchor";
import { Ch15Anchor } from "../target/types/ch15_anchor";
import { expect } from "chai";

describe("ch15-anchor", () => {
  // provider：连接到 anchor test 自动启动的本地 validator
  const provider = anchor.AnchorProvider.env();
  anchor.setProvider(provider);

  const program = anchor.workspace.Ch15Anchor as Program<Ch15Anchor>;

  // PDA：与程序端约定同一种子 [b"counter", user_pubkey]
  const [counterPda] = anchor.web3.PublicKey.findProgramAddressSync(
    [Buffer.from("counter"), provider.wallet.publicKey.toBuffer()],
    program.programId,
  );

  it("initializes counter to 0", async () => {
    await program.methods
      .initialize()
      .accounts({ counter: counterPda, user: provider.wallet.publicKey })
      .rpc();

    // 读状态：读的是数据账户，不是程序账户
    const counter = await program.account.counter.fetch(counterPda);
    expect(counter.count.toNumber()).to.equal(0);
    expect(counter.authority).to.deep.equal(provider.wallet.publicKey);
  });

  it("increments twice", async () => {
    await program.methods
      .increment()
      .accounts({
        counter: counterPda,
        authority: provider.wallet.publicKey,
      })
      .rpc();
    await program.methods
      .increment()
      .accounts({
        counter: counterPda,
        authority: provider.wallet.publicKey,
      })
      .rpc();

    const counter = await program.account.counter.fetch(counterPda);
    expect(counter.count.toNumber()).to.equal(2);
  });

  it("rejects unauthorized increment", async () => {
    // 换一个没有权限的签名者，期望交易失败
    const attacker = anchor.web3.Keypair.generate();
    try {
      await program.methods
        .increment()
        .accounts({
          counter: counterPda,
          authority: attacker.publicKey,
        })
        .signers([attacker])
        .rpc();
      expect.fail("应当因权限校验失败而抛错");
    } catch (err) {
      // Anchor 的 has_one 校验失败会以约束错误形式抛出
      expect(err.toString()).to.include("ConstraintHasOne");
    }
  });
});
