// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockPriceFeed} from "../src/MockPriceFeed.sol";
import {PriceConsumer} from "../src/PriceConsumer.sol";

contract MockPriceFeedTest is Test {
    MockPriceFeed feed;
    PriceConsumer consumer;

    function setUp() public {
        // 2000.00000000（8 位小数的喂价形态，与主流 USD 喂价一致）
        feed = new MockPriceFeed("MOCK / USD", 8, 2000_00000000);
        consumer = new PriceConsumer(address(feed), 1 hours);
    }

    function test_ReadsLatestPrice() public view {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        assertEq(answer, 2000_00000000);
        assertEq(updatedAt, block.timestamp);
        assertEq(consumer.latestPrice(), 2000_00000000);
    }

    function test_RoundIdIncreasesOnUpdate() public {
        (uint80 round0, , , , ) = feed.latestRoundData();
        feed.setPrice(2100_00000000);
        (uint80 round1, int256 answer1, , , ) = feed.latestRoundData();
        assertEq(round1, round0 + 1);
        assertEq(answer1, 2100_00000000);
    }

    function test_FreshnessGuardPasses() public view {
        assertEq(consumer.priceWithFreshnessGuard(), 2000_00000000);
    }

    function test_FreshnessGuardRevertsOnStalePrice() public {
        // 快进 2 小时：喂价没人更新，消费者必须拒绝使用过期价格
        vm.warp(block.timestamp + 2 hours);
        vm.expectRevert(abi.encodeWithSelector(PriceConsumer.StalePrice.selector, block.timestamp - 2 hours, 2 hours, 1 hours));
        consumer.priceWithFreshnessGuard();
    }

    function test_ValueConversionUsesFeedDecimals() public view {
        // 1 个 18 位小数的代币，按 2000.00000000 喂价 = 2000 个 18 位小数的计价单位
        assertEq(consumer.valueOf(1e18), 2000e18);
    }

    function test_RevertWhen_SettingNonPositivePrice() public {
        vm.expectRevert(MockPriceFeed.NonPositivePrice.selector);
        feed.setPrice(0);
    }
}
