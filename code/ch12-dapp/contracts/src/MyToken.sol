// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 直接复用第 10 章 code/ch10-erc20/ 中手写的 ERC-20，不做任何修改。
// 编译后产物在本目录 out/MyToken.sol/MyToken.json，scripts/deploy.mjs 会读取它部署。
import {MyToken} from "../../../ch10-erc20/src/MyToken.sol";
