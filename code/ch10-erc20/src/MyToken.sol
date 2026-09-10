// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "./IERC20.sol";

/// @title MyToken —— 从零手写的 ERC-20（教学版，零外部依赖）
/// @notice 完整实现 EIP-20 接口；每个函数存在的设计理由见本书第 10 章。
/// @dev 教学取向：不做 unchecked 优化，保留编译器算术检查，优先可读性。
contract MyToken is IERC20 {
    // ---- 元数据 ----
    // public 状态变量会自动生成同名 getter，正好满足接口的函数声明
    string public constant name = "Chapter10 Token";
    string public constant symbol = "C10";
    // decimals 是"人类单位与最小单位的换算率"：1 token = 10^18 个最小单位
    uint8 public constant decimals = 18;

    // ---- 核心状态：就这三样 ----
    uint256 public totalSupply;
    // 命名映射参数（0.8.18+）让嵌套映射的含义一目了然
    mapping(address account => uint256) private _balances;
    mapping(address owner => mapping(address spender => uint256)) private _allowances;

    // ---- 自定义错误（0.8.4+）：比 require 字符串省 gas，且可被调用方结构化处理 ----
    error InsufficientBalance(address account, uint256 needed, uint256 available);
    error InsufficientAllowance(address spender, address owner, uint256 needed, uint256 available);
    error ZeroAddress();

    /// @notice 铸造固定总量给部署者。这里刻意不开放后续 mint 权限：
    /// 任何"合约拥有铸币权"的设计都必须在第 4 章的检查清单里交代清楚。
    constructor() {
        _mint(msg.sender, 1_000_000 ether); // 100 万 token，ether 是 10^18 的字面量后缀
    }

    // ---- 只读层 ----

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) external view returns (uint256) {
        return _allowances[owner][spender];
    }

    // ---- 直接转账 ----

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    // ---- 授权与第三方代转 ----

    function approve(address spender, uint256 value) external returns (bool) {
        _allowances[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = _allowances[from][msg.sender];
        // 约定俗成：type(uint256).max 视为无限授权，不扣减，
        // 避免并发授权场景下"扣减后残余授权"引发的竞态窗口
        if (allowed != type(uint256).max) {
            if (allowed < value) {
                revert InsufficientAllowance(msg.sender, from, value, allowed);
            }
            _allowances[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    // ---- 内部实现 ----

    function _transfer(address from, address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        uint256 balance = _balances[from];
        if (balance < value) revert InsufficientBalance(from, value, balance);
        // Solidity 0.8+ 对算术溢出/下溢默认 revert，无需 SafeMath
        _balances[from] = balance - value;
        _balances[to] += value;
        emit Transfer(from, to, value);
    }

    function _mint(address to, uint256 value) internal {
        if (to == address(0)) revert ZeroAddress();
        totalSupply += value;
        _balances[to] += value;
        // 铸造的标志性记号：Transfer 的 from 是 address(0)
        emit Transfer(address(0), to, value);
    }
}
