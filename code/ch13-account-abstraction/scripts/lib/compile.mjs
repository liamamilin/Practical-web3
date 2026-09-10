// 极简 Solidity 编译工具：基于 solc-js，从 npm 包源码就地编译，
// 不依赖 Foundry 也能产出可部署字节码。读者若已装 Foundry，也可用 forge 编译 contracts/ 下的合约。
import solc from 'solc'
import fs from 'node:fs'
import path from 'node:path'

const OZ_PLACEHOLDER = '@openzeppelin/'

/**
 * 编译一个合约并返回 {abi, bytecode}。
 * @param {string} virtualPath  以 baseRoot 为基准的入口源文件路径（如 'core/EntryPoint.sol'）
 * @param {string} baseRoot     源码根目录（相对导入以此解析；@openzeppelin/ 导入解析到 ozRoot）
 * @param {string} ozRoot       @openzeppelin/contracts 的实际目录
 * @param {string} contractName 入口文件中的目标合约名
 */
export function compileContract(virtualPath, baseRoot, ozRoot, contractName) {
  const sources = {}

  function realFile(key) {
    if (key.startsWith(OZ_PLACEHOLDER)) {
      return path.resolve(ozRoot, key.replace('@openzeppelin/contracts/', ''))
    }
    return path.resolve(baseRoot, key)
  }

  function virtualKeyOf(key, importPath) {
    if (importPath.startsWith(OZ_PLACEHOLDER)) return importPath
    const dir = key.includes('/') ? key.slice(0, key.lastIndexOf('/')) : ''
    return path.posix.normalize(dir ? `${dir}/${importPath}` : importPath)
  }

  function load(key) {
    if (sources[key]) return
    const src = fs.readFileSync(realFile(key), 'utf8')
    sources[key] = { content: src }
    const re = /import\s+(?:{[^}]*}\s*(?:from\s*)?|\*\s+as\s+\w+\s+from\s*)?"([^"]+)"/g
    let m
    while ((m = re.exec(src))) load(virtualKeyOf(key, m[1]))
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
