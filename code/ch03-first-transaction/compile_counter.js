// 编译 Counter.sol 的辅助脚本（正文实验用 counter_bytecode.txt 即由它生成）
const solc = require('solc');
const fs = require('fs');
const path = require('path');
const dir = __dirname;
const src = fs.readFileSync(path.join(dir, 'Counter.sol'), 'utf8');
const input = {
  language: 'Solidity',
  sources: { 'Counter.sol': { content: src } },
  settings: {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: 'cancun',
    outputSelection: { '*': { '*': ['abi', 'evm.bytecode', 'evm.deployedBytecode'] } }
  }
};
const out = JSON.parse(solc.compile(JSON.stringify(input)));
if (out.errors) out.errors.forEach(e => console.error(e.formattedMessage));
const c = out.contracts['Counter.sol']['Counter'];
fs.writeFileSync(path.join(dir, 'counter_bytecode.txt'), '0x' + c.evm.bytecode.object);
console.log('creation code bytes:', c.evm.bytecode.object.length / 2);
console.log('deployedCode bytes:', c.evm.deployedBytecode.object.length / 2);console.log('abi:', JSON.stringify(c.abi));
