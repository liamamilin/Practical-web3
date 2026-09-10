// 发起一笔由 Paymaster 代付的 UserOperation：
//   一个尚不存在、也没有任何 ETH 的 SimpleAccount（由 initCode 在本次操作中创建）
//   转出 0.01 ETH —— 而 gas 由 Paymaster 保证金支付，sender 全程零余额。
// 前提：先运行 node scripts/deploy.mjs
// 运行：node scripts/send-uop.mjs
import {readFileSync} from 'node:fs'
import {fileURLToPath} from 'node:url'
import {dirname, join} from 'node:path'
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  encodeFunctionData,
  encodePacked,
  concatHex,
  parseEther,
  parseGwei,
  formatEther,
  toHex,
} from 'viem'
import {privateKeyToAccount, sign, serializeSignature} from 'viem/accounts'

// 角色（全部是 Anvil 公开测试密钥，仅限本地链）：
const OWNER_KEY =
  '0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a' // Anvil #2：智能账户的主人
const BUNDLER_KEY =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80' // Anvil #0：扮演 Bundler（提交者/受益人）
const RECIPIENT = '0x90F79bf6EB2c4f870365E785982E1f101E93b906' // Anvil #3：收款人
const SALT = 0n

const anvil = defineChain({
  id: 31337,
  name: 'anvil',
  rpcUrls: {default: {http: ['http://127.0.0.1:8545']}},
})

const here = dirname(fileURLToPath(import.meta.url))
const aa = join(here, '../node_modules/@account-abstraction/contracts/artifacts')
const state = JSON.parse(readFileSync(join(here, 'aa-state.json'), 'utf8'))
const epAbi = JSON.parse(readFileSync(join(aa, 'IEntryPoint.json'), 'utf8')).abi
const factoryAbi = JSON.parse(readFileSync(join(aa, 'SimpleAccountFactory.json'), 'utf8')).abi
const accountAbi = JSON.parse(readFileSync(join(aa, 'SimpleAccount.json'), 'utf8')).abi

const publicClient = createPublicClient({chain: anvil, transport: http()})
const owner = privateKeyToAccount(OWNER_KEY)
const bundler = privateKeyToAccount(BUNDLER_KEY)
const bundlerWallet = createWalletClient({
  account: bundler,
  chain: anvil,
  transport: http(),
})

console.log(' EntryPoint:', state.entryPoint)
console.log(' AccountFactory:', state.factory)
console.log(' Paymaster:', state.paymaster)

// ① 智能账户地址：由 factory + owner + salt 用 CREATE2 确定（counterfactual）
const sender = /** @type {`0x${string}`} */ (
  await publicClient.readContract({
    address: state.factory,
    abi: factoryAbi,
    functionName: 'getAddress',
    args: [owner.address, SALT],
    gas: 500_000n,
  })
)
console.log('① 智能账户（将被创建于）:', sender)

// ② 组装 UserOperation 各字段
const nonce = /** @type {bigint} */ (
  await publicClient.readContract({
    address: state.entryPoint,
    abi: epAbi,
    functionName: 'getNonce',
    args: [sender, 0n],
    gas: 500_000n,
  })
)
// initCode = factory 地址 + createAccount 调用数据：首次操作时由 EntryPoint 创建账户
const initCode = concatHex([
  state.factory,
  encodeFunctionData({
    abi: factoryAbi,
    functionName: 'createAccount',
    args: [owner.address, SALT],
  }),
])
// callData = 让账户执行一次零值调用：execute(收款地址, 0 ETH, 空数据)。
// 注意：Paymaster 只代付 GAS，不代付转账面额——若要转 0.01 ETH，账户自身得持有它。
const callData = encodeFunctionData({
  abi: accountAbi,
  functionName: 'execute',
  args: [RECIPIENT, 0n, '0x'],
})

