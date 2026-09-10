// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice 零依赖的 Foundry cheatcode / console 接口（免装 forge-std，本地即可编译运行）。
interface Vm {
    function prank(address) external;
    function startPrank(address) external;
    function stopPrank() external;
    function expectRevert(bytes calldata) external;
    function addr(uint256) external returns (address);
    function label(address, string calldata) external;
}

Vm constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

library console {
    address constant CONSOLE = address(bytes20(hex"0000000000000000000000" hex"636F6e736F6c654465"));

    function log(string memory s) internal {
        CONSOLE.call(abi.encodeWithSignature("log(string)", s));
    }

    function log(string memory s, uint256 v) internal {
        CONSOLE.call(abi.encodeWithSignature("log(string,uint256)", s, v));
    }

    function log(string memory s, address a) internal {
        CONSOLE.call(abi.encodeWithSignature("log(string,address)", s, a));
    }
}
