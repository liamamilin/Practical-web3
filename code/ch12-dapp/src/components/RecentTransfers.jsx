import {useEffect, useState} from 'react'
import {usePublicClient, useWatchContractEvent} from 'wagmi'
import {formatUnits} from 'viem'
import {TOKEN_ABI, TOKEN_ADDRESS, DECIMALS} from '../token'

// 两条取数路径的对照演示：
// 1) 历史：publicClient.getLogs 扫一个区块范围（链不是数据库，没有索引，只能"重放"）
// 2) 实时：useWatchContractEvent 订阅新事件（便宜，因为只看未来）
// 大规模历史检索请交给 indexer（本章"事件与索引"一节）。
export function RecentTransfers({address}) {
  const publicClient = usePublicClient()
  const [logs, setLogs] = useState([])

  // 历史：只扫最近 5000 个区块作演示。主网上这必须分页/走 indexer。
  useEffect(() => {
    let cancelled = false
    async function load() {
      const head = await publicClient.getBlockNumber()
      const from = head > 5000n ? head - 5000n : 0n
      const recent = await publicClient.getLogs({
        address: TOKEN_ADDRESS,
        event: TOKEN_ABI.find((item) => item.type === 'event' && item.name === 'Transfer'),
        fromBlock: from,
        toBlock: 'latest',
      })
      if (!cancelled) setLogs(recent.reverse())
    }
    load().catch(console.error)
    return () => {
      cancelled = true
    }
  }, [publicClient])

  // 实时：新事件到来时追加到列表头部
  useWatchContractEvent({
    address: TOKEN_ADDRESS,
    abi: TOKEN_ABI,
    eventName: 'Transfer',
    onLogs(newLogs) {
      setLogs((prev) => [...newLogs.slice().reverse(), ...prev])
    },
  })

  return (
    <div className="card">
      <h2>最近转账（Transfer 事件）</h2>
      <p className="hint">
        合约状态里没有"转账历史"这回事——历史只存在于事件日志里，由链下程序维护索引。
      </p>
      {logs.length === 0 && <p>暂无记录</p>}
      <ul>
        {logs.map((log) => (
          <li key={`${log.transactionHash}-${log.logIndex}`}>
            block {String(log.blockNumber)}：{log.args.from} → {log.args.to}{' '}
            <strong>{formatUnits(log.args.value, DECIMALS)}</strong>
            {log.args.from.toLowerCase() === address?.toLowerCase() ||
            log.args.to.toLowerCase() === address?.toLowerCase()
              ? ' ←与你的地址相关'
              : ''}
          </li>
        ))}
      </ul>
    </div>
  )
}
