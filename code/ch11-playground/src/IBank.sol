// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice 靶场中"银行"的最小接口，攻击者不关心对面是漏洞版还是修复版。
interface IBank {
    function deposit() external payable;
    function withdraw(uint256 amount) external;
    function balances(address account) external view returns (uint256);
}
