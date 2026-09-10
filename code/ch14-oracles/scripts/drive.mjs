// 驱动脚本：部署 MockPriceFeed + PriceConsumer，验证"读喂价 → 改价 → 再读 → 过期拒绝"全链路。
// 运行：node scripts/drive.mjs（需 anvil 在跑，已 npm install）
import {fileURLToPath} from 'node:url'
import {dirname, join} from 'node:path'
import {createPublicClient, createWalletClient, http, defineChain} from 'viem'
import {privateKeyToAccount} from 'viem/accounts'
import {compileContract} from './lib/compile.mjs'

const anvil = defineChain({
  id: 31337,
  name: 'anvil',
  rpcUrls: {default: {http: ['http://127.0.0.1:8545']}},
})

const here = dirname(fileURLToPath(import.meta.url))
const srcRoot = join(here, '../src')

const publicClient = createPublicClient({chain: anvil, transport: http()})
const deployer = privateKeyToAccount(
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80',
)
const walletClient = createWalletClient({
  account: deployer,
  chain: anvil,
  transport: http(),
})

const chainId = await publicClient.getChainId()
if (chainId !== 31337) {
  throw new Error(`RPC 返回 chainId=${chainId}，不是本地链（31337）。先启动 anvil。`)
}

const feedArt = compileContract('MockPriceFeed.sol', srcRoot, 'MockPriceFeed')
const consumerArt = compileContract('PriceConsumer.sol', srcRoot, 'PriceConsumer')

async function deploy(name, artifact, args) {
  const bytecode = artifact.bytecode.object.startsWith('0x')
    ? artifact.bytecode.object
    : `0x${artifact.bytecode.object}`
  const hash = await walletClient.deployContract({abi: artifact.abi, bytecode, args})
  const {contractAddress} = await publicClient.waitForTransactionReceipt({hash})
  console.log(`${name}: ${contractAddress}`)
  return {address: contractAddress, abi: artifact.abi}
}

const feed = await deploy('MockPriceFeed', feedArt, ['MOCK / USD', 8, 2000n*100000000n])
const consumer = await deploy('PriceConsumer', consumerArt, [feed.address, 3600n])

const read = (c, fn, args = []) =>
  publicClient.readContract({address: c.address, abi: c.abi, functionName: fn, args, gas: 200_000n})

// 1. 读初始喂价
console.log('初始喂价:', Number(await read(consumer, 'latestPrice')) / 1e8)
console.log('带新鲜度守卫的读法:', Number(await read(consumer, 'priceWithFreshnessGuard')) / 1e8)
console.log('1 个代币按喂价折算:', Number(await read(consumer, 'valueOf', [1_000_000_000_000_000_000n])) / 1e18)

// 2. 改价（真实预言机网络里这一步由多节点报告+聚合完成）
await walletClient.writeContract({
  address: feed.address,
  abi: feed.abi,
  functionName: 'setPrice',
  args: [2100n*100000000n],
  gas: 100_000n,
})
console.log('改价后读数:', Number(await read(consumer, 'latestPrice')) / 1e8)

// 3. 时间前进 2 小时 → 喂价过期 → 新鲜度守卫必须拒绝
await publicClient.request({method: 'evm_increaseTime', params: [7200]})
for (const mine of ['anvil_mine', 'hardhat_mine', 'evm_mine']) {
  try { await publicClient.request({method: mine, params: ['0x1']}); break } catch {}
}
try {
  await read(consumer, 'priceWithFreshnessGuard')
  console.log('❌ 过期喂价没有被拒绝——新鲜度守卫失效')
  process.exitCode = 1
} catch (e) {
  console.log('✅ 过期喂价被拒绝（StalePrice）:', String(e.message).slice(0, 60))
}
