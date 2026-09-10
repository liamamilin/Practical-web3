// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice EIP-20（ERC-20）标准接口，函数与事件与 EIP-20 原文一一对应。
/// @dev 每个函数"为什么存在"的完整解释见本书第 10 章。
interface IERC20 {
    // 转账事件：from 为 address(0) 表示铸造，to 为 address(0) 表示销毁
    event Transfer(address indexed from, address indexed to, uint256 value);
    // 授权事件：owner 允许 spender 最多动用 value 数量的代币
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // ---- 元数据（可选，但在实践中约定俗成必实现）----
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);

    // ---- 只读层 ----
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);

    // ---- 写入层：直接转账 ----
    function transfer(address to, uint256 value) external returns (bool);

    // ---- 写入层：授权 + 第三方代转 ----
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 value) external returns (bool);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
}
