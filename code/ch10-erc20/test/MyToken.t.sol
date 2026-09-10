// SPDX-License-Identifier: MIT
// 本机无 Foundry 环境，此测试套件未本地验证；forge init + forge install foundry-rs/forge-std 后可直接替换运行。
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "../src/IERC20.sol";
import {MyToken} from "../src/MyToken.sol";

contract MyTokenTest is Test {
    MyToken token;

    address alice;
    address bob;

    uint256 constant SUPPLY = 1_000_000 ether;

    function setUp() public {
        token = new MyToken();
        alice = makeAddr("alice");
        bob = makeAddr("bob");
    }

    // ---- 元数据 ----

    function test_Metadata() public view {
        assertEq(token.name(), "Chapter10 Token");
        assertEq(token.symbol(), "C10");
        assertEq(token.decimals(), 18);
    }

    // ---- 铸造 ----

    function test_ConstructorMintsDeployer() public view {
        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)), SUPPLY);
    }

    // ---- transfer ----

    function test_TransferMovesBalanceAndEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Transfer(address(this), alice, 100 ether);
        assertTrue(token.transfer(alice, 100 ether));
        assertEq(token.balanceOf(alice), 100 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY - 100 ether);
    }

    function test_TransferRevertsOnInsufficientBalance() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyToken.InsufficientBalance.selector, alice, 1 ether, 0)
        );
        token.transfer(bob, 1 ether);
    }

    function test_TransferRevertsOnZeroAddress() public {
        vm.expectRevert(abi.encodeWithSelector(MyToken.ZeroAddress.selector));
        token.transfer(address(0), 1 ether);
    }

    // ---- approve / transferFrom ----

    function test_ApproveSetsAllowanceAndEmits() public {
        vm.expectEmit(true, true, false, true);
        emit IERC20.Approval(address(this), bob, 50 ether);
        assertTrue(token.approve(bob, 50 ether));
        assertEq(token.allowance(address(this), bob), 50 ether);
    }

    function test_TransferFromUsesAllowance() public {
        token.approve(bob, 100 ether);

        vm.prank(bob);
        assertTrue(token.transferFrom(address(this), alice, 40 ether));

        assertEq(token.allowance(address(this), bob), 60 ether);
        assertEq(token.balanceOf(alice), 40 ether);
        assertEq(token.balanceOf(address(this)), SUPPLY - 40 ether);
    }

    function test_TransferFromRevertsOnInsufficientAllowance() public {
        token.approve(bob, 10 ether);

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                MyToken.InsufficientAllowance.selector, bob, address(this), 11 ether, 10 ether
            )
        );
        token.transferFrom(address(this), alice, 11 ether);
    }

    function test_TransferFromUnlimitedAllowanceNotDecremented() public {
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(address(this), alice, 100 ether);

        assertEq(token.allowance(address(this), bob), type(uint256).max);
    }

    // ---- 模糊测试（呼应第 9 章：fuzzing）----

    function testFuzz_TransferPreservesTotalSupply(uint256 amount) public {
        amount = bound(amount, 0, token.balanceOf(address(this)));

        token.transfer(alice, amount);

        assertEq(token.totalSupply(), SUPPLY);
        assertEq(token.balanceOf(address(this)) + token.balanceOf(alice), SUPPLY);
    }

    function testFuzz_ApproveThenTransferFrom(uint256 approved, uint256 spent) public {
        approved = bound(approved, 0, SUPPLY);
        spent = bound(spent, 0, approved);

        token.approve(bob, approved);
        vm.prank(bob);
        token.transferFrom(address(this), alice, spent);

        assertEq(token.balanceOf(alice), spent);
        assertEq(token.allowance(address(this), bob), approved - spent);
    }
}
