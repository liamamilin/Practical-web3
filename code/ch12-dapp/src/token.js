import deployed from './deployed.json'

// 第 10 章 MyToken 接口中，前端真正用到的部分。
// 完整 ABI 见合约编译产物；前端只声明自己调用的条目，减小体积也降低出错面。
export const TOKEN_ABI = [
  {type: 'function', name: 'name', stateMutability: 'view', inputs: [], outputs: [{type: 'string'}]},
  {type: 'function', name: 'symbol', stateMutability: 'view', inputs: [], outputs: [{type: 'string'}]},
  {type: 'function', name: 'decimals', stateMutability: 'view', inputs: [], outputs: [{type: 'uint8'}]},
  {type: 'function', name: 'totalSupply', stateMutability: 'view', inputs: [], outputs: [{type: 'uint256'}]},
  {type: 'function', name: 'balanceOf', stateMutability: 'view', inputs: [{type: 'address'}], outputs: [{type: 'uint256'}]},
  {type: 'function', name: 'transfer', stateMutability: 'nonpayable', inputs: [{type: 'address', name: 'to'}, {type: 'uint256', name: 'value'}], outputs: [{type: 'bool'}]},
  {type: 'event', name: 'Transfer', inputs: [
    {type: 'address', indexed: true, name: 'from'},
    {type: 'address', indexed: true, name: 'to'},
    {type: 'uint256', indexed: false, name: 'value'},
  ]},
]

export const TOKEN_ADDRESS = /** @type {`0x${string}` | undefined} */ (
  deployed?.address
)
export const DECIMALS = 18
