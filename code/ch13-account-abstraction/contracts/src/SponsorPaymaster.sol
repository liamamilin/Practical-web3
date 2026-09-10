// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// 教学用"无条件代付" Paymaster：演示 ERC-4337 中 Paymaster 的最小职责。
// 生产级 Paymaster 必须做配额、风控与签名校验（见本章正文"边界"）。

// 结构与官方 PackedUserOperation（ERC-4337 v0.7+）字段一一对应，
// ABI 编码层面完全一致，这里本地声明以保持零依赖。
struct PackedUserOperation {
    address sender;
    uint256 nonce;
    bytes initCode;
    bytes callData;
    bytes32 accountGasLimits;
    uint256 preVerificationGas;
    bytes32 gasFees;
    bytes paymasterAndData;
    bytes signature;
}

interface IEntryPointView {
    function depositTo(address account) external payable;
    function withdrawTo(address withdrawAddress, uint256 withdrawAmount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract SponsorPaymaster {
    enum PostOpMode {
        opSucceeded,
        opReverted,
        postOpReverted
    }

    IEntryPointView public immutable entryPoint;
    address public immutable owner;

    // 部署时随构造转入的 ETH 全部存入 EntryPoint 作为代付保证金
    constructor(IEntryPointView _entryPoint) payable {
        entryPoint = _entryPoint;
        owner = msg.sender;
        if (msg.value > 0) {
            entryPoint.depositTo{value: msg.value}(address(this));
        }
    }

    // EntryPoint 在校验阶段调用：返回 (context, validationData)。
    // 本教学版无条件同意代付：context 为空、validationData 0（= 有效、不限时）。
    function validatePaymasterUserOp(
        PackedUserOperation calldata /*userOp*/,
        bytes32 /*userOpHash*/,
        uint256 /*maxCost*/
    ) external view returns (bytes memory, uint256) {
        require(msg.sender == address(entryPoint));
        return ("", 0);
    }

    // EntryPoint 在执行后调用：教学版无逻辑（生产版在这里按实际消耗记账/扣费）。
    function postOp(PostOpMode /*mode*/, bytes calldata /*context*/, uint256 /*actualGasCost*/, uint256 /*actualUserOpFeePerGas*/) external pure {
        require(true);
    }

    // 追加代付保证金
    function deposit() external payable {
        entryPoint.depositTo{value: msg.value}(address(this));
    }

    // 取回剩余保证金（仅限 owner）
    function withdrawTo(address to, uint256 amount) external {
        require(msg.sender == owner);
        entryPoint.withdrawTo(to, amount);
    }

    function depositBalance() external view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }
}
