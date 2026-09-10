// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice 教学用最小 ERC-20：只实现本实验需要的 approve / transferFrom / transfer。
///         不用 OpenZeppelin 等外部库，保证零依赖、本地可跑。
contract MockToken {
    string public name = "Mock Token";
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    constructor() {
        balanceOf[msg.sender] = 1_000_000e18;
        emit Transfer(address(0), msg.sender, 1_000_000e18);
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        _transfer(msg.sender, to, value);
        return true;
    }

    /// @dev 授权的关键：allowance 记录"spender 可以代替 owner 转走多少"。
    ///      传 type(uint256).max 即通常所说的"无限授权"。
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    /// @dev 第三方花钱的入口：只要 allowance 够，spender 无需 owner 在场。
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= value, "insufficient allowance");
        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - value;
        }
        _transfer(from, to, value);
        return true;
    }

    function _transfer(address from, address to, uint256 value) internal {
        require(balanceOf[from] >= value, "insufficient balance");
        balanceOf[from] -= value;
        balanceOf[to] += value;
        emit Transfer(from, to, value);
    }
}
