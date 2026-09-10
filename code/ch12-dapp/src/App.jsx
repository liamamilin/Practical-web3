import {useConnection} from 'wagmi'
import {ConnectWallet} from './components/ConnectWallet'
import {TokenCard} from './components/TokenCard'
import {TransferForm} from './components/TransferForm'
import {RecentTransfers} from './components/RecentTransfers'
import {TOKEN_ADDRESS} from './token'

export function App() {
  const {isConnected, address} = useConnection()

  return (
    <main>
      <header>
        <h1>C10 转账台 — DApp 全栈示例</h1>
        <ConnectWallet />
      </header>

      {!TOKEN_ADDRESS && (
        <p className="err">
          尚未部署合约：先启动 anvil，再在 contracts/ 下 forge build，然后运行 node
          scripts/deploy.mjs
        </p>
      )}

      {TOKEN_ADDRESS && !isConnected && (
        <p>连接钱包后开始操作。别忘了：钱包里要导入一个 Anvil 测试账户的私钥。</p>
      )}

      {TOKEN_ADDRESS && isConnected && address && (
        <>
          <TokenCard address={address} />
          <TransferForm address={address} />
          <RecentTransfers address={address} />
        </>
      )}
    </main>
  )
}
