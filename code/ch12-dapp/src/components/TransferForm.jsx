import {useState} from 'react'
import {useWriteContract, useWaitForTransactionReceipt} from 'wagmi'
import {parseUnits, formatUnits} from 'viem'
import {TOKEN_ABI, TOKEN_ADDRESS, DECIMALS} from '../token'

// 写路径：前端 → 钱包弹窗（签名）→ 钱包把已签名交易交给 RPC 广播。
// 前端自始至终接触不到私钥——这就是第 2 章"钱包是一串钥匙"在工程上的落点。
export function TransferForm({address}) {
  const [to, setTo] = useState('')
  const [amount, setAmount] = useState('')

  const write = useWriteContract()
  // 等待"这笔交易被打包并确认"——写操作分两拍：签名确认 ≠ 链上确认
  const receipt = useWaitForTransactionReceipt({hash: write.data})

  async function onSubmit(e) {
    e.preventDefault()
    try {
      write.mutate({
        address: TOKEN_ADDRESS,
        abi: TOKEN_ABI,
        functionName: 'transfer',
        args: [to, parseUnits(amount, DECIMALS)],
      })
    } catch (err) {
      // 典型失败：gas 估算阶段就 revert（余额不足），错误信息来自节点模拟执行
      console.error(err)
    }
  }

  const submitting = write.isPending
  const confirming = receipt.isLoading

  return (
    <div className="card">
      <h2>转账</h2>
      <form onSubmit={onSubmit}>
        <label>
          收款地址
          <input
            value={to}
            onChange={(e) => setTo(e.target.value)}
            placeholder="0x…（Anvil 账户 2：0x3C44…93DB）"
            required
          />
        </label>
        <label>
          数量
          <input
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            placeholder="10"
            required
          />
        </label>
        <button type="submit" disabled={submitting || confirming}>
          {submitting ? '请在钱包中确认……' : confirming ? '等待链上确认……' : '发送转账'}
        </button>
      </form>

      {receipt.isSuccess && (
        <p className="ok">
          转账已确认 ✅ tx: <span className="mono">{receipt.data.transactionHash}</span>
        </p>
      )}
      {write.isError && <p className="err">签名或执行出错：{String(write.error?.message ?? write.error)}</p>}
      {receipt.isError && <p className="err">确认出错：{String(receipt.error)}</p>}
      <p className="hint">
        状态机：待签名 →（钱包确认）→ 已广播 →（矿工打包）→ 已确认。金额以 18 位小数的最小单位编码
        （parseUnits）。
      </p>
    </div>
  )
}
