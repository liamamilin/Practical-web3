// 部署脚本：把第 10 章的 MyToken 部署到本地 Anvil，并给测试账户发一点初始持仓。
// 依赖：forge build 已在 contracts/ 目录跑过（生成 out/MyToken.sol/MyToken.json）
// 运行：node scripts/deploy.mjs   （前提：anvil 已在 http://127.0.0.1:8545 运行）
import {readFileSync, writeFileSync} from 'node:fs'
import {fileURLToPath} from 'node:url'
import {dirname, join} from 'node:path'
import {
  createPublicClient,
  createWalletClient,
  http,
  parseUnits,
  formatUnits,
  defineChain,
} from 'viem'
import {privateKeyToAccount} from 'viem/accounts'

// Anvil 默认助记词下的第 0 号账户（deployer）与第 1 号账户（前端演示用）
const DEPLOYER_KEY =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'
const USER_ADDRESS = '0x70997970C51812dc3A010C7d01b50e0d17dc79C8'

const anvil = defineChain({
  id: 31337,
  name: 'anvil',
  rpcUrls: {default: {http: ['http://127.0.0.1:8545']}},
})

const here = dirname(fileURLToPath(import.meta.url))
const artifactPath = join(here, '../contracts/out/MyToken.sol/MyToken.json')
const artifact = JSON.parse(readFileSync(artifactPath, 'utf8'))
// Foundry 标准产物：abi + bytecode（bytecode.object 是初始化代码）
const abi = artifact.abi
// 注意：Foundry 产物的 bytecode.object 不带 0x 前缀，viem 需要显式补上
const bytecode = /** @type {{bytecode: {object: string}}} */ (artifact).bytecode
  .object.startsWith('0x')
  ? /** @type {{bytecode: {object: string}}} */ (artifact).bytecode.object
  : `0x${/** @type {{bytecode: {object: string}}} */ (artifact).bytecode.object}`

const publicClient = createPublicClient({chain: anvil, transport: http()})
const deployer = privateKeyToAccount(DEPLOYER_KEY)
const walletClient = createWalletClient({
  account: deployer,
  chain: anvil,
  transport: http(),
})

const chainId = await publicClient.getChainId()
if (chainId !== 31337) {
  throw new Error(`RPC 返回 chainId=${chainId}，不是 Anvil（31337）。先启动 anvil。`)
}

// 1. 部署
const hash = await walletClient.deployContract({abi, bytecode})
const {contractAddress} = await publicClient.waitForTransactionReceipt({hash})
console.log('MyToken 部署于:', contractAddress)

// 2. 从部署者转 1000 C10 给前端演示账户（第 10 章版本是固定总量、无 mint）
const amount = parseUnits('1000', 18)
const transferHash = await walletClient.writeContract({
  address: contractAddress,
  abi,
  functionName: 'transfer',
  args: [USER_ADDRESS, amount],
})
const receipt = await publicClient.waitForTransactionReceipt({
  hash: transferHash,
})
console.log('已向', USER_ADDRESS, '转 1000 C10，tx:', transferHash)

// 3. 验证 + 落盘给前端读取
const balance = /** @type {bigint} */ (
  await publicClient.readContract({
    address: contractAddress,
    abi,
    functionName: 'balanceOf',
    args: [USER_ADDRESS],
  })
)
console.log('演示账户余额:', formatUnits(balance, 18), 'C10')

writeFileSync(
  join(here, '../src/deployed.json'),
  JSON.stringify(
    {address: contractAddress, deployer: deployer.address, block: receipt.blockNumber.toString()},
    null,
    2,
  ),
)
console.log('地址已写入 src/deployed.json，可运行 npm run dev 打开前端。')
