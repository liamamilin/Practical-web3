// SPDX-License-Identifier: MIT
// 本机无 Foundry 环境，此测试套件未本地验证；forge init + forge install foundry-rs/forge-std 后可直接替换运行。
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC165, IERC721, IERC721Receiver} from "../src/IERC721.sol";
import {MyNFT} from "../src/MyNFT.sol";

/// @dev 诚实接收方：正确返回选择器
contract MockReceiver is IERC721Receiver {
    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}

/// @dev 坏接收方：没有实现 onERC721Received（任何对它的 safeTransferFrom 都应被拒绝）
contract BadReceiver {}

contract MyNFTTest is Test {
    MyNFT nft;
    MockReceiver receiver;
    BadReceiver badReceiver;

    address alice;

    function setUp() public {
        nft = new MyNFT();
        receiver = new MockReceiver();
        badReceiver = new BadReceiver();
        alice = makeAddr("alice");
    }

    function _mintTo(address to, uint256 tokenId) internal {
        nft.mint(to, tokenId);
    }

    // ---- 铸造 ----

    function test_MintAssignsOwnerAndEmits() public {
        vm.expectEmit(true, true, true, true);
        emit IERC721.Transfer(address(0), alice, 1);
        _mintTo(alice, 1);
        assertEq(nft.ownerOf(1), alice);
        assertEq(nft.balanceOf(alice), 1);
    }

    function test_MintOnlyDeployer() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(MyNFT.NotTokenOwner.selector, alice, address(this))
        );
        nft.mint(alice, 1);
    }

    function test_MintDuplicateTokenIdReverts() public {
        _mintTo(alice, 1);
        vm.expectRevert(abi.encodeWithSelector(MyNFT.TokenAlreadyMinted.selector, 1));
        nft.mint(alice, 1);
    }

    function test_OwnerOfNonexistentTokenReverts() public {
        vm.expectRevert(abi.encodeWithSelector(MyNFT.NonexistentToken.selector, 99));
        nft.ownerOf(99);
    }

    // ---- transferFrom 与两层授权 ----

    function test_OwnerCanTransfer() public {
        _mintTo(address(this), 1);
        nft.transferFrom(address(this), alice, 1);
        assertEq(nft.ownerOf(1), alice);
    }

    function test_ApprovedCanTransfer() public {
        _mintTo(address(this), 1);
        nft.approve(alice, 1);

        vm.prank(alice);
        nft.transferFrom(address(this), alice, 1);

        assertEq(nft.ownerOf(1), alice);
    }

    function test_OperatorCanTransfer() public {
        _mintTo(address(this), 1);
        nft.setApprovalForAll(alice, true);

        vm.prank(alice);
        nft.transferFrom(address(this), alice, 1);

        assertEq(nft.ownerOf(1), alice);
    }

    function test_UnapprovedCannotTransfer() public {
        _mintTo(address(this), 1);

        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(MyNFT.NotApproved.selector, alice, 1));
        nft.transferFrom(address(this), alice, 1);
    }

    function test_TransferClearsSingleApproval() public {
        _mintTo(address(this), 1);
        nft.approve(alice, 1);

        nft.transferFrom(address(this), alice, 1);
        // 转移后旧授权必须失效
        assertEq(nft.getApproved(1), address(0));
    }

    // ---- safeTransferFrom 与接收方校验 ----

    function test_SafeTransferToHonestReceiver() public {
        _mintTo(address(this), 1);
        nft.safeTransferFrom(address(this), address(receiver), 1);
        assertEq(nft.ownerOf(1), address(receiver));
    }

    function test_SafeTransferToBadReceiverReverts() public {
        _mintTo(address(this), 1);
        vm.expectRevert(abi.encodeWithSelector(MyNFT.TransferToNonReceiver.selector, badReceiver));
        nft.safeTransferFrom(address(this), address(badReceiver), 1);
        // NFT 仍在原所有者手里，没有进入黑洞
        assertEq(nft.ownerOf(1), address(this));
    }

    // ---- ERC-165 ----

    function test_SupportsInterface() public view {
        assertTrue(nft.supportsInterface(type(IERC165).interfaceId));
        assertTrue(nft.supportsInterface(type(IERC721).interfaceId));
        assertFalse(nft.supportsInterface(bytes4(0xdeadbeef)));
    }
}
