import {useConnection, useConnect, useConnectors, useDisconnect} from 'wagmi'

// 连接钱包 = 前端与浏览器插件（EIP-1193 提供者）握手。
// 注意：这一步之后前端拿到的只是"地址"，签名能力永远在钱包插件手里。
export function ConnectWallet() {
  const {isConnected, address} = useConnection()
  const connect = useConnect()
  const connectors = useConnectors()
  const disconnect = useDisconnect()

  if (isConnected) {
    return (
      <div className="wallet">
        <span className="mono">{address}</span>
        <button onClick={() => disconnect.mutate()}>断开</button>
      </div>
    )
  }

  return (
    <div className="wallet">
      {connectors.map((connector) => (
        <button key={connector.uid} onClick={() => connect.mutate({connector})}>
          连接 {connector.name}
        </button>
      ))}
      <span className="hint">需要一个注入式钱包（如 MetaMask），并添加 Anvil 本地网络</span>
    </div>
  )
}
