// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockToken} from "./MockToken.sol";

/// @notice 模拟"恶意授权对象"：一旦被无限授权，可以随时、反复转走用户的代币。
///         它不需要任何花哨手段——transferFrom 是标准 ERC-20 的公开函数。
contract MaliciousSpender {
    address public owner; // 骗局经营者
    MockToken public token;

    constructor(address tokenAddr, address owner_) {
        owner = owner_;
        token = MockToken(tokenAddr);
    }

    /// @notice 把受害者账上的代币尽量搬走：取余额与授权额度中较小者。
    ///         只要有授权，任何人/任何合约都可调用，无需受害者配合。
    function drain(address victim) external {
        uint256 amount = token.balanceOf(victim);
        uint256 allowed = token.allowance(victim, address(this));
        if (amount > allowed) {
            amount = allowed;
        }
        token.transferFrom(victim, owner, amount);
    }

    /// @notice 撤销后再次尝试搬币（尝试转走固定数量）：应当 revert，代币留在受害者账上。
    function tryDrainAfterRevoke(address victim) external {
        token.transferFrom(victim, owner, 1e18);
    }
}
