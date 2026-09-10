import {createConfig, http} from 'wagmi'
import {anvil} from 'wagmi/chains'
import {injected} from 'wagmi/connectors'

// 全书约定：实验环境只有一条本地链（Anvil，chainId 31337）。
// 真实产品会在这里列出多条链，并给每条链配置 transport（RPC 入口）。
export const config = createConfig({
  chains: [anvil],
  connectors: [injected()],
  transports: {
    [anvil.id]: http('http://127.0.0.1:8545'),
  },
})