const userOp = {
  sender,
  nonce,
  initCode,
  callData,
  // accountGasLimits = verificationGasLimit(前 16 字节) + callGasLimit(后 16 字节)
  accountGasLimits: encodePacked(['uint128', 'uint128'], [500_000n, 100_000n]),
  preVerificationGas: 100_000n,
  // gasFees = maxPriorityFeePerGas(前 16 字节) + maxFeePerGas(后 16 字节)
  gasFees: encodePacked(['uint128', 'uint128'], [parseGwei('1'), parseGwei('10')]),
  // paymasterAndData（v0.8 布局）= paymaster(20B) + paymasterVerificationGasLimit(16B)
  //                    + postOpGasLimit(16B) + paymaster 自定义数据（教学版为空）。
  // 注意：v0.7 的 validUntil/validAfter 6 字节字段在 v0.8 中已移除。
  paymasterAndData: encodePacked(
    ['address', 'uint128', 'uint128'],
    [state.paymaster, 200_000n, 50_000n],
  ),
  signature: '0x',
}
console.log('② UserOperation 组装完成（sender 余额：', formatEther(await publicClient.getBalance({address: sender})), 'ETH）')

// ③ 算哈希并用 owner 私钥签名
const userOpHash = /** @type {`0x${string}`} */ (
  await publicClient.readContract({
    address: state.entryPoint,
    abi: epAbi,
    functionName: 'getUserOpHash',
    args: [userOp],
    gas: 500_000n,
  })
)
const signature = await sign({privateKey: OWNER_KEY, hash: userOpHash})
// viem 的 sign() 返回 {r, s, v, yParity} 对象，需序列化为 65 字节签名串
userOp.signature = serializeSignature(signature)
console.log('③ userOpHash:', userOpHash, '（owner 已签名）')

// ④ 记录各方执行前状态
const paymasterBefore = /** @type {bigint} */ (
  await publicClient.readContract({
    address: state.entryPoint,
    abi: epAbi,
    functionName: 'balanceOf',
    args: [state.paymaster],
    gas: 500_000n,
  })
)
const bundlerBefore = await publicClient.getBalance({address: bundler.address})

// ⑤ 扮演 Bundler：把签好的 UserOperation 装进 handleOps 提交上链
let handleOpsData
try {
  handleOpsData = encodeFunctionData({
    abi: epAbi,
    functionName: 'handleOps',
    args: [[userOp], bundler.address],
  })
} catch (err) {
  console.error('编码失败，userOp 字段诊断：')
  for (const [k, v] of Object.entries(userOp)) {
    console.error('  ', k, typeof v, String(v).slice(0, 50))
  }
  throw err
}
const txHash = await bundlerWallet.sendTransaction({
  to: state.entryPoint,
  data: handleOpsData,
  gas: 3_000_000n,
})
const receipt = await publicClient.waitForTransactionReceipt({hash: txHash})
console.log('⑤ handleOps 已上链: block', receipt.blockNumber.toString(), 'status', receipt.status)

// ⑥ 验证代付效果
const paymasterAfter = /** @type {bigint} */ (
  await publicClient.readContract({
    address: state.entryPoint,
    abi: epAbi,
    functionName: 'balanceOf',
    args: [state.paymaster],
    gas: 500_000n,
  })
)
const bundlerAfter = await publicClient.getBalance({address: bundler.address})
const gasCost = paymasterBefore - paymasterAfter
const bundlerReward = bundlerAfter - bundlerBefore

// 从 UserOperationEvent 读取本笔操作的成败与实际开销
// 事件：indexed(userOpHash, sender, paymaster)，data = (nonce, success, actualGasCost, actualGasUsed)
const uopEvent = receipt.logs.find(
  (log) => log.address.toLowerCase() === state.entryPoint.toLowerCase() && log.topics[0].startsWith('0x49628fd1'),
)
const success = uopEvent ? BigInt('0x' + uopEvent.data.slice(66, 130)) === 1n : false

console.log('⑥ 执行结果：')
console.log(`   UserOperation 成功: ${success}`)
console.log(`   sender 余额: ${formatEther(await publicClient.getBalance({address: sender}))} ETH（从未注资，应保持 0）`)
console.log(`   Paymaster 保证金: -${formatEther(gasCost)} ETH（代付了全部 gas）`)
console.log(`   Bundler/受益人净变化: +${formatEther(bundlerReward)} ETH（收到 gas 奖励，扣除自身交易 gas 后的净值）`)

if (!success) {
  throw new Error('UserOperationEvent.success = false，内层调用失败')
}
if (paymasterBefore <= paymasterAfter) {
  throw new Error('Paymaster 保证金未减少，代付未生效')
}
console.log('✅ 代付 UserOperation 全流程通过：账户被创建、调用执行成功、gas 全由 Paymaster 支付。')
