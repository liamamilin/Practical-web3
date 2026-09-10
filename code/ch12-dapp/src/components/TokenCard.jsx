import {useEffect} from 'react'
import {useReadContracts, useBlockNumber} from 'wagmi'
import {formatUnits} from 'viem'
import {TOKEN_ABI, TOKEN_ADDRESS, DECIMALS} from '../token'

// 读路径：前端 → RPC → 节点直接查询，不经过钱包、不需要签名。
// 余额这类"会变的读"必须自己搭上区块高度刷新，wagmi 3 不再内置自动 watch。
export function TokenCard({address}) {
  const blockNumber = useBlockNumber({watch: true})
  const read = useReadContracts({
    allowFailure: false,
    contracts: [
      {address: TOKEN_ADDRESS, abi: TOKEN_ABI, functionName: 'name'},
      {address: TOKEN_ADDRESS, abi: TOKEN_ABI, functionName: 'symbol'},
      {address: TOKEN_ADDRESS, abi: TOKEN_ABI, functionName: 'decimals'},
      {address: TOKEN_ADDRESS, abi: TOKEN_ABI, functionName: 'totalSupply'},
      {
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: 'balanceOf',
        args: [address],
      },
    ],
  })

  const [name, symbol, decimals, totalSupply, balance] = read.data ?? []

  useEffect(() => {
    read.refetch()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [blockNumber.data])

  if (read.isLoading) return <p>读取合约中……</p>
  if (read.isError) return <p className="err">读取失败：{String(read.error)}</p>

  return (
    <div className="card">
      <h2>
        {name}（{symbol}）— 第 10 章的 MyToken
      </h2>
      <p>
        你的余额：
        <strong>{formatUnits(balance ?? 0n, decimals ?? DECIMALS)}</strong> {symbol}
      </p>
      <p className="hint">
        全网总量 {formatUnits(totalSupply ?? 0n, decimals ?? DECIMALS)}（当前区块{' '}
        {String(blockNumber.data ?? '?')}）
      </p>
    </div>
  )
}
