// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @notice ERC-165：接口发现。让其他合约能问"你支持某某标准吗"。
interface IERC165 {
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}

/// @notice EIP-721（ERC-721）核心接口，函数与事件与原文一一对应。
interface IERC721 is IERC165 {
    // from 为 address(0) 表示铸造；to 为 address(0) 表示销毁
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);

    function balanceOf(address owner) external view returns (uint256 balance);
    function ownerOf(uint256 tokenId) external view returns (address owner);

    // 不带接收方校验的普通转账
    function transferFrom(address from, address to, uint256 tokenId) external;

    // 带接收方校验的安全转账（两个重载）
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data)
        external;

    // 两层授权体系：单枚授权 + 操作员全量授权
    function approve(address to, uint256 tokenId) external;
    function setApprovalForAll(address operator, bool approved) external;
    function getApproved(uint256 tokenId) external view returns (address operator);
    function isApprovedForAll(address owner, address operator) external view returns (bool);
}

/// @notice ERC-721 元数据扩展：名称、符号、tokenURI
interface IERC721Metadata is IERC721 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}

/// @notice 接收方回调：合约想"安全地"接收 NFT，必须实现它并返回本选择器。
interface IERC721Receiver {
    function onERC721Received(address operator, address from, uint256 tokenId, bytes calldata data)
        external
        returns (bytes4);
}
