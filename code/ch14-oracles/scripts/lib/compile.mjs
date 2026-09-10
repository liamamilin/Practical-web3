// 极简 Solidity 编译工具（相对导入），供 drive.mjs 就地编译，零 Foundry 依赖。
import solc from 'solc'
import fs from 'node:fs'
import path from 'node:path'

/**
 * @param {string} virtualPath 以 baseRoot 为基准的入口源文件路径
 * @param {string} baseRoot    源码根目录
 * @param {string} contractName 目标合约名
 */
export function compileContract(virtualPath, baseRoot, contractName) {
  const sources = {}

  function load(key) {
    if (sources[key]) return
    const src = fs.readFileSync(path.resolve(baseRoot, key), 'utf8')
    sources[key] = {content: src}
    const re = /import\s+(?:{[^}]*}\s*(?:from\s*)?|\*\s+as\s+\w+\s+from\s*)?"([^"]+)"/g
    let m
    while ((m = re.exec(src))) {
      const dir = key.includes('/') ? key.slice(0, key.lastIndexOf('/')) : ''
      load(path.posix.normalize(dir ? `${dir}/${m[1]}` : m[1]))
    }
  }

  load(virtualPath)

  const input = {
    language: 'Solidity',
    sources,
    settings: {
      optimizer: {enabled: true, runs: 200},
      evmVersion: 'cancun',
      outputSelection: {[virtualPath]: {[contractName]: ['abi', 'evm.bytecode.object']}},
    },
  }
  const out = JSON.parse(solc.compile(JSON.stringify(input)))
  const errors = (out.errors ?? []).filter((e) => e.severity === 'error')
  if (errors.length) {
    throw new Error(errors.map((e) => e.formattedMessage).join('\n'))
  }
  const c = out.contracts[virtualPath]?.[contractName]
  if (!c) throw new Error(`编译产物中找不到 ${contractName}（在 ${virtualPath}）`)
  return {abi: c.abi, bytecode: {object: c.evm.bytecode.object}}
}
