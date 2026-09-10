// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// 教学版预言机：实现 Chainlink AggregatorV3 接口的形状，价格由部署者手工设定。
// 它演示的是"喂价的形态"（roundId / answer / updatedAt），不是真实预言机网络的信任机制——
// 真实去中心化预言机网络的信任模型见本章正文。
interface AggregatorV3Interface {
    function decimals() external view returns (uint8);
    function description() external view returns (string memory);
    function version() external view returns (uint256);

    function getRoundData(uint80 _roundId)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract MockPriceFeed is AggregatorV3Interface {
    string private _description;
    uint8 private _decimals;
    uint80 private _roundId;
    int256 private _price;
    uint256 private _updatedAt;

    error NotOwner();
    error NonPositivePrice();
    error NoAnswer();

    address public immutable owner;

    constructor(string memory description_, uint8 decimals_, int256 initialPrice) {
        _description = description_;
        _decimals = decimals_;
        owner = msg.sender;
        _setPrice(initialPrice);
    }

    function setPrice(int256 newPrice) external {
        if (msg.sender != owner) revert NotOwner();
        _setPrice(newPrice);
    }

    function _setPrice(int256 newPrice) internal {
        if (newPrice <= 0) revert NonPositivePrice();
        _roundId += 1;
        _price = newPrice;
        _updatedAt = block.timestamp;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function description() external view returns (string memory) {
        return _description;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_price == 0) revert NoAnswer();
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }

    function getRoundData(uint80 _roundId_)
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound)
    {
        if (_roundId_ != _roundId || _price == 0) revert NoAnswer();
        return (_roundId, _price, _updatedAt, _updatedAt, _roundId);
    }
}
