// 部署 ERC-4337 本地三件套：
//   EntryPoint + SimpleAccountFactory ← 编译自官方 npm 包源码（@account-abstraction/contracts）
//   SponsorPaymaster（教学版代付）     ← 本项目 contracts/src/
// 前提：anvil 在 http://127.0.0.1:8545；npm install 已完成
// 运行：node scripts/deploy.mjs
import {readFileSync, writeFileSync} from 'node:fs'
import {fileURLToPath} from 'node:url'
import {dirname, join} from 'node:path'
import {
  createPublicClient,
  createWalletClient,
  http,
  defineChain,
  parseEther,
} from 'viem'
import {privateKeyToAccount} from 'viem/accounts'
import {compileContract} from './lib/compile.mjs'

const DEPLOYER_KEY =
  '0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80'

const anvil = defineChain({
  id: 31337,
  name: 'anvil',
  rpcUrls: {default: {http: ['http://127.0.0.1:8545']}},
})

const here = dirname(fileURLToPath(import.meta.url))
const aaRoot = join(here, '../node_modules/@account-abstraction/contracts')
const ozRoot = join(here, '../node_modules/@openzeppelin/contracts')
const contractsRoot = join(here, '../contracts')

console.log('编译 EntryPoint / SimpleAccountFactory / SponsorPaymaster ……')
const entryPointArt = compileContract('core/EntryPoint.sol', aaRoot, ozRoot, 'EntryPoint')
const factoryArt = compileContract('accounts/SimpleAccountFactory.sol', aaRoot, ozRoot, 'SimpleAccountFactory')
const paymasterArt = compileContract('src/SponsorPaymaster.sol', contractsRoot, ozRoot, 'SponsorPaymaster')

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

const ensure0x = (x) => (x.startsWith('0x') ? x : `0x${x}`)

async function deploy(name, artifact, args = [], value = 0n) {
  const hash = await walletClient.deployContract({
    abi: artifact.abi,
    bytecode: ensure0x(artifact.bytecode.object),
    args,
    value,
  })
  const {contractAddress} = await publicClient.waitForTransactionReceipt({hash})
  console.log(`${name}: ${contractAddress}`)
  return contractAddress
}

const entryPoint = await deploy('EntryPoint (ERC-4337 v0.7+)', entryPointArt)
const factory = await deploy('SimpleAccountFactory', factoryArt, [entryPoint])
// 教学版 Paymaster：随部署存入 0.1 ETH 代付保证金
const paymaster = await deploy('SponsorPaymaster', paymasterArt, [entryPoint], parseEther('0.1'))

const deposit = /** @type {bigint} */ (
  await publicClient.readContract({
    address: paymaster,
    abi: paymasterArt.abi,
    functionName: 'depositBalance',
    gas: 100_000n,
  })
)
console.log('Paymaster 保证金:', Number(deposit) / 1e18, 'ETH')

writeFileSync(
  join(here, 'aa-state.json'),
  JSON.stringify({entryPoint, factory, paymaster}, null, 2),
)
console.log('地址已写入 scripts/aa-state.json，可运行 node scripts/send-uop.mjs 发起代付 UserOperation。')
