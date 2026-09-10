// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {AggregatorV3Interface} from "./MockPriceFeed.sol";

// 一个"消费预言机"的标准姿势：读喂价，并对喂价做新鲜度检查。
// 预言机报告的是"最近一次共识快照"，不是实时价格——不设新鲜度门槛的
// DeFi 协议在预言机停更时会拿陈旧价格做清算决策（历史上多次出事）。
contract PriceConsumer {
    AggregatorV3Interface public immutable feed;
    uint256 public immutable maxAgeSeconds;

    error StalePrice(uint256 updatedAt, uint256 age, uint256 maxAge);

    constructor(address feedAddress, uint256 maxAgeSeconds_) {
        feed = AggregatorV3Interface(feedAddress);
        maxAgeSeconds = maxAgeSeconds_;
    }

    // 不设防的读法：演示用。生产代码永远带上新鲜度检查。
    function latestPrice() external view returns (int256) {
        (, int256 answer, , , ) = feed.latestRoundData();
        return answer;
    }

    // 带新鲜度门槛的读法：喂价太旧就 revert，而不是默默用过期价格做决策
    function priceWithFreshnessGuard() external view returns (int256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        uint256 age = block.timestamp - updatedAt;
        if (age > maxAgeSeconds) {
            revert StalePrice(updatedAt, age, maxAgeSeconds);
        }
        return answer;
    }

    // 按喂价换算：演示 decimals 对齐（喂价 8 位小数 vs 链上金额 18 位）
    function valueOf(uint256 amount18) external view returns (uint256) {
        (, int256 answer, , uint256 updatedAt, ) = feed.latestRoundData();
        require(answer > 0);
        uint256 age = block.timestamp - updatedAt;
        if (age > maxAgeSeconds) revert StalePrice(updatedAt, age, maxAgeSeconds);
        uint8 feedDecimals = feed.decimals();
        // amount18 × price(10^-feedDecimals) = amount in 18 decimals
        return (amount18 * uint256(answer)) / (10 ** feedDecimals);
    }
}
